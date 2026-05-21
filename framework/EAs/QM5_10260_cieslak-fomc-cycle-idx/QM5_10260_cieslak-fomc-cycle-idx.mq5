#property strict
#property version   "5.0"
#property description "QM5_10260 Cieslak FOMC-cycle even-week long"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10260;
input int    qm_magic_slot_offset       = 0;
// HR5: magic = qm_ea_id * 10000 + qm_magic_slot_offset.
// Registered slots: NDX.DWX=102600000, WS30.DWX=102600001, SP500.DWX=102600002.

input group "Risk"
// HR4: P2 backtests use RISK_FIXED=1000; live deploy manifests must set RISK_PERCENT=0.5.
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 3.0;
input int    strategy_entry_hour_broker = 0;
input int    strategy_entry_minute      = 0;
input int    strategy_exit_hour_broker  = 20;
input int    strategy_exit_minute       = 30;
input int    strategy_max_cycle_week    = 8;
input int    strategy_max_spread_points = 0;
input bool   strategy_allow_fomc_hold   = true;

// FOMC scheduled meeting decision dates, table-as-of 2026-05-21 from
// federalreserve.gov/monetarypolicy/fomccalendars.htm. Refresh for 2028+ builds.
const datetime FOMC_DATES[] =
  {
   D'2018.01.31 00:00', D'2018.03.21 00:00', D'2018.05.02 00:00', D'2018.06.13 00:00',
   D'2018.08.01 00:00', D'2018.09.26 00:00', D'2018.11.08 00:00', D'2018.12.19 00:00',
   D'2019.01.30 00:00', D'2019.03.20 00:00', D'2019.05.01 00:00', D'2019.06.19 00:00',
   D'2019.07.31 00:00', D'2019.09.18 00:00', D'2019.10.30 00:00', D'2019.12.11 00:00',
   D'2020.01.29 00:00', D'2020.03.18 00:00', D'2020.04.29 00:00', D'2020.06.10 00:00',
   D'2020.07.29 00:00', D'2020.09.16 00:00', D'2020.11.05 00:00', D'2020.12.16 00:00',
   D'2021.01.27 00:00', D'2021.03.17 00:00', D'2021.04.28 00:00', D'2021.06.16 00:00',
   D'2021.07.28 00:00', D'2021.09.22 00:00', D'2021.11.03 00:00', D'2021.12.15 00:00',
   D'2022.01.26 00:00', D'2022.03.16 00:00', D'2022.05.04 00:00', D'2022.06.15 00:00',
   D'2022.07.27 00:00', D'2022.09.21 00:00', D'2022.11.02 00:00', D'2022.12.14 00:00',
   D'2023.02.01 00:00', D'2023.03.22 00:00', D'2023.05.03 00:00', D'2023.06.14 00:00',
   D'2023.07.26 00:00', D'2023.09.20 00:00', D'2023.11.01 00:00', D'2023.12.13 00:00',
   D'2024.01.31 00:00', D'2024.03.20 00:00', D'2024.05.01 00:00', D'2024.06.12 00:00',
   D'2024.07.31 00:00', D'2024.09.18 00:00', D'2024.11.07 00:00', D'2024.12.18 00:00',
   D'2025.01.29 00:00', D'2025.03.19 00:00', D'2025.05.07 00:00', D'2025.06.18 00:00',
   D'2025.07.30 00:00', D'2025.09.17 00:00', D'2025.10.29 00:00', D'2025.12.10 00:00',
   D'2026.01.28 00:00', D'2026.03.18 00:00', D'2026.04.29 00:00', D'2026.06.17 00:00',
   D'2026.07.29 00:00', D'2026.09.16 00:00', D'2026.10.28 00:00', D'2026.12.09 00:00',
   D'2027.01.27 00:00', D'2027.03.17 00:00', D'2027.04.28 00:00', D'2027.06.09 00:00',
   D'2027.07.28 00:00', D'2027.09.15 00:00', D'2027.10.27 00:00', D'2027.12.08 00:00'
  };

