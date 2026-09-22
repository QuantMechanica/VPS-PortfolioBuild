#ifndef QM_KILL_SWITCH_MQH
#define QM_KILL_SWITCH_MQH

#include <Trade/Trade.mqh>

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"

// V5 Framework Step 07:
// Three independent kill paths:
// - KS_DAILY_LOSS: day PnL breach versus broker-day starting equity
// - KS_PORTFOLIO_DD: external signal file from monitor
// - KS_MANUAL: manual halt file QM\halt\<ea_id>.halt (MQL5 sandbox:
//   terminal MQL5\Files first, then Common\Files — see the H2 fix note in
//   QM_KillSwitchInit; drive-letter paths are invalid in the file sandbox)

int    g_qm_ks_ea_id                     = 0;
long   g_qm_ks_magic                     = 0;
long   g_qm_ks_additional_magics[];
double g_qm_ks_daily_loss_halt_pct       = 0.0;
double g_qm_ks_portfolio_dd_halt_pct     = 0.0;
double g_qm_ks_per_trade_risk_cap_pct    = 1.0;
string g_qm_ks_manual_halt_file          = "";
string g_qm_ks_portfolio_dd_signal_file  = "";
bool   g_qm_ks_portfolio_signal_explicit = false;
string g_qm_ks_book_tag                  = "";

// Named anchor policy.  FTMO's published Maximum Daily Loss rule uses the
// balance recorded at midnight Prague time.  MAX_BALANCE_EQUITY is the
// QuantMechanica conservative overlay: when floating equity is above balance
// it raises (never lowers) the internal loss floor.  FTMO-mode inputs default
// to that conservative overlay; legacy/non-FTMO EAs retain EQUITY_AT_DAY_START.
enum QM_KillSwitchAnchorMode
  {
   EQUITY_AT_DAY_START       = 0,
   FTMO_BALANCE_AT_MIDNIGHT = 1,
   MAX_BALANCE_EQUITY       = 2
  };

enum QM_FtmoExecutionMode
  {
   QM_FTMO_EXECUTION_OFF      = 0,
   QM_FTMO_EXECUTION_GOVERNED = 1
  };

// One shared FTMO contract surface for every V5 EA.  Fable's governed preset
// turns the mode on and supplies the exact generation/cycle id as book tag;
// leaving the tag blank while the mode is on is an INIT_FAILED condition.
input group "FTMO Kill-Switch Contract"
input QM_FtmoExecutionMode     qm_ftmo_execution_mode = QM_FTMO_EXECUTION_OFF;
input string                   qm_ftmo_book_tag        = "";
input QM_KillSwitchAnchorMode  qm_ftmo_anchor_mode     = MAX_BALANCE_EQUITY;

bool   g_qm_ks_initialized               = false;
bool   g_qm_ks_halted                    = false;
bool   g_qm_ks_unconfigured_logged       = false;
string g_qm_ks_halt_reason               = "";
int    g_qm_ks_halt_day_key              = -1;
int    g_qm_ks_day_key                   = -1;
double g_qm_ks_day_start_equity          = 0.0;

// E2/E3 (2026-07-06 audit): restart persistence + configurable day anchor.
// Defaults preserve historical behavior (broker-midnight boundary, equity
// anchor); the FTMO preset opts into the anchor options at challenge rebuild.
int    g_qm_ks_day_anchor_offset_hours   = 0;
bool   g_qm_ks_anchor_use_max_be         = false;
QM_KillSwitchAnchorMode g_qm_ks_anchor_mode = EQUITY_AT_DAY_START;
bool   g_qm_ks_prague_calendar           = false;
datetime g_qm_ks_effective_prague_time   = 0;
datetime g_qm_ks_effective_server_time   = 0;
string g_qm_ks_state_file                = "";
datetime g_qm_ks_halt_retry_ts           = 0;

CTrade g_qm_ks_trade;

void QM_FrameworkTrackOpenPositionMae();

int QM_KillSwitchDayKey(const datetime broker_time)
{
   MqlDateTime t;
   TimeToStruct(broker_time, t);
   return t.year * 1000 + t.day_of_year;
}

string QM_KillSwitchAnchorModeName(const QM_KillSwitchAnchorMode mode)
{
   switch(mode)
   {
      case EQUITY_AT_DAY_START:       return "EQUITY_AT_DAY_START";
      case FTMO_BALANCE_AT_MIDNIGHT: return "FTMO_BALANCE_AT_MIDNIGHT";
      case MAX_BALANCE_EQUITY:       return "MAX_BALANCE_EQUITY";
   }
   return "UNKNOWN";
}

int QM_KillSwitchAnchorModeFromName(const string name)
{
   if(name == "EQUITY_AT_DAY_START")       return (int)EQUITY_AT_DAY_START;
   if(name == "FTMO_BALANCE_AT_MIDNIGHT") return (int)FTMO_BALANCE_AT_MIDNIGHT;
   if(name == "MAX_BALANCE_EQUITY")       return (int)MAX_BALANCE_EQUITY;
   return -1;
}

string QM_KillSwitchDateString(const datetime value)
{
   MqlDateTime t;
   TimeToStruct(value, t);
   return StringFormat("%04d-%02d-%02d", t.year, t.mon, t.day);
}

string QM_KillSwitchTimeString(const datetime value)
{
   return TimeToString(value, TIME_DATE | TIME_SECONDS);
}

datetime QM_KillSwitchMakeTime(const int year,
                               const int month,
                               const int day,
                               const int hour,
                               const int minute,
                               const int second)
{
   MqlDateTime t;
   t.year = year;
   t.mon = month;
   t.day = day;
   t.hour = hour;
   t.min = minute;
   t.sec = second;
   t.day_of_week = 0;
   t.day_of_year = 0;
   return StructToTime(t);
}

int QM_KillSwitchNthSunday(const int year, const int month, const int nth)
{
   MqlDateTime first;
   TimeToStruct(QM_KillSwitchMakeTime(year, month, 1, 0, 0, 0), first);
   return 1 + ((7 - first.day_of_week) % 7) + 7 * (nth - 1);
}

int QM_KillSwitchDaysInMonth(const int year, const int month)
{
   if(month == 2)
   {
      const bool leap = ((year % 4) == 0 && (year % 100) != 0) || ((year % 400) == 0);
      return leap ? 29 : 28;
   }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
}

