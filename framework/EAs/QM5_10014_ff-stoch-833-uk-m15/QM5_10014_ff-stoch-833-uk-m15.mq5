#property strict
#property version   "5.0"
#property description "QM5_10014 ForexFactory Stochastic 8/3/3 UK M15 Scalp"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10014;
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
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_M15;
input int    strategy_stoch_k_period     = 8;
input int    strategy_stoch_d_period     = 3;
input int    strategy_stoch_slowing      = 3;
input int    strategy_arm_lookback_bars  = 3;
input double strategy_long_arm_level     = 20.0;
input double strategy_long_cross_level   = 30.0;
input double strategy_short_arm_level    = 80.0;
input double strategy_short_cross_level  = 70.0;
input int    strategy_stop_pips          = 20;
input int    strategy_tp_pips_fx_major   = 10;
input int    strategy_tp_pips_jpy_cross  = 15;
input int    strategy_breakeven_pips     = 10;
input int    strategy_max_hold_bars      = 8;
input int    strategy_uk_start_hhmm      = 600;
input int    strategy_uk_end_hhmm        = 1000;
input double strategy_max_spread_stop_pct = 15.0;

int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4) == 0 && (year % 100) != 0) || ((year % 400) == 0);
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

int Strategy_LastSundayDay(const int year, const int month)
  {
   for(int day = Strategy_DaysInMonth(year, month); day >= 1; --day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon = month;
      dt.day = day;
      datetime t = StructToTime(dt);
      MqlDateTime checked;
      ZeroMemory(checked);
      TimeToStruct(t, checked);
      if(checked.day_of_week == 0)
         return day;
     }
   return -1;
  }

datetime Strategy_UKDSTBoundaryUTC(const int year, const int month)
  {
   const int day = Strategy_LastSundayDay(year, month);
   if(day < 1)
      return 0;

   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = 1;
   return StructToTime(dt);
  }

bool Strategy_IsUKDSTUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_time, dt);

   const datetime start_utc = Strategy_UKDSTBoundaryUTC(dt.year, 3);
   const datetime end_utc = Strategy_UKDSTBoundaryUTC(dt.year, 10);
   if(start_utc <= 0 || end_utc <= 0)
      return false;
   return (utc_time >= start_utc && utc_time < end_utc);
  }

datetime Strategy_BrokerToUKTime(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return utc_time + (Strategy_IsUKDSTUTC(utc_time) ? 3600 : 0);
  }

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_IsUKEntrySession(const datetime broker_time)
  {
   const int hhmm = Strategy_HHMM(Strategy_BrokerToUKTime(broker_time));
   return (hhmm >= strategy_uk_start_hhmm && hhmm < strategy_uk_end_hhmm);
  }

bool Strategy_IsUKCloseTime(const datetime broker_time)
  {
   return (Strategy_HHMM(Strategy_BrokerToUKTime(broker_time)) >= strategy_uk_end_hhmm);
  }

bool Strategy_IsJPYCross()
  {
   return (StringFind(_Symbol, "JPY") >= 0);
  }

int Strategy_TakeProfitPips()
  {
   return Strategy_IsJPYCross() ? strategy_tp_pips_jpy_cross : strategy_tp_pips_fx_major;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type,
                                datetime &open_time,
                                ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      ticket = t;
      return true;
     }
   return false;
  }

bool Strategy_HasOurPosition()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time = 0;
   ulong ticket = 0;
   return Strategy_SelectOurPosition(position_type, open_time, ticket);
  }

bool Strategy_LongArmed()
  {
   for(int shift = 1; shift <= strategy_arm_lookback_bars; ++shift)
     {
      const double k = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      const double d = QM_Stoch_D(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      if(k > 0.0 && d > 0.0 && k < strategy_long_arm_level && d < strategy_long_arm_level)
         return true;
     }
   return false;
  }

bool Strategy_ShortArmed()
  {
   for(int shift = 1; shift <= strategy_arm_lookback_bars; ++shift)
     {
      const double k = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      const double d = QM_Stoch_D(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      if(k > strategy_short_arm_level && d > strategy_short_arm_level)
         return true;
     }
   return false;
  }

bool Strategy_LongTrigger()
  {
   if(!Strategy_LongArmed())
      return false;
   const double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   return (k2 <= strategy_long_cross_level && k1 > strategy_long_cross_level);
  }

bool Strategy_ShortTrigger()
  {
   if(!Strategy_ShortArmed())
      return false;
   const double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   return (k2 >= strategy_short_cross_level && k1 < strategy_short_cross_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurPosition())
      return false;

   if(!Strategy_IsUKEntrySession(TimeCurrent()))
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_pips);
   if(bid <= 0.0 || ask <= 0.0 || stop_distance <= 0.0)
      return true;

   const double spread = ask - bid;
   return (spread > stop_distance * strategy_max_spread_stop_pct / 100.0);
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

   if(Strategy_HasOurPosition())
      return false;
   if(!Strategy_IsUKEntrySession(TimeCurrent()))
      return false;

   const bool long_signal = Strategy_LongTrigger();
   const bool short_signal = Strategy_ShortTrigger();
   if(!long_signal && !short_signal)
      return false;
   if(long_signal && short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_stop_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, Strategy_TakeProfitPips());
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "FF_STOCH_833_UK_M15_LONG" : "FF_STOCH_833_UK_M15_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
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

      QM_TM_MoveToBreakEven(ticket, strategy_breakeven_pips, 0);
     }
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time = 0;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(position_type, open_time, ticket))
      return false;

   const datetime now = TimeCurrent();
   if(Strategy_IsUKCloseTime(now))
      return true;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_timeframe);
   if(hold_seconds > 0 && open_time > 0 && (now - open_time) >= hold_seconds)
      return true;

   if(position_type == POSITION_TYPE_BUY && Strategy_ShortTrigger())
      return true;
   if(position_type == POSITION_TYPE_SELL && Strategy_LongTrigger())
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10014\",\"ea\":\"ff-stoch-833-uk-m15\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
