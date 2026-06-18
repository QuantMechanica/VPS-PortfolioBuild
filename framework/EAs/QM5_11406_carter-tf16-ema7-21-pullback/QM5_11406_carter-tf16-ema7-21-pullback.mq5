#property strict
#property version   "5.0"
#property description "QM5_11406 carter-tf16-ema7-21-pullback — EMA7/21 trend pullback, stop-order entry (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11406 carter-tf16-ema7-21-pullback
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Trend Following Systems" (2014), Strategy #16.
// Card: artifacts/cards_approved/QM5_11406_carter-tf16-ema7-21-pullback.md
//       (g0_status APPROVED).
//
// Mechanics (long + short mirror, closed-bar reads at shift 1):
//   Trend STATE  : EMA7 > EMA21 (long) AND EMA21 sloping up (ema21@1 > ema21@4,
//                  i.e. current vs 3 closed bars ago) AND close above both EMAs.
//   Pullback EVENT: within the last `pullback_lookback` closed bars (shift 1..N)
//                  the bar's Low pierced/touched EMA21 (Low[s] <= EMA21[s]). The
//                  MOST RECENT such bar is the "touch bar". This single event is
//                  the trigger; the EMA stack/slope/close are STATES — they are
//                  never required to be a same-bar second cross (avoids the
//                  two-cross zero-trade trap).
//   Entry        : BUYSTOP at High[touch_bar] + 1 point. Order rides the bounce
//                  off EMA21 dynamic support; fills only if price breaks the
//                  touch bar's high.
//   Stop         : structure stop = lowest Low over `sl_lookback` bars ending at
//                  the touch bar; risk distance capped at `sl_cap_pips`.
//   Take profit  : `tp_rr` x risk distance (RR multiple, Carter default 2.0).
//   Cancel rule  : a live pending order is removed if the trend invalidates
//                  (EMA7 crosses to the wrong side of EMA21) before it triggers.
//   Spread guard : fail-OPEN on .DWX zero modeled spread; block only a genuinely
//                  wide spread > `spread_pct_of_stop` of the stop distance.
//
// SHORT is the exact mirror (EMA7<EMA21, slope down, close below both, High[s]>=
// EMA21[s] touch, SELLSTOP at Low[touch]-1 point, structure = highest High).
//
// One position OR one pending order per symbol/magic at any time (no stacking).
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11406;
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
input int    strategy_ema_fast_period     = 7;     // fast EMA (trend / pullback ref)
input int    strategy_ema_slow_period     = 21;    // slow EMA = dynamic S/R for pullback
input int    strategy_slope_lookback      = 3;     // EMA21 slope: shift1 vs shift(1+N) closed bars
input int    strategy_pullback_lookback   = 3;     // bars (shift 1..N) scanned for the EMA21 touch
input int    strategy_sl_lookback         = 5;     // structure stop: extreme over N bars to touch bar
input int    strategy_sl_cap_pips         = 70;    // P2 hard cap on risk distance (pips)
input double strategy_tp_rr               = 2.0;   // take-profit = RR x risk distance
input int    strategy_entry_buffer_pips   = 0;     // extra buffer above/below trigger (0 = +1 point)
input int    strategy_pending_expiry_bars = 3;     // cancel un-triggered pending after N bars
input double strategy_spread_pct_of_stop  = 15.0;  // block only spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal helpers (order/pending bookkeeping for THIS magic + symbol).
// OrdersTotal/OrderGet* are the MQL5 trade API (not market-data iX readers) and
// are the sanctioned way to inspect pending orders.
// -----------------------------------------------------------------------------

// Ticket of the live pending order for this magic+symbol, or 0 if none.
ulong PendingOrderTicket()
  {
   const long magic = (long)QM_FrameworkMagic();
   const int total = OrdersTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP)
         return ticket;
     }
   return 0;
  }

