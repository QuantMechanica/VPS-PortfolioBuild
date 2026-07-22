#ifndef QM_LBMA_GOLD_PM_CALENDAR_MQH
#define QM_LBMA_GOLD_PM_CALENDAR_MQH

// Governed ICE IBA LBMA Gold Price PM schedule package.  This loader binds the
// dense 2020-2025 planned schedule, row provenance, source registry, pinned
// Europe/London transitions, declared gaps and manifest.  It deliberately does
// not turn a planned auction into proof that the auction actually completed:
// no official historical cancellation/No-Publication ledger is available.
#define QM_LBMA_GOLD_PM_RUNTIME_FILE "QM5_LBMA_Gold_PM_schedule_20200101_20251231.csv"
#define QM_LBMA_GOLD_PM_RUNTIME_SHA256 "B71F6A2FC04565A3D7AED997B8876B7BA8B5D0B913383B4340814E56DB527D94"
#define QM_LBMA_GOLD_PM_PROVENANCE_FILE "QM5_LBMA_Gold_PM_schedule_provenance.csv"
#define QM_LBMA_GOLD_PM_PROVENANCE_SHA256 "F2507DB2327E0A8BA3407A3076C6A379F7ECF36726C505BCE7501BB856D96B16"
#define QM_LBMA_GOLD_PM_SOURCES_FILE "QM5_LBMA_Gold_PM_schedule_sources.csv"
#define QM_LBMA_GOLD_PM_SOURCES_SHA256 "4F3076944D906B1A67DC9890F883F375EA19E354AF7DB8A0B8D312118A5AD8DE"
#define QM_LBMA_GOLD_PM_TRANSITIONS_FILE "QM5_Europe_London_transitions_20180101_20251231.csv"
#define QM_LBMA_GOLD_PM_TRANSITIONS_SHA256 "D0E5ABA84B707C02F5C045EFD56BED816F7D413E3F337CB255047E501570340C"
#define QM_LBMA_GOLD_PM_EMBEDDED_CLOCK_SOURCE_SHA256 QM_LBMA_GOLD_PM_TRANSITIONS_SHA256
#define QM_LBMA_GOLD_PM_GAPS_FILE "QM5_LBMA_Gold_PM_schedule_gaps.csv"
#define QM_LBMA_GOLD_PM_GAPS_SHA256 "7A59DEAC3306A78AC3747AC2CCEC93D04C2B38E6C695145A0BBC4347451289A3"
#define QM_LBMA_GOLD_PM_MANIFEST_FILE "QM5_LBMA_Gold_PM_schedule_manifest.json"
#define QM_LBMA_GOLD_PM_MANIFEST_SHA256 "556EB64FD1DA3277568FC4AE5D84400A9780D15E60C11D18E6CC4D0530F8DA21"
#define QM_LBMA_GOLD_PM_CALENDAR_STATUS "PARTIAL_BLOCKED"
#define QM_LBMA_GOLD_PM_ACTUAL_STATUS_POLICY "PROMOTION_EVIDENCE_GAP_NO_HISTORICAL_LEDGER"

enum QM_LbmaGoldPmScheduleStatus
  {
   QM_LBMA_GOLD_PM_INVALID = 0,
   QM_LBMA_GOLD_PM_SCHEDULED = 1,
   QM_LBMA_GOLD_PM_NO_AUCTION_HOLIDAY = 2,
   QM_LBMA_GOLD_PM_NO_AUCTION_WEEKEND = 3,
   QM_LBMA_GOLD_PM_OUT_OF_COVERAGE = 4
  };

enum QM_LbmaGoldPmActualStatus
  {
   QM_LBMA_GOLD_PM_ACTUAL_UNKNOWN = 0,
   QM_LBMA_GOLD_PM_ACTUAL_COMPLETED = 1,
   QM_LBMA_GOLD_PM_ACTUAL_CANCELLED_OR_NO_PUBLICATION = 2
  };

const int QM_LBMA_GOLD_PM_REQUESTED_START = 20180101;
const int QM_LBMA_GOLD_PM_REQUESTED_END = 20251231;
const int QM_LBMA_GOLD_PM_COVERAGE_START = 20200101;
const int QM_LBMA_GOLD_PM_COVERAGE_END = 20251231;
const int QM_LBMA_GOLD_PM_EXPECTED_ROWS = 2192;
const int QM_LBMA_GOLD_PM_EXPECTED_SCHEDULED_ROWS = 1503;
const int QM_LBMA_GOLD_PM_EXPECTED_HOLIDAY_ROWS = 63;
const int QM_LBMA_GOLD_PM_EXPECTED_WEEKEND_ROWS = 626;
const int QM_LBMA_GOLD_PM_EXPECTED_TRANSITION_ROWS = 16;

