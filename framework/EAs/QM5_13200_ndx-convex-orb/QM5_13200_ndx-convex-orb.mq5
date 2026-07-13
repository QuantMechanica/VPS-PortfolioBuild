#property strict
#property version   "5.0"
#property description "QM5_13200 NDX Convex Opening-Range Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13200;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period        = 14;
input double strategy_buffer_atr        = 0.05;
input double strategy_max_range_atr     = 1.75;
input double strategy_target_rr         = 8.0;
input int    strategy_range_start_hour_ny = 9;
input int    strategy_range_bars        = 2;
input int    strategy_trigger_hour_ny   = 11;
input int    strategy_pending_end_hour_ny = 12;
input int    strategy_exit_hour_ny      = 16;

int  g_trade_day_key = 0;
bool g_orders_placed_today = false;
bool g_position_seen_today = false;

datetime Strategy_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc_time) ? -4 : -5;
   return utc_time + ny_offset_hours * 3600;
  }

bool Strategy_NewYorkParts(const datetime broker_time, MqlDateTime &parts)
  {
   if(broker_time <= 0)
      return false;
   return TimeToStruct(Strategy_BrokerToNewYork(broker_time), parts);
  }

int Strategy_NewYorkDayKey(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_NewYorkParts(broker_time, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_NewYorkHour(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_NewYorkParts(broker_time, parts))
      return -1;
   return parts.hour;
  }

bool Strategy_IsWeekdayNewYork(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_NewYorkParts(broker_time, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

void Strategy_ResetDay(const datetime broker_time)
  {
   const int day_key = Strategy_NewYorkDayKey(broker_time);
   if(day_key <= 0 || day_key == g_trade_day_key)
      return;

   g_trade_day_key = day_key;
   g_orders_placed_today = false;
   g_position_seen_today = false;
  }

bool Strategy_IsOurPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      g_position_seen_today = true;
      return true;
     }
   return false;
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int index = OrdersTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = OrderGetTicket(index);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelOurPendingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int index = OrdersTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = OrderGetTicket(index);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_HadSetupToday(const datetime broker_now)
  {
   const int day_key = Strategy_NewYorkDayKey(broker_now);
   if(day_key <= 0)
      return true;
   if(!HistorySelect(broker_now - 3 * 86400, broker_now))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int index = HistoryOrdersTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = HistoryOrderGetTicket(index);
      if(ticket == 0)
         continue;
      if((int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
         continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      if(!Strategy_IsOurPendingType((ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE)))
         continue;
      const datetime setup_time = (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP);
      if(Strategy_NewYorkDayKey(setup_time) == day_key)
         return true;
     }
   return false;
  }

double Strategy_SimpleATR(const int shift)
  {
   if(strategy_atr_period <= 0 || shift < 1)
      return 0.0;

   double total = 0.0;
   for(int offset = 0; offset < strategy_atr_period; ++offset)
     {
      const int bar_shift = shift + offset;
      const double high = iHigh(_Symbol, PERIOD_H1, bar_shift);
      const double low = iLow(_Symbol, PERIOD_H1, bar_shift);
      const double previous_close = iClose(_Symbol, PERIOD_H1, bar_shift + 1);
      if(high <= 0.0 || low <= 0.0 || previous_close <= 0.0 || high < low)
         return 0.0;
      const double true_range = MathMax(high - low,
                                        MathMax(MathAbs(high - previous_close),
                                                MathAbs(low - previous_close)));
      total += true_range;
     }
   return total / strategy_atr_period;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_BuildRequest(const QM_OrderType type,
                           const double entry,
                           const double stop,
                           const int expiration_seconds,
                           const string reason,
                           QM_EntryRequest &request)
  {
   request.type = type;
   request.price = Strategy_NormalizePrice(entry);
   request.sl = Strategy_NormalizePrice(stop);
   request.tp = QM_TakeRR(_Symbol, type, request.price, request.sl, strategy_target_rr);
   request.reason = reason;
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = expiration_seconds;

   if(request.price <= 0.0 || request.sl <= 0.0 || request.tp <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(type))
      return (request.sl < request.price && request.tp > request.price);
   return (request.sl > request.price && request.tp < request.price);
  }

bool Strategy_NoTradeFilter()
  {
   Strategy_ResetDay(TimeCurrent());
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_BUY_STOP;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(strategy_range_bars != 2 || strategy_atr_period != 14 ||
      strategy_buffer_atr <= 0.0 || strategy_max_range_atr <= 0.0 ||
      strategy_target_rr <= 0.0)
      return false;

   const datetime current_bar_time = iTime(_Symbol, PERIOD_H1, 0);
   const datetime range_second_time = iTime(_Symbol, PERIOD_H1, 1);
   const datetime range_first_time = iTime(_Symbol, PERIOD_H1, 2);
   if(current_bar_time <= 0 || range_second_time <= 0 || range_first_time <= 0)
      return false;

   Strategy_ResetDay(current_bar_time);
   const int day_key = Strategy_NewYorkDayKey(current_bar_time);
   if(day_key <= 0 || !Strategy_IsWeekdayNewYork(current_bar_time))
      return false;
   if(Strategy_NewYorkHour(current_bar_time) != strategy_trigger_hour_ny ||
      Strategy_NewYorkHour(range_second_time) != strategy_range_start_hour_ny + 1 ||
      Strategy_NewYorkHour(range_first_time) != strategy_range_start_hour_ny)
      return false;
   if(Strategy_NewYorkDayKey(range_second_time) != day_key ||
      Strategy_NewYorkDayKey(range_first_time) != day_key)
      return false;
   if(g_orders_placed_today || g_position_seen_today || Strategy_HasOurPosition() ||
      Strategy_HasOurPendingOrder() || Strategy_HadSetupToday(TimeCurrent()))
      return false;

   const double atr = Strategy_SimpleATR(1);
   const double range_high = MathMax(iHigh(_Symbol, PERIOD_H1, 1),
                                     iHigh(_Symbol, PERIOD_H1, 2));
   const double range_low = MathMin(iLow(_Symbol, PERIOD_H1, 1),
                                    iLow(_Symbol, PERIOD_H1, 2));
   const double range_width = range_high - range_low;
   if(atr <= 0.0 || range_low <= 0.0 || range_width <= 0.0 ||
      range_width > strategy_max_range_atr * atr)
      return false;

   const double buffer = strategy_buffer_atr * atr;
   const double buy_price = range_high + buffer;
   const double sell_price = range_low - buffer;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   g_orders_placed_today = true;

   // A gap through one threshold at 11:00 is a real stop fill at the first
   // available quote. Native execution uses that quote rather than the
   // research screen's ideal threshold price.
   if(ask >= buy_price && bid > sell_price)
     {
      if(!Strategy_BuildRequest(QM_BUY, ask, range_low, 0,
                                "NDX_CONVEX_ORB_GAP_BUY", request))
         return false;
      ulong ticket = 0;
      QM_TM_OpenPosition(request, ticket);
      return false;
     }
   if(bid <= sell_price && ask < buy_price)
     {
      if(!Strategy_BuildRequest(QM_SELL, bid, range_high, 0,
                                "NDX_CONVEX_ORB_GAP_SELL", request))
         return false;
      ulong ticket = 0;
      QM_TM_OpenPosition(request, ticket);
      return false;
     }
   if(ask >= buy_price || bid <= sell_price)
      return false;

   int expiration_seconds = (int)(current_bar_time + 3600 - TimeCurrent());
   if(expiration_seconds < 60)
      expiration_seconds = 60;

   QM_EntryRequest buy_request;
   QM_EntryRequest sell_request;
   if(!Strategy_BuildRequest(QM_BUY_STOP, buy_price, range_low, expiration_seconds,
                             "NDX_CONVEX_ORB_BUY_STOP", buy_request) ||
      !Strategy_BuildRequest(QM_SELL_STOP, sell_price, range_high, expiration_seconds,
                             "NDX_CONVEX_ORB_SELL_STOP", sell_request))
      return false;

   ulong buy_ticket = 0;
   ulong sell_ticket = 0;
   const bool buy_ok = QM_TM_OpenPosition(buy_request, buy_ticket);
   const bool sell_ok = QM_TM_OpenPosition(sell_request, sell_ticket);
   if(!buy_ok || !sell_ok)
      Strategy_CancelOurPendingOrders("ndx_convex_orb_incomplete_pair");
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_ResetDay(broker_now);
   const bool has_position = Strategy_HasOurPosition();
   const int ny_hour = Strategy_NewYorkHour(broker_now);
   if(has_position || ny_hour < strategy_trigger_hour_ny ||
      ny_hour >= strategy_pending_end_hour_ny)
      Strategy_CancelOurPendingOrders(has_position ? "ndx_convex_orb_oco" :
                                                     "ndx_convex_orb_expired");
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const int current_day_key = Strategy_NewYorkDayKey(broker_now);
   const int position_day_key = Strategy_NewYorkDayKey(
      (datetime)PositionGetInteger(POSITION_TIME));
   if(current_day_key <= 0 || position_day_key <= 0 ||
      current_day_key != position_day_key)
      return true;
   return (Strategy_NewYorkHour(broker_now) >= strategy_exit_hour_ny);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(_Symbol != "NDX.DWX" || _Period != PERIOD_H1)
      return INIT_PARAMETERS_INCORRECT;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13200_ndx-convex-orb\"}");
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
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
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   QM_EntryRequest request;
   Strategy_EntrySignal(request);
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
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != QM_FrameworkMagic() ||
      HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   const ENUM_DEAL_ENTRY entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
     {
      g_position_seen_today = true;
      Strategy_CancelOurPendingOrders("ndx_convex_orb_oco_fill");
     }
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
