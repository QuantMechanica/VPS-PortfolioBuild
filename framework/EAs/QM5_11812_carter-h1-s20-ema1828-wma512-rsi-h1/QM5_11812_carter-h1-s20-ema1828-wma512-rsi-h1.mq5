#property strict
#property version   "5.0"
#property description "QM5_11812 carter-h1-s20-ema1828-wma512-rsi-h1 — EMA(18/28) tunnel STATE + WMA(5/12) cross EVENT + RSI(21) STATE (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11812 carter-h1-s20-ema1828-wma512-rsi-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy S20, 2014 (source_id 529382f8-fbd1-5c17-ba62-fbe56990ebcd).
// Card: artifacts/cards_approved/QM5_11812_carter-h1-s20-ema1828-wma512-rsi-h1.md
//       (g0_status APPROVED).
//
// Sibling EA QM5_11680 implements the same Carter S20 family but realises the
// trigger as the WMA-pair breaking THROUGH the EMA tunnel. THIS card (S20) is
// explicit in its Implementation Notes that the trigger EVENT is the WMA(5)/(12)
// cross itself ("wma5[1] > wma12[1] AND wma5[2] <= wma12[2] for long"), with the
// EMA(18/28) tunnel direction and the RSI(21) level as confirming STATES. We
// follow THIS card literally.
//
// Mechanics (closed-bar reads at shift 1/2; H1):
//   Trigger EVENT : WMA(5)/WMA(12) cross.
//                   LONG  = WMA5 crosses ABOVE WMA12: wma5[1] > wma12[1] AND
//                           wma5[2] <= wma12[2] (one fresh transition bar[2]->bar[1]).
//                   SHORT = WMA5 crosses BELOW WMA12: wma5[1] < wma12[1] AND
//                           wma5[2] >= wma12[2].
//   Tunnel STATE  : EMA(18) vs EMA(28) on bar[1]. LONG needs EMA18 > EMA28
//                   (bullish tunnel); SHORT needs EMA18 < EMA28.
//   RSI STATE     : RSI(21) on bar[1] > rsi_mid for longs / < rsi_mid for shorts.
//   Stop / target : 2*ATR(14) SL, 4*ATR(14) TP (card factory defaults).
//   Defensive exit: WMA(5) crosses back through WMA(12) against the open side.
//
// Two-cross trap avoidance: the WMA5/12 cross is the ONE event (single fresh
// transition between bar[2] and bar[1]). The EMA tunnel and RSI sides are
// confirming STATE reads on the same closed bar — never second simultaneous
// cross events. This is the trap that zeroed ~88 EAs on 2026-06-16.
//
// .DWX invariants: no spread fail-closed (fail-open on zero modeled spread),
// no swap gate, single QM_IsNewBar consume per tick (framework OnTick owns it),
// ATR-derived stops via QM_StopATR / QM_TakeRR so they are scale-correct on
// 5-digit EURUSD/GBPUSD/AUDUSD and 3-digit USDJPY.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11812;
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
input int    strategy_ema_fast_period    = 18;     // tunnel fast EMA (bullish when > slow)
input int    strategy_ema_slow_period    = 28;     // tunnel slow EMA
input int    strategy_wma_fast_period    = 5;      // fast WMA (LINEAR_WEIGHTED) — cross trigger
input int    strategy_wma_slow_period    = 12;     // slow WMA (LINEAR_WEIGHTED) — cross trigger
input int    strategy_rsi_period         = 21;     // RSI lookback period
input double strategy_rsi_mid            = 50.0;   // RSI bias level (>mid long / <mid short)
input int    strategy_atr_period         = 14;     // ATR period for SL/TP
input double strategy_atr_sl_mult        = 2.0;    // stop = 2*ATR (card default)
input double strategy_atr_tp_mult        = 4.0;    // target = 4*ATR (card default)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar WMA-pair cross detection; no per-EA new-bar gate)
// -----------------------------------------------------------------------------

// TRUE if, at closed-bar `shift`, the fast WMA sits ABOVE the slow WMA.
bool WmaFastAboveSlow(const int shift)
  {
   const double wma_fast = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, shift);
   const double wma_slow = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, shift);
   if(wma_fast <= 0.0 || wma_slow <= 0.0)
      return false;
   return (wma_fast > wma_slow);
  }

// TRUE if, at closed-bar `shift`, the fast WMA sits BELOW the slow WMA.
bool WmaFastBelowSlow(const int shift)
  {
   const double wma_fast = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, shift);
   const double wma_slow = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, shift);
   if(wma_fast <= 0.0 || wma_slow <= 0.0)
      return false;
   return (wma_fast < wma_slow);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
// Regime/signal work is on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_atr_sl_mult * atr;
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

   // --- Confirming STATES (closed bar 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double rsi1     = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || rsi1 <= 0.0)
      return false;

   const bool bullish_tunnel = (ema_fast > ema_slow); // EMA18 > EMA28
   const bool bearish_tunnel = (ema_fast < ema_slow); // EMA18 < EMA28

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // --- Trigger EVENT (one only): WMA(5)/WMA(12) cross between bar[2] and bar[1] ---
   const bool wma_cross_up   = (WmaFastAboveSlow(1) && !WmaFastAboveSlow(2));
   const bool wma_cross_down = (WmaFastBelowSlow(1) && !WmaFastBelowSlow(2));

   // ATR for ATR-based stops (closed bar 1).
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(wma_cross_up && bullish_tunnel && rsi1 > strategy_rsi_mid)
     {
      const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      const double rr = (strategy_atr_sl_mult > 0.0) ? (strategy_atr_tp_mult / strategy_atr_sl_mult) : 0.0;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_s20_wma_cross_long";
      return true;
     }

   if(wma_cross_down && bearish_tunnel && rsi1 < strategy_rsi_mid)
     {
      const double sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
      const double rr = (strategy_atr_sl_mult > 0.0) ? (strategy_atr_tp_mult / strategy_atr_sl_mult) : 0.0;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_s20_wma_cross_short";
      return true;
     }

   return false;
  }

// No active management beyond the ATR SL/TP. Defensive exit is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: the WMA(5) crosses back through WMA(12) against the open side.
// A long is closed once WMA5 falls below WMA12; a short once WMA5 rises above
// WMA12. Single closed-bar state read (shift 1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool have_long = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Long exits when WMA5 is no longer above WMA12 (crossed back down).
   if(have_long && !WmaFastAboveSlow(1))
      return true;
   // Short exits when WMA5 is no longer below WMA12 (crossed back up).
   if(have_short && !WmaFastBelowSlow(1))
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
