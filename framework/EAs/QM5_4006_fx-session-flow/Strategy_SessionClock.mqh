#ifndef QM5_4006_STRATEGY_SESSION_CLOCK_MQH
#define QM5_4006_STRATEGY_SESSION_CLOCK_MQH

#include <QM/QM_DSTAware.mqh>

// SRC09_S01 is qualified only on the currently available 2017-2026
// DarwinexZero history.  Calendar rules can change by legislation, so dates
// outside the reviewed interval fail closed instead of silently extrapolating.
#define STRATEGY_CLOCK_FIRST_REVIEWED_YEAR 2017
#define STRATEGY_CLOCK_LAST_REVIEWED_YEAR  2026

bool Strategy_ClockReviewedYear(const int year)
  {
   return (year >= STRATEGY_CLOCK_FIRST_REVIEWED_YEAR &&
           year <= STRATEGY_CLOCK_LAST_REVIEWED_YEAR);
  }

bool Strategy_ClockUTCReviewed(const datetime utc)
  {
   if(utc <= 0)
      return false;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(utc, parts))
      return false;
   return Strategy_ClockReviewedYear(parts.year);
  }

bool Strategy_ClockStructToNaive(const MqlDateTime &source,
                                 datetime &naive_out)
  {
   naive_out = 0;
   if(!Strategy_ClockReviewedYear(source.year) ||
      source.mon < 1 || source.mon > 12 ||
      source.day < 1 || source.day > 31 ||
      source.hour < 0 || source.hour > 23 ||
      source.min < 0 || source.min > 59 ||
      source.sec < 0 || source.sec > 59)
      return false;

   MqlDateTime normalized;
   ZeroMemory(normalized);
   normalized.year = source.year;
   normalized.mon  = source.mon;
   normalized.day  = source.day;
   normalized.hour = source.hour;
   normalized.min  = source.min;
   normalized.sec  = source.sec;

   const datetime encoded = StructToTime(normalized);
   if(encoded <= 0)
      return false;

   MqlDateTime decoded;
   ZeroMemory(decoded);
   if(!TimeToStruct(encoded, decoded))
      return false;
   if(decoded.year != source.year || decoded.mon != source.mon ||
      decoded.day != source.day || decoded.hour != source.hour ||
      decoded.min != source.min || decoded.sec != source.sec)
      return false;

   naive_out = encoded;
   return true;
  }

datetime Strategy_LastSundayUTC(const int year,
                                const int month,
                                const int hour_utc)
  {
   if(!Strategy_ClockReviewedYear(year) ||
      month < 1 || month > 12 || hour_utc < 0 || hour_utc > 23)
      return 0;

   const int days = QM_DSTAware_DaysInMonth(year, month);
   for(int day = days; day >= 1; --day)
     {
      MqlDateTime parts;
      ZeroMemory(parts);
      parts.year = year;
      parts.mon  = month;
      parts.day  = day;
      parts.hour = hour_utc;
      const datetime candidate = StructToTime(parts);
      if(candidate > 0 && QM_DSTAware_DayOfWeek(candidate) == SUNDAY)
         return candidate;
     }
   return 0;
  }

datetime Strategy_UKDSTStartUTC(const int year)
  {
   // Europe/London: last Sunday in March at 01:00 UTC.
   return Strategy_LastSundayUTC(year, 3, 1);
  }

datetime Strategy_UKDSTEndUTC(const int year)
  {
   // Europe/London: last Sunday in October at 01:00 UTC.
   return Strategy_LastSundayUTC(year, 10, 1);
  }

bool Strategy_IsUKDSTUTC(const datetime utc)
  {
   if(!Strategy_ClockUTCReviewed(utc))
      return false;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(utc, parts))
      return false;

   const datetime start_utc = Strategy_UKDSTStartUTC(parts.year);
   const datetime end_utc   = Strategy_UKDSTEndUTC(parts.year);
   if(start_utc <= 0 || end_utc <= 0)
      return false;
   return (utc >= start_utc && utc < end_utc);
  }