int QM_KillSwitchLastSunday(const int year, const int month)
{
   const int last_day = QM_KillSwitchDaysInMonth(year, month);
   MqlDateTime last;
   TimeToStruct(QM_KillSwitchMakeTime(year, month, last_day, 0, 0, 0), last);
   return last_day - last.day_of_week;
}

// Darwinex/FTMO MT5 server clocks follow the New-York DST calendar while
// displaying UTC+2 in US standard time and UTC+3 in US daylight time.  These
// helpers encode the statutory transition instants, not a hard-coded -1 shift.
bool QM_KillSwitchServerDstAtUtc(const datetime utc_time)
{
   MqlDateTime t;
   TimeToStruct(utc_time, t);
   const int start_day = QM_KillSwitchNthSunday(t.year, 3, 2);
   const int end_day = QM_KillSwitchNthSunday(t.year, 11, 1);
   const datetime start_utc = QM_KillSwitchMakeTime(t.year, 3, start_day, 7, 0, 0);
   const datetime end_utc = QM_KillSwitchMakeTime(t.year, 11, end_day, 6, 0, 0);
   return utc_time >= start_utc && utc_time < end_utc;
}

bool QM_KillSwitchPragueDstAtUtc(const datetime utc_time)
{
   MqlDateTime t;
   TimeToStruct(utc_time, t);
   const int start_day = QM_KillSwitchLastSunday(t.year, 3);
   const int end_day = QM_KillSwitchLastSunday(t.year, 10);
   const datetime start_utc = QM_KillSwitchMakeTime(t.year, 3, start_day, 1, 0, 0);
   const datetime end_utc = QM_KillSwitchMakeTime(t.year, 10, end_day, 1, 0, 0);
   return utc_time >= start_utc && utc_time < end_utc;
}

int QM_KillSwitchServerUtcOffsetAtUtc(const datetime utc_time)
{
   return QM_KillSwitchServerDstAtUtc(utc_time) ? 3 : 2;
}

int QM_KillSwitchPragueUtcOffsetAtUtc(const datetime utc_time)
{
   return QM_KillSwitchPragueDstAtUtc(utc_time) ? 2 : 1;
}

// Infer the UTC offset from a server-clock calendar value.  The repeated hour
// at the November rollback is intrinsically ambiguous without UTC metadata;
// the live wall-clock path below starts from TimeGMT and is exact.  This pure
// server-time helper is deterministic at every Prague day boundary (including
// both US/EU divergence windows), which is the kill-switch decision surface.
int QM_KillSwitchServerUtcOffsetFromServerTime(const datetime server_time)
{
   MqlDateTime t;
   TimeToStruct(server_time, t);
   const int start_day = QM_KillSwitchNthSunday(t.year, 3, 2);
   const int end_day = QM_KillSwitchNthSunday(t.year, 11, 1);
   if(t.mon < 3 || t.mon > 11)
      return 2;
   if(t.mon > 3 && t.mon < 11)
      return 3;
   if(t.mon == 3)
   {
      if(t.day > start_day || (t.day == start_day && t.hour >= 10))
         return 3;
      return 2;
   }
   if(t.day < end_day || (t.day == end_day && t.hour < 9))
      return 3;
   return 2;
}

// Deterministic Europe/Prague translation from an MT5 server timestamp.  The
// returned offset is -1 in both stable seasons and -2 only while US and EU DST
// status diverges.
bool QM_KillSwitchPragueFromServerTime(const datetime server_time,
                                       datetime &prague_time,
                                       int &offset_hours)
{
   if(server_time <= 0)
      return false;
   const int server_utc_offset = QM_KillSwitchServerUtcOffsetFromServerTime(server_time);
   const datetime utc_time = server_time - server_utc_offset * 3600;
   const int prague_utc_offset = QM_KillSwitchPragueUtcOffsetAtUtc(utc_time);
   offset_hours = prague_utc_offset - server_utc_offset;
   prague_time = server_time + offset_hours * 3600;
   return true;
}

// Advancing live clock for weekend/no-tick protection.  TimeGMT is calculated
// from the machine wall clock and does not freeze at the last received quote.
// Tester runs retain simulated TimeCurrent semantics for determinism.
bool QM_KillSwitchPragueClock(datetime &server_time,
                              datetime &prague_time,
                              int &offset_hours)
{
   if(MQLInfoInteger(MQL_TESTER) != 0)
   {
      server_time = TimeCurrent();
      return QM_KillSwitchPragueFromServerTime(server_time, prague_time, offset_hours);
   }

   const datetime utc_time = TimeGMT();
   if(utc_time <= 0)
      return false;
   const int server_utc_offset = QM_KillSwitchServerUtcOffsetAtUtc(utc_time);
   const int prague_utc_offset = QM_KillSwitchPragueUtcOffsetAtUtc(utc_time);
   server_time = utc_time + server_utc_offset * 3600;
   prague_time = utc_time + prague_utc_offset * 3600;
   offset_hours = prague_utc_offset - server_utc_offset;
   return true;
}

string QM_KillSwitchTrim(const string value)
{
   string out = value;
   StringTrimLeft(out);
   StringTrimRight(out);
   return out;
}

bool QM_KillSwitchFileExists(const string path)
{
   if(StringLen(path) == 0)
      return false;

   if(FileIsExist(path))
      return true;

   if(FileIsExist(path, FILE_COMMON))
      return true;

   return false;
}

