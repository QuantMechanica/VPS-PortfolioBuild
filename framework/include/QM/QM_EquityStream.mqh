#ifndef QM_EQUITY_STREAM_MQH
#define QM_EQUITY_STREAM_MQH

// V5 Framework — End-of-day equity snapshot emitter.
//
// Created 2026-05-23 (FW6, pipeline rewrite). Purpose: produce a clean
// time-series of {ts_utc, equity, day_pnl, month_pnl, atr_regime} events
// so Q08 sub-gates (Seasonal / Edge Decay / Regime) can read structured
// monthly data without re-parsing trade logs.
//
// Emission rule:
//   On every closed bar, check whether the broker-time DAY has changed since
//   the last snapshot. If so, emit one EQUITY_SNAPSHOT log event with the
//   previous day's closing equity + per-day / per-month P&L attribution.
//
// The event lands in the standard per-EA JSON-lines log; Q08 sub-gate
// scripts pull EQUITY_SNAPSHOT events directly from that log.
//
// ATR regime classification (low / normal / high) uses the symbol's
// current-bar ATR(14) D1 vs a 100-bar rolling baseline:
//   atr_ratio = ATR_today / ATR_baseline_median
//   < 0.75 → "low"   (compression)
//   0.75 to 1.25 → "normal"
//   > 1.25 → "high"  (expansion)

#include "QM_Logger.mqh"
#include "QM_DSTAware.mqh"

bool      g_qm_eqstream_initialized      = false;
int       g_qm_eqstream_last_day_key     = -1;
int       g_qm_eqstream_last_month_key   = -1;
double    g_qm_eqstream_day_start_equity = 0.0;
double    g_qm_eqstream_month_start_equity = 0.0;
int       g_qm_eqstream_atr_handle       = INVALID_HANDLE;

string QM_EquityStreamStateName(const string suffix)
  {
   return StringFormat("QM_EQS_%I64d_%d_%s",
                       AccountInfoInteger(ACCOUNT_LOGIN),
                       g_qm_logger_ea_id,
                       suffix);
  }

bool QM_EquityStreamRestoreBaseline(const string period_name,
                                    const string key_suffix,
                                    const string equity_suffix,
                                    const int current_key,
                                    double &baseline)
  {
   // Tester agents reuse terminal GlobalVariables across runs. Reading them in
   // a test would make otherwise-identical backtests depend on agent history.
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return false;
   if(AccountInfoInteger(ACCOUNT_LOGIN) <= 0)
      return false;

   const string key_name = QM_EquityStreamStateName(key_suffix);
   const string equity_name = QM_EquityStreamStateName(equity_suffix);
   const bool has_key = GlobalVariableCheck(key_name);
   const bool has_equity = GlobalVariableCheck(equity_name);
   if(!has_key && !has_equity)
      return false;

   const double raw_key = has_key ? GlobalVariableGet(key_name) : -1.0;
   const double saved_equity = has_equity ? GlobalVariableGet(equity_name) : 0.0;
   int saved_key = -1;
   if(MathIsValidNumber(raw_key))
      saved_key = (int)MathRound(raw_key);

   const bool key_is_integer = MathIsValidNumber(raw_key) &&
                               MathAbs(raw_key - (double)saved_key) <= 0.0000001;
   const bool saved_equity_valid = MathIsValidNumber(saved_equity) && saved_equity > 0.0;
   const bool valid = has_key && has_equity && key_is_integer &&
                      saved_key == current_key && saved_equity_valid;
   if(!valid)
     {
      const double logged_saved_equity = MathIsValidNumber(saved_equity) ? saved_equity : 0.0;
      QM_LogEvent(QM_WARN, "EQUITY_STREAM_STATE_STALE_IGNORED",
                  StringFormat("{\"period\":\"%s\",\"saved_key\":%d,\"current_key\":%d,\"has_key\":%s,\"has_equity\":%s,\"saved_equity_valid\":%s,\"saved_equity\":%.2f}",
                               QM_LoggerEscapeJson(period_name),
                               saved_key,
                               current_key,
                               has_key ? "true" : "false",
                               has_equity ? "true" : "false",
                               saved_equity_valid ? "true" : "false",
                               logged_saved_equity));
      return false;
     }

   baseline = saved_equity;
   QM_LogEvent(QM_INFO, "EQUITY_STREAM_STATE_RESTORED",
               StringFormat("{\"period\":\"%s\",\"key\":%d,\"start_equity\":%.2f}",
                            QM_LoggerEscapeJson(period_name), current_key, baseline));
   return true;
  }

