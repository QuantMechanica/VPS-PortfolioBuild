#property strict
#property version   "5.0"
#property description "QM5_11874 USDJPY 24hr range breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11874 usdjpy-24hr-range-breakout
// -----------------------------------------------------------------------------
// Card: D:/QM/strategy_farm/artifacts/cards_approved/
//       QM5_11874_usdjpy-24hr-range-breakout.md (g0_status APPROVED)
//
// Mechanical translation:
//   At the H1 bar whose open time is 6pm EST (23:00 UTC outside US DST,
//   22:00 UTC during US DST), scan the prior 24 completed H1 bars.
//   Place both pending stops:
//      buy stop  = 24h high + 7 pips
//      sell stop = 24h low  - 7 pips
//   Each order has 25-pip SL, 50-pip TP, and 24-hour expiry. If one side
//   triggers, remove the opposite pending order. No trailing or discretionary
//   exit exists in the card.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11874;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_range_hours          = 24;
input int    strategy_setup_hour_utc_std   = 23;
input int    strategy_setup_hour_utc_dst   = 22;
input int    strategy_breakout_offset_pips = 7;
input int    strategy_sl_pips              = 25;
input int    strategy_tp_pips              = 50;
input int    strategy_order_expiry_hours   = 24;

bool QM11874_IsSetupBar()
  {
   // perf-allowed: bar-open time is required to avoid exact tick-minute gates;
   // no framework helper exposes current bar open time.
   const datetime bar_open_broker = iTime(_Symbol, _Period, 0); // perf-allowed
   if(bar_open_broker <= 0)
      return false;

   const datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   MqlDateTime dt;
   TimeToStruct(bar_open_utc, dt);

   const int setup_hour = QM_IsUSDSTUTC(bar_open_utc)
                          ? strategy_setup_hour_utc_dst
                          : strategy_setup_hour_utc_std;
   return (dt.hour == setup_hour && dt.min == 0);
  }

bool QM11874_ReadPriorRange(double &range_high, double &range_low)
  {
   range_high = 0.0;
   range_low = 0.0;

   if(strategy_range_hours <= 0)
      return false;

   bool have_bar = false;
   for(int shift = 1; shift <= strategy_range_hours; ++shift)
     {
      // perf-allowed: bounded 24-bar H1 range scan at setup only; no QM_High
      // or QM_Low reader exists in the framework.
      const double h = iHigh(_Symbol, _Period, shift); // perf-allowed
      const double l = iLow(_Symbol, _Period, shift); // perf-allowed
      if(h <= 0.0 || l <= 0.0 || h < l)
         return false;

      if(!have_bar)
        {
         range_high = h;
         range_low = l;
         have_bar = true;
        }
      else
        {
         if(h > range_high)
            range_high = h;
         if(l < range_low)
            range_low = l;
        }
     }

   return (have_bar && range_high > range_low);
  }

bool QM11874_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }

   return false;
  }

bool QM11874_IsOurPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int QM11874_PendingStopCount()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!QM11874_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      ++count;
     }

   return count;
  }

void QM11874_RemovePendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!QM11874_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool QM11874_BuildStopRequest(const QM_OrderType type,
                              const double entry_price,
                              const string reason,
                              QM_EntryRequest &req)
  {
   req.type = type;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry_price);
   req.sl = QM_StopFixedPips(_Symbol, type, req.price, strategy_sl_pips);
   req.tp = QM_TakeFixedPips(_Symbol, type, req.price, strategy_tp_pips);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_order_expiry_hours * 60 * 60;

   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(strategy_sl_pips <= 0 || strategy_tp_pips <= 0 || req.expiration_seconds <= 0)
      return false;

   return true;
  }

// No Trade Filter (time, spread, news): the card adds no extra session or spread
// gate beyond the daily setup hour and central framework news/Friday filters.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: daily 6pm EST prior-24-hour range breakout stop straddle.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!QM11874_IsSetupBar())
      return false;

   if(QM11874_HasOpenPosition())
     {
      QM11874_RemovePendingStops("oco_position_live");
      return false;
     }

   QM11874_RemovePendingStops("daily_setup_refresh");

   double range_high = 0.0;
   double range_low = 0.0;
   if(!QM11874_ReadPriorRange(range_high, range_low))
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_offset_pips);
   if(offset <= 0.0)
      return false;

   if(!QM11874_BuildStopRequest(QM_BUY_STOP,
                                range_high + offset,
                                "range_breakout_buy_stop",
                                req))
      return false;

   QM_EntryRequest sell_req;
   if(!QM11874_BuildStopRequest(QM_SELL_STOP,
                                range_low - offset,
                                "range_breakout_sell_stop",
                                sell_req))
      return false;

   ulong sell_ticket = 0;
   ulong buy_ticket = 0;
   const bool sell_ok = QM_TM_OpenPosition(sell_req, sell_ticket);
   const bool buy_ok = QM_TM_OpenPosition(req, buy_ticket);
   if(!sell_ok || !buy_ok)
      QM11874_RemovePendingStops("incomplete_oco_pair");

   return false;
  }

// Trade Management: cancel the opposite pending stop after either side triggers.
void Strategy_ManageOpenPosition()
  {
   if(QM11874_HasOpenPosition())
      QM11874_RemovePendingStops("oco_triggered");
  }

// Trade Close: no discretionary close; fixed SL/TP and framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: central framework news filter handles configured blackout.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
