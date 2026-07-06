#ifndef QM_NEWS_FILTER_MQH
#define QM_NEWS_FILTER_MQH

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"
#include "QM_DSTAware.mqh"
#include "..\\news_rules\\ftmo.mqh"
#include "..\\news_rules\\5ers.mqh"

// FW1 2026-05-23 — Two-axis news filter per Vault Q09 "News Impact Mode".
//
// Axis A — Temporal: how the EA reacts in the vicinity of a news event.
//   0..6 mapping is canonical per Q09. Default for V5 EAs is mode 3.
//
// Axis B — Compliance: prop-firm-specific blackout windows that compose
//   on top of the temporal mode. A trade is allowed only if BOTH axes
//   allow at the queried timestamp.
//
// Legacy `QM_NewsMode` (single enum) is kept as a backwards-compatibility
// shim — `QM_NewsAllowsTrade(symbol, t, QM_NewsMode)` still works and is
// translated to the new 2-axis internally. New code (and the V5 skeleton)
// should use `QM_NewsAllowsTrade2(symbol, t, temporal, compliance)` and
// the two new input enums directly.

enum QM_NewsTemporalMode
  {
   QM_NEWS_TEMPORAL_OFF = 0,            // mode 0 — trade through everything
   QM_NEWS_TEMPORAL_PRE30,              // mode 1 — pause 30min before event
   QM_NEWS_TEMPORAL_PRE60,              // mode 2 — pause 60min before event
   QM_NEWS_TEMPORAL_PRE30_POST30,       // mode 3 — DEFAULT (Vault Q09)
   QM_NEWS_TEMPORAL_PRE60_POST60,       // mode 4 — pause 60min pre + 60min post
   QM_NEWS_TEMPORAL_SKIP_DAY,           // mode 5 — no new opens during news day
   QM_NEWS_TEMPORAL_CLOSE_ALL_PRE       // mode 6 — close all 30min before
  };

enum QM_NewsComplianceProfile
  {
   QM_NEWS_COMPLIANCE_NONE = 0,         // no firm-specific window
   QM_NEWS_COMPLIANCE_DXZ,              // DarwinexZero house rules (placeholder)
   QM_NEWS_COMPLIANCE_FTMO,             // FTMO funded-account blackouts
   QM_NEWS_COMPLIANCE_5ERS              // The5ers blackout schedule
  };

// Legacy single-enum (PRE-FW1). Kept for backwards compatibility with old
// setfiles that still set `qm_news_mode`. Translated to (temporal, compliance)
// by QM_NewsAllowsTrade(...).
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

// Legacy → 2-axis translation. Stored as two parallel arrays so the
// translation is data-driven and visible at a glance.
QM_NewsTemporalMode QM_NewsLegacyTemporal(const QM_NewsMode mode)
  {
   switch(mode)
     {
      case QM_NEWS_OFF:         return QM_NEWS_TEMPORAL_OFF;
      case QM_NEWS_PAUSE:       return QM_NEWS_TEMPORAL_PRE30_POST30;
      case QM_NEWS_SKIP_DAY:    return QM_NEWS_TEMPORAL_SKIP_DAY;
      case QM_NEWS_FTMO_PAUSE:  return QM_NEWS_TEMPORAL_PRE30_POST30;
      case QM_NEWS_5ERS_PAUSE:  return QM_NEWS_TEMPORAL_PRE30_POST30;
      case QM_NEWS_NO_NEWS:     return QM_NEWS_TEMPORAL_SKIP_DAY;
      case QM_NEWS_NEWS_ONLY:   return QM_NEWS_TEMPORAL_OFF;
     }
   return QM_NEWS_TEMPORAL_OFF;
  }

QM_NewsComplianceProfile QM_NewsLegacyCompliance(const QM_NewsMode mode)
  {
   switch(mode)
     {
      case QM_NEWS_FTMO_PAUSE:  return QM_NEWS_COMPLIANCE_FTMO;
      case QM_NEWS_5ERS_PAUSE:  return QM_NEWS_COMPLIANCE_5ERS;
      default:                  return QM_NEWS_COMPLIANCE_NONE;
     }
  }

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
// FW7 2026-05-23 — set by QM_FrameworkInit; gates all per-tick news work.
// false → calendar never loaded, all news permissions return "allow" fast.
bool          g_qm_news_active                       = false;

