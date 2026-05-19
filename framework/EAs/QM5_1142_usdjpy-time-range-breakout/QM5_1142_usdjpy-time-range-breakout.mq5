#property strict
#property version   "5.0"
#property description "QM5_1142 USDJPY Time-Range Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                            = 1142;
input int    qm_magic_slot_offset                = 0;

input group "Risk"
input double RISK_PERCENT                        = 0.0;
input double RISK_FIXED                          = 1000.0;
input double PORTFOLIO_WEIGHT                    = 1.0;

input group "News"
input QM_NewsMode qm_news_mode                   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled             = true;
input int    qm_friday_close_hour_broker         = 21;

input group "Strategy"
input int    strategy_range_start_hour_broker    = 22;
input int    strategy_range_start_minute         = 0;
input int    strategy_range_duration_minutes     = 240;
input int    strategy_hold_minutes_max           = 480;
input int    strategy_exit_hour_broker           = 22;
input int    strategy_atr_period                 = 14;
input double strategy_atr_stop_mult              = 2.0;
input double strategy_atr_target_mult            = 0.0;
input bool   strategy_long_only                  = false;
input bool   strategy_short_only                 = false;
input int    strategy_max_spread_points          = 30;
input double strategy_min_range_atr_ratio        = 0.5;
input double strategy_max_range_atr_ratio        = 3.0;
input bool   strategy_enable_friday              = false;
input bool   strategy_skip_news_hour             = true;
input int    strategy_breakout_buffer_points     = 5;
input int    strategy_session_filter_hour_to     = 22;

datetime g_last_order_session_close = 0;
datetime g_last_evaluated_session_close = 0;
datetime g_last_force_flat_marker = 0;

int ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

int TimeOfDayMinutes(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

datetime BrokerMidnight(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime BrokerDateTimeAtHour(const datetime anchor, const int hour)
  {
   MqlDateTime dt;
   TimeToStruct(anchor, dt);
   dt.hour = ClampInt(hour, 0, 23);
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool HasOpenPositionForMagic()
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

int PendingOrderCountForMagic()
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
      if((int)OrderGetInteger(ORDER_MAGIC) == magic)
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

int DeletePendingOrdersForMagic(const string reason)
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
      if(DeletePendingOrder(ticket, reason))
         ++deleted;
     }
   return deleted;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M30)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   return (spread_points > (double)MathMax(1, strategy_max_spread_points));
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!strategy_skip_news_hour)
      return false;
   if(!QM_NewsIsAvailable())
      return false;
   return !QM_NewsAllowsTrade(_Symbol, broker_time, QM_NEWS_FTMO_PAUSE);
  }

bool ResolveLatestClosedRange(const datetime broker_now, datetime &range_start, datetime &range_close)
  {
   const int start_hour = ClampInt(strategy_range_start_hour_broker, 0, 23);
   const int start_min = ClampInt(strategy_range_start_minute, 0, 59);
   const int duration = ClampInt(strategy_range_duration_minutes, 30, 480);
   const int start_offset = start_hour * 60 + start_min;

   const datetime today_midnight = BrokerMidnight(broker_now);
   datetime best_start = 0;
   datetime best_close = 0;

   for(int day_offset = -1; day_offset <= 0; ++day_offset)
     {
      const datetime candidate_start = today_midnight + day_offset * 86400 + start_offset * 60;
      const datetime candidate_close = candidate_start + duration * 60;
      if(candidate_close <= broker_now && candidate_close > best_close)
        {
         best_start = candidate_start;
         best_close = candidate_close;
        }
     }

   if(best_start <= 0 || best_close <= 0)
      return false;

   range_start = best_start;
   range_close = best_close;
   return true;
  }

datetime ResolveOrderExpiration(const datetime range_close)
  {
   const int hold_minutes = ClampInt(strategy_hold_minutes_max, 60, 720);
   const datetime hold_expiry = range_close + hold_minutes * 60;

   datetime exit_time = BrokerDateTimeAtHour(range_close, strategy_exit_hour_broker);
   if(exit_time <= range_close)
      exit_time += 86400;

   return (exit_time < hold_expiry) ? exit_time : hold_expiry;
  }

bool IsEntryTimeAllowed(const datetime range_close, const datetime broker_now, const datetime expiry_time)
  {
   if(broker_now >= expiry_time)
      return false;

   const int filter_hour = ClampInt(strategy_session_filter_hour_to, 0, 23);
   const int now_minutes = TimeOfDayMinutes(broker_now);
   if(now_minutes > filter_hour * 60 + 59)
      return false;

   if(!strategy_enable_friday)
     {
      MqlDateTime dt;
      TimeToStruct(range_close, dt);
      if(dt.day_of_week == 5)
         return false;
     }

   return true;
  }

bool ComputeRange(const datetime range_start,
                  const datetime range_close,
                  double &range_high,
                  double &range_low)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_M1, range_start, range_close - 1, rates); // perf-allowed: called only after the M30 QM_IsNewBar gate.
   if(copied <= 0)
      return false;

   range_high = 0.0;
   range_low = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0)
         return false;
      if(range_high <= 0.0 || rates[i].high > range_high)
         range_high = rates[i].high;
      if(range_low <= 0.0 || rates[i].low < range_low)
         range_low = rates[i].low;
     }

   return (range_high > range_low && range_low > 0.0);
  }

