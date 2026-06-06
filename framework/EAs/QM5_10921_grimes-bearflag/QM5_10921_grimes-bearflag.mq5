#property strict
#property version   "5.0"
#property description "QM5_10921 Grimes Momentum Bear Flag"

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
input int    qm_ea_id                   = 10921;
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
input int    strategy_keltner_period          = 20;
input double strategy_keltner_atr_mult        = 2.25;
input int    strategy_breakout_lookback       = 20;
input int    strategy_breakdown_scan_bars     = 10;
input int    strategy_macd_fast               = 12;
input int    strategy_macd_slow               = 26;
input int    strategy_macd_signal             = 9;
input int    strategy_macd_extreme_lookback   = 60;
input int    strategy_macd_extreme_window     = 3;
input int    strategy_bounce_min_bars         = 2;
input int    strategy_bounce_max_bars         = 8;
input double strategy_bounce_max_retrace      = 0.50;
input double strategy_bounce_reject_retrace   = 0.618;
input int    strategy_sl_atr_period           = 14;
input double strategy_sl_atr_buffer_mult      = 0.25;
input double strategy_max_stop_atr_mult       = 3.0;
input double strategy_target_r_mult           = 1.0;
input double strategy_trail_atr_mult          = 2.0;
input int    strategy_time_exit_bars          = 10;
input double strategy_spread_stop_fraction    = 0.10;

ulong g_trailing_tickets[32];
int   g_trailing_ticket_count = 0;

double BarOpen(const int shift)  { return iOpen(_Symbol, _Period, shift); }   // perf-allowed: structural D1 flag math, EntrySignal is framework new-bar gated.
double BarHigh(const int shift)  { return iHigh(_Symbol, _Period, shift); }   // perf-allowed: structural D1 flag math, bounded helper.
double BarLow(const int shift)   { return iLow(_Symbol, _Period, shift); }    // perf-allowed: structural D1 flag math, bounded helper.
double BarClose(const int shift) { return iClose(_Symbol, _Period, shift); }  // perf-allowed: structural D1 flag math, bounded helper.

bool ValidStrategyInputs()
  {
   return strategy_keltner_period > 1 &&
          strategy_keltner_atr_mult > 0.0 &&
          strategy_breakout_lookback > 1 &&
          strategy_breakdown_scan_bars >= 3 &&
          strategy_macd_fast > 0 &&
          strategy_macd_slow > strategy_macd_fast &&
          strategy_macd_signal > 0 &&
          strategy_macd_extreme_lookback > 1 &&
          strategy_macd_extreme_window > 0 &&
          strategy_bounce_min_bars >= 1 &&
          strategy_bounce_max_bars >= strategy_bounce_min_bars &&
          strategy_bounce_max_retrace > 0.0 &&
          strategy_bounce_reject_retrace >= strategy_bounce_max_retrace &&
          strategy_sl_atr_period > 1 &&
          strategy_sl_atr_buffer_mult >= 0.0 &&
          strategy_max_stop_atr_mult > 0.0 &&
          strategy_target_r_mult > 0.0 &&
          strategy_trail_atr_mult > 0.0 &&
          strategy_time_exit_bars > 0 &&
          strategy_spread_stop_fraction > 0.0;
  }

double HighestClose(const int start_shift, const int count)
  {
   double value = -DBL_MAX;
   for(int i = start_shift; i < start_shift + count; ++i)
     {
      const double close_i = BarClose(i);
      if(close_i <= 0.0)
         return 0.0;
      value = MathMax(value, close_i);
     }
   return value;
  }

double LowestClose(const int start_shift, const int count)
  {
   double value = DBL_MAX;
   for(int i = start_shift; i < start_shift + count; ++i)
     {
      const double close_i = BarClose(i);
      if(close_i <= 0.0)
         return 0.0;
      value = MathMin(value, close_i);
     }
   return value;
  }

double HighestHigh(const int start_shift, const int count)
  {
   double value = -DBL_MAX;
   for(int i = start_shift; i < start_shift + count; ++i)
     {
      const double high_i = BarHigh(i);
      if(high_i <= 0.0)
         return 0.0;
      value = MathMax(value, high_i);
     }
   return value;
  }

