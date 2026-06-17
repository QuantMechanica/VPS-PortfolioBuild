#property strict
#property version   "5.0"
#property description "QM5_11002 the5ers-m1-ema-stoch — M1 EMA(50/100) + Stochastic pullback scalper"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11002 the5ers-m1-ema-stoch
// -----------------------------------------------------------------------------
// Source: The5ers blog "1 Minute Scalping Strategy" (the5ers.com/1-minute-scalping-trading/).
// Card: artifacts/cards_approved/QM5_11002_the5ers-m1-ema-stoch.md (g0_status APPROVED).
//
// Timeframe: M1 (source timeframe). Closed-bar reads at shift 1 (last closed),
// shift 2 (prior closed). NOTE: factory has known M1 history gaps (2017-2022)
// for some symbols — that is a downstream data concern, not a build concern.
//
// Mechanics (closed-bar, both directions, one position per magic):
//   Regime STATE  : long  -> ema_fast[1] > ema_slow[1] AND an EMA cross-up
//                            occurred within the last `cross_lookback` bars.
//                   short -> ema_fast[1] < ema_slow[1].
//   Pullback STATE: |close[1] - ema_fast[1]| <= pullback_atr_frac * ATR[1]  OR
//                   long  -> low[1]  <= max(ema_fast[1], ema_slow[1])
//                   short -> high[1] >= min(ema_fast[1], ema_slow[1])
//   Trigger EVENT : long  -> stoch_k[2] <= 20 AND stoch_k[1] > 20  (cross up)
//                   short -> stoch_k[2] >= 80 AND stoch_k[1] < 80  (cross down)
//                   The Stochastic cross is the SINGLE entry event; EMA + pullback
//                   are states (avoids the .DWX "two cross events same bar" trap).
//   Stop          : farther (more protective) of the prior `swing_lookback`-bar
//                   structural swing low/high and a 1.0*ATR minimum distance.
//   Take profit   : fixed `tp_pips` pips (default 10; P3 sweep {8,10,12}).
//   Exits         : EMA(50) recrosses EMA(100) against the trade, OR Stochastic K
//                   crosses back through 50 against the trade, OR time-stop after
//                   `time_stop_bars` M1 bars.
//   Filters       : trade only 07:00-17:00 broker time (London+NY liquid window);
//                   skip if spread > spread_pct_of_tp of the TP distance
//                   (fail-open on .DWX zero modeled spread); skip dead-tick scalps
//                   when ATR(14) < atr_floor_mult * a slow M1 ATR baseline.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11002;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period   = 50;     // fast EMA (EMA 50)
input int    strategy_ema_slow_period   = 100;    // slow EMA (EMA 100)
input int    strategy_stoch_k           = 14;     // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slow        = 3;      // Stochastic slowing
input double strategy_stoch_lo          = 20.0;   // long  trigger: K crosses up through this
input double strategy_stoch_hi          = 80.0;   // short trigger: K crosses down through this
input double strategy_stoch_mid         = 50.0;   // exit:  K recross of this midline
input int    strategy_cross_lookback    = 10;     // bars to confirm a recent EMA cross-up (long)
input double strategy_pullback_atr_frac = 0.35;   // pullback zone width as fraction of ATR
input int    strategy_atr_period        = 14;     // ATR period (pullback / SL minimum / floor)
input int    strategy_atr_baseline      = 200;    // slow M1 ATR baseline (median proxy)
input double strategy_atr_floor_mult    = 0.5;    // skip if ATR(14) < mult * baseline ATR
input int    strategy_swing_lookback    = 10;     // prior bars for structural swing SL
input double strategy_sl_atr_min_mult   = 1.0;    // minimum SL distance = mult * ATR
input int    strategy_tp_pips           = 10;     // fixed take-profit in pips (P3 sweep 8/10/12)
input int    strategy_time_stop_bars    = 30;     // close after N M1 bars if no TP/SL
input int    strategy_session_start_h   = 7;      // London+NY window start (broker time)
input int    strategy_session_end_h     = 17;     // London+NY window end (broker time)
input double strategy_spread_pct_of_tp  = 15.0;   // skip if spread > this % of TP distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: liquid-session window, spread cap, dead-tick ATR floor.
// All checks fail-open on .DWX (zero modeled spread, missing warmup) so they never
// silently block every trade.
bool Strategy_NoTradeFilter()
  {
   // --- Liquid session window in BROKER time (card states 07:00-17:00 broker). ---
   const datetime broker_now = TimeCurrent();
   if(QM_Sig_Session(broker_now, strategy_session_start_h, strategy_session_end_h) != 1)
      return true; // outside liquid window — block

   // --- Dead-tick ATR floor: skip when current ATR is far below its slow baseline. ---
   const double atr_now      = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double atr_baseline = QM_ATR(_Symbol, _Period, strategy_atr_baseline, 1);
   if(atr_now > 0.0 && atr_baseline > 0.0 &&
      atr_now < strategy_atr_floor_mult * atr_baseline)
      return true; // dead-tick regime — block

   // --- Spread cap vs TP distance. Fail-open on .DWX zero/negative modeled spread. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double tp_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
      if(tp_distance > 0.0)
        {
         const double spread = ask - bid;
         if(spread > (strategy_spread_pct_of_tp / 100.0) * tp_distance)
            return true; // genuinely wide spread — block
        }
     }

   return false;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMAs at the two most recent closed bars. ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0)
      return false;

   // --- ATR for pullback width + SL minimum. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Stochastic %K at the two most recent closed bars (the trigger event). ---
   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   if(k1 <= 0.0 || k2 <= 0.0)
      return false;

   // --- Prior closed-bar OHLC for the pullback-zone band test. ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   // Pullback zone (shared band test): close hugged the fast EMA, OR price wicked
   // into the EMA band on the correct side.
   const double band_proximity = MathAbs(close1 - ema_fast_1);
   const double pullback_width  = strategy_pullback_atr_frac * atr_value;
   const double ema_band_top    = MathMax(ema_fast_1, ema_slow_1);
   const double ema_band_bot    = MathMin(ema_fast_1, ema_slow_1);

   // ------------------------------- LONG ------------------------------------
   if(ema_fast_1 > ema_slow_1)
     {
      // Regime confirmation: a fresh EMA cross-up within the last N closed bars.
      bool recent_cross_up = false;
      const int last_shift = strategy_cross_lookback + 1; // need shift s+1 for the prior bar
      for(int s = 1; s <= strategy_cross_lookback; ++s)
        {
         const double f_s  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s);
         const double sl_s = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
         const double f_p  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s + 1);
         const double sl_p = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s + 1);
         if(f_s <= 0.0 || sl_s <= 0.0 || f_p <= 0.0 || sl_p <= 0.0)
            continue;
         if(f_p <= sl_p && f_s > sl_s)
           {
            recent_cross_up = true;
            break;
           }
        }
      if(!recent_cross_up)
         return false;

      // Pullback STATE.
      const bool pulled_back = (band_proximity <= pullback_width) || (low1 <= ema_band_top);
      if(!pulled_back)
         return false;

      // Trigger EVENT: Stochastic K crosses up through the low threshold.
      const bool stoch_cross_up = (k2 <= strategy_stoch_lo && k1 > strategy_stoch_lo);
      if(!stoch_cross_up)
         return false;

      // Build the long entry. Framework sizes lots (no lots field).
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // SL = farther of structural swing low and the 1.0*ATR minimum distance.
      double sl_struct = QM_StopStructure(_Symbol, QM_BUY, entry, strategy_swing_lookback);
      const double sl_atr_min = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_min_mult);
      double sl = sl_atr_min;
      if(sl_struct > 0.0 && sl_struct < sl_atr_min) // lower stop = farther for a long
         sl = sl_struct;
      if(sl <= 0.0 || sl >= entry)
         return false;

      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(tp <= 0.0 || tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "the5ers_m1_long";
      return true;
     }

   // ------------------------------- SHORT -----------------------------------
   if(ema_fast_1 < ema_slow_1)
     {
      // Pullback STATE.
      const bool pulled_back = (band_proximity <= pullback_width) || (high1 >= ema_band_bot);
      if(!pulled_back)
         return false;

      // Trigger EVENT: Stochastic K crosses down through the high threshold.
      const bool stoch_cross_dn = (k2 >= strategy_stoch_hi && k1 < strategy_stoch_hi);
      if(!stoch_cross_dn)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      // SL = farther of structural swing high and the 1.0*ATR minimum distance.
      double sl_struct = QM_StopStructure(_Symbol, QM_SELL, entry, strategy_swing_lookback);
      const double sl_atr_min = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_min_mult);
      double sl = sl_atr_min;
      if(sl_struct > 0.0 && sl_struct > sl_atr_min) // higher stop = farther for a short
         sl = sl_struct;
      if(sl <= 0.0 || sl <= entry)
         return false;

      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(tp <= 0.0 || tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "the5ers_m1_short";
      return true;
     }

   return false;
  }

