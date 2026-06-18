#property strict
#property version   "5.0"
#property description "QM5_1274 bressert-double-stochastic-h1 — Bressert double stochastic pullback (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1274 bressert-double-stochastic-h1
// -----------------------------------------------------------------------------
// Source: ForexFactory Trading Systems "Bressert Double-Stochastic" cluster +
//   Walter Bressert, "The Power of Oscillator/Cycle Combinations" (Wiley 1991).
// Card: artifacts/cards_approved/QM5_1274_bressert-double-stochastic-h1.md
//       (g0_status APPROVED, source_id 6e967762-b26d-59a3-b076-35c17f2e7c36).
//
// Realization (closed-bar reads at shift 1/2; ONE cross as the trigger EVENT):
//   Bressert's "double stochastic" pairs a slow stochastic (the cycle/regime
//   STATE — which OB/OS zone we are in) with a fast stochastic whose K/D cross
//   out of that zone is the trigger EVENT. MQL5 has no iStochasticOnArray, and
//   modelling a literal Stoch-of-Stoch as a second cross would risk the
//   two-cross-same-bar zero-trade trap. So per the build directive we use
//   QM_Stoch_K/QM_Stoch_D TWICE with different period inputs:
//     SLOW Stoch(13,5,3)  -> regime STATE: was K in OB/OS zone at the setup bar.
//     FAST Stoch(8,3,3)   -> trigger EVENT: K crosses D (ONE event/bar).
//   EMA(200) gates direction.
//
//   LONG  (all on the last-closed H1 bar):
//     1. FAST K/D bullish cross: fastK[2] <= fastD[2] AND fastK[1] > fastD[1].
//     2. Cross fired out of oversold: slowK[2] < os_level (regime STATE).
//     3. close[1] > EMA(200)  (trend filter).
//   SHORT: mirror — fast bearish cross, slowK[2] > ob_level, close[1] < EMA.
//
//   Stop : entry -/+ sl_atr_mult * ATR(period).
//   Take : RR multiple of the stop distance (tp_rr).
//   Exit : opposite-direction FAST K/D cross out of the opposite extreme zone
//          -> close manually at next bar.
//   One position per symbol per magic (HR14).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1274;
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
// SLOW stochastic = regime STATE (Bressert original raw periods 13/5/3).
input int    strategy_slow_k_period     = 13;    // slow Stoch %K period
input int    strategy_slow_d_period     = 5;     // slow Stoch %D period
input int    strategy_slow_slowing      = 3;     // slow Stoch slowing
// FAST stochastic = trigger EVENT (Bressert smoothed periods 8/3/3).
input int    strategy_fast_k_period     = 8;     // fast Stoch %K period
input int    strategy_fast_d_period     = 3;     // fast Stoch %D period
input int    strategy_fast_slowing      = 3;     // fast Stoch slowing
input double strategy_oversold_level    = 20.0;  // slow %K oversold threshold
input double strategy_overbought_level  = 80.0;  // slow %K overbought threshold
input int    strategy_ema_period        = 200;   // EMA trend-bias period
input int    strategy_atr_period        = 14;    // ATR period (stop sizing)
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR
input double strategy_tp_rr             = 2.0;   // take-profit = RR * stop distance
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- FAST stochastic (trigger EVENT) at shift 1 and 2 ---
   const double fastK1 = QM_Stoch_K(_Symbol, _Period, strategy_fast_k_period,
                                    strategy_fast_d_period, strategy_fast_slowing, 1);
   const double fastD1 = QM_Stoch_D(_Symbol, _Period, strategy_fast_k_period,
                                    strategy_fast_d_period, strategy_fast_slowing, 1);
   const double fastK2 = QM_Stoch_K(_Symbol, _Period, strategy_fast_k_period,
                                    strategy_fast_d_period, strategy_fast_slowing, 2);
   const double fastD2 = QM_Stoch_D(_Symbol, _Period, strategy_fast_k_period,
                                    strategy_fast_d_period, strategy_fast_slowing, 2);
   if(fastK1 <= 0.0 || fastD1 <= 0.0 || fastK2 <= 0.0 || fastD2 <= 0.0)
      return false;

   // --- SLOW stochastic (regime STATE) — zone at the setup bar (shift 2) ---
   const double slowK2 = QM_Stoch_K(_Symbol, _Period, strategy_slow_k_period,
                                    strategy_slow_d_period, strategy_slow_slowing, 2);
   if(slowK2 <= 0.0)
      return false;

   // --- EMA(200) trend bias (closed bar) ---
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // The fast K/D cross is the ONE trigger EVENT; the slow-zone membership is a
   // STATE observed at the setup bar — never a second same-bar cross.
   const bool bull_cross = (fastK2 <= fastD2 && fastK1 > fastD1);
   const bool bear_cross = (fastK2 >= fastD2 && fastK1 < fastD1);

   bool is_long = false;
   bool is_short = false;

   if(bull_cross && slowK2 < strategy_oversold_level && close1 > ema)
      is_long = true;
   else if(bear_cross && slowK2 > strategy_overbought_level && close1 < ema)
      is_short = true;

   if(!is_long && !is_short)
      return false;

   const double entry = (is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const QM_OrderType ot = (is_long ? QM_BUY : QM_SELL);
   const double sl = QM_StopATRFromValue(_Symbol, ot, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, ot, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (is_long ? "bressert_dss_long" : "bressert_dss_short");
   return true;
  }

// No active management beyond the fixed ATR stop / RR target. The defensive
// opposite-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite-direction FAST K/D cross out of the opposite extreme
// zone, evaluated on the last-closed H1 bar (shift 1/2). One event per bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fastK1 = QM_Stoch_K(_Symbol, _Period, strategy_fast_k_period,
                                    strategy_fast_d_period, strategy_fast_slowing, 1);
   const double fastD1 = QM_Stoch_D(_Symbol, _Period, strategy_fast_k_period,
                                    strategy_fast_d_period, strategy_fast_slowing, 1);
   const double fastK2 = QM_Stoch_K(_Symbol, _Period, strategy_fast_k_period,
                                    strategy_fast_d_period, strategy_fast_slowing, 2);
   const double fastD2 = QM_Stoch_D(_Symbol, _Period, strategy_fast_k_period,
                                    strategy_fast_d_period, strategy_fast_slowing, 2);
   if(fastK1 <= 0.0 || fastD1 <= 0.0 || fastK2 <= 0.0 || fastD2 <= 0.0)
      return false;

   const double slowK2 = QM_Stoch_K(_Symbol, _Period, strategy_slow_k_period,
                                    strategy_slow_d_period, strategy_slow_slowing, 2);
   if(slowK2 <= 0.0)
      return false;

   const bool bull_cross = (fastK2 <= fastD2 && fastK1 > fastD1);
   const bool bear_cross = (fastK2 >= fastD2 && fastK1 < fastD1);

   // Determine the current open direction for this magic.
   bool have_long = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Long closes on a bearish cross out of overbought; short on bullish cross
   // out of oversold.
   if(have_long && bear_cross && slowK2 > strategy_overbought_level)
      return true;
   if(have_short && bull_cross && slowK2 < strategy_oversold_level)
      return true;

   return false;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