datetime DateOnly(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
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

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool SameDate(const datetime a, const datetime b)
  {
   MqlDateTime da;
   MqlDateTime db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year == db.year && da.mon == db.mon && da.day == db.day);
  }

int DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0));
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

datetime NthWeekdayOfMonth(const int year, const int month, const int weekday, const int nth)
  {
   int found = 0;
   for(int day = 1; day <= DaysInMonth(year, month); ++day)
     {
      const datetime d = MakeDate(year, month, day);
      MqlDateTime dt;
      TimeToStruct(d, dt);
      if(dt.day_of_week == weekday)
        {
         ++found;
         if(found == nth)
            return d;
        }
     }
   return 0;
  }

datetime LastWeekdayOfMonth(const int year, const int month, const int weekday)
  {
   for(int day = DaysInMonth(year, month); day >= 1; --day)
     {
      const datetime d = MakeDate(year, month, day);
      MqlDateTime dt;
      TimeToStruct(d, dt);
      if(dt.day_of_week == weekday)
         return d;
     }
   return 0;
  }

datetime ObservedFixedHoliday(const int year, const int month, const int day)
  {
   const datetime d = MakeDate(year, month, day);
   MqlDateTime dt;
   TimeToStruct(d, dt);
   if(dt.day_of_week == 6)
      return d - 86400;
   if(dt.day_of_week == 0)
      return d + 86400;
   return d;
  }

bool IsUsMarketHoliday(const datetime t)
  {
   const datetime d = DateOnly(t);
   MqlDateTime dt;
   TimeToStruct(d, dt);
   const int y = dt.year;

   if(SameDate(d, ObservedFixedHoliday(y, 1, 1)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 1, 1, 3)))
      return true;
   if(SameDate(d, NthWeekdayOfMonth(y, 2, 1, 3)))
      return true;
   if(SameDate(d, LastWeekdayOfMonth(y, 5, 1)))
      return true;
   if(y >= 2022 && SameDate(d, ObservedFixedHoliday(y, 6, 19)))
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

int FomcCycleWeek(const datetime t)
  {
   const datetime d = DateOnly(t);
   datetime last_meeting = 0;
   const int n = ArraySize(FOMC_DATES);
   for(int i = 0; i < n; ++i)
     {
      if(FOMC_DATES[i] <= d)
         last_meeting = FOMC_DATES[i];
      else
         break;
     }
   if(last_meeting <= 0)
      return -1;
   return (int)((d - last_meeting) / (7 * 86400));
  }

bool IsEvenFomcWeek(const datetime t)
  {
   const int week = FomcCycleWeek(t);
   if(week < 0 || week > strategy_max_cycle_week)
      return false;
   return ((week % 2) == 0);
  }

bool IsEntryDate(const datetime t)
  {
   if(!IsEvenFomcWeek(t))
      return false;

   MqlDateTime dt;
   TimeToStruct(DateOnly(t), dt);
   if(dt.day_of_week == 1)
      return !IsUsMarketHoliday(t);

   if(dt.day_of_week == 2)
     {
      const datetime monday = DateOnly(t) - 86400;
      return IsUsMarketHoliday(monday);
     }

   return false;
  }

bool HasOpenPositionForThisMagic()
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

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0 || HasOpenPositionForThisMagic())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   const int spread_points = (int)MathRound((ask - bid) / point);
   return (spread_points > strategy_max_spread_points);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10260_FOMC_EVEN_WEEK_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime now = TimeCurrent();
   if(!IsEntryDate(now))
      return false;

   const int entry_hhmm = strategy_entry_hour_broker * 100 + strategy_entry_minute;
   if(Hhmm(now) != entry_hhmm)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or target.
  }

bool Strategy_ExitSignal()
  {
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   if(dt.day_of_week != 5)
      return false;
   if(!IsEvenFomcWeek(now))
      return false;

   const int exit_hhmm = strategy_exit_hour_broker * 100 + strategy_exit_minute;
   return (Hhmm(now) >= exit_hhmm);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(strategy_allow_fomc_hold && IsEvenFomcWeek(broker_time))
      return false;
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
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10260\",\"ea\":\"cieslak-fomc-cycle-idx\"}");
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
