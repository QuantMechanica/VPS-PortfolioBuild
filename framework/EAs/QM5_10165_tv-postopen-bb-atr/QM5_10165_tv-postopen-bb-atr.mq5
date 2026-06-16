#property strict
#property version   "5.0"
#property description "QM5_10165 TradingView post-open BB ATR breakout"
// rework v2 2026-06-16: session windows (DE 08:00-12:00 / US 15:30-19:00) are
// CET/Frankfurt local exchange time per the card, but were compared against raw
// broker time (GMT+2/+3). Broker runs 1h ahead of CET year-round, so every
// session window was shifted +1h and clipped, suppressing entries to a near-zero
// trade count (Q02 MIN_TRADES_NOT_MET). Fix: convert broker->CET via the
// canonical QM_DSTAware helpers before the hhmm comparison, mirroring QM5_10210.

#include <QM/QM_Common.mqh>

// Broker time -> CET/CEST local (Frankfurt) hhmm. Broker is UTC+2 (UTC+3 in US
// DST); CET is UTC+1 (CEST UTC+2). Uses the same US-DST proxy the broker offset
// itself uses, so the broker->CET delta is a clean -1h all year.
int QM5_10165_LocalHHMM(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const datetime cet = utc + (QM_IsUSDSTUTC(utc) ? 2 * 3600 : 1 * 3600);
   MqlDateTime ldt;
   TimeToStruct(cet, ldt);
   return ldt.hour * 100 + ldt.min;
  }

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
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
input int    qm_ea_id                   = 10165;
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
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period           = 14;
input double strategy_bb_deviation        = 1.5;
input double strategy_bb_near_basis_frac  = 0.50;
input int    strategy_ema_fast_period     = 10;
input int    strategy_ema_slow_period     = 200;
input int    strategy_rsi_period          = 7;
input double strategy_rsi_min             = 30.0;
input int    strategy_adx_period          = 7;
input double strategy_adx_min             = 10.0;
input int    strategy_resistance_bars     = 20;
input int    strategy_resistance_touches  = 2;
input double strategy_touch_tolerance_atr = 0.20;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.0;
input double strategy_atr_tp_mult         = 4.0;
input double strategy_max_spread_sl_frac  = 0.15;
input int    strategy_de_open_start_hhmm  = 800;
input int    strategy_de_open_end_hhmm    = 1200;
input int    strategy_us_open_start_hhmm  = 1530;
input int    strategy_us_open_end_hhmm    = 1900;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
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

   const int hhmm = QM5_10165_LocalHHMM(TimeCurrent());
   const bool in_de_window =
      (strategy_de_open_start_hhmm <= strategy_de_open_end_hhmm)
      ? (hhmm >= strategy_de_open_start_hhmm && hhmm < strategy_de_open_end_hhmm)
      : (hhmm >= strategy_de_open_start_hhmm || hhmm < strategy_de_open_end_hhmm);
   const bool in_us_window =
      (strategy_us_open_start_hhmm <= strategy_us_open_end_hhmm)
      ? (hhmm >= strategy_us_open_start_hhmm && hhmm < strategy_us_open_end_hhmm)
      : (hhmm >= strategy_us_open_start_hhmm || hhmm < strategy_us_open_end_hhmm);
   if(!in_de_window && !in_us_window)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;

   const double stop_distance = atr * strategy_atr_sl_mult;
   if(stop_distance <= 0.0)
      return true;

   return ((ask - bid) > stop_distance * strategy_max_spread_sl_frac);
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

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed breakout-bar session check
   if(bar_time <= 0)
      return false;

   const int hhmm = QM5_10165_LocalHHMM(bar_time);
   const bool in_de_window =
      (strategy_de_open_start_hhmm <= strategy_de_open_end_hhmm)
      ? (hhmm >= strategy_de_open_start_hhmm && hhmm < strategy_de_open_end_hhmm)
      : (hhmm >= strategy_de_open_start_hhmm || hhmm < strategy_de_open_end_hhmm);
   const bool in_us_window =
      (strategy_us_open_start_hhmm <= strategy_us_open_end_hhmm)
      ? (hhmm >= strategy_us_open_start_hhmm && hhmm < strategy_us_open_end_hhmm)
      : (hhmm >= strategy_us_open_start_hhmm || hhmm < strategy_us_open_end_hhmm);
   if(!in_de_window && !in_us_window)
      return false;

   const double setup_open = iOpen(_Symbol, _Period, 2); // perf-allowed: closed setup-candle colour check
   const double setup_close = iClose(_Symbol, _Period, 2); // perf-allowed: closed setup-candle colour check
   const double prior_open = iOpen(_Symbol, _Period, 3); // perf-allowed: bounded two-candle bearish rejection
   const double prior_close = iClose(_Symbol, _Period, 3); // perf-allowed: bounded two-candle bearish rejection
   if(setup_open <= 0.0 || setup_close <= 0.0 || prior_open <= 0.0 || prior_close <= 0.0)
      return false;
   if(setup_close >= setup_open)
      return false;
   if(prior_close < prior_open)
      return false;

   const double bb_middle = QM_BB_Middle(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_upper = QM_BB_Upper(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_lower = QM_BB_Lower(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(bb_middle <= 0.0 || bb_upper <= bb_lower)
      return false;

   const double bb_half_width = (bb_upper - bb_lower) * 0.5;
   if(bb_half_width <= 0.0 || MathAbs(setup_close - bb_middle) > bb_half_width * strategy_bb_near_basis_frac)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed breakout-bar confirmation
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: closed setup-bar resistance confirmation
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || close1 <= ema_fast || close1 <= ema_slow)
      return false;

   if(QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1) <= strategy_rsi_min)
      return false;

   if(QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1) <= strategy_adx_min)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const int resistance_bars = MathMin(MathMax(strategy_resistance_bars, 2), 20);
   const int required_touches = MathMax(strategy_resistance_touches, 1);
   const double tolerance = MathMax(point, atr * strategy_touch_tolerance_atr);
   double resistance = 0.0;
   int touch_count = 0;

   for(int candidate_shift = 2; candidate_shift < 2 + resistance_bars; ++candidate_shift)
     {
      const double candidate = iHigh(_Symbol, _Period, candidate_shift); // perf-allowed: bounded 20-bar resistance scan
      if(candidate <= 0.0)
         return false;

      int candidate_touches = 0;
      for(int touch_shift = 2; touch_shift < 2 + resistance_bars; ++touch_shift)
        {
         const double high = iHigh(_Symbol, _Period, touch_shift); // perf-allowed: bounded 20-bar resistance scan
         if(high <= 0.0)
            return false;
         if(MathAbs(high - candidate) <= tolerance)
            candidate_touches++;
        }

      if(candidate_touches >= required_touches && candidate > resistance)
        {
         resistance = candidate;
         touch_count = candidate_touches;
        }
     }

   if(touch_count < required_touches || resistance <= 0.0)
      return false;
   if(close1 <= resistance || close2 > resistance)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_tp_mult);
   if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "POST_OPEN_BB_ATR_BREAKOUT_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR SL/TP only; no trailing, partial, or break-even move.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      break;
     }

   if(!has_position)
      return false;

   const int hhmm = QM5_10165_LocalHHMM(TimeCurrent());
   const bool in_de_window =
      (strategy_de_open_start_hhmm <= strategy_de_open_end_hhmm)
      ? (hhmm >= strategy_de_open_start_hhmm && hhmm < strategy_de_open_end_hhmm)
      : (hhmm >= strategy_de_open_start_hhmm || hhmm < strategy_de_open_end_hhmm);
   const bool in_us_window =
      (strategy_us_open_start_hhmm <= strategy_us_open_end_hhmm)
      ? (hhmm >= strategy_us_open_start_hhmm && hhmm < strategy_us_open_end_hhmm)
      : (hhmm >= strategy_us_open_start_hhmm || hhmm < strategy_us_open_end_hhmm);
   return (!in_de_window && !in_us_window);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
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
