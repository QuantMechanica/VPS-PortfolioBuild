#ifndef QM_MOD_FTMO_JOINT_EQUITY_SAMPLER_20180_MQH
#define QM_MOD_FTMO_JOINT_EQUITY_SAMPLER_20180_MQH

#ifndef QM_FJ_FTMO_PRODUCER_VERSION
#define QM_FJ_FTMO_PRODUCER_VERSION "QM5_20181_FTMO_TRACE_V2"
#endif

// =============================================================================
// QM5_20180 FTMO JOINT (backtest-only) — account-equity sampler.
// -----------------------------------------------------------------------------
// LEGACY DIAGNOSTIC DELIVERABLE (design §7 / task requirement #4): observed
// account-equity rows instead of a proxy that invents intratrade equity
// (a5768d03_equity_export_gap_2026-07-27.md).  These rows are FTMO-complete only
// when every enabled position is on the host symbol.  QM5_20181 J1/J2 carry
// non-host symbols and therefore use the explicit v2 setup block below.
//
// The shipped emitter QM_EquityStreamOnNewBar emits ONE snapshot per DAY at the
// day CLOSE — it captures neither observed intraday equity nor observed lows.
// This sampler adds diagnostic resolution; it does not by itself prove a
// tick/event-complete FTMO interval minimum for a multi-symbol book.
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
// COMPLETENESS BOUNDARY (adversarial-review C4):
//   QM5_20180 is USDJPY-only, so every price-driven equity move is on the host
//   tick stream. QM5_20181 J1/J2 are NOT USDJPY-only: XAUUSD/XTIUSD can make and
//   reverse a trough between host ticks and between one-second timer callbacks.
//   Their legacy rows are diagnostic only. QM_FJ_Eq_ConfigureV2Blocked writes
//   coverage_complete=false so the downstream money gate cannot consume them.
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

double QM_FJ_Eq_FloatingForMagic(const long magic);

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

