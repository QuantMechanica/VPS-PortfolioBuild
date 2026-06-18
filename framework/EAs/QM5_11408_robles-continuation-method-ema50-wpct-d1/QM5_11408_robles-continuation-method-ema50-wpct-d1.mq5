#property strict
#property version   "5.0"
#property description "QM5_11408 robles-continuation-method-ema50-wpct-d1 — EMA50 trend + Williams %R pullback-resume stop entry, D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11408 robles-continuation-method-ema50-wpct-d1
// -----------------------------------------------------------------------------
// Source: Cecil Robles (Your Forex Mentor) "The Continuation Method", in
// "6 Simple Strategies for Trading Forex" (TradingPub).
// Card: artifacts/cards_approved/QM5_11408_robles-continuation-method-ema50-wpct-d1.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; D1):
//   Trend STATE  : EMA(ema_period) slope over slope_lookback bars.
//                  LONG  -> EMA[1] > EMA[1+slope_lookback]  (rising)
//                  SHORT -> EMA[1] < EMA[1+slope_lookback]  (falling)
//   Pullback+resume EVENT (the single trigger; encodes both the dip and the
//   recovery in ONE bar-to-bar cross, so it never needs two events on one bar):
//                  LONG  -> WPR[2] <= os_level  AND WPR[1] >  os_level
//                           (Williams %R was oversold then crossed back up)
//                  SHORT -> WPR[2] >= ob_level  AND WPR[1] <  ob_level
//   Entry        : stop order beyond the signal bar's extreme +/- buffer pips.
//                  LONG  -> BUY_STOP  at High[1] + buffer
//                  SHORT -> SELL_STOP at Low[1]  - buffer
//                  Pending order expires after `pending_expiry_bars` D1 bars; a
//                  fresh signal bar replaces any still-pending order.
//   Stop loss    : nearest swing extreme before the signal bar (structure
//                  lookback), capped at sl_cap_pips. Framework sizes lots from
//                  the entry->SL distance.
//   Exit / trail : once price reaches trail_trigger_rr * initial-risk in profit,
//                  trail the SL toward SMA(trail_sma_period) confirmed by two
//                  consecutive closes on the profitable side of the SMA.
//   Spread guard : block only a genuinely wide spread > spread_pct_of_stop of
//                  the stop distance (fail-OPEN on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11408;
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
input int    strategy_ema_period         = 50;     // EMA50 trend state
input int    strategy_ema_slope_lookback = 10;     // slope window: EMA[1] vs EMA[1+lb]
input int    strategy_wpr_period         = 14;     // Williams %R period
input double strategy_wpr_os_level       = -80.0;  // oversold threshold (long resume)
input double strategy_wpr_ob_level       = -20.0;  // overbought threshold (short resume)
input int    strategy_entry_buffer_pips  = 1;      // stop-order offset beyond signal extreme
input int    strategy_sl_structure_bars  = 10;     // swing-extreme lookback for the SL
input int    strategy_sl_cap_pips        = 100;    // P2 cap on the structural SL distance
input int    strategy_pending_expiry_bars = 1;     // D1 bars a stop order stays live
input double strategy_trail_trigger_rr   = 2.0;    // start trailing after this R multiple
input int    strategy_trail_sma_period   = 5;      // SMA used for the trailing stop
input double strategy_spread_pct_of_stop = 25.0;   // skip if spread > this % of stop distance

// File-scope: initial per-position risk distance (entry->SL) captured at fill,
// used for the trail_trigger_rr test. Re-derived from the live position if 0.
double g_initial_risk_distance = 0.0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Count this EA's live pending stop orders on the current symbol.
int QM_Local_PendingCount(const int magic)
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      ++n;
     }
   return n;
  }

