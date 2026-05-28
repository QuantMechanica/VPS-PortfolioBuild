#property strict
#property version   "5.0"
#property description "QM5_1148 Unger DAX gap reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1148;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_timeframe_minutes       = 30;
input int    strategy_session_start_hour      = 8;
input int    strategy_session_start_minute    = 0;
input int    strategy_session_end_hour        = 22;
input int    strategy_session_end_minute      = 0;
input int    strategy_cancel_bars             = 3;
input int    strategy_atr_period_m30          = 14;
input int    strategy_gap_atr_period_d1       = 14;
input double strategy_min_gap_atr_d1_mult     = 0.25;
input double strategy_sl_atr_mult             = 1.0;
input double strategy_tp_atr_mult             = 1.0;
input int    strategy_preclose_flatten_minutes = 5;
input int    strategy_spread_max_points       = 60;

const string STRATEGY_SYMBOL = "GDAXI.DWX";

int g_day_key = 0;
int g_armed_day_key = 0;
int g_trade_day_key = 0;
int g_cancel_day_key = 0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
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

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_SessionStartMin()
  {
   return strategy_session_start_hour * 60 + strategy_session_start_minute;
  }

int Strategy_SessionEndMin()
  {
   return strategy_session_end_hour * 60 + strategy_session_end_minute;
  }

datetime Strategy_TimeAtMinute(const datetime anchor, const int minute_of_day)
  {
   MqlDateTime dt;
   TimeToStruct(anchor, dt);
   dt.hour = MathMax(0, MathMin(23, minute_of_day / 60));
   dt.min = MathMax(0, MathMin(59, minute_of_day % 60));
   dt.sec = 0;
   return StructToTime(dt);
  }

void Strategy_RefreshDayState(const datetime broker_time)
  {
   const int key = Strategy_DayKey(broker_time);
   if(key != g_day_key)
      g_day_key = key;
  }

bool Strategy_IsSupportedSymbol()
  {
   return (_Symbol == STRATEGY_SYMBOL);
  }

bool Strategy_IsSupportedTimeframe()
  {
   return (_Period == PERIOD_M30 && strategy_timeframe_minutes == 30);
  }

bool Strategy_IsInsideSession(const datetime broker_time)
  {
   const int minute = Strategy_MinutesOfDay(broker_time);
   return (minute >= Strategy_SessionStartMin() && minute < Strategy_SessionEndMin());
  }

bool Strategy_IsAfterCancelWindow(const datetime broker_time)
  {
   const int cancel_min = Strategy_SessionStartMin() + MathMax(1, strategy_cancel_bars) * strategy_timeframe_minutes;
   return (Strategy_MinutesOfDay(broker_time) >= cancel_min);
  }

bool Strategy_IsPreClose(const datetime broker_time)
  {
   return (Strategy_MinutesOfDay(broker_time) >= Strategy_SessionEndMin() - strategy_preclose_flatten_minutes);
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

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_max_points <= 0)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return true;
   return (spread <= strategy_spread_max_points);
  }

bool Strategy_SessionRangeForDaysAgo(const int days_ago, double &out_high, double &out_low, double &out_close)
  {
   out_high = 0.0;
   out_low = 0.0;
   out_close = 0.0;
   if(days_ago <= 0)
      return false;

   const datetime target_day = Strategy_DayStart(TimeCurrent()) - (datetime)(days_ago * 86400);
   const int target_key = Strategy_DayKey(target_day);
   const int start_min = Strategy_SessionStartMin();
   const int end_min = Strategy_SessionEndMin();
   datetime last_bar_time = 0;
   bool found = false;

   const int bars = Bars(_Symbol, PERIOD_M30);
   const int max_scan = MathMin(bars - 1, 3000);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_M30, shift);
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

      const double high = iHigh(_Symbol, PERIOD_M30, shift);
      const double low = iLow(_Symbol, PERIOD_M30, shift);
      const double close = iClose(_Symbol, PERIOD_M30, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high <= low)
         continue;

      if(!found)
        {
         out_high = high;
         out_low = low;
         found = true;
        }
      else
        {
         if(high > out_high)
            out_high = high;
         if(low < out_low)
            out_low = low;
        }

      if(bar_time > last_bar_time)
        {
         last_bar_time = bar_time;
         out_close = close;
        }
     }

   return (found && out_high > out_low && out_close > 0.0);
  }

bool Strategy_PreviousSession(double &out_high, double &out_low, double &out_close)
  {
   for(int days_ago = 1; days_ago <= 10; ++days_ago)
      if(Strategy_SessionRangeForDaysAgo(days_ago, out_high, out_low, out_close))
         return true;
   return false;
  }

