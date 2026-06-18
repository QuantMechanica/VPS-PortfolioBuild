#property strict
#property version   "5.0"
#property description "QM5_1316 tom-fps-stochastic-h1 — Tom Yeoman FPS Stochastic K/D + EMA-stack (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1316 tom-fps-stochastic-h1
// -----------------------------------------------------------------------------
// Source: Tom Yeoman "Forex Profit System" master-thread (ForexFactory thread/12503),
//   Stochastic K/D + EMA-stack-bias variant.
// Card: artifacts/cards_approved/QM5_1316_tom-fps-stochastic-h1.md (g0_status APPROVED).
//
// Mechanics (H1, closed-bar reads; shift 1 = last closed bar, shift 2 = the bar
// before it). The Stochastic K/D cross is the single trigger EVENT; everything
// else is a STATE evaluated on the same closed bar.
//
//   Entry — BUY:
//     STATE  macro bias : close[1] > EMA(200)[1]                  (FPS signature)
//     STATE  slope gate : EMA(50)[1] > EMA(200)[1]                (Tom's stack)
//     EVENT  K/D cross  : K[2] < D[2]  AND  K[1] > D[1]           (one event/bar)
//     STATE  zone origin: K[2] <= os_threshold (cross came from oversold)
//     STATE  location   : K[1] < 50 (cross fired in lower half — not a late one)
//     STATE  bar agree  : close[1] > open[1] (closed bar bullish)
//   Entry — SELL: mirror (close<EMA200, EMA50<EMA200, K[2]>D[2] & K[1]<D[1],
//                 K[2] >= ob_threshold, K[1] > 50, close[1] < open[1]).
//
//   Stop  : BUY  = min(low[1..stop_lookback]) − stop_atr_buf * ATR  (structure + ATR buffer)
//           SELL = max(high[1..stop_lookback]) + stop_atr_buf * ATR
//   TP    : ATR fallback target = tp_atr_mult * ATR from entry (set as req.tp).
//           Tom's "ride to opposite extreme" + opposite-cross + EMA200-flip exits
//           live in Strategy_ExitSignal and fire before the ATR-TP when they hit.
//
//   Exit (Strategy_ExitSignal), whichever first:
//     - Opposite Stoch cross (unconditional, no zone-of-origin requirement on exit)
//     - Stoch reaching the opposite extreme (BUY: K>=k_exit_hi, SELL: K<=k_exit_lo)
//     - EMA-200 macro-bias flip (BUY: close crosses below EMA200; SELL mirror)
//
//   Session : trade only 06:00–21:00 broker-time (Strategy_NoTradeFilter).
//   Spread  : skip only a genuinely wide spread (fail-open on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1316;
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
input int    strategy_stoch_k           = 14;    // Stochastic %K period
input int    strategy_stoch_d           = 3;     // Stochastic %D period
input int    strategy_stoch_slowing     = 3;     // Stochastic slowing
input int    strategy_ema_macro_period  = 200;   // macro-bias EMA (FPS signature)
input int    strategy_ema_slope_period  = 50;    // slope-confirmation EMA (above/below macro)
input double strategy_os_threshold      = 25.0;  // BUY: cross must originate from K <= this
input double strategy_ob_threshold      = 75.0;  // SELL: cross must originate from K >= this
input double strategy_k_exit_hi         = 80.0;  // BUY exit: K reached the upper extreme
input double strategy_k_exit_lo         = 20.0;  // SELL exit: K reached the lower extreme
input int    strategy_atr_period        = 14;    // ATR period (stop buffer + TP fallback)
input int    strategy_stop_lookback     = 3;     // structure low/high lookback (closed bars)
input double strategy_stop_atr_buf      = 1.0;   // SL = structure ± buf * ATR
input double strategy_tp_atr_mult       = 2.0;   // ATR fallback TP = mult * ATR from entry
input int    strategy_sess_start_hour   = 6;     // session start, broker time (inclusive)
input int    strategy_sess_end_hour     = 21;    // session end, broker time (exclusive)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + wide-spread guard.
// Returns TRUE to BLOCK. Fail-open on .DWX zero/negative modeled spread.
bool Strategy_NoTradeFilter()
  {
   // --- Session window in broker time (06:00–21:00 broker). ---
   // TimeCurrent() is broker time in the tester; gate on the current bar-open hour.
   const datetime broker_now = TimeCurrent();
   MqlDateTime bt;
   TimeToStruct(broker_now, bt);
   if(strategy_sess_start_hour <= strategy_sess_end_hour)
     {
      if(bt.hour < strategy_sess_start_hour || bt.hour >= strategy_sess_end_hour)
         return true; // outside session
     }
   else
     {
      // wrap-around window (not used by default, kept robust)
      if(bt.hour < strategy_sess_start_hour && bt.hour >= strategy_sess_end_hour)
         return true;
     }

   // --- Wide-spread guard relative to ATR-scaled stop distance. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_stop_atr_buf * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA stack (closed bar). ---
   const double ema_macro = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 1);
   const double ema_slope = QM_EMA(_Symbol, _Period, strategy_ema_slope_period, 1);
   if(ema_macro <= 0.0 || ema_slope <= 0.0)
      return false;

   // --- Stochastic K/D at the last two closed bars (shift 1 = newest closed,
   //     shift 2 = the bar before). The cross is K[2]vsD[2] -> K[1]vsD[1]. ---
   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(k1 <= 0.0 || d1 <= 0.0 || k2 <= 0.0 || d2 <= 0.0)
      return false;

   // --- Bar OHLC of the last closed bar (perf-allowed single-bar reads). ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed
   if(close1 <= 0.0 || open1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // ---------------------------- BUY ----------------------------
   const bool macro_bull = (close1 > ema_macro);
   const bool slope_bull = (ema_slope > ema_macro);
   const bool cross_up   = (k2 < d2 && k1 > d1);          // fresh K-over-D EVENT
   const bool from_os    = (k2 <= strategy_os_threshold); // cross originated oversold
   const bool loc_lower  = (k1 < 50.0);                   // fired in lower half
   const bool bar_bull   = (close1 > open1);              // closed bar agreement

   if(macro_bull && slope_bull && cross_up && from_os && loc_lower && bar_bull)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Structure low over the lookback, then push the stop one ATR further down.
      const double struct_sl = QM_StopStructure(_Symbol, QM_BUY, entry, strategy_stop_lookback);
      if(struct_sl <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, struct_sl - strategy_stop_atr_buf * atr_value);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fps_stoch_long";
      return true;
     }

   // ---------------------------- SELL ---------------------------
   const bool macro_bear = (close1 < ema_macro);
   const bool slope_bear = (ema_slope < ema_macro);
   const bool cross_dn   = (k2 > d2 && k1 < d1);          // fresh K-under-D EVENT
   const bool from_ob    = (k2 >= strategy_ob_threshold); // cross originated overbought
   const bool loc_upper  = (k1 > 50.0);                   // fired in upper half
   const bool bar_bear   = (close1 < open1);              // closed bar agreement

   if(macro_bear && slope_bear && cross_dn && from_ob && loc_upper && bar_bear)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double struct_sl = QM_StopStructure(_Symbol, QM_SELL, entry, strategy_stop_lookback);
      if(struct_sl <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, struct_sl + strategy_stop_atr_buf * atr_value);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fps_stoch_short";
      return true;
     }

   return false;
  }

