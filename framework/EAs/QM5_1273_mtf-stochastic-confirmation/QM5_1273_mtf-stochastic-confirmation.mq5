#property strict
#property version   "5.0"
#property description "QM5_1273 mtf-stochastic-confirmation — MTF Stoch Sync H1/H4/D1 (FX majors)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1273 mtf-stochastic-confirmation
// -----------------------------------------------------------------------------
// Source: ForexFactory Trading Systems — MTF Stochastic sync-confirmation
//   cluster (named-handle threads 2010-2020; 3-Ducks QM5_1051 lineage).
// Card: artifacts/cards_approved/QM5_1273_mtf-stochastic-confirmation.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads; entry TF = H1, all stochs = Stoch(14,3,3)):
//   Trigger EVENT (H1, entry TF): %K crosses %D — the ONE cross of the system.
//     LONG : K[1] > D[1] AND K[2] <= D[2]  (fresh cross UP within last 2 bars)
//     SHORT: K[1] < D[1] AND K[2] >= D[2]  (fresh cross DOWN)
//   Regime STATE (H4, intermediate filter — NO cross, level + alignment):
//     LONG : %K[1] > 50 AND %K[1] > %D[1]   SHORT: %K[1] < 50 AND %K[1] < %D[1]
//   Macro STATE (D1, bias filter — NO cross, level only):
//     LONG : %K[1] > 50                     SHORT: %K[1] < 50
//   MA bias STATE (H1): close[1] > EMA(200,H1) for LONG, < for SHORT.
//   Stop  : ATR(14,H1) * sl_atr_mult from entry.
//   Take  : fixed RR (tp_rr) off the stop distance.
//   Exit  : (a) H1 opposite-direction %K/%D cross on the closed H1 bar, or
//           (b) D1 macro-flip — %K[1] crossed back through 50 against position.
//   Spread guard: blocks only a genuinely wide spread vs the stop distance;
//                 fail-open on .DWX zero modeled spread.
//
// Two-cross trap avoidance: the H1 stoch cross is the SOLE event. H4 and D1
// are STATE filters (above/below 50 + alignment), never simultaneous crosses.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1273;
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
input int    strategy_stoch_k_period    = 14;    // Stochastic %K period (all TFs)
input int    strategy_stoch_d_period    = 3;     // Stochastic %D smoothing (all TFs)
input int    strategy_stoch_slowing     = 3;     // Stochastic slowing (all TFs)
input double strategy_stoch_midline     = 50.0;  // HTF state midline
input int    strategy_ema_period        = 200;   // H1 macro MA-bias period
input int    strategy_atr_period        = 14;    // ATR period (stop sizing)
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR  (P3 {1.5,2.0,2.5,3.0})
input double strategy_tp_rr             = 1.5;   // take-profit RR multiple     (P3 {1.0,1.5,2.0,3.0})
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal helpers (closed-bar stochastic reads on explicit timeframes)
// -----------------------------------------------------------------------------

// H1 stoch cross direction on the last closed bar: +1 cross UP, -1 cross DOWN,
// 0 none. ONE event — compares shift-1 vs shift-2 on the entry TF.
int H1StochCross()
  {
   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(k1 <= 0.0 || d1 <= 0.0 || k2 <= 0.0 || d2 <= 0.0)
      return 0;
   if(k1 > d1 && k2 <= d2)
      return +1;
   if(k1 < d1 && k2 >= d2)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true on the H1 entry TF.
// H1 cross = trigger EVENT; H4/D1 = STATE filters (no second cross).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: H1 stochastic %K/%D cross on the last closed H1 bar ---
   const int h1_cross = H1StochCross();
   if(h1_cross == 0)
      return false;

   // --- Macro STATE (D1): %K relative to the midline (level only, no cross) ---
   const double d1_k = QM_Stoch_K(_Symbol, PERIOD_D1, strategy_stoch_k_period,
                                  strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(d1_k <= 0.0)
      return false;

   // --- Regime STATE (H4): %K above/below midline AND %K aligned vs %D ---
   const double h4_k = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period,
                                  strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double h4_d = QM_Stoch_D(_Symbol, PERIOD_H4, strategy_stoch_k_period,
                                  strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(h4_k <= 0.0 || h4_d <= 0.0)
      return false;

   // --- MA-bias STATE (H1): close vs EMA(200) ---
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema <= 0.0 || close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   bool go_long  = false;
   bool go_short = false;

   if(h1_cross == +1)
     {
      go_long = (d1_k > strategy_stoch_midline) &&                 // D1 macro bullish
                (h4_k > strategy_stoch_midline && h4_k > h4_d) &&  // H4 above midline + aligned
                (close1 > ema);                                    // price above macro MA
     }
   else // h1_cross == -1
     {
      go_short = (d1_k < strategy_stoch_midline) &&                // D1 macro bearish
                 (h4_k < strategy_stoch_midline && h4_k < h4_d) && // H4 below midline + aligned
                 (close1 < ema);                                   // price below macro MA
     }

   if(!go_long && !go_short)
      return false;

   const QM_OrderType ot = go_long ? QM_BUY : QM_SELL;

   const double entry = (go_long) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

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
   req.reason = go_long ? "mtf_stoch_long" : "mtf_stoch_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop and RR target.
// Discretionary exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: (a) H1 opposite-direction stoch cross against the open position, or
//       (b) D1 macro-flip — D1 %K crossed back through the midline against it.
// Each is ONE event on the last closed H1 bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Resolve current position direction for this EA's magic.
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

   // (a) H1 opposite-direction stochastic cross.
   const int h1_cross = H1StochCross();
   if(is_long && h1_cross == -1)
      return true;
   if(is_short && h1_cross == +1)
      return true;

   // (b) D1 macro-flip through the midline against the position.
   const double d1_k1 = QM_Stoch_K(_Symbol, PERIOD_D1, strategy_stoch_k_period,
                                   strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1_k2 = QM_Stoch_K(_Symbol, PERIOD_D1, strategy_stoch_k_period,
                                   strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(d1_k1 > 0.0 && d1_k2 > 0.0)
     {
      const bool flip_down = (d1_k2 >= strategy_stoch_midline && d1_k1 < strategy_stoch_midline);
      const bool flip_up   = (d1_k2 <= strategy_stoch_midline && d1_k1 > strategy_stoch_midline);
      if(is_long && flip_down)
         return true;
      if(is_short && flip_up)
         return true;
     }

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