bool QM_KillSwitchReadFirstLine(const string path, string &line)
{
   line = "";
   if(StringLen(path) == 0)
      return false;

   int flags = FILE_READ | FILE_TXT | FILE_ANSI;
   int handle = FileOpen(path, flags);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(path, flags | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;

   if(!FileIsEnding(handle))
      line = QM_KillSwitchTrim(FileReadString(handle));
   FileClose(handle);
   return true;
}

bool QM_KillSwitchTryParseDouble(string text, double &value)
{
   text = QM_KillSwitchTrim(text);
   if(StringLen(text) == 0)
      return false;

   const int eq = StringFind(text, "=");
   if(eq >= 0)
      text = QM_KillSwitchTrim(StringSubstr(text, eq + 1));

   if(StringLen(text) == 0)
      return false;

   value = StringToDouble(text);
   if(!MathIsValidNumber(value))
      return false;

   if(value == 0.0 && text != "0" && text != "0.0" && text != "0.00")
      return false;

   return true;
}

int QM_KillSwitchCurrentDayKey()
{
   if(g_qm_ks_prague_calendar)
   {
      datetime server_time = 0;
      datetime prague_time = 0;
      int offset_hours = 0;
      if(!QM_KillSwitchPragueClock(server_time, prague_time, offset_hours))
         return g_qm_ks_day_key;
      g_qm_ks_effective_server_time = server_time;
      g_qm_ks_effective_prague_time = prague_time;
      g_qm_ks_day_anchor_offset_hours = offset_hours;
      return QM_KillSwitchDayKey(prague_time);
   }

   g_qm_ks_effective_server_time = TimeCurrent();
   g_qm_ks_effective_prague_time =
      g_qm_ks_effective_server_time + g_qm_ks_day_anchor_offset_hours * 3600;
   return QM_KillSwitchDayKey(g_qm_ks_effective_prague_time);
}

double QM_KillSwitchAnchorEquity()
{
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_qm_ks_anchor_mode == FTMO_BALANCE_AT_MIDNIGHT)
      return balance;
   if(g_qm_ks_anchor_mode == MAX_BALANCE_EQUITY)
      return MathMax(equity, balance);
   return equity;
}

// E2 fix (2026-07-06 audit): KS_DAILY_LOSS halt + day anchor lived only in
// globals — any mid-day reload (recompile, terminal restart, watchdog reboot)
// erased an active halt AND re-anchored the day at the already-depleted
// equity, silently granting a second full daily-loss budget the same day.
// State persists terminal-locally (each terminal is its own risk domain) and
// is restored on init only when it belongs to the SAME halt-day. Tester runs
// never persist or restore (evidence determinism). KS_MANUAL/KS_PORTFOLIO_DD
// self-restore via their signal files; this file is what saves KS_DAILY_LOSS.
void QM_KillSwitchSaveState()
{
   if(MQLInfoInteger(MQL_TESTER) != 0 || StringLen(g_qm_ks_state_file) == 0)
      return;
   int fh = FileOpen(g_qm_ks_state_file, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE)
   {
      QM_LogEvent(QM_WARN, "KS_STATE_SAVE_FAILED",
                  StringFormat("{\"path\":\"%s\",\"error\":%d}",
                               QM_LoggerEscapeJson(g_qm_ks_state_file), GetLastError()));
      return;
   }
   FileWriteString(fh, StringFormat("day_key=%d\n", g_qm_ks_day_key));
   FileWriteString(fh, StringFormat("day_start_equity=%.2f\n", g_qm_ks_day_start_equity));
   FileWriteString(fh, StringFormat("halted=%d\n", g_qm_ks_halted ? 1 : 0));
   FileWriteString(fh, StringFormat("halt_reason=%s\n", g_qm_ks_halt_reason));
   FileWriteString(fh, StringFormat("halt_day_key=%d\n", g_qm_ks_halt_day_key));
   FileWriteString(fh, StringFormat("magic=%I64d\n", g_qm_ks_magic));
   // Review 83be4dd3 (E3 round-trip): state is only valid under the SAME
   // anchor configuration — a state saved pre-SetDayAnchor must not override
   // the max(balance,equity)/offset baseline computed after it.
    FileWriteString(fh, StringFormat("anchor_offset=%d\n", g_qm_ks_day_anchor_offset_hours));
    FileWriteString(fh, StringFormat("anchor_max_be=%d\n", g_qm_ks_anchor_use_max_be ? 1 : 0));
    FileWriteString(fh, StringFormat("anchor_mode=%s\n", QM_KillSwitchAnchorModeName(g_qm_ks_anchor_mode)));
    FileWriteString(fh, StringFormat("book_tag=%s\n", g_qm_ks_book_tag));
    FileWriteString(fh, StringFormat("prague_calendar=%d\n", g_qm_ks_prague_calendar ? 1 : 0));
    FileWriteString(fh, StringFormat("prague_date=%s\n", QM_KillSwitchDateString(g_qm_ks_effective_prague_time)));
    FileClose(fh);
}

// Restore outcome (review 5f860f79 item 1): the caller must know WHY nothing
// was applied. A valid same-magic state saved under a DIFFERENT anchor
// configuration is NOT stale — it belongs to the documented post-init
// QM_KillSwitchSetDayAnchor consumer and must never be overwritten by init.
#define QM_KS_RESTORE_APPLIED          1
#define QM_KS_RESTORE_NONE             0
#define QM_KS_RESTORE_FOREIGN_CONFIG (-1)