bool QM_EquityStreamPersistBaseline(const string period_name,
                                    const string key_suffix,
                                    const string equity_suffix,
                                    const int period_key,
                                    const double baseline)
  {
   // Backtests stay process-local and deterministic; never read or write
   // terminal GlobalVariables from tester/optimization agents.
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return true;

   if(AccountInfoInteger(ACCOUNT_LOGIN) <= 0)
     {
      QM_LogEvent(QM_WARN, "EQUITY_STREAM_STATE_PERSIST_FAILED",
                  StringFormat("{\"period\":\"%s\",\"stage\":\"account_login\",\"key\":%d,\"error\":0}",
                               QM_LoggerEscapeJson(period_name), period_key));
      return false;
     }

   if(!MathIsValidNumber(baseline) || baseline <= 0.0)
     {
      QM_LogEvent(QM_WARN, "EQUITY_STREAM_STATE_PERSIST_FAILED",
                  StringFormat("{\"period\":\"%s\",\"stage\":\"validation\",\"key\":%d,\"error\":0}",
                               QM_LoggerEscapeJson(period_name), period_key));
      return false;
     }

   const string key_name = QM_EquityStreamStateName(key_suffix);
   const string equity_name = QM_EquityStreamStateName(equity_suffix);

   // The value is written first and the period key last as the commit marker.
   // A crash between the writes therefore leaves a key mismatch on next init.
   ResetLastError();
   if(GlobalVariableSet(equity_name, baseline) == 0)
     {
      QM_LogEvent(QM_WARN, "EQUITY_STREAM_STATE_PERSIST_FAILED",
                  StringFormat("{\"period\":\"%s\",\"stage\":\"equity\",\"key\":%d,\"error\":%d}",
                               QM_LoggerEscapeJson(period_name), period_key, GetLastError()));
      return false;
     }

   ResetLastError();
   if(GlobalVariableSet(key_name, (double)period_key) == 0)
     {
      QM_LogEvent(QM_WARN, "EQUITY_STREAM_STATE_PERSIST_FAILED",
                  StringFormat("{\"period\":\"%s\",\"stage\":\"key\",\"key\":%d,\"error\":%d}",
                               QM_LoggerEscapeJson(period_name), period_key, GetLastError()));
      return false;
     }

   GlobalVariablesFlush();
   return true;
  }

int QM_EquityStreamDayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int QM_EquityStreamMonthKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 100 + dt.mon;
  }

string QM_EquityStreamATRRegime()
  {
   if(g_qm_eqstream_atr_handle == INVALID_HANDLE)
      g_qm_eqstream_atr_handle = iATR(_Symbol, PERIOD_D1, 14);
   if(g_qm_eqstream_atr_handle == INVALID_HANDLE)
      return "unknown";

   double atr_now[1];
   if(CopyBuffer(g_qm_eqstream_atr_handle, 0, 1, 1, atr_now) <= 0)
      return "unknown";
   if(atr_now[0] <= 0.0)
      return "unknown";

   // 100-day baseline median for atr_today/baseline ratio. A PARTIAL copy
   // must be rejected: local fixed arrays are not zero-initialized in MQL5,
   // so sorting a partially-filled buffer mixes stack garbage into the
   // median (2026-07-06 audit, found independently by 4 lanes).
   double atr_hist[100];
   if(CopyBuffer(g_qm_eqstream_atr_handle, 0, 2, 100, atr_hist) != 100)
      return "unknown";

   // simple selection-sort partial for median (cheap; 100 is small)
   ArraySort(atr_hist);
   const double median = atr_hist[50];
   if(median <= 0.0)
      return "unknown";

   const double ratio = atr_now[0] / median;
   if(ratio < 0.75)
      return "low";
   if(ratio > 1.25)
      return "high";
   return "normal";
  }

