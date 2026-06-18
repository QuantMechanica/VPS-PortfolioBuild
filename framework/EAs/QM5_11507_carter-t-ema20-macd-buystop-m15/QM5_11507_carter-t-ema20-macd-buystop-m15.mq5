#property strict
#property version   "5.0"
#property description "QM5_11507 carter-t-ema20-macd-buystop-m15 — EMA20 trend + MACD zero-cross BuyStop (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11507 carter-t-ema20-macd-buystop-m15
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #2, self-published 2014.
// Card: artifacts/cards_approved/QM5_11507_carter-t-ema20-macd-buystop-m15.md
//       (g0_status APPROVED).
//
// Mechanics (M15, closed-bar reads at shift 1/2):
//   The confirming conditions are STATES; the pending-order FILL is the entry
//   EVENT. This avoids the "two crosses on one bar" zero-trade trap — nothing
//   requires two fresh cross events to coincide on a single bar.
//
//   LONG:
//     EMA20 STATE : EMA20(shift1) > EMA20(shift2)            (EMA20 rising)
//     MACD STATE  : MACD main(shift1) > 0                    (currently positive)
//                   AND MACD main crossed up through zero within the last
//                   macd_recency_bars closed bars (recent momentum turn).
//     Trigger     : BUY STOP placed entry_offset_pips above EMA20(shift1),
//                   expiring after pending_expiry_bars M15 bars. The actual
//                   break above EMA20+offset (the fill) is the entry event.
//     Stop        : entry - sl_pips   (card: 20p below EMA20 at entry).
//     Take profit : entry + sl_pips * take_rr   (card: 1:1 R/R = 20p).
//   SHORT is the mirror image (EMA20 falling, MACD negative + recent down-cross,
//     SELL STOP below EMA20).
//
//   One pending OR position per magic/symbol at a time (OCO by construction:
//   we never stack the opposite pending while one already lives, and the
//   framework blocks a duplicate open position on the same magic/symbol).
//   Stale pendings self-expire after pending_expiry_bars via ORDER_TIME_SPECIFIED.
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread passes);
// no swap gate; QM_IsNewBar consumed once (entry path only); confirmations are
// STATES with the FILL as the event; pip-scaled offsets via
// QM_StopRulesPipsToPriceDistance; no external feed; closed-bar reads only.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11507;
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
input int    strategy_ema_period          = 20;    // trend EMA period (card: EMA20)
input int    strategy_macd_fast           = 12;    // MACD fast EMA
input int    strategy_macd_slow           = 26;    // MACD slow EMA
input int    strategy_macd_signal         = 9;     // MACD signal SMA
input int    strategy_macd_recency_bars   = 5;     // MACD zero-cross recency window (P3: 3/5/7)
input int    strategy_entry_offset_pips   = 10;    // pending STOP offset from EMA20 (P3: 0/5/10/15)
input int    strategy_sl_pips             = 20;    // stop distance from fill price (P3: 15/20/25)
input double strategy_take_rr             = 1.0;   // TP = RR * SL distance (card: 1:1; P2: 1/1.5/2)
input int    strategy_pending_expiry_bars = 5;     // cancel unfilled pending after N M15 bars (P3: 3/5/7)
input bool   strategy_no_friday_entry     = true;  // card: no Friday entries
input double strategy_spread_pct_of_stop  = 75.0;  // skip only if spread > this % of stop distance

// 15-pip spread cap (card) expressed as % of the 20-pip stop = 75%. Kept as a
// %-of-stop cap so it scales with the configured stop distance.

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// pip-distance in price terms for the active symbol (5-digit / JPY safe).
double PipsToPrice(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// MACD main crossed UP through zero within [shift1 .. recency] closed bars.
// State window — a momentum turn that is "recent or current". MACD can still be
// just above zero now; we only check the sign transition between closed bars.
bool MacdCrossedUpRecently(const int recency)
  {
   for(int s = 1; s <= recency; ++s)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s);
      const double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s + 1);
      if(m_prev <= 0.0 && m_now > 0.0)
         return true;
     }
   return false;
  }

bool MacdCrossedDownRecently(const int recency)
  {
   for(int s = 1; s <= recency; ++s)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s);
      const double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s + 1);
      if(m_prev >= 0.0 && m_now < 0.0)
         return true;
     }
   return false;
  }

// True if a pending order for this EA's magic/symbol already lives.
bool HasLivePending(const int magic)
  {
   for(int oi = OrdersTotal() - 1; oi >= 0; --oi)
     {
      const ulong oticket = OrderGetTicket(oi);
      if(oticket == 0 || !OrderSelect(oticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = PipsToPrice(strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && ask > bid && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on the closed-bar path (QM_IsNewBar() == true guaranteed by caller).
// EMA20 rising + MACD positive & recently crossed zero = confirming STATES;
// the BUY/SELL STOP fill is the entry EVENT. One pending/open per magic/symbol.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   // One position per magic; do not stack a pending on top of an open position
   // or another pending (OCO by construction).
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(HasLivePending(magic))
      return false;

   // No Friday entries (card filter). Broker-time day-of-week.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   const double macd1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 1);

   const double offset  = PipsToPrice(strategy_entry_offset_pips);
   const double sl_dist = PipsToPrice(strategy_sl_pips);
   if(offset < 0.0 || sl_dist <= 0.0)
      return false;
   const int expiry_seconds = strategy_pending_expiry_bars * PeriodSeconds(_Period);

   // ---- LONG: EMA20 rising + MACD positive + recent up-cross of zero ----
   const bool ema_rising = (ema1 > ema2);
   if(ema_rising && macd1 > 0.0 && MacdCrossedUpRecently(strategy_macd_recency_bars))
     {
      const double entry_price = QM_TM_NormalizePrice(_Symbol, ema1 + offset);
      const double sl_price    = QM_TM_NormalizePrice(_Symbol, entry_price - sl_dist);
      const double tp_price    = QM_TM_NormalizePrice(_Symbol, entry_price + sl_dist * strategy_take_rr);
      if(entry_price <= 0.0 || sl_price <= 0.0 || sl_price >= entry_price)
         return false;
      if(strategy_take_rr > 0.0 && (tp_price <= 0.0 || tp_price <= entry_price))
         return false;

      req.type               = QM_BUY_STOP;
      req.price              = entry_price;
      req.sl                 = sl_price;
      req.tp                 = (strategy_take_rr > 0.0) ? tp_price : 0.0;
      req.reason             = "ema20_up_macd_buystop";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   // ---- SHORT: EMA20 falling + MACD negative + recent down-cross of zero ----
   const bool ema_falling = (ema1 < ema2);
   if(ema_falling && macd1 < 0.0 && MacdCrossedDownRecently(strategy_macd_recency_bars))
     {
      const double entry_price = QM_TM_NormalizePrice(_Symbol, ema1 - offset);
      const double sl_price    = QM_TM_NormalizePrice(_Symbol, entry_price + sl_dist);
      const double tp_price    = QM_TM_NormalizePrice(_Symbol, entry_price - sl_dist * strategy_take_rr);
      if(entry_price <= 0.0 || sl_price <= 0.0 || sl_price <= entry_price)
         return false;
      if(strategy_take_rr > 0.0 && (tp_price <= 0.0 || tp_price >= entry_price))
         return false;

      req.type               = QM_SELL_STOP;
      req.price              = entry_price;
      req.sl                 = sl_price;
      req.tp                 = (strategy_take_rr > 0.0) ? tp_price : 0.0;
      req.reason             = "ema20_down_macd_sellstop";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   return false;
  }

// Fixed SL/TP managed by the broker order; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary close beyond the fixed SL / TP.
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
