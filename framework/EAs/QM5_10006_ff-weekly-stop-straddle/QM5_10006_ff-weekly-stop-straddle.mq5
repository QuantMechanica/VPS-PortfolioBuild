#property strict
#property version   "5.0"
#property description "QM5_10006 ForexFactory weekly stop straddle"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10006;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 23;

input group "Strategy"
input int    strategy_entry_offset_pips   = 50;
input int    strategy_fx_sl_pips          = 30;
input int    strategy_atr_period          = 14;
input double strategy_xau_sl_atr_mult     = 0.60;
input double strategy_weekly_range_atr_min = 1.00;
input double strategy_weekly_range_atr_max = 3.50;
input int    strategy_max_spread_points   = 80;

datetime g_armed_week_open = 0;

int MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 60 + dt.min);
  }

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return 10.0 * point;
   return point;
  }

bool IsXauSymbol()
  {
   return (StringFind(_Symbol, "XAU") >= 0);
  }

bool HasOurOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool IsOurPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool HasOurPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

bool DeleteOrderByTicket(const ulong ticket, const string reason)
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
               "PENDING_CANCEL",
               StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
                            ticket,
                            QM_LoggerEscapeJson(reason),
                            ok ? "true" : "false",
                            result.retcode,
                            QM_LoggerEscapeJson(error_class)));
   return ok;
  }

void CancelOurPendingStops(const string reason)
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
      if(!IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      DeleteOrderByTicket(ticket, reason);
     }
  }

bool IsPlacementWindow(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.day_of_week == 0)
      return (dt.hour >= 22);
   if(dt.day_of_week == 1)
      return true;
   return false;
  }

bool IsFridayCloseWindow(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return (dt.day_of_week == 5 && dt.hour >= qm_friday_close_hour_broker);
  }

int SecondsToFridayClose(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   int days_to_friday = 5 - dt.day_of_week;
   if(days_to_friday < 0)
      days_to_friday += 7;

   MqlDateTime close_dt = dt;
   close_dt.hour = qm_friday_close_hour_broker;
   close_dt.min = 0;
   close_dt.sec = 0;
   datetime close_time = StructToTime(close_dt) + (days_to_friday * 86400);
   if(close_time <= broker_time)
      close_time += 7 * 86400;
   return (int)(close_time - broker_time);
  }

bool WeeklyRangeAllowsEntry()
  {
   const double pwh = iHigh(_Symbol, PERIOD_W1, 1);
   const double pwl = iLow(_Symbol, PERIOD_W1, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_W1, strategy_atr_period, 1);
   if(pwh <= 0.0 || pwl <= 0.0 || atr <= 0.0 || pwh <= pwl)
      return false;

   const double range = pwh - pwl;
   return (range >= strategy_weekly_range_atr_min * atr &&
           range <= strategy_weekly_range_atr_max * atr);
  }

bool BuildStopRequest(const QM_OrderType type,
                      const double price,
                      const int expiration_seconds,
                      const string reason,
                      QM_EntryRequest &req)
  {
   req.type = type;
   req.price = NormalizeDouble(price, _Digits);
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   req.reason = reason;

   const double pip = PipSize();
   if(pip <= 0.0 || req.price <= 0.0)
      return false;

   if(IsXauSymbol())
     {
      const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
      if(atr_h4 <= 0.0)
         return false;
      req.sl = (type == QM_BUY_STOP)
               ? req.price - strategy_xau_sl_atr_mult * atr_h4
               : req.price + strategy_xau_sl_atr_mult * atr_h4;
     }
   else
     {
      req.sl = QM_StopFixedPips(_Symbol, type, req.price, strategy_fx_sl_pips);
     }

   req.sl = NormalizeDouble(req.sl, _Digits);
   return (req.sl > 0.0);
  }

// No Trade Filter (time, spread, news): central news runs before this hook;
// entry-time is enforced in Strategy_EntrySignal and spread is checked here.
bool Strategy_NoTradeFilter()
  {
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;
   return false;
  }

// Trade Entry: prior-week OCO buy-stop/sell-stop straddle.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   const datetime week_open = iTime(_Symbol, PERIOD_W1, 0);
   if(week_open <= 0 || g_armed_week_open == week_open)
      return false;
   if(!IsPlacementWindow(broker_now))
      return false;
   if(HasOurOpenPosition() || HasOurPendingStops())
      return false;
   if(!WeeklyRangeAllowsEntry())
      return false;

   const double pip = PipSize();
   const double pwh = iHigh(_Symbol, PERIOD_W1, 1);
   const double pwl = iLow(_Symbol, PERIOD_W1, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip <= 0.0 || pwh <= 0.0 || pwl <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double buy_stop = pwh + strategy_entry_offset_pips * pip;
   const double sell_stop = pwl - strategy_entry_offset_pips * pip;
   if(buy_stop <= ask + point || sell_stop >= bid - point)
      return false;

   const int expiry_seconds = SecondsToFridayClose(broker_now);
   if(expiry_seconds <= 0)
      return false;

   QM_EntryRequest buy_req;
   if(!BuildStopRequest(QM_BUY_STOP, buy_stop, expiry_seconds, "FF_WEEKLY_BUY_STOP", buy_req))
      return false;
   if(!BuildStopRequest(QM_SELL_STOP, sell_stop, expiry_seconds, "FF_WEEKLY_SELL_STOP", req))
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   g_armed_week_open = week_open;
   return true;
  }

// Trade Management: enforce OCO cancellation once either side is filled.
void Strategy_ManageOpenPosition()
  {
   if(HasOurOpenPosition())
     {
      CancelOurPendingStops("oco_peer_cancel");
      return;
     }

   if(IsFridayCloseWindow(TimeCurrent()))
      CancelOurPendingStops("friday_expiry");
  }

// Trade Close: no TP; positions close at Friday 17:00 New York, approximated by
// the broker Friday close hour configured for the framework.
bool Strategy_ExitSignal()
  {
   return (HasOurOpenPosition() && IsFridayCloseWindow(TimeCurrent()));
  }

// News Filter Hook: no custom override; defer to the central framework filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10006\",\"ea\":\"ff-weekly-stop-straddle\"}");
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
