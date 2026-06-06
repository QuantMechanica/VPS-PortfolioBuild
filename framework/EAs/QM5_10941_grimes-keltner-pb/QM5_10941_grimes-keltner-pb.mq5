#property strict
#property version   "5.0"
#property description "QM5_10941 Grimes Keltner Pullback Continuation"

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
input int    qm_ea_id                   = 10941;
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
input int    strategy_ema_period        = 20;
input int    strategy_atr_period        = 20;
input int    strategy_atr_filter_period = 100;
input double strategy_keltner_atr_mult  = 2.25;
input int    strategy_setup_max_bars    = 10;
input int    strategy_ema_slope_bars    = 5;
input double strategy_atr_filter_mult   = 0.70;
input double strategy_stop_atr_mult     = 2.0;
input double strategy_max_stop_atr_mult = 3.0;
input double strategy_rr_target         = 2.0;
input int    strategy_time_exit_bars    = 12;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: framework handles time, spread/broker, news, and Friday gates.
   // Card adds a dead-market volatility filter: ATR(20) must be at least 0.7 * ATR(100).
   if(_Period != PERIOD_D1)
      return true;

   if(strategy_atr_period <= 0 ||
      strategy_atr_filter_period <= strategy_atr_period ||
      strategy_atr_filter_mult <= 0.0)
      return true;

   const double atr_fast = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double atr_slow = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_filter_period, 1);
   if(atr_fast <= 0.0 || atr_slow <= 0.0)
      return true;

   return (atr_fast < strategy_atr_filter_mult * atr_slow);
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

   if(_Period != PERIOD_D1)
      return false;

   if(strategy_ema_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_keltner_atr_mult <= 0.0 ||
      strategy_setup_max_bars < 1 ||
      strategy_ema_slope_bars < 1 ||
      strategy_stop_atr_mult <= 0.0 ||
      strategy_max_stop_atr_mult <= strategy_stop_atr_mult ||
      strategy_rr_target <= 0.0)
      return false;

   const int bars_needed = strategy_setup_max_bars + strategy_ema_slope_bars + 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: one bounded closed-bar OHLC snapshot on the framework new-bar path.
   if(CopyRates(_Symbol, PERIOD_D1, 0, bars_needed, rates) < bars_needed)
      return false;

   const double ema_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   const double ema_prior_to_touch = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 2);
   const double ema_slope_ref = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1 + strategy_ema_slope_bars);
   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ema_1 <= 0.0 || ema_prior_to_touch <= 0.0 || ema_slope_ref <= 0.0 || atr_1 <= 0.0)
      return false;

   const double upper_1 = ema_1 + strategy_keltner_atr_mult * atr_1;
   const double lower_1 = ema_1 - strategy_keltner_atr_mult * atr_1;
   const bool touch_long = (rates[1].low <= ema_prior_to_touch);
   const bool touch_short = (rates[1].high >= ema_prior_to_touch);
   const bool slope_up = (ema_1 > ema_slope_ref);
   const bool slope_down = (ema_1 < ema_slope_ref);

   bool long_setup = false;
   bool short_setup = false;

   if(touch_long && slope_up)
     {
      for(int thrust_shift = 2; thrust_shift <= strategy_setup_max_bars + 1; ++thrust_shift)
        {
         const double ema_thrust = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, thrust_shift);
         const double atr_thrust = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, thrust_shift);
         if(ema_thrust <= 0.0 || atr_thrust <= 0.0)
            continue;

         const double upper_thrust = ema_thrust + strategy_keltner_atr_mult * atr_thrust;
         if(rates[thrust_shift].close <= upper_thrust)
            continue;

         bool stayed_above_ema = true;
         for(int s = thrust_shift - 1; s >= 1; --s)
           {
            const double ema_s = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, s);
            if(ema_s <= 0.0 || rates[s].close < ema_s)
              {
               stayed_above_ema = false;
               break;
              }
           }

         if(stayed_above_ema)
           {
            long_setup = true;
            break;
           }
        }
     }

   if(touch_short && slope_down)
     {
      for(int thrust_shift = 2; thrust_shift <= strategy_setup_max_bars + 1; ++thrust_shift)
        {
         const double ema_thrust = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, thrust_shift);
         const double atr_thrust = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, thrust_shift);
         if(ema_thrust <= 0.0 || atr_thrust <= 0.0)
            continue;

         const double lower_thrust = ema_thrust - strategy_keltner_atr_mult * atr_thrust;
         if(rates[thrust_shift].close >= lower_thrust)
            continue;

         bool stayed_below_ema = true;
         for(int s = thrust_shift - 1; s >= 1; --s)
           {
            const double ema_s = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, s);
            if(ema_s <= 0.0 || rates[s].close > ema_s)
              {
               stayed_below_ema = false;
               break;
              }
           }

         if(stayed_below_ema)
           {
            short_setup = true;
            break;
           }
        }
     }

   if(long_setup)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double sl = MathMin(rates[1].low, entry - strategy_stop_atr_mult * atr_1);
      const double stop_dist = entry - sl;
      if(sl <= 0.0 || stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr_mult * atr_1)
         return false;

      const double rr_tp = entry + strategy_rr_target * stop_dist;
      const double keltner_tp = (upper_1 > entry) ? upper_1 : rr_tp;
      req.type = QM_BUY;
      req.price = entry;
      req.sl = sl;
      req.tp = MathMin(rr_tp, keltner_tp);
      req.reason = "QM5_10941_KELTNER_PB_LONG";
      return (req.tp > req.price);
     }

   if(short_setup)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double sl = MathMax(rates[1].high, entry + strategy_stop_atr_mult * atr_1);
      const double stop_dist = sl - entry;
      if(sl <= 0.0 || stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr_mult * atr_1)
         return false;

      const double rr_tp = entry - strategy_rr_target * stop_dist;
      const double keltner_tp = (lower_1 < entry) ? lower_1 : rr_tp;
      req.type = QM_SELL;
      req.price = entry;
      req.sl = sl;
      req.tp = MathMax(rr_tp, keltner_tp);
      req.reason = "QM5_10941_KELTNER_PB_SHORT";
      return (req.tp > 0.0 && req.tp < req.price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(strategy_ema_period <= 0 || strategy_time_exit_bars <= 0)
      return false;

   // perf-allowed: O(1) closed D1 close read for the card's close-against-EMA exit.
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);
   const double ema_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   if(close_1 <= 0.0 || ema_1 <= 0.0)
      return false;

   const int hold_seconds = strategy_time_exit_bars * PeriodSeconds(PERIOD_D1);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close_1 < ema_1)
         return true;
      if(ptype == POSITION_TYPE_SELL && close_1 > ema_1)
         return true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && TimeCurrent() - opened >= hold_seconds)
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
