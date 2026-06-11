#property strict
#property version   "5.0"
#property description "QM5_9991 ForexFactory TMT Scalping M15"

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
input int    qm_ea_id                   = 9991;
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
input int    strategy_ema_fast_period       = 7;
input int    strategy_ema_slow_period       = 20;
input int    strategy_rsi_period            = 14;
input double strategy_rsi_midline           = 50.0;
input int    strategy_atr_period            = 14;
input double strategy_break_atr_mult        = 0.10;
input int    strategy_swing_lookback_bars   = 48;
input int    strategy_fractal_side_bars     = 2;
input int    strategy_pullback_bars         = 6;
input int    strategy_stop_pips             = 10;
input int    strategy_take_profit_pips      = 15;
input int    strategy_time_stop_bars        = 12;
input int    strategy_session_start_utc     = 7;
input int    strategy_session_end_utc       = 20;
input double strategy_max_spread_pips       = 1.5;
input double strategy_max_spread_stop_pct   = 15.0;

int      g_tmt_signal_dir   = 0;
datetime g_tmt_signal_stamp = 0;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

bool Strategy_SessionAllows(const datetime broker_time)
  {
   const int start_h = strategy_session_start_utc;
   const int end_h = strategy_session_end_utc;
   if(start_h < 0 || start_h > 23 || end_h < 0 || end_h > 23)
      return false;
   if(start_h == end_h)
      return true;

   const datetime utc_time = QM_BrokerToUTC(broker_time);
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);

   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool Strategy_SpreadAllows()
  {
   const double pip = Strategy_PipSize();
   if(pip <= 0.0 || strategy_stop_pips <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double spread_pips = (ask - bid) / pip;
   if(spread_pips > strategy_max_spread_pips)
      return false;

   const double spread_stop_pct = (spread_pips / (double)strategy_stop_pips) * 100.0;
   return (spread_stop_pct <= strategy_max_spread_stop_pct);
  }

bool Strategy_FindOurPosition(ENUM_POSITION_TYPE &pos_type, datetime &opened_at)
  {
   pos_type = POSITION_TYPE_BUY;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOurPosition()
  {
   ENUM_POSITION_TYPE pos_type;
   datetime opened_at;
   return Strategy_FindOurPosition(pos_type, opened_at);
  }

bool Strategy_IsSwingHigh(MqlRates &rates[], const int idx, const int side)
  {
   const double pivot = rates[idx].high;
   for(int d = 1; d <= side; ++d)
     {
      if(pivot <= rates[idx - d].high || pivot <= rates[idx + d].high)
         return false;
     }
   return true;
  }

bool Strategy_IsSwingLow(MqlRates &rates[], const int idx, const int side)
  {
   const double pivot = rates[idx].low;
   for(int d = 1; d <= side; ++d)
     {
      if(pivot >= rates[idx - d].low || pivot >= rates[idx + d].low)
         return false;
     }
   return true;
  }

bool Strategy_FindTwoSwingHighs(MqlRates &rates[], const int rates_count,
                                int &recent_idx, double &recent_price,
                                int &older_idx, double &older_price)
  {
   recent_idx = -1;
   older_idx = -1;
   recent_price = 0.0;
   older_price = 0.0;

   const int side = strategy_fractal_side_bars;
   const int last_idx = MathMin(strategy_swing_lookback_bars - 1, rates_count - side - 1);
   if(side < 1 || last_idx <= side)
      return false;

   for(int idx = side; idx <= last_idx; ++idx)
     {
      if(!Strategy_IsSwingHigh(rates, idx, side))
         continue;
      if(recent_idx < 0)
        {
         recent_idx = idx;
         recent_price = rates[idx].high;
        }
      else
        {
         older_idx = idx;
         older_price = rates[idx].high;
         return true;
        }
     }

   return false;
  }

bool Strategy_FindTwoSwingLows(MqlRates &rates[], const int rates_count,
                               int &recent_idx, double &recent_price,
                               int &older_idx, double &older_price)
  {
   recent_idx = -1;
   older_idx = -1;
   recent_price = 0.0;
   older_price = 0.0;

   const int side = strategy_fractal_side_bars;
   const int last_idx = MathMin(strategy_swing_lookback_bars - 1, rates_count - side - 1);
   if(side < 1 || last_idx <= side)
      return false;

   for(int idx = side; idx <= last_idx; ++idx)
     {
      if(!Strategy_IsSwingLow(rates, idx, side))
         continue;
      if(recent_idx < 0)
        {
         recent_idx = idx;
         recent_price = rates[idx].low;
        }
      else
        {
         older_idx = idx;
         older_price = rates[idx].low;
         return true;
        }
     }

   return false;
  }

double Strategy_ProjectLine(const int recent_idx, const double recent_price,
                            const int older_idx, const double older_price,
                            const int target_idx)
  {
   if(older_idx == recent_idx)
      return 0.0;
   const double slope = (older_price - recent_price) / (double)(older_idx - recent_idx);
   return recent_price + ((double)(target_idx - recent_idx) * slope);
  }

bool Strategy_HadEmaBandPullback(MqlRates &rates[])
  {
   const int bars = MathMax(1, strategy_pullback_bars);
   for(int idx = 0; idx < bars; ++idx)
     {
      const int shift = idx + 1;
      const double ema_fast = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_fast_period, shift);
      const double ema_slow = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_slow_period, shift);
      if(ema_fast <= 0.0 || ema_slow <= 0.0)
         continue;

      const double band_low = MathMin(ema_fast, ema_slow);
      const double band_high = MathMax(ema_fast, ema_slow);
      if(rates[idx].low <= band_high && rates[idx].high >= band_low)
         return true;
     }

   return false;
  }

