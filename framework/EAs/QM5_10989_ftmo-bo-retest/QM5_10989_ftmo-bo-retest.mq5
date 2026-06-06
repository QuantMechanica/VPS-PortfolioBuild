#property strict
#property version   "5.0"
#property description "QM5_10989 FTMO breakout retest acceptance"

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
input int    qm_ea_id                   = 10989;
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
input int    strategy_donchian_bars             = 24;
input int    strategy_atr_period                = 14;
input double strategy_min_range_atr             = 0.8;
input double strategy_max_range_atr             = 2.5;
input double strategy_breakout_buffer_atr       = 0.15;
input int    strategy_max_retest_bars           = 6;
input double strategy_max_breakout_bar_atr      = 2.0;
input int    strategy_failed_breakout_lookback  = 12;
input double strategy_stop_atr_mult             = 0.75;
input double strategy_reward_r                  = 2.0;
input int    strategy_max_hold_bars             = 24;

int     g_setup_dir = 0;
int     g_setup_bars_left = 0;
double  g_setup_range_high = 0.0;
double  g_setup_range_low = 0.0;
double  g_setup_atr = 0.0;

bool    g_position_range_valid = false;
double  g_position_range_high = 0.0;
double  g_position_range_low = 0.0;
int     g_position_bars_held = 0;
bool    g_cached_close_ready = false;
double  g_last_closed_close = 0.0;

bool Strategy_LoadRecentRates(MqlRates &rates[])
  {
   if(strategy_donchian_bars < 2 || strategy_atr_period < 1)
      return false;

   int required = strategy_donchian_bars + strategy_failed_breakout_lookback + 8;
   const int retest_required = strategy_donchian_bars + strategy_max_retest_bars + 8;
   if(required < retest_required)
      required = retest_required;
   if(required < 40)
      required = 40;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, required, rates); // perf-allowed: bounded Donchian/retest OHLC snapshot, called only from skeleton new-bar entry hook.
   return (copied >= required);
  }

bool Strategy_DonchianRange(MqlRates &rates[],
                            const int start_shift,
                            const int bars,
                            double &range_high,
                            double &range_low)
  {
   const int total = ArraySize(rates);
   if(bars <= 0 || start_shift < 0 || start_shift + bars > total)
      return false;

   range_high = -DBL_MAX;
   range_low = DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      if(rates[i].high > range_high)
         range_high = rates[i].high;
      if(rates[i].low < range_low)
         range_low = rates[i].low;
     }

   return (range_high > range_low && range_low > 0.0);
  }

bool Strategy_HaveOpenPosition()
  {
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
      return true;
     }

   return false;
  }

void Strategy_UpdateClosedBarState(MqlRates &rates[])
  {
   if(ArraySize(rates) < 2)
      return;

   g_last_closed_close = rates[1].close;
   g_cached_close_ready = (g_last_closed_close > 0.0);

   if(Strategy_HaveOpenPosition())
     {
      if(g_position_range_valid)
         g_position_bars_held++;
      return;
     }

   g_position_range_valid = false;
   g_position_bars_held = 0;
  }

bool Strategy_HasOppositeFailedBreakout(MqlRates &rates[], const int new_breakout_dir)
  {
   if(strategy_failed_breakout_lookback <= 0)
      return false;

   const int lookback = strategy_failed_breakout_lookback;
   for(int shift = 2; shift < 2 + lookback; ++shift)
     {
      double range_high = 0.0;
      double range_low = 0.0;
      if(!Strategy_DonchianRange(rates, shift + 1, strategy_donchian_bars, range_high, range_low))
         continue;

      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;

      const double buffer = strategy_breakout_buffer_atr * atr;
      if(new_breakout_dir > 0)
        {
         const bool broke_down = (rates[shift].close < range_low - buffer);
         const bool returned_inside = (rates[shift - 1].close >= range_low && rates[shift - 1].close <= range_high);
         if(broke_down && returned_inside)
            return true;
        }
      else if(new_breakout_dir < 0)
        {
         const bool broke_up = (rates[shift].close > range_high + buffer);
         const bool returned_inside = (rates[shift - 1].close >= range_low && rates[shift - 1].close <= range_high);
         if(broke_up && returned_inside)
            return true;
        }
     }

   return false;
  }

