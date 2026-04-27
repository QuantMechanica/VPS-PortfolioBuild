#ifndef QM_NEWS_FILTER_MQH
#define QM_NEWS_FILTER_MQH

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"
#include "QM_DSTAware.mqh"
#include "..\\news_rules\\ftmo.mqh"
#include "..\\news_rules\\5ers.mqh"

enum QM_NewsMode
  {
   QM_NEWS_OFF = 0,
   QM_NEWS_PAUSE,
   QM_NEWS_SKIP_DAY,
   QM_NEWS_FTMO_PAUSE,
   QM_NEWS_5ERS_PAUSE,
   QM_NEWS_NO_NEWS,
   QM_NEWS_NEWS_ONLY
  };

struct QM_NewsEvent
  {
   datetime event_utc;
   string   currency;
   string   impact_upper;
   int      day_key_utc;
  };

string        g_qm_news_base_dir                     = "D:\\QM\\data\\news_calendar";
string        g_qm_news_calendar_path_primary        = "";
string        g_qm_news_calendar_path_secondary      = "";
QM_NewsEvent  g_qm_news_events[];
bool          g_qm_news_loaded                       = false;
bool          g_qm_news_available                    = false;
int           g_qm_news_rows_loaded                  = 0;
string        g_qm_news_hash                         = "";
datetime      g_qm_news_latest_modified_utc          = 0;
datetime      g_qm_news_last_missing_log_utc         = 0;
int           g_qm_news_pause_before_minutes         = 30;
int           g_qm_news_pause_after_minutes          = 30;
int           g_qm_news_stale_max_hours              = 24 * 14;

string QM_NewsTrim(const string value)
  {
   string out = value;
   StringTrimLeft(out);
   StringTrimRight(out);
   return out;
  }

string QM_NewsUpper(const string value)
  {
   string out = value;
   StringToUpper(out);
   return out;
  }

string QM_NewsStripQuotes(const string value)
  {
   string out = QM_NewsTrim(value);
   if(StringLen(out) >= 2 && StringGetCharacter(out, 0) == '\"' && StringGetCharacter(out, StringLen(out) - 1) == '\"')
      out = StringSubstr(out, 1, StringLen(out) - 2);
   return QM_NewsTrim(out);
  }

string QM_NewsNormalizeSymbol(const string symbol)
  {
   string out = QM_NewsUpper(QM_NewsTrim(symbol));
   int dot = StringFind(out, ".");
   if(dot > 0)
      out = StringSubstr(out, 0, dot);
   return out;
  }

int QM_NewsDayKeyUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   return (dt.year * 10000) + (dt.mon * 100) + dt.day;
  }

string QM_NewsImpactUpper(const string raw)
  {
   string value = QM_NewsUpper(QM_NewsStripQuotes(raw));
   if(StringFind(value, "HIGH") >= 0 || StringFind(value, "RED") >= 0)
      return "HIGH";
   if(StringFind(value, "MED") >= 0 || StringFind(value, "ORANGE") >= 0 || StringFind(value, "YELLOW") >= 0)
      return "MEDIUM";
   if(StringFind(value, "LOW") >= 0)
      return "LOW";
   return "UNKNOWN";
  }

bool QM_NewsParseDateTimeUTC(const string raw, datetime &out_utc)
  {
   string s = QM_NewsStripQuotes(raw);
   if(StringLen(s) == 0)
      return false;

   StringReplace(s, "T", " ");
   StringReplace(s, "Z", "");
   StringReplace(s, "/", ".");
   StringReplace(s, "-", ".");

   datetime parsed = StringToTime(s);
   if(parsed <= 0)
     {
      if(StringLen(s) >= 10)
         parsed = StringToTime(StringSubstr(s, 0, 10) + " 00:00");
     }

   if(parsed <= 0)
      return false;

   out_utc = parsed;
   return true;
  }

bool QM_NewsSplitCsvLine(const string line, string &fields[])
  {
   string clean = QM_NewsTrim(line);
   if(StringLen(clean) == 0)
      return false;
   if(StringGetCharacter(clean, 0) == '#')
      return false;
   int n = StringSplit(clean, ',', fields);
   return (n > 0);
  }

