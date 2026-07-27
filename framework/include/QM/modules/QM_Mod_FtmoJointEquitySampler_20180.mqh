#ifndef QM_MOD_FTMO_JOINT_EQUITY_SAMPLER_20180_MQH
#define QM_MOD_FTMO_JOINT_EQUITY_SAMPLER_20180_MQH

// =============================================================================
// QM5_20180 FTMO JOINT (backtest-only) — account-equity sampler.
// -----------------------------------------------------------------------------
// PRIMARY DELIVERABLE (design §7 / task requirement #4): a REAL account-equity
// series so the FTMO -5% daily / -10% total / +10% / +5% predicates are direct
// reads instead of a proxy that "invents intratrade equity"
// (a5768d03_equity_export_gap_2026-07-27.md).
//
// The shipped emitter QM_EquityStreamOnNewBar emits ONE snapshot per DAY at the
// day CLOSE — it captures neither intraday equity nor the intraday LOW that the
// -5% daily limit is a predicate on. This sampler adds the missing resolution.
//
// File conventions mirror the Q08 trade stream exactly (QM_Common.mqh:952-979):
//   FILE_COMMON, FILE_WRITE|FILE_TXT|FILE_ANSI, persistent handle truncated once
//   at first write, buffered append flushed at ~32 KB and on shutdown.
// Path (host-keyed, one account = one file):
//   Common\Files\QM\q08_equity\20180_USDJPY_DWX.jsonl
//
// Two deterministic row types (Model-4 tick sequence is deterministic):
//   EQUITY_BAR — one per host H1 CLOSED bar; account equity/balance + per-sleeve
//                floating P&L breakdown (so §6 re-leveraging is exact).
//   EQUITY_LOW — every NEW intraday (per-broker-day) low of account equity, plus
//                one anchor row at each broker-day rollover.
//
// WHY THIS IS COMPLETE FOR THIS INSTRUMENT (adversarial-review C4 does NOT bite):
//   C4 showed the sampler under-samples when the account carries a NON-host
//   symbol whose intraday troughs fall between host ticks. This instrument is
//   USDJPY-ONLY: both sleeves trade the host symbol, so every account-equity
//   move happens on a host tick and QM_FJ_Eq_OnTick (called every OnTick) sees
//   it at full tick resolution. No cross-symbol under-sampling exists here.
//
// COST (adversarial-review M3): the per-tick path reads ACCOUNT_EQUITY and does
// one comparison. The O(PositionsTotal) floating-P&L scan runs ONLY when a row
// is actually emitted (a new bar, or a new intraday low), never unconditionally
// every tick — strictly cheaper than the design's per-tick scan that M3 flagged.
// =============================================================================

#include <QM/QM_Common.mqh>

int    g_qm_fj_eq_fh       = INVALID_HANDLE;
string g_qm_fj_eq_buf      = "";
int    g_qm_fj_eq_day_key  = -1;
double g_qm_fj_eq_day_low  = 0.0;
bool   g_qm_fj_eq_have_low = false;
long   g_qm_fj_eq_magics[];
int    g_qm_fj_eq_nmagics  = 0;

void QM_FJ_Eq_Configure(const long &magics[])
  {
   g_qm_fj_eq_nmagics = ArraySize(magics);
   ArrayResize(g_qm_fj_eq_magics, g_qm_fj_eq_nmagics);
   for(int i = 0; i < g_qm_fj_eq_nmagics; ++i)
      g_qm_fj_eq_magics[i] = magics[i];
   g_qm_fj_eq_day_key  = -1;
   g_qm_fj_eq_have_low = false;
   g_qm_fj_eq_day_low  = 0.0;
  }

int QM_FJ_Eq_DayKey(const datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return s.year * 10000 + s.mon * 100 + s.day;
  }

// Floating P&L (profit + swap) of all open positions carrying this magic.
double QM_FJ_Eq_FloatingForMagic(const long magic)
  {
   double f = 0.0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      f += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return f;
  }