bool   g_qm_lbma_gold_pm_attempted = false;
bool   g_qm_lbma_gold_pm_ready = false;
bool   g_qm_lbma_gold_pm_embedded_clock_ready = false;
string g_qm_lbma_gold_pm_last_error = "not_loaded";
string g_qm_lbma_gold_pm_runtime_actual_sha256 = "";
string g_qm_lbma_gold_pm_provenance_actual_sha256 = "";
string g_qm_lbma_gold_pm_sources_actual_sha256 = "";
string g_qm_lbma_gold_pm_transitions_actual_sha256 = "";
string g_qm_lbma_gold_pm_gaps_actual_sha256 = "";
string g_qm_lbma_gold_pm_manifest_actual_sha256 = "";
int      g_qm_lbma_gold_pm_date_key[];
int      g_qm_lbma_gold_pm_schedule_status[];
datetime g_qm_lbma_gold_pm_auction_start_utc[];
int      g_qm_lbma_gold_pm_london_offset_minutes[];
datetime g_qm_lbma_gold_pm_transition_utc[];
int      g_qm_lbma_gold_pm_transition_offset_after[];

string QM_LbmaGoldPmTrimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

string QM_LbmaGoldPmUpper(string value)
  {
   StringToUpper(value);
   return value;
  }

bool QM_LbmaGoldPmDateKeyParts(const int date_key, MqlDateTime &parts)
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

bool QM_LbmaGoldPmParseDateKey(string value,
                               int &date_key,
                               datetime &date_value)
  {
   date_key = 0;
   date_value = 0;
   value = QM_LbmaGoldPmTrimmed(value);
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
   if(!QM_LbmaGoldPmDateKeyParts(date_key, parts) ||
      parts.year != year || parts.mon != month || parts.day != day)
     {
      date_key = 0;
      return false;
     }
   date_value = StructToTime(parts);
   return (date_value > 0);
  }

bool QM_LbmaGoldPmParseUtc(string value,
                           datetime &utc,
                           int &date_key)
  {
   utc = 0;
   date_key = 0;
   value = QM_LbmaGoldPmTrimmed(value);
   if(StringLen(value) != 20 || StringSubstr(value, 4, 1) != "-" ||
      StringSubstr(value, 7, 1) != "-" ||
      StringSubstr(value, 10, 1) != "T" ||
      StringSubstr(value, 13, 1) != ":" ||
      StringSubstr(value, 16, 1) != ":" ||
      StringSubstr(value, 19, 1) != "Z")
      return false;
   const string digits = "0123456789";
   for(int i = 0; i < 19; ++i)
     {
      if(i == 4 || i == 7 || i == 10 || i == 13 || i == 16)
         continue;
      if(StringFind(digits, StringSubstr(value, i, 1)) < 0)
         return false;
     }

   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = (int)StringToInteger(StringSubstr(value, 0, 4));
   parts.mon = (int)StringToInteger(StringSubstr(value, 5, 2));
   parts.day = (int)StringToInteger(StringSubstr(value, 8, 2));
   parts.hour = (int)StringToInteger(StringSubstr(value, 11, 2));
   parts.min = (int)StringToInteger(StringSubstr(value, 14, 2));
   parts.sec = (int)StringToInteger(StringSubstr(value, 17, 2));
   utc = StructToTime(parts);
   MqlDateTime actual;
   if(utc <= 0 || !TimeToStruct(utc, actual) ||
      actual.year != parts.year || actual.mon != parts.mon ||
      actual.day != parts.day || actual.hour != parts.hour ||
      actual.min != parts.min || actual.sec != parts.sec)
     {
      utc = 0;
      return false;
     }
   date_key = parts.year * 10000 + parts.mon * 100 + parts.day;
   return true;
  }

bool QM_LbmaGoldPmCommonFileSha256(const string file_name, string &hash_hex)
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

bool QM_LbmaGoldPmCalendarFail(const string detail)
  {
   g_qm_lbma_gold_pm_ready = false;
   g_qm_lbma_gold_pm_last_error = detail;
   ArrayResize(g_qm_lbma_gold_pm_date_key, 0);
   ArrayResize(g_qm_lbma_gold_pm_schedule_status, 0);
   ArrayResize(g_qm_lbma_gold_pm_auction_start_utc, 0);
   ArrayResize(g_qm_lbma_gold_pm_london_offset_minutes, 0);
   // Keep the compile-time pinned transition table available for deterministic
   // time exits on an already-open position.  Calendar readiness remains false,
   // so this fallback can never make a new auction date entry-eligible.
   return false;
  }