// +1 = current pending is a BUYSTOP, -1 = SELLSTOP, 0 = none.
int PendingOrderSide()
  {
   const ulong ticket = PendingOrderTicket();
   if(ticket == 0)
      return 0;
   if(!OrderSelect(ticket))
      return 0;
   const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   if(ot == ORDER_TYPE_BUY_STOP)
      return 1;
   if(ot == ORDER_TYPE_SELL_STOP)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on it

   const double atr_value = QM_ATR(_Symbol, _Period, 14, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = 2.0 * atr_value; // ATR-scaled reference for the cap
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on a closed bar. Places a single BUYSTOP / SELLSTOP pending order.
// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position OR one pending order per symbol/magic — never stack.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(PendingOrderTicket() != 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double buffer = (strategy_entry_buffer_pips > 0)
                         ? QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_buffer_pips)
                         : point; // default: 1 point above/below the trigger bar

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_slow_prior = QM_EMA(_Symbol, _Period, strategy_ema_slow_period,
                                        1 + strategy_slope_lookback);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || ema_slow_prior <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // ===================== LONG setup =====================
   const bool long_trend = (ema_fast > ema_slow) &&
                           (ema_slow > ema_slow_prior) &&
                           (close1 > ema_fast) &&
                           (close1 > ema_slow);
   if(long_trend)
     {
      // Pullback EVENT: most recent closed bar (shift 1..N) whose Low touched/
      // pierced EMA21. perf-allowed single-shift reads inside a bounded loop.
      int touch = -1;
      for(int s = 1; s <= strategy_pullback_lookback; ++s)
        {
         const double low_s  = iLow(_Symbol, _Period, s);   // perf-allowed
         const double ema_s  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
         if(low_s <= 0.0 || ema_s <= 0.0)
            continue;
         if(low_s <= ema_s)
           {
            touch = s;
            break; // most recent touch
           }
        }
      if(touch >= 0)
        {
         const double trigger_high = iHigh(_Symbol, _Period, touch); // perf-allowed
         if(trigger_high > 0.0)
           {
            const double entry = trigger_high + buffer;
            // BUYSTOP must sit above the current ask, else broker rejects it.
            if(entry > ask)
              {
               // Structure stop = lowest Low over sl_lookback bars ending at the
               // touch bar (shifts touch .. touch+sl_lookback-1).
               double sl = QM_StopStructure(_Symbol, QM_BUY, entry,
                                            touch + strategy_sl_lookback - 1);
               if(sl > 0.0 && sl < entry)
                 {
                  // Cap risk distance at sl_cap_pips.
                  const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                                          strategy_sl_cap_pips);
                  if(cap_dist > 0.0 && (entry - sl) > cap_dist)
                     sl = QM_StopRulesNormalizePrice(_Symbol, entry - cap_dist);

                  const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
                  if(sl > 0.0 && tp > 0.0)
                    {
                     req.type   = QM_BUY_STOP;
                     req.price  = QM_StopRulesNormalizePrice(_Symbol, entry);
                     req.sl     = sl;
                     req.tp     = tp;
                     req.reason = "carter_tf16_long";
                     req.expiration_seconds = strategy_pending_expiry_bars *
                                              PeriodSeconds(_Period);
                     return true;
                    }
                 }
              }
           }
        }
     }

   // ===================== SHORT setup (mirror) =====================
   const bool short_trend = (ema_fast < ema_slow) &&
                            (ema_slow < ema_slow_prior) &&
                            (close1 < ema_fast) &&
                            (close1 < ema_slow);
   if(short_trend)
     {
      int touch = -1;
      for(int s = 1; s <= strategy_pullback_lookback; ++s)
        {
         const double high_s = iHigh(_Symbol, _Period, s);  // perf-allowed
         const double ema_s  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
         if(high_s <= 0.0 || ema_s <= 0.0)
            continue;
         if(high_s >= ema_s)
           {
            touch = s;
            break; // most recent touch
           }
        }
      if(touch >= 0)
        {
         const double trigger_low = iLow(_Symbol, _Period, touch); // perf-allowed
         if(trigger_low > 0.0)
           {
            const double entry = trigger_low - buffer;
            // SELLSTOP must sit below the current bid, else broker rejects it.
            if(entry > 0.0 && entry < bid)
              {
               double sl = QM_StopStructure(_Symbol, QM_SELL, entry,
                                            touch + strategy_sl_lookback - 1);
               if(sl > entry)
                 {
                  const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                                          strategy_sl_cap_pips);
                  if(cap_dist > 0.0 && (sl - entry) > cap_dist)
                     sl = QM_StopRulesNormalizePrice(_Symbol, entry + cap_dist);

                  const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
                  if(sl > 0.0 && tp > 0.0)
                    {
                     req.type   = QM_SELL_STOP;
                     req.price  = QM_StopRulesNormalizePrice(_Symbol, entry);
                     req.sl     = sl;
                     req.tp     = tp;
                     req.reason = "carter_tf16_short";
                     req.expiration_seconds = strategy_pending_expiry_bars *
                                              PeriodSeconds(_Period);
                     return true;
                    }
                 }
              }
           }
        }
     }

   return false;
  }

// Cancel a live pending order if the trend invalidates before it triggers.
// Position SL/TP are broker-attached on the pending order, so no per-tick
// position management is needed. This runs per tick but is O(1)+cheap.
void Strategy_ManageOpenPosition()
  {
   const int side = PendingOrderSide();
   if(side == 0)
      return; // no pending order to police

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return;

   bool invalidated = false;
   if(side > 0 && ema_fast < ema_slow)       // long pending, EMA7 fell below EMA21
      invalidated = true;
   else if(side < 0 && ema_fast > ema_slow)  // short pending, EMA7 rose above EMA21
      invalidated = true;

   if(invalidated)
     {
      const ulong ticket = PendingOrderTicket();
      if(ticket != 0)
         QM_TM_RemovePendingOrder(ticket, "carter_tf16_trend_invalidated");
     }
  }

// No discretionary close — exits are the broker-attached SL/TP on the position.
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
