#ifndef QM_MOD_FTMO_JOINT_TRADE_V2_20181_MQH
#define QM_MOD_FTMO_JOINT_TRADE_V2_20181_MQH

#ifndef QM_FJ_FTMO_PRODUCER_VERSION
#define QM_FJ_FTMO_PRODUCER_VERSION "QM5_20181_FTMO_TRACE_V2"
#endif

// =============================================================================
// QM5_20181 FTMO Book-3 — q08 TRADE_CLOSED lifecycle-v2 producer.
// -----------------------------------------------------------------------------
// This module is TESTER-ONLY evidence instrumentation.  It does not participate
// in signal generation, sizing, order submission, position management, or any
// other trading decision.
//
// The framework's legacy q08 emitter deliberately writes one row per closing
// deal.  The FTMO money-evidence adapter needs one row per fully closed position,
// including stable position/deal identities and entry/exit cost events.  MT5's
// tester does not deliver every DEAL_ADD callback reliably, so this module uses
// the same authoritative source as the legacy emitter: one HistorySelect walk at
// shutdown.
//
// Fail-closed rules:
//   * every trading deal must belong to one configured (magic,symbol) member;
//   * INOUT/reversal deals, non-cent money, fees, open/imbalanced positions, and
//     multi-exit lifecycles block v2 publication;
//   * the complete v2 payload is prepared BEFORE framework shutdown (while MAE
//     state still exists), then replaces the legacy stream only AFTER the
//     framework has closed its legacy file handle;
//   * if preparation fails, the legacy stream remains in place and the Python
//     adapter rejects it as SETUP_DATA_MISSING.  A crash/write failure during
//     replacement can leave a partial file, which the adapter rejects; no
//     crash-atomicity or partial success is claimed.
//
// The one-exit restriction preserves the existing singleton replay comparator's
// one-row-per-close cardinality.  If a future strategy uses partial closes, the
// comparator and evidence contract must be versioned together before relaxing it.
// =============================================================================

struct QM_FJ_TradeV2Lifecycle
  {
   ulong    position_id;
   long     magic;
   string   symbol;
   datetime entry_time;
   datetime close_time;
   double   entry_volume;
   double   exit_volume;
   double   profit;
   double   swap;
   double   commission;
   double   entry_commission;
   double   exit_commission;
   double   close_price;
   ulong    last_exit_deal;
   int      entry_count;
   int      exit_count;
   string   entry_deal_ids;
   string   exit_deal_ids;
   string   balance_events;
   int      balance_event_count;
  };

bool   g_qm_fj_trade_v2_configured = false;
bool   g_qm_fj_trade_v2_prepared   = false;
int    g_qm_fj_trade_v2_ea_id      = 0;
string g_qm_fj_trade_v2_host       = "";
string g_qm_fj_trade_v2_run_id     = "";
long   g_qm_fj_trade_v2_magics[];
string g_qm_fj_trade_v2_symbols[];
string g_qm_fj_trade_v2_payload    = "";
string g_qm_fj_trade_v2_block      = "";

double QM_FJ_TradeV2Cents(const double value)
  {
   return MathRound(value * 100.0) / 100.0;
  }

bool QM_FJ_TradeV2IsCentExact(const double value)
  {
   return MathIsValidNumber(value) &&
          MathAbs(value - QM_FJ_TradeV2Cents(value)) <= 0.0000001;
  }

void QM_FJ_TradeV2Block(const string reason)
  {
   if(g_qm_fj_trade_v2_block == "")
      g_qm_fj_trade_v2_block = reason;
  }

int QM_FJ_TradeV2MemberIndex(const long magic, const string symbol)
  {
   const int count = ArraySize(g_qm_fj_trade_v2_magics);
   for(int i = 0; i < count; ++i)
      if(g_qm_fj_trade_v2_magics[i] == magic &&
         g_qm_fj_trade_v2_symbols[i] == symbol)
         return i;
   return -1;
  }

int QM_FJ_TradeV2LifecycleIndex(const QM_FJ_TradeV2Lifecycle &rows[],
                                const ulong position_id)
  {
   const int count = ArraySize(rows);
   for(int i = 0; i < count; ++i)
      if(rows[i].position_id == position_id)
         return i;
   return -1;
  }

void QM_FJ_TradeV2AppendId(string &payload, int &count, const ulong deal_id)
  {
   if(count > 0)
      payload += ",";
   payload += (string)deal_id;
   ++count;
  }