// No active trailing/break-even management beyond the fixed SL/TP. Discretionary
// exits (EMA recross / Stoch midline recross / time-stop) live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: EMA recross against the trade, Stochastic K recross of the
// midline against the trade, or the time-stop. Evaluated per closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current open-position direction (one position per magic).
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;

      // --- Time-stop: close after N M1 bars elapsed since entry. ---
      const datetime opened   = (datetime)PositionGetInteger(POSITION_TIME);
      const datetime bar_open = iTime(_Symbol, _Period, 0); // current (forming) bar open
      if(opened > 0 && bar_open > opened)
        {
         const int bars_held = (int)((bar_open - opened) / (PeriodSeconds(_Period)));
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }
     }
   if(!is_long && !is_short)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   if(k1 <= 0.0 || k2 <= 0.0)
      return false;

   if(is_long)
     {
      // EMA(50) closes below EMA(100), or Stoch K crosses back below the midline.
      const bool ema_recross   = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1);
      const bool stoch_recross = (k2 >= strategy_stoch_mid && k1 < strategy_stoch_mid);
      return (ema_recross || stoch_recross);
     }

   // short
   const bool ema_recross   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1);
   const bool stoch_recross = (k2 <= strategy_stoch_mid && k1 > strategy_stoch_mid);
   return (ema_recross || stoch_recross);
  }

// Defer to the central news filter.
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

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
