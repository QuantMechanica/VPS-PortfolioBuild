#property strict
#property version   "5.0"
#property description "QM5_1109 Unger Gold previous-session breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1109;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                = 336;
input string qm_news_min_impact                     = "high";
input QM_NewsMode qm_news_mode_legacy               = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_session_start_hour        = 8;
input int    strategy_session_start_minute      = 0;
input int    strategy_session_end_hour          = 22;
input int    strategy_session_end_minute        = 0;
input int    strategy_preclose_flatten_minutes  = 15;
input int    strategy_atr_period                = 14;
input double strategy_entry_buffer_atr_mult     = 0.10;
input double strategy_sl_atr_mult               = 1.50;
input bool   strategy_use_take_profit           = false;
input double strategy_tp_rr                     = 2.50;
input int    strategy_range_median_sessions     = 20;
input double strategy_min_range_median_mult     = 0.50;
input int    strategy_spread_median_days        = 20;
input double strategy_spread_max_median_mult    = 2.00;

const string STRATEGY_SYMBOL = "XAUUSD.DWX";

int  g_session_day_key = 0;
int  g_armed_day_key = 0;
bool g_trade_taken_today = false;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_SessionStartMin()
  {
   return strategy_session_start_hour * 60 + strategy_session_start_minute;
  }

int Strategy_SessionEndMin()
  {
   return strategy_session_end_hour * 60 + strategy_session_end_minute;
  }

void Strategy_RefreshDayState(const datetime broker_time)
  {
   const int key = Strategy_DayKey(broker_time);
   if(key != g_session_day_key)
     {
      g_session_day_key = key;
      g_armed_day_key = 0;
      g_trade_taken_today = false;
     }
  }

bool Strategy_IsInsideSession(const datetime broker_time)
  {
   const int now_min = Strategy_MinutesOfDay(broker_time);
   return (now_min >= Strategy_SessionStartMin() && now_min < Strategy_SessionEndMin());
  }

bool Strategy_IsFirstSessionBar(const datetime broker_time)
  {
   if(!Strategy_IsInsideSession(broker_time))
      return false;

   int grace = PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60;
   if(grace < 5)
      grace = 5;
   if(grace > 60)
      grace = 60;

   return ((Strategy_MinutesOfDay(broker_time) - Strategy_SessionStartMin()) < grace);
  }

bool Strategy_IsPreClose(const datetime broker_time)
  {
   const int flatten_min = Strategy_SessionEndMin() - strategy_preclose_flatten_minutes;
   return (Strategy_MinutesOfDay(broker_time) >= flatten_min);
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_IsOurPendingOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasPendingOrders()
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
      if(Strategy_IsOurPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelPendingOrders(const string reason)
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
      if(!Strategy_IsOurPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_SessionRangeForDaysAgo(const int days_ago, double &out_high, double &out_low)
  {
   out_high = 0.0;
   out_low = 0.0;
   if(days_ago <= 0)
      return false;

   const datetime target_day = Strategy_DayStart(TimeCurrent()) - (datetime)(days_ago * 86400);
   const int target_key = Strategy_DayKey(target_day);
   const int start_min = Strategy_SessionStartMin();
   const int end_min = Strategy_SessionEndMin();
   bool found = false;

   const int bars = Bars(_Symbol, PERIOD_M15);
   const int max_scan = MathMin(bars - 1, 3000);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_M15, shift);
      if(bar_time <= 0)
         continue;

      const int bar_key = Strategy_DayKey(bar_time);
      if(bar_key > target_key)
         continue;
      if(bar_key < target_key)
        {
         if(found)
            break;
         continue;
        }

      const int minute = Strategy_MinutesOfDay(bar_time);
      if(minute < start_min || minute >= end_min)
         continue;

      const double bar_high = iHigh(_Symbol, PERIOD_M15, shift);
      const double bar_low = iLow(_Symbol, PERIOD_M15, shift);
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high <= bar_low)
         continue;

      if(!found)
        {
         out_high = bar_high;
         out_low = bar_low;
         found = true;
        }
      else
        {
         if(bar_high > out_high)
            out_high = bar_high;
         if(bar_low < out_low)
            out_low = bar_low;
        }
     }

   return (found && out_high > out_low);
  }

bool Strategy_PreviousSessionRange(double &out_high, double &out_low)
  {
   for(int days_ago = 1; days_ago <= 10; ++days_ago)
     {
      if(Strategy_SessionRangeForDaysAgo(days_ago, out_high, out_low))
         return true;
     }
   return false;
  }

void Strategy_SortPrefix(double &values[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }
  }