int QM_KillSwitchRestoreState()
{
   if(MQLInfoInteger(MQL_TESTER) != 0 || StringLen(g_qm_ks_state_file) == 0)
      return QM_KS_RESTORE_NONE;
   int fh = FileOpen(g_qm_ks_state_file, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(fh == INVALID_HANDLE)
      return QM_KS_RESTORE_NONE; // first run on this terminal — nothing to restore

   int saved_day_key = -1, saved_halted = 0, saved_halt_day_key = -1;
    int saved_anchor_offset = 0, saved_anchor_max_be = 0;
    int saved_anchor_mode = -1, saved_prague_calendar = -1;
    double saved_anchor = 0.0;
    long saved_magic = 0;
    string saved_reason = "", saved_book_tag = "";
   while(!FileIsEnding(fh))
   {
      const string line = QM_KillSwitchTrim(FileReadString(fh));
      const int eq = StringFind(line, "=");
      if(eq <= 0)
         continue;
      const string key = StringSubstr(line, 0, eq);
      const string val = StringSubstr(line, eq + 1);
      if(key == "day_key")               saved_day_key = (int)StringToInteger(val);
      else if(key == "day_start_equity") saved_anchor = StringToDouble(val);
      else if(key == "halted")           saved_halted = (int)StringToInteger(val);
      else if(key == "halt_reason")      saved_reason = val;
      else if(key == "halt_day_key")     saved_halt_day_key = (int)StringToInteger(val);
      else if(key == "magic")            saved_magic = StringToInteger(val);
       else if(key == "anchor_offset")    saved_anchor_offset = (int)StringToInteger(val);
       else if(key == "anchor_max_be")    saved_anchor_max_be = (int)StringToInteger(val);
       else if(key == "anchor_mode")      saved_anchor_mode = QM_KillSwitchAnchorModeFromName(val);
       else if(key == "book_tag")         saved_book_tag = val;
       else if(key == "prague_calendar")  saved_prague_calendar = (int)StringToInteger(val);
    }
    FileClose(fh);

    // Backward-compatible inference for pre-named-mode state.  A governed FTMO
    // file still cannot be mistaken for legacy because its non-empty book tag
    // and Prague-calendar flag are part of the exact configuration match.
    if(saved_anchor_mode < 0)
       saved_anchor_mode = saved_anchor_max_be == 1
          ? (int)MAX_BALANCE_EQUITY : (int)EQUITY_AT_DAY_START;
    if(saved_prague_calendar < 0)
       saved_prague_calendar = 0;

   if(saved_magic != g_qm_ks_magic || saved_anchor <= 0.0)
   {
      QM_LogEvent(QM_INFO, "KS_STATE_STALE_IGNORED",
                  StringFormat("{\"saved_day_key\":%d,\"current_day_key\":%d,\"saved_magic\":%I64d,\"saved_anchor_offset\":%d,\"saved_anchor_max_be\":%d}",
                               saved_day_key, g_qm_ks_day_key, saved_magic,
                               saved_anchor_offset, saved_anchor_max_be));
      return QM_KS_RESTORE_NONE;
   }
   // Review 5f860f79 item-1 fix: config mismatch is checked BEFORE the day-key
   // comparison — day_key itself is computed under the anchor offset, so a
   // foreign-config file cannot even be judged stale under our boundary. It is
   // preserved for the setter, which re-restores after adopting the config.
    if(saved_anchor_offset != g_qm_ks_day_anchor_offset_hours ||
       saved_anchor_max_be != (g_qm_ks_anchor_use_max_be ? 1 : 0) ||
       saved_anchor_mode != (int)g_qm_ks_anchor_mode ||
       saved_book_tag != g_qm_ks_book_tag ||
       saved_prague_calendar != (g_qm_ks_prague_calendar ? 1 : 0))
    {
       QM_LogEvent(QM_INFO, "KS_STATE_FOREIGN_CONFIG_PRESERVED",
                   StringFormat("{\"saved_anchor_offset\":%d,\"current_anchor_offset\":%d,\"saved_anchor_max_be\":%d,\"current_anchor_max_be\":%d,\"saved_anchor_mode\":\"%s\",\"current_anchor_mode\":\"%s\",\"saved_book_tag\":\"%s\",\"current_book_tag\":\"%s\",\"saved_prague_calendar\":%d,\"current_prague_calendar\":%d}",
                                saved_anchor_offset, g_qm_ks_day_anchor_offset_hours,
                                saved_anchor_max_be, g_qm_ks_anchor_use_max_be ? 1 : 0,
                                QM_KillSwitchAnchorModeName((QM_KillSwitchAnchorMode)saved_anchor_mode),
                                QM_KillSwitchAnchorModeName(g_qm_ks_anchor_mode),
                                QM_LoggerEscapeJson(saved_book_tag),
                                QM_LoggerEscapeJson(g_qm_ks_book_tag),
                                saved_prague_calendar, g_qm_ks_prague_calendar ? 1 : 0));
       return QM_KS_RESTORE_FOREIGN_CONFIG;
    }
   if(saved_day_key != g_qm_ks_day_key)
   {
      QM_LogEvent(QM_INFO, "KS_STATE_STALE_IGNORED",
                  StringFormat("{\"saved_day_key\":%d,\"current_day_key\":%d,\"saved_magic\":%I64d,\"saved_anchor_offset\":%d,\"saved_anchor_max_be\":%d}",
                               saved_day_key, g_qm_ks_day_key, saved_magic,
                               saved_anchor_offset, saved_anchor_max_be));
      return QM_KS_RESTORE_NONE;
   }

   // Review 83be4dd3 M-3: only the fileless KS_DAILY_LOSS halt is restored
   // from state — KS_MANUAL/KS_PORTFOLIO_DD self-restore via their signal
   // files, and restoring them from stale state would re-halt an EA whose
   // halt file the operator deliberately deleted while it was offline.
   g_qm_ks_day_start_equity = saved_anchor;
   if(saved_halted == 1 && saved_halt_day_key == g_qm_ks_day_key &&
      saved_reason == KS_DAILY_LOSS)
   {
      g_qm_ks_halted = true;
      g_qm_ks_halt_reason = saved_reason;
      g_qm_ks_halt_day_key = saved_halt_day_key;
      QM_LogEvent(QM_WARN, "KS_STATE_RESTORED_HALT",
                  StringFormat("{\"halt_reason\":\"%s\",\"day_start_equity\":%.2f}",
                               QM_LoggerEscapeJson(saved_reason), saved_anchor));
   }
   else
      QM_LogEvent(QM_INFO, "KS_STATE_RESTORED_ANCHOR",
                  StringFormat("{\"day_start_equity\":%.2f}", saved_anchor));
   return QM_KS_RESTORE_APPLIED;
}

void QM_KillSwitchRefreshBrokerDay()
{
   const int old_day_key = g_qm_ks_day_key;
   const int old_offset_hours = g_qm_ks_day_anchor_offset_hours;
   const int current_day_key = QM_KillSwitchCurrentDayKey();
   if(g_qm_ks_day_key == current_day_key)
   {
      // A US/EU DST transition can change the server->Prague offset without
      // changing the Prague calendar date.  Persist that configuration change
      // so the pulse never reads a stale -1/-2 offset from an otherwise-current
      // state file.
      if(old_offset_hours != g_qm_ks_day_anchor_offset_hours)
         QM_KillSwitchSaveState();
      return;
   }

   g_qm_ks_day_key = current_day_key;
   g_qm_ks_day_start_equity = QM_KillSwitchAnchorEquity();

   QM_LogEvent(QM_INFO,
               "KS_DAY_ROLLOVER",
               StringFormat("{\"old_day_key\":%d,\"new_day_key\":%d,\"server_time\":\"%s\",\"effective_prague_time\":\"%s\",\"offset_hours\":%d,\"anchor_mode\":\"%s\",\"selected_anchor\":%.2f,\"book_tag\":\"%s\"}",
                            old_day_key,
                            current_day_key,
                            QM_LoggerEscapeJson(QM_KillSwitchTimeString(g_qm_ks_effective_server_time)),
                            QM_LoggerEscapeJson(QM_KillSwitchTimeString(g_qm_ks_effective_prague_time)),
                            g_qm_ks_day_anchor_offset_hours,
                            QM_KillSwitchAnchorModeName(g_qm_ks_anchor_mode),
                            g_qm_ks_day_start_equity,
                            QM_LoggerEscapeJson(g_qm_ks_book_tag)));

   if(g_qm_ks_halted && g_qm_ks_halt_day_key != current_day_key)
   {
      g_qm_ks_halted = false;
      g_qm_ks_halt_reason = "";
      QM_LogEvent(QM_INFO,
                  "KILL_SWITCH_RESET_NEXT_BROKER_DAY",
                  StringFormat("{\"day_key\":%d,\"equity_start\":%.2f}", current_day_key, g_qm_ks_day_start_equity));
   }

   QM_KillSwitchSaveState();
}

int QM_KillSwitchClosePositionsByMagic(const long magic)
{
   int closed = 0;
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(magic > 0 && pos_magic != magic)
         continue;

      // F3/F14 (2026-07-06 audit): resolve filling per symbol — the single most
      // safety-critical close path must not die on TRADE_RETCODE_INVALID_FILL.
      g_qm_ks_trade.SetTypeFillingBySymbol(PositionGetString(POSITION_SYMBOL));
      if(g_qm_ks_trade.PositionClose(ticket))
      {
         ++closed;
         continue;
      }

      QM_LogEvent(QM_ERROR,
                  "KILL_SWITCH_CLOSE_FAILED",
                  StringFormat("{\"ticket\":%I64u,\"retcode\":%u,\"reason\":\"%s\"}",
                               ticket,
                               g_qm_ks_trade.ResultRetcode(),
                               QM_LoggerEscapeJson(g_qm_ks_trade.ResultRetcodeDescription())));
   }

   return closed;
}

