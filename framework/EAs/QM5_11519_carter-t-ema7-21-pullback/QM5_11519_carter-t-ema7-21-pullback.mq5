#property strict
#property version   "5.0"
#property description "QM5_11519 carter-t-ema7-21-pullback — EMA(7/21) trend + pullback BuyStop/SellStop (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11519 carter-t-ema7-21-pullback
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #16, self-published 2014.
// Card: artifacts/cards_approved/QM5_11519_carter-t-ema7-21-pullback.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1 default):
//   Trend STATE (long) : EMA(7) > EMA(21)  AND  EMA(21) rising (shift1 > shift3)
//                        AND  close[1] > EMA(7).
//   Pullback STATE     : bar[1] low touched EMA(21) from above (low[1] <= EMA21).
//   Trigger EVENT      : a BuyStop pending order 1 pip ABOVE bar[1] high. The
//                        order fills only if upside momentum RESUMES through the
//                        pullback bar's high. The stop fill IS the resume event,
//                        so the EMA stack is the STATE and the order fill is the
//                        single trigger EVENT — this avoids the two-cross-same-bar
//                        zero-trade trap (we never require two fresh crosses).
//   Short is the mirror (EMA7<EMA21, EMA21 falling, price below, pullback up to
//                        EMA21, SellStop 1 pip below bar[1] low).
//   Expiry             : pending order expires after expiry_bars closed bars.
//   Stop               : sl_pips fixed pips from the stop trigger price.
//   Take profit        : tp_rr * SL distance (RR multiple, card 2R).
//   Spread guard       : block only a genuinely wide spread (fail-open on .DWX
//                        zero modeled spread).
//   No Friday entry    : new entries suppressed on Fridays (card filter).
//
// One pending order OR one open position per magic (single-entry path).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11519;
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
input int    strategy_ema_fast_period   = 7;      // trend fast EMA
input int    strategy_ema_slow_period   = 21;     // trend slow EMA
input int    strategy_ema_rising_lookback = 3;    // EMA(slow) rising/falling lookback (shift 1 vs this)
input int    strategy_sl_pips           = 25;     // stop-loss distance in pips (card default; P2 cap 30)
input double strategy_tp_rr             = 2.0;    // take-profit = tp_rr * SL distance
input int    strategy_pending_offset_pips = 1;    // BuyStop above high / SellStop below low, in pips
input int    strategy_expiry_bars       = 3;      // pending-order lifetime in closed bars
input bool   strategy_no_friday_entry   = true;   // suppress new entries on Fridays
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Count live pending orders (BuyStop/SellStop) for this EA's magic on this
// symbol. Order-bookkeeping only — not strategy/indicator math — so the native
// order calls are appropriate here. Used to enforce one-pending-per-magic so
// the EA does not stack a new stop order on every closed bar while the trend +
// pullback state persists.
int CountPendingOrders(const int magic)
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      ++n;
     }
   return n;
  }

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap (fixed-pip stop).
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
// Places a single pending stop order per closed bar when the trend+pullback
// state aligns. One pending order OR one open position per magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();

   // Single-entry discipline: never stack. If a position OR a live pending
   // order already exists for this magic, do nothing.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(CountPendingOrders(magic) > 0)
      return false;

   // Card filter: no new entries on Fridays (broker time).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == FRIDAY)
         return false;
     }

   // --- EMA state (closed bar = shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // EMA(slow) slope reference (shift = rising_lookback, default 3).
   const int slope_shift = (strategy_ema_rising_lookback > 1 ? strategy_ema_rising_lookback : 2);
   const double ema_slow_back = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, slope_shift);
   if(ema_slow_back <= 0.0)
      return false;

   // Closed-bar OHLC of the pullback bar (shift 1). Single closed-bar reads.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_pending_offset_pips);
   if(offset <= 0.0)
      return false;

   const int expiry_seconds = strategy_expiry_bars * PeriodSeconds(_Period);

   // --- LONG: uptrend + pullback to EMA21, BuyStop above bar[1] high ---
   const bool up_trend   = (ema_fast > ema_slow) && (ema_slow > ema_slow_back) && (close1 > ema_fast);
   const bool up_pullback = (low1 <= ema_slow); // bar[1] low touched EMA21 from above
   if(up_trend && up_pullback)
     {
      const double trigger = QM_TM_NormalizePrice(_Symbol, high1 + offset);
      if(trigger <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY_STOP, trigger, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY_STOP, trigger, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type               = QM_BUY_STOP;
      req.price              = trigger;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "carter_ema721_pb_long";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   // --- SHORT: downtrend + pullback up to EMA21, SellStop below bar[1] low ---
   const bool down_trend    = (ema_fast < ema_slow) && (ema_slow < ema_slow_back) && (close1 < ema_fast);
   const bool down_pullback = (high1 >= ema_slow); // bar[1] high touched EMA21 from below
   if(down_trend && down_pullback)
     {
      const double trigger = QM_TM_NormalizePrice(_Symbol, low1 - offset);
      if(trigger <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL_STOP, trigger, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL_STOP, trigger, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type               = QM_SELL_STOP;
      req.price              = trigger;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "carter_ema721_pb_short";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   return false;
  }

// Fixed SL/TP ride to completion; pending-order expiry is handled by the broker
// via req.expiration_seconds. No active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary close — exits are the fixed SL/TP attached at order placement.
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