bool QM_NewsHashBytes(const uchar &data[], string &hash_hex)
  {
   uchar digest[];
   uchar key[];
   ArrayResize(key, 0);
   const int digest_size = CryptEncode(CRYPT_HASH_SHA256, data, key, digest);
   if(digest_size <= 0)
      return false;

   hash_hex = "";
   for(int i = 0; i < digest_size; i++)
      hash_hex += StringFormat("%02X", digest[i]);
   return true;
  }

bool QM_NewsReadFileBytes(const string path, uchar &bytes[], datetime &modified_utc)
  {
   int handle = FileOpen(path, FILE_READ | FILE_BIN | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(path, FILE_READ | FILE_BIN | FILE_SHARE_READ | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;

   long modified = FileGetInteger(handle, FILE_MODIFY_DATE);
   modified_utc = (datetime)modified;

   int size = (int)FileSize(handle);
   if(size < 0)
     {
      FileClose(handle);
      return false;
     }

   ArrayResize(bytes, size);
   if(size > 0)
      FileReadArray(handle, bytes, 0, size);
   FileClose(handle);
   return true;
  }

bool QM_NewsEventAffectsSymbol(const string event_currency, const string symbol)
  {
   string currency = QM_NewsUpper(QM_NewsStripQuotes(event_currency));
   if(StringLen(currency) == 0 || currency == "ALL")
      return true;

   string normalized_symbol = QM_NewsNormalizeSymbol(symbol);
   if(StringLen(normalized_symbol) < 6)
      return true;

   string base = StringSubstr(normalized_symbol, 0, 3);
   string quote = StringSubstr(normalized_symbol, 3, 3);
   string padded = " " + currency + " ";

   if(StringFind(padded, " " + base + " ") >= 0)
      return true;
   if(StringFind(padded, " " + quote + " ") >= 0)
      return true;
   if(StringFind(currency, base) >= 0)
      return true;
   if(StringFind(currency, quote) >= 0)
      return true;
   return false;
  }

bool QM_NewsPushEvent(const datetime event_utc, const string currency, const string impact_upper)
  {
   if(event_utc <= 0)
      return false;

   QM_NewsEvent event;
   event.event_utc     = event_utc;
   event.currency      = QM_NewsUpper(QM_NewsStripQuotes(currency));
   event.impact_upper  = impact_upper;
   event.day_key_utc   = QM_NewsDayKeyUTC(event_utc);

   int n = ArraySize(g_qm_news_events);
   ArrayResize(g_qm_news_events, n + 1);
   g_qm_news_events[n] = event;
   return true;
  }

bool QM_NewsLoadCsv(const string path, int &rows_added)
  {
   rows_added = 0;
   int handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;

   bool first_line = true;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringLen(line) == 0)
         continue;

      string fields[];
      if(!QM_NewsSplitCsvLine(line, fields))
         continue;

      if(first_line)
        {
         first_line = false;
         string header0 = QM_NewsUpper(QM_NewsStripQuotes(fields[0]));
         if(StringFind(header0, "DATE") >= 0 || StringFind(header0, "TIME") >= 0 || StringFind(header0, "UTC") >= 0)
            continue;
        }

      datetime event_utc = 0;
      bool parsed = false;
      if(ArraySize(fields) >= 2)
         parsed = QM_NewsParseDateTimeUTC(QM_NewsStripQuotes(fields[0]) + " " + QM_NewsStripQuotes(fields[1]), event_utc);
      if(!parsed && ArraySize(fields) >= 1)
         parsed = QM_NewsParseDateTimeUTC(fields[0], event_utc);
      if(!parsed)
         continue;

      string currency = "";
      if(ArraySize(fields) >= 3)
         currency = fields[2];

      string impact = "";
      if(ArraySize(fields) >= 4)
         impact = fields[3];

      if(QM_NewsPushEvent(event_utc, currency, QM_NewsImpactUpper(impact)))
         rows_added++;
     }

   FileClose(handle);
   return true;
  }