// Review 27c36fb7 (2026-07-06): the trip flatten previously ignored PENDING
// orders — a resting limit/stop with the EA's magic could fill AFTER the halt,
// leaving an open position no EA logic would ever manage (OnTick is gated on
// the halt). Pendings are now deleted at trip and during halted re-sweeps.
int QM_KillSwitchDeletePendingsByMagic(const long magic)
{
   int deleted = 0;
   const int total = OrdersTotal();
   for(int i = total - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(magic > 0 && OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(g_qm_ks_trade.OrderDelete(ticket))
      {
         ++deleted;
         continue;
      }
      QM_LogEvent(QM_ERROR,
                  "KILL_SWITCH_PENDING_DELETE_FAILED",
                  StringFormat("{\"ticket\":%I64u,\"retcode\":%u}",
                               ticket, g_qm_ks_trade.ResultRetcode()));
   }
   return deleted;
}

bool QM_KillSwitchOwnExposureExists(const long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(magic <= 0 || PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
   }
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(magic <= 0 || OrderGetInteger(ORDER_MAGIC) == magic)
         return true;
   }
   return false;
}

bool QM_KillSwitchOwnsMagic(const long magic)
{
   if(!g_qm_ks_initialized || magic <= 0)
      return false;
   if(magic == g_qm_ks_magic)
      return true;

   const int count = ArraySize(g_qm_ks_additional_magics);
   for(int i = 0; i < count; ++i)
      if(g_qm_ks_additional_magics[i] == magic)
         return true;
   return false;
}

// Opt-in symbol-master ownership. Legacy EAs never register an additional
// magic, so their single-pass flatten path remains unchanged.
bool QM_KillSwitchRegisterMagic(const long magic)
{
   if(!g_qm_ks_initialized || magic <= 0)
      return false;
   if(QM_KillSwitchOwnsMagic(magic))
      return true;

   const int count = ArraySize(g_qm_ks_additional_magics);
   if(ArrayResize(g_qm_ks_additional_magics, count + 1) != count + 1)
      return false;
   g_qm_ks_additional_magics[count] = magic;
   return true;
}

int QM_KillSwitchCloseOwnedPositions()
{
   int closed = QM_KillSwitchClosePositionsByMagic(g_qm_ks_magic);
   const int count = ArraySize(g_qm_ks_additional_magics);
   for(int i = 0; i < count; ++i)
      closed += QM_KillSwitchClosePositionsByMagic(g_qm_ks_additional_magics[i]);
   return closed;
}

int QM_KillSwitchDeleteOwnedPendings()
{
   int deleted = QM_KillSwitchDeletePendingsByMagic(g_qm_ks_magic);
   const int count = ArraySize(g_qm_ks_additional_magics);
   for(int i = 0; i < count; ++i)
      deleted += QM_KillSwitchDeletePendingsByMagic(g_qm_ks_additional_magics[i]);
   return deleted;
}

bool QM_KillSwitchOwnedExposureExists()
{
   if(QM_KillSwitchOwnExposureExists(g_qm_ks_magic))
      return true;
   const int count = ArraySize(g_qm_ks_additional_magics);
   for(int i = 0; i < count; ++i)
      if(QM_KillSwitchOwnExposureExists(g_qm_ks_additional_magics[i]))
         return true;
   return false;
}

bool QM_KillSwitchPortfolioSignalTriggered(double &signal_value, bool &value_present)
{
   signal_value = 0.0;
   value_present = false;

   if(StringLen(g_qm_ks_portfolio_dd_signal_file) == 0)
      return false;
   if(!QM_KillSwitchFileExists(g_qm_ks_portfolio_dd_signal_file))
      return false;

   string first_line = "";
   if(QM_KillSwitchReadFirstLine(g_qm_ks_portfolio_dd_signal_file, first_line))
      value_present = QM_KillSwitchTryParseDouble(first_line, signal_value);

   if(g_qm_ks_portfolio_dd_halt_pct <= 0.0)
      return true;

   if(value_present)
      return (signal_value >= g_qm_ks_portfolio_dd_halt_pct);

   // If a signal file exists but value cannot be parsed, fail-safe to halt.
   return true;
}

