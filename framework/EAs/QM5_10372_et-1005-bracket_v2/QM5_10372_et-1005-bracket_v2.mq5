#property strict
#property version   "5.0"
#property description "QM5_10372 Elite Trader 10:05 High-Low Bracket v2"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10372;
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
input int    strategy_session_open_hour   = 16;
input int    strategy_session_open_min    = 30;
input int    strategy_bracket_hour        = 17;
input int    strategy_bracket_min         = 5;
input int    strategy_exit_hour           = 22;
input int    strategy_exit_min            = 0;
input int    strategy_entry_offset_ticks  = 1;
input int    strategy_stop_buffer_ticks   = 1;
input int    strategy_atr_period          = 14;
input double strategy_max_range_atr_mult  = 1.5;

int      g_trade_day_key = 0;
bool     g_range_ready = false;
bool     g_initial_orders_submitted = false;
bool     g_long_taken_today = false;
bool     g_short_taken_today = false;
double   g_range_high = 0.0;
double   g_range_low = 0.0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_InWindow(const int now_min, const int start_min, const int end_min)
  {
   if(start_min <= end_min)
      return (now_min >= start_min && now_min < end_min);
   return (now_min >= start_min || now_min < end_min);
  }

void Strategy_ResetDay(const datetime t)
  {
   const int day_key = Strategy_DayKey(t);
   if(day_key == g_trade_day_key)
      return;

   g_trade_day_key = day_key;
   g_range_ready = false;
   g_initial_orders_submitted = false;
   g_long_taken_today = false;
   g_short_taken_today = false;
   g_range_high = 0.0;
   g_range_low = 0.0;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double Strategy_CurrentSpreadPrice()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return 0.0;
   return ask - bid;
  }

bool Strategy_HasOurPosition()
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
         g_long_taken_today = true;
      if(pos_type == POSITION_TYPE_SELL)
         g_short_taken_today = true;
      return true;
     }
   return false;
  }