// Fixed ATR-TP + structure SL handle the protective side; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits (whichever fires first), evaluated on the closed bar:
//   - opposite Stoch K/D cross (unconditional)
//   - Stoch reaching the opposite extreme (BUY: K>=hi, SELL: K<=lo)
//   - EMA-200 macro-bias flip (BUY: close crosses below EMA200; SELL mirror)
// Direction taken from the live open position for this EA's magic.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine open direction.
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
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(k1 <= 0.0 || d1 <= 0.0 || k2 <= 0.0 || d2 <= 0.0)
      return false;

   const double ema_macro_now  = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 1);
   const double ema_macro_prev = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 2);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
   if(ema_macro_now <= 0.0 || ema_macro_prev <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   if(is_long)
     {
      const bool opp_cross   = (k2 > d2 && k1 < d1);                 // K crossed below D
      const bool extreme_hit = (k1 >= strategy_k_exit_hi);           // rode to upper extreme
      const bool bias_flip   = (close2 >= ema_macro_prev && close1 < ema_macro_now); // close crossed below EMA200
      return (opp_cross || extreme_hit || bias_flip);
     }

   // is_short
   const bool opp_cross   = (k2 < d2 && k1 > d1);                    // K crossed above D
   const bool extreme_hit = (k1 <= strategy_k_exit_lo);              // rode to lower extreme
   const bool bias_flip   = (close2 <= ema_macro_prev && close1 > ema_macro_now); // close crossed above EMA200
   return (opp_cross || extreme_hit || bias_flip);
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
