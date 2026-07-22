#ifndef QM_XETRA_CASH_CALENDAR_MQH
#define QM_XETRA_CASH_CALENDAR_MQH

// Canonical Deutsche Boerse Xetra cash-equity calendar exceptions, generated
// only from official Deutsche Boerse/Xetra PDFs.  The runtime file contains
// exceptions only: an unlisted Europe/Berlin weekday inside coverage is a
// normal 09:00-17:30 Xetra session.  Weekends, load errors and dates outside
// coverage fail closed.
#define QM_XETRA_CASH_CALENDAR_RUNTIME_FILE "QM5_XETRA_cash_session_exceptions_20180101_20251231.csv"
#define QM_XETRA_CASH_CALENDAR_RUNTIME_SHA256 "C6EA69E62BDD309C7253B2DB9B09CACB0116FF1001E0CE9CB7ACE03BDA024FF2"
#define QM_XETRA_CASH_CALENDAR_MANIFEST_SHA256 "5C914C3CE1A9C3A7C2E69C97BE0236EC3E2C401E2D8D8A2EE9EC5C29280902F1"

enum QM_XetraCashSessionType
  {
   QM_XETRA_CASH_INVALID = 0,
   QM_XETRA_CASH_NORMAL = 1,
   QM_XETRA_CASH_FULL_CLOSE = 2,
   QM_XETRA_CASH_EARLY_CLOSE = 3,
   QM_XETRA_CASH_OUT_OF_COVERAGE = 4
  };

const int QM_XETRA_CASH_COVERAGE_START = 20180101;
const int QM_XETRA_CASH_COVERAGE_END = 20251231;
const int QM_XETRA_CASH_EXPECTED_ROWS = 66;
const int QM_XETRA_CASH_EXPECTED_FULL_CLOSE_ROWS = 58;
const int QM_XETRA_CASH_EXPECTED_EARLY_CLOSE_ROWS = 8;

bool   g_qm_xetra_cash_calendar_attempted = false;
bool   g_qm_xetra_cash_calendar_ready = false;
string g_qm_xetra_cash_calendar_last_error = "not_loaded";
string g_qm_xetra_cash_calendar_file = "";
string g_qm_xetra_cash_calendar_expected_sha256 = "";
string g_qm_xetra_cash_calendar_actual_sha256 = "";
int    g_qm_xetra_cash_calendar_date_key[];
int    g_qm_xetra_cash_calendar_session_type[];

string QM_XetraCashTrimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

string QM_XetraCashUpper(string value)
  {
   StringToUpper(value);
   return value;
  }

bool QM_XetraCashIsSha256(const string value)
  {
   if(StringLen(value) != 64)
      return false;
   const string hex = "0123456789abcdefABCDEF";
   for(int i = 0; i < 64; ++i)
     {
      if(StringFind(hex, StringSubstr(value, i, 1)) < 0)
         return false;
     }
   return true;
  }

bool QM_XetraCashDateKeyParts(const int date_key, MqlDateTime &parts)
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

bool QM_XetraCashParseDateKey(string value, int &date_key)
  {
   date_key = 0;
   value = QM_XetraCashTrimmed(value);
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
   if(!QM_XetraCashDateKeyParts(date_key, parts) ||
      parts.year != year || parts.mon != month || parts.day != day)
     {
      date_key = 0;
      return false;
     }
   return true;
  }