void QM_FJ_Eq_Flush()
  {
   if(StringLen(g_qm_fj_eq_buf) == 0)
      return;
   if(g_qm_fj_eq_fh == INVALID_HANDLE)
     {
      string sym = _Symbol;
      StringReplace(sym, ".", "_");
      const string path = StringFormat("QM\\q08_equity\\%d_%s.jsonl", g_qm_fw_ea_id, sym);
      g_qm_fj_eq_fh = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON); // truncate fresh, keep open
      if(g_qm_fj_eq_fh == INVALID_HANDLE)
        {
         QM_LogEvent(QM_WARN, "JOINT_EQUITY_OPEN_FAILED",
                     StringFormat("{\"ea\":%d,\"error\":%d}", g_qm_fw_ea_id, GetLastError()));
         return; // keep the buffer; retry on the next flush
        }
     }
   FileWriteString(g_qm_fj_eq_fh, g_qm_fj_eq_buf);
   FileFlush(g_qm_fj_eq_fh);
   g_qm_fj_eq_buf = "";
  }

void QM_FJ_Eq_EmitRow(const string event, const datetime t)
  {
   const double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   const double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   string fl = "[";
   double fl_total = 0.0;
   for(int i = 0; i < g_qm_fj_eq_nmagics; ++i)
     {
      const double f = QM_FJ_Eq_FloatingForMagic(g_qm_fj_eq_magics[i]);
      fl_total += f;
      if(i > 0)
         fl += ",";
      fl += StringFormat("{\"magic\":%I64d,\"f\":%.2f}", g_qm_fj_eq_magics[i], f);
     }
   fl += "]";

   const long t_broker = (long)t;
   const long t_utc    = (long)QM_BrokerToUTC(t);
   g_qm_fj_eq_buf += StringFormat(
      "{\"event\":\"%s\",\"t_broker\":%I64d,\"t_utc\":%I64d,\"day_key\":%d,\"equity\":%.2f,\"balance\":%.2f,\"fl_total\":%.2f,\"fl\":%s}\r\n",
      event, t_broker, t_utc, QM_FJ_Eq_DayKey(t), eq, bal, fl_total, fl);

   if(StringLen(g_qm_fj_eq_buf) >= 32768)
      QM_FJ_Eq_Flush();
  }

// Call on EVERY OnTick (before the new-bar gate). Tracks the running per-broker-
// day equity minimum and emits an EQUITY_LOW on each new low + a day-rollover
// anchor. The O(N) position scan happens only inside QM_FJ_Eq_EmitRow, i.e. only
// when a row is actually written.
void QM_FJ_Eq_OnTick()
  {
   const datetime now = TimeCurrent();
   const int      dk  = QM_FJ_Eq_DayKey(now);
   const double   eq  = AccountInfoDouble(ACCOUNT_EQUITY);

   if(dk != g_qm_fj_eq_day_key)
     {
      // Broker-day rollover: reset the running minimum and anchor the new day.
      g_qm_fj_eq_day_key  = dk;
      g_qm_fj_eq_day_low  = eq;
      g_qm_fj_eq_have_low = true;
      QM_FJ_Eq_EmitRow("EQUITY_LOW", now);
      return;
     }

   if(!g_qm_fj_eq_have_low || eq < g_qm_fj_eq_day_low)
     {
      g_qm_fj_eq_day_low  = eq;
      g_qm_fj_eq_have_low = true;
      QM_FJ_Eq_EmitRow("EQUITY_LOW", now);
     }
  }

// Call once per host H1 closed bar (inside the QM_IsNewBar gate).
void QM_FJ_Eq_OnNewBar()
  {
   QM_FJ_Eq_EmitRow("EQUITY_BAR", TimeCurrent());
  }

void QM_FJ_Eq_Shutdown()
  {
   QM_FJ_Eq_Flush();
   if(g_qm_fj_eq_fh != INVALID_HANDLE)
     {
      FileClose(g_qm_fj_eq_fh);
      g_qm_fj_eq_fh = INVALID_HANDLE;
     }
  }

#endif // QM_MOD_FTMO_JOINT_EQUITY_SAMPLER_20180_MQH