// The returned datetime encodes London civil wall-clock fields.  It is not a
// UTC instant and must not be passed to broker APIs as though it were one.
datetime Strategy_UTCToLondon(const datetime utc)
  {
   if(!Strategy_ClockUTCReviewed(utc))
      return 0;
   return utc + (Strategy_IsUKDSTUTC(utc) ? 3600 : 0);
  }

// The returned datetime encodes New-York civil wall-clock fields.  It is not a
// UTC instant and must not be passed to broker APIs as though it were one.
datetime Strategy_UTCToNewYork(const datetime utc)
  {
   if(!Strategy_ClockUTCReviewed(utc))
      return 0;
   return utc + (QM_IsUSDSTUTC(utc) ? -4 * 3600 : -5 * 3600);
  }

bool Strategy_ClockUTCToUniqueBroker(const datetime utc,
                                     datetime &broker_out)
  {
   broker_out = 0;
   if(!Strategy_ClockUTCReviewed(utc))
      return false;

   const datetime broker = QM_UTCToBroker(utc);
   if(broker <= 0 || QM_BrokerToUTC(broker) != utc)
      return false;

   broker_out = broker;
   return true;
  }

bool Strategy_ResolveLondonLocal(const MqlDateTime &local_dt,
                                 datetime &utc_out,
                                 datetime &broker_out)
  {
   utc_out = 0;
   broker_out = 0;

   datetime local_naive = 0;
   if(!Strategy_ClockStructToNaive(local_dt, local_naive))
      return false;

   // A London civil instant has either the GMT candidate or the BST
   // candidate.  At the spring gap neither is valid; at the autumn overlap
   // both are valid.  Both cases are deliberately rejected.
   const datetime candidate_gmt = local_naive;
   const datetime candidate_bst = local_naive - 3600;
   const bool valid_gmt =
      (Strategy_UTCToLondon(candidate_gmt) == local_naive);
   const bool valid_bst =
      (Strategy_UTCToLondon(candidate_bst) == local_naive);
   if(valid_gmt == valid_bst)
      return false;

   const datetime resolved_utc = valid_gmt ? candidate_gmt : candidate_bst;
   datetime resolved_broker = 0;
   if(!Strategy_ClockUTCToUniqueBroker(resolved_utc, resolved_broker))
      return false;

   utc_out = resolved_utc;
   broker_out = resolved_broker;
   return true;
  }

bool Strategy_ResolveNewYorkLocal(const MqlDateTime &local_dt,
                                  datetime &utc_out,
                                  datetime &broker_out)
  {
   utc_out = 0;
   broker_out = 0;

   datetime local_naive = 0;
   if(!Strategy_ClockStructToNaive(local_dt, local_naive))
      return false;

   // New York local = UTC-5 (EST) or UTC-4 (EDT).  Validate candidates by
   // converting them back through the reviewed US calendar.  DST gaps and
   // overlaps therefore fail closed instead of being guessed.
   const datetime candidate_est = local_naive + 5 * 3600;
   const datetime candidate_edt = local_naive + 4 * 3600;
   const bool valid_est =
      (Strategy_UTCToNewYork(candidate_est) == local_naive);
   const bool valid_edt =
      (Strategy_UTCToNewYork(candidate_edt) == local_naive);
   if(valid_est == valid_edt)
      return false;

   const datetime resolved_utc = valid_est ? candidate_est : candidate_edt;
   datetime resolved_broker = 0;
   if(!Strategy_ClockUTCToUniqueBroker(resolved_utc, resolved_broker))
      return false;

   utc_out = resolved_utc;
   broker_out = resolved_broker;
   return true;
  }

bool Strategy_ClockExpectTime(const string label,
                              const datetime actual,
                              const datetime expected)
  {
   if(actual == expected)
      return true;
   PrintFormat("[SESSION_CLOCK][FAIL] %s expected=%s actual=%s",
               label,
               TimeToString(expected, TIME_DATE | TIME_SECONDS),
               TimeToString(actual, TIME_DATE | TIME_SECONDS));
   return false;
  }