bool QM_LbmaGoldPmVerifyArtifact(const string file_name,
                                 const string expected_sha256,
                                 string &actual_sha256,
                                 const string component)
  {
   actual_sha256 = "";
   if(!QM_LbmaGoldPmCommonFileSha256(file_name, actual_sha256))
      return QM_LbmaGoldPmCalendarFail(component + "_missing_or_unreadable");
   if(QM_LbmaGoldPmUpper(actual_sha256) != expected_sha256)
      return QM_LbmaGoldPmCalendarFail(component + "_sha256_mismatch");
   return true;
  }

bool QM_LbmaGoldPmAppendTransition(const datetime transition_utc,
                                   const int offset_after_minutes)
  {
   const int n = ArraySize(g_qm_lbma_gold_pm_transition_utc);
   if(ArrayResize(g_qm_lbma_gold_pm_transition_utc, n + 1) != n + 1 ||
      ArrayResize(g_qm_lbma_gold_pm_transition_offset_after, n + 1) != n + 1)
      return false;
   g_qm_lbma_gold_pm_transition_utc[n] = transition_utc;
   g_qm_lbma_gold_pm_transition_offset_after[n] = offset_after_minutes;
   return true;
  }

// Generated from QM5_Europe_London_transitions_20180101_20251231.csv at
// SHA-256 QM_LBMA_GOLD_PM_EMBEDDED_CLOCK_SOURCE_SHA256.  The embedded table is
// an exit-only restart fallback: the external artifact and every other package
// component must still pass their hashes before calendar entries are enabled.
bool QM_LbmaGoldPmLoadEmbeddedClock()
  {
   ArrayResize(g_qm_lbma_gold_pm_transition_utc, 0);
   ArrayResize(g_qm_lbma_gold_pm_transition_offset_after, 0);
   g_qm_lbma_gold_pm_embedded_clock_ready = false;

   static const long transition_epoch[16] =
     {
      1521939600, 1540688400, 1553994000, 1572138000,
      1585443600, 1603587600, 1616893200, 1635642000,
      1648342800, 1667091600, 1679792400, 1698541200,
      1711846800, 1729990800, 1743296400, 1761440400
     };
   static const int offset_after[16] =
     {
      60, 0, 60, 0, 60, 0, 60, 0,
      60, 0, 60, 0, 60, 0, 60, 0
     };

   for(int i = 0; i < QM_LBMA_GOLD_PM_EXPECTED_TRANSITION_ROWS; ++i)
     {
      if(!QM_LbmaGoldPmAppendTransition((datetime)transition_epoch[i],
                                        offset_after[i]))
         return QM_LbmaGoldPmCalendarFail("embedded_clock_init_failed");
     }
   g_qm_lbma_gold_pm_embedded_clock_ready = true;
   return true;
  }