// FW8 perf 2026-05-23 — events are kept sorted by event_utc ascending so
// QM_NewsInWindow can binary-search the [utc-after, utc+before] window
// instead of linear-scanning all ~95k events on every cache miss. Reduces
// per-bar cache-miss cost from O(N) to O(log N + k) where k≈events-in-window
// (typically 1-10 over a 60-minute buffer).
bool          g_qm_news_events_sorted                = false;

// FW7 2026-05-23 — per-bar verdict cache. News permission only changes at bar
// boundaries on every timeframe we trade (≥ M5); a per-tick recompute was the
// root cause of the Q02 30-60min hangs. Cache key is (symbol, broker_bar_time,
// temporal, compliance); on Q02 single-symbol runs this collapses to one
// QM_NewsAllowsTrade2 call per closed bar instead of one per tick.
string                       g_qm_news_cache_symbol     = "";
datetime                     g_qm_news_cache_bar_time   = 0;
QM_NewsTemporalMode          g_qm_news_cache_temporal   = QM_NEWS_TEMPORAL_OFF;
QM_NewsComplianceProfile     g_qm_news_cache_compliance = QM_NEWS_COMPLIANCE_NONE;
bool                         g_qm_news_cache_verdict    = true;
bool                         g_qm_news_cache_valid      = false;
datetime                     g_qm_news_cache_wall_utc   = 0; // E10: live TTL basis
int           g_qm_news_rows_loaded                  = 0;
string        g_qm_news_hash                         = "";
datetime      g_qm_news_latest_modified_utc          = 0;
datetime      g_qm_news_last_missing_log_utc         = 0;
int           g_qm_news_pause_before_minutes         = 30;
int           g_qm_news_pause_after_minutes          = 30;
int           g_qm_news_stale_max_hours              = 24 * 14;
string        g_qm_news_min_impact_upper             = "HIGH";

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

int QM_NewsImpactRank(const string impact_upper)
  {
   string value = QM_NewsUpper(QM_NewsTrim(impact_upper));
   if(value == "HIGH")
      return 3;
   if(value == "MEDIUM")
      return 2;
   if(value == "LOW")
      return 1;
   return 0;
  }