bool Strategy_ClockExpectBool(const string label,
                              const bool actual,
                              const bool expected)
  {
   if(actual == expected)
      return true;
   PrintFormat("[SESSION_CLOCK][FAIL] %s expected=%s actual=%s",
               label,
               expected ? "true" : "false",
               actual ? "true" : "false");
   return false;
  }

bool Strategy_ClockPartsFromText(const string text, MqlDateTime &parts)
  {
   ZeroMemory(parts);
   const datetime encoded = StringToTime(text);
   return (encoded > 0 && TimeToStruct(encoded, parts));
  }

bool Strategy_ClockExpectLondonResolution(const string label,
                                          const string local_text,
                                          const string expected_utc_text,
                                          const string expected_broker_text)
  {
   MqlDateTime local_parts;
   if(!Strategy_ClockPartsFromText(local_text, local_parts))
     {
      PrintFormat("[SESSION_CLOCK][FAIL] %s invalid local fixture", label);
      return false;
     }

   datetime utc = 0;
   datetime broker = 0;
   if(!Strategy_ResolveLondonLocal(local_parts, utc, broker))
     {
      PrintFormat("[SESSION_CLOCK][FAIL] %s London resolution rejected", label);
      return false;
     }

   bool ok = true;
   ok &= Strategy_ClockExpectTime(label + " UTC", utc,
                                  StringToTime(expected_utc_text));
   ok &= Strategy_ClockExpectTime(label + " broker", broker,
                                  StringToTime(expected_broker_text));
   return ok;
  }

bool Strategy_ClockExpectNewYorkResolution(const string label,
                                           const string local_text,
                                           const string expected_utc_text,
                                           const string expected_broker_text)
  {
   MqlDateTime local_parts;
   if(!Strategy_ClockPartsFromText(local_text, local_parts))
     {
      PrintFormat("[SESSION_CLOCK][FAIL] %s invalid local fixture", label);
      return false;
     }

   datetime utc = 0;
   datetime broker = 0;
   if(!Strategy_ResolveNewYorkLocal(local_parts, utc, broker))
     {
      PrintFormat("[SESSION_CLOCK][FAIL] %s New-York resolution rejected", label);
      return false;
     }

   bool ok = true;
   ok &= Strategy_ClockExpectTime(label + " UTC", utc,
                                  StringToTime(expected_utc_text));
   ok &= Strategy_ClockExpectTime(label + " broker", broker,
                                  StringToTime(expected_broker_text));
   return ok;
  }

bool Strategy_ClockExpectRejectedLocal(const string label,
                                       const string local_text,
                                       const bool london)
  {
   MqlDateTime local_parts;
   if(!Strategy_ClockPartsFromText(local_text, local_parts))
     {
      PrintFormat("[SESSION_CLOCK][FAIL] %s invalid rejection fixture", label);
      return false;
     }

   datetime utc = 123;
   datetime broker = 456;
   const bool resolved = london
      ? Strategy_ResolveLondonLocal(local_parts, utc, broker)
      : Strategy_ResolveNewYorkLocal(local_parts, utc, broker);
   if(!resolved && utc == 0 && broker == 0)
      return true;

   PrintFormat("[SESSION_CLOCK][FAIL] %s expected fail-closed resolution",
               label);
   return false;
  }

