#property strict
#property version   "5.0"
#property description "QM5_10815 TradingView Post-Absorption VWAP Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10815;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period           = 14;
input int    strategy_volume_lookback      = 20;
input double strategy_vwap_stretch_atr     = 0.50;
input double strategy_volume_ratio         = 1.50;
input double strategy_wick_share           = 0.55;
input double strategy_stop_buffer_atr      = 0.25;
input double strategy_max_stop_atr         = 2.50;
input double strategy_target_rr            = 0.0;
input int    strategy_time_stop_m15_bars   = 24;
input int    strategy_time_stop_h1_bars    = 12;
input bool   strategy_session_filter       = true;
input int    strategy_session_start_hour   = 7;
input int    strategy_session_end_hour     = 21;
input int    strategy_max_spread_points    = 0;

int g_last_absorption_signal_dir = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point > 0.0 && ask > bid && ((ask - bid) / point) > (double)strategy_max_spread_points)
         return true;
     }

   if(strategy_session_filter)
     {
      MqlDateTime now_dt;
      TimeToStruct(TimeCurrent(), now_dt);
      const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
      const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour));
      bool inside = true;
      if(start_h < end_h)
         inside = (now_dt.hour >= start_h && now_dt.hour < end_h);
      else if(start_h > end_h)
         inside = (now_dt.hour >= start_h || now_dt.hour < end_h);
      if(!inside)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_absorption_signal_dir = 0;

   if(strategy_atr_period <= 0 ||
      strategy_volume_lookback < 3 ||
      strategy_vwap_stretch_atr <= 0.0 ||
      strategy_volume_ratio <= 0.0 ||
      strategy_wick_share <= 0.0 ||
      strategy_wick_share >= 1.0 ||
      strategy_stop_buffer_atr < 0.0 ||
      strategy_max_stop_atr <= 0.0)
      return false;

   const int need_bars = MathMax(strategy_volume_lookback + 4, 64);
   const int bars_to_copy = MathMin(MathMax(need_bars, 64), 512);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_to_copy, rates); // perf-allowed: called only after the framework QM_IsNewBar gate.
   if(copied < strategy_volume_lookback + 4)
      return false;

   MqlDateTime session_dt;
   TimeToStruct(rates[1].time, session_dt);
   double pv_sum = 0.0;
   double vol_sum = 0.0;
   for(int i = 1; i < copied; ++i)
     {
      MqlDateTime bar_dt;
      TimeToStruct(rates[i].time, bar_dt);
      if(bar_dt.year != session_dt.year || bar_dt.day_of_year != session_dt.day_of_year)
         break;

      const double bar_vol = MathMax(1.0, (double)rates[i].tick_volume);
      const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      pv_sum += typical * bar_vol;
      vol_sum += bar_vol;
     }
   if(vol_sum <= 0.0)
      return false;
   const double session_vwap = pv_sum / vol_sum;
   if(session_vwap <= 0.0)
      return false;

   double avg_volume = 0.0;
   for(int i = 3; i < 3 + strategy_volume_lookback && i < copied; ++i)
      avg_volume += MathMax(1.0, (double)rates[i].tick_volume);
   avg_volume /= (double)strategy_volume_lookback;
   if(avg_volume <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double abs_open = rates[2].open;
   const double abs_high = rates[2].high;
   const double abs_low = rates[2].low;
   const double abs_close = rates[2].close;
   const double abs_range = abs_high - abs_low;
   if(abs_range <= 0.0)
      return false;

   const double lower_wick = MathMin(abs_open, abs_close) - abs_low;
   const double upper_wick = abs_high - MathMax(abs_open, abs_close);
   const bool high_relative_volume = ((double)rates[2].tick_volume >= avg_volume * strategy_volume_ratio);
   const bool close_inside_prior = (abs_close <= rates[3].high && abs_close >= rates[3].low);
   const bool stretched_below_vwap = (abs_low <= session_vwap - strategy_vwap_stretch_atr * atr);
   const bool stretched_above_vwap = (abs_high >= session_vwap + strategy_vwap_stretch_atr * atr);
   const bool bearish_side_absorption = high_relative_volume &&
                                        close_inside_prior &&
                                        stretched_below_vwap &&
                                        ((lower_wick / abs_range) >= strategy_wick_share);
   const bool bullish_side_absorption = high_relative_volume &&
                                        close_inside_prior &&
                                        stretched_above_vwap &&
                                        ((upper_wick / abs_range) >= strategy_wick_share);

   const bool long_signal = bearish_side_absorption && (rates[1].close > abs_high);
   const bool short_signal = bullish_side_absorption && (rates[1].close < abs_low);
   if(long_signal)
      g_last_absorption_signal_dir = 1;
   else if(short_signal)
      g_last_absorption_signal_dir = -1;
   else
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   if(long_signal)
     {
      const double natural_sl = abs_low - strategy_stop_buffer_atr * atr;
      const double capped_sl = entry - strategy_max_stop_atr * atr;
      sl = MathMax(natural_sl, capped_sl);
      if(session_vwap <= entry)
         return false;
     }
   else
     {
      const double natural_sl = abs_high + strategy_stop_buffer_atr * atr;
      const double capped_sl = entry + strategy_max_stop_atr * atr;
      sl = MathMin(natural_sl, capped_sl);
      if(session_vwap >= entry)
         return false;
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0 || (long_signal && sl >= entry) || (short_signal && sl <= entry))
      return false;

   double tp = 0.0;
   if(strategy_target_rr > 0.0)
      tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_rr);
   else
      tp = QM_StopRulesNormalizePrice(_Symbol, session_vwap);
   if(tp <= 0.0 || (long_signal && tp <= entry) || (short_signal && tp >= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "POST_ABS_VWAP_LONG" : "POST_ABS_VWAP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, or partial-close rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const int max_bars = (_Period == PERIOD_H1) ? strategy_time_stop_h1_bars
                                               : strategy_time_stop_m15_bars;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((ptype == POSITION_TYPE_BUY && g_last_absorption_signal_dir < 0) ||
         (ptype == POSITION_TYPE_SELL && g_last_absorption_signal_dir > 0))
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && period_seconds > 0 && max_bars > 0)
        {
         const int bars_held = (int)((TimeCurrent() - open_time) / period_seconds);
         if(bars_held >= max_bars)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // callable hook for P8; this card declares no strategy-specific news override.
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