// Remove this EA's live pending stop orders on the current symbol (a fresh
// signal bar supersedes a still-unfilled order, and avoids GTC dangling).
void QM_Local_CancelPending(const int magic, const string reason)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on it

   // Reference stop distance for the spread cap = the SL cap distance.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic. If a position is open, drop any stale pending and
   // do not stack a new entry.
   if(QM_TM_OpenPositionCount(magic) > 0)
     {
      QM_Local_CancelPending(magic, "position_open_supersede");
      return false;
     }

   // A new closed bar arrived: any still-unfilled stop order from a prior signal
   // bar is now stale — cancel it so this bar's evaluation owns the decision.
   if(QM_Local_PendingCount(magic) > 0)
      QM_Local_CancelPending(magic, "new_bar_supersede");

   // --- Trend STATE: EMA slope over the lookback window (closed bars) ---
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_past = QM_EMA(_Symbol, _Period, strategy_ema_period,
                                  1 + strategy_ema_slope_lookback);
   if(ema_now <= 0.0 || ema_past <= 0.0)
      return false;

   const bool uptrend   = (ema_now > ema_past);
   const bool downtrend = (ema_now < ema_past);
   if(!uptrend && !downtrend)
      return false;

   // --- Williams %R pullback-resume EVENT (single cross-back trigger) ---
   const double wpr_sig  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1); // signal bar
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2); // bar before
   // WPR is bounded [-100, 0]; 0.0 is a valid extreme so guard on the bound, not >0.
   if(wpr_sig < -100.5 || wpr_prev < -100.5)
      return false;

   QM_OrderType side;
   double extreme;        // signal-bar high (long) or low (short)
   double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_buffer_pips);
   if(buffer <= 0.0)
      return false;

   if(uptrend &&
      wpr_prev <= strategy_wpr_os_level && wpr_sig > strategy_wpr_os_level)
     {
      side    = QM_BUY_STOP;
      extreme = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(extreme <= 0.0)
         return false;
      req.price = QM_TM_NormalizePrice(_Symbol, extreme + buffer);
     }
   else if(downtrend &&
           wpr_prev >= strategy_wpr_ob_level && wpr_sig < strategy_wpr_ob_level)
     {
      side    = QM_SELL_STOP;
      extreme = iLow(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(extreme <= 0.0)
         return false;
      req.price = QM_TM_NormalizePrice(_Symbol, extreme - buffer);
     }
   else
      return false;

   if(req.price <= 0.0)
      return false;

   // --- Stop loss: structural swing extreme before the signal bar, capped ---
   const QM_OrderType dir = QM_OrderTypeIsBuy(side) ? QM_BUY : QM_SELL;
   double sl = QM_StopStructure(_Symbol, dir, req.price, strategy_sl_structure_bars);
   if(sl <= 0.0)
      return false;

   // Apply the P2 cap: never risk more than sl_cap_pips from the entry price.
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_dist > 0.0)
     {
      if(dir == QM_BUY && (req.price - sl) > cap_dist)
         sl = QM_TM_NormalizePrice(_Symbol, req.price - cap_dist);
      else if(dir == QM_SELL && (sl - req.price) > cap_dist)
         sl = QM_TM_NormalizePrice(_Symbol, req.price + cap_dist);
     }

   // Reject degenerate stops (SL on the wrong side / zero distance).
   if(dir == QM_BUY && !(sl < req.price))
      return false;
   if(dir == QM_SELL && !(sl > req.price))
      return false;

   req.type   = side;
   req.sl     = sl;
   req.tp     = 0.0;  // exit is the SMA5 trail, not a fixed TP
   req.expiration_seconds = strategy_pending_expiry_bars * 24 * 60 * 60; // D1 bars
   req.reason = (side == QM_BUY_STOP) ? "robles_wpr_long_stop" : "robles_wpr_short_stop";
   return true;
  }

// SMA5 trailing stop, armed once price has reached trail_trigger_rr * initial
// risk in profit. Trail to the SMA only after two consecutive closes on the
// profitable side of the SMA (per the card). Closed-bar cadence via latch.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_initial_risk_distance = 0.0;
      return;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long   ptype     = PositionGetInteger(POSITION_TYPE);
      const double entry      = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl      = PositionGetDouble(POSITION_SL);
      const bool   is_long     = (ptype == POSITION_TYPE_BUY);

      // (Re)capture the initial risk distance from the live SL if not latched.
      if(g_initial_risk_distance <= 0.0 && cur_sl > 0.0)
         g_initial_risk_distance = MathAbs(entry - cur_sl);
      if(g_initial_risk_distance <= 0.0)
         continue; // cannot evaluate the RR trigger without a risk reference

      const double price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(price <= 0.0)
         continue;

      const double profit_dist = is_long ? (price - entry) : (entry - price);
      if(profit_dist < strategy_trail_trigger_rr * g_initial_risk_distance)
         continue; // not yet at the trail-trigger R multiple

      // Two consecutive closes on the profitable side of the SMA5 (closed bars).
      const double sma   = QM_SMA(_Symbol, _Period, strategy_trail_sma_period, 1);
      if(sma <= 0.0)
         continue;
      const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
      if(close1 <= 0.0 || close2 <= 0.0)
         continue;

      bool confirm = false;
      if(is_long)
         confirm = (close1 > sma && close2 > sma);
      else
         confirm = (close1 < sma && close2 < sma);
      if(!confirm)
         continue;

      // Trail the SL to the SMA only in the favourable direction (never loosen).
      const double new_sl = QM_TM_NormalizePrice(_Symbol, sma);
      if(is_long)
        {
         if(new_sl > cur_sl && new_sl < price)
            QM_TM_MoveSL(ticket, new_sl, "sma5_trail_long");
        }
      else
        {
         if((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > price)
            QM_TM_MoveSL(ticket, new_sl, "sma5_trail_short");
        }
     }
  }

// No discretionary exit beyond the SMA5 trail / structural SL.
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
