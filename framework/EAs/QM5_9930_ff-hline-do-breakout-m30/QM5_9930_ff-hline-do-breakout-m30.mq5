#property strict
#property version   "5.0"
#property description "QM5_9930 ForexFactory horizontal-line daily-open breakout M30"

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
input int    qm_ea_id                   = 9930;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_PAUSE;

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
input int    strategy_atr_period                 = 14;
input int    strategy_fx_offset_pips             = 10;
input int    strategy_fx_stop_pips               = 11;
input int    strategy_fx_tp_pips                 = 20;
input double strategy_xau_offset_atr_mult        = 0.35;
input double strategy_xau_sl_atr_mult            = 1.00;
input double strategy_fx_sl_atr_floor_mult       = 0.80;
input double strategy_fx_sl_atr_cap_mult         = 1.80;
input double strategy_signal_range_atr_mult      = 0.40;
input double strategy_reward_r_multiple          = 1.40;
input int    strategy_session_start_hour_broker  = 8;
input int    strategy_session_end_hour_broker    = 22;
input int    strategy_max_hold_bars              = 16;
input int    strategy_news_pause_minutes         = 15;
input int    strategy_max_spread_points          = 0;

int  g_strategy_day_key = -1;
bool g_strategy_long_taken_today = false;
bool g_strategy_short_taken_today = false;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

void Strategy_ResetDayStateIfNeeded()
  {
   const int day_key = Strategy_DayKey(TimeCurrent());
   if(day_key == g_strategy_day_key)
      return;

   g_strategy_day_key = day_key;
   g_strategy_long_taken_today = false;
   g_strategy_short_taken_today = false;
  }

bool Strategy_IsXauSymbol()
  {
   return (StringFind(_Symbol, "XAU") >= 0);
  }

bool Strategy_HourInSession(const int hour, const int start_hour, const int end_hour)
  {
   const int start = MathMax(0, MathMin(23, start_hour));
   const int end = MathMax(0, MathMin(23, end_hour));
   if(start == end)
      return true;
   if(start < end)
      return (hour >= start && hour < end);
   return (hour >= start || hour < end);
  }

bool Strategy_IsEntrySession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return Strategy_HourInSession(dt.hour,
                                 strategy_session_start_hour_broker,
                                 strategy_session_end_hour_broker);
  }

bool Strategy_IsSessionEndOrLater(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int end_hour = MathMax(0, MathMin(23, strategy_session_end_hour_broker));
   return (dt.hour >= end_hour);
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at)
  {
   ptype = POSITION_TYPE_BUY;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   return Strategy_HasOpenPosition(ptype, opened_at);
  }

double Strategy_TakeCloser(const QM_OrderType side,
                           const double entry,
                           const double sl,
                           const int fixed_tp_pips,
                           const double rr)
  {
   const double fixed_tp = QM_TakeFixedPips(_Symbol, side, entry, fixed_tp_pips);
   const double rr_tp = QM_TakeRR(_Symbol, side, entry, sl, rr);
   if(fixed_tp <= 0.0)
      return rr_tp;
   if(rr_tp <= 0.0)
      return fixed_tp;

   const double fixed_dist = MathAbs(fixed_tp - entry);
   const double rr_dist = MathAbs(rr_tp - entry);
   return (fixed_dist <= rr_dist) ? fixed_tp : rr_tp;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetDayStateIfNeeded();

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsEntrySession(TimeCurrent()))
      return false;

   const double daily_open = iOpen(_Symbol, PERIOD_D1, 0);          // perf-allowed: fixed-shift daily-open structural level.
   const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);       // perf-allowed: fixed closed-bar breakout check.
   const double high_1 = iHigh(_Symbol, PERIOD_CURRENT, 1);         // perf-allowed: fixed closed-bar signal range.
   const double low_1 = iLow(_Symbol, PERIOD_CURRENT, 1);           // perf-allowed: fixed closed-bar signal range.
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(daily_open <= 0.0 || close_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || atr <= 0.0)
      return false;

   if((high_1 - low_1) < atr * strategy_signal_range_atr_mult)
      return false;

   const bool is_xau = Strategy_IsXauSymbol();
   const double offset_dist = is_xau
                              ? atr * strategy_xau_offset_atr_mult
                              : QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fx_offset_pips);
   if(offset_dist <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   if(close_1 > daily_open + offset_dist)
     {
      if(g_strategy_long_taken_today)
         return false;
      side = QM_BUY;
     }
   else if(close_1 < daily_open - offset_dist)
     {
      if(g_strategy_short_taken_today)
         return false;
      side = QM_SELL;
     }
   else
      return false;

   const double entry = QM_OrderTypeIsBuy(side)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl_dist = 0.0;
   if(is_xau)
      sl_dist = atr * strategy_xau_sl_atr_mult;
   else
     {
      const double fixed_stop = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fx_stop_pips);
      sl_dist = MathMax(fixed_stop, atr * strategy_fx_sl_atr_floor_mult);
      sl_dist = MathMin(sl_dist, atr * strategy_fx_sl_atr_cap_mult);
     }
   if(sl_dist <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   req.tp = is_xau
            ? QM_TakeRR(_Symbol, side, entry, req.sl, strategy_reward_r_multiple)
            : Strategy_TakeCloser(side, entry, req.sl, strategy_fx_tp_pips, strategy_reward_r_multiple);
   req.reason = QM_OrderTypeIsBuy(side) ? "DO_BREAKOUT_LONG" : "DO_BREAKOUT_SHORT";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   if(QM_OrderTypeIsBuy(side))
      g_strategy_long_taken_today = true;
   else
      g_strategy_short_taken_today = true;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, partial close, or pyramiding rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   if(!Strategy_HasOpenPosition(ptype, opened_at))
      return false;

   if(strategy_max_hold_bars > 0 && opened_at > 0)
     {
      const int max_hold_seconds = strategy_max_hold_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(max_hold_seconds > 0 && TimeCurrent() - opened_at >= max_hold_seconds)
         return true;
     }

   if(Strategy_IsSessionEndOrLater(TimeCurrent()))
      return true;

   const double daily_open = iOpen(_Symbol, PERIOD_D1, 0);       // perf-allowed: fixed-shift daily-open structural exit.
   const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);    // perf-allowed: fixed closed-bar daily-open recross exit.
   if(daily_open <= 0.0 || close_1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && close_1 < daily_open)
      return true;
   if(ptype == POSITION_TYPE_SELL && close_1 > daily_open)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
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
                        strategy_news_pause_minutes,   // pause-before (legacy hint)
                        strategy_news_pause_minutes,   // pause-after (legacy hint)
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