bool Strategy_BrokerStopDistanceOK(const double entry, const double sl, const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_distance = (double)stops_level * point;
   if(min_distance <= 0.0)
      return true;

   return (MathAbs(entry - sl) >= min_distance && MathAbs(entry - tp) >= min_distance);
  }

bool Strategy_BuildRetestEntry(MqlRates &rates[], QM_EntryRequest &req)
  {
   if(g_setup_dir == 0 || g_setup_bars_left <= 0 || ArraySize(rates) < 2)
      return false;

   const double retest_low = rates[1].low;
   const double retest_high = rates[1].high;
   const double retest_close = rates[1].close;
   const bool long_accept = (g_setup_dir > 0 &&
                             retest_low <= g_setup_range_high &&
                             retest_close > g_setup_range_high);
   const bool short_accept = (g_setup_dir < 0 &&
                              retest_high >= g_setup_range_low &&
                              retest_close < g_setup_range_low);

   if(!long_accept && !short_accept)
     {
      g_setup_bars_left--;
      if(g_setup_bars_left <= 0)
         g_setup_dir = 0;
      return false;
     }

   const bool is_long = (g_setup_dir > 0);
   const double market_entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (market_entry > 0.0) ? market_entry : retest_close;
   const double structural_sl = is_long ? MathMin(retest_low, g_setup_range_high - strategy_stop_atr_mult * g_setup_atr)
                                        : MathMax(retest_high, g_setup_range_low + strategy_stop_atr_mult * g_setup_atr);
   const double risk_distance = is_long ? (entry - structural_sl) : (structural_sl - entry);
   if(risk_distance <= 0.0 || strategy_reward_r <= 0.0)
     {
      g_setup_dir = 0;
      return false;
     }

   const double tp = is_long ? (entry + strategy_reward_r * risk_distance)
                             : (entry - strategy_reward_r * risk_distance);
   if(!Strategy_BrokerStopDistanceOK(entry, structural_sl, tp))
     {
      g_setup_dir = 0;
      return false;
     }

   req.type = is_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = structural_sl;
   req.tp = tp;
   req.reason = is_long ? "FTMO_BO_RETEST_LONG" : "FTMO_BO_RETEST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_position_range_valid = true;
   g_position_range_high = g_setup_range_high;
   g_position_range_low = g_setup_range_low;
   g_position_bars_held = 0;
   g_setup_dir = 0;
   g_setup_bars_left = 0;
   return true;
  }

void Strategy_DetectBreakoutSetup(MqlRates &rates[])
  {
   double range_high = 0.0;
   double range_low = 0.0;
   if(!Strategy_DonchianRange(rates, 2, strategy_donchian_bars, range_high, range_low))
      return;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double range_height = range_high - range_low;
   if(range_height < strategy_min_range_atr * atr || range_height > strategy_max_range_atr * atr)
      return;

   const double breakout_bar_range = rates[1].high - rates[1].low;
   if(breakout_bar_range > strategy_max_breakout_bar_atr * atr)
      return;

   const double buffer = strategy_breakout_buffer_atr * atr;
   int dir = 0;
   if(rates[1].close > range_high + buffer)
      dir = 1;
   else if(rates[1].close < range_low - buffer)
      dir = -1;

   if(dir == 0)
      return;
   if(Strategy_HasOppositeFailedBreakout(rates, dir))
      return;

   g_setup_dir = dir;
   g_setup_bars_left = strategy_max_retest_bars;
   g_setup_range_high = range_high;
   g_setup_range_low = range_low;
   g_setup_atr = atr;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M30)
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

   MqlRates rates[];
   if(!Strategy_LoadRecentRates(rates))
      return false;

   Strategy_UpdateClosedBarState(rates);
   if(Strategy_HaveOpenPosition())
      return false;

   if(Strategy_BuildRetestEntry(rates, req))
      return true;

   Strategy_DetectBreakoutSetup(rates);
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HaveOpenPosition())
      return false;

   if(strategy_max_hold_bars > 0 && g_position_range_valid && g_position_bars_held >= strategy_max_hold_bars)
      return true;

   if(g_position_range_valid && g_cached_close_ready)
     {
      if(g_last_closed_close >= g_position_range_low && g_last_closed_close <= g_position_range_high)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
