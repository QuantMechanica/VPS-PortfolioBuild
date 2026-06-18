#property strict
#property version   "5.0"
#property description "QM5_11545 carter-t-h1-ema18-28-wma5-12-rsi21 — EMA(18/28) red-tunnel + WMA(5/12) cross + RSI(21) (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11545 carter-t-h1-ema18-28-wma5-12-rsi21
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         System #20, self-published 2014 (source_id 3001a121-...).
// Card: artifacts/cards_approved/QM5_11545_carter-t-h1-ema18-28-wma5-12-rsi21.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Tunnel STATE  : EMA(18) and EMA(28) form a narrow "red tunnel" —
//                   |EMA18 - EMA28| <= tunnel_narrow_pips (price distance).
//   RSI STATE     : RSI(21) > rsi_mid for longs / < rsi_mid for shorts.
//   Trigger EVENT : the WMA(5)/WMA(12)-vs-tunnel cross. This is the ONE event.
//                   LONG  = bar[1] has WMA5 > EMA18 AND WMA12 > EMA28, while
//                           bar[2] did NOT have both above (fresh transition
//                           of the pair to "above the tunnel").
//                   SHORT = mirror: bar[1] WMA5 < EMA28 AND WMA12 < EMA18,
//                           bar[2] not both below.
//   Stop / target : fixed sl_pips / tp_pips (card: 50 / 50).
//   Defensive exit: both WMAs cross back to the opposite side of the tunnel.
//
// Two-cross trap avoidance: only the WMA-pair vs tunnel position is an EVENT
// (one transition). Tunnel-narrow and RSI-side are confirming STATES read on
// the same closed bar — never a second simultaneous cross requirement.
//
// .DWX invariants: no spread fail-closed (fail-open on zero modeled spread),
// no swap gate, single QM_IsNewBar consume per tick (framework OnTick owns it),
// tunnel threshold expressed in pips via QM_StopRulesPipsToPriceDistance so it
// is scale-correct on 5-digit EURUSD.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11545;
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
input int    strategy_ema_fast_period    = 18;     // red-tunnel fast EMA
input int    strategy_ema_slow_period    = 28;     // red-tunnel slow EMA
input int    strategy_wma_fast_period    = 5;      // fast WMA (LINEAR_WEIGHTED)
input int    strategy_wma_slow_period    = 12;     // slow WMA (LINEAR_WEIGHTED)
input int    strategy_rsi_period         = 21;     // RSI lookback period
input double strategy_rsi_mid            = 50.0;   // RSI bias level (>mid long / <mid short)
input int    strategy_tunnel_narrow_pips = 5;      // tunnel-narrow gap, in pips
input int    strategy_sl_pips            = 50;     // stop distance, in pips
input int    strategy_tp_pips            = 50;     // target distance, in pips
input bool   strategy_no_friday_entry    = true;   // card: no Friday entries
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar pair-vs-tunnel position; no per-EA new-bar gate)
// -----------------------------------------------------------------------------

// TRUE if, at closed-bar `shift`, both WMAs sit ABOVE the red tunnel
// (WMA5 > EMA18 AND WMA12 > EMA28).
bool WmaPairAboveTunnel(const int shift)
  {
   const double wma_fast = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, shift);
   const double wma_slow = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, shift);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift);
   if(wma_fast <= 0.0 || wma_slow <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;
   return (wma_fast > ema_fast && wma_slow > ema_slow);
  }

// TRUE if, at closed-bar `shift`, both WMAs sit BELOW the red tunnel
// (WMA5 < EMA28 AND WMA12 < EMA18).
bool WmaPairBelowTunnel(const int shift)
  {
   const double wma_fast = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, shift);
   const double wma_slow = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, shift);
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift);
   if(wma_fast <= 0.0 || wma_slow <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;
   return (wma_fast < ema_slow && wma_slow < ema_fast);
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

   // Card filter: no Friday entries (broker time).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Tunnel STATE: red tunnel is narrow (closed bar 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;
   const double tunnel_gap   = MathAbs(ema_fast - ema_slow);
   const double narrow_price = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tunnel_narrow_pips);
   if(narrow_price <= 0.0)
      return false;
   if(tunnel_gap > narrow_price)
      return false; // tunnel not narrow enough — no setup

   // --- RSI STATE: side bias (closed bar 1) ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || entry_bid <= 0.0)
      return false;

   // --- Trigger EVENT (one only): WMA-pair vs tunnel fresh transition ---
   // LONG: both WMAs above tunnel on bar[1], NOT both above on bar[2].
   const bool long_cross  = (WmaPairAboveTunnel(1) && !WmaPairAboveTunnel(2));
   // SHORT: both WMAs below tunnel on bar[1], NOT both below on bar[2].
   const bool short_cross = (WmaPairBelowTunnel(1) && !WmaPairBelowTunnel(2));

   if(long_cross && rsi1 > strategy_rsi_mid)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, (double)strategy_tp_pips / (double)strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_tunnel_wma_long";
      return true;
     }

   if(short_cross && rsi1 < strategy_rsi_mid)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry_bid, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry_bid, sl, (double)strategy_tp_pips / (double)strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_tunnel_wma_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed SL/TP. Defensive exit is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: WMAs cross back to the opposite side of the tunnel.
// A long is closed once both WMAs are below the tunnel; a short once both
// WMAs are above it. Single closed-bar state read (shift 1).
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

   if(have_long && WmaPairBelowTunnel(1))
      return true;
   if(have_short && WmaPairAboveTunnel(1))
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