void QM_FJ_TradeV2AppendBalanceEvent(string &payload,
                                     int &count,
                                     const ulong deal_id,
                                     const datetime event_time,
                                     const string component,
                                     const double amount)
  {
   if(count > 0)
      payload += ",";
   payload += StringFormat(
      "{\"deal_id\":%I64u,\"time\":%I64d,\"component\":\"%s\",\"amount\":%.2f}",
      deal_id,
      (long)event_time,
      component,
      QM_FJ_TradeV2Cents(amount));
   ++count;
  }

bool QM_FJ_TradeV2PositionStillOpen(const ulong position_id)
  {
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_id)
         return true;
     }
   return false;
  }

bool QM_FJ_TradeV2Configure(const int ea_id,
                            const string evidence_host_symbol,
                            const string run_id,
                            const long &magics[],
                            const string &symbols[])
  {
   g_qm_fj_trade_v2_configured = false;
   g_qm_fj_trade_v2_prepared = false;
   g_qm_fj_trade_v2_payload = "";
   g_qm_fj_trade_v2_block = "";

   const int count = ArraySize(magics);
   if(ea_id != 20181 || evidence_host_symbol == "" || run_id == "" ||
      count <= 0 || count != ArraySize(symbols))
     {
      QM_FJ_TradeV2Block("CONFIG_INVALID");
      return false;
     }

   ArrayResize(g_qm_fj_trade_v2_magics, count);
   ArrayResize(g_qm_fj_trade_v2_symbols, count);
   for(int i = 0; i < count; ++i)
     {
      if(magics[i] <= 0 || symbols[i] == "")
        {
         QM_FJ_TradeV2Block("MEMBER_INVALID");
         return false;
        }
      for(int j = 0; j < i; ++j)
         if(magics[j] == magics[i] || symbols[j] == symbols[i])
           {
            QM_FJ_TradeV2Block("MEMBER_DUPLICATE");
            return false;
           }
      g_qm_fj_trade_v2_magics[i] = magics[i];
      g_qm_fj_trade_v2_symbols[i] = symbols[i];
     }

   g_qm_fj_trade_v2_ea_id = ea_id;
   g_qm_fj_trade_v2_host = evidence_host_symbol;
   g_qm_fj_trade_v2_run_id = run_id;
   g_qm_fj_trade_v2_configured = true;
   return true;
  }

