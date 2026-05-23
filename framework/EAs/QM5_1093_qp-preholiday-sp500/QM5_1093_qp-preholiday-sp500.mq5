#property strict
#property version   "5.0"
#property description "QM5_1093 Quantpedia Pre-Holiday SP500"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1093;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 2.0;
input double strategy_spread_median_mult = 3.0;
input int    strategy_spread_lookback    = 20;
input int    strategy_time_stop_days     = 3;

datetime g_last_spread_d1_bar = 0;
double   g_cached_median_spread = 0.0;
datetime g_last_entry_d1_bar = 0;
datetime g_last_exit_d1_bar = 0;

datetime DateFloor(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime MakeDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   return StructToTime(dt);
  }

int DayOfWeek(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

int YearOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
  }

bool SameDate(const datetime left, const datetime right)
  {
   return (DateFloor(left) == DateFloor(right));
  }

datetime NthWeekdayOfMonth(const int year, const int month, const int weekday, const int ordinal)
  {
   datetime day = MakeDate(year, month, 1);
   int seen = 0;
   for(int i = 0; i < 31; ++i)
     {
      const datetime candidate = day + i * 86400;
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(dt.day_of_week == weekday)
        {
         seen++;
         if(seen == ordinal)
            return DateFloor(candidate);
        }
     }
   return 0;
  }

datetime LastWeekdayOfMonth(const int year, const int month, const int weekday)
  {
   datetime found = 0;
   datetime day = MakeDate(year, month, 1);
   for(int i = 0; i < 31; ++i)
     {
      const datetime candidate = day + i * 86400;
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(dt.day_of_week == weekday)
         found = DateFloor(candidate);
     }
   return found;
  }

datetime ObservedFixedHoliday(const int year, const int month, const int day)
  {
   const datetime actual = MakeDate(year, month, day);
   const int dow = DayOfWeek(actual);
   if(dow == 0)
      return actual + 86400;
   if(dow == 6)
      return actual - 86400;
   return actual;
  }

datetime EasterSunday(const int year)
  {
   const int a = year % 19;
   const int b = year / 100;
   const int c = year % 100;
   const int d = b / 4;
   const int e = b % 4;
   const int f = (b + 8) / 25;
   const int g = (b - f + 1) / 3;
   const int h = (19 * a + b - d - g + 15) % 30;
   const int i = c / 4;
   const int k = c % 4;
   const int l = (32 + 2 * e + 2 * i - h - k) % 7;
   const int m = (a + 11 * h + 22 * l) / 451;
   const int month = (h + l - 7 * m + 114) / 31;
   const int day = ((h + l - 7 * m + 114) % 31) + 1;
   return MakeDate(year, month, day);
  }

bool IsConfiguredHoliday(const datetime value)
  {
   const datetime d = DateFloor(value);
   const int y = YearOf(d);

   if(SameDate(d, ObservedFixedHoliday(y, 1, 1)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 1, 1, 3)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 2, 1, 3)))
      return true;
   if(SameDate(d, EasterSunday(y) - 2 * 86400))
      return true;
   if(SameDate(d, LastWeekdayOfMonth(y, 5, 1)))
      return true;
   if(SameDate(d, ObservedFixedHoliday(y, 7, 4)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 9, 1, 1)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 11, 2, 1)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 11, 4, 4)))
      return true;
   if(SameDate(d, ObservedFixedHoliday(y, 12, 25)))
      return true;

   return false;
  }

bool IsWeekday(const datetime value)
  {
   const int dow = DayOfWeek(value);
   return (dow >= 1 && dow <= 5);
  }

datetime NextWeekdayAfter(const datetime value)
  {
   datetime candidate = DateFloor(value) + 86400;
   for(int i = 0; i < 10; ++i)
     {
      if(IsWeekday(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

datetime NextAvailableTradingDayAfter(const datetime value)
  {
   datetime candidate = DateFloor(value) + 86400;
   for(int i = 0; i < 10; ++i)
     {
      if(IsWeekday(candidate) && !IsConfiguredHoliday(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

bool HasScheduledTradeSession(const datetime date_time)
  {
   MqlDateTime dt;
   TimeToStruct(date_time, dt);

   datetime session_from = 0;
   datetime session_to = 0;
   for(uint session = 0; session < 10; ++session)
     {
      if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, session, session_from, session_to))
         return true;
     }

   return IsWeekday(date_time);
  }

datetime NextScheduledTradingDayAfter(const datetime value)
  {
   datetime candidate = DateFloor(value) + 86400;
   for(int i = 0; i < 10; ++i)
     {
      if(HasScheduledTradeSession(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

bool IsNearD1SessionClose(const datetime current_d1)
  {
   const datetime next_d1 = NextScheduledTradingDayAfter(current_d1);
   if(next_d1 <= 0)
      return false;
   return (TimeCurrent() >= next_d1 - 60);
  }

bool GetOurPosition(datetime &open_time)
  {
   open_time = 0;
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

void RefreshMedianSpread()
  {
   const datetime d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(d1 <= 0 || d1 == g_last_spread_d1_bar)
      return;

   g_last_spread_d1_bar = d1;
   g_cached_median_spread = 0.0;

   const int lookback = MathMax(1, strategy_spread_lookback);
   double values[];
   ArrayResize(values, lookback);
   int samples = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const int spread_points = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread_points <= 0)
         continue;
      values[samples] = (double)spread_points;
      samples++;
     }

   if(samples <= 0)
      return;

   ArrayResize(values, samples);
   ArraySort(values);
   const int mid = samples / 2;
   if((samples % 2) == 1)
      g_cached_median_spread = values[mid];
   else
      g_cached_median_spread = (values[mid - 1] + values[mid]) * 0.5;
  }

datetime FirstConfiguredHolidayAfter(const datetime value)
  {
   datetime candidate = DateFloor(value) + 86400;
   for(int i = 0; i < 10; ++i)
     {
      if(IsConfiguredHoliday(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "SP500.DWX")
      return true;

   RefreshMedianSpread();
   if(strategy_spread_median_mult > 0.0 && g_cached_median_spread > 0.0)
     {
      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)current_spread > strategy_spread_median_mult * g_cached_median_spread)
         return true;
     }

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

   if(_Period != PERIOD_D1)
      return false;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_entry_d1_bar)
      return false;

   datetime open_time = 0;
   if(GetOurPosition(open_time))
      return false;

   const datetime next_weekday = NextWeekdayAfter(current_d1);
   if(next_weekday <= 0 || !IsConfiguredHoliday(next_weekday))
      return false;

   g_last_entry_d1_bar = current_d1;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   req.price = ask;
   req.tp = 0.0;
   req.reason = "QP_PREHOLIDAY_SP500_LONG";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_exit_d1_bar)
      return false;

   datetime open_time = 0;
   if(!GetOurPosition(open_time))
      return false;

   if(open_time > 0 && TimeCurrent() >= open_time + MathMax(1, strategy_time_stop_days) * 86400)
     {
      g_last_exit_d1_bar = current_d1;
      return true;
     }

   const datetime holiday = FirstConfiguredHolidayAfter(open_time);
   if(holiday <= 0)
      return false;

   const datetime exit_day = NextAvailableTradingDayAfter(holiday);
   if(exit_day <= 0 || DateFloor(current_d1) < exit_day)
      return false;

   if(!IsNearD1SessionClose(current_d1))
      return false;

   g_last_exit_d1_bar = current_d1;
   return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1093\",\"ea\":\"qp_preholiday_sp500\"}");
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
