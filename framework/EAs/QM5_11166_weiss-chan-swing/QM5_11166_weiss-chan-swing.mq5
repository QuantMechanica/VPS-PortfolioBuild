#property strict
#property version   "5.0"
#property description "QM5_11166 Weissman Channel Breakout Swing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11166;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_channel_bars = 15;
input int    strategy_exit_channel_bars  = 8;
input int    strategy_max_hold_bars      = 8;
input int    strategy_atr_period         = 20;
input double strategy_atr_mult           = 2.0;
input double strategy_min_stop_pct       = 1.0;
input double strategy_max_stop_pct       = 5.0;

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   opened = 0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened = (datetime)PositionGetInteger(POSITION_TIME);
      ticket = t;
      return true;
     }

   return false;
  }

bool Strategy_HasOurPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened;
   ulong ticket;
   return Strategy_SelectOurPosition(ptype, opened, ticket);
  }

bool Strategy_IsOurPendingOrder()
  {
   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return false;
   if((int)OrderGetInteger(ORDER_MAGIC) != QM_FrameworkMagic())
      return false;

   const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   return (type == ORDER_TYPE_BUY_STOP ||
           type == ORDER_TYPE_SELL_STOP ||
           type == ORDER_TYPE_BUY_LIMIT ||
           type == ORDER_TYPE_SELL_LIMIT);
  }

void Strategy_RemoveOurPendingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(!Strategy_IsOurPendingOrder())
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

double Strategy_HighestHigh(const int first_shift, const int bars)
  {
   if(first_shift < 1 || bars <= 0)
      return 0.0;

   double highest = -DBL_MAX;
   for(int i = 0; i < bars; ++i)
     {
      const int shift = first_shift + i;
      const double value = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 Donchian channel structural scan.
      if(value <= 0.0)
         return 0.0;
      if(value > highest)
         highest = value;
     }
   return (highest > 0.0 && highest > -DBL_MAX) ? highest : 0.0;
  }

double Strategy_LowestLow(const int first_shift, const int bars)
  {
   if(first_shift < 1 || bars <= 0)
      return 0.0;

   double lowest = DBL_MAX;
   for(int i = 0; i < bars; ++i)
     {
      const int shift = first_shift + i;
      const double value = iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 Donchian channel structural scan.
      if(value <= 0.0)
         return 0.0;
      if(value < lowest)
         lowest = value;
     }
   return (lowest > 0.0 && lowest < DBL_MAX) ? lowest : 0.0;
  }

double Strategy_StopDistance(const double entry_price)
  {
   if(entry_price <= 0.0 || strategy_atr_period <= 0 || strategy_atr_mult <= 0.0)
      return 0.0;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return 0.0;

   double distance = atr * strategy_atr_mult;
   const double min_distance = entry_price * MathMax(0.0, strategy_min_stop_pct) / 100.0;
   const double max_distance = entry_price * MathMax(strategy_min_stop_pct, strategy_max_stop_pct) / 100.0;
   if(min_distance > 0.0 && distance < min_distance)
      distance = min_distance;
   if(max_distance > 0.0 && distance > max_distance)
      distance = max_distance;
   return distance;
  }

bool Strategy_BuildEntryRequest(const QM_OrderType order_type,
                                const double entry_price,
                                const string reason,
                                QM_EntryRequest &req)
  {
   const double distance = Strategy_StopDistance(entry_price);
   if(entry_price <= 0.0 || distance <= 0.0)
      return false;

   req.type = order_type;
   req.price = NormalizeDouble(entry_price, _Digits);
   req.sl = QM_StopRulesNormalizePrice(_Symbol,
                                       QM_OrderTypeIsBuy(order_type)
                                       ? entry_price - distance
                                       : entry_price + distance);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;
   if(strategy_entry_channel_bars < 1 || strategy_exit_channel_bars < 1)
      return false;

   if(Strategy_HasOurPosition())
     {
      Strategy_RemoveOurPendingOrders("position_active_cancel_opposite_stops");
      return false;
     }

   Strategy_RemoveOurPendingOrders("refresh_d1_channel_stops");

   const double upper = Strategy_HighestHigh(1, strategy_entry_channel_bars);
   const double lower = Strategy_LowestLow(1, strategy_entry_channel_bars);
   if(upper <= 0.0 || lower <= 0.0 || upper <= lower)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   const QM_OrderType buy_type = (ask >= upper) ? QM_BUY : QM_BUY_STOP;
   const QM_OrderType sell_type = (bid <= lower) ? QM_SELL : QM_SELL_STOP;
   const double buy_entry = (buy_type == QM_BUY) ? ask : upper;
   const double sell_entry = (sell_type == QM_SELL) ? bid : lower;

   const bool have_buy = Strategy_BuildEntryRequest(buy_type, buy_entry, "WEISS_CHAN_15D_BUY_BREAKOUT", buy_req);
   const bool have_sell = Strategy_BuildEntryRequest(sell_type, sell_entry, "WEISS_CHAN_15D_SELL_BREAKOUT", sell_req);

   if(have_buy && buy_type == QM_BUY)
     {
      req = buy_req;
      return true;
     }
   if(have_sell && sell_type == QM_SELL)
     {
      req = sell_req;
      return true;
     }

   if(have_sell)
     {
      ulong sell_ticket = 0;
      QM_TM_OpenPosition(sell_req, sell_ticket);
     }
   if(have_buy)
     {
      req = buy_req;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurPosition())
      Strategy_RemoveOurPendingOrders("position_active_cancel_opposite_stops");
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened;
   ulong ticket;
   if(!Strategy_SelectOurPosition(ptype, opened, ticket))
      return false;
   if(strategy_exit_channel_bars < 1)
      return false;

   const int open_shift = iBarShift(_Symbol, PERIOD_D1, opened, false);
   if(open_shift >= strategy_max_hold_bars && strategy_max_hold_bars > 0)
      return true;

   const double exit_low = Strategy_LowestLow(1, strategy_exit_channel_bars);
   const double exit_high = Strategy_HighestHigh(1, strategy_exit_channel_bars);
   if(exit_low <= 0.0 || exit_high <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ptype == POSITION_TYPE_BUY)
      return (bid > 0.0 && bid <= exit_low);
   if(ptype == POSITION_TYPE_SELL)
      return (ask > 0.0 && ask >= exit_high);

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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
