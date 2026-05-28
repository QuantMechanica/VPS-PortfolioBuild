#property strict
#property version   "5.0"
#property description "QM5_1124 Unger Index Holiday Long"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1124;
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
input int    strategy_atr_period         = 10;
input double strategy_atr_sl_mult        = 1.0;
input double strategy_atr_tp_mult        = 3.0;
input bool   strategy_use_sma_filter     = true;
input int    strategy_sma_period         = 180;
input bool   strategy_use_month_filter   = true;
input string strategy_allowed_months     = "3,4,12";
input int    strategy_days_before_holiday = 2;
input int    strategy_time_stop_bars     = 5;
input bool   strategy_exit_after_holiday_close = false;
input double strategy_gap_skip_stop_mult = 1.5;
input int    strategy_spread_lookback    = 20;
input double strategy_spread_median_mult = 3.0;

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

int MonthOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.mon;
  }

bool SameDate(const datetime left, const datetime right)
  {
   return (DateFloor(left) == DateFloor(right));
  }

datetime NthWeekdayOfMonth(const int year, const int month, const int weekday, const int ordinal)
  {
   const datetime month_start = MakeDate(year, month, 1);
   int seen = 0;
   for(int i = 0; i < 31; ++i)
     {
      const datetime candidate = month_start + i * 86400;
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
   const datetime month_start = MakeDate(year, month, 1);
   for(int i = 0; i < 31; ++i)
     {
      const datetime candidate = month_start + i * 86400;
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

bool IsUSExchangeHoliday(const datetime value)
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
   if(SameDate(d, ObservedFixedHoliday(y, 6, 19)))
      return true;
   if(SameDate(d, ObservedFixedHoliday(y, 7, 4)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 9, 1, 1)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 11, 4, 4)))
      return true;
   if(SameDate(d, ObservedFixedHoliday(y, 12, 25)))
      return true;

   return false;
  }

bool IsGermanExchangeHoliday(const datetime value)
  {
   const datetime d = DateFloor(value);
   const int y = YearOf(d);

   if(SameDate(d, ObservedFixedHoliday(y, 1, 1)))
      return true;
   if(SameDate(d, EasterSunday(y) - 2 * 86400))
      return true;
   if(SameDate(d, EasterSunday(y) + 1 * 86400))
      return true;
   if(SameDate(d, MakeDate(y, 5, 1)))
      return true;
   if(SameDate(d, MakeDate(y, 10, 3)))
      return true;
   if(SameDate(d, MakeDate(y, 12, 24)))
      return true;
   if(SameDate(d, MakeDate(y, 12, 25)))
      return true;
   if(SameDate(d, MakeDate(y, 12, 26)))
      return true;
   if(SameDate(d, MakeDate(y, 12, 31)))
      return true;

   return false;
  }

bool IsConfiguredHoliday(const datetime value)
  {
   if(_Symbol == "GDAXI.DWX")
      return IsGermanExchangeHoliday(value);
   if(_Symbol == "SP500.DWX" || _Symbol == "NDX.DWX" || _Symbol == "WS30.DWX")
      return IsUSExchangeHoliday(value);
   return false;
  }

int SymbolSlotForCurrentSymbol()
  {
   if(_Symbol == "GDAXI.DWX")
      return 0;
   if(_Symbol == "SP500.DWX")
      return 1;
   if(_Symbol == "NDX.DWX")
      return 2;
   if(_Symbol == "WS30.DWX")
      return 3;
   return -1;
  }

bool IsWeekday(const datetime value)
  {
   const int dow = DayOfWeek(value);
   return (dow >= 1 && dow <= 5);
  }

datetime AddTradingDays(const datetime value, const int delta_days)
  {
   if(delta_days == 0)
      return DateFloor(value);

   datetime candidate = DateFloor(value);
   const int step = (delta_days > 0) ? 1 : -1;
   int remaining = MathAbs(delta_days);
   for(int i = 0; i < 40 && remaining > 0; ++i)
     {
      candidate += step * 86400;
      if(IsWeekday(candidate) && !IsConfiguredHoliday(candidate))
         remaining--;
     }

   if(remaining == 0)
      return DateFloor(candidate);
   return 0;
  }