bool QM_LbmaGoldPmLoadTransitions()
  {
   if(!g_qm_lbma_gold_pm_embedded_clock_ready ||
      ArraySize(g_qm_lbma_gold_pm_transition_utc) !=
         QM_LBMA_GOLD_PM_EXPECTED_TRANSITION_ROWS ||
      ArraySize(g_qm_lbma_gold_pm_transition_offset_after) !=
         QM_LBMA_GOLD_PM_EXPECTED_TRANSITION_ROWS)
      return QM_LbmaGoldPmCalendarFail("embedded_clock_contract_failed");

   const int handle = FileOpen(QM_LBMA_GOLD_PM_TRANSITIONS_FILE,
                               FILE_READ | FILE_CSV | FILE_ANSI |
                               FILE_SHARE_READ | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return QM_LbmaGoldPmCalendarFail("transitions_csv_open_failed");

   const string header_utc = QM_LbmaGoldPmTrimmed(FileReadString(handle));
   const string header_before = QM_LbmaGoldPmTrimmed(FileReadString(handle));
   const string header_after = QM_LbmaGoldPmTrimmed(FileReadString(handle));
   const string header_abbreviation = QM_LbmaGoldPmTrimmed(FileReadString(handle));
   const string header_source = QM_LbmaGoldPmTrimmed(FileReadString(handle));
   if(header_utc != "transition_utc" ||
      header_before != "offset_before_minutes" ||
      header_after != "offset_after_minutes" ||
      header_abbreviation != "abbreviation_after" ||
      header_source != "source_id")
     {
      FileClose(handle);
      return QM_LbmaGoldPmCalendarFail("transitions_csv_header_invalid");
     }

   int rows = 0;
   datetime previous = 0;
   while(!FileIsEnding(handle))
     {
      const string utc_text = QM_LbmaGoldPmTrimmed(FileReadString(handle));
      const string before_text = QM_LbmaGoldPmTrimmed(FileReadString(handle));
      const string after_text = QM_LbmaGoldPmTrimmed(FileReadString(handle));
      const string abbreviation = QM_LbmaGoldPmTrimmed(FileReadString(handle));
      const string source_id = QM_LbmaGoldPmTrimmed(FileReadString(handle));
      if(utc_text == "" && before_text == "" && after_text == "" &&
         abbreviation == "" && source_id == "")
         continue;

      datetime transition_utc = 0;
      int transition_date_key = 0;
       if(rows >= QM_LBMA_GOLD_PM_EXPECTED_TRANSITION_ROWS ||
          !QM_LbmaGoldPmParseUtc(utc_text, transition_utc, transition_date_key) ||
          transition_date_key < QM_LBMA_GOLD_PM_REQUESTED_START ||
          transition_date_key > QM_LBMA_GOLD_PM_REQUESTED_END ||
          transition_utc <= previous || source_id != "IANA_TZDATA_2026C" ||
          transition_utc != g_qm_lbma_gold_pm_transition_utc[rows])
        {
         FileClose(handle);
         return QM_LbmaGoldPmCalendarFail("transitions_csv_row_invalid");
        }

      const int before = (int)StringToInteger(before_text);
      const int after = (int)StringToInteger(after_text);
      const bool spring = (before_text == "0" && after_text == "60" &&
                           abbreviation == "BST");
      const bool autumn = (before_text == "60" && after_text == "0" &&
                           abbreviation == "GMT");
       if((!spring && !autumn) || before < 0 || after < 0 ||
          after != g_qm_lbma_gold_pm_transition_offset_after[rows])
        {
         FileClose(handle);
         return QM_LbmaGoldPmCalendarFail("transitions_csv_contract_invalid");
        }
      previous = transition_utc;
      ++rows;
     }
   FileClose(handle);

   if(rows != QM_LBMA_GOLD_PM_EXPECTED_TRANSITION_ROWS ||
      ArraySize(g_qm_lbma_gold_pm_transition_utc) != rows ||
      ArraySize(g_qm_lbma_gold_pm_transition_offset_after) != rows)
      return QM_LbmaGoldPmCalendarFail("transitions_csv_count_contract_failed");
   return true;
  }

int QM_LbmaGoldPmLondonOffsetMinutesForUTC(const datetime utc)
  {
   if(ArraySize(g_qm_lbma_gold_pm_transition_utc) !=
      QM_LBMA_GOLD_PM_EXPECTED_TRANSITION_ROWS || utc <= 0)
      return -1;
   int offset = 0;
   for(int i = 0; i < ArraySize(g_qm_lbma_gold_pm_transition_utc); ++i)
     {
      if(utc < g_qm_lbma_gold_pm_transition_utc[i])
         break;
      offset = g_qm_lbma_gold_pm_transition_offset_after[i];
     }
   return offset;
  }

datetime QM_LbmaGoldPmUTCToLondonLocal(const datetime utc)
  {
   const int offset = QM_LbmaGoldPmLondonOffsetMinutesForUTC(utc);
   if(offset < 0)
      return 0;
   return utc + offset * 60;
  }

int QM_LbmaGoldPmLondonDateKeyFromUTC(const datetime utc)
  {
   const datetime local = QM_LbmaGoldPmUTCToLondonLocal(utc);
   MqlDateTime parts;
   if(local <= 0 || !TimeToStruct(local, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

// Both GMT and BST candidates are checked against the pinned transition table.
// Ambiguous or nonexistent London wall labels fail closed.
bool QM_LbmaGoldPmLondonLocalToUTC(const int date_key,
                                   const int hour,
                                   const int minute,
                                   datetime &utc)
  {
   utc = 0;
   if(date_key < QM_LBMA_GOLD_PM_REQUESTED_START ||
      date_key > QM_LBMA_GOLD_PM_REQUESTED_END ||
      hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;
   MqlDateTime local_parts;
   if(!QM_LbmaGoldPmDateKeyParts(date_key, local_parts))
      return false;
   local_parts.hour = hour;
   local_parts.min = minute;
   local_parts.sec = 0;
   const datetime local_label = StructToTime(local_parts);
   if(local_label <= 0)
      return false;

   datetime resolved = 0;
   int valid_candidates = 0;
   for(int offset = 0; offset <= 60; offset += 60)
     {
      const datetime candidate = local_label - offset * 60;
      if(QM_LbmaGoldPmLondonOffsetMinutesForUTC(candidate) != offset ||
         QM_LbmaGoldPmUTCToLondonLocal(candidate) != local_label)
         continue;
      resolved = candidate;
      ++valid_candidates;
     }
   if(valid_candidates != 1)
      return false;
   utc = resolved;
   return true;
  }

bool QM_LbmaGoldPmAppendRuntimeRow(const int date_key,
                                   const QM_LbmaGoldPmScheduleStatus status,
                                   const datetime auction_start_utc,
                                   const int london_offset_minutes)
  {
   const int n = ArraySize(g_qm_lbma_gold_pm_date_key);
   if(ArrayResize(g_qm_lbma_gold_pm_date_key, n + 1) != n + 1 ||
      ArrayResize(g_qm_lbma_gold_pm_schedule_status, n + 1) != n + 1 ||
      ArrayResize(g_qm_lbma_gold_pm_auction_start_utc, n + 1) != n + 1 ||
      ArrayResize(g_qm_lbma_gold_pm_london_offset_minutes, n + 1) != n + 1)
      return false;
   g_qm_lbma_gold_pm_date_key[n] = date_key;
   g_qm_lbma_gold_pm_schedule_status[n] = (int)status;
   g_qm_lbma_gold_pm_auction_start_utc[n] = auction_start_utc;
   g_qm_lbma_gold_pm_london_offset_minutes[n] = london_offset_minutes;
   return true;
  }

string QM_LbmaGoldPmAnnualSourceId(const int year)
  {
   return StringFormat("IBA_LBMA_GOLD_CALENDAR_%d", year);
  }

bool QM_LbmaGoldPmLoadRuntimeAndProvenance()
  {
   const int runtime_handle = FileOpen(QM_LBMA_GOLD_PM_RUNTIME_FILE,
                                       FILE_READ | FILE_CSV | FILE_ANSI |
                                       FILE_SHARE_READ | FILE_COMMON,
                                       ',');
   if(runtime_handle == INVALID_HANDLE)
      return QM_LbmaGoldPmCalendarFail("runtime_csv_open_failed");
   const int provenance_handle = FileOpen(QM_LBMA_GOLD_PM_PROVENANCE_FILE,
                                          FILE_READ | FILE_CSV | FILE_ANSI |
                                          FILE_SHARE_READ | FILE_COMMON,
                                          ',');
   if(provenance_handle == INVALID_HANDLE)
     {
      FileClose(runtime_handle);
      return QM_LbmaGoldPmCalendarFail("provenance_csv_open_failed");
     }

   const string runtime_header_date = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
   const string runtime_header_status = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
   const string runtime_header_local = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
   const string runtime_header_utc = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
   const string runtime_header_offset = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
   const string provenance_header_date = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
   const string provenance_header_status = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
   const string provenance_header_event = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
   const string provenance_header_qualification = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
   const string provenance_header_sources = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
   const string provenance_header_clock = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
   if(runtime_header_date != "date_london" ||
      runtime_header_status != "pm_auction_status" ||
      runtime_header_local != "auction_start_london" ||
      runtime_header_utc != "auction_start_utc" ||
      runtime_header_offset != "london_utc_offset_minutes" ||
      provenance_header_date != "date_london" ||
      provenance_header_status != "pm_auction_status" ||
      provenance_header_event != "event_name" ||
      provenance_header_qualification != "qualification" ||
      provenance_header_sources != "schedule_source_ids" ||
      provenance_header_clock != "clock_source_id")
     {
      FileClose(runtime_handle);
      FileClose(provenance_handle);
      return QM_LbmaGoldPmCalendarFail("runtime_or_provenance_header_invalid");
     }

   int rows = 0;
   int scheduled_rows = 0;
   int holiday_rows = 0;
   int weekend_rows = 0;
   datetime previous_date_value = 0;
   while(!FileIsEnding(runtime_handle))
     {
      const string date_text = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
      const string status_text = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
      const string local_text = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
      const string utc_text = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));
      const string offset_text = QM_LbmaGoldPmTrimmed(FileReadString(runtime_handle));

      const string provenance_date = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
      const string provenance_status = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
      const string provenance_event = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
      const string provenance_qualification = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
      const string provenance_sources = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));
      const string provenance_clock = QM_LbmaGoldPmTrimmed(FileReadString(provenance_handle));

      const bool runtime_empty = (date_text == "" && status_text == "" &&
                                  local_text == "" && utc_text == "" &&
                                  offset_text == "");
      const bool provenance_empty = (provenance_date == "" &&
                                     provenance_status == "" &&
                                     provenance_event == "" &&
                                     provenance_qualification == "" &&
                                     provenance_sources == "" &&
                                     provenance_clock == "");
      if(runtime_empty && provenance_empty)
         continue;
      if(runtime_empty != provenance_empty)
        {
         FileClose(runtime_handle);
         FileClose(provenance_handle);
         return QM_LbmaGoldPmCalendarFail("runtime_provenance_row_alignment_failed");
        }

      int date_key = 0;
      datetime date_value = 0;
      if(!QM_LbmaGoldPmParseDateKey(date_text, date_key, date_value) ||
         date_key < QM_LBMA_GOLD_PM_COVERAGE_START ||
         date_key > QM_LBMA_GOLD_PM_COVERAGE_END ||
         (rows == 0 && date_key != QM_LBMA_GOLD_PM_COVERAGE_START) ||
         (rows > 0 && date_value != previous_date_value + 86400) ||
         provenance_date != date_text || provenance_status != status_text ||
         provenance_event == "" || provenance_clock != "IANA_TZDATA_2026C")
        {
         FileClose(runtime_handle);
         FileClose(provenance_handle);
         return QM_LbmaGoldPmCalendarFail("runtime_provenance_date_contract_failed");
        }

      MqlDateTime date_parts;
      if(!QM_LbmaGoldPmDateKeyParts(date_key, date_parts))
        {
         FileClose(runtime_handle);
         FileClose(provenance_handle);
         return QM_LbmaGoldPmCalendarFail("runtime_date_parts_invalid");
        }
      const int year = date_parts.year;
      const string annual_source = QM_LbmaGoldPmAnnualSourceId(year);
      QM_LbmaGoldPmScheduleStatus status = QM_LBMA_GOLD_PM_INVALID;
      datetime auction_utc = 0;
      int london_offset = -1;
      if(offset_text == "0")
         london_offset = 0;
      else if(offset_text == "60")
         london_offset = 60;
      else
        {
         FileClose(runtime_handle);
         FileClose(provenance_handle);
         return QM_LbmaGoldPmCalendarFail("runtime_london_offset_invalid");
        }

      if(status_text == "SCHEDULED_PM_AUCTION")
        {
         int utc_date_key = 0;
         if(local_text != "15:00:00" ||
            !QM_LbmaGoldPmParseUtc(utc_text, auction_utc, utc_date_key) ||
            utc_date_key != date_key ||
            QM_LbmaGoldPmLondonOffsetMinutesForUTC(auction_utc) != london_offset ||
            QM_LbmaGoldPmUTCToLondonLocal(auction_utc) != date_value + 15 * 3600 ||
            provenance_qualification != "OFFICIAL_DAILY_METHOD_PLUS_ANNUAL_CALENDAR_COMPLEMENT" ||
            provenance_sources != annual_source + ";IBA_PRECIOUS_METALS_METHODOLOGY_2026")
           {
            FileClose(runtime_handle);
            FileClose(provenance_handle);
            return QM_LbmaGoldPmCalendarFail("scheduled_row_contract_failed");
           }
         status = QM_LBMA_GOLD_PM_SCHEDULED;
         ++scheduled_rows;
        }
      else if(status_text == "NO_PM_AUCTION_HOLIDAY")
        {
         if(local_text != "" || utc_text != "" ||
            date_parts.day_of_week < 1 || date_parts.day_of_week > 5 ||
            provenance_qualification != "OFFICIAL_ANNUAL_PM_NO_AUCTION_ROW" ||
            provenance_sources != annual_source)
           {
            FileClose(runtime_handle);
            FileClose(provenance_handle);
            return QM_LbmaGoldPmCalendarFail("holiday_row_contract_failed");
           }
         status = QM_LBMA_GOLD_PM_NO_AUCTION_HOLIDAY;
         ++holiday_rows;
        }
      else if(status_text == "NO_PM_AUCTION_WEEKEND")
        {
         if(local_text != "" || utc_text != "" ||
            (date_parts.day_of_week >= 1 && date_parts.day_of_week <= 5) ||
            provenance_event != "Weekend" ||
            provenance_qualification != "OFFICIAL_LONDON_BUSINESS_DAY_RULE" ||
            provenance_sources != "IBA_PRECIOUS_METALS_METHODOLOGY_2026")
           {
            FileClose(runtime_handle);
            FileClose(provenance_handle);
            return QM_LbmaGoldPmCalendarFail("weekend_row_contract_failed");
           }
         status = QM_LBMA_GOLD_PM_NO_AUCTION_WEEKEND;
         ++weekend_rows;
        }
      else
        {
         FileClose(runtime_handle);
         FileClose(provenance_handle);
         return QM_LbmaGoldPmCalendarFail("runtime_schedule_status_invalid");
        }

      if(!QM_LbmaGoldPmAppendRuntimeRow(date_key,
                                        status,
                                        auction_utc,
                                        london_offset))
        {
         FileClose(runtime_handle);
         FileClose(provenance_handle);
         return QM_LbmaGoldPmCalendarFail("runtime_array_append_failed");
        }
      previous_date_value = date_value;
      ++rows;
     }

   const bool provenance_has_extra_rows = !FileIsEnding(provenance_handle);
   FileClose(runtime_handle);
   FileClose(provenance_handle);
   if(provenance_has_extra_rows)
      return QM_LbmaGoldPmCalendarFail("provenance_has_extra_rows");
   if(rows != QM_LBMA_GOLD_PM_EXPECTED_ROWS ||
      scheduled_rows != QM_LBMA_GOLD_PM_EXPECTED_SCHEDULED_ROWS ||
      holiday_rows != QM_LBMA_GOLD_PM_EXPECTED_HOLIDAY_ROWS ||
      weekend_rows != QM_LBMA_GOLD_PM_EXPECTED_WEEKEND_ROWS ||
      ArraySize(g_qm_lbma_gold_pm_date_key) != rows ||
      g_qm_lbma_gold_pm_date_key[rows - 1] != QM_LBMA_GOLD_PM_COVERAGE_END)
      return QM_LbmaGoldPmCalendarFail("runtime_count_contract_failed");
   return true;
  }

bool QM_LbmaGoldPmCalendarLoad()
  {
   if(g_qm_lbma_gold_pm_attempted)
      return g_qm_lbma_gold_pm_ready;
   g_qm_lbma_gold_pm_attempted = true;
   g_qm_lbma_gold_pm_ready = false;
   g_qm_lbma_gold_pm_last_error = "loading";
   g_qm_lbma_gold_pm_runtime_actual_sha256 = "";
   g_qm_lbma_gold_pm_provenance_actual_sha256 = "";
   g_qm_lbma_gold_pm_sources_actual_sha256 = "";
   g_qm_lbma_gold_pm_transitions_actual_sha256 = "";
   g_qm_lbma_gold_pm_gaps_actual_sha256 = "";
   g_qm_lbma_gold_pm_manifest_actual_sha256 = "";
   ArrayResize(g_qm_lbma_gold_pm_date_key, 0);
   ArrayResize(g_qm_lbma_gold_pm_schedule_status, 0);
   ArrayResize(g_qm_lbma_gold_pm_auction_start_utc, 0);
   ArrayResize(g_qm_lbma_gold_pm_london_offset_minutes, 0);
   ArrayResize(g_qm_lbma_gold_pm_transition_utc, 0);
   ArrayResize(g_qm_lbma_gold_pm_transition_offset_after, 0);
   g_qm_lbma_gold_pm_embedded_clock_ready = false;

   if(!QM_LbmaGoldPmLoadEmbeddedClock())
      return false;

   if(!QM_LbmaGoldPmVerifyArtifact(QM_LBMA_GOLD_PM_RUNTIME_FILE,
                                    QM_LBMA_GOLD_PM_RUNTIME_SHA256,
                                    g_qm_lbma_gold_pm_runtime_actual_sha256,
                                    "runtime") ||
      !QM_LbmaGoldPmVerifyArtifact(QM_LBMA_GOLD_PM_PROVENANCE_FILE,
                                    QM_LBMA_GOLD_PM_PROVENANCE_SHA256,
                                    g_qm_lbma_gold_pm_provenance_actual_sha256,
                                    "provenance") ||
      !QM_LbmaGoldPmVerifyArtifact(QM_LBMA_GOLD_PM_SOURCES_FILE,
                                    QM_LBMA_GOLD_PM_SOURCES_SHA256,
                                    g_qm_lbma_gold_pm_sources_actual_sha256,
                                    "sources") ||
      !QM_LbmaGoldPmVerifyArtifact(QM_LBMA_GOLD_PM_TRANSITIONS_FILE,
                                    QM_LBMA_GOLD_PM_TRANSITIONS_SHA256,
                                    g_qm_lbma_gold_pm_transitions_actual_sha256,
                                    "transitions") ||
      !QM_LbmaGoldPmVerifyArtifact(QM_LBMA_GOLD_PM_GAPS_FILE,
                                    QM_LBMA_GOLD_PM_GAPS_SHA256,
                                    g_qm_lbma_gold_pm_gaps_actual_sha256,
                                    "gaps") ||
      !QM_LbmaGoldPmVerifyArtifact(QM_LBMA_GOLD_PM_MANIFEST_FILE,
                                    QM_LBMA_GOLD_PM_MANIFEST_SHA256,
                                    g_qm_lbma_gold_pm_manifest_actual_sha256,
                                    "manifest"))
      return false;
   if(!QM_LbmaGoldPmLoadTransitions() ||
      !QM_LbmaGoldPmLoadRuntimeAndProvenance())
      return false;

   g_qm_lbma_gold_pm_ready = true;
   g_qm_lbma_gold_pm_last_error = "";
   return true;
  }

bool QM_LbmaGoldPmCalendarReady()
  {
   return g_qm_lbma_gold_pm_ready;
  }

bool QM_LbmaGoldPmEmbeddedClockReady()
  {
   return g_qm_lbma_gold_pm_embedded_clock_ready;
  }

string QM_LbmaGoldPmCalendarLastError()
  {
   return g_qm_lbma_gold_pm_last_error;
  }

string QM_LbmaGoldPmRuntimeActualSha256()
  {
   return g_qm_lbma_gold_pm_runtime_actual_sha256;
  }

string QM_LbmaGoldPmProvenanceActualSha256()
  {
   return g_qm_lbma_gold_pm_provenance_actual_sha256;
  }

string QM_LbmaGoldPmSourcesActualSha256()
  {
   return g_qm_lbma_gold_pm_sources_actual_sha256;
  }

string QM_LbmaGoldPmTransitionsActualSha256()
  {
   return g_qm_lbma_gold_pm_transitions_actual_sha256;
  }

string QM_LbmaGoldPmGapsActualSha256()
  {
   return g_qm_lbma_gold_pm_gaps_actual_sha256;
  }

string QM_LbmaGoldPmManifestActualSha256()
  {
   return g_qm_lbma_gold_pm_manifest_actual_sha256;
  }

int QM_LbmaGoldPmFindDate(const int date_key)
  {
   int lo = 0;
   int hi = ArraySize(g_qm_lbma_gold_pm_date_key);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_qm_lbma_gold_pm_date_key[mid] < date_key)
         lo = mid + 1;
      else
         hi = mid;
     }
   if(lo < ArraySize(g_qm_lbma_gold_pm_date_key) &&
      g_qm_lbma_gold_pm_date_key[lo] == date_key)
      return lo;
   return -1;
  }

