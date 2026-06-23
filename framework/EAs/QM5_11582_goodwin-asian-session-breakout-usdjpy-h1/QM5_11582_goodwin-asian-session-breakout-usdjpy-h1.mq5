#property strict
#property version   "5.0"
#property description "QM5_11582 Goodwin Asian Session Breakout USDJPY H1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11582;
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
input int    strategy_session_start_broker_minute = 0;     // 17:00 ET = 00:00 broker
input int    strategy_range_cutoff_broker_minute  = 270;   // 21:30 ET = 04:30 broker
input int    strategy_h1_order_gate_broker_minute = 300;   // first H1 gate after 04:30
input int    strategy_pending_expiry_broker_minute = 390;  // 23:30 ET = 06:30 broker
input int    strategy_eod_exit_broker_minute      = 1430;  // 16:50 ET = 23:50 broker
input int    strategy_sl_pips                     = 150;
input int    strategy_spread_cap_pips             = 20;

int g_order_session_key = 0;

int Strategy_MinuteOfDay(const datetime value)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_TimeAtMinute(datetime reference_time, const int minute_of_day)
  {
   int minute = minute_of_day;
   if(minute < 0)
      minute = 0;
   if(minute > 1439)
      minute = 1439;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(reference_time, dt);
   dt.hour = minute / 60;
   dt.min = minute % 60;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_SessionTime(datetime reference_time, const int minute_of_day)
  {
   datetime session_time = Strategy_TimeAtMinute(reference_time, minute_of_day);
   const int now_min = Strategy_MinuteOfDay(reference_time);

   if(strategy_session_start_broker_minute > strategy_range_cutoff_broker_minute &&
      now_min < strategy_range_cutoff_broker_minute)
      session_time -= 86400;

   return session_time;
  }

bool Strategy_InWrapWindow(const int minute_now, const int start_minute, const int end_minute)
  {
   if(start_minute == end_minute)
      return false;
   if(start_minute < end_minute)
      return (minute_now >= start_minute && minute_now < end_minute);
   return (minute_now >= start_minute || minute_now < end_minute);
  }

bool Strategy_HasOurPendingOrder()
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

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }

   return false;
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
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_ReadPriorD1Direction(int &direction)
  {
   direction = 0;
   MqlRates d1[];
   ArraySetAsSeries(d1, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, d1); // perf-allowed: one closed D1 bar for card direction filter
   if(copied != 1)
      return false;
   if(d1[0].close > d1[0].open)
      direction = 1;
   else if(d1[0].close < d1[0].open)
      direction = -1;
   return (direction != 0);
  }

bool Strategy_ReadSessionRange(const datetime range_start,
                               const datetime range_end,
                               double &session_high,
                               double &session_low)
  {
   session_high = 0.0;
   session_low = 0.0;
   if(range_end <= range_start)
      return false;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_M1, range_start, range_end, rates); // perf-allowed: bounded M1 structural range scan once per H1 gate
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0)
         continue;
      if(session_high <= 0.0 || rates[i].high > session_high)
         session_high = rates[i].high;
      if(session_low <= 0.0 || rates[i].low < session_low)
         session_low = rates[i].low;
     }

   return (session_high > 0.0 && session_low > 0.0 && session_high > session_low);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(ask > bid && cap > 0.0 && (ask - bid) > cap)
      return true;

   return false;
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0 || Strategy_HasOurPendingOrder())
      return false;

   const datetime now = TimeCurrent();
   const int now_min = Strategy_MinuteOfDay(now);
   if(now_min != strategy_h1_order_gate_broker_minute)
      return false;

   const datetime range_start = Strategy_SessionTime(now, strategy_session_start_broker_minute);
   const datetime range_cutoff = Strategy_SessionTime(now, strategy_range_cutoff_broker_minute);
   const datetime range_end = range_cutoff - 60;
   const datetime expiry_time = Strategy_SessionTime(now, strategy_pending_expiry_broker_minute);
   if(expiry_time <= now)
      return false;

   const int session_key = Strategy_DateKey(range_cutoff);
   if(g_order_session_key == session_key)
      return false;

   int direction = 0;
   if(!Strategy_ReadPriorD1Direction(direction))
      return false;

   double session_high = 0.0;
   double session_low = 0.0;
   if(!Strategy_ReadSessionRange(range_start, range_end, session_high, session_low))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(direction > 0)
     {
      const bool already_triggered = (ask >= session_high);
      const double entry = already_triggered ? ask : session_high;
      const QM_OrderType order_type = already_triggered ? QM_BUY : QM_BUY_STOP;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      if(sl <= 0.0)
         return false;

      req.type = order_type;
      req.price = already_triggered ? 0.0 : QM_StopRulesNormalizePrice(_Symbol, entry);
      req.sl = sl;
      req.tp = 0.0;
      req.reason = already_triggered ? "goodwin_long_stop_filled_before_h1_gate" : "goodwin_long_buy_stop";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = already_triggered ? 0 : (int)(expiry_time - now);
      g_order_session_key = session_key;
      return true;
     }

   if(direction < 0)
     {
      const bool already_triggered = (bid <= session_low);
      const double entry = already_triggered ? bid : session_low;
      const QM_OrderType order_type = already_triggered ? QM_SELL : QM_SELL_STOP;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      if(sl <= 0.0)
         return false;

      req.type = order_type;
      req.price = already_triggered ? 0.0 : QM_StopRulesNormalizePrice(_Symbol, entry);
      req.sl = sl;
      req.tp = 0.0;
      req.reason = already_triggered ? "goodwin_short_stop_filled_before_h1_gate" : "goodwin_short_sell_stop";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = already_triggered ? 0 : (int)(expiry_time - now);
      g_order_session_key = session_key;
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int now_min = Strategy_MinuteOfDay(TimeCurrent());
   if(!Strategy_InWrapWindow(now_min, strategy_h1_order_gate_broker_minute, strategy_pending_expiry_broker_minute))
      Strategy_RemoveOurPendingOrders("goodwin_pending_expired");
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int now_min = Strategy_MinuteOfDay(TimeCurrent());
   return !Strategy_InWrapWindow(now_min,
                                 strategy_h1_order_gate_broker_minute,
                                 strategy_eod_exit_broker_minute);
  }

// News Filter Hook
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
