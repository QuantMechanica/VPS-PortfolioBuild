#property strict
#property version   "5.0"
#property description "QM5_1122 Unger Crude Donchian 160"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1122;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input int    strategy_donchian_period    = 160;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 3.0;
input bool   strategy_trailing_enabled   = false;
input double strategy_trailing_atr_mult  = 2.5;
input int    strategy_max_sessions       = 10;
input int    strategy_session_skip_minutes = 30;
input int    strategy_d1_atr_percentile_days = 120;
input double strategy_d1_atr_percentile  = 25.0;
input int    strategy_spread_median_bars = 120;
input double strategy_spread_mult        = 2.0;

datetime g_last_strategy_close_bar = 0;
datetime g_last_exit_eval_bar = 0;

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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_DonchianChannel(double &upper, double &lower)
  {
   upper = -DBL_MAX;
   lower = DBL_MAX;
   if(strategy_donchian_period <= 0)
      return false;

   for(int shift = 2; shift <= strategy_donchian_period + 1; ++shift)
     {
      const double high_i = iHigh(_Symbol, strategy_signal_tf, shift);
      const double low_i = iLow(_Symbol, strategy_signal_tf, shift);
      if(high_i <= 0.0 || low_i <= 0.0 || high_i < low_i)
         return false;
      if(high_i > upper)
         upper = high_i;
      if(low_i < lower)
         lower = low_i;
     }

   return (upper > 0.0 && lower > 0.0 && upper > lower);
  }

double Strategy_CurrentEntryPrice(const QM_OrderType side)
  {
   return (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0 || strategy_spread_median_bars <= 0 || strategy_spread_mult <= 0.0)
      return true;

   const int cap = MathMin(strategy_spread_median_bars, 256);
   int samples[256];
   int count = 0;
   for(int shift = 1; shift <= cap; ++shift)
     {
      const long spread_i = iSpread(_Symbol, strategy_signal_tf, shift);
      if(spread_i <= 0)
         continue;
      samples[count] = (int)spread_i;
      ++count;
     }
   if(count <= 0)
      return true;

   for(int i = 1; i < count; ++i)
     {
      const int key = samples[i];
      int j = i - 1;
      while(j >= 0 && samples[j] > key)
        {
         samples[j + 1] = samples[j];
         --j;
        }
      samples[j + 1] = key;
     }

   const double median = (count % 2 == 1)
                         ? (double)samples[count / 2]
                         : 0.5 * (double)(samples[(count / 2) - 1] + samples[count / 2]);
   return ((double)current_spread <= median * strategy_spread_mult);
  }

bool Strategy_DailyAtrAllowsEntry()
  {
   const int days = MathMin(strategy_d1_atr_percentile_days, 256);
   if(days <= 0 || strategy_d1_atr_percentile <= 0.0)
      return true;

   const double atr_now = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_now <= 0.0)
      return false;

   double values[256];
   int count = 0;
   for(int shift = 1; shift <= days; ++shift)
     {
      const double atr_i = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr_i <= 0.0)
         continue;
      values[count] = atr_i;
      ++count;
     }
   if(count < MathMin(20, days))
      return false;

   for(int i = 1; i < count; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }

   int idx = (int)MathFloor(((MathMin(100.0, strategy_d1_atr_percentile) / 100.0) * (double)(count - 1)) + 0.5);
   idx = MathMax(0, MathMin(count - 1, idx));
   return (atr_now > values[idx]);
  }

bool Strategy_SessionAllowsEntry()
  {
   if(strategy_session_skip_minutes <= 0)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const datetime today_midnight = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   const int seconds_now = dt.hour * 3600 + dt.min * 60 + dt.sec;
   const int skip_seconds = strategy_session_skip_minutes * 60;

   datetime from_time = 0;
   datetime to_time = 0;
   for(uint session = 0; session < 16; ++session)
     {
      if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, session, from_time, to_time))
         break;

      MqlDateTime from_dt;
      MqlDateTime to_dt;
      TimeToStruct(from_time, from_dt);
      TimeToStruct(to_time, to_dt);
      int from_seconds = from_dt.hour * 3600 + from_dt.min * 60 + from_dt.sec;
      int to_seconds = to_dt.hour * 3600 + to_dt.min * 60 + to_dt.sec;
      if(to_seconds <= from_seconds)
         to_seconds += 24 * 3600;

      int adjusted_now = seconds_now;
      if(adjusted_now < from_seconds)
         adjusted_now += 24 * 3600;

      if(adjusted_now >= from_seconds && adjusted_now < to_seconds)
         return (adjusted_now >= from_seconds + skip_seconds &&
                 adjusted_now < to_seconds - skip_seconds);
     }

   return (today_midnight > 0);
  }

int Strategy_PositionSessionsHeld()
  {
   const int magic = QM_FrameworkMagic();
   datetime open_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(open_time <= 0)
      return 0;

   int sessions = 0;
   for(int shift = 1; shift <= 32; ++shift)
     {
      const datetime d1_time = iTime(_Symbol, PERIOD_D1, shift);
      if(d1_time <= 0)
         break;
      if(d1_time >= open_time)
         ++sessions;
     }
   return sessions;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XTIUSD.DWX")
      return true;
   if(strategy_signal_tf != PERIOD_M5)
      return true;
   if(strategy_donchian_period <= 0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_trailing_enabled && strategy_trailing_atr_mult <= 0.0)
      return true;
   if(!Strategy_HasOpenPosition() && !Strategy_SessionAllowsEntry())
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

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_strategy_close_bar)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(!Strategy_DailyAtrAllowsEntry())
      return false;

   double upper = 0.0;
   double lower = 0.0;
   if(!Strategy_DonchianChannel(upper, lower))
      return false;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(close_1 <= 0.0)
      return false;

   int direction = 0;
   if(close_1 > upper)
      direction = 1;
   else if(close_1 < lower)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = Strategy_CurrentEntryPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1122_DONCHIAN160_LONG" : "QM5_1122_DONCHIAN160_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!strategy_trailing_enabled)
      return;

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
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trailing_atr_mult);
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0)
      return false;
   if(bar_time == g_last_exit_eval_bar)
      return false;
   g_last_exit_eval_bar = bar_time;

   if(strategy_max_sessions > 0 && Strategy_PositionSessionsHeld() >= strategy_max_sessions)
     {
      g_last_strategy_close_bar = bar_time;
      return true;
     }

   double upper = 0.0;
   double lower = 0.0;
   if(!Strategy_DonchianChannel(upper, lower))
      return false;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   if(close_1 <= 0.0)
      return false;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close_1 < lower)
        {
         g_last_strategy_close_bar = bar_time;
         return true;
        }
      if(ptype == POSITION_TYPE_SELL && close_1 > upper)
        {
         g_last_strategy_close_bar = bar_time;
         return true;
        }
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1122\",\"ea\":\"unger-crude-donchian160\"}");
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
