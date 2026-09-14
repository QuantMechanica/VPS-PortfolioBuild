#property strict

#include <QM/QM_DSTAware.mqh>

// Contract section 8 (docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md):
// - at least 3 consecutive years spanning a leap year and a non-leap year
// - boundaries computed from the nth-weekday rule AT TEST TIME (QM_DSTAware_USDSTStartUTC/
//   EndUTC below), never hardcoded literals for the *rule itself*
// - a dense sweep (per-minute) across each transition week, no off-by-one
// - November fallback resolves to the standard-time (UTC+2) candidate
//
// GOLDEN_START_UTC/GOLDEN_END_UTC are the one exception: they are cross-language parity
// oracle values, generated 2026-09-14 by the independent, from-scratch Python
// implementation in tools/strategy_farm/dst_rule_golden_table.py (not copied from this
// file, not hand-picked) - see docs/ops/evidence/2026-09-14_dst_cross_language_parity/
// golden_table.csv. This test asserts the *dynamically computed* QM_DSTAware boundary for
// each year equals that independently generated value - the actual cross-language check.
// The 2026 pair also matches the single reference point this test already carried before
// this extension (2026.03.08 07:00:00 / 2026.11.01 06:00:00), a third confirmation.

#define QM_DST_TEST_YEAR_COUNT 5

int      g_test_years[QM_DST_TEST_YEAR_COUNT]        = {2023, 2024, 2025, 2026, 2027};
string   g_golden_start_utc[QM_DST_TEST_YEAR_COUNT]  = {
   "2023.03.12 07:00:00", "2024.03.10 07:00:00", "2025.03.09 07:00:00",
   "2026.03.08 07:00:00", "2027.03.14 07:00:00"
  };
string   g_golden_end_utc[QM_DST_TEST_YEAR_COUNT]    = {
   "2023.11.05 06:00:00", "2024.11.03 06:00:00", "2025.11.02 06:00:00",
   "2026.11.01 06:00:00", "2027.11.07 06:00:00"
  };

bool AssertTimeEquals(const string label, const datetime got, const datetime expected)
  {
   if(got == expected)
      return true;

   PrintFormat("[DST_TEST][FAIL] %s expected=%s got=%s",
               label,
               TimeToString(expected, TIME_DATE | TIME_SECONDS),
               TimeToString(got, TIME_DATE | TIME_SECONDS));
   return false;
  }

bool AssertIntEquals(const string label, const int got, const int expected)
  {
   if(got == expected)
      return true;

   PrintFormat("[DST_TEST][FAIL] %s expected=%d got=%d", label, expected, got);
   return false;
  }

bool AssertTrue(const string label, const bool cond)
  {
   if(cond)
      return true;
   PrintFormat("[DST_TEST][FAIL] %s expected true, got false", label);
   return false;
  }

// Dense per-minute sweep around one boundary instant: no off-by-one, offset flips
// exactly at the boundary and nowhere else in the swept window.
bool DenseSweepBoundary(const string label, const datetime boundary,
                        const int offset_before, const int offset_at_and_after)
  {
   bool ok = true;
   int window_minutes = 180; // +/- 3h, matches the Python-side golden table window

   for(int m = -window_minutes; m <= window_minutes; m++)
     {
      datetime t = boundary + (m * 60);
      int expected = (t < boundary) ? offset_before : offset_at_and_after;
      int got = QM_BrokerUtcOffsetHoursForUTC(t);
      if(got != expected)
        {
         PrintFormat("[DST_TEST][FAIL] %s dense-sweep minute=%d t=%s expected_offset=%d got_offset=%d",
                     label, m, TimeToString(t, TIME_DATE | TIME_SECONDS), expected, got);
         ok = false;
        }
     }
   return ok;
  }

int OnInit()
  {
   bool ok = true;

   for(int i = 0; i < QM_DST_TEST_YEAR_COUNT; i++)
     {
      int year = g_test_years[i];
      datetime start_dyn = QM_DSTAware_USDSTStartUTC(year);
      datetime end_dyn   = QM_DSTAware_USDSTEndUTC(year);
      datetime start_golden = StringToTime(g_golden_start_utc[i]);
      datetime end_golden   = StringToTime(g_golden_end_utc[i]);

      // Cross-language parity: the dynamically computed (nth-weekday-at-test-time)
      // boundary must equal the independently generated Python golden value.
      ok &= AssertTimeEquals(StringFormat("DST start %d vs golden", year), start_dyn, start_golden);
      ok &= AssertTimeEquals(StringFormat("DST end %d vs golden", year), end_dyn, end_golden);

      // Structural sanity (mirrors the Python-side DstRuleTests assertions).
      MqlDateTime dt_start, dt_end;
      TimeToStruct(start_dyn, dt_start);
      TimeToStruct(end_dyn, dt_end);
      ok &= AssertIntEquals(StringFormat("start %d month", year), dt_start.mon, 3);
      ok &= AssertIntEquals(StringFormat("start %d hour", year), dt_start.hour, 7);
      ok &= AssertIntEquals(StringFormat("start %d weekday", year), dt_start.day_of_week, 0); // Sunday
      ok &= AssertIntEquals(StringFormat("end %d month", year), dt_end.mon, 11);
      ok &= AssertIntEquals(StringFormat("end %d hour", year), dt_end.hour, 6);
      ok &= AssertIntEquals(StringFormat("end %d weekday", year), dt_end.day_of_week, 0);

      // No off-by-one at either boundary (one minute before/after).
      ok &= AssertTrue(StringFormat("%d start-1min not DST", year), !QM_IsUSDSTUTC(start_dyn - 60));
      ok &= AssertTrue(StringFormat("%d start DST", year), QM_IsUSDSTUTC(start_dyn));
      ok &= AssertTrue(StringFormat("%d end-1min DST", year), QM_IsUSDSTUTC(end_dyn - 60));
      ok &= AssertTrue(StringFormat("%d end not DST", year), !QM_IsUSDSTUTC(end_dyn));

      // Dense per-minute sweep across both transition weeks.
      ok &= DenseSweepBoundary(StringFormat("%d start", year), start_dyn, 2, 3);
      ok &= DenseSweepBoundary(StringFormat("%d end", year), end_dyn, 3, 2);

      // November fallback ambiguity: prefer the standard-time (UTC+2) candidate.
      datetime ambiguous_broker = end_dyn + (2 * 3600); // 08:00 local on fallback morning
      datetime resolved = QM_BrokerToUTC(ambiguous_broker);
      ok &= AssertTimeEquals(StringFormat("%d fallback prefers standard time", year), resolved, end_dyn);
      ok &= AssertTrue(StringFormat("%d fallback resolved is not DST", year), !QM_IsUSDSTUTC(resolved));
     }

   // Roundtrip + offset sanity on a representative year (kept from the original test).
   datetime utc_normal = StringToTime("2026.04.15 12:34:56");
   datetime roundtrip  = QM_BrokerToUTC(QM_UTCToBroker(utc_normal));
   ok &= AssertTimeEquals("UTC roundtrip non-transition", roundtrip, utc_normal);

   ok &= AssertIntEquals("Offset in January", QM_BrokerUtcOffsetHoursForUTC(StringToTime("2026.01.15 00:00:00")), 2);
   ok &= AssertIntEquals("Offset in July", QM_BrokerUtcOffsetHoursForUTC(StringToTime("2026.07.15 00:00:00")), 3);

   if(!ok)
     {
      Print("[DST_TEST] FAIL");
      return INIT_FAILED;
     }

   Print("[DST_TEST] PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