bool Strategy_FirstSessionBar(double &bar_open, double &bar_high, double &bar_low)
  {
   const datetime day_start = Strategy_DayStart(TimeCurrent());
   const datetime session_start = Strategy_TimeAtMinute(day_start, Strategy_SessionStartMin());
   const int shift = iBarShift(_Symbol, PERIOD_M30, session_start, false);
   if(shift < 1)
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_M30, shift);
   if(Strategy_DayKey(bar_time) != Strategy_DayKey(day_start))
      return false;
   if(Strategy_MinutesOfDay(bar_time) != Strategy_SessionStartMin())
      return false;

   bar_open = iOpen(_Symbol, PERIOD_M30, shift);
   bar_high = iHigh(_Symbol, PERIOD_M30, shift);
   bar_low = iLow(_Symbol, PERIOD_M30, shift);
   return (bar_open > 0.0 && bar_high > 0.0 && bar_low > 0.0 && bar_high > bar_low);
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

   if(strategy_tp_atr_mult > 0.0)
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, type, req.price, atr_value * strategy_tp_atr_mult);

   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(type == QM_BUY_STOP && (req.sl >= req.price || req.tp <= req.price))
      return false;
   if(type == QM_SELL_STOP && (req.sl <= req.price || req.tp >= req.price))
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsSupportedSymbol())
      return true;
   if(!Strategy_IsSupportedTimeframe())
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
   if(strategy_cancel_bars < 1 || strategy_cancel_bars > 12)
      return true;
   if(strategy_preclose_flatten_minutes < 0 || strategy_preclose_flatten_minutes >= (Strategy_SessionEndMin() - Strategy_SessionStartMin()))
      return true;
   if(strategy_atr_period_m30 <= 0 || strategy_gap_atr_period_d1 <= 0)
      return true;
   if(strategy_min_gap_atr_d1_mult < 0.0 || strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
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

   if(g_armed_day_key == g_day_key || g_trade_day_key == g_day_key)
      return false;
   if(!Strategy_IsInsideSession(broker_now) || Strategy_IsAfterCancelWindow(broker_now))
      return false;
   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrders())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double prev_high = 0.0;
   double prev_low = 0.0;
   double prev_close = 0.0;
   if(!Strategy_PreviousSession(prev_high, prev_low, prev_close))
      return false;

   double first_open = 0.0;
   double first_high = 0.0;
   double first_low = 0.0;
   if(!Strategy_FirstSessionBar(first_open, first_high, first_low))
      return false;

   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_gap_atr_period_d1, 1);
   const double m30_atr = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period_m30, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(d1_atr <= 0.0 || m30_atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double gap_abs = MathAbs(first_open - prev_close);
   if(gap_abs < strategy_min_gap_atr_d1_mult * d1_atr)
      return false;

   const int cancel_min = Strategy_SessionStartMin() + MathMax(1, strategy_cancel_bars) * strategy_timeframe_minutes;
   const int expiration_seconds = (cancel_min - Strategy_MinutesOfDay(broker_now)) * 60;
   if(expiration_seconds <= 0)
      return false;

   if(first_open > prev_high)
     {
      const double sell_stop = first_low;
      if(sell_stop >= bid - point)
         return false;
      if(!Strategy_BuildStopRequest(QM_SELL_STOP, sell_stop, m30_atr, expiration_seconds, "QM5_1148_GAP_UP_FADE", req))
         return false;
     }
   else if(first_open < prev_low)
     {
      const double buy_stop = first_high;
      if(buy_stop <= ask + point)
         return false;
      if(!Strategy_BuildStopRequest(QM_BUY_STOP, buy_stop, m30_atr, expiration_seconds, "QM5_1148_GAP_DOWN_FADE", req))
         return false;
     }
   else
      return false;

   g_armed_day_key = g_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_RefreshDayState(broker_now);

   if(Strategy_HasOpenPosition())
     {
      g_trade_day_key = g_day_key;
      Strategy_CancelPendingOrders("one_trade_per_day");
      return;
     }

   if(Strategy_IsAfterCancelWindow(broker_now) && g_cancel_day_key != g_day_key)
     {
      Strategy_CancelPendingOrders("first_three_m30_bars_expired");
      g_cancel_day_key = g_day_key;
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_RefreshDayState(broker_now);
   return (Strategy_HasOpenPosition() && (!Strategy_IsInsideSession(broker_now) || Strategy_IsPreClose(broker_now)));
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1148\",\"ea\":\"unger-dax-gap-reversal\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
      ulong ticket = 0;
      QM_TM_OpenPosition(req, ticket);
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
