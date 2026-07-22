#ifndef QM_US_CASH_CALENDAR_MQH
#define QM_US_CASH_CALENDAR_MQH

// Canonical NYSE Group US cash-equity calendar exceptions, generated from
// provenance-locked ICE/NYSE releases.  The runtime file contains exceptions
// only: an unlisted New York weekday inside coverage is a normal 09:30-16:00
// session.  Weekends, load errors and dates outside coverage fail closed.
#define QM_US_CASH_CALENDAR_FILE "QM5_NYSE_US_cash_session_exceptions_20180101_20251231.csv"
#define QM_US_CASH_CALENDAR_SHA256 "C2E87E2F72B5A5FC09AE6632A2DDC47CFA3CFDD98AF7DEB67A42292BCAF5FD11"
#define QM_US_CASH_CALENDAR_MANIFEST_SHA256 "38CB75A7AF6E5648CCF9A2016200CD37DB634007D3A51D70D741C88F0FA32B92"

enum QM_USCashSessionType
  {
   QM_US_CASH_INVALID = 0,
   QM_US_CASH_NORMAL = 1,
   QM_US_CASH_FULL_CLOSE = 2,
   QM_US_CASH_EARLY_CLOSE = 3,
   QM_US_CASH_OUT_OF_COVERAGE = 4
  };

const int QM_US_CASH_COVERAGE_START = 20180101;
const int QM_US_CASH_COVERAGE_END = 20251231;
const int QM_US_CASH_EXPECTED_ROWS = 95;
const int QM_US_CASH_EXPECTED_FULL_CLOSE_ROWS = 77;
const int QM_US_CASH_EXPECTED_EARLY_CLOSE_ROWS = 18;

bool   g_qm_us_cash_calendar_attempted = false;
bool   g_qm_us_cash_calendar_ready = false;
string g_qm_us_cash_calendar_last_error = "not_loaded";
string g_qm_us_cash_calendar_file = "";
string g_qm_us_cash_calendar_expected_sha256 = "";
string g_qm_us_cash_calendar_actual_sha256 = "";
int    g_qm_us_cash_calendar_date_key[];
int    g_qm_us_cash_calendar_session_type[];

string QM_USCashTrimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

string QM_USCashUpper(string value)
  {
   StringToUpper(value);
   return value;
  }

bool QM_USCashIsSha256(const string value)
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

bool QM_USCashParseDateKey(string value, int &date_key)
  {
   date_key = 0;
   value = QM_USCashTrimmed(value);
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
   MqlDateTime requested;
   ZeroMemory(requested);
   requested.year = year;
   requested.mon = month;
   requested.day = day;
   const datetime timestamp = StructToTime(requested);
   MqlDateTime actual;
   if(timestamp <= 0 || !TimeToStruct(timestamp, actual) ||
      actual.year != year || actual.mon != month || actual.day != day)
      return false;
   date_key = year * 10000 + month * 100 + day;
   return true;
  }

bool QM_USCashDateKeyParts(const int date_key, MqlDateTime &parts)
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

