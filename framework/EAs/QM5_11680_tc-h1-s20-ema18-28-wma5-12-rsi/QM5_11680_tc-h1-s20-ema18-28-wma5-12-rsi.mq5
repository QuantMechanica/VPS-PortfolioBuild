#property strict
#property version   "5.0"
#property description "QM5_11680 tc-h1-s20-ema18-28-wma5-12-rsi — EMA(18/28) tunnel + WMA(5/12) breakout + RSI(21) (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11680 tc-h1-s20-ema18-28-wma5-12-rsi
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies Collection (1 Hour Time
//         Frame)", Strategy #20, self-published 2014 (source_id 6b5ab225-...).
// Card: artifacts/cards_approved/QM5_11680_tc-h1-s20-ema18-28-wma5-12-rsi.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trend STATE   : EMA(18)/EMA(28) form the "tunnel" (the 18-28 band).
//   Trigger EVENT : the WMA(5)/WMA(12) pair breaking fully through the tunnel.
//                   LONG  = bar[1] has WMA5 > EMA28 AND WMA12 > EMA28 (both fast
//                           WMAs above the UPPER tunnel edge), while bar[2] did
//                           NOT (fresh transition above the tunnel).
//                   SHORT = mirror: bar[1] WMA5 < EMA18 AND WMA12 < EMA18 (both
//                           below the LOWER tunnel edge), bar[2] not both below.
//   RSI STATE     : RSI(21) > rsi_mid for longs / < rsi_mid for shorts (the
//                   confirming momentum side — NOT a second cross event).
//   Stop / target : fixed sl_pips / tp_pips (card: 50 / 50).
//   Defensive exit: the WMA pair re-enters the tunnel (no longer fully above /
//                   below the relevant edge) or breaks through the opposite edge.
//
// Two-cross trap avoidance: the WMA-pair-vs-tunnel breakout is the ONE event
// (a single fresh transition between bar[2] and bar[1]). The RSI side is a
// confirming STATE read on the same closed bar — never a second simultaneous
// cross. This is the trap that zeroed ~88 EAs on 2026-06-16.
//
// .DWX invariants: no spread fail-closed (fail-open on zero modeled spread),
// no swap gate, single QM_IsNewBar consume per tick (framework OnTick owns it),
// stop/target/spread thresholds in pips via QM_StopRulesPipsToPriceDistance so
// they are scale-correct on 5-digit EURUSD / GBPUSD.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11680;
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
input int    strategy_ema_fast_period    = 18;     // tunnel fast EMA (upper/lower edge)
input int    strategy_ema_slow_period    = 28;     // tunnel slow EMA (upper/lower edge)
input int    strategy_wma_fast_period    = 5;      // fast WMA (LINEAR_WEIGHTED)
input int    strategy_wma_slow_period    = 12;     // slow WMA (LINEAR_WEIGHTED)
input int    strategy_rsi_period         = 21;     // RSI lookback period
input double strategy_rsi_mid            = 50.0;   // RSI bias level (>mid long / <mid short)
input int    strategy_sl_pips            = 50;     // stop distance, in pips (card: 50)
input int    strategy_tp_pips            = 50;     // target distance, in pips (card: 50)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar WMA-pair-vs-tunnel position; no per-EA new-bar gate)
// -----------------------------------------------------------------------------

// TRUE if, at closed-bar `shift`, BOTH WMAs sit ABOVE the upper tunnel edge
// (EMA28): WMA5 > EMA28 AND WMA12 > EMA28. Card "both above the tunnel".
bool WmaPairAboveTunnel(const int shift)
  {
   const double wma_fast = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, shift);
   const double wma_slow = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, shift);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift);
   if(wma_fast <= 0.0 || wma_slow <= 0.0 || ema_slow <= 0.0)
      return false;
   return (wma_fast > ema_slow && wma_slow > ema_slow);
  }

// TRUE if, at closed-bar `shift`, BOTH WMAs sit BELOW the lower tunnel edge
// (EMA18): WMA5 < EMA18 AND WMA12 < EMA18. Card "both below the tunnel".
bool WmaPairBelowTunnel(const int shift)
  {
   const double wma_fast = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, shift);
   const double wma_slow = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, shift);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
   if(wma_fast <= 0.0 || wma_slow <= 0.0 || ema_fast <= 0.0)
      return false;
   return (wma_fast < ema_fast && wma_slow < ema_fast);
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

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
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

   // --- RSI STATE: side bias (closed bar 1) ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // --- Trigger EVENT (one only): WMA-pair breaking fully through the tunnel ---
   // LONG : both WMAs above the tunnel on bar[1], NOT both above on bar[2].
   const bool long_break  = (WmaPairAboveTunnel(1) && !WmaPairAboveTunnel(2));
   // SHORT: both WMAs below the tunnel on bar[1], NOT both below on bar[2].
   const bool short_break = (WmaPairBelowTunnel(1) && !WmaPairBelowTunnel(2));

   if(long_break && rsi1 > strategy_rsi_mid)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, (double)strategy_tp_pips / (double)strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "tc_tunnel_wma_long";
      return true;
     }

   if(short_break && rsi1 < strategy_rsi_mid)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, (double)strategy_tp_pips / (double)strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "tc_tunnel_wma_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed SL/TP. Defensive exit is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: the WMA pair re-enters the tunnel (no longer fully above /
// below the relevant edge) or crosses to the opposite side. A long is closed
// once the pair is no longer fully above the upper edge; a short once the pair
// is no longer fully below the lower edge. Single closed-bar state read (shift 1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the side of our open position for this magic.
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

   // Long exits when the pair is no longer fully above the tunnel (re-entry or
   // break to the opposite/lower side). Short mirrors.
   if(have_long && !WmaPairAboveTunnel(1))
      return true;
   if(have_short && !WmaPairBelowTunnel(1))
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
