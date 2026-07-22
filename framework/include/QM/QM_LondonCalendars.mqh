#ifndef QM_LONDON_CALENDARS_MQH
#define QM_LONDON_CALENDARS_MQH

// Manifest-bound London calendar contracts.  These files are provisioned to
// MT5 Common Files by framework/calendars/london/provision_london_calendars.ps1.
//
// The contracts deliberately answer different questions:
//   * England/Wales public holidays are jurisdictional context only.  They do
//     not prove that an FX route is closed or operating abnormal hours.
//   * LSE status describes the official cash-equity session, including full
//     closes and scheduled 12:30 London early closes.  It is not an FX route
//     calendar.
//   * WMR status describes the 16:00 London spot-fix service.  It must never be
//     inferred from a public-holiday or LSE cash-session date.
//
// Every selected runtime file and the bundle manifest are SHA-256 verified
// before any lookup becomes ready.  Dates outside each stated coverage range
// are returned as OUT_OF_COVERAGE and therefore remain fail-closed at the EA.

#define QM_LONDON_CALENDAR_MANIFEST_FILE "QM5_London_calendar_manifest.json"
#define QM_LONDON_CALENDAR_MANIFEST_SHA256 "4B8DA9E3AF536C99DB2F3D2571D4082F2EE81DEB3B0E2CB2C6C56E13B2AECC7D"

#define QM_LONDON_PUBLIC_HOLIDAY_FILE "QM5_GOVUK_England_Wales_public_holidays_20180101_20251231.csv"
#define QM_LONDON_PUBLIC_HOLIDAY_SHA256 "8A54E3F2FB7437FDED65E8DB05B4317F7B2881ABC0D3090EFE23DB1349FE1A75"

#define QM_LONDON_LSE_CASH_FILE "QM5_LSE_cash_session_exceptions_20180101_20251231.csv"
#define QM_LONDON_LSE_CASH_SHA256 "166A391FBB59A49D42A363FF347286139725853CD9F70D30D8CD71A404DD7D8D"

#define QM_LONDON_WMR_1600_FILE "QM5_WMR_1600_London_service_exceptions_20250101_20251231.csv"
#define QM_LONDON_WMR_1600_SHA256 "544F347A39E82E1B4EF3354D16110591A76A7C6CCE70A7F599DCA886706006F2"

const int QM_LONDON_PUBLIC_HOLIDAY_COVERAGE_START = 20180101;
const int QM_LONDON_PUBLIC_HOLIDAY_COVERAGE_END = 20251231;
const int QM_LONDON_PUBLIC_HOLIDAY_EXPECTED_ROWS = 67;

const int QM_LONDON_LSE_CASH_COVERAGE_START = 20180101;
const int QM_LONDON_LSE_CASH_COVERAGE_END = 20251231;
const int QM_LONDON_LSE_CASH_EXPECTED_ROWS = 83;
const int QM_LONDON_LSE_CASH_EXPECTED_FULL_CLOSE_ROWS = 67;
const int QM_LONDON_LSE_CASH_EXPECTED_EARLY_CLOSE_ROWS = 16;

// Official byte-pinnable WMR service-alteration coverage currently starts in
// 2025.  The requested 2018-2024 study interval intentionally remains outside
// coverage rather than being synthesized from UK/LSE holidays.
const int QM_LONDON_WMR_1600_COVERAGE_START = 20250101;
const int QM_LONDON_WMR_1600_COVERAGE_END = 20251231;
const int QM_LONDON_WMR_1600_EXPECTED_ROWS = 7;
const int QM_LONDON_WMR_1600_EXPECTED_NO_FIX_ROWS = 3;
const int QM_LONDON_WMR_1600_EXPECTED_AVAILABLE_ROWS = 4;

enum QM_LondonPublicDayType
  {
   QM_LONDON_PUBLIC_DAY_INVALID = 0,
   QM_LONDON_PUBLIC_DAY_ORDINARY_WEEKDAY = 1,
   QM_LONDON_PUBLIC_DAY_PUBLIC_OR_BANK_HOLIDAY = 2,
   QM_LONDON_PUBLIC_DAY_WEEKEND = 3,
   QM_LONDON_PUBLIC_DAY_OUT_OF_COVERAGE = 4
  };