int Strategy_ComputeTmtSignal(datetime &signal_time)
  {
   signal_time = 0;
   if(strategy_swing_lookback_bars < 8 || strategy_fractal_side_bars < 1)
      return 0;

   const int copy_count = strategy_swing_lookback_bars + strategy_fractal_side_bars + 4;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, copy_count, rates); // perf-allowed: gated by skeleton QM_IsNewBar; bounded fractal-trendline window.
   if(copied < strategy_swing_lookback_bars)
      return 0;

   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, daily) != 1) // perf-allowed: one current D1 candle read inside closed-bar signal.
      return 0;

   const double ema_fast = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_slow_period, 1);
   const double rsi = QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || rsi <= 0.0 || atr <= 0.0)
      return 0;

   if(!Strategy_HadEmaBandPullback(rates))
      return 0;

   signal_time = rates[0].time;
   const double close_1 = rates[0].close;
   const double break_buffer = atr * strategy_break_atr_mult;

   int recent_idx = -1;
   int older_idx = -1;
   double recent_price = 0.0;
   double older_price = 0.0;

   if(daily[0].close > daily[0].open &&
      ema_fast > ema_slow &&
      rsi > strategy_rsi_midline &&
      Strategy_FindTwoSwingHighs(rates, copied, recent_idx, recent_price, older_idx, older_price) &&
      recent_price < older_price)
     {
      const double trendline_now = Strategy_ProjectLine(recent_idx, recent_price, older_idx, older_price, 0);
      if(trendline_now > 0.0 && close_1 > trendline_now + break_buffer)
         return 1;
     }

   if(daily[0].close < daily[0].open &&
      ema_fast < ema_slow &&
      rsi < strategy_rsi_midline &&
      Strategy_FindTwoSwingLows(rates, copied, recent_idx, recent_price, older_idx, older_price) &&
      recent_price > older_price)
     {
      const double trendline_now = Strategy_ProjectLine(recent_idx, recent_price, older_idx, older_price, 0);
      if(trendline_now > 0.0 && close_1 < trendline_now - break_buffer)
         return -1;
     }

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_SessionAllows(TimeCurrent()))
      return true;
   if(!Strategy_SpreadAllows())
      return true;
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

   datetime signal_time = 0;
   const int signal = Strategy_ComputeTmtSignal(signal_time);
   g_tmt_signal_dir = signal;
   g_tmt_signal_stamp = signal_time;
   if(signal == 0 || Strategy_HasOurPosition())
      return false;

   QM_OrderType side = QM_BUY;
   if(signal < 0)
      side = QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_stop_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_take_profit_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (signal > 0) ? "TMT_LONG_BREAKOUT" : "TMT_SHORT_BREAKOUT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no break-even, trailing, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type;
   datetime opened_at;
   if(!Strategy_FindOurPosition(pos_type, opened_at))
      return false;

   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_M15);
   if(hold_seconds > 0 && opened_at > 0 && (TimeCurrent() - opened_at) >= hold_seconds)
      return true;

   if(g_tmt_signal_stamp > 0)
     {
      if(pos_type == POSITION_TYPE_BUY && g_tmt_signal_dir < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_tmt_signal_dir > 0)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false; // defer to QM_NewsAllowsTrade(...)
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