bool QM_XetraCashIsWeekday(const int date_key)
  {
   MqlDateTime parts;
   if(!QM_XetraCashDateKeyParts(date_key, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

bool QM_XetraCashCommonFileSha256(const string file_name, string &hash_hex)
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

bool QM_XetraCashCalendarFail(const string detail)
  {
   g_qm_xetra_cash_calendar_ready = false;
   g_qm_xetra_cash_calendar_last_error = detail;
   ArrayResize(g_qm_xetra_cash_calendar_date_key, 0);
   ArrayResize(g_qm_xetra_cash_calendar_session_type, 0);
   return false;
  }

bool QM_XetraCashCalendarAppend(const int date_key,
                                const QM_XetraCashSessionType session_type)
  {
   const int n = ArraySize(g_qm_xetra_cash_calendar_date_key);
   if(ArrayResize(g_qm_xetra_cash_calendar_date_key, n + 1) != n + 1 ||
      ArrayResize(g_qm_xetra_cash_calendar_session_type, n + 1) != n + 1)
      return false;
   g_qm_xetra_cash_calendar_date_key[n] = date_key;
   g_qm_xetra_cash_calendar_session_type[n] = (int)session_type;
   return true;
  }

bool QM_XetraCashCalendarLoad(const string file_name,
                              const string expected_sha256)
  {
   const string normalized_file = QM_XetraCashTrimmed(file_name);
   const string normalized_expected = QM_XetraCashUpper(
      QM_XetraCashTrimmed(expected_sha256));
   if(g_qm_xetra_cash_calendar_attempted)
     {
      if(normalized_file != g_qm_xetra_cash_calendar_file ||
         normalized_expected != g_qm_xetra_cash_calendar_expected_sha256)
         return QM_XetraCashCalendarFail("configuration_changed_after_load");
      return g_qm_xetra_cash_calendar_ready;
     }

   g_qm_xetra_cash_calendar_attempted = true;
   g_qm_xetra_cash_calendar_file = normalized_file;
   g_qm_xetra_cash_calendar_expected_sha256 = normalized_expected;
   g_qm_xetra_cash_calendar_actual_sha256 = "";
   ArrayResize(g_qm_xetra_cash_calendar_date_key, 0);
   ArrayResize(g_qm_xetra_cash_calendar_session_type, 0);
   if(normalized_file == "" || !QM_XetraCashIsSha256(normalized_expected))
      return QM_XetraCashCalendarFail("invalid_file_or_expected_sha256");
   if(!QM_XetraCashCommonFileSha256(normalized_file,
                                    g_qm_xetra_cash_calendar_actual_sha256))
      return QM_XetraCashCalendarFail("runtime_file_missing_or_unreadable");
   if(QM_XetraCashUpper(g_qm_xetra_cash_calendar_actual_sha256) !=
      normalized_expected)
      return QM_XetraCashCalendarFail("runtime_sha256_mismatch");

   const int handle = FileOpen(normalized_file,
                               FILE_READ | FILE_CSV | FILE_ANSI |
                               FILE_SHARE_READ | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return QM_XetraCashCalendarFail("runtime_csv_open_failed");

   const string header_date = QM_XetraCashTrimmed(FileReadString(handle));
   const string header_type = QM_XetraCashTrimmed(FileReadString(handle));
   const string header_open = QM_XetraCashTrimmed(FileReadString(handle));
   const string header_close = QM_XetraCashTrimmed(FileReadString(handle));
   if(header_date != "date_berlin" || header_type != "session_type" ||
      header_open != "open_time_berlin" ||
      header_close != "close_time_berlin")
     {
      FileClose(handle);
      return QM_XetraCashCalendarFail("runtime_csv_header_invalid");
     }

   int rows = 0;
   int full_close_rows = 0;
   int early_close_rows = 0;
   int previous_date_key = 0;
   while(!FileIsEnding(handle))
     {
      const string date_text = QM_XetraCashTrimmed(FileReadString(handle));
      const string type_text = QM_XetraCashTrimmed(FileReadString(handle));
      const string open_text = QM_XetraCashTrimmed(FileReadString(handle));
      const string close_text = QM_XetraCashTrimmed(FileReadString(handle));
      if(date_text == "" && type_text == "" && open_text == "" &&
         close_text == "")
         continue;

      int date_key = 0;
      QM_XetraCashSessionType session_type = QM_XETRA_CASH_INVALID;
      if(!QM_XetraCashParseDateKey(date_text, date_key) ||
         date_key < QM_XETRA_CASH_COVERAGE_START ||
         date_key > QM_XETRA_CASH_COVERAGE_END ||
         date_key <= previous_date_key || !QM_XetraCashIsWeekday(date_key))
        {
         FileClose(handle);
         return QM_XetraCashCalendarFail("runtime_csv_date_invalid");
        }
      if(type_text == "FULL_CLOSE")
        {
         if(open_text != "" || close_text != "")
           {
            FileClose(handle);
            return QM_XetraCashCalendarFail("full_close_time_fields_not_empty");
           }
         session_type = QM_XETRA_CASH_FULL_CLOSE;
         ++full_close_rows;
        }
      else if(type_text == "EARLY_CLOSE")
        {
         if(open_text != "09:00" || close_text != "14:00")
           {
            FileClose(handle);
            return QM_XetraCashCalendarFail("early_close_time_fields_invalid");
           }
         session_type = QM_XETRA_CASH_EARLY_CLOSE;
         ++early_close_rows;
        }
      else
        {
         FileClose(handle);
         return QM_XetraCashCalendarFail("runtime_csv_session_type_invalid");
        }
      if(!QM_XetraCashCalendarAppend(date_key, session_type))
        {
         FileClose(handle);
         return QM_XetraCashCalendarFail("runtime_csv_array_append_failed");
        }
      previous_date_key = date_key;
      ++rows;
     }
   FileClose(handle);

   if(rows != QM_XETRA_CASH_EXPECTED_ROWS ||
      full_close_rows != QM_XETRA_CASH_EXPECTED_FULL_CLOSE_ROWS ||
      early_close_rows != QM_XETRA_CASH_EXPECTED_EARLY_CLOSE_ROWS ||
      ArraySize(g_qm_xetra_cash_calendar_date_key) != rows ||
      ArraySize(g_qm_xetra_cash_calendar_session_type) != rows)
      return QM_XetraCashCalendarFail("runtime_csv_count_contract_failed");

   g_qm_xetra_cash_calendar_ready = true;
   g_qm_xetra_cash_calendar_last_error = "";
   return true;
  }

bool QM_XetraCashCalendarReady()
  {
   return g_qm_xetra_cash_calendar_ready;
  }

string QM_XetraCashCalendarLastError()
  {
   return g_qm_xetra_cash_calendar_last_error;
  }

string QM_XetraCashCalendarActualSha256()
  {
   return g_qm_xetra_cash_calendar_actual_sha256;
  }

int QM_XetraCashCalendarFindException(const int date_key)
  {
   int lo = 0;
   int hi = ArraySize(g_qm_xetra_cash_calendar_date_key);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_qm_xetra_cash_calendar_date_key[mid] < date_key)
         lo = mid + 1;
      else
         hi = mid;
     }
   if(lo < ArraySize(g_qm_xetra_cash_calendar_date_key) &&
      g_qm_xetra_cash_calendar_date_key[lo] == date_key)
      return lo;
   return -1;
  }

QM_XetraCashSessionType QM_XetraCashCalendarClassify(const int date_key)
  {
   if(!g_qm_xetra_cash_calendar_ready)
      return QM_XETRA_CASH_INVALID;
   MqlDateTime parts;
   if(!QM_XetraCashDateKeyParts(date_key, parts))
      return QM_XETRA_CASH_INVALID;
   if(date_key < QM_XETRA_CASH_COVERAGE_START ||
      date_key > QM_XETRA_CASH_COVERAGE_END)
      return QM_XETRA_CASH_OUT_OF_COVERAGE;
   if(parts.day_of_week < 1 || parts.day_of_week > 5)
      return QM_XETRA_CASH_FULL_CLOSE;
   const int index = QM_XetraCashCalendarFindException(date_key);
   if(index < 0)
      return QM_XETRA_CASH_NORMAL;
   return (QM_XetraCashSessionType)g_qm_xetra_cash_calendar_session_type[index];
  }

string QM_XetraCashSessionTypeName(const QM_XetraCashSessionType session_type)
  {
   if(session_type == QM_XETRA_CASH_NORMAL)
      return "NORMAL";
   if(session_type == QM_XETRA_CASH_FULL_CLOSE)
      return "FULL_CLOSE";
   if(session_type == QM_XETRA_CASH_EARLY_CLOSE)
      return "EARLY_CLOSE";
   if(session_type == QM_XETRA_CASH_OUT_OF_COVERAGE)
      return "OUT_OF_COVERAGE";
   return "INVALID";
  }

datetime QM_XetraCashLastSundayAtOneUTC(const int year, const int month)
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
   if(next_month_start <= 0 || !TimeToStruct(next_month_start - 86400, last_day))
      return 0;
   last_day.hour = 1;
   last_day.min = 0;
   last_day.sec = 0;
   return StructToTime(last_day) - last_day.day_of_week * 86400;
  }

int QM_XetraCashBerlinUtcOffsetHoursForUTC(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return 0;
   const datetime start_utc = QM_XetraCashLastSundayAtOneUTC(parts.year, 3);
   const datetime end_utc = QM_XetraCashLastSundayAtOneUTC(parts.year, 10);
   if(start_utc <= 0 || end_utc <= start_utc)
      return 0;
   return (utc >= start_utc && utc < end_utc) ? 2 : 1;
  }

datetime QM_XetraCashUTCToBerlinLocal(const datetime utc)
  {
   const int offset_hours = QM_XetraCashBerlinUtcOffsetHoursForUTC(utc);
   return (offset_hours > 0 ? utc + offset_hours * 3600 : 0);
  }

int QM_XetraCashBerlinDateKeyFromUTC(const datetime utc)
  {
   const datetime local = QM_XetraCashUTCToBerlinLocal(utc);
   MqlDateTime parts;
   if(local <= 0 || !TimeToStruct(local, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

// Converts a Europe/Berlin wall-clock label to UTC.  Both possible UTC
// candidates are validated against the EU DST transition rule.  Ambiguous or
// nonexistent labels fail closed; Xetra session boundaries never occur in the
// Sunday transition interval.
bool QM_XetraCashBerlinLocalToUTC(const int date_key,
                                  const int hour,
                                  const int minute,
                                  datetime &utc)
  {
   utc = 0;
   if(date_key < QM_XETRA_CASH_COVERAGE_START ||
      date_key > QM_XETRA_CASH_COVERAGE_END ||
      hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;
   MqlDateTime local_parts;
   if(!QM_XetraCashDateKeyParts(date_key, local_parts))
      return false;
   local_parts.hour = hour;
   local_parts.min = minute;
   local_parts.sec = 0;
   const datetime local_label = StructToTime(local_parts);
   if(local_label <= 0)
      return false;

   datetime resolved = 0;
   int valid_candidates = 0;
   for(int offset_hours = 1; offset_hours <= 2; ++offset_hours)
     {
      const datetime candidate = local_label - offset_hours * 3600;
      if(QM_XetraCashBerlinUtcOffsetHoursForUTC(candidate) != offset_hours ||
         QM_XetraCashUTCToBerlinLocal(candidate) != local_label)
         continue;
      resolved = candidate;
      ++valid_candidates;
     }
   if(valid_candidates != 1)
      return false;
   utc = resolved;
   return true;
  }

#endif // QM_XETRA_CASH_CALENDAR_MQH
