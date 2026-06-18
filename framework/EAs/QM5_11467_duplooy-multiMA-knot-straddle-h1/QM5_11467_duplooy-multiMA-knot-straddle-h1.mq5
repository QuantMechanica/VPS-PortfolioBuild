#property strict
#property version   "5.0"
#property description "QM5_11467 duplooy-multiMA-knot-straddle-h1 — Multi-MA Knot Straddle (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11467 duplooy-multiMA-knot-straddle-h1
// -----------------------------------------------------------------------------
// Source: Alex du Plooy, Expert4x Multi-MA Convergence Course (~2015).
// Card: artifacts/cards_approved/QM5_11467_duplooy-multiMA-knot-straddle-h1.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Knot STATE (compression): six SMAs (periods 4/8/12/16/20/24) cluster tight.
//     knot_spread[s] = max(SMAs[s]) - min(SMAs[s]).  The cluster is "knotted"
//     when knot_spread is below KNOT_PIPS (in price-distance terms) for
//     KNOT_BARS consecutive CLOSED bars (shifts 1 .. KNOT_BARS). This is a
//     STATE, not an event — a multi-bar compression of the MA dispersion.
//   Break EVENT (single trigger): once the knot is confirmed and there is no
//     open position and no live straddle, place an OCO bracket:
//       BUYSTOP  at cluster_top[1]    + offset, SL at cluster_bottom[1] - offset
//       SELLSTOP at cluster_bottom[1] - offset, SL at cluster_top[1]    + offset
//     The break of the cluster in either direction is the ONE event that arms
//     a fill. One knot confirmation => one bracket (never two cross events on
//     the same bar — the bracket itself captures whichever side breaks first).
//   OCO + expiry (per tick): when one leg fills (becomes a position), cancel
//     the opposite pending leg immediately. If neither fills within
//     ORDER_EXPIRY_BARS bars, cancel both. The framework duplicate-guard keeps
//     it ONE position per magic; cancelling the opposite leg enforces OCO.
//   Take profit: SL distance x TP_RR (default 2.0 -> 2:1 R:R) baked into each
//     pending leg at placement (symmetric bracket).
//   Stop loss: opposite side of the knot +/- offset. P2 cap: if the total
//     stop distance (knot span + 2*offset) exceeds SL_CAP_PIPS, skip the knot.
//   Spread guard: skip only a genuinely WIDE spread (fail-open on .DWX zero
//     modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11467;
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
input int    strategy_ma1_period        = 4;     // fastest SMA in the cluster
input int    strategy_ma2_period        = 8;
input int    strategy_ma3_period        = 12;
input int    strategy_ma4_period        = 16;
input int    strategy_ma5_period        = 20;
input int    strategy_ma6_period        = 24;    // slowest SMA in the cluster
input int    strategy_knot_pips         = 10;    // max cluster spread for a "knot"
input int    strategy_knot_bars         = 3;     // consecutive closed bars of compression
input int    strategy_offset_pips       = 1;     // breakout buffer above/below the cluster
input double strategy_tp_rr             = 2.0;   // take-profit reward:risk multiple
input int    strategy_sl_cap_pips       = 30;    // skip knot if total stop distance exceeds this
input int    strategy_order_expiry_bars = 5;     // cancel both legs if neither fills in N bars
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope straddle state (advanced on the per-tick management path).
// -----------------------------------------------------------------------------
ulong    g_buy_stop_ticket  = 0;     // live BUYSTOP pending ticket (0 = none)
ulong    g_sell_stop_ticket = 0;     // live SELLSTOP pending ticket (0 = none)
datetime g_straddle_armed_bar = 0;   // bar-open time when the bracket was placed

// -----------------------------------------------------------------------------
// Helpers (closed-bar SMA cluster reads; not framework-reimplementations).
// -----------------------------------------------------------------------------