bool ValidateRangeAgainstATR(const double range_high, const double range_low, const double atr)
  {
   if(atr <= 0.0)
      return false;

   const double range_size = range_high - range_low;
   const double ratio = range_size / atr;
   if(strategy_min_range_atr_ratio > 0.0 && ratio < strategy_min_range_atr_ratio)
      return false;
   if(strategy_max_range_atr_ratio > 0.0 && ratio > strategy_max_range_atr_ratio)
      return false;
   return true;
  }

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildEntryRequests(QM_EntryRequest &long_req,
                        QM_EntryRequest &short_req,
                        datetime &range_close)
  {
   InitEntryRequest(long_req);
   InitEntryRequest(short_req);

   const datetime broker_now = TimeCurrent();
   datetime range_start = 0;
   if(!ResolveLatestClosedRange(broker_now, range_start, range_close))
      return false;
   if(range_close == g_last_evaluated_session_close)
      return false;
   g_last_evaluated_session_close = range_close;

   const datetime expiry_time = ResolveOrderExpiration(range_close);
   if(!IsEntryTimeAllowed(range_close, broker_now, expiry_time))
      return false;
   if(HasOpenPositionForMagic() || PendingOrderCountForMagic() > 0)
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!ComputeRange(range_start, range_close, range_high, range_low))
      return false;

   const int atr_period = MathMax(1, strategy_atr_period);
   const double atr = QM_ATR(_Symbol, PERIOD_M30, atr_period, 1);
   if(!ValidateRangeAgainstATR(range_high, range_low, atr))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   const double buffer = MathMax(0, strategy_breakout_buffer_points) * point;
   const double long_entry = QM_TM_NormalizePrice(_Symbol, range_high + buffer);
   const double short_entry = QM_TM_NormalizePrice(_Symbol, range_low - buffer);
   if(long_entry <= 0.0 || short_entry <= 0.0 || long_entry <= short_entry)
      return false;

   const int expiration_seconds = MathMax(60, (int)(expiry_time - broker_now));
   const double target_mult = MathMax(0.0, strategy_atr_target_mult);

   long_req.type = QM_BUY_STOP;
   long_req.price = long_entry;
   long_req.sl = QM_TM_NormalizePrice(_Symbol, long_entry - atr * strategy_atr_stop_mult);
   long_req.tp = (target_mult > 0.0) ? QM_TM_NormalizePrice(_Symbol, long_entry + atr * target_mult) : 0.0;
   long_req.reason = "QM5_1142_RANGE_BREAKOUT_LONG";
   long_req.symbol_slot = qm_magic_slot_offset;
   long_req.expiration_seconds = expiration_seconds;

   short_req.type = QM_SELL_STOP;
   short_req.price = short_entry;
   short_req.sl = QM_TM_NormalizePrice(_Symbol, short_entry + atr * strategy_atr_stop_mult);
   short_req.tp = (target_mult > 0.0) ? QM_TM_NormalizePrice(_Symbol, short_entry - atr * target_mult) : 0.0;
   short_req.reason = "QM5_1142_RANGE_BREAKOUT_SHORT";
   short_req.symbol_slot = qm_magic_slot_offset;
   short_req.expiration_seconds = expiration_seconds;

   if(long_req.sl <= 0.0 || long_req.sl >= long_entry)
      return false;
   if(short_req.sl <= short_entry)
      return false;
   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   QM_EntryRequest short_req;
   datetime range_close = 0;
   if(!BuildEntryRequests(req, short_req, range_close))
      return false;
   if(strategy_short_only)
      req = short_req;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(HasOpenPositionForMagic())
      DeletePendingOrdersForMagic("opposite_order_after_fill");
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.hour < ClampInt(strategy_exit_hour_broker, 0, 23))
      return false;

   const datetime marker = BrokerDateTimeAtHour(broker_now, strategy_exit_hour_broker);
   if(marker == g_last_force_flat_marker)
      return false;

   g_last_force_flat_marker = marker;
   DeletePendingOrdersForMagic("forced_flat");
   return HasOpenPositionForMagic();
  }

void Strategy_PlaceRangeOrders()
  {
   QM_EntryRequest long_req;
   QM_EntryRequest short_req;
   datetime range_close = 0;
   if(!BuildEntryRequests(long_req, short_req, range_close))
      return;

   int opened = 0;
   ulong out_ticket = 0;
   if(!strategy_short_only && QM_TM_OpenPosition(long_req, out_ticket))
      ++opened;
   out_ticket = 0;
   if(!strategy_long_only && QM_TM_OpenPosition(short_req, out_ticket))
      ++opened;

   if(opened > 0)
     {
      g_last_order_session_close = range_close;
      QM_LogEvent(QM_INFO,
                  "RANGE_ORDERS_PLACED",
                  StringFormat("{\"range_close\":%I64d,\"orders\":%d}", (long)range_close, opened));
     }
  }

int OnInit()
  {
   if(strategy_long_only && strategy_short_only)
     {
      Print("QM5_1142 invalid inputs: long_only and short_only cannot both be true.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1142\",\"ea\":\"usdjpy-time-range-breakout\"}");
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
      DeletePendingOrdersForMagic("friday_close");
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, PERIOD_M30))
      return;

   Strategy_PlaceRangeOrders();
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
