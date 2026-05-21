#property strict
#property version   "5.0"
#property description "QM5_10048 ForexFactory Toby Inside-Bar D1 Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10048;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe  = PERIOD_D1;
input int    strategy_sma_period          = 21;
input double strategy_entry_buffer_pips   = 5.0;
input double strategy_rr_multiple         = 2.0;
input double strategy_max_spread_stop_frac = 0.12;
input int    strategy_pending_days        = 1;

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

bool CurrentSpread(double &spread_price)
  {
   spread_price = 0.0;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   spread_price = ask - bid;
   return true;
  }

string BaseSymbol()
  {
   string symbol = _Symbol;
   const int dot_pos = StringFind(symbol, ".");
   if(dot_pos >= 0)
      symbol = StringSubstr(symbol, 0, dot_pos);
   return symbol;
  }

double StopDistance()
  {
   const string symbol = BaseSymbol();
   double stop_pips = 50.0;
   if(symbol == "GBPUSD" || symbol == "USDCAD")
      stop_pips = 60.0;
   else if(symbol == "EURJPY")
      stop_pips = 90.0;
   else if(symbol == "GBPJPY")
      stop_pips = 100.0;

   const double pip = PipDistance();
   if(pip <= 0.0)
      return 0.0;

   double stop_distance = stop_pips * pip;
   if(symbol != "EURUSD" && symbol != "USDCHF" && symbol != "NZDUSD" &&
      symbol != "AUDUSD" && symbol != "USDJPY" && symbol != "GBPUSD" &&
      symbol != "USDCAD" && symbol != "EURJPY" && symbol != "GBPJPY")
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, 14, 1);
      if(atr > 0.0)
         stop_distance = MathMax(stop_distance, 1.25 * atr);
     }
   return stop_distance;
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
   const int max_age_seconds = MathMax(1, strategy_pending_days) * 86400;
   const datetime now = TimeCurrent();
   const int magic = QM_FrameworkMagic();
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
         DeletePendingOrder(ticket, "pending_one_day_expiry");
     }
  }

int SmaSlope()
  {
   const double sma_1 = QM_SMA(_Symbol, strategy_timeframe, MathMax(1, strategy_sma_period), 1, PRICE_CLOSE);
   const double sma_2 = QM_SMA(_Symbol, strategy_timeframe, MathMax(1, strategy_sma_period), 2, PRICE_CLOSE);
   if(sma_1 <= 0.0 || sma_2 <= 0.0)
      return 0;
   if(sma_1 > sma_2)
      return 1;
   if(sma_1 < sma_2)
      return -1;
   return 0;
  }

void CancelPendingStopsOnSlopeFlip()
  {
   const int slope = SmaSlope();
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP && slope <= 0)
         DeletePendingOrder(ticket, "sma_slope_flip_before_fill");
      else if(order_type == ORDER_TYPE_SELL_STOP && slope >= 0)
         DeletePendingOrder(ticket, "sma_slope_flip_before_fill");
     }
  }

bool InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_pending_days) * 86400;
   return true;
  }

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   double spread_price = 0.0;
   if(!CurrentSpread(spread_price))
      return true;

   const double stop_distance = StopDistance();
   if(stop_distance <= 0.0)
      return true;
   if(strategy_max_spread_stop_frac > 0.0 && spread_price > strategy_max_spread_stop_frac * stop_distance)
      return true;

   return false;
  }

// Trade Entry: completed D1 inside bar with SMA(21) slope stop-entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitEntryRequest(req);
   DeleteExpiredPendingStops();
   CancelPendingStopsOnSlopeFlip();

   if(strategy_timeframe != PERIOD_D1)
      return false;
   if(HasOurOpenPosition() || OurPendingStopCount() > 0)
      return false;

   const double high_1 = iHigh(_Symbol, strategy_timeframe, 1);
   const double low_1 = iLow(_Symbol, strategy_timeframe, 1);
   const double high_2 = iHigh(_Symbol, strategy_timeframe, 2);
   const double low_2 = iLow(_Symbol, strategy_timeframe, 2);
   if(high_1 <= 0.0 || low_1 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0)
      return false;
   if(!(high_1 < high_2 && low_1 > low_2))
      return false;

   double spread_price = 0.0;
   if(!CurrentSpread(spread_price))
      return false;

   const double pip = PipDistance();
   const double stop_distance = StopDistance();
   if(pip <= 0.0 || stop_distance <= 0.0 || strategy_rr_multiple <= 0.0)
      return false;
   if(strategy_max_spread_stop_frac > 0.0 && spread_price > strategy_max_spread_stop_frac * stop_distance)
      return false;

   const int slope = SmaSlope();
   const double buffer = strategy_entry_buffer_pips * pip;
   if(slope > 0)
     {
      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, high_1 + buffer + spread_price);
      req.sl = QM_TM_NormalizePrice(_Symbol, req.price - stop_distance);
      req.tp = QM_TM_NormalizePrice(_Symbol, req.price + strategy_rr_multiple * stop_distance);
      req.reason = "TOBY_INSIDE_D1_BUY_STOP";
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0 && req.sl < req.price);
     }
   if(slope < 0)
     {
      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, low_1 - buffer - spread_price);
      req.sl = QM_TM_NormalizePrice(_Symbol, req.price + stop_distance);
      req.tp = QM_TM_NormalizePrice(_Symbol, req.price - strategy_rr_multiple * stop_distance);
      req.reason = "TOBY_INSIDE_D1_SELL_STOP";
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0 && req.sl > req.price);
     }

   return false;
  }

// Trade Management: cancel stale/flipped pending stops; no trailing or partials in card.
void Strategy_ManageOpenPosition()
  {
   DeleteExpiredPendingStops();
   CancelPendingStopsOnSlopeFlip();
  }

// Trade Close: opposite pending setup closes existing position before SL/TP.
bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;

   const double high_1 = iHigh(_Symbol, strategy_timeframe, 1);
   const double low_1 = iLow(_Symbol, strategy_timeframe, 1);
   const double high_2 = iHigh(_Symbol, strategy_timeframe, 2);
   const double low_2 = iLow(_Symbol, strategy_timeframe, 2);
   if(high_1 <= 0.0 || low_1 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0)
      return false;
   if(!(high_1 < high_2 && low_1 > low_2))
      return false;

   const int slope = SmaSlope();
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && slope < 0)
         return true;
      if(position_type == POSITION_TYPE_SELL && slope > 0)
         return true;
     }

   return false;
  }

// News Filter Hook: no card-specific override beyond framework news mode.
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10048\",\"ea\":\"ff-toby-inside-d1\"}");
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
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
      return;

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
      return;
     }

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