// Fill smas[0..5] with the six cluster SMAs at the given closed-bar shift.
// Returns false if any read is invalid.
bool QM5_ReadCluster(const int shift, double &smas[])
  {
   smas[0] = QM_SMA(_Symbol, _Period, strategy_ma1_period, shift);
   smas[1] = QM_SMA(_Symbol, _Period, strategy_ma2_period, shift);
   smas[2] = QM_SMA(_Symbol, _Period, strategy_ma3_period, shift);
   smas[3] = QM_SMA(_Symbol, _Period, strategy_ma4_period, shift);
   smas[4] = QM_SMA(_Symbol, _Period, strategy_ma5_period, shift);
   smas[5] = QM_SMA(_Symbol, _Period, strategy_ma6_period, shift);
   for(int i = 0; i < 6; ++i)
      if(smas[i] <= 0.0)
         return false;
   return true;
  }

double QM5_ClusterMax(const double &smas[])
  {
   double m = smas[0];
   for(int i = 1; i < 6; ++i)
      if(smas[i] > m) m = smas[i];
   return m;
  }

double QM5_ClusterMin(const double &smas[])
  {
   double m = smas[0];
   for(int i = 1; i < 6; ++i)
      if(smas[i] < m) m = smas[i];
   return m;
  }

// True while the BUYSTOP / SELLSTOP pending order is still live (not filled,
// not cancelled). Pending orders are OrderSelect-able; once filled they leave
// the orders pool and become a position.
bool QM5_PendingAlive(const ulong ticket)
  {
   if(ticket == 0)
      return false;
   if(!OrderSelect(ticket))
      return false;
   const long ot = OrderGetInteger(ORDER_TYPE);
   return (ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — knot/cluster work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Spread cap referenced to the configured max stop distance so it scales
   // with the symbol. Only a genuinely wide spread blocks.
   const double stop_ref = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(stop_ref <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_ref)
      return true;

   return false;
  }

// Knot-confirmation + bracket placement. Caller guarantees QM_IsNewBar()==true.
// Returns false from the framework's single-open path: this hook never asks the
// framework to open ONE market order. Instead it places BOTH pending legs here
// (knot break = single event) and tracks them for OCO. Always returns false so
// the framework wiring does not also try to open a market position.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Already in a position for this magic -> nothing to arm.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // A live straddle is already armed -> let management handle it; do not
   // re-arm on top of it.
   if(QM5_PendingAlive(g_buy_stop_ticket) || QM5_PendingAlive(g_sell_stop_ticket))
      return false;

   // Stale ticket handles with no live order -> reset before re-arming.
   g_buy_stop_ticket  = 0;
   g_sell_stop_ticket = 0;

   // --- Knot STATE: cluster spread below threshold for KNOT_BARS closed bars.
   const double knot_threshold = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_knot_pips);
   const double offset_dist     = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   const double sl_cap_dist     = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(knot_threshold <= 0.0 || sl_cap_dist <= 0.0)
      return false;

   double smas[6];
   const int bars = (strategy_knot_bars < 1) ? 1 : strategy_knot_bars;
   for(int s = 1; s <= bars; ++s)
     {
      if(!QM5_ReadCluster(s, smas))
         return false;
      const double spread_s = QM5_ClusterMax(smas) - QM5_ClusterMin(smas);
      if(spread_s >= knot_threshold)
         return false; // not compressed on this bar -> no knot
     }

   // Knot confirmed. Reference the most-recent CLOSED bar's cluster extremes.
   if(!QM5_ReadCluster(1, smas))
      return false;
   const double cluster_top    = QM5_ClusterMax(smas);
   const double cluster_bottom = QM5_ClusterMin(smas);
   if(cluster_top <= cluster_bottom)
      return false;

   const double buy_entry  = cluster_top    + offset_dist;
   const double sell_entry = cluster_bottom - offset_dist;
   const double buy_sl     = cluster_bottom - offset_dist; // opposite side of knot
   const double sell_sl    = cluster_top    + offset_dist;

   // P2 stop cap: total stop distance = knot span + 2*offset. Skip if too wide.
   const double stop_distance = (cluster_top - cluster_bottom) + 2.0 * offset_dist;
   if(stop_distance <= 0.0 || stop_distance > sl_cap_dist)
      return false;

   // Symmetric TP at TP_RR * stop_distance from each entry.
   const double buy_tp  = buy_entry  + strategy_tp_rr * stop_distance;
   const double sell_tp = sell_entry - strategy_tp_rr * stop_distance;

   const int expiry_seconds = strategy_order_expiry_bars * PeriodSeconds(_Period);

   // --- Place the BUYSTOP leg. ---
   QM_EntryRequest buy_req;
   buy_req.type               = QM_BUY_STOP;
   buy_req.price              = buy_entry;
   buy_req.sl                 = buy_sl;
   buy_req.tp                 = buy_tp;
   buy_req.reason             = "knot_straddle_buystop";
   buy_req.symbol_slot        = qm_magic_slot_offset;
   buy_req.expiration_seconds = expiry_seconds;
   ulong buy_ticket = 0;
   if(QM_TM_OpenPosition(buy_req, buy_ticket))
      g_buy_stop_ticket = buy_ticket;

   // --- Place the SELLSTOP leg. ---
   QM_EntryRequest sell_req;
   sell_req.type               = QM_SELL_STOP;
   sell_req.price              = sell_entry;
   sell_req.sl                 = sell_sl;
   sell_req.tp                 = sell_tp;
   sell_req.reason             = "knot_straddle_sellstop";
   sell_req.symbol_slot        = qm_magic_slot_offset;
   sell_req.expiration_seconds = expiry_seconds;
   ulong sell_ticket = 0;
   if(QM_TM_OpenPosition(sell_req, sell_ticket))
      g_sell_stop_ticket = sell_ticket;

   if(g_buy_stop_ticket != 0 || g_sell_stop_ticket != 0)
      g_straddle_armed_bar = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open

   // The bracket is placed directly; never ask the framework to open a market
   // position from this hook.
   return false;
  }