QM_LbmaGoldPmScheduleStatus QM_LbmaGoldPmCalendarClassify(const int date_key)
  {
   if(!g_qm_lbma_gold_pm_ready)
      return QM_LBMA_GOLD_PM_INVALID;
   MqlDateTime parts;
   if(!QM_LbmaGoldPmDateKeyParts(date_key, parts))
      return QM_LBMA_GOLD_PM_INVALID;
   if(date_key < QM_LBMA_GOLD_PM_COVERAGE_START ||
      date_key > QM_LBMA_GOLD_PM_COVERAGE_END)
      return QM_LBMA_GOLD_PM_OUT_OF_COVERAGE;
   const int index = QM_LbmaGoldPmFindDate(date_key);
   if(index < 0)
      return QM_LBMA_GOLD_PM_INVALID;
   return (QM_LbmaGoldPmScheduleStatus)g_qm_lbma_gold_pm_schedule_status[index];
  }

bool QM_LbmaGoldPmAuctionStartUTC(const int date_key, datetime &auction_utc)
  {
   auction_utc = 0;
   if(QM_LbmaGoldPmCalendarClassify(date_key) != QM_LBMA_GOLD_PM_SCHEDULED)
      return false;
   const int index = QM_LbmaGoldPmFindDate(date_key);
   if(index < 0 || g_qm_lbma_gold_pm_auction_start_utc[index] <= 0)
      return false;
   auction_utc = g_qm_lbma_gold_pm_auction_start_utc[index];
   return true;
  }

