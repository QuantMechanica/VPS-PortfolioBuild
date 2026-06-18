#property strict
#property version   "5.0"
#property description "QM5_11744 rfs-ema5-stoch-rsi-h1 — EMA(5/10) cross + Stochastic + RSI (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11744 rfs-ema5-stoch-rsi-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "EMA, Stochastic and RSI", Robo-forex Strategy Compilation
//         (robofx.com, ~2015). Card: artifacts/cards_approved/
//         QM5_11744_rfs-ema5-stoch-rsi-h1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trigger EVENT : EMA(fast) crosses EMA(slow) on the just-closed bar.
//                     long  = fast[2] <= slow[2] AND fast[1] >  slow[1]
//                     short = fast[2] >= slow[2] AND fast[1] <  slow[1]
//                   This is the ONE cross event. Everything else is a STATE
//                   read on the SAME closed bar (no second cross required —
//                   avoids the two-cross zero-trade trap).
//   Momentum STATE: Stochastic %K directed with the trade.
//                     long  = K[1] > K[2]   (rising)
//                     short = K[1] < K[2]   (falling)
//   Zone STATE    : Stochastic %K not already exhausted.
//                     long  = K[1] < stoch_ob   (not overbought)
//                     short = K[1] > stoch_os   (not oversold)
//   Bias STATE    : RSI on the bullish/bearish side of 50.
//                     long  = RSI[1] > rsi_mid ; short = RSI[1] < rsi_mid
//   Stop          : entry -/+ sl_atr_mult * ATR (card: 2*ATR factory default).
//   Take profit   : entry +/- tp_atr_mult * ATR (card safety: hard 3*ATR).
//   Exit (manual) : reverse EMA cross OR RSI crossing the mid level against the
//                   open position — whichever comes first.
//   Spread guard  : block only a genuinely wide spread (> pct of stop distance);
//                   fail-open on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11744;
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
input int    strategy_ema_fast_period    = 5;      // fast EMA (directional trigger leg)
input int    strategy_ema_slow_period    = 10;     // slow EMA (directional trigger leg)
input int    strategy_stoch_k            = 14;     // Stochastic %K period
input int    strategy_stoch_d            = 3;      // Stochastic %D period
input int    strategy_stoch_slowing      = 3;      // Stochastic slowing
input double strategy_stoch_ob           = 80.0;   // overbought ceiling (block longs above)
input double strategy_stoch_os           = 20.0;   // oversold floor (block shorts below)
input int    strategy_rsi_period         = 14;     // RSI period
input double strategy_rsi_mid            = 50.0;   // RSI bias / exit level
input int    strategy_atr_period         = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 3.0;    // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
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

   // --- EMA legs (closed bars: shift 1 current, shift 2 prior) ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   // Trigger EVENT: ONE fresh EMA cross on the just-closed bar.
   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);
   if(!cross_up && !cross_down)
      return false;

   // --- Stochastic %K: direction STATE + zone STATE (same closed bar) ---
   const double k_1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k_2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(k_1 <= 0.0 || k_2 <= 0.0)
      return false;

   // --- RSI bias STATE (same closed bar) ---
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_1 <= 0.0)
      return false;

   // --- ATR for stops/targets ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   QM_OrderType side;
   if(cross_up)
     {
      // Long confirmations: Stoch rising, not overbought, RSI above mid.
      if(!(k_1 > k_2))             return false;
      if(!(k_1 < strategy_stoch_ob)) return false;
      if(!(rsi_1 > strategy_rsi_mid)) return false;
      side = QM_BUY;
     }
   else
     {
      // Short confirmations: Stoch falling, not oversold, RSI below mid.
      if(!(k_1 < k_2))             return false;
      if(!(k_1 > strategy_stoch_os)) return false;
      if(!(rsi_1 < strategy_rsi_mid)) return false;
      side = QM_SELL;
     }

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ema_stoch_rsi_long" : "ema_stoch_rsi_short";
   return true;
  }

// Fixed ATR stop/target only; discretionary exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Manual exit: reverse EMA cross OR RSI crossing the mid level against the
// open position. Direction-aware via the held position's type. Closed-bar reads.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the side of the held position for this magic.
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

   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;

   if(is_long)
     {
      const bool ema_rev = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1);
      const bool rsi_rev = (rsi_2 >= strategy_rsi_mid && rsi_1 < strategy_rsi_mid);
      return (ema_rev || rsi_rev);
     }

   // is_short
   const bool ema_rev = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1);
   const bool rsi_rev = (rsi_2 <= strategy_rsi_mid && rsi_1 > strategy_rsi_mid);
   return (ema_rev || rsi_rev);
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