double LowestLow(const int start_shift, const int count)
  {
   double value = DBL_MAX;
   for(int i = start_shift; i < start_shift + count; ++i)
     {
      const double low_i = BarLow(i);
      if(low_i <= 0.0)
         return 0.0;
      value = MathMin(value, low_i);
     }
   return value;
  }

bool MacdExtremeNearBreak(const int break_shift, const bool bullish)
  {
   for(int s = break_shift; s < break_shift + strategy_macd_extreme_window; ++s)
     {
      const double candidate = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s);
      double extreme = bullish ? -DBL_MAX : DBL_MAX;
      for(int j = s; j < s + strategy_macd_extreme_lookback; ++j)
        {
         const double macd_j = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, j);
         extreme = bullish ? MathMax(extreme, macd_j) : MathMin(extreme, macd_j);
        }

      if(bullish && candidate >= extreme - 1e-10)
         return true;
      if(!bullish && candidate <= extreme + 1e-10)
         return true;
     }
   return false;
  }

bool SpreadWithinStop(const double stop_distance)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || stop_distance <= 0.0)
      return false;
   return (ask - bid) <= strategy_spread_stop_fraction * stop_distance;
  }

bool IsTrailingTicket(const ulong ticket)
  {
   for(int i = 0; i < g_trailing_ticket_count; ++i)
      if(g_trailing_tickets[i] == ticket)
         return true;
   return false;
  }

void MarkTrailingTicket(const ulong ticket)
  {
   if(ticket == 0 || IsTrailingTicket(ticket) || g_trailing_ticket_count >= 32)
      return;
   g_trailing_tickets[g_trailing_ticket_count] = ticket;
   g_trailing_ticket_count++;
  }