// Configure the explicit FTMO-v2 setup-block envelope used by QM5_20181.
//
// The producer can truthfully observe account equity on every HOST tick plus
// every model-second timer callback.  It cannot prove the sub-second ticks of
// XAUUSD/XTIUSD that occur between those callbacks.  Therefore this function
// writes the exact requested v2 metadata followed by one coverage point with
// coverage_complete=false.  The adapter consequently returns
// SETUP_DATA_MISSING instead of interpreting the legacy sampler as a money gate.
// Existing EQUITY_LOW/EQUITY_BAR rows continue afterwards for diagnostics and
// historical consumers; no legacy trading or comparator path is changed.
bool QM_FJ_Eq_ConfigureV2Blocked(const long &magics[],
                                 const string &symbols[],
                                 const string run_id)
  {
   QM_FJ_Eq_Configure(magics);
   if(run_id == "" || AccountInfoString(ACCOUNT_CURRENCY) != "USD" ||
      g_qm_fj_eq_nmagics <= 0 ||
      g_qm_fj_eq_nmagics != ArraySize(symbols))
      return false;

   string members = "[";
   string covered_magics = "[";
   string covered_symbols = "[";
   string floating = "[";
   double floating_total = 0.0;
   for(int i = 0; i < g_qm_fj_eq_nmagics; ++i)
     {
      if(magics[i] <= 0 || symbols[i] == "")
         return false;
      for(int j = 0; j < i; ++j)
         if(magics[j] == magics[i] || symbols[j] == symbols[i])
            return false;
      const double value = QM_FJ_Eq_FloatingForMagic(magics[i]);
      floating_total += value;
      if(i > 0)
        {
         members += ",";
         covered_magics += ",";
         covered_symbols += ",";
         floating += ",";
        }
      members += StringFormat("{\"magic\":%I64d,\"symbol\":\"%s\"}",
                              magics[i],
                              QM_LoggerEscapeJson(symbols[i]));
      covered_magics += (string)magics[i];
      covered_symbols += StringFormat("\"%s\"",
                                      QM_LoggerEscapeJson(symbols[i]));
      floating += StringFormat(
         "{\"magic\":%I64d,\"symbol\":\"%s\",\"f\":%.2f}",
         magics[i],
         QM_LoggerEscapeJson(symbols[i]),
         value);
     }
   members += "]";
   covered_magics += "]";
   covered_symbols += "]";
   floating += "]";

   const datetime now = TimeCurrent();
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_qm_fj_eq_buf += StringFormat(
      "{\"event\":\"FTMO_JOINT_TRACE_META\",\"schema_version\":1,"
      "\"q08_trade_schema_version\":2,\"trace_id\":\"%s\","
      "\"run_id\":\"%s\",\"producer_version\":\"%s\","
      "\"currency\":\"USD\",\"grid_seconds\":3600,"
      "\"money_decimals\":2,\"host_symbol\":\"%s\","
      "\"expected_members\":%s,"
      "\"balance_basis\":\"NET_CLOSED_TRADING_PNL_INCLUDING_COSTS_NO_EXTERNAL_CASHFLOWS\","
      "\"equity_basis\":\"MARK_TO_MARKET_INCLUDING_OPEN_PNL_SWAP_COMMISSION\","
      "\"opened_positions_basis\":\"RECONCILED_POSITION_FIRST_OPEN_EVENTS_IN_INTERVAL_(PREVIOUS_TS,TS]\","
      "\"interval_min_equity_basis\":\"TICK_EVENT_COMPLETE_INTERVAL_MIN_EQUITY_INCLUDING_ENDPOINTS\","
      "\"pending_orders_basis\":\"RECONCILED_PENDING_ORDER_STATE_AT_ENDPOINT_AND_EVENT_COMPLETE_INTERVAL\","
      "\"coverage_basis\":\"TICK_EVENT_COMPLETE_ALL_BOOK_SYMBOLS_AND_ACCOUNT_EVENTS\","
      "\"trade_net_basis\":\"FULL_POSITION_LIFECYCLE_PROFIT_SWAP_AND_ENTRY_EXIT_COMMISSION\","
      "\"floating_basis\":\"OPEN_POSITION_PROFIT_AND_ACCRUED_SWAP_BY_MAGIC\","
      "\"producer_status\":\"SETUP_DATA_MISSING\","
      "\"coverage_observation_basis\":\"HOST_TICK_PLUS_MODEL_SECOND_TIMER_NOT_EVENT_COMPLETE\","
      "\"producer_block_reasons\":[\"NON_HOST_SUBSECOND_TICKS_NOT_OBSERVED\","
      "\"EVENT_COMPLETE_MTM_REPLAY_PRODUCER_MISSING\"]}\r\n",
      QM_LoggerEscapeJson(run_id),
      QM_LoggerEscapeJson(run_id),
      QM_FJ_FTMO_PRODUCER_VERSION,
      QM_LoggerEscapeJson(_Symbol),
      members);
   g_qm_fj_eq_buf += StringFormat(
      "{\"event\":\"FTMO_JOINT_TRACE_POINT\",\"schema_version\":1,"
      "\"trace_id\":\"%s\",\"run_id\":\"%s\","
      "\"producer_version\":\"%s\",\"interval_sequence\":0,"
      "\"interval_start_utc\":%I64d,\"interval_end_utc\":%I64d,"
      "\"t_utc\":%I64d,\"balance\":%.2f,\"equity\":%.2f,"
      "\"interval_min_equity\":%.2f,\"open_positions\":%d,"
      "\"opened_positions\":0,\"pending_orders\":%d,"
      "\"day_anchor\":false,\"coverage_complete\":false,"
      "\"covered_magics\":%s,\"covered_symbols\":%s,"
      "\"fl_total\":%.2f,\"fl\":%s,"
      "\"coverage_block_reason\":\"NON_HOST_SUBSECOND_TICKS_NOT_OBSERVED\"}\r\n",
      QM_LoggerEscapeJson(run_id),
      QM_LoggerEscapeJson(run_id),
      QM_FJ_FTMO_PRODUCER_VERSION,
      (long)QM_BrokerToUTC(now),
      (long)QM_BrokerToUTC(now),
      (long)QM_BrokerToUTC(now),
      balance,
      equity,
      equity,
      PositionsTotal(),
      OrdersTotal(),
      covered_magics,
      covered_symbols,
      floating_total,
      floating);
   return true;
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