void QM_NewsLogSetupMissing(const string reason)
  {
   datetime now_utc = TimeGMT();
   if(g_qm_news_last_missing_log_utc > 0 && (now_utc - g_qm_news_last_missing_log_utc) < 300)
      return;

   g_qm_news_last_missing_log_utc = now_utc;
   string payload = StringFormat("{\"reason\":\"%s\",\"path_primary\":\"%s\",\"path_secondary\":\"%s\"}",
                                 reason,
                                 QM_LoggerEscapeJson(g_qm_news_calendar_path_primary),
                                 QM_LoggerEscapeJson(g_qm_news_calendar_path_secondary));
   QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING, payload);
  }

bool QM_NewsInit(const string base_dir = "D:\\QM\\data\\news_calendar",
                 const int stale_max_hours = 24 * 14,
                 const int pause_before_minutes = 30,
                 const int pause_after_minutes = 30)
  {
   g_qm_news_base_dir                = base_dir;
   g_qm_news_stale_max_hours         = stale_max_hours;
   g_qm_news_pause_before_minutes    = pause_before_minutes;
   g_qm_news_pause_after_minutes     = pause_after_minutes;
   g_qm_news_calendar_path_primary   = g_qm_news_base_dir + "\\news_calendar_2015_2025.csv";
   g_qm_news_calendar_path_secondary = g_qm_news_base_dir + "\\forex_factory_calendar_clean.csv";

   ArrayResize(g_qm_news_events, 0);
   g_qm_news_rows_loaded = 0;
   g_qm_news_hash = "";
   g_qm_news_latest_modified_utc = 0;
   g_qm_news_loaded = true;
   g_qm_news_available = false;

   uchar bytes_primary[];
   uchar bytes_secondary[];
   datetime modified_primary = 0;
   datetime modified_secondary = 0;

   if(!QM_NewsReadFileBytes(g_qm_news_calendar_path_primary, bytes_primary, modified_primary) ||
      !QM_NewsReadFileBytes(g_qm_news_calendar_path_secondary, bytes_secondary, modified_secondary))
     {
      QM_NewsLogSetupMissing("calendar_file_missing_or_unreadable");
      return false;
     }

   if(modified_primary > g_qm_news_latest_modified_utc)
      g_qm_news_latest_modified_utc = modified_primary;
   if(modified_secondary > g_qm_news_latest_modified_utc)
      g_qm_news_latest_modified_utc = modified_secondary;

   int age_seconds = (int)(TimeGMT() - g_qm_news_latest_modified_utc);
   if(age_seconds < 0)
      age_seconds = 0;
   if(g_qm_news_stale_max_hours > 0 && age_seconds > (g_qm_news_stale_max_hours * 3600))
     {
      QM_NewsLogSetupMissing("calendar_file_stale");
      return false;
     }

   int rows_primary = 0;
   int rows_secondary = 0;
   if(!QM_NewsLoadCsv(g_qm_news_calendar_path_primary, rows_primary) ||
      !QM_NewsLoadCsv(g_qm_news_calendar_path_secondary, rows_secondary))
     {
      QM_NewsLogSetupMissing("calendar_csv_parse_failed");
      return false;
     }

   g_qm_news_rows_loaded = rows_primary + rows_secondary;

   string primary_hash = "";
   string secondary_hash = "";
   if(!QM_NewsHashBytes(bytes_primary, primary_hash) || !QM_NewsHashBytes(bytes_secondary, secondary_hash))
     {
      QM_NewsLogSetupMissing("calendar_hash_failed");
      return false;
     }

   string combined = primary_hash + "|" + secondary_hash;
   uchar combined_bytes[];
   int combined_len = StringLen(combined);
   StringToCharArray(combined, combined_bytes, 0, combined_len, CP_UTF8);
   if(!QM_NewsHashBytes(combined_bytes, g_qm_news_hash))
      g_qm_news_hash = primary_hash + "+" + secondary_hash;

   string payload = StringFormat("{\"hash\":\"%s\",\"rows\":%d,\"modified_utc\":\"%s\"}",
                                 g_qm_news_hash,
                                 g_qm_news_rows_loaded,
                                 TimeToString(g_qm_news_latest_modified_utc, TIME_DATE | TIME_SECONDS));
   QM_LogEvent(QM_INFO, "NEWS_CALENDAR_LOADED", payload);

   g_qm_news_available = true;
   return true;
  }

bool QM_NewsIsLoaded()
  {
   return g_qm_news_loaded;
  }

bool QM_NewsIsAvailable()
  {
   return g_qm_news_available;
  }