bool BuildShortSignal(const int bounce_bars, QM_EntryRequest &req)
  {
   const int break_shift = bounce_bars + 2;
   if(break_shift > strategy_breakdown_scan_bars)
      return false;

   const double trigger_close = BarClose(1);
   const double break_close = BarClose(break_shift);
   if(trigger_close <= 0.0 || break_close <= 0.0)
      return false;

   const double prior_low = LowestClose(break_shift + 1, strategy_breakout_lookback);
   const double prior_high = HighestClose(break_shift + 1, strategy_breakout_lookback);
   if(prior_low <= 0.0 || prior_high <= 0.0 || break_close >= prior_low)
      return false;

   const double atr20 = QM_ATR(_Symbol, _Period, strategy_keltner_period, break_shift);
   const double ema20 = QM_EMA(_Symbol, _Period, strategy_keltner_period, break_shift);
   if(atr20 <= 0.0 || ema20 <= 0.0 || break_close > ema20 - strategy_keltner_atr_mult * atr20)
      return false;

   if(!MacdExtremeNearBreak(break_shift, false))
      return false;

   const double bounce_high = HighestHigh(2, bounce_bars);
   const double bounce_low = LowestLow(2, bounce_bars);
   const double bounce_high_close = HighestClose(2, bounce_bars);
   const double leg = prior_high - break_close;
   if(bounce_high <= 0.0 || bounce_low <= 0.0 || bounce_high_close <= 0.0 || leg <= 0.0)
      return false;

   const double retrace = (bounce_high_close - break_close) / leg;
   if(retrace > strategy_bounce_max_retrace || retrace > strategy_bounce_reject_retrace)
      return false;
   if(trigger_close >= bounce_low)
      return false;

   const double atr14 = QM_ATR(_Symbol, _Period, strategy_sl_atr_period, 1);
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop = bounce_high + strategy_sl_atr_buffer_mult * atr14;
   const double stop_distance = stop - entry;
   if(atr14 <= 0.0 || entry <= 0.0 || stop_distance <= 0.0)
      return false;
   if(stop_distance > strategy_max_stop_atr_mult * atr14)
      return false;
   if(!SpreadWithinStop(stop_distance))
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(stop, _Digits);
   req.tp = 0.0;
   req.reason = "GRIMES_BEARFLAG_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool BuildLongSignal(const int bounce_bars, QM_EntryRequest &req)
  {
   const int break_shift = bounce_bars + 2;
   if(break_shift > strategy_breakdown_scan_bars)
      return false;

   const double trigger_close = BarClose(1);
   const double break_close = BarClose(break_shift);
   if(trigger_close <= 0.0 || break_close <= 0.0)
      return false;

   const double prior_high = HighestClose(break_shift + 1, strategy_breakout_lookback);
   const double prior_low = LowestClose(break_shift + 1, strategy_breakout_lookback);
   if(prior_high <= 0.0 || prior_low <= 0.0 || break_close <= prior_high)
      return false;

   const double atr20 = QM_ATR(_Symbol, _Period, strategy_keltner_period, break_shift);
   const double ema20 = QM_EMA(_Symbol, _Period, strategy_keltner_period, break_shift);
   if(atr20 <= 0.0 || ema20 <= 0.0 || break_close < ema20 + strategy_keltner_atr_mult * atr20)
      return false;

   if(!MacdExtremeNearBreak(break_shift, true))
      return false;

   const double pullback_low = LowestLow(2, bounce_bars);
   const double pullback_high = HighestHigh(2, bounce_bars);
   const double pullback_low_close = LowestClose(2, bounce_bars);
   const double leg = break_close - prior_low;
   if(pullback_low <= 0.0 || pullback_high <= 0.0 || pullback_low_close <= 0.0 || leg <= 0.0)
      return false;

   const double retrace = (break_close - pullback_low_close) / leg;
   if(retrace > strategy_bounce_max_retrace || retrace > strategy_bounce_reject_retrace)
      return false;
   if(trigger_close <= pullback_high)
      return false;

   const double atr14 = QM_ATR(_Symbol, _Period, strategy_sl_atr_period, 1);
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double stop = pullback_low - strategy_sl_atr_buffer_mult * atr14;
   const double stop_distance = entry - stop;
   if(atr14 <= 0.0 || entry <= 0.0 || stop_distance <= 0.0)
      return false;
   if(stop_distance > strategy_max_stop_atr_mult * atr14)
      return false;
   if(!SpreadWithinStop(stop_distance))
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = NormalizeDouble(stop, _Digits);
   req.tp = 0.0;
   req.reason = "GRIMES_BEARFLAG_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no time/session/regime no-trade filter. Spread is enforced
   // after the signal because it depends on the signal's stop distance.
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

   if(!ValidStrategyInputs())
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   for(int bounce_bars = strategy_bounce_min_bars; bounce_bars <= strategy_bounce_max_bars; ++bounce_bars)
     {
      if(BuildShortSignal(bounce_bars, req))
         return true;
      if(BuildLongSignal(bounce_bars, req))
         return true;
     }
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_open = iBarShift(_Symbol, _Period, open_time, false);
      if(bars_open >= strategy_time_exit_bars)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      if(IsTrailingTicket(ticket))
        {
         QM_TM_TrailATR(ticket, strategy_sl_atr_period, strategy_trail_atr_mult);
         continue;
        }

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double risk_distance = MathAbs(entry - sl);
      if(entry <= 0.0 || sl <= 0.0 || risk_distance <= 0.0)
         continue;

      const double target = is_buy ? entry + strategy_target_r_mult * risk_distance
                                   : entry - strategy_target_r_mult * risk_distance;
      const double high1 = BarHigh(1);
      const double low1 = BarLow(1);
      const double close1 = BarClose(1);
      if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
         continue;

      const bool target_touched = is_buy ? (high1 >= target) : (low1 <= target);
      if(!target_touched)
         continue;

      const bool closed_beyond_target = is_buy ? (close1 >= target) : (close1 <= target);
      if(closed_beyond_target)
        {
         MarkTrailingTicket(ticket);
         QM_TM_TrailATR(ticket, strategy_sl_atr_period, strategy_trail_atr_mult);
        }
      else
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Time exit and 1R continuation/exit handling live in Trade Management so
   // the hook can address each ticket with its open time and stop distance.
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
