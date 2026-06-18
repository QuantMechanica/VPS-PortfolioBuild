#property strict
#property version   "5.0"
#property description "QM5_11634 fsr-double-stoch21-9-h1 — Double Stochastic (slow 21/9/9 zone-bias + fast 9/3/3 cross trigger, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11634 fsr-double-stoch21-9-h1
// -----------------------------------------------------------------------------
// Source: forex-strategies-revealed.com "Complex Forex Strategy #6 (Double
//   Stochastic)". Card: artifacts/cards_approved/QM5_11634_fsr-double-stoch21-9-h1.md
//   (g0_status APPROVED). Source id 5e9e8c4d-0c88-5dc6-a550-b3b070a5b44d.
//
// Mechanics (closed-bar reads at shift 1/2; H1):
//   Slow Stoch(21,9,9)  = DIRECTION/ZONE STATE.
//        long bias  : slow %K > slow %D  AND slow %K not overbought (< ob_level)
//        short bias : slow %K < slow %D  AND slow %K not oversold  (> os_level)
//   Fast Stoch(9,3,3)   = single TRIGGER EVENT (one fresh cross per bar).
//        long  : fast %K crosses ABOVE fast %D  (prev <= , now > )
//        short : fast %K crosses BELOW fast %D  (prev >= , now < )
//   Entry  : bias STATE agrees with the fast-cross EVENT.
//   Exit   : fast Stoch crosses in the opposite direction (reversal signal).
//   Stop   : entry +/- sl_atr_mult * ATR(atr_period).  No fixed TP by source;
//            an optional RR target (tp_rr) is provided, 0 = no TP.
//
// Two-cross-same-bar trap avoided: ONLY the fast %K/%D cross is an EVENT. The
// slow Stoch contributes STATE (current K-vs-D ordering + zone), never a second
// same-bar cross requirement. So exactly one fresh crossover must coincide with
// a standing directional state.
//
// .DWX invariants honoured: spread guard fails OPEN on zero modeled spread; no
// swap gate; QM_IsNewBar consumed once by the framework OnTick wiring.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11634;
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
// Slow Stochastic = direction / zone STATE (card: Stochastic(21,9,9)).
input int    slow_stoch_k_period        = 21;    // slow %K period
input int    slow_stoch_d_period        = 9;     // slow %D period
input int    slow_stoch_slowing         = 9;     // slow %K slowing
input double slow_overbought_level      = 80.0;  // suppress long bias when slow %K >= this
input double slow_oversold_level        = 20.0;  // suppress short bias when slow %K <= this
// Fast Stochastic = single TRIGGER EVENT (card: Stochastic(9,3,3)).
input int    fast_stoch_k_period        = 9;     // fast %K period
input int    fast_stoch_d_period        = 3;     // fast %D period
input int    fast_stoch_slowing         = 3;     // fast %K slowing
// Stop / target.
input int    strategy_atr_period        = 14;    // ATR period for the stop
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR
input double strategy_tp_rr             = 0.0;   // RR-multiple TP; 0.0 = no fixed TP
// Spread guard (fail-open on .DWX zero modeled spread).
input double strategy_spread_pct_of_stop = 15.0; // skip only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work runs on the
// closed bar in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

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
// Slow Stoch supplies a standing directional STATE + zone filter; the fast
// Stoch %K/%D cross is the single fresh EVENT.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Slow Stoch STATE (closed bar shift 1): direction + zone ---
   const double slow_k = QM_Stoch_K(_Symbol, _Period, slow_stoch_k_period, slow_stoch_d_period, slow_stoch_slowing, 1);
   const double slow_d = QM_Stoch_D(_Symbol, _Period, slow_stoch_k_period, slow_stoch_d_period, slow_stoch_slowing, 1);
   if(slow_k <= 0.0 || slow_d <= 0.0)
      return false;

   const bool long_bias  = (slow_k > slow_d) && (slow_k < slow_overbought_level);
   const bool short_bias = (slow_k < slow_d) && (slow_k > slow_oversold_level);
   if(!long_bias && !short_bias)
      return false;

   // --- Fast Stoch EVENT: one fresh %K/%D cross (prev shift 2 -> now shift 1) ---
   const double fast_k_now  = QM_Stoch_K(_Symbol, _Period, fast_stoch_k_period, fast_stoch_d_period, fast_stoch_slowing, 1);
   const double fast_d_now  = QM_Stoch_D(_Symbol, _Period, fast_stoch_k_period, fast_stoch_d_period, fast_stoch_slowing, 1);
   const double fast_k_prev = QM_Stoch_K(_Symbol, _Period, fast_stoch_k_period, fast_stoch_d_period, fast_stoch_slowing, 2);
   const double fast_d_prev = QM_Stoch_D(_Symbol, _Period, fast_stoch_k_period, fast_stoch_d_period, fast_stoch_slowing, 2);
   if(fast_k_now <= 0.0 || fast_d_now <= 0.0 || fast_k_prev <= 0.0 || fast_d_prev <= 0.0)
      return false;

   const bool fast_cross_up   = (fast_k_prev <= fast_d_prev) && (fast_k_now > fast_d_now);
   const bool fast_cross_down = (fast_k_prev >= fast_d_prev) && (fast_k_now < fast_d_now);

   const bool long_signal  = long_bias  && fast_cross_up;
   const bool short_signal = short_bias && fast_cross_down;
   if(!long_signal && !short_signal)
      return false;

   // --- ATR stop / optional RR target ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType otype = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   double tp = 0.0; // 0.0 => no fixed TP (source specifies none)
   if(strategy_tp_rr > 0.0)
     {
      tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
     }

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_signal ? "fsr_dstoch_long" : "fsr_dstoch_short";
   return true;
  }

// No active management beyond the ATR stop; reversal exit is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Reversal exit: the fast Stoch crosses in the direction OPPOSITE the open
// position (one fresh fast-cross event at shift 1 vs shift 2).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast_k_now  = QM_Stoch_K(_Symbol, _Period, fast_stoch_k_period, fast_stoch_d_period, fast_stoch_slowing, 1);
   const double fast_d_now  = QM_Stoch_D(_Symbol, _Period, fast_stoch_k_period, fast_stoch_d_period, fast_stoch_slowing, 1);
   const double fast_k_prev = QM_Stoch_K(_Symbol, _Period, fast_stoch_k_period, fast_stoch_d_period, fast_stoch_slowing, 2);
   const double fast_d_prev = QM_Stoch_D(_Symbol, _Period, fast_stoch_k_period, fast_stoch_d_period, fast_stoch_slowing, 2);
   if(fast_k_now <= 0.0 || fast_d_now <= 0.0 || fast_k_prev <= 0.0 || fast_d_prev <= 0.0)
      return false;

   const bool fast_cross_up   = (fast_k_prev <= fast_d_prev) && (fast_k_now > fast_d_now);
   const bool fast_cross_down = (fast_k_prev >= fast_d_prev) && (fast_k_now < fast_d_now);
   if(!fast_cross_up && !fast_cross_down)
      return false;

   bool should_close = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      // Long closes on a bearish fast cross; short closes on a bullish fast cross.
      if((pt == POSITION_TYPE_BUY && fast_cross_down) ||
         (pt == POSITION_TYPE_SELL && fast_cross_up))
         should_close = true;
     }
   return should_close;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11634\",\"strategy\":\"fsr-double-stoch21-9-h1\"}");
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