double Strategy_MedianRecentSessionRange()
  {
   if(strategy_range_median_sessions <= 0 || strategy_range_median_sessions > 60)
      return 0.0;

   double ranges[60];
   int count = 0;
   for(int days_ago = 1; days_ago <= 90 && count < strategy_range_median_sessions; ++days_ago)
     {
      double high = 0.0;
      double low = 0.0;
      if(!Strategy_SessionRangeForDaysAgo(days_ago, high, low))
         continue;
      ranges[count] = high - low;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   Strategy_SortPrefix(ranges, count);
   if((count % 2) == 1)
      return ranges[count / 2];
   return 0.5 * (ranges[(count / 2) - 1] + ranges[count / 2]);
  }

bool Strategy_RangeAllowsEntry(const double prev_high, const double prev_low)
  {
   const double prev_range = prev_high - prev_low;
   if(prev_range <= 0.0)
      return false;

   const double median_range = Strategy_MedianRecentSessionRange();
   if(median_range <= 0.0)
      return false;

   return (prev_range >= strategy_min_range_median_mult * median_range);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0 || strategy_spread_median_days <= 0 || strategy_spread_median_days > 64)
      return true;

   double spreads[64];
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_median_days; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = (double)spread;
      ++count;
     }
   if(count <= 0)
      return true;

   Strategy_SortPrefix(spreads, count);
   const double median = (count % 2 == 1)
                         ? spreads[count / 2]
                         : 0.5 * (spreads[(count / 2) - 1] + spreads[count / 2]);
   if(median <= 0.0 || strategy_spread_max_median_mult <= 0.0)
      return true;
   return ((double)current_spread <= strategy_spread_max_median_mult * median);
  }

bool Strategy_BuildStopRequest(const QM_OrderType type,
                               const double price,
                               const double atr_value,
                               const int expiration_seconds,
                               const string reason,
                               QM_EntryRequest &req)
  {
   req.type = type;
   req.price = NormalizeDouble(price, _Digits);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   req.reason = reason;
   req.sl = QM_StopATRFromValue(_Symbol, type, req.price, atr_value, strategy_sl_atr_mult);
   req.tp = 0.0;

   if(strategy_use_take_profit && strategy_tp_rr > 0.0 && req.sl > 0.0)
     {
      const double risk_distance = MathAbs(req.price - req.sl);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, type, req.price, risk_distance * strategy_tp_rr);
     }

   if(req.price <= 0.0 || req.sl <= 0.0)
      return false;
   if(type == QM_BUY_STOP && req.sl >= req.price)
      return false;
   if(type == QM_SELL_STOP && req.sl <= req.price)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_M15)
      return true;
   if(strategy_session_start_hour < 0 || strategy_session_start_hour > 23)
      return true;
   if(strategy_session_end_hour < 0 || strategy_session_end_hour > 23)
      return true;
   if(strategy_session_start_minute < 0 || strategy_session_start_minute > 59)
      return true;
   if(strategy_session_end_minute < 0 || strategy_session_end_minute > 59)
      return true;
   if(Strategy_SessionEndMin() <= Strategy_SessionStartMin())
      return true;
   if(strategy_preclose_flatten_minutes < 0 || strategy_preclose_flatten_minutes >= (Strategy_SessionEndMin() - Strategy_SessionStartMin()))
      return true;
   if(strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0 || strategy_entry_buffer_atr_mult < 0.0)
      return true;
   if(strategy_range_median_sessions <= 0 || strategy_min_range_median_mult <= 0.0)
      return true;
   if(strategy_use_take_profit && strategy_tp_rr <= 0.0)
      return true;
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

   const datetime broker_now = TimeCurrent();
   Strategy_RefreshDayState(broker_now);

   if(g_trade_taken_today || g_armed_day_key == g_session_day_key)
      return false;
   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrders())
      return false;
   if(!Strategy_IsFirstSessionBar(broker_now))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double prev_high = 0.0;
   double prev_low = 0.0;
   if(!Strategy_PreviousSessionRange(prev_high, prev_low))
      return false;
   if(!Strategy_RangeAllowsEntry(prev_high, prev_low))
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr_value <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double buffer = atr_value * strategy_entry_buffer_atr_mult;
   const double buy_stop = prev_high + buffer;
   const double sell_stop = prev_low - buffer;
   if(buy_stop <= ask + point || sell_stop >= bid - point)
      return false;

   const int seconds_to_flatten = (Strategy_SessionEndMin() - strategy_preclose_flatten_minutes - Strategy_MinutesOfDay(broker_now)) * 60;
   if(seconds_to_flatten <= 0)
      return false;

   QM_EntryRequest buy_req;
   if(!Strategy_BuildStopRequest(QM_BUY_STOP,
                                 buy_stop,
                                 atr_value,
                                 seconds_to_flatten,
                                 "QM5_1109_BUY_PREV_SESSION_HIGH",
                                 buy_req))
      return false;

   if(!Strategy_BuildStopRequest(QM_SELL_STOP,
                                 sell_stop,
                                 atr_value,
                                 seconds_to_flatten,
                                 "QM5_1109_SELL_PREV_SESSION_LOW",
                                 req))
      return false;

   ulong buy_ticket = 0;
   QM_TM_OpenPosition(buy_req, buy_ticket);
   g_armed_day_key = g_session_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_RefreshDayState(broker_now);

   if(Strategy_HasOpenPosition())
     {
      g_trade_taken_today = true;
      Strategy_CancelPendingOrders("oco_peer_cancel");
      return;
     }

   if(!Strategy_IsInsideSession(broker_now) || Strategy_IsPreClose(broker_now))
      Strategy_CancelPendingOrders("session_window_closed");
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_RefreshDayState(broker_now);
   return (Strategy_HasOpenPosition() && Strategy_IsPreClose(broker_now));
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1109\",\"ea\":\"unger-gold-prev-session-breakout\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