datetime FirstConfiguredHolidayAfter(const datetime value)
  {
   datetime candidate = DateFloor(value) + 86400;
   for(int i = 0; i < 20; ++i)
     {
      if(IsConfiguredHoliday(candidate))
         return DateFloor(candidate);
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
         return DateFloor(candidate);
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

bool SpreadAllowsNewEntry()
  {
   RefreshMedianSpread();
   if(strategy_spread_median_mult <= 0.0 || g_cached_median_spread <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return ((double)current_spread <= strategy_spread_median_mult * g_cached_median_spread);
  }

bool MonthAllowed(const int month)
  {
   if(!strategy_use_month_filter)
      return true;

   string parts[];
   const int n = StringSplit(strategy_allowed_months, ',', parts);
   for(int i = 0; i < n; ++i)
     {
      if((int)StringToInteger(parts[i]) == month)
         return true;
     }
   return false;
  }

bool HasRequiredD1History()
  {
   const int required = MathMax(strategy_sma_period, strategy_atr_period) + 5;
   return (Bars(_Symbol, PERIOD_D1) > required && iTime(_Symbol, PERIOD_D1, required) > 0);
  }

bool GapAllowsEntry(const double entry_price, const double atr)
  {
   if(strategy_gap_skip_stop_mult <= 0.0)
      return true;

   const double prior_close = iClose(_Symbol, PERIOD_D1, 1);
   if(prior_close <= 0.0 || atr <= 0.0)
      return false;

   const double planned_stop_distance = atr * strategy_atr_sl_mult;
   if(planned_stop_distance <= 0.0)
      return false;

   return (MathAbs(entry_price - prior_close) <= strategy_gap_skip_stop_mult * planned_stop_distance);
  }

int TradingBarsSinceOpen(const datetime open_time, const datetime current_d1)
  {
   int bars = 0;
   datetime candidate = DateFloor(open_time);
   for(int i = 0; i < 40; ++i)
     {
      candidate = AddTradingDays(candidate, 1);
      if(candidate <= 0 || candidate > DateFloor(current_d1))
         break;
      bars++;
     }
   return bars;
  }

bool Strategy_NoTradeFilter()
  {
   const int slot = SymbolSlotForCurrentSymbol();
   if(slot < 0 || slot != qm_magic_slot_offset)
      return true;

   datetime open_time = 0;
   if(GetOurPosition(open_time))
      return false;

   return !SpreadAllowsNewEntry();
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

   if(_Period != PERIOD_D1)
      return false;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_entry_d1_bar)
      return false;

   datetime open_time = 0;
   if(GetOurPosition(open_time))
      return false;

   if(!HasRequiredD1History())
      return false;

   const datetime signal_day = AddTradingDays(current_d1, -1);
   if(signal_day <= 0)
      return false;

   const datetime holiday = DateFloor(signal_day) + MathMax(1, strategy_days_before_holiday) * 86400;
   if(holiday <= 0 || !IsConfiguredHoliday(holiday))
      return false;

   if(!MonthAllowed(MonthOf(holiday)))
      return false;

   if(strategy_use_sma_filter)
     {
      const double prior_close = iClose(_Symbol, PERIOD_D1, 1);
      const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
      if(prior_close <= 0.0 || sma <= 0.0 || prior_close <= sma)
         return false;
     }

   g_last_entry_d1_bar = current_d1;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0 || !GapAllowsEntry(ask, atr))
      return false;

   req.price = ask;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
   req.tp = ask + atr * strategy_atr_tp_mult;
   if(req.sl <= 0.0 || req.sl >= ask || req.tp <= ask)
      return false;

   req.reason = "UNGER_INDEX_HOLIDAY_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_exit_d1_bar)
      return false;

   datetime open_time = 0;
   if(!GetOurPosition(open_time))
      return false;

   const datetime holiday = FirstConfiguredHolidayAfter(open_time);
   if(strategy_exit_after_holiday_close && holiday > 0)
     {
      const datetime first_session_after_holiday = AddTradingDays(holiday, 1);
      if(first_session_after_holiday > 0 && DateFloor(current_d1) >= first_session_after_holiday && IsNearD1SessionClose(current_d1))
        {
         g_last_exit_d1_bar = current_d1;
         return true;
        }
     }

   if(TradingBarsSinceOpen(open_time, current_d1) >= MathMax(1, strategy_time_stop_bars))
     {
      g_last_exit_d1_bar = current_d1;
      return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1124\",\"ea\":\"unger_index_holiday_long\"}");
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
