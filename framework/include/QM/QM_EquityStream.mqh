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

   // 100-day baseline median for atr_today/baseline ratio
   double atr_hist[100];
   if(CopyBuffer(g_qm_eqstream_atr_handle, 0, 2, 100, atr_hist) <= 0)
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
   g_qm_eqstream_day_start_equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   g_qm_eqstream_month_start_equity = g_qm_eqstream_day_start_equity;
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
      "{\"day_key\":%d,\"month_key\":%d,\"equity\":%.2f,\"day_pnl\":%.2f,\"month_pnl\":%.2f,\"atr_regime\":\"%s\",\"symbol\":\"%s\"}",
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

   // Roll the month window when month also rolled over.
   if(month_key != g_qm_eqstream_last_month_key)
     {
      g_qm_eqstream_last_month_key = month_key;
      g_qm_eqstream_month_start_equity = equity_now;
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