bool QM_FJ_TradeV2Prepare()
  {
   g_qm_fj_trade_v2_prepared = false;
   g_qm_fj_trade_v2_payload = "";
   if(!g_qm_fj_trade_v2_configured || MQLInfoInteger(MQL_TESTER) == 0)
     {
      QM_FJ_TradeV2Block("NOT_CONFIGURED_OR_NOT_TESTER");
      return false;
     }
   if(!HistorySelect(0, TimeCurrent()))
     {
      QM_FJ_TradeV2Block("HISTORY_SELECT_FAILED");
      return false;
     }

   QM_FJ_TradeV2Lifecycle rows[];
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
        {
         QM_FJ_TradeV2Block("HISTORY_DEAL_TICKET_ZERO");
         break;
        }

      const long deal_type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue; // initial tester deposit and other non-trading records

      const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_INOUT)
        {
         QM_FJ_TradeV2Block("INOUT_REVERSAL_UNSUPPORTED");
         break;
        }
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY)
        {
         QM_FJ_TradeV2Block("DEAL_ENTRY_KIND_UNSUPPORTED");
         break;
        }

      const ulong position_id =
         (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      const string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
      const long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      const double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      const double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
      const double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      const double fee = HistoryDealGetDouble(deal, DEAL_FEE);

      if(position_id == 0 || deal_time <= 0 || volume <= 0.0 ||
         !MathIsValidNumber(volume) ||
         !QM_FJ_TradeV2IsCentExact(profit) ||
         !QM_FJ_TradeV2IsCentExact(swap) ||
         !QM_FJ_TradeV2IsCentExact(commission) ||
         !QM_FJ_TradeV2IsCentExact(fee) || MathAbs(fee) > 0.0000001)
        {
         QM_FJ_TradeV2Block("DEAL_MONEY_OR_IDENTITY_INVALID");
         break;
        }

      int row_index = QM_FJ_TradeV2LifecycleIndex(rows, position_id);
      if(entry == DEAL_ENTRY_IN)
        {
         if(QM_FJ_TradeV2MemberIndex(magic, symbol) < 0)
           {
            QM_FJ_TradeV2Block("FOREIGN_ENTRY_DEAL_PRESENT");
            break;
           }
         if(MathAbs(profit) > 0.0000001 || MathAbs(swap) > 0.0000001)
           {
            QM_FJ_TradeV2Block("ENTRY_PROFIT_OR_SWAP_UNSUPPORTED");
            break;
           }
         if(row_index < 0)
           {
            const int count = ArraySize(rows);
            ArrayResize(rows, count + 1);
            row_index = count;
            rows[row_index].position_id = position_id;
            rows[row_index].magic = magic;
            rows[row_index].symbol = symbol;
            rows[row_index].entry_time = deal_time;
            rows[row_index].close_time = 0;
            rows[row_index].entry_volume = 0.0;
            rows[row_index].exit_volume = 0.0;
            rows[row_index].profit = 0.0;
            rows[row_index].swap = 0.0;
            rows[row_index].commission = 0.0;
            rows[row_index].entry_commission = 0.0;
            rows[row_index].exit_commission = 0.0;
            rows[row_index].close_price = 0.0;
            rows[row_index].last_exit_deal = 0;
            rows[row_index].entry_count = 0;
            rows[row_index].exit_count = 0;
            rows[row_index].entry_deal_ids = "";
            rows[row_index].exit_deal_ids = "";
            rows[row_index].balance_events = "";
            rows[row_index].balance_event_count = 0;
           }
         if(rows[row_index].magic != magic || rows[row_index].symbol != symbol)
           {
            QM_FJ_TradeV2Block("POSITION_MEMBER_CHANGED");
            break;
           }
         rows[row_index].entry_time =
            (rows[row_index].entry_time == 0 ||
             deal_time < rows[row_index].entry_time)
            ? deal_time : rows[row_index].entry_time;
         rows[row_index].entry_volume += volume;
         rows[row_index].commission = QM_FJ_TradeV2Cents(
            rows[row_index].commission + commission);
         rows[row_index].entry_commission = QM_FJ_TradeV2Cents(
            rows[row_index].entry_commission + commission);
         QM_FJ_TradeV2AppendId(rows[row_index].entry_deal_ids,
                               rows[row_index].entry_count,
                               deal);
         QM_FJ_TradeV2AppendBalanceEvent(
            rows[row_index].balance_events,
            rows[row_index].balance_event_count,
            deal,
            deal_time,
            "COMMISSION",
            commission);
         continue;
        }

      // SL/TP exits may carry magic 0.  Ownership is position-based, exactly as
      // in QM_FrameworkQ08EmitFromHistory.
      if(row_index < 0 || rows[row_index].symbol != symbol)
        {
         QM_FJ_TradeV2Block("FOREIGN_OR_ORPHAN_EXIT_DEAL_PRESENT");
         break;
        }
      rows[row_index].close_time = deal_time;
      rows[row_index].exit_volume += volume;
      rows[row_index].profit = QM_FJ_TradeV2Cents(
         rows[row_index].profit + profit);
      rows[row_index].swap = QM_FJ_TradeV2Cents(
         rows[row_index].swap + swap);
      rows[row_index].commission = QM_FJ_TradeV2Cents(
         rows[row_index].commission + commission);
      rows[row_index].exit_commission = QM_FJ_TradeV2Cents(
         rows[row_index].exit_commission + commission);
      rows[row_index].close_price = HistoryDealGetDouble(deal, DEAL_PRICE);
      rows[row_index].last_exit_deal = deal;
      QM_FJ_TradeV2AppendId(rows[row_index].exit_deal_ids,
                            rows[row_index].exit_count,
                            deal);
      QM_FJ_TradeV2AppendBalanceEvent(rows[row_index].balance_events,
                                      rows[row_index].balance_event_count,
                                      deal,
                                      deal_time,
                                      "PROFIT",
                                      profit);
      QM_FJ_TradeV2AppendBalanceEvent(rows[row_index].balance_events,
                                      rows[row_index].balance_event_count,
                                      deal,
                                      deal_time,
                                      "SWAP",
                                      swap);
      QM_FJ_TradeV2AppendBalanceEvent(rows[row_index].balance_events,
                                      rows[row_index].balance_event_count,
                                      deal,
                                      deal_time,
                                      "COMMISSION",
                                      commission);
      QM_FJ_TradeV2AppendBalanceEvent(rows[row_index].balance_events,
                                      rows[row_index].balance_event_count,
                                      deal,
                                      deal_time,
                                      "FEE",
                                      fee);
     }

   if(g_qm_fj_trade_v2_block != "")
      return false;
   const int row_count = ArraySize(rows);
   if(row_count <= 0)
     {
      QM_FJ_TradeV2Block("NO_OWNED_POSITION_LIFECYCLES");
      return false;
     }

   for(int i = 0; i < row_count; ++i)
     {
      const double step = SymbolInfoDouble(rows[i].symbol, SYMBOL_VOLUME_STEP);
      const double tolerance = MathMax(0.0000001, step * 0.5);
      if(rows[i].entry_count <= 0 || rows[i].exit_count != 1 ||
         rows[i].last_exit_deal == 0 ||
         rows[i].entry_time <= 0 || rows[i].close_time <= rows[i].entry_time ||
         MathAbs(rows[i].entry_volume - rows[i].exit_volume) > tolerance ||
         QM_FJ_TradeV2PositionStillOpen(rows[i].position_id))
        {
         QM_FJ_TradeV2Block("POSITION_LIFECYCLE_NOT_FULLY_CLOSED_OR_NOT_LEGACY_COMPATIBLE");
         g_qm_fj_trade_v2_payload = "";
         return false;
        }

      datetime mae_entry_time = 0;
      double mae = QM_FrameworkQ08LookupMae(rows[i].position_id,
                                            mae_entry_time);
      if(mae_entry_time > 0 && mae_entry_time != rows[i].entry_time)
        {
         QM_FJ_TradeV2Block("POSITION_ENTRY_TIME_MAE_HISTORY_MISMATCH");
         g_qm_fj_trade_v2_payload = "";
         return false;
        }
      const double net = QM_FJ_TradeV2Cents(rows[i].profit + rows[i].swap +
                                            rows[i].commission);
      mae = MathMin(MathMin(0.0, mae), net);
      const double notional = QM_FrameworkDealNotionalAccount(
         rows[i].last_exit_deal,
         rows[i].symbol,
         rows[i].exit_volume,
         rows[i].close_price);
      if(!MathIsValidNumber(notional) || notional < 0.0)
        {
         QM_FJ_TradeV2Block("POSITION_NOTIONAL_INVALID");
         g_qm_fj_trade_v2_payload = "";
         return false;
        }

      string row = StringFormat(
         "{\"event\":\"TRADE_CLOSED\",\"schema_version\":2,"
         "\"run_id\":\"%s\",\"producer_version\":\"%s\","
         "\"position_fully_closed\":true,"
         "\"position_id\":%I64u,\"entry_deal_ids\":[%s],"
         "\"exit_deal_ids\":[%s],\"magic\":%I64d,"
         "\"symbol\":\"%s\",\"entry_time\":%I64d,\"time\":%I64d,"
         "\"profit\":%.2f,\"swap\":%.2f,\"commission\":%.2f,"
         "\"entry_commission\":%.2f,\"exit_commission\":%.2f,\"fee\":0.00,"
         "\"net\":%.2f,\"balance_events\":[%s],"
         "\"mae_acct\":%.2f,\"volume\":%.2f,\"notional\":%.2f}\r\n",
         QM_LoggerEscapeJson(g_qm_fj_trade_v2_run_id),
         QM_FJ_FTMO_PRODUCER_VERSION,
         rows[i].position_id,
         rows[i].entry_deal_ids,
         rows[i].exit_deal_ids,
         rows[i].magic,
         QM_LoggerEscapeJson(rows[i].symbol),
         (long)rows[i].entry_time,
         (long)rows[i].close_time,
         rows[i].profit,
         rows[i].swap,
         rows[i].commission,
         rows[i].entry_commission,
         rows[i].exit_commission,
         net,
         rows[i].balance_events,
         mae,
         rows[i].exit_volume,
         notional);
      g_qm_fj_trade_v2_payload += row;
     }

   g_qm_fj_trade_v2_prepared = (g_qm_fj_trade_v2_payload != "");
   return g_qm_fj_trade_v2_prepared;
  }

bool QM_FJ_TradeV2Commit()
  {
   if(!g_qm_fj_trade_v2_prepared || g_qm_fj_trade_v2_payload == "")
      return false;
   string safe_symbol = g_qm_fj_trade_v2_host;
   StringReplace(safe_symbol, ".", "_");
   const string path = StringFormat("QM\\q08_trades\\%d_%s.jsonl",
                                    g_qm_fj_trade_v2_ea_id,
                                    safe_symbol);
   ResetLastError();
   const int handle = FileOpen(path,
                               FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;
   const uint written = FileWriteString(handle, g_qm_fj_trade_v2_payload);
   FileFlush(handle);
   FileClose(handle);
   return written == (uint)StringLen(g_qm_fj_trade_v2_payload);
  }

#endif // QM_MOD_FTMO_JOINT_TRADE_V2_20181_MQH
