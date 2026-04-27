#ifndef QM_LOGGER_MQH
#define QM_LOGGER_MQH

enum QM_LogLevel
  {
   QM_TRACE = 0,
   QM_INFO  = 1,
   QM_WARN  = 2,
   QM_ERROR = 3,
   QM_FATAL = 4
  };

int             g_qm_logger_ea_id                = 0;
string          g_qm_logger_slug                 = "unconfigured";
string          g_qm_logger_symbol               = "";
ENUM_TIMEFRAMES g_qm_logger_tf                   = PERIOD_CURRENT;
long            g_qm_logger_magic                = 0;
bool            g_qm_logger_initialized          = false;
string          g_qm_logger_active_path          = "";
string          g_qm_logger_primary_dir          = "";
string          g_qm_logger_fallback_dir         = "QM";

string QM_LoggerLevelToString(const QM_LogLevel level)
  {
   switch(level)
     {
      case QM_TRACE: return "TRACE";
      case QM_INFO:  return "INFO";
      case QM_WARN:  return "WARN";
      case QM_ERROR: return "ERROR";
      case QM_FATAL: return "FATAL";
     }
   return "INFO";
  }

string QM_LoggerEscapeJson(const string value)
  {
   string escaped = value;
   StringReplace(escaped, "\\", "\\\\");
   StringReplace(escaped, "\"", "\\\"");
   StringReplace(escaped, "\r", "\\r");
   StringReplace(escaped, "\n", "\\n");
   StringReplace(escaped, "\t", "\\t");
   return escaped;
  }

string QM_LoggerIsoTimestamp(const datetime t, const bool utc_with_millis)
  {
   string stamp = TimeToString(t, TIME_DATE | TIME_SECONDS);
   StringReplace(stamp, ".", "-");
   StringReplace(stamp, " ", "T");
   if(!utc_with_millis)
      return stamp;

   uint ms = GetTickCount() % 1000;
   return StringFormat("%s.%03uZ", stamp, ms);
  }

string QM_LoggerTimeframeToString(const ENUM_TIMEFRAMES tf)
  {
   string tf_name = EnumToString(tf);
   StringReplace(tf_name, "PERIOD_", "");
   return tf_name;
  }

string QM_LoggerTrim(const string value)
  {
   string out = value;
   StringTrimLeft(out);
   StringTrimRight(out);
   return out;
  }

string QM_LoggerSanitizeSlug(const string slug)
  {
   string clean = QM_LoggerTrim(slug);
   if(StringLen(clean) == 0)
      clean = "unnamed";

   string banned[] = {"\\", "/", ":", "*", "?", "\"", "<", ">", "|", " "};
   for(int i = 0; i < ArraySize(banned); i++)
      StringReplace(clean, banned[i], "-");
   return clean;
  }

string QM_LoggerFileName()
  {
   return StringFormat("QM5_%04d_%s.log", g_qm_logger_ea_id, QM_LoggerSanitizeSlug(g_qm_logger_slug));
  }

string QM_LoggerPrimaryPath()
  {
   string data_path = TerminalInfoString(TERMINAL_DATA_PATH);
   g_qm_logger_primary_dir = data_path + "\\MQL5\\Logs\\QM";
   return g_qm_logger_primary_dir + "\\" + QM_LoggerFileName();
  }

string QM_LoggerFallbackPath()
  {
   return g_qm_logger_fallback_dir + "\\" + QM_LoggerFileName();
  }

bool QM_LoggerEnsurePaths()
  {
   if(StringLen(g_qm_logger_primary_dir) == 0)
      QM_LoggerPrimaryPath();
   FolderCreate(g_qm_logger_primary_dir);
   FolderCreate(g_qm_logger_fallback_dir);
   return true;
  }

bool QM_LoggerInit(const int ea_id,
                   const string slug,
                   const string symbol,
                   const ENUM_TIMEFRAMES tf,
                   const long magic)
  {
   g_qm_logger_ea_id       = ea_id;
   g_qm_logger_slug        = slug;
   g_qm_logger_symbol      = (StringLen(symbol) > 0) ? symbol : _Symbol;
   g_qm_logger_tf          = tf;
   g_qm_logger_magic       = magic;
   g_qm_logger_initialized = true;
   g_qm_logger_active_path = QM_LoggerPrimaryPath();
   QM_LoggerEnsurePaths();
   return true;
  }

void QM_LoggerSetMagic(const long magic)
  {
   g_qm_logger_magic = magic;
  }

string QM_LoggerPath()
  {
   if(StringLen(g_qm_logger_active_path) == 0)
      g_qm_logger_active_path = QM_LoggerPrimaryPath();
   return g_qm_logger_active_path;
  }

bool QM_LoggerWriteLine(const string line)
  {
   if(StringLen(g_qm_logger_active_path) == 0)
      g_qm_logger_active_path = QM_LoggerPrimaryPath();

   int mode = FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE;
   int handle = FileOpen(g_qm_logger_active_path, mode);
   if(handle == INVALID_HANDLE)
     {
      g_qm_logger_active_path = QM_LoggerFallbackPath();
      handle = FileOpen(g_qm_logger_active_path, mode);
      if(handle == INVALID_HANDLE)
        {
         Print("QM_Logger FileOpen failed. primary=", QM_LoggerPrimaryPath(), " fallback=", QM_LoggerFallbackPath(), " err=", GetLastError());
         return false;
        }
     }

   FileSeek(handle, 0, SEEK_END);
   FileWriteString(handle, line + "\r\n");
   FileFlush(handle);
   FileClose(handle);
   return true;
  }

bool QM_LogEvent(const QM_LogLevel level,
                 const string event_name,
                 const string payload_json = "{}")
  {
   if(!g_qm_logger_initialized)
      QM_LoggerInit(0, "unconfigured", _Symbol, (ENUM_TIMEFRAMES)_Period, 0);

   string payload = payload_json;
   if(StringLen(QM_LoggerTrim(payload)) == 0)
      payload = "{}";

   string line = StringFormat(
      "{\"ts_utc\":\"%s\",\"ts_broker\":\"%s\",\"level\":\"%s\",\"ea_id\":%d,\"slug\":\"%s\",\"symbol\":\"%s\",\"tf\":\"%s\",\"magic\":%I64d,\"event\":\"%s\",\"payload\":%s}",
      QM_LoggerIsoTimestamp(TimeGMT(), true),
      QM_LoggerIsoTimestamp(TimeCurrent(), false),
      QM_LoggerLevelToString(level),
      g_qm_logger_ea_id,
      QM_LoggerEscapeJson(g_qm_logger_slug),
      QM_LoggerEscapeJson(g_qm_logger_symbol),
      QM_LoggerEscapeJson(QM_LoggerTimeframeToString(g_qm_logger_tf)),
      g_qm_logger_magic,
      QM_LoggerEscapeJson(event_name),
      payload
   );

   return QM_LoggerWriteLine(line);
  }

bool QM_LogFatal(const string event_name, const string payload_json = "{}")
  {
   return QM_LogEvent(QM_FATAL, event_name, payload_json);
  }

#endif