string QM_LbmaGoldPmScheduleStatusName(const QM_LbmaGoldPmScheduleStatus status)
  {
   if(status == QM_LBMA_GOLD_PM_SCHEDULED)
      return "SCHEDULED_PM_AUCTION";
   if(status == QM_LBMA_GOLD_PM_NO_AUCTION_HOLIDAY)
      return "NO_PM_AUCTION_HOLIDAY";
   if(status == QM_LBMA_GOLD_PM_NO_AUCTION_WEEKEND)
      return "NO_PM_AUCTION_WEEKEND";
   if(status == QM_LBMA_GOLD_PM_OUT_OF_COVERAGE)
      return "OUT_OF_VERIFIED_COVERAGE";
   return "INVALID";
  }

// No official historical date-level cancellation/No-Publication ledger was
// available for this package.  UNKNOWN is an explicit Q02/promotion evidence
// marker.  It does not override a provenance-locked SCHEDULED_PM_AUCTION row;
// a positively known cancellation or No Publication would still fail closed.
QM_LbmaGoldPmActualStatus QM_LbmaGoldPmActualStatusForDate(const int date_key)
  {
   if(QM_LbmaGoldPmCalendarClassify(date_key) != QM_LBMA_GOLD_PM_SCHEDULED)
      return QM_LBMA_GOLD_PM_ACTUAL_UNKNOWN;
   return QM_LBMA_GOLD_PM_ACTUAL_UNKNOWN;
  }

string QM_LbmaGoldPmActualStatusName(const QM_LbmaGoldPmActualStatus status)
  {
   if(status == QM_LBMA_GOLD_PM_ACTUAL_COMPLETED)
      return "COMPLETED";
   if(status == QM_LBMA_GOLD_PM_ACTUAL_CANCELLED_OR_NO_PUBLICATION)
      return "CANCELLED_OR_NO_PUBLICATION";
   return QM_LBMA_GOLD_PM_ACTUAL_STATUS_POLICY;
  }

#endif // QM_LBMA_GOLD_PM_CALENDAR_MQH