void QM_KillSwitchTrip(const string reason, const string details_json)
{
   if(g_qm_ks_halted)
      return;

   g_qm_ks_halted = true;
   g_qm_ks_halt_reason = reason;
   g_qm_ks_halt_day_key = g_qm_ks_day_key;

   // Persist BEFORE the close sweep: a crash mid-flatten must not lose the halt.
   QM_KillSwitchSaveState();

   const int closed = QM_KillSwitchCloseOwnedPositions();
   const int pendings_deleted = QM_KillSwitchDeleteOwnedPendings();
   QM_LogFatal("KILL_SWITCH_TRIGGERED",
               StringFormat("{\"reason\":\"%s\",\"ea_id\":%d,\"magic\":%I64d,\"closed_positions\":%d,\"pendings_deleted\":%d,\"details\":%s}",
                            QM_LoggerEscapeJson(reason),
                            g_qm_ks_ea_id,
                            g_qm_ks_magic,
                            closed,
                            pendings_deleted,
                            details_json));
}

bool QM_KillSwitchInit(const int ea_id,
                       const long magic,
                       const double daily_loss_halt_pct,
                       const double portfolio_dd_halt_pct = 0.0,
                       const double per_trade_risk_cap_pct = 1.0,
                       const string portfolio_dd_signal_file = "",
                       const string manual_halt_file = "")
{
   g_qm_ks_ea_id = ea_id;
   g_qm_ks_magic = magic;
   ArrayResize(g_qm_ks_additional_magics, 0);
   g_qm_ks_daily_loss_halt_pct = MathMax(0.0, daily_loss_halt_pct);
   g_qm_ks_portfolio_dd_halt_pct = MathMax(0.0, portfolio_dd_halt_pct);
   g_qm_ks_per_trade_risk_cap_pct = MathMax(0.0, per_trade_risk_cap_pct);
   g_qm_ks_portfolio_dd_signal_file = QM_KillSwitchTrim(portfolio_dd_signal_file);
   g_qm_ks_manual_halt_file = QM_KillSwitchTrim(manual_halt_file);
   g_qm_ks_portfolio_signal_explicit = (StringLen(g_qm_ks_portfolio_dd_signal_file) > 0);
   // H2 fix (2026-07-05): the historical defaults were absolute D:\QM\data\halt\
   // paths, which the MQL5 file sandbox can never resolve (drive-letter paths are
   // invalid for FileIsExist/FileOpen) — the halt-file channel was silently dead
   // on live terminals since introduction (D:\QM\data\halt stayed empty; no
   // KS_MANUAL/KS_PORTFOLIO_DD ever fired). Defaults are now sandbox-relative:
   // terminal-local MQL5\Files\QM\halt\ is checked first (terminal-scoped halt),
   // then Common\Files\QM\halt\ via FILE_COMMON (machine-wide halt).
   if(StringLen(g_qm_ks_manual_halt_file) == 0 && ea_id > 0)
      g_qm_ks_manual_halt_file = StringFormat("QM\\halt\\%d.halt", ea_id);
   if(StringLen(g_qm_ks_portfolio_dd_signal_file) == 0 && ea_id > 0)
      g_qm_ks_portfolio_dd_signal_file = "QM\\halt\\portfolio_dd.signal";
   // Review 83be4dd3 M-2: the magic scopes the file — two charts of the same
   // EA on different symbols (different slots) must not clobber each other.
   g_qm_ks_state_file = (ea_id > 0)
      ? StringFormat("QM\\halt\\ks_state_%d_%I64d.state", ea_id, magic)
      : "";

   g_qm_ks_halted = false;
   g_qm_ks_halt_reason = "";
   g_qm_ks_halt_day_key = -1;
   g_qm_ks_day_key = -1;
   g_qm_ks_day_start_equity = 0.0;
   g_qm_ks_day_anchor_offset_hours = 0;
   g_qm_ks_anchor_use_max_be = false;
   g_qm_ks_anchor_mode = EQUITY_AT_DAY_START;
   g_qm_ks_prague_calendar = false;
   g_qm_ks_effective_prague_time = 0;
   g_qm_ks_effective_server_time = 0;
   g_qm_ks_book_tag = "";
   g_qm_ks_unconfigured_logged = false;
   g_qm_ks_initialized = true;
   // E2 ordering (adversarial review 27c36fb7, 2026-07-06): RestoreState MUST
   // read the state file BEFORE anything writes it. RefreshBrokerDay always
   // sees a day change on init (day_key==-1) and its SaveState would truncate
   // the file with halted=0 + a fresh anchor — restore would then read back
   // its own clobbering. So: compute the fresh anchor WITHOUT persisting,
   // let a same-day persisted state override it, then persist the result.
   g_qm_ks_day_key = QM_KillSwitchCurrentDayKey();
   g_qm_ks_day_start_equity = QM_KillSwitchAnchorEquity();
   // Review 5f860f79 item-1 fix: init must NOT persist over a valid same-magic
   // state saved under a different anchor configuration — that file belongs to
   // the documented post-init QM_KillSwitchSetDayAnchor call, which re-restores
   // it after adopting the configuration. Saving here truncated it with the
   // default-config fresh anchor and lost the daily halt + depletion baseline.
   if(QM_KillSwitchRestoreState() != QM_KS_RESTORE_FOREIGN_CONFIG)
      QM_KillSwitchSaveState();

   QM_LogEvent(QM_INFO,
               "KILL_SWITCH_INIT",
               StringFormat("{\"ea_id\":%d,\"magic\":%I64d,\"daily_loss_halt_pct\":%.4f,\"portfolio_dd_halt_pct\":%.4f,\"per_trade_risk_cap_pct\":%.4f,\"manual_halt_file\":\"%s\",\"portfolio_dd_signal_file\":\"%s\"}",
                            g_qm_ks_ea_id,
                            g_qm_ks_magic,
                            g_qm_ks_daily_loss_halt_pct,
                            g_qm_ks_portfolio_dd_halt_pct,
                            g_qm_ks_per_trade_risk_cap_pct,
                            QM_LoggerEscapeJson(g_qm_ks_manual_halt_file),
                            QM_LoggerEscapeJson(g_qm_ks_portfolio_dd_signal_file)));
   return true;
}

