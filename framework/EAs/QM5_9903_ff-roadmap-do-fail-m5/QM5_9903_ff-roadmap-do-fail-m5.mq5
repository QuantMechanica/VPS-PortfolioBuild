#property strict
#property version   "5.0"
#property description "QM5_9903 ForexFactory Roadmap Daily-Open Failure M5"

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
input int    qm_ea_id                   = 9903;
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
input int    strategy_atr_period          = 14;
input int    strategy_ema_period          = 8;
input int    strategy_rsi_period          = 14;
input int    strategy_sma_period          = 200;
input int    strategy_adr_days            = 14;
input int    strategy_session_start_hour  = 7;
input int    strategy_session_end_hour    = 17;
input double strategy_failure_atr_mult    = 0.25;
input int    strategy_failure_window_bars = 12;
input int    strategy_retest_window_bars  = 6;
input double strategy_retest_atr_mult     = 0.15;
input double strategy_sl_atr_buffer       = 0.25;
input double strategy_stop_min_atr        = 0.5;
input double strategy_stop_max_atr        = 2.0;
input double strategy_tp_r_multiple       = 1.8;
input double strategy_min_room_r          = 1.5;
input double strategy_sma_stack_atr_mult  = 0.20;
input double strategy_max_spread_atr_pct  = 12.0;
input int    strategy_time_stop_bars      = 30;

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

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return true;

   const int hour = dt.hour;
   bool session_ok = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         session_ok = (hour >= strategy_session_start_hour && hour < strategy_session_end_hour);
      else
         session_ok = (hour >= strategy_session_start_hour || hour < strategy_session_end_hour);
     }
   if(!session_ok)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask < bid)
      return true;
   if((ask - bid) > atr * strategy_max_spread_atr_pct / 100.0)
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

   static int      setup_state = 0;       // 0 none, 1 waiting reclaim, 2 waiting retest
   static int      setup_dir = 0;         // +1 long, -1 short
   static int      setup_age = 0;
   static int      retest_age = 0;
   static datetime setup_day = 0;
   static double   setup_swing_high = 0.0;
   static double   setup_swing_low = 0.0;

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

   if(Strategy_NoTradeFilter())
      return false;

   if(strategy_atr_period <= 0 || strategy_ema_period <= 0 ||
      strategy_rsi_period <= 0 || strategy_sma_period <= 0 ||
      strategy_failure_window_bars <= 0 || strategy_retest_window_bars <= 0 ||
      strategy_time_stop_bars <= 0)
      return false;

   // perf-allowed: single D1/M5 OHLC reads for daily-open failure and yesterday-level logic; EntrySignal is framework new-bar gated.
   const datetime day_time = iTime(_Symbol, PERIOD_D1, 0);      // perf-allowed
   const double daily_open = iOpen(_Symbol, PERIOD_D1, 0);      // perf-allowed
   const double yesterday_high = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed
   const double yesterday_low = iLow(_Symbol, PERIOD_D1, 1);    // perf-allowed
   const double open1 = iOpen(_Symbol, PERIOD_M5, 1);           // perf-allowed
   const double high1 = iHigh(_Symbol, PERIOD_M5, 1);           // perf-allowed
   const double low1 = iLow(_Symbol, PERIOD_M5, 1);             // perf-allowed
   const double close1 = iClose(_Symbol, PERIOD_M5, 1);         // perf-allowed
   if(day_time <= 0 || daily_open <= 0.0 || yesterday_high <= 0.0 || yesterday_low <= 0.0 ||
      open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   if(setup_day != day_time)
     {
      setup_state = 0;
      setup_dir = 0;
      setup_age = 0;
      retest_age = 0;
      setup_swing_high = 0.0;
      setup_swing_low = 0.0;
      setup_day = day_time;
     }

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double ema_close = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1, PRICE_CLOSE);
   const double sma200 = QM_SMA(_Symbol, PERIOD_M5, strategy_sma_period, 1, PRICE_CLOSE);
   const double rsi = QM_RSI(_Symbol, PERIOD_M5, strategy_rsi_period, 1, PRICE_CLOSE);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || ema_close <= 0.0 || sma200 <= 0.0 || rsi <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;
   if(MathAbs(daily_open - sma200) <= strategy_sma_stack_atr_mult * atr)
      return false;

   double adr = 0.0;
   int adr_count = 0;
   for(int d = 1; d <= strategy_adr_days; ++d)
     {
      const double dh = iHigh(_Symbol, PERIOD_D1, d); // perf-allowed: bounded ADR loop inside new-bar gated EntrySignal
      const double dl = iLow(_Symbol, PERIOD_D1, d);  // perf-allowed: bounded ADR loop inside new-bar gated EntrySignal
      if(dh <= 0.0 || dl <= 0.0 || dh <= dl)
         continue;
      adr += (dh - dl);
      adr_count++;
     }
   if(adr_count <= 0)
      return false;
   adr /= (double)adr_count;
   const double adr_upper = daily_open + adr;
   const double adr_lower = daily_open - adr;

   if(setup_state == 0)
     {
      if(close1 > daily_open + strategy_failure_atr_mult * atr)
        {
         setup_state = 1;
         setup_dir = -1;
         setup_age = 0;
         retest_age = 0;
         setup_swing_high = high1;
         setup_swing_low = low1;
        }
      else if(close1 < daily_open - strategy_failure_atr_mult * atr)
        {
         setup_state = 1;
         setup_dir = +1;
         setup_age = 0;
         retest_age = 0;
         setup_swing_high = high1;
         setup_swing_low = low1;
        }
      return false;
     }

   setup_swing_high = MathMax(setup_swing_high, high1);
   setup_swing_low = (setup_swing_low <= 0.0) ? low1 : MathMin(setup_swing_low, low1);

   if(setup_state == 1)
     {
      setup_age++;
      if(setup_age > strategy_failure_window_bars)
        {
         setup_state = 0;
         setup_dir = 0;
         return false;
        }
      if((setup_dir < 0 && close1 < daily_open) || (setup_dir > 0 && close1 > daily_open))
        {
         setup_state = 2;
         retest_age = 0;
        }
      return false;
     }

   if(setup_state != 2)
      return false;

   retest_age++;
   if(retest_age > strategy_retest_window_bars)
     {
      setup_state = 0;
      setup_dir = 0;
      return false;
     }

   const bool short_retest = (setup_dir < 0 &&
                              high1 >= daily_open - strategy_retest_atr_mult * atr &&
                              close1 < daily_open &&
                              close1 < open1 &&
                              close1 < ema_close &&
                              rsi <= 45.0);
   const bool long_retest = (setup_dir > 0 &&
                             low1 <= daily_open + strategy_retest_atr_mult * atr &&
                             close1 > daily_open &&
                             close1 > open1 &&
                             close1 > ema_close &&
                             rsi >= 55.0);
   if(!short_retest && !long_retest)
      return false;

   const bool want_short = short_retest;
   const double entry = want_short ? bid : ask;
   const double sl = want_short ? (setup_swing_high + strategy_sl_atr_buffer * atr)
                                : (setup_swing_low - strategy_sl_atr_buffer * atr);
   if(entry <= 0.0 || sl <= 0.0)
      return false;
   const double risk = MathAbs(entry - sl);
   if(risk < strategy_stop_min_atr * atr || risk > strategy_stop_max_atr * atr)
      return false;

   if(want_short)
     {
      if(sl <= entry)
         return false;
      double support = 0.0;
      if(yesterday_low < entry)
         support = yesterday_low;
      if(adr_lower < entry && adr_lower > support)
         support = adr_lower;
      if(support <= 0.0 || (entry - support) < strategy_min_room_r * risk)
         return false;

      double tp = entry - strategy_tp_r_multiple * risk;
      if(yesterday_low < entry && yesterday_low > tp)
         tp = yesterday_low;
      if(adr_lower < entry && adr_lower > tp)
         tp = adr_lower;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FF_ROADMAP_DO_FAIL_SHORT";
     }
   else
     {
      if(sl >= entry)
         return false;
      double resistance = DBL_MAX;
      if(yesterday_high > entry)
         resistance = yesterday_high;
      if(adr_upper > entry && adr_upper < resistance)
         resistance = adr_upper;
      if(resistance == DBL_MAX || (resistance - entry) < strategy_min_room_r * risk)
         return false;

      double tp = entry + strategy_tp_r_multiple * risk;
      if(yesterday_high > entry && yesterday_high < tp)
         tp = yesterday_high;
      if(adr_upper > entry && adr_upper < tp)
         tp = adr_upper;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FF_ROADMAP_DO_FAIL_LONG";
     }

   setup_state = 0;
   setup_dir = 0;
   return (req.tp > 0.0 && MathAbs(req.tp - entry) > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, scale-in, or scale-out logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_time_stop_bars <= 0)
      return false;

   // perf-allowed: closed M5/D1 reads for strategy exit checks; bounded O(1) per tick.
   const double daily_open = iOpen(_Symbol, PERIOD_D1, 0);       // perf-allowed
   const double close1 = iClose(_Symbol, PERIOD_M5, 1);          // perf-allowed
   const double ema_close = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1, PRICE_CLOSE);
   const datetime now = TimeCurrent();
   const int max_hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_M5);
   if(daily_open <= 0.0 || close1 <= 0.0 || ema_close <= 0.0)
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(now - open_time >= max_hold_seconds)
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         if(close1 < daily_open || ema_close < daily_open)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(close1 > daily_open || ema_close > daily_open)
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
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9903_ff-roadmap-do-fail-m5\"}");
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