string QM_NewsCalendarHash()
  {
   return g_qm_news_hash;
  }

int QM_NewsRowsLoaded()
  {
   return g_qm_news_rows_loaded;
  }

bool QM_NewsInWindow(const datetime utc_time,
                     const string symbol,
                     const int before_minutes,
                     const int after_minutes,
                     const string impact_filter = "")
  {
   const int n = ArraySize(g_qm_news_events);
   if(n == 0)
      return false;

   string impact_need = QM_NewsUpper(QM_NewsTrim(impact_filter));
   for(int i = 0; i < n; i++)
     {
      const QM_NewsEvent event = g_qm_news_events[i];
      if(!QM_NewsEventAffectsSymbol(event.currency, symbol))
         continue;

      if(StringLen(impact_need) > 0 && event.impact_upper != impact_need)
         continue;

      datetime from_t = event.event_utc - (before_minutes * 60);
      datetime to_t   = event.event_utc + (after_minutes * 60);
      if(utc_time >= from_t && utc_time <= to_t)
         return true;
     }
   return false;
  }

bool QM_NewsDayHasEvent(const datetime utc_time, const string symbol)
  {
   const int n = ArraySize(g_qm_news_events);
   if(n == 0)
      return false;

   int day_key = QM_NewsDayKeyUTC(utc_time);
   for(int i = 0; i < n; i++)
     {
      const QM_NewsEvent event = g_qm_news_events[i];
      if(event.day_key_utc != day_key)
         continue;
      if(!QM_NewsEventAffectsSymbol(event.currency, symbol))
         continue;
      return true;
     }
   return false;
  }

bool QM_NewsAllowsTrade(const string symbol, const datetime broker_time, const QM_NewsMode mode)
  {
   if(mode == QM_NEWS_OFF)
      return true;

   if(!g_qm_news_loaded)
      QM_NewsInit();

   if(!g_qm_news_available)
     {
      QM_NewsLogSetupMissing("calendar_unavailable");
      return false;
     }

   datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      utc_time = TimeGMT();

   switch(mode)
     {
      case QM_NEWS_PAUSE:
         return !QM_NewsInWindow(utc_time, symbol, g_qm_news_pause_before_minutes, g_qm_news_pause_after_minutes);

      case QM_NEWS_SKIP_DAY:
         return !QM_NewsDayHasEvent(utc_time, symbol);

      case QM_NEWS_FTMO_PAUSE:
        {
         const int n = ArraySize(g_qm_news_events);
         for(int i = 0; i < n; i++)
           {
            const QM_NewsEvent event = g_qm_news_events[i];
            if(!QM_NewsEventAffectsSymbol(event.currency, symbol))
               continue;
            int before = QM_NewsFTMOBeforeMinutes(event.impact_upper);
            int after  = QM_NewsFTMOAfterMinutes(event.impact_upper);
            if(before <= 0 && after <= 0)
               continue;
            datetime from_t = event.event_utc - (before * 60);
            datetime to_t   = event.event_utc + (after * 60);
            if(utc_time >= from_t && utc_time <= to_t)
               return false;
           }
         return true;
        }

      case QM_NEWS_5ERS_PAUSE:
        {
         const int n = ArraySize(g_qm_news_events);
         for(int i = 0; i < n; i++)
           {
            const QM_NewsEvent event = g_qm_news_events[i];
            if(!QM_NewsEventAffectsSymbol(event.currency, symbol))
               continue;
            int before = QM_News5ersBeforeMinutes(event.impact_upper);
            int after  = QM_News5ersAfterMinutes(event.impact_upper);
            if(before <= 0 && after <= 0)
               continue;
            datetime from_t = event.event_utc - (before * 60);
            datetime to_t   = event.event_utc + (after * 60);
            if(utc_time >= from_t && utc_time <= to_t)
               return false;
           }
         return true;
        }

      case QM_NEWS_NO_NEWS:
         return !QM_NewsDayHasEvent(utc_time, symbol);

      case QM_NEWS_NEWS_ONLY:
         return QM_NewsInWindow(utc_time, symbol, g_qm_news_pause_before_minutes, g_qm_news_pause_after_minutes);
     }

   return false;
  }

#endif // QM_NEWS_FILTER_MQH