bool QM_KillSwitchBookTagIsSafe(const string tag)
{
   const int length = StringLen(tag);
   if(length < 1 || length > 96)
      return false;
   for(int i = 0; i < length; ++i)
   {
      const ushort ch = StringGetCharacter(tag, i);
      const bool alpha = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z');
      const bool digit = ch >= '0' && ch <= '9';
      if(!alpha && !digit && ch != '_' && ch != '-')
         return false;
   }
   return true;
}

// H2 book-scoping (2026-07-05): route the portfolio-DD signal per book so a
// halt of one live book (e.g. FTMO challenge) can never flatten another (e.g.
// the DXZ T_Live book). Call AFTER QM_KillSwitchInit — same rollout pattern as
// QM_FrameworkSetRiskCapPct: book EAs gain an input (qm_ks_book_tag) at their
// next rebuild; all other EAs keep the un-scoped default. No-op when init
// received an explicit signal path. Runtime proof: KS_BOOK_TAG_SET event.
bool QM_KillSwitchSetBookTag(const string tag)
{
   string t = QM_KillSwitchTrim(tag);
   if(!g_qm_ks_initialized || !QM_KillSwitchBookTagIsSafe(t))
      return false;
   g_qm_ks_book_tag = t;
   if(!g_qm_ks_portfolio_signal_explicit)
      g_qm_ks_portfolio_dd_signal_file =
         StringFormat("QM\\halt\\book_%s\\portfolio_dd.signal", t);
   QM_LogEvent(QM_INFO,
               "KS_BOOK_TAG_SET",
               StringFormat("{\"book_tag\":\"%s\",\"portfolio_dd_signal_file\":\"%s\"}",
                            QM_LoggerEscapeJson(t),
                            QM_LoggerEscapeJson(g_qm_ks_portfolio_dd_signal_file)));
   return true;
}

// Legacy/manual day-anchor setter retained for non-FTMO consumers.  Governed
// FTMO builds use QM_KillSwitchSetPragueDayAnchor below so the offset follows
// the US/EU calendar automatically instead of being an operator-supplied -1.
bool QM_KillSwitchSetDayAnchor(const int offset_hours, const bool use_max_balance_equity)
{
   if(!g_qm_ks_initialized || offset_hours < -12 || offset_hours > 12)
      return false;
   g_qm_ks_prague_calendar = false;
   g_qm_ks_day_anchor_offset_hours = offset_hours;
   g_qm_ks_anchor_use_max_be = use_max_balance_equity;
   g_qm_ks_anchor_mode = use_max_balance_equity
      ? MAX_BALANCE_EQUITY : EQUITY_AT_DAY_START;
   g_qm_ks_day_key = QM_KillSwitchCurrentDayKey();
   g_qm_ks_day_start_equity = QM_KillSwitchAnchorEquity();
   // Keep an active halt pinned to the re-based day so it reliably survives
   // until the next boundary instead of expiring on a key mismatch.
   if(g_qm_ks_halted)
      g_qm_ks_halt_day_key = g_qm_ks_day_key;
   QM_KillSwitchRestoreState();
   QM_KillSwitchSaveState();
   QM_LogEvent(QM_INFO, "KS_DAY_ANCHOR_SET",
               StringFormat("{\"offset_hours\":%d,\"anchor_mode\":\"%s\",\"use_max_balance_equity\":%s,\"day_key\":%d,\"day_start_equity\":%.2f,\"prague_calendar\":false}",
                             offset_hours,
                             QM_KillSwitchAnchorModeName(g_qm_ks_anchor_mode),
                             use_max_balance_equity ? "true" : "false",
                             g_qm_ks_day_key,
                             g_qm_ks_day_start_equity));
   return true;
}

// Governed FTMO anchor setter.  The exact FTMO rule is
// FTMO_BALANCE_AT_MIDNIGHT; MAX_BALANCE_EQUITY is the default conservative QM
// overlay.  Both use an advancing Prague wall clock and a dynamically derived
// -1/-2 server offset.  An active daily halt is never cleared by reconfiguration.
bool QM_KillSwitchSetPragueDayAnchor(const QM_KillSwitchAnchorMode mode)
{
   if(!g_qm_ks_initialized ||
      (mode != FTMO_BALANCE_AT_MIDNIGHT && mode != MAX_BALANCE_EQUITY))
      return false;

   datetime server_time = 0;
   datetime prague_time = 0;
   int offset_hours = 0;
   if(!QM_KillSwitchPragueClock(server_time, prague_time, offset_hours))
      return false;

   g_qm_ks_prague_calendar = true;
   g_qm_ks_effective_server_time = server_time;
   g_qm_ks_effective_prague_time = prague_time;
   g_qm_ks_day_anchor_offset_hours = offset_hours;
   g_qm_ks_anchor_mode = mode;
   g_qm_ks_anchor_use_max_be = (mode == MAX_BALANCE_EQUITY);
   g_qm_ks_day_key = QM_KillSwitchDayKey(prague_time);
   g_qm_ks_day_start_equity = QM_KillSwitchAnchorEquity();
   if(g_qm_ks_halted)
      g_qm_ks_halt_day_key = g_qm_ks_day_key;
   QM_KillSwitchRestoreState();
   QM_KillSwitchSaveState();
   QM_LogEvent(QM_INFO, "KS_DAY_ANCHOR_SET",
               StringFormat("{\"offset_hours\":%d,\"anchor_mode\":\"%s\",\"day_key\":%d,\"day_start_equity\":%.2f,\"server_time\":\"%s\",\"effective_prague_time\":\"%s\",\"prague_calendar\":true}",
                            offset_hours,
                            QM_KillSwitchAnchorModeName(mode),
                            g_qm_ks_day_key,
                            g_qm_ks_day_start_equity,
                            QM_LoggerEscapeJson(QM_KillSwitchTimeString(server_time)),
                            QM_LoggerEscapeJson(QM_KillSwitchTimeString(prague_time))));
   return true;
}

bool QM_KillSwitchFtmoContractEnabled()
{
   return qm_ftmo_execution_mode == QM_FTMO_EXECUTION_GOVERNED;
}