bool Strategy_SessionClockSelfTest()
  {
   const int years[10] =
      {2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026};
   const string uk_start[10] =
     {
      "2017.03.26 01:00:00", "2018.03.25 01:00:00",
      "2019.03.31 01:00:00", "2020.03.29 01:00:00",
      "2021.03.28 01:00:00", "2022.03.27 01:00:00",
      "2023.03.26 01:00:00", "2024.03.31 01:00:00",
      "2025.03.30 01:00:00", "2026.03.29 01:00:00"
     };
   const string uk_end[10] =
     {
      "2017.10.29 01:00:00", "2018.10.28 01:00:00",
      "2019.10.27 01:00:00", "2020.10.25 01:00:00",
      "2021.10.31 01:00:00", "2022.10.30 01:00:00",
      "2023.10.29 01:00:00", "2024.10.27 01:00:00",
      "2025.10.26 01:00:00", "2026.10.25 01:00:00"
     };
   const string us_start[10] =
     {
      "2017.03.12 07:00:00", "2018.03.11 07:00:00",
      "2019.03.10 07:00:00", "2020.03.08 07:00:00",
      "2021.03.14 07:00:00", "2022.03.13 07:00:00",
      "2023.03.12 07:00:00", "2024.03.10 07:00:00",
      "2025.03.09 07:00:00", "2026.03.08 07:00:00"
     };
   const string us_end[10] =
     {
      "2017.11.05 06:00:00", "2018.11.04 06:00:00",
      "2019.11.03 06:00:00", "2020.11.01 06:00:00",
      "2021.11.07 06:00:00", "2022.11.06 06:00:00",
      "2023.11.05 06:00:00", "2024.11.03 06:00:00",
      "2025.11.02 06:00:00", "2026.11.01 06:00:00"
     };

   bool ok = true;
   for(int i = 0; i < 10; ++i)
     {
      const datetime expected_uk_start = StringToTime(uk_start[i]);
      const datetime expected_uk_end   = StringToTime(uk_end[i]);
      const datetime expected_us_start = StringToTime(us_start[i]);
      const datetime expected_us_end   = StringToTime(us_end[i]);
      const string year_label = IntegerToString(years[i]);

      ok &= Strategy_ClockExpectTime("UK start " + year_label,
                                     Strategy_UKDSTStartUTC(years[i]),
                                     expected_uk_start);
      ok &= Strategy_ClockExpectTime("UK end " + year_label,
                                     Strategy_UKDSTEndUTC(years[i]),
                                     expected_uk_end);
      ok &= Strategy_ClockExpectBool("UK pre-start " + year_label,
                                     Strategy_IsUKDSTUTC(expected_uk_start - 1),
                                     false);
      ok &= Strategy_ClockExpectBool("UK at-start " + year_label,
                                     Strategy_IsUKDSTUTC(expected_uk_start),
                                     true);
      ok &= Strategy_ClockExpectBool("UK pre-end " + year_label,
                                     Strategy_IsUKDSTUTC(expected_uk_end - 1),
                                     true);
      ok &= Strategy_ClockExpectBool("UK at-end " + year_label,
                                     Strategy_IsUKDSTUTC(expected_uk_end),
                                     false);

      ok &= Strategy_ClockExpectTime("US start " + year_label,
                                     QM_DSTAware_USDSTStartUTC(years[i]),
                                     expected_us_start);
      ok &= Strategy_ClockExpectTime("US end " + year_label,
                                     QM_DSTAware_USDSTEndUTC(years[i]),
                                     expected_us_end);
      ok &= Strategy_ClockExpectBool("US pre-start " + year_label,
                                     QM_IsUSDSTUTC(expected_us_start - 1), false);
      ok &= Strategy_ClockExpectBool("US at-start " + year_label,
                                     QM_IsUSDSTUTC(expected_us_start), true);
      ok &= Strategy_ClockExpectBool("US pre-end " + year_label,
                                     QM_IsUSDSTUTC(expected_us_end - 1), true);
      ok &= Strategy_ClockExpectBool("US at-end " + year_label,
                                     QM_IsUSDSTUTC(expected_us_end), false);
     }

   // 2026 Europe/US mismatch-week fixtures.  The EU leg is five hours while
   // only the US is on DST and six hours when both centres share DST state.
   const string dates[4] =
      {"2026.03.09", "2026.03.30", "2026.10.26", "2026.11.02"};
   const string london_utc[4] =
     {
      "2026.03.09 07:00:00", "2026.03.30 06:00:00",
      "2026.10.26 07:00:00", "2026.11.02 07:00:00"
     };
   const string london_broker[4] =
     {
      "2026.03.09 10:00:00", "2026.03.30 09:00:00",
      "2026.10.26 10:00:00", "2026.11.02 09:00:00"
     };
   const string ny_open_utc[4] =
     {
      "2026.03.09 12:00:00", "2026.03.30 12:00:00",
      "2026.10.26 12:00:00", "2026.11.02 13:00:00"
     };
   const string ny_open_broker[4] =
     {
      "2026.03.09 15:00:00", "2026.03.30 15:00:00",
      "2026.10.26 15:00:00", "2026.11.02 15:00:00"
     };
   const string ny_close_utc[4] =
     {
      "2026.03.09 20:00:00", "2026.03.30 20:00:00",
      "2026.10.26 20:00:00", "2026.11.02 21:00:00"
     };
   const string ny_close_broker[4] =
     {
      "2026.03.09 23:00:00", "2026.03.30 23:00:00",
      "2026.10.26 23:00:00", "2026.11.02 23:00:00"
     };
   const int expected_eu_hold_hours[4] = {5, 6, 5, 6};

   for(int i = 0; i < 4; ++i)
     {
      ok &= Strategy_ClockExpectLondonResolution(
         "London 07 " + dates[i], dates[i] + " 07:00:00",
         london_utc[i], london_broker[i]);
      ok &= Strategy_ClockExpectNewYorkResolution(
         "New York 08 " + dates[i], dates[i] + " 08:00:00",
         ny_open_utc[i], ny_open_broker[i]);
      ok &= Strategy_ClockExpectNewYorkResolution(
         "New York 16 " + dates[i], dates[i] + " 16:00:00",
         ny_close_utc[i], ny_close_broker[i]);

      const long hold_seconds =
         (long)(StringToTime(ny_open_utc[i]) - StringToTime(london_utc[i]));
      const long expected_seconds = (long)expected_eu_hold_hours[i] * 3600L;
      if(hold_seconds != expected_seconds)
        {
         PrintFormat("[SESSION_CLOCK][FAIL] EU hold %s expected=%I64d actual=%I64d",
                     dates[i], expected_seconds, hold_seconds);
         ok = false;
        }
     }

   // Non-existent and duplicated civil instants must never be guessed.
   ok &= Strategy_ClockExpectRejectedLocal(
      "London spring gap", "2026.03.29 01:30:00", true);
   ok &= Strategy_ClockExpectRejectedLocal(
      "London autumn overlap", "2026.10.25 01:30:00", true);
   ok &= Strategy_ClockExpectRejectedLocal(
      "New York spring gap", "2026.03.08 02:30:00", false);
   ok &= Strategy_ClockExpectRejectedLocal(
      "New York autumn overlap", "2026.11.01 01:30:00", false);

   // Dates outside the reviewed data/calendar contract fail closed.
   MqlDateTime outside_parts;
   ZeroMemory(outside_parts);
   outside_parts.year = 2027;
   outside_parts.mon = 1;
   outside_parts.day = 4;
   outside_parts.hour = 7;
   datetime outside_utc = 123;
   datetime outside_broker = 456;
   ok &= Strategy_ClockExpectBool(
      "outside reviewed London range",
      Strategy_ResolveLondonLocal(outside_parts, outside_utc, outside_broker),
      false);
   ok &= Strategy_ClockExpectBool("outside UTC conversion range",
                                  Strategy_UTCToNewYork(
                                     StringToTime("2027.01.04 12:00:00")) != 0,
                                  false);
   if(outside_utc != 0 || outside_broker != 0)
     {
      Print("[SESSION_CLOCK][FAIL] rejected outputs were not cleared");
      ok = false;
     }

   if(ok)
      Print("[SESSION_CLOCK] PASS reviewed UK/US transitions and mismatch fixtures");
   else
      Print("[SESSION_CLOCK] FAIL");
   return ok;
  }

#endif // QM5_4006_STRATEGY_SESSION_CLOCK_MQH