bool QM_NewsImpactMeetsMinimum(const string impact_upper, const string min_impact_upper)
  {
   int required = QM_NewsImpactRank(min_impact_upper);
   if(required <= 0)
      required = 3;
   return QM_NewsImpactRank(impact_upper) >= required;
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

//+------------------------------------------------------------------+
//| Basename of a path (last segment after \ or /).                  |
//| MT5 build 5833+ rejects FileOpen on absolute paths with drive    |
//| letter (err 5002 ERR_FILE_WRONG_FILENAME). Callers fall back to  |
//| this basename + FILE_COMMON after the absolute path is refused.  |
//+------------------------------------------------------------------+
string QM_NewsBasename(const string path)
  {
   int pos = StringLen(path) - 1;
   while(pos >= 0)
     {
      const ushort ch = StringGetCharacter(path, pos);
      if(ch == '\\' || ch == '/')
         break;
      pos--;
     }
   if(pos >= 0)
      return StringSubstr(path, pos + 1);
   return path;
  }

bool QM_NewsReadFileBytes(const string path, uchar &bytes[], datetime &modified_utc)
  {
   int handle = FileOpen(path, FILE_READ | FILE_BIN | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(path, FILE_READ | FILE_BIN | FILE_SHARE_READ | FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      // MT5 5833+ rejects absolute paths with err 5002. Fallback: basename in Common\Files.
      const string base = QM_NewsBasename(path);
      if(StringLen(base) > 0 && base != path)
         handle = FileOpen(base, FILE_READ | FILE_BIN | FILE_SHARE_READ | FILE_COMMON);
     }
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

string QM_NewsIndexCurrencies(const string normalized_symbol)
  {
   if(normalized_symbol == "NDX" || normalized_symbol == "SP500" ||
      normalized_symbol == "SPX500" || normalized_symbol == "WS30" ||
      normalized_symbol == "US30" || normalized_symbol == "US500" ||
      normalized_symbol == "USTEC")
      return "USD";
   if(normalized_symbol == "GDAXI" || normalized_symbol == "GER40" ||
      normalized_symbol == "DE40" || normalized_symbol == "STOXX50E" ||
      normalized_symbol == "EU50" || normalized_symbol == "ESP35" ||
      normalized_symbol == "FRA40" || normalized_symbol == "F40")
      return "EUR";
   if(normalized_symbol == "UK100" || normalized_symbol == "FTSE100")
      return "GBP";
   if(normalized_symbol == "JP225" || normalized_symbol == "NIK225")
      return "JPY";
   return "";
  }

bool QM_NewsEventAffectsSymbol(const string event_currency, const string symbol)
  {
   string currency = QM_NewsUpper(QM_NewsStripQuotes(event_currency));
   if(StringLen(currency) == 0 || currency == "ALL")
      return true;

   string normalized_symbol = QM_NewsNormalizeSymbol(symbol);
   string index_currencies = QM_NewsIndexCurrencies(normalized_symbol);
   if(StringLen(index_currencies) > 0)
     {
      // Mapped index/commodity: only its economy's events apply.
      string padded_idx = " " + currency + " ";
      if(StringFind(padded_idx, " " + index_currencies + " ") >= 0)
         return true;
      if(StringFind(currency, index_currencies) >= 0)
         return true;
      return false;
     }
   if(StringLen(normalized_symbol) < 6)
      return true;   // unknown short symbol: fail-closed (unchanged behavior)

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
     {
      // MT5 5833+ rejects absolute paths with err 5002. Fallback: basename in Common\Files.
      const string base = QM_NewsBasename(path);
      if(StringLen(base) > 0 && base != path)
         handle = FileOpen(base, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
     }
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
                 const int pause_after_minutes = 30,
                 const string min_impact = "high")
  {
   g_qm_news_base_dir                = base_dir;
   g_qm_news_stale_max_hours         = stale_max_hours;
   g_qm_news_pause_before_minutes    = pause_before_minutes;
   g_qm_news_pause_after_minutes     = pause_after_minutes;
   g_qm_news_min_impact_upper        = QM_NewsImpactUpper(min_impact);
   if(QM_NewsImpactRank(g_qm_news_min_impact_upper) <= 0)
      g_qm_news_min_impact_upper = "HIGH";
   g_qm_news_calendar_path_primary   = g_qm_news_base_dir + "\\news_calendar_2015_2025.csv";
   g_qm_news_calendar_path_secondary = g_qm_news_base_dir + "\\forex_factory_calendar_clean.csv";

   ArrayResize(g_qm_news_events, 0);
   g_qm_news_rows_loaded = 0;
   g_qm_news_hash = "";
   g_qm_news_latest_modified_utc = 0;
   g_qm_news_loaded = true;
   g_qm_news_available = false;
   g_qm_news_events_sorted = false; // FW8: re-sort after fresh load

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

   if(!MQLInfoInteger(MQL_TESTER))
     {
      int age_seconds = (int)(TimeGMT() - g_qm_news_latest_modified_utc);
      if(age_seconds < 0)
         age_seconds = 0;
      if(g_qm_news_stale_max_hours > 0 && age_seconds > (g_qm_news_stale_max_hours * 3600))
        {
         QM_NewsLogSetupMissing("calendar_file_stale");
         return false;
        }
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

   // 2026-07-06 audit (D5): a calendar whose every row fails to parse (format
   // drift, truncation) previously passed init with 0 events — the EA then
   // traded "news-filtered" evidence with no filter at all. Zero parsed rows
   // is always a broken calendar, never a valid state for active news axes.
   if(g_qm_news_rows_loaded <= 0)
     {
      QM_NewsLogSetupMissing("calendar_zero_rows_parsed");
      return false;
     }

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

   // FW8 perf — build the sorted index now so the first OnTick query
   // doesn't pay the one-time sort cost (~50ms for 95k events).
   QM_NewsBuildUtcIndex();

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

// FW8 perf 2026-05-23 — sort events by event_utc ascending. Idempotent: only
// the first call does real work. Insertion sort is O(N) on near-sorted data
// (calendar CSVs are chronological by nature) and worst-case O(N²); we accept
// the latter as a one-time init cost (in practice <50ms for 95k events).
void QM_NewsBuildUtcIndex()
  {
   if(g_qm_news_events_sorted)
      return;
   const int n = ArraySize(g_qm_news_events);
   if(n < 2)
     {
      g_qm_news_events_sorted = true;
      return;
     }

   // Shell sort: significantly faster than insertion sort for large,
   // partially-ordered arrays (like concatenated sorted calendar files).
   // O(N log N) to O(N^1.5) depending on gaps.
   for(int gap = n / 2; gap > 0; gap /= 2)
     {
      for(int i = gap; i < n; i++)
        {
         const QM_NewsEvent temp = g_qm_news_events[i];
         int j;
         for(j = i; j >= gap && g_qm_news_events[j - gap].event_utc > temp.event_utc; j -= gap)
           {
            g_qm_news_events[j] = g_qm_news_events[j - gap];
           }
         g_qm_news_events[j] = temp;
        }
     }
   g_qm_news_events_sorted = true;
  }

// Smallest index where g_qm_news_events[i].event_utc >= target.
// Returns n if all events are before target.
int QM_NewsLowerBoundUtc(const datetime target)
  {
   const int n = ArraySize(g_qm_news_events);
   int lo = 0;
   int hi = n;
   while(lo < hi)
     {
      const int mid = (lo + hi) / 2;
      if(g_qm_news_events[mid].event_utc < target)
         lo = mid + 1;
      else
         hi = mid;
     }
   return lo;
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
   if(!g_qm_news_events_sorted)
      QM_NewsBuildUtcIndex();

   // utc_time is in event's blackout window iff
   //   event.event_utc - before_min*60 <= utc_time <= event.event_utc + after_min*60
   // Rearranged: event.event_utc in [utc_time - after, utc_time + before].
   const datetime t_min = utc_time - (after_minutes * 60);
   const datetime t_max = utc_time + (before_minutes * 60);

   const string impact_need = QM_NewsUpper(QM_NewsTrim(impact_filter));
   const int start = QM_NewsLowerBoundUtc(t_min);
   for(int i = start; i < n; i++)
     {
      const QM_NewsEvent event = g_qm_news_events[i];
      if(event.event_utc > t_max)
         break; // sorted — no later event can match
      if(!QM_NewsEventAffectsSymbol(event.currency, symbol))
         continue;
      if(StringLen(impact_need) > 0 && event.impact_upper != impact_need)
         continue;
      if(StringLen(impact_need) == 0 && !QM_NewsImpactMeetsMinimum(event.impact_upper, g_qm_news_min_impact_upper))
         continue;
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
      if(!QM_NewsImpactMeetsMinimum(event.impact_upper, g_qm_news_min_impact_upper))
         continue;
      return true;
     }
   return false;
  }

// Internal: prop-firm blackout check for a single profile. Returns true
// if the current UTC timestamp falls inside any applicable firm window.
bool QM_NewsInFirmWindow(const QM_NewsComplianceProfile profile,
                         const datetime utc_time,
                         const string symbol)
  {
   if(profile == QM_NEWS_COMPLIANCE_NONE || profile == QM_NEWS_COMPLIANCE_DXZ)
      return false;

   const int n = ArraySize(g_qm_news_events);
   if(n == 0)
      return false;
   if(!g_qm_news_events_sorted)
      QM_NewsBuildUtcIndex();

   // Firm blackouts (FTMO, 5ers) are typically very short (2-5 minutes).
   // Searching in a +/- 60 minute window is efficient and safe.
   const datetime t_min = utc_time - 3600;
   const datetime t_max = utc_time + 3600;
   const int start = QM_NewsLowerBoundUtc(t_min);

   for(int i = start; i < n; i++)
     {
      const QM_NewsEvent event = g_qm_news_events[i];
      if(event.event_utc > t_max)
         break;
      if(!QM_NewsEventAffectsSymbol(event.currency, symbol))
         continue;
      if(!QM_NewsImpactMeetsMinimum(event.impact_upper, g_qm_news_min_impact_upper))
         continue;

      int before = 0;
      int after  = 0;
      if(profile == QM_NEWS_COMPLIANCE_FTMO)
        {
         before = QM_NewsFTMOBeforeMinutes(event.impact_upper);
         after  = QM_NewsFTMOAfterMinutes(event.impact_upper);
        }
      else if(profile == QM_NEWS_COMPLIANCE_5ERS)
        {
         before = QM_News5ersBeforeMinutes(event.impact_upper);
         after  = QM_News5ersAfterMinutes(event.impact_upper);
        }
      if(before <= 0 && after <= 0)
         continue;

      const datetime from_t = event.event_utc - (before * 60);
      const datetime to_t   = event.event_utc + (after * 60);
      if(utc_time >= from_t && utc_time <= to_t)
         return true;
     }
   return false;
  }

// AXIS A — Temporal mode allows trade at this UTC timestamp.
bool QM_NewsTemporalAllows(const string symbol,
                           const datetime utc_time,
                           const QM_NewsTemporalMode temporal)
  {
   switch(temporal)
     {
      case QM_NEWS_TEMPORAL_OFF:
         return true;

      case QM_NEWS_TEMPORAL_PRE30:
         return !QM_NewsInWindow(utc_time, symbol, 30, 0);

      case QM_NEWS_TEMPORAL_PRE60:
         return !QM_NewsInWindow(utc_time, symbol, 60, 0);

      case QM_NEWS_TEMPORAL_PRE30_POST30:
         return !QM_NewsInWindow(utc_time, symbol, 30, 30);

      case QM_NEWS_TEMPORAL_PRE60_POST60:
         return !QM_NewsInWindow(utc_time, symbol, 60, 60);

      case QM_NEWS_TEMPORAL_SKIP_DAY:
         return !QM_NewsDayHasEvent(utc_time, symbol);

      case QM_NEWS_TEMPORAL_CLOSE_ALL_PRE:
         // Entry-side behaviour: identical to PRE30 (don't open within 30min).
         // The "close all open positions" half lives in the Strategy_Manage
         // hook — TODO once the Q05/Q06 stress runners drive Mode 6 tests.
         return !QM_NewsInWindow(utc_time, symbol, 30, 0);
     }
   return false;
  }

// AXIS B — Compliance profile allows trade at this UTC timestamp.
bool QM_NewsComplianceAllows(const string symbol,
                             const datetime utc_time,
                             const QM_NewsComplianceProfile compliance)
  {
   return !QM_NewsInFirmWindow(compliance, utc_time, symbol);
  }

// ===========================================================================
// FW-LIVE 2026-06-28 (OWNER) — native MT5 Economic Calendar for LIVE blackout.
//
// The CSV calendar is a BACKTEST artifact: deterministic and available inside
// the Strategy Tester, but its event data is a fixed historical window and is
// NOT a live feed. The MQL5 Calendar API is the inverse — unavailable in the
// tester, but live and broker/MetaQuotes-maintained. So:
//   * Strategy Tester  → CSV path (unchanged, deterministic, gate-validated).
//   * Live / real-time → native MQL5 Calendar (CalendarValueHistory).
// FAIL-CLOSED on live: if the native calendar is unreachable or unpopulated,
// block trading (return false) rather than trade blind through news.
// ===========================================================================

// Calendar is "healthy" iff it returns at least one event over the recent
// probe window (proves data is actually downloaded, not just an empty query).
bool QM_NewsLiveCalendarHealthy()
  {
   const datetime to   = TimeTradeServer();
   const datetime from = to - (7 * 24 * 3600); // last 7 days
   MqlCalendarValue probe[];
   const int n = CalendarValueHistory(probe, from, to);
   return (n > 0);
  }

// True iff `server_time` is inside a min-impact blackout window for `symbol`,
// per the native calendar. out_ok=false signals the calendar is unavailable.
bool QM_NewsLiveInWindow(const string symbol, const datetime server_time,
                         const int before_minutes, const int after_minutes,
                         bool &out_ok)
  {
   out_ok = true;
   const datetime from = server_time - (after_minutes * 60);
   const datetime to   = server_time + (before_minutes * 60);
   MqlCalendarValue values[];
   const int n = CalendarValueHistory(values, from, to);
   if(n <= 0)
     {
      // No events in window — but confirm the calendar is populated at all.
      if(!QM_NewsLiveCalendarHealthy())
         out_ok = false;             // data missing → caller fails closed
      return false;
     }
   for(int i = 0; i < n; i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;
      string imp = "LOW";
      if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
         imp = "HIGH";
      else if(ev.importance == CALENDAR_IMPORTANCE_MODERATE)
         imp = "MEDIUM";
      if(!QM_NewsImpactMeetsMinimum(imp, g_qm_news_min_impact_upper))
         continue;
      MqlCalendarCountry country;
      if(!CalendarCountryById(ev.country_id, country))
         continue;
      if(!QM_NewsEventAffectsSymbol(country.currency, symbol))
         continue;
      if(values[i].time >= from && values[i].time <= to)
         return true;              // high-impact event in the blackout window
     }
   return false;
  }

// One-time live diagnostic: log calendar health + the next high-impact event the
// native calendar reports for `symbol`. Lets OWNER eyeball-verify at chart-attach
// (cross-check vs ForexFactory) that the calendar is populated and timezone-correct
// BEFORE enabling AutoTrading. Logged once per EA instance.
bool g_qm_news_live_selftest_done = false;
void QM_NewsLiveSelfTest(const string symbol)
  {
   if(g_qm_news_live_selftest_done)
      return;
   g_qm_news_live_selftest_done = true;
   const bool healthy = QM_NewsLiveCalendarHealthy();
   const datetime from = TimeTradeServer();
   const datetime to   = from + (7 * 24 * 3600);
   MqlCalendarValue values[];
   const int n = CalendarValueHistory(values, from, to);
   string next_evt = "none";
   string next_time = "";
   for(int i = 0; i < n; i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;
      string imp = "LOW";
      if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
         imp = "HIGH";
      else if(ev.importance == CALENDAR_IMPORTANCE_MODERATE)
         imp = "MEDIUM";
      if(!QM_NewsImpactMeetsMinimum(imp, g_qm_news_min_impact_upper))
         continue;
      MqlCalendarCountry country;
      if(!CalendarCountryById(ev.country_id, country))
         continue;
      if(!QM_NewsEventAffectsSymbol(country.currency, symbol))
         continue;
      next_evt = country.currency + " " + ev.name;
      next_time = TimeToString(values[i].time, TIME_DATE | TIME_MINUTES);
      break;
     }
   const string payload = StringFormat(
      "{\"healthy\":%s,\"window7d_total\":%d,\"min_impact\":\"%s\",\"next_high_impact\":\"%s\",\"next_time_srv\":\"%s\"}",
      (healthy ? "true" : "false"), n, g_qm_news_min_impact_upper, next_evt, next_time);
   QM_LogEvent(QM_INFO, "NEWS_LIVE_CALENDAR_SELFTEST", payload);
  }

// Live temporal-axis verdict (mirrors QM_NewsTemporalAllows but native-calendar).
bool QM_NewsLiveTemporalAllows(const string symbol, const datetime server_time,
                               const QM_NewsTemporalMode temporal, bool &out_ok)
  {
   out_ok = true;
   int before = 0;
   int after  = 0;
   switch(temporal)
     {
      case QM_NEWS_TEMPORAL_OFF:           return true;
      case QM_NEWS_TEMPORAL_PRE30:         before = 30;      after = 0;       break;
      case QM_NEWS_TEMPORAL_PRE60:         before = 60;      after = 0;       break;
      case QM_NEWS_TEMPORAL_PRE30_POST30:  before = 30;      after = 30;      break;
      case QM_NEWS_TEMPORAL_PRE60_POST60:  before = 60;      after = 60;      break;
      case QM_NEWS_TEMPORAL_CLOSE_ALL_PRE: before = 30;      after = 0;       break;
      case QM_NEWS_TEMPORAL_SKIP_DAY:
        {
         // E5 (2026-07-06 audit): the tester blocks the UTC calendar DAY of a
         // qualifying event (QM_NewsDayHasEvent); the previous ±24h rolling
         // window here blocked live EAs up to twice as long (a Tue 14:30
         // event blocked Mon 14:30 → Wed 14:30) — live traded a different
         // strategy than the evidence. Window = the CURRENT UTC day expressed
         // as elapsed/remaining minutes around now (minute skew immaterial).
         const datetime now_utc = TimeGMT();
         const int elapsed_min = (int)((now_utc % 86400) / 60);
         after  = elapsed_min;
         before = 24 * 60 - elapsed_min;
         break;
        }
      default:                             before = 30;      after = 30;      break;
     }
   return !QM_NewsLiveInWindow(symbol, server_time, before, after, out_ok);
  }

// Live compliance-axis verdict (native-calendar mirror of QM_NewsInFirmWindow).
// E4 fix (2026-07-06 audit): the live branch previously evaluated ONLY the
// temporal axis — FTMO/5ers firm windows were enforced in the tester CSV path
// and silently dropped live, so gate evidence was compliance-gated while live
// trading was not. Mirrors the tester exactly (incl. the min-impact pre-filter)
// for backtest/live parity; per-impact windows come from news_rules tables.
bool QM_NewsLiveComplianceAllows(const string symbol, const datetime server_time,
                                 const QM_NewsComplianceProfile compliance, bool &out_ok)
  {
   out_ok = true;
   if(compliance == QM_NEWS_COMPLIANCE_NONE || compliance == QM_NEWS_COMPLIANCE_DXZ)
      return true;

   // Widest firm window is minutes-scale; ±60min bounds every table safely.
   MqlCalendarValue values[];
   const datetime from = server_time - 3600;
   const datetime to   = server_time + 3600;
   const int n = CalendarValueHistory(values, from, to);
   if(n <= 0)
     {
      if(!QM_NewsLiveCalendarHealthy())
         out_ok = false;             // data missing → caller fails closed
      return true;                   // healthy calendar, no events near now
     }
   for(int i = 0; i < n; i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;
      string imp = "LOW";
      if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
         imp = "HIGH";
      else if(ev.importance == CALENDAR_IMPORTANCE_MODERATE)
         imp = "MEDIUM";
      if(!QM_NewsImpactMeetsMinimum(imp, g_qm_news_min_impact_upper))
         continue;
      MqlCalendarCountry country;
      if(!CalendarCountryById(ev.country_id, country))
         continue;
      if(!QM_NewsEventAffectsSymbol(country.currency, symbol))
         continue;

      int before = 0;
      int after  = 0;
      if(compliance == QM_NEWS_COMPLIANCE_FTMO)
        {
         before = QM_NewsFTMOBeforeMinutes(imp);
         after  = QM_NewsFTMOAfterMinutes(imp);
        }
      else if(compliance == QM_NEWS_COMPLIANCE_5ERS)
        {
         before = QM_News5ersBeforeMinutes(imp);
         after  = QM_News5ersAfterMinutes(imp);
        }
      if(before <= 0 && after <= 0)
         continue;

      if(server_time >= values[i].time - (before * 60) &&
         server_time <= values[i].time + (after * 60))
         return false;               // inside a firm blackout window
     }
   return true;
  }

// FW1 canonical query — two-axis composed via AND.
//
// FW7 2026-05-23 — fast-path + per-bar cache.
//   * If both axes are OFF → return true without touching anything.
//   * If g_qm_news_active was set false at framework-init time, the calendar
//     was never loaded; same fast return.
//   * Otherwise, cache the verdict per (symbol, current-bar-time, axes); per-tick
//     re-queries hit the cache after the first call per bar.
bool QM_NewsAllowsTrade2(const string symbol,
                         const datetime broker_time,
                         const QM_NewsTemporalMode temporal,
                         const QM_NewsComplianceProfile compliance)
  {
   if(temporal == QM_NEWS_TEMPORAL_OFF && compliance == QM_NEWS_COMPLIANCE_NONE)
      return true;

   // Cache lookup. Bar-time is the current chart bar's open time; one verdict
   // per bar is sufficient IN THE TESTER (deterministic CSV, bar-close edges).
   // E10 (2026-07-06 audit): LIVE verdicts additionally expire after 60s — a
   // D1/H4 chart otherwise samples 5-minute firm windows once per bar and
   // caches a transient fail-closed calendar hiccup for up to a full day.
   const datetime bar_time = iTime(symbol, _Period, 0);
   if(g_qm_news_cache_valid &&
      g_qm_news_cache_bar_time == bar_time &&
      g_qm_news_cache_symbol == symbol &&
      g_qm_news_cache_temporal == temporal &&
      g_qm_news_cache_compliance == compliance &&
      (MQLInfoInteger(MQL_TESTER) != 0 ||
       (TimeGMT() - g_qm_news_cache_wall_utc) < 60))
      return g_qm_news_cache_verdict;

   // FW-LIVE: real-time trading uses the native MT5 calendar. The CSV path below
   // is reserved for the Strategy Tester (where the Calendar API is unavailable).
   if(!MQLInfoInteger(MQL_TESTER))
     {
      QM_NewsLiveSelfTest(symbol); // one-time diagnostic for attach-time verification
      const datetime srv = (broker_time > 0 ? broker_time : TimeTradeServer());
      bool ok = true;
      bool ok_comp = true;
      const bool allows = QM_NewsLiveTemporalAllows(symbol, srv, temporal, ok);
      // E4 (2026-07-06 audit): compliance axis now enforced live too — the
      // tester branch below has always ANDed both axes; live must match.
      const bool comp_allows = QM_NewsLiveComplianceAllows(symbol, srv, compliance, ok_comp);
      bool verdict_live = (allows && comp_allows);
      if(!ok || !ok_comp)
        {
         QM_NewsLogSetupMissing("live_calendar_unavailable");
         verdict_live = false; // fail-closed: never trade blind through live news
        }
      g_qm_news_cache_symbol     = symbol;
      g_qm_news_cache_bar_time   = bar_time;
      g_qm_news_cache_temporal   = temporal;
      g_qm_news_cache_compliance = compliance;
      g_qm_news_cache_verdict    = verdict_live;
      g_qm_news_cache_valid      = true;
      g_qm_news_cache_wall_utc   = TimeGMT(); // E10: 60s live TTL
      return verdict_live;
     }

   if(!g_qm_news_active)
      return true; // tester: calendar deliberately not loaded — caller asked, we say allow.

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

   bool verdict = true;
   if(!QM_NewsTemporalAllows(symbol, utc_time, temporal))
      verdict = false;
   else if(!QM_NewsComplianceAllows(symbol, utc_time, compliance))
      verdict = false;

   g_qm_news_cache_symbol     = symbol;
   g_qm_news_cache_bar_time   = bar_time;
   g_qm_news_cache_temporal   = temporal;
   g_qm_news_cache_compliance = compliance;
   g_qm_news_cache_verdict    = verdict;
   g_qm_news_cache_valid      = true;
   return verdict;
  }

// Legacy shim — accepts the old single QM_NewsMode and delegates to the
// new 2-axis function via the translation table. Existing setfiles and old
// EAs keep working; new code uses QM_NewsAllowsTrade2 directly.
bool QM_NewsAllowsTrade(const string symbol,
                        const datetime broker_time,
                        const QM_NewsMode mode)
  {
   // NEWS_ONLY is the one legacy mode that *inverts* (trade only inside news
   // window). It doesn't compose into the 2-axis cleanly — keep its old
   // semantics here as a special case.
   if(mode == QM_NEWS_NEWS_ONLY)
     {
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
      return QM_NewsInWindow(utc_time, symbol,
                             g_qm_news_pause_before_minutes,
                             g_qm_news_pause_after_minutes);
     }

   return QM_NewsAllowsTrade2(symbol, broker_time,
                              QM_NewsLegacyTemporal(mode),
                              QM_NewsLegacyCompliance(mode));
  }

#endif // QM_NEWS_FILTER_MQH