enum QM_LondonWmr1600Status
  {
   QM_LONDON_WMR_1600_INVALID = 0,
   QM_LONDON_WMR_1600_NORMAL_FIX_AVAILABLE = 1,
   QM_LONDON_WMR_1600_ONLY_FIX_AVAILABLE = 2,
   QM_LONDON_WMR_1600_NO_FIX = 3,
   QM_LONDON_WMR_1600_WEEKEND = 4,
   QM_LONDON_WMR_1600_OUT_OF_COVERAGE = 5
  };

enum QM_LondonLseCashSessionType
  {
   QM_LONDON_LSE_CASH_INVALID = 0,
   QM_LONDON_LSE_CASH_NORMAL = 1,
   QM_LONDON_LSE_CASH_FULL_CLOSE = 2,
   QM_LONDON_LSE_CASH_EARLY_CLOSE = 3,
   QM_LONDON_LSE_CASH_OUT_OF_COVERAGE = 4
  };

bool   g_qm_london_manifest_attempted = false;
bool   g_qm_london_manifest_ready = false;
string g_qm_london_manifest_last_error = "not_loaded";
string g_qm_london_manifest_actual_sha256 = "";

bool   g_qm_london_public_attempted = false;
bool   g_qm_london_public_ready = false;
string g_qm_london_public_last_error = "not_loaded";
string g_qm_london_public_actual_sha256 = "";
int    g_qm_london_public_date_keys[];

bool   g_qm_london_lse_attempted = false;
bool   g_qm_london_lse_ready = false;
string g_qm_london_lse_last_error = "not_loaded";
string g_qm_london_lse_actual_sha256 = "";
int    g_qm_london_lse_date_keys[];
int    g_qm_london_lse_session_types[];

bool   g_qm_london_wmr_attempted = false;
bool   g_qm_london_wmr_ready = false;
string g_qm_london_wmr_last_error = "not_loaded";
string g_qm_london_wmr_actual_sha256 = "";
int    g_qm_london_wmr_date_keys[];
int    g_qm_london_wmr_statuses[];

string QM_LondonCalendarTrimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

string QM_LondonCalendarUpper(string value)
  {
   StringToUpper(value);
   return value;
  }

bool QM_LondonCalendarDateKeyParts(const int date_key, MqlDateTime &parts)
  {
   ZeroMemory(parts);
   if(date_key < 19000101 || date_key > 29991231)
      return false;
   const int year = date_key / 10000;
   const int month = (date_key / 100) % 100;
   const int day = date_key % 100;
   parts.year = year;
   parts.mon = month;
   parts.day = day;
   const datetime timestamp = StructToTime(parts);
   if(timestamp <= 0 || !TimeToStruct(timestamp, parts))
      return false;
   return (parts.year == year && parts.mon == month && parts.day == day);
  }

bool QM_LondonCalendarParseDateKey(string value, int &date_key)
  {
   date_key = 0;
   value = QM_LondonCalendarTrimmed(value);
   if(StringLen(value) != 10 || StringSubstr(value, 4, 1) != "-" ||
      StringSubstr(value, 7, 1) != "-")
      return false;
   const string digits = "0123456789";
   for(int i = 0; i < 10; ++i)
     {
      if(i == 4 || i == 7)
         continue;
      if(StringFind(digits, StringSubstr(value, i, 1)) < 0)
         return false;
     }

   const int year = (int)StringToInteger(StringSubstr(value, 0, 4));
   const int month = (int)StringToInteger(StringSubstr(value, 5, 2));
   const int day = (int)StringToInteger(StringSubstr(value, 8, 2));
   date_key = year * 10000 + month * 100 + day;
   MqlDateTime parts;
   if(!QM_LondonCalendarDateKeyParts(date_key, parts) ||
      parts.year != year || parts.mon != month || parts.day != day)
     {
      date_key = 0;
      return false;
     }
   return true;
  }