// The one governed FTMO initializer called centrally by QM_FrameworkInitCore.
// Both setters must succeed before the framework is allowed to emit INIT/return
// success; there is no per-sleeve copy of this contract.
bool QM_KillSwitchApplyFtmoContract()
{
   if(qm_ftmo_execution_mode == QM_FTMO_EXECUTION_OFF)
      return true;
   if(qm_ftmo_execution_mode != QM_FTMO_EXECUTION_GOVERNED)
      return false;

   const string tag = QM_KillSwitchTrim(qm_ftmo_book_tag);
   if(!QM_KillSwitchBookTagIsSafe(tag))
      return false;
   if(qm_ftmo_anchor_mode != FTMO_BALANCE_AT_MIDNIGHT &&
      qm_ftmo_anchor_mode != MAX_BALANCE_EQUITY)
      return false;
   if(!QM_KillSwitchSetBookTag(tag))
      return false;
   if(!QM_KillSwitchSetPragueDayAnchor(qm_ftmo_anchor_mode))
      return false;
   return true;
}

bool QM_KillSwitchIsHalted()
{
   return g_qm_ks_halted;
}

string QM_KillSwitchHaltReason()
{
   return g_qm_ks_halt_reason;
}

double QM_KillSwitchPerTradeRiskCapPct()
{
   return g_qm_ks_per_trade_risk_cap_pct;
}

// FW8 2026-05-23 — tester-aware throttle for file-stat checks. Pre-FW8 every
// tick called QM_KillSwitchFileExists() twice (manual_halt + portfolio_DD),
// each doing FileIsExist locally + FILE_COMMON — 4 syscalls per tick. In MT5
// tester these signal files never exist; in live they change rarely. We now:
//   - skip both checks entirely in tester (manual halt + portfolio kill from
//     an external file are operator concepts, meaningless during a backtest)
//   - in live, throttle to 1× per broker-second so a busy tick stream
//     doesn't translate to thousands of syscalls/sec
datetime g_qm_ks_last_file_check_broker_ts = 0;

bool QM_KillSwitchCheck()
{
   if(!g_qm_ks_initialized)
   {
      if(!g_qm_ks_unconfigured_logged)
      {
         QM_LogEvent(QM_WARN, "KILL_SWITCH_UNCONFIGURED", "{}");
         g_qm_ks_unconfigured_logged = true;
      }
      return true;
   }

   QM_FrameworkTrackOpenPositionMae();
   QM_KillSwitchRefreshBrokerDay();
   if(g_qm_ks_halted)
   {
      // Review 27c36fb7: the trip flatten was ONE-SHOT — a failed close
      // (market closed on a leg, disconnect, partial fill) or a pending that
      // filled after the trip left exposure open and unmanaged forever while
      // halted. Re-sweep at most once per 60 broker-seconds until flat.
      const datetime now_retry = TimeCurrent();
      if(now_retry - g_qm_ks_halt_retry_ts >= 60)
      {
         g_qm_ks_halt_retry_ts = now_retry;
         if(QM_KillSwitchOwnedExposureExists())
         {
            const int closed_retry = QM_KillSwitchCloseOwnedPositions();
            const int deleted_retry = QM_KillSwitchDeleteOwnedPendings();
            QM_LogEvent(QM_ERROR,
                        "KILL_SWITCH_FLATTEN_RETRY",
                        StringFormat("{\"reason\":\"%s\",\"closed\":%d,\"pendings_deleted\":%d}",
                                     QM_LoggerEscapeJson(g_qm_ks_halt_reason),
                                     closed_retry,
                                     deleted_retry));
         }
      }
      return false;
   }

   // Operator-signal files (manual halt + portfolio DD) live only in live ops.
   const bool is_tester = (MQLInfoInteger(MQL_TESTER) != 0);
   if(!is_tester)
   {
      const datetime broker_now = TimeCurrent();
      if(broker_now != g_qm_ks_last_file_check_broker_ts)
      {
         g_qm_ks_last_file_check_broker_ts = broker_now;
         if(QM_KillSwitchFileExists(g_qm_ks_manual_halt_file))
         {
            QM_KillSwitchTrip(KS_MANUAL,
                              StringFormat("{\"file\":\"%s\"}", QM_LoggerEscapeJson(g_qm_ks_manual_halt_file)));
            return false;
         }

         double portfolio_signal_value = 0.0;
         bool portfolio_value_present = false;
         if(QM_KillSwitchPortfolioSignalTriggered(portfolio_signal_value, portfolio_value_present))
         {
            if(portfolio_value_present)
            {
               QM_KillSwitchTrip(KS_PORTFOLIO_DD,
                                 StringFormat("{\"file\":\"%s\",\"signal_value\":%.6f,\"halt_pct\":%.6f}",
                                              QM_LoggerEscapeJson(g_qm_ks_portfolio_dd_signal_file),
                                              portfolio_signal_value,
                                              g_qm_ks_portfolio_dd_halt_pct));
            }
            else
            {
               QM_KillSwitchTrip(KS_PORTFOLIO_DD,
                                 StringFormat("{\"file\":\"%s\",\"signal_value\":null,\"halt_pct\":%.6f}",
                                              QM_LoggerEscapeJson(g_qm_ks_portfolio_dd_signal_file),
                                              g_qm_ks_portfolio_dd_halt_pct));
            }
            return false;
         }
      } // end: if(broker_now != g_qm_ks_last_file_check_broker_ts)
   } // end: if(!is_tester)

   if(g_qm_ks_daily_loss_halt_pct > 0.0 && g_qm_ks_day_start_equity > 0.0)
   {
      const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
      const double pnl_pct = ((equity_now - g_qm_ks_day_start_equity) / g_qm_ks_day_start_equity) * 100.0;
      if(pnl_pct <= -g_qm_ks_daily_loss_halt_pct)
      {
         QM_KillSwitchTrip(KS_DAILY_LOSS,
                           StringFormat("{\"equity_start\":%.2f,\"equity_now\":%.2f,\"pnl_pct\":%.6f,\"halt_pct\":%.6f}",
                                        g_qm_ks_day_start_equity,
                                        equity_now,
                                        pnl_pct,
                                        g_qm_ks_daily_loss_halt_pct));
         return false;
      }
   }

   return true;
}

#endif // QM_KILL_SWITCH_MQH