bool QM_USCashIsWeekday(const int date_key)
  {
   MqlDateTime parts;
   if(!QM_USCashDateKeyParts(date_key, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

bool QM_USCashCommonFileSha256(const string file_name, string &hash_hex)
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

bool QM_USCashCalendarFail(const string detail)
  {
   g_qm_us_cash_calendar_ready = false;
   g_qm_us_cash_calendar_last_error = detail;
   ArrayResize(g_qm_us_cash_calendar_date_key, 0);
   ArrayResize(g_qm_us_cash_calendar_session_type, 0);
   return false;
  }

bool QM_USCashCalendarAppend(const int date_key,
                             const QM_USCashSessionType session_type)
  {
   const int n = ArraySize(g_qm_us_cash_calendar_date_key);
   if(ArrayResize(g_qm_us_cash_calendar_date_key, n + 1) != n + 1 ||
      ArrayResize(g_qm_us_cash_calendar_session_type, n + 1) != n + 1)
      return false;
   g_qm_us_cash_calendar_date_key[n] = date_key;
   g_qm_us_cash_calendar_session_type[n] = (int)session_type;
   return true;
  }

bool QM_USCashCalendarLoad(const string file_name,
                           const string expected_sha256)
  {
   const string normalized_file = QM_USCashTrimmed(file_name);
   const string normalized_expected = QM_USCashUpper(
      QM_USCashTrimmed(expected_sha256));
   if(g_qm_us_cash_calendar_attempted)
     {
      if(normalized_file != g_qm_us_cash_calendar_file ||
         normalized_expected != g_qm_us_cash_calendar_expected_sha256)
         return QM_USCashCalendarFail("configuration_changed_after_load");
      return g_qm_us_cash_calendar_ready;
     }

   g_qm_us_cash_calendar_attempted = true;
   g_qm_us_cash_calendar_file = normalized_file;
   g_qm_us_cash_calendar_expected_sha256 = normalized_expected;
   g_qm_us_cash_calendar_actual_sha256 = "";
   ArrayResize(g_qm_us_cash_calendar_date_key, 0);
   ArrayResize(g_qm_us_cash_calendar_session_type, 0);
   if(normalized_file == "" || !QM_USCashIsSha256(normalized_expected))
      return QM_USCashCalendarFail("invalid_file_or_expected_sha256");
   if(!QM_USCashCommonFileSha256(normalized_file,
                                 g_qm_us_cash_calendar_actual_sha256))
      return QM_USCashCalendarFail("runtime_file_missing_or_unreadable");
   if(QM_USCashUpper(g_qm_us_cash_calendar_actual_sha256) !=
      normalized_expected)
      return QM_USCashCalendarFail("runtime_sha256_mismatch");

   const int handle = FileOpen(normalized_file,
                               FILE_READ | FILE_CSV | FILE_ANSI |
                               FILE_SHARE_READ | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return QM_USCashCalendarFail("runtime_csv_open_failed");

   const string header_date = QM_USCashTrimmed(FileReadString(handle));
   const string header_type = QM_USCashTrimmed(FileReadString(handle));
   const string header_open = QM_USCashTrimmed(FileReadString(handle));
   const string header_close = QM_USCashTrimmed(FileReadString(handle));
   if(header_date != "date_new_york" || header_type != "session_type" ||
      header_open != "open_time_new_york" ||
      header_close != "close_time_new_york")
     {
      FileClose(handle);
      return QM_USCashCalendarFail("runtime_csv_header_invalid");
     }

   int rows = 0;
   int full_close_rows = 0;
   int early_close_rows = 0;
   int previous_date_key = 0;
   while(!FileIsEnding(handle))
     {
      const string date_text = QM_USCashTrimmed(FileReadString(handle));
      const string type_text = QM_USCashTrimmed(FileReadString(handle));
      const string open_text = QM_USCashTrimmed(FileReadString(handle));
      const string close_text = QM_USCashTrimmed(FileReadString(handle));
      if(date_text == "" && type_text == "" && open_text == "" &&
         close_text == "")
         continue;

      int date_key = 0;
      QM_USCashSessionType session_type = QM_US_CASH_INVALID;
      if(!QM_USCashParseDateKey(date_text, date_key) ||
         date_key < QM_US_CASH_COVERAGE_START ||
         date_key > QM_US_CASH_COVERAGE_END ||
         date_key <= previous_date_key || !QM_USCashIsWeekday(date_key))
        {
         FileClose(handle);
         return QM_USCashCalendarFail("runtime_csv_date_invalid");
        }
      if(type_text == "FULL_CLOSE")
        {
         if(open_text != "" || close_text != "")
           {
            FileClose(handle);
            return QM_USCashCalendarFail("full_close_time_fields_not_empty");
           }
         session_type = QM_US_CASH_FULL_CLOSE;
         ++full_close_rows;
        }
      else if(type_text == "EARLY_CLOSE")
        {
         if(open_text != "09:30" || close_text != "13:00")
           {
            FileClose(handle);
            return QM_USCashCalendarFail("early_close_time_fields_invalid");
           }
         session_type = QM_US_CASH_EARLY_CLOSE;
         ++early_close_rows;
        }
      else
        {
         FileClose(handle);
         return QM_USCashCalendarFail("runtime_csv_session_type_invalid");
        }
      if(!QM_USCashCalendarAppend(date_key, session_type))
        {
         FileClose(handle);
         return QM_USCashCalendarFail("runtime_csv_array_append_failed");
        }
      previous_date_key = date_key;
      ++rows;
     }
   FileClose(handle);

   if(rows != QM_US_CASH_EXPECTED_ROWS ||
      full_close_rows != QM_US_CASH_EXPECTED_FULL_CLOSE_ROWS ||
      early_close_rows != QM_US_CASH_EXPECTED_EARLY_CLOSE_ROWS ||
      ArraySize(g_qm_us_cash_calendar_date_key) != rows ||
      ArraySize(g_qm_us_cash_calendar_session_type) != rows)
      return QM_USCashCalendarFail("runtime_csv_count_contract_failed");

   g_qm_us_cash_calendar_ready = true;
   g_qm_us_cash_calendar_last_error = "";
   return true;
  }

bool QM_USCashCalendarReady()
  {
   return g_qm_us_cash_calendar_ready;
  }

string QM_USCashCalendarLastError()
  {
   return g_qm_us_cash_calendar_last_error;
  }

string QM_USCashCalendarActualSha256()
  {
   return g_qm_us_cash_calendar_actual_sha256;
  }

int QM_USCashCalendarFindException(const int date_key)
  {
   int lo = 0;
   int hi = ArraySize(g_qm_us_cash_calendar_date_key);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_qm_us_cash_calendar_date_key[mid] < date_key)
         lo = mid + 1;
      else
         hi = mid;
     }
   if(lo < ArraySize(g_qm_us_cash_calendar_date_key) &&
      g_qm_us_cash_calendar_date_key[lo] == date_key)
      return lo;
   return -1;
  }

QM_USCashSessionType QM_USCashCalendarClassify(const int date_key)
  {
   if(!g_qm_us_cash_calendar_ready)
      return QM_US_CASH_INVALID;
   MqlDateTime parts;
   if(!QM_USCashDateKeyParts(date_key, parts))
      return QM_US_CASH_INVALID;
   if(date_key < QM_US_CASH_COVERAGE_START ||
      date_key > QM_US_CASH_COVERAGE_END)
      return QM_US_CASH_OUT_OF_COVERAGE;
   if(parts.day_of_week < 1 || parts.day_of_week > 5)
      return QM_US_CASH_FULL_CLOSE;
   const int index = QM_USCashCalendarFindException(date_key);
   if(index < 0)
      return QM_US_CASH_NORMAL;
   return (QM_USCashSessionType)g_qm_us_cash_calendar_session_type[index];
  }

string QM_USCashSessionTypeName(const QM_USCashSessionType session_type)
  {
   if(session_type == QM_US_CASH_NORMAL)
      return "NORMAL";
   if(session_type == QM_US_CASH_FULL_CLOSE)
      return "FULL_CLOSE";
   if(session_type == QM_US_CASH_EARLY_CLOSE)
      return "EARLY_CLOSE";
   if(session_type == QM_US_CASH_OUT_OF_COVERAGE)
      return "OUT_OF_COVERAGE";
   return "INVALID";
  }

#endif // QM_US_CASH_CALENDAR_MQH