bool Strategy_IsOurPendingType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurPendingOrder()
  {
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
      if(Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelOurPendingOrders()
  {
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
      if(!Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;
      request.symbol = _Symbol;
      request.comment = "et_1005_cancel_pending";

      string error_class = BROKER_OTHER;
      QM_TradeContextSend(request, result, error_class);
     }
  }

int Strategy_SecondsToExit(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = strategy_exit_hour;
   dt.min = strategy_exit_min;
   dt.sec = 0;
   datetime exit_time = StructToTime(dt);
   if(exit_time <= t)
      exit_time += 86400;
   return (int)MathMax(60, exit_time - t);
  }

bool Strategy_AfterExitTime(const datetime t)
  {
   const int now_min = Strategy_MinuteOfDay(t);
   const int open_min = strategy_session_open_hour * 60 + strategy_session_open_min;
   const int exit_min = strategy_exit_hour * 60 + strategy_exit_min;
   if(open_min < exit_min)
      return (now_min >= exit_min);
   return (now_min >= exit_min && now_min < open_min);
  }

bool Strategy_RangeQualityOK()
  {
   const double range_width = g_range_high - g_range_low;
   const double spread = Strategy_CurrentSpreadPrice();
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(range_width <= 0.0 || spread <= 0.0 || atr <= 0.0)
      return false;
   if(range_width < 4.0 * spread)
      return false;
   return (range_width <= strategy_max_range_atr_mult * atr);
  }

bool Strategy_BuildRequest(const QM_OrderType type,
                           const double entry,
                           const double sl,
                           const int expiration_seconds,
                           const string reason,
                           QM_EntryRequest &req)
  {
   req.type = type;
   req.price = Strategy_NormalizePrice(entry);
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;

   if(req.sl <= 0.0)
      return false;
   if((type == QM_BUY || type == QM_BUY_STOP) && !(req.sl < ((req.price > 0.0) ? req.price : SymbolInfoDouble(_Symbol, SYMBOL_BID))))
      return false;
   if((type == QM_SELL || type == QM_SELL_STOP) && !(req.sl > ((req.price > 0.0) ? req.price : SymbolInfoDouble(_Symbol, SYMBOL_ASK))))
      return false;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetDay(now);

   if(Strategy_HasOurPosition() || Strategy_HasOurPendingOrder())
      return false;
   if(Strategy_AfterExitTime(now))
      return true;

   const int now_min = Strategy_MinuteOfDay(now);
   const int open_min = strategy_session_open_hour * 60 + strategy_session_open_min;
   const int exit_min = strategy_exit_hour * 60 + strategy_exit_min;
   return !Strategy_InWindow(now_min, open_min, exit_min);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_entry_offset_ticks < 0 ||
      strategy_stop_buffer_ticks < 0 ||
      strategy_atr_period <= 0 ||
      strategy_max_range_atr_mult <= 0.0)
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;
   Strategy_ResetDay(bar_time);
   Strategy_HasOurPosition();

   const int bar_min = Strategy_MinuteOfDay(bar_time);
   const int open_min = strategy_session_open_hour * 60 + strategy_session_open_min;
   const int bracket_min = strategy_bracket_hour * 60 + strategy_bracket_min;

   if(!g_range_ready && Strategy_InWindow(bar_min, open_min, bracket_min))
     {
      const double high = iHigh(_Symbol, _Period, 1);
      const double low = iLow(_Symbol, _Period, 1);
      if(high <= 0.0 || low <= 0.0 || high <= low)
         return false;

      if(g_range_high <= 0.0 || g_range_low <= 0.0)
        {
         g_range_high = high;
         g_range_low = low;
        }
      else
        {
         g_range_high = MathMax(g_range_high, high);
         g_range_low = MathMin(g_range_low, low);
        }
      return false;
     }

   const int now_min = Strategy_MinuteOfDay(TimeCurrent());
   if(!g_range_ready)
     {
      if(now_min < bracket_min || g_range_high <= 0.0 || g_range_low <= 0.0)
         return false;
      g_range_ready = true;
     }

   if(!Strategy_RangeQualityOK() || Strategy_HasOurPosition() || Strategy_HasOurPendingOrder())
      return false;

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      return false;

   const double entry_offset = strategy_entry_offset_ticks * tick_size;
   const double stop_buffer = strategy_stop_buffer_ticks * tick_size;
   const double buy_stop = g_range_high + entry_offset;
   const double sell_stop = g_range_low - entry_offset;
   const double buy_sl = g_range_low - stop_buffer;
   const double sell_sl = g_range_high + stop_buffer;

   if(!g_initial_orders_submitted)
     {
      QM_EntryRequest buy_req;
      if(!Strategy_BuildRequest(QM_BUY_STOP, buy_stop, buy_sl, Strategy_SecondsToExit(TimeCurrent()), "ET_1005_BRACKET_BUY_STOP", buy_req))
         return false;
      if(!Strategy_BuildRequest(QM_SELL_STOP, sell_stop, sell_sl, Strategy_SecondsToExit(TimeCurrent()), "ET_1005_BRACKET_SELL_STOP", req))
         return false;

      ulong buy_ticket = 0;
      QM_TM_OpenPosition(buy_req, buy_ticket);
      g_initial_orders_submitted = true;
      return true;
     }

   const double close_last = iClose(_Symbol, _Period, 1);
   const double close_prev = iClose(_Symbol, _Period, 2);
   if(close_last <= 0.0 || close_prev <= 0.0)
      return false;

   if(!g_long_taken_today && close_prev <= buy_stop && close_last > buy_stop)
      return Strategy_BuildRequest(QM_BUY, 0.0, buy_sl, 0, "ET_1005_BRACKET_LONG_REENTRY", req);

   if(!g_short_taken_today && close_prev >= sell_stop && close_last < sell_stop)
      return Strategy_BuildRequest(QM_SELL, 0.0, sell_sl, 0, "ET_1005_BRACKET_SHORT_REENTRY", req);

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetDay(now);

   if(Strategy_HasOurPosition() || Strategy_AfterExitTime(now))
      Strategy_CancelOurPendingOrders();
  }

// Trade Close
bool Strategy_ExitSignal()
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick_size <= 0.0)
         return false;

      if(Strategy_AfterExitTime(TimeCurrent()))
         return true;
      if(pos_type == POSITION_TYPE_BUY && bid > 0.0 && bid <= g_range_low - tick_size)
         return true;
      if(pos_type == POSITION_TYPE_SELL && ask > 0.0 && ask >= g_range_high + tick_size)
         return true;
     }
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10372_et-1005-bracket\"}");
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