void QM_EquityStreamInit()
  {
   g_qm_eqstream_initialized = true;
   const datetime now = TimeCurrent();
   g_qm_eqstream_last_day_key   = QM_EquityStreamDayKey(now);
   g_qm_eqstream_last_month_key = QM_EquityStreamMonthKey(now);
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   g_qm_eqstream_day_start_equity   = equity_now;
   g_qm_eqstream_month_start_equity = equity_now;

   // Restore each period independently. Missing, stale, or invalid state is
   // re-baselined to current equity without preventing framework init.
   if(!QM_EquityStreamRestoreBaseline("day",
                                      "DAY_KEY",
                                      "DAY_EQUITY",
                                      g_qm_eqstream_last_day_key,
                                      g_qm_eqstream_day_start_equity))
      QM_EquityStreamPersistBaseline("day",
                                     "DAY_KEY",
                                     "DAY_EQUITY",
                                     g_qm_eqstream_last_day_key,
                                     g_qm_eqstream_day_start_equity);

   if(!QM_EquityStreamRestoreBaseline("month",
                                      "MONTH_KEY",
                                      "MONTH_EQUITY",
                                      g_qm_eqstream_last_month_key,
                                      g_qm_eqstream_month_start_equity))
      QM_EquityStreamPersistBaseline("month",
                                     "MONTH_KEY",
                                     "MONTH_EQUITY",
                                     g_qm_eqstream_last_month_key,
                                     g_qm_eqstream_month_start_equity);
  }

// Call on every closed-bar tick. Cheap: most calls early-return because
// the day hasn't changed yet.
void QM_EquityStreamOnNewBar()
  {
   if(!g_qm_eqstream_initialized)
      QM_EquityStreamInit();

   const datetime now = TimeCurrent();
   const int day_key   = QM_EquityStreamDayKey(now);
   const int month_key = QM_EquityStreamMonthKey(now);
   if(day_key == g_qm_eqstream_last_day_key)
      return;  // same day, no snapshot needed

   // Day rolled over — emit snapshot for the day that just closed.
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   const double day_pnl    = equity_now - g_qm_eqstream_day_start_equity;
   const double month_pnl  = equity_now - g_qm_eqstream_month_start_equity;
   const string regime     = QM_EquityStreamATRRegime();

   const string payload = StringFormat(
      "{\"scope\":\"account\",\"day_key\":%d,\"month_key\":%d,\"equity\":%.2f,\"day_pnl\":%.2f,\"month_pnl\":%.2f,\"atr_regime\":\"%s\",\"symbol\":\"%s\"}",
      g_qm_eqstream_last_day_key,
      g_qm_eqstream_last_month_key,
      equity_now,
      day_pnl,
      month_pnl,
      regime,
      QM_LoggerEscapeJson(_Symbol)
   );
   QM_LogEvent(QM_INFO, "EQUITY_SNAPSHOT", payload);

   // Roll the day window.
   g_qm_eqstream_last_day_key = day_key;
   g_qm_eqstream_day_start_equity = equity_now;
   QM_EquityStreamPersistBaseline("day",
                                  "DAY_KEY",
                                  "DAY_EQUITY",
                                  g_qm_eqstream_last_day_key,
                                  g_qm_eqstream_day_start_equity);

   // Roll the month window when month also rolled over.
   if(month_key != g_qm_eqstream_last_month_key)
     {
      g_qm_eqstream_last_month_key = month_key;
      g_qm_eqstream_month_start_equity = equity_now;
      QM_EquityStreamPersistBaseline("month",
                                     "MONTH_KEY",
                                     "MONTH_EQUITY",
                                     g_qm_eqstream_last_month_key,
                                     g_qm_eqstream_month_start_equity);
     }
  }

void QM_EquityStreamShutdown()
  {
   if(g_qm_eqstream_atr_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_qm_eqstream_atr_handle);
      g_qm_eqstream_atr_handle = INVALID_HANDLE;
     }
   g_qm_eqstream_initialized = false;
  }

#endif // QM_EQUITY_STREAM_MQH
