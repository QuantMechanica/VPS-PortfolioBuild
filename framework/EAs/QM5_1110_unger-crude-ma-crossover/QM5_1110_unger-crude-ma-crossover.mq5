#property strict
#property version   "5.0"
#property description "QM5_1110 Unger Crude MA Crossover"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1110;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M15;
input int    strategy_fast_sma_period    = 30;
input int    strategy_slow_sma_period    = 140;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.5;
input bool   strategy_tp_enabled         = false;
input double strategy_tp_rr              = 4.0;
input int    strategy_max_sessions       = 5;
input int    strategy_session_skip_minutes = 60;
input int    strategy_d1_atr_percentile_days = 120;
input double strategy_d1_atr_percentile  = 30.0;
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

double Strategy_DailyAtrRatio(const int shift)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
   const double close = iClose(_Symbol, PERIOD_D1, shift);
   if(atr <= 0.0 || close <= 0.0)
      return 0.0;
   return atr / close;
  }

bool Strategy_DailyAtrAllowsEntry()
  {
   const int days = MathMin(strategy_d1_atr_percentile_days, 256);
   if(days <= 0 || strategy_d1_atr_percentile <= 0.0)
      return true;

   const double ratio_now = Strategy_DailyAtrRatio(1);
   if(ratio_now <= 0.0)
      return false;

   double values[256];
   int count = 0;
   for(int shift = 1; shift <= days; ++shift)
     {
      const double ratio_i = Strategy_DailyAtrRatio(shift);
      if(ratio_i <= 0.0)
         continue;
      values[count] = ratio_i;
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
   return (ratio_now > values[idx]);
  }

bool Strategy_SessionAllowsEntry()
  {
   if(strategy_session_skip_minutes <= 0)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
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

   return true;
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

int Strategy_CrossoverDirection()
  {
   const double fast_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_fast_sma_period, 1);
   const double fast_2 = QM_SMA(_Symbol, strategy_signal_tf, strategy_fast_sma_period, 2);
   const double slow_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_slow_sma_period, 1);
   const double slow_2 = QM_SMA(_Symbol, strategy_signal_tf, strategy_slow_sma_period, 2);

   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0)
      return 0;
   if(fast_1 > slow_1 && fast_2 <= slow_2)
      return 1;
   if(fast_1 < slow_1 && fast_2 >= slow_2)
      return -1;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XTIUSD.DWX")
      return true;
   if(strategy_signal_tf != PERIOD_M15)
      return true;
   if(strategy_fast_sma_period <= 0 || strategy_slow_sma_period <= strategy_fast_sma_period)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_tp_enabled && strategy_tp_rr <= 0.0)
      return true;
   if(!Strategy_HasOpenPosition() && !Strategy_SessionAllowsEntry())
      return true;
   return false;
  }

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

   const int direction = Strategy_CrossoverDirection();
   if(direction == 0)
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

   if(strategy_tp_enabled)
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);

   req.reason = (direction > 0) ? "QM5_1110_SMA30_140_LONG" : "QM5_1110_SMA30_140_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card has no trailing/scale-out rule. SL/TP and strategy exits handle management.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_exit_eval_bar)
      return false;
   g_last_exit_eval_bar = bar_time;

   if(strategy_max_sessions > 0 && Strategy_PositionSessionsHeld() >= strategy_max_sessions)
     {
      g_last_strategy_close_bar = bar_time;
      return true;
     }

   const int direction = Strategy_CrossoverDirection();
   if(direction == 0)
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
      if(ptype == POSITION_TYPE_BUY && direction < 0)
        {
         g_last_strategy_close_bar = bar_time;
         return true;
        }
      if(ptype == POSITION_TYPE_SELL && direction > 0)
        {
         g_last_strategy_close_bar = bar_time;
         return true;
        }
     }

   return false;
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1110\",\"ea\":\"unger-crude-ma-crossover\"}");
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
