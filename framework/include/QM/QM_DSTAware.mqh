#ifndef QM_DST_AWARE_MQH
#define QM_DST_AWARE_MQH

// DarwinexZero NY-close convention:
// Broker time is UTC+2 outside US DST, UTC+3 during US DST.
// US DST boundaries are computed from calendar rules (no broker-clock dependency).

int QM_DSTAware_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      bool leap = ((year % 4) == 0 && (year % 100) != 0) || ((year % 400) == 0);
      return leap ? 29 : 28;
     }

   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;

   return 31;
  }

int QM_DSTAware_DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

int QM_DSTAware_NthWeekdayOfMonth(const int year,
                                  const int month,
                                  const int weekday,
                                  const int nth)
  {
   int hits = 0;
   int days = QM_DSTAware_DaysInMonth(year, month);

   for(int day = 1; day <= days; day++)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon = month;
      dt.day = day;
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;

      datetime t = StructToTime(dt);
      if(QM_DSTAware_DayOfWeek(t) != weekday)
         continue;

      hits++;
      if(hits == nth)
         return day;
     }

   return -1;
  }

datetime QM_DSTAware_USDSTStartUTC(const int year)
  {
   // US DST starts at 02:00 local (EST, UTC-5) on second Sunday of March => 07:00 UTC.
   int day = QM_DSTAware_NthWeekdayOfMonth(year, 3, SUNDAY, 2);
   if(day < 0)
      return 0;

   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon  = 3;
   dt.day  = day;
   dt.hour = 7;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

datetime QM_DSTAware_USDSTEndUTC(const int year)
  {
   // US DST ends at 02:00 local (EDT, UTC-4) on first Sunday of November => 06:00 UTC.
   int day = QM_DSTAware_NthWeekdayOfMonth(year, 11, SUNDAY, 1);
   if(day < 0)
      return 0;

   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon  = 11;
   dt.day  = day;
   dt.hour = 6;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

bool QM_IsUSDSTUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);

   datetime start_utc = QM_DSTAware_USDSTStartUTC(dt.year);
   datetime end_utc   = QM_DSTAware_USDSTEndUTC(dt.year);

   if(start_utc == 0 || end_utc == 0)
      return false;

   return (utc >= start_utc && utc < end_utc);
  }

int QM_BrokerUtcOffsetHoursForUTC(const datetime utc)
  {
   return QM_IsUSDSTUTC(utc) ? 3 : 2;
  }

datetime QM_UTCToBroker(const datetime utc)
  {
   return utc + (QM_BrokerUtcOffsetHoursForUTC(utc) * 3600);
  }

datetime QM_BrokerToUTC(const datetime broker_time)
  {
   // Around November fallback, one broker-time hour is ambiguous.
   // Policy: prefer standard-time offset (UTC+2) when both offsets are valid.
   datetime candidate_standard = broker_time - (2 * 3600);
   datetime candidate_dst      = broker_time - (3 * 3600);

   bool standard_valid = (QM_BrokerUtcOffsetHoursForUTC(candidate_standard) == 2);
   bool dst_valid      = (QM_BrokerUtcOffsetHoursForUTC(candidate_dst) == 3);

   if(standard_valid)
      return candidate_standard;
   if(dst_valid)
      return candidate_dst;

   // Fallback should not be reached for valid calendar years.
   return candidate_standard;
  }

#endif // QM_DST_AWARE_MQH