bool QM_LondonCalendarIsWeekday(const int date_key)
  {
   MqlDateTime parts;
   if(!QM_LondonCalendarDateKeyParts(date_key, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

bool QM_LondonCalendarCommonFileSha256(const string file_name,
                                       string &hash_hex)
  {
   hash_hex = "";
   const int handle = FileOpen(file_name,
                               FILE_READ | FILE_BIN | FILE_SHARE_READ |
                               FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;
   const int size = (int)FileSize(handle);
   if(size <= 0)
     {
      FileClose(handle);
      return false;
     }
   uchar bytes[];
   if(ArrayResize(bytes, size) != size ||
      FileReadArray(handle, bytes, 0, size) != size)
     {
      FileClose(handle);
      return false;
     }
   FileClose(handle);

   uchar digest[];
   uchar key[];
   ArrayResize(key, 0);
   const int digest_size = CryptEncode(CRYPT_HASH_SHA256, bytes, key, digest);
   if(digest_size != 32)
      return false;
   for(int i = 0; i < digest_size; ++i)
      hash_hex += StringFormat("%02X", digest[i]);
   return true;
  }

bool QM_LondonCalendarManifestFail(const string detail)
  {
   g_qm_london_manifest_ready = false;
   g_qm_london_manifest_last_error = detail;
   return false;
  }

bool QM_LondonCalendarEnsureManifest()
  {
   if(g_qm_london_manifest_attempted)
      return g_qm_london_manifest_ready;
   g_qm_london_manifest_attempted = true;
   g_qm_london_manifest_actual_sha256 = "";
   if(!QM_LondonCalendarCommonFileSha256(QM_LONDON_CALENDAR_MANIFEST_FILE,
                                         g_qm_london_manifest_actual_sha256))
      return QM_LondonCalendarManifestFail("manifest_missing_or_unreadable");
   if(QM_LondonCalendarUpper(g_qm_london_manifest_actual_sha256) !=
      QM_LONDON_CALENDAR_MANIFEST_SHA256)
      return QM_LondonCalendarManifestFail("manifest_sha256_mismatch");
   g_qm_london_manifest_ready = true;
   g_qm_london_manifest_last_error = "";
   return true;
  }

bool QM_LondonPublicHolidayFail(const string detail)
  {
   g_qm_london_public_ready = false;
   g_qm_london_public_last_error = detail;
   ArrayResize(g_qm_london_public_date_keys, 0);
   return false;
  }

bool QM_LondonPublicHolidayAppend(const int date_key)
  {
   const int n = ArraySize(g_qm_london_public_date_keys);
   if(ArrayResize(g_qm_london_public_date_keys, n + 1) != n + 1)
      return false;
   g_qm_london_public_date_keys[n] = date_key;
   return true;
  }

bool QM_LondonPublicHolidayCalendarLoad()
  {
   if(g_qm_london_public_attempted)
      return g_qm_london_public_ready;
   g_qm_london_public_attempted = true;
   g_qm_london_public_actual_sha256 = "";
   ArrayResize(g_qm_london_public_date_keys, 0);

   if(!QM_LondonCalendarEnsureManifest())
      return QM_LondonPublicHolidayFail("manifest_" +
                                        g_qm_london_manifest_last_error);
   if(!QM_LondonCalendarCommonFileSha256(QM_LONDON_PUBLIC_HOLIDAY_FILE,
                                         g_qm_london_public_actual_sha256))
      return QM_LondonPublicHolidayFail("runtime_file_missing_or_unreadable");
   if(QM_LondonCalendarUpper(g_qm_london_public_actual_sha256) !=
      QM_LONDON_PUBLIC_HOLIDAY_SHA256)
      return QM_LondonPublicHolidayFail("runtime_sha256_mismatch");

   const int handle = FileOpen(QM_LONDON_PUBLIC_HOLIDAY_FILE,
                               FILE_READ | FILE_CSV | FILE_ANSI |
                               FILE_SHARE_READ | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return QM_LondonPublicHolidayFail("runtime_csv_open_failed");
   const string header_date =
      QM_LondonCalendarTrimmed(FileReadString(handle));
   const string header_type =
      QM_LondonCalendarTrimmed(FileReadString(handle));
   if(header_date != "date_london" || header_type != "day_type")
     {
      FileClose(handle);
      return QM_LondonPublicHolidayFail("runtime_csv_header_invalid");
     }

   int rows = 0;
   int previous_date_key = 0;
   while(!FileIsEnding(handle))
     {
      const string date_text =
         QM_LondonCalendarTrimmed(FileReadString(handle));
      const string type_text =
         QM_LondonCalendarTrimmed(FileReadString(handle));
      if(date_text == "" && type_text == "")
         continue;
      int date_key = 0;
      if(!QM_LondonCalendarParseDateKey(date_text, date_key) ||
         type_text != "PUBLIC_OR_BANK_HOLIDAY" ||
         date_key < QM_LONDON_PUBLIC_HOLIDAY_COVERAGE_START ||
         date_key > QM_LONDON_PUBLIC_HOLIDAY_COVERAGE_END ||
         date_key <= previous_date_key ||
         !QM_LondonCalendarIsWeekday(date_key) ||
         !QM_LondonPublicHolidayAppend(date_key))
        {
         FileClose(handle);
         return QM_LondonPublicHolidayFail("runtime_csv_row_invalid");
        }
      previous_date_key = date_key;
      ++rows;
     }
   FileClose(handle);
   if(rows != QM_LONDON_PUBLIC_HOLIDAY_EXPECTED_ROWS ||
      ArraySize(g_qm_london_public_date_keys) != rows)
      return QM_LondonPublicHolidayFail("runtime_csv_count_contract_failed");

   g_qm_london_public_ready = true;
   g_qm_london_public_last_error = "";
   return true;
  }

int QM_LondonCalendarFindDate(const int date_key, const int &date_keys[])
  {
   int lo = 0;
   int hi = ArraySize(date_keys);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(date_keys[mid] < date_key)
         lo = mid + 1;
      else
         hi = mid;
     }
   if(lo < ArraySize(date_keys) && date_keys[lo] == date_key)
      return lo;
   return -1;
  }

QM_LondonPublicDayType QM_LondonPublicHolidayClassify(const int date_key)
  {
   if(!g_qm_london_public_ready)
      return QM_LONDON_PUBLIC_DAY_INVALID;
   MqlDateTime parts;
   if(!QM_LondonCalendarDateKeyParts(date_key, parts))
      return QM_LONDON_PUBLIC_DAY_INVALID;
   if(date_key < QM_LONDON_PUBLIC_HOLIDAY_COVERAGE_START ||
      date_key > QM_LONDON_PUBLIC_HOLIDAY_COVERAGE_END)
      return QM_LONDON_PUBLIC_DAY_OUT_OF_COVERAGE;
   if(parts.day_of_week < 1 || parts.day_of_week > 5)
      return QM_LONDON_PUBLIC_DAY_WEEKEND;
   if(QM_LondonCalendarFindDate(date_key,
                                g_qm_london_public_date_keys) >= 0)
      return QM_LONDON_PUBLIC_DAY_PUBLIC_OR_BANK_HOLIDAY;
   return QM_LONDON_PUBLIC_DAY_ORDINARY_WEEKDAY;
  }

string QM_LondonPublicDayTypeName(const QM_LondonPublicDayType day_type)
  {
   if(day_type == QM_LONDON_PUBLIC_DAY_ORDINARY_WEEKDAY)
      return "ORDINARY_WEEKDAY";
   if(day_type == QM_LONDON_PUBLIC_DAY_PUBLIC_OR_BANK_HOLIDAY)
      return "PUBLIC_OR_BANK_HOLIDAY";
   if(day_type == QM_LONDON_PUBLIC_DAY_WEEKEND)
      return "WEEKEND";
   if(day_type == QM_LONDON_PUBLIC_DAY_OUT_OF_COVERAGE)
      return "OUT_OF_COVERAGE";
   return "INVALID";
  }

// Europe/London conversion under the UK/EU rule used throughout the covered
// 2018-2025 interval: clocks advance at 01:00 UTC on the last Sunday in March
// and return at 01:00 UTC on the last Sunday in October.  Local-to-UTC checks
// both possible offsets and rejects ambiguous or nonexistent wall-clock labels.
datetime QM_LondonCalendarLastSundayAtOneUTC(const int year, const int month)
  {
   if(year < 1900 || year > 2999 || (month != 3 && month != 10))
      return 0;
   MqlDateTime next_month;
   ZeroMemory(next_month);
   next_month.year = year;
   next_month.mon = month + 1;
   next_month.day = 1;
   const datetime next_month_start = StructToTime(next_month);
   MqlDateTime last_day;
   if(next_month_start <= 0 ||
      !TimeToStruct(next_month_start - 86400, last_day))
      return 0;
   last_day.hour = 1;
   last_day.min = 0;
   last_day.sec = 0;
   return StructToTime(last_day) - last_day.day_of_week * 86400;
  }

int QM_LondonCalendarUtcOffsetHoursForUTC(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return -1;
   const datetime start_utc =
      QM_LondonCalendarLastSundayAtOneUTC(parts.year, 3);
   const datetime end_utc =
      QM_LondonCalendarLastSundayAtOneUTC(parts.year, 10);
   if(start_utc <= 0 || end_utc <= start_utc)
      return -1;
   return (utc >= start_utc && utc < end_utc) ? 1 : 0;
  }

datetime QM_LondonCalendarUTCToLondonLocal(const datetime utc)
  {
   const int offset_hours = QM_LondonCalendarUtcOffsetHoursForUTC(utc);
   return (offset_hours >= 0 ? utc + offset_hours * 3600 : 0);
  }

int QM_LondonCalendarDateKeyFromUTC(const datetime utc)
  {
   const datetime local = QM_LondonCalendarUTCToLondonLocal(utc);
   MqlDateTime parts;
   if(local <= 0 || !TimeToStruct(local, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

bool QM_LondonCalendarLondonLocalToUTC(const int date_key,
                                       const int hour,
                                       const int minute,
                                       datetime &utc)
  {
   utc = 0;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;
   MqlDateTime local_parts;
   if(!QM_LondonCalendarDateKeyParts(date_key, local_parts))
      return false;
   local_parts.hour = hour;
   local_parts.min = minute;
   local_parts.sec = 0;
   const datetime local_label = StructToTime(local_parts);
   if(local_label <= 0)
      return false;

   datetime resolved = 0;
   int valid_candidates = 0;
   for(int offset_hours = 0; offset_hours <= 1; ++offset_hours)
     {
      const datetime candidate = local_label - offset_hours * 3600;
      if(QM_LondonCalendarUtcOffsetHoursForUTC(candidate) != offset_hours ||
         QM_LondonCalendarUTCToLondonLocal(candidate) != local_label)
         continue;
      resolved = candidate;
      ++valid_candidates;
     }
   if(valid_candidates != 1)
      return false;
   utc = resolved;
   return true;
  }

bool QM_LondonLseCashFail(const string detail)
  {
   g_qm_london_lse_ready = false;
   g_qm_london_lse_last_error = detail;
   ArrayResize(g_qm_london_lse_date_keys, 0);
   ArrayResize(g_qm_london_lse_session_types, 0);
   return false;
  }

bool QM_LondonLseCashAppend(const int date_key,
                            const QM_LondonLseCashSessionType session_type)
  {
   const int n = ArraySize(g_qm_london_lse_date_keys);
   if(ArrayResize(g_qm_london_lse_date_keys, n + 1) != n + 1 ||
      ArrayResize(g_qm_london_lse_session_types, n + 1) != n + 1)
      return false;
   g_qm_london_lse_date_keys[n] = date_key;
   g_qm_london_lse_session_types[n] = (int)session_type;
   return true;
  }

bool QM_LondonLseCashCalendarLoad()
  {
   if(g_qm_london_lse_attempted)
      return g_qm_london_lse_ready;
   g_qm_london_lse_attempted = true;
   g_qm_london_lse_actual_sha256 = "";
   ArrayResize(g_qm_london_lse_date_keys, 0);
   ArrayResize(g_qm_london_lse_session_types, 0);

   if(!QM_LondonCalendarEnsureManifest())
      return QM_LondonLseCashFail("manifest_" +
                                  g_qm_london_manifest_last_error);
   if(!QM_LondonCalendarCommonFileSha256(QM_LONDON_LSE_CASH_FILE,
                                         g_qm_london_lse_actual_sha256))
      return QM_LondonLseCashFail("runtime_file_missing_or_unreadable");
   if(QM_LondonCalendarUpper(g_qm_london_lse_actual_sha256) !=
      QM_LONDON_LSE_CASH_SHA256)
      return QM_LondonLseCashFail("runtime_sha256_mismatch");

   const int handle = FileOpen(QM_LONDON_LSE_CASH_FILE,
                               FILE_READ | FILE_CSV | FILE_ANSI |
                               FILE_SHARE_READ | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return QM_LondonLseCashFail("runtime_csv_open_failed");
   const string header_date =
      QM_LondonCalendarTrimmed(FileReadString(handle));
   const string header_type =
      QM_LondonCalendarTrimmed(FileReadString(handle));
   const string header_open =
      QM_LondonCalendarTrimmed(FileReadString(handle));
   const string header_close =
      QM_LondonCalendarTrimmed(FileReadString(handle));
   if(header_date != "date_london" || header_type != "session_type" ||
      header_open != "regular_open_london" ||
      header_close != "regular_close_london")
     {
      FileClose(handle);
      return QM_LondonLseCashFail("runtime_csv_header_invalid");
     }

   int rows = 0;
   int full_close_rows = 0;
   int early_close_rows = 0;
   int previous_date_key = 0;
   while(!FileIsEnding(handle))
     {
      const string date_text =
         QM_LondonCalendarTrimmed(FileReadString(handle));
      const string type_text =
         QM_LondonCalendarTrimmed(FileReadString(handle));
      const string open_text =
         QM_LondonCalendarTrimmed(FileReadString(handle));
      const string close_text =
         QM_LondonCalendarTrimmed(FileReadString(handle));
      if(date_text == "" && type_text == "" && open_text == "" &&
         close_text == "")
         continue;

      int date_key = 0;
      QM_LondonLseCashSessionType session_type =
         QM_LONDON_LSE_CASH_INVALID;
      if(type_text == "FULL_CLOSE")
        {
         if(open_text != "" || close_text != "")
           {
            FileClose(handle);
            return QM_LondonLseCashFail(
               "full_close_time_fields_not_empty");
           }
         session_type = QM_LONDON_LSE_CASH_FULL_CLOSE;
         ++full_close_rows;
        }
      else if(type_text == "EARLY_CLOSE")
        {
         if(open_text != "08:00" || close_text != "12:30")
           {
            FileClose(handle);
            return QM_LondonLseCashFail(
               "early_close_time_fields_invalid");
           }
         session_type = QM_LONDON_LSE_CASH_EARLY_CLOSE;
         ++early_close_rows;
        }
      else
        {
         FileClose(handle);
         return QM_LondonLseCashFail("runtime_csv_session_type_invalid");
        }

      if(!QM_LondonCalendarParseDateKey(date_text, date_key) ||
         date_key < QM_LONDON_LSE_CASH_COVERAGE_START ||
         date_key > QM_LONDON_LSE_CASH_COVERAGE_END ||
         date_key <= previous_date_key ||
         !QM_LondonCalendarIsWeekday(date_key) ||
         !QM_LondonLseCashAppend(date_key, session_type))
        {
         FileClose(handle);
         return QM_LondonLseCashFail("runtime_csv_row_invalid");
        }
      previous_date_key = date_key;
      ++rows;
     }
   FileClose(handle);
   if(rows != QM_LONDON_LSE_CASH_EXPECTED_ROWS ||
      full_close_rows != QM_LONDON_LSE_CASH_EXPECTED_FULL_CLOSE_ROWS ||
      early_close_rows != QM_LONDON_LSE_CASH_EXPECTED_EARLY_CLOSE_ROWS ||
      ArraySize(g_qm_london_lse_date_keys) != rows ||
      ArraySize(g_qm_london_lse_session_types) != rows)
      return QM_LondonLseCashFail("runtime_csv_count_contract_failed");

   g_qm_london_lse_ready = true;
   g_qm_london_lse_last_error = "";
   return true;
  }

QM_LondonLseCashSessionType QM_LondonLseCashCalendarClassify(
   const int date_key)
  {
   if(!g_qm_london_lse_ready)
      return QM_LONDON_LSE_CASH_INVALID;
   MqlDateTime parts;
   if(!QM_LondonCalendarDateKeyParts(date_key, parts))
      return QM_LONDON_LSE_CASH_INVALID;
   if(date_key < QM_LONDON_LSE_CASH_COVERAGE_START ||
      date_key > QM_LONDON_LSE_CASH_COVERAGE_END)
      return QM_LONDON_LSE_CASH_OUT_OF_COVERAGE;
   if(parts.day_of_week < 1 || parts.day_of_week > 5)
      return QM_LONDON_LSE_CASH_FULL_CLOSE;
   const int index =
      QM_LondonCalendarFindDate(date_key, g_qm_london_lse_date_keys);
   if(index < 0)
      return QM_LONDON_LSE_CASH_NORMAL;
   return (QM_LondonLseCashSessionType)
      g_qm_london_lse_session_types[index];
  }

string QM_LondonLseCashSessionTypeName(
   const QM_LondonLseCashSessionType session_type)
  {
   if(session_type == QM_LONDON_LSE_CASH_NORMAL)
      return "NORMAL";
   if(session_type == QM_LONDON_LSE_CASH_FULL_CLOSE)
      return "FULL_CLOSE";
   if(session_type == QM_LONDON_LSE_CASH_EARLY_CLOSE)
      return "EARLY_CLOSE";
   if(session_type == QM_LONDON_LSE_CASH_OUT_OF_COVERAGE)
      return "OUT_OF_COVERAGE";
   return "INVALID";
  }

bool QM_LondonLseCashSessionUTC(
   const int date_key,
   QM_LondonLseCashSessionType &session_type,
   datetime &open_utc,
   datetime &close_utc)
  {
   open_utc = 0;
   close_utc = 0;
   session_type = QM_LondonLseCashCalendarClassify(date_key);
   if(session_type != QM_LONDON_LSE_CASH_NORMAL &&
      session_type != QM_LONDON_LSE_CASH_EARLY_CLOSE)
      return false;
   const int close_hour =
      (session_type == QM_LONDON_LSE_CASH_EARLY_CLOSE ? 12 : 16);
   const int close_minute = 30;
   if(!QM_LondonCalendarLondonLocalToUTC(date_key, 8, 0, open_utc) ||
      !QM_LondonCalendarLondonLocalToUTC(date_key,
                                         close_hour,
                                         close_minute,
                                         close_utc))
      return false;
   return (open_utc > 0 && close_utc > open_utc &&
           close_utc - open_utc ==
              (session_type == QM_LONDON_LSE_CASH_EARLY_CLOSE
               ? 270 * 60 : 510 * 60));
  }

bool QM_LondonLseCashCalendarReady()
  {
   return g_qm_london_lse_ready;
  }

string QM_LondonLseCashCalendarLastError()
  {
   return g_qm_london_lse_last_error;
  }

string QM_LondonLseCashCalendarActualSha256()
  {
   return g_qm_london_lse_actual_sha256;
  }

bool QM_LondonWmr1600Fail(const string detail)
  {
   g_qm_london_wmr_ready = false;
   g_qm_london_wmr_last_error = detail;
   ArrayResize(g_qm_london_wmr_date_keys, 0);
   ArrayResize(g_qm_london_wmr_statuses, 0);
   return false;
  }

bool QM_LondonWmr1600Append(const int date_key,
                            const QM_LondonWmr1600Status status)
  {
   const int n = ArraySize(g_qm_london_wmr_date_keys);
   if(ArrayResize(g_qm_london_wmr_date_keys, n + 1) != n + 1 ||
      ArrayResize(g_qm_london_wmr_statuses, n + 1) != n + 1)
      return false;
   g_qm_london_wmr_date_keys[n] = date_key;
   g_qm_london_wmr_statuses[n] = (int)status;
   return true;
  }

bool QM_LondonWmr1600CalendarLoad()
  {
   if(g_qm_london_wmr_attempted)
      return g_qm_london_wmr_ready;
   g_qm_london_wmr_attempted = true;
   g_qm_london_wmr_actual_sha256 = "";
   ArrayResize(g_qm_london_wmr_date_keys, 0);
   ArrayResize(g_qm_london_wmr_statuses, 0);

   if(!QM_LondonCalendarEnsureManifest())
      return QM_LondonWmr1600Fail("manifest_" +
                                  g_qm_london_manifest_last_error);
   if(!QM_LondonCalendarCommonFileSha256(QM_LONDON_WMR_1600_FILE,
                                         g_qm_london_wmr_actual_sha256))
      return QM_LondonWmr1600Fail("runtime_file_missing_or_unreadable");
   if(QM_LondonCalendarUpper(g_qm_london_wmr_actual_sha256) !=
      QM_LONDON_WMR_1600_SHA256)
      return QM_LondonWmr1600Fail("runtime_sha256_mismatch");

   const int handle = FileOpen(QM_LONDON_WMR_1600_FILE,
                               FILE_READ | FILE_CSV | FILE_ANSI |
                               FILE_SHARE_READ | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return QM_LondonWmr1600Fail("runtime_csv_open_failed");
   const string header_date =
      QM_LondonCalendarTrimmed(FileReadString(handle));
   const string header_status =
      QM_LondonCalendarTrimmed(FileReadString(handle));
   if(header_date != "date_london" ||
      header_status != "wmr_1600_spot_status")
     {
      FileClose(handle);
      return QM_LondonWmr1600Fail("runtime_csv_header_invalid");
     }

   int rows = 0;
   int no_fix_rows = 0;
   int available_rows = 0;
   int previous_date_key = 0;
   while(!FileIsEnding(handle))
     {
      const string date_text =
         QM_LondonCalendarTrimmed(FileReadString(handle));
      const string status_text =
         QM_LondonCalendarTrimmed(FileReadString(handle));
      if(date_text == "" && status_text == "")
         continue;

      int date_key = 0;
      QM_LondonWmr1600Status status = QM_LONDON_WMR_1600_INVALID;
      if(status_text == "NO_1600_FIX")
        {
         status = QM_LONDON_WMR_1600_NO_FIX;
         ++no_fix_rows;
        }
      else if(status_text == "NORMAL_1600_FIX_AVAILABLE")
        {
         status = QM_LONDON_WMR_1600_NORMAL_FIX_AVAILABLE;
         ++available_rows;
        }
      else if(status_text == "ONLY_1600_FIX_AVAILABLE")
        {
         status = QM_LONDON_WMR_1600_ONLY_FIX_AVAILABLE;
         ++available_rows;
        }
      else
        {
         FileClose(handle);
         return QM_LondonWmr1600Fail("runtime_csv_status_invalid");
        }

      if(!QM_LondonCalendarParseDateKey(date_text, date_key) ||
         date_key < QM_LONDON_WMR_1600_COVERAGE_START ||
         date_key > QM_LONDON_WMR_1600_COVERAGE_END ||
         date_key <= previous_date_key ||
         !QM_LondonCalendarIsWeekday(date_key) ||
         !QM_LondonWmr1600Append(date_key, status))
        {
         FileClose(handle);
         return QM_LondonWmr1600Fail("runtime_csv_row_invalid");
        }
      previous_date_key = date_key;
      ++rows;
     }
   FileClose(handle);
   if(rows != QM_LONDON_WMR_1600_EXPECTED_ROWS ||
      no_fix_rows != QM_LONDON_WMR_1600_EXPECTED_NO_FIX_ROWS ||
      available_rows != QM_LONDON_WMR_1600_EXPECTED_AVAILABLE_ROWS ||
      ArraySize(g_qm_london_wmr_date_keys) != rows ||
      ArraySize(g_qm_london_wmr_statuses) != rows)
      return QM_LondonWmr1600Fail("runtime_csv_count_contract_failed");

   g_qm_london_wmr_ready = true;
   g_qm_london_wmr_last_error = "";
   return true;
  }

QM_LondonWmr1600Status QM_LondonWmr1600Classify(const int date_key)
  {
   if(!g_qm_london_wmr_ready)
      return QM_LONDON_WMR_1600_INVALID;
   MqlDateTime parts;
   if(!QM_LondonCalendarDateKeyParts(date_key, parts))
      return QM_LONDON_WMR_1600_INVALID;
   if(date_key < QM_LONDON_WMR_1600_COVERAGE_START ||
      date_key > QM_LONDON_WMR_1600_COVERAGE_END)
      return QM_LONDON_WMR_1600_OUT_OF_COVERAGE;
   if(parts.day_of_week < 1 || parts.day_of_week > 5)
      return QM_LONDON_WMR_1600_WEEKEND;
   const int index =
      QM_LondonCalendarFindDate(date_key, g_qm_london_wmr_date_keys);
   if(index < 0)
      return QM_LONDON_WMR_1600_NORMAL_FIX_AVAILABLE;
   return (QM_LondonWmr1600Status)g_qm_london_wmr_statuses[index];
  }

bool QM_LondonWmr1600IsAvailable(const QM_LondonWmr1600Status status)
  {
   return (status == QM_LONDON_WMR_1600_NORMAL_FIX_AVAILABLE ||
           status == QM_LONDON_WMR_1600_ONLY_FIX_AVAILABLE);
  }

string QM_LondonWmr1600StatusName(const QM_LondonWmr1600Status status)
  {
   if(status == QM_LONDON_WMR_1600_NORMAL_FIX_AVAILABLE)
      return "NORMAL_1600_FIX_AVAILABLE";
   if(status == QM_LONDON_WMR_1600_ONLY_FIX_AVAILABLE)
      return "ONLY_1600_FIX_AVAILABLE";
   if(status == QM_LONDON_WMR_1600_NO_FIX)
      return "NO_1600_FIX";
   if(status == QM_LONDON_WMR_1600_WEEKEND)
      return "WEEKEND";
   if(status == QM_LONDON_WMR_1600_OUT_OF_COVERAGE)
      return "OUT_OF_COVERAGE";
   return "INVALID";
  }

bool QM_LondonPublicHolidayCalendarReady()
  {
   return g_qm_london_public_ready;
  }

string QM_LondonPublicHolidayCalendarLastError()
  {
   return g_qm_london_public_last_error;
  }

string QM_LondonPublicHolidayCalendarActualSha256()
  {
   return g_qm_london_public_actual_sha256;
  }

bool QM_LondonWmr1600CalendarReady()
  {
   return g_qm_london_wmr_ready;
  }

string QM_LondonWmr1600CalendarLastError()
  {
   return g_qm_london_wmr_last_error;
  }

string QM_LondonWmr1600CalendarActualSha256()
  {
   return g_qm_london_wmr_actual_sha256;
  }

string QM_LondonCalendarManifestActualSha256()
  {
   return g_qm_london_manifest_actual_sha256;
  }

#endif // QM_LONDON_CALENDARS_MQH
