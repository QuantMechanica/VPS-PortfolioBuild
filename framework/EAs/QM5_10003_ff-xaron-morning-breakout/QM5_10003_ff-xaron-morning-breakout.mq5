#property strict
#property version   "5.0"
#property description "QM5_10003 ForexFactory Xaron Morning Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10003;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_M30;
input int    strategy_cet_range_hour     = 9;
input int    strategy_cet_range_minute   = 0;
input int    strategy_cet_time_stop_hour = 20;
input int    strategy_atr_period         = 14;
input double strategy_min_range_atr_mult = 0.3;
input double strategy_max_range_atr_mult = 2.5;
input double strategy_sl_range_mult      = 0.9;
input double strategy_tp_range_mult      = 0.0;
input int    strategy_pending_hours      = 24;
input int    strategy_max_spread_points  = 0;

int ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

datetime BrokerToFixedCET(const datetime broker_time)
  {
   return QM_BrokerToUTC(broker_time) + 3600;
  }

bool IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

int OurPendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

bool DeletePendingOrder(const ulong ticket, const string reason)
  {
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   request.symbol = _Symbol;
   request.comment = reason;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);
   QM_LogEvent(ok ? QM_INFO : QM_WARN,
               "PENDING_DELETE",
               StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
                            ticket,
                            QM_LoggerEscapeJson(reason),
                            ok ? "true" : "false",
                            result.retcode,
                            QM_LoggerEscapeJson(error_class)));
   return ok;
  }

int DeleteOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(DeletePendingOrder(ticket, reason))
         ++deleted;
     }
   return deleted;
  }

void DeleteExpiredPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int max_age_seconds = MathMax(1, strategy_pending_hours) * 3600;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= max_age_seconds)
         DeletePendingOrder(ticket, "one_trading_day_expiry");
     }
  }

bool CurrentSpread(double &spread_price, double &spread_points)
  {
   spread_price = 0.0;
   spread_points = 0.0;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || point <= 0.0)
      return false;

   spread_price = ask - bid;
   spread_points = spread_price / point;
   return true;
  }

bool LastClosedBarIsRangeBar()
  {
   const datetime bar_open = iTime(_Symbol, strategy_timeframe, 1);
   if(bar_open <= 0)
      return false;

   MqlDateTime cet;
   TimeToStruct(BrokerToFixedCET(bar_open), cet);
   return (cet.hour == ClampInt(strategy_cet_range_hour, 0, 23) &&
           cet.min == ClampInt(strategy_cet_range_minute, 0, 59));
  }

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(3600, strategy_pending_hours * 3600);
  }

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   double spread_price = 0.0;
   double spread_points = 0.0;
   if(!CurrentSpread(spread_price, spread_points))
      return true;
   if(strategy_max_spread_points > 0 && spread_points > (double)strategy_max_spread_points)
      return true;

   return false;
  }

// Trade Entry: 09:00-09:30 fixed-CET M30 breakout stop orders.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitEntryRequest(req);
   DeleteExpiredPendingStops();

   if(strategy_timeframe != PERIOD_M30)
      return false;
   if(HasOurOpenPosition() || OurPendingStopCount() > 0)
      return false;
   if(!LastClosedBarIsRangeBar())
      return false;

   double spread_price = 0.0;
   double spread_points = 0.0;
   if(!CurrentSpread(spread_price, spread_points))
      return false;

   const double range_high = iHigh(_Symbol, strategy_timeframe, 1);
   const double range_low = iLow(_Symbol, strategy_timeframe, 1);
   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   const double range_size = range_high - range_low;
   const double atr = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0)
      return false;
   if(range_size < strategy_min_range_atr_mult * atr)
      return false;
   if(range_size > strategy_max_range_atr_mult * atr)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_sl_range_mult <= 0.0)
      return false;

   const double sl_distance = strategy_sl_range_mult * range_size;
   const double buy_entry = QM_TM_NormalizePrice(_Symbol, range_high + spread_price);
   const double sell_entry = QM_TM_NormalizePrice(_Symbol, range_low - spread_price);
   if(buy_entry <= 0.0 || sell_entry <= 0.0 || buy_entry <= sell_entry)
      return false;

   QM_EntryRequest buy_req;
   InitEntryRequest(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = QM_TM_NormalizePrice(_Symbol, buy_entry - sl_distance);
   buy_req.tp = (strategy_tp_range_mult > 0.0) ? QM_TM_NormalizePrice(_Symbol, buy_entry + strategy_tp_range_mult * range_size) : 0.0;
   buy_req.reason = "XARON_MORNING_BREAKOUT_BUY_STOP";

   req.type = QM_SELL_STOP;
   req.price = sell_entry;
   req.sl = QM_TM_NormalizePrice(_Symbol, sell_entry + sl_distance);
   req.tp = (strategy_tp_range_mult > 0.0) ? QM_TM_NormalizePrice(_Symbol, sell_entry - strategy_tp_range_mult * range_size) : 0.0;
   req.reason = "XARON_MORNING_BREAKOUT_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(3600, strategy_pending_hours * 3600);

   if(buy_req.sl <= 0.0 || buy_req.sl >= buy_entry)
      return false;
   if(req.sl <= sell_entry)
      return false;

   ulong ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, ticket))
      return false;

   return true;
  }

// Trade Management: cancel opposite pending after fill, then trail last two M30 bars after +1R.
void Strategy_ManageOpenPosition()
  {
   DeleteExpiredPendingStops();
   if(!HasOurOpenPosition())
      return;

   DeleteOurPendingStops("opposite_order_after_fill");

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double risk = MathAbs(open_price - current_sl);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double profit_distance = is_buy ? (market - open_price) : (open_price - market);
      if(risk <= 0.0 || profit_distance < risk)
         continue;

      const double low1 = iLow(_Symbol, strategy_timeframe, 1);
      const double low2 = iLow(_Symbol, strategy_timeframe, 2);
      const double high1 = iHigh(_Symbol, strategy_timeframe, 1);
      const double high2 = iHigh(_Symbol, strategy_timeframe, 2);
      if(low1 <= 0.0 || low2 <= 0.0 || high1 <= 0.0 || high2 <= 0.0)
         continue;

      const double raw_trail = is_buy ? MathMin(low1, low2) : MathMax(high1, high2);
      const double new_sl = QM_TM_NormalizePrice(_Symbol, raw_trail);
      if(new_sl <= 0.0)
         continue;

      const bool improves = is_buy ? (new_sl > current_sl + point * 0.5 && new_sl < market)
                                   : (new_sl < current_sl - point * 0.5 && new_sl > market);
      if(improves)
         QM_TM_MoveSL(ticket, new_sl, "xaron_two_bar_trail_after_1r");
     }
  }

// Trade Close: same-day 20:00 fixed-CET time stop.
bool Strategy_ExitSignal()
  {
   MqlDateTime cet;
   TimeToStruct(BrokerToFixedCET(TimeCurrent()), cet);
   if(cet.hour < ClampInt(strategy_cet_time_stop_hour, 0, 23))
      return false;

   DeleteExpiredPendingStops();
   return HasOurOpenPosition();
  }

// News Filter Hook: central QM_NEWS_PAUSE handles the high-impact 30-minute blackout.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(strategy_timeframe != PERIOD_M30)
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10003\",\"ea\":\"ff-xaron-morning-breakout\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
     {
      DeleteOurPendingStops("friday_close");
      return;
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