// Per-tick OCO + expiry management for the pending straddle.
//   - If one leg has filled (a position exists for this magic), cancel any
//     still-pending opposite leg immediately (OCO).
//   - If neither leg has filled within ORDER_EXPIRY_BARS bars, cancel both.
void Strategy_ManageOpenPosition()
  {
   const bool buy_alive  = QM5_PendingAlive(g_buy_stop_ticket);
   const bool sell_alive = QM5_PendingAlive(g_sell_stop_ticket);

   if(!buy_alive && !sell_alive)
     {
      // Nothing live to manage; clear stale handles.
      g_buy_stop_ticket  = 0;
      g_sell_stop_ticket = 0;
      return;
     }

   // OCO: a filled leg means a position now exists for this magic. Cancel the
   // remaining pending leg.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
     {
      if(buy_alive)
        {
         QM_TM_RemovePendingOrder(g_buy_stop_ticket, "oco_cancel_buy");
         g_buy_stop_ticket = 0;
        }
      if(sell_alive)
        {
         QM_TM_RemovePendingOrder(g_sell_stop_ticket, "oco_cancel_sell");
         g_sell_stop_ticket = 0;
        }
      return;
     }

   // Expiry backstop (in addition to the broker-side order expiration): cancel
   // both legs once the armed window elapses.
   if(g_straddle_armed_bar > 0)
     {
      const int    expiry_seconds = strategy_order_expiry_bars * PeriodSeconds(_Period);
      const datetime now_bar = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open
      if(now_bar - g_straddle_armed_bar >= expiry_seconds)
        {
         if(buy_alive)
            QM_TM_RemovePendingOrder(g_buy_stop_ticket, "straddle_expiry_buy");
         if(sell_alive)
            QM_TM_RemovePendingOrder(g_sell_stop_ticket, "straddle_expiry_sell");
         g_buy_stop_ticket  = 0;
         g_sell_stop_ticket = 0;
        }
     }
  }

// No discretionary exit beyond the symmetric SL/TP baked into each filled leg.
bool Strategy_ExitSignal()
  {
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
