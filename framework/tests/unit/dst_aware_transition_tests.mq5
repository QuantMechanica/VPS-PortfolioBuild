#property strict

#include <QM/QM_DSTAware.mqh>

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

int OnInit()
  {
   bool ok = true;

   datetime start_2026 = QM_DSTAware_USDSTStartUTC(2026);
   datetime end_2026   = QM_DSTAware_USDSTEndUTC(2026);

   ok &= AssertTimeEquals("DST start 2026 UTC",
                          start_2026,
                          StringToTime("2026.03.08 07:00:00"));
   ok &= AssertTimeEquals("DST end 2026 UTC",
                          end_2026,
                          StringToTime("2026.11.01 06:00:00"));

   datetime utc_pre_start  = StringToTime("2026.03.08 06:59:59");
   datetime utc_at_start   = StringToTime("2026.03.08 07:00:00");
   datetime utc_pre_end    = StringToTime("2026.11.01 05:59:59");
   datetime utc_at_end     = StringToTime("2026.11.01 06:00:00");

   ok &= AssertTimeEquals("UTC->Broker pre DST start",
                          QM_UTCToBroker(utc_pre_start),
                          StringToTime("2026.03.08 08:59:59"));
   ok &= AssertTimeEquals("UTC->Broker at DST start",
                          QM_UTCToBroker(utc_at_start),
                          StringToTime("2026.03.08 10:00:00"));

   ok &= AssertTimeEquals("UTC->Broker pre DST end",
                          QM_UTCToBroker(utc_pre_end),
                          StringToTime("2026.11.01 08:59:59"));
   ok &= AssertTimeEquals("UTC->Broker at DST end",
                          QM_UTCToBroker(utc_at_end),
                          StringToTime("2026.11.01 08:00:00"));

   ok &= AssertTimeEquals("Broker->UTC pre DST start",
                          QM_BrokerToUTC(StringToTime("2026.03.08 08:59:59")),
                          utc_pre_start);
   ok &= AssertTimeEquals("Broker->UTC at DST start",
                          QM_BrokerToUTC(StringToTime("2026.03.08 10:00:00")),
                          utc_at_start);

   // Ambiguous fallback hour policy is standard-time preference (UTC+2).
   ok &= AssertTimeEquals("Broker->UTC fallback policy",
                          QM_BrokerToUTC(StringToTime("2026.11.01 08:30:00")),
                          StringToTime("2026.11.01 06:30:00"));

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
