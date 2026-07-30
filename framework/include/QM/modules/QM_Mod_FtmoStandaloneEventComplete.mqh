#ifndef QM_MOD_FTMO_STANDALONE_EVENT_COMPLETE_MQH
#define QM_MOD_FTMO_STANDALONE_EVENT_COMPLETE_MQH

// =============================================================================
// FTMO Book-3 standalone event-complete diagnostic producer.
// -----------------------------------------------------------------------------
// Evidence only.  This module never originates an additional trade operation.
// Its 9936 SL hook delegates the EA's existing QM_TM_MoveSL call exactly once
// while observing its request/result; all other code is observational.  The
// module is inert unless BOTH an EA input enables it and MQL_TESTER is true.
// Only the three native Book-3 sleeves are accepted; QM5_20181 joint runs are
// deliberately outside this contract.
//
// HistorySelect at shutdown is authoritative for deals and final order rows.
// Runtime callbacks are used only to prove callback coverage, millisecond deal
// grouping, account checkpoints, and absolute POSITION_SWAP changes.  The
// producer writes a COMPLETE receipt only if every strict check succeeds.
// Otherwise it writes a single-use INCOMPLETE status where possible.  Existing
// run artifacts are never removed, truncated, or replaced.
// No downstream consumer may infer completeness from the five data files alone.
// =============================================================================

#define QM_FTMOEC_ORDER_SCHEMA      "FTMO_ORDER_EVENT_V1"
#define QM_FTMOEC_DEAL_SCHEMA       "FTMO_DEAL_V1"
#define QM_FTMOEC_ACCOUNT_SCHEMA    "FTMO_ACCOUNT_EVENT_V1"
#define QM_FTMOEC_CHECKPOINT_SCHEMA "FTMO_ACCOUNT_CHECKPOINT_V1"
#define QM_FTMOEC_MODIFICATION_SCHEMA "FTMO_POSITION_MODIFICATION_V1"
#define QM_FTMOEC_RECEIPT_SCHEMA    "FTMO_STANDALONE_HISTORY_COMPLETE_V1"
#define QM_FTMOEC_STATUS_SCHEMA     "FTMO_EVENT_COMPLETE_STATUS_V1"
#define QM_FTMOEC_TIME_BASIS        "DARWINEX_US_DST_BROKER_WALL_EPOCH"

bool   g_qm_ftmoec_active = false;
bool   g_qm_ftmoec_complete = false;
bool   g_qm_ftmoec_history_select_complete = false;
bool   g_qm_ftmoec_on_tester_seen = false;
int    g_qm_ftmoec_ea_id = 0;
long   g_qm_ftmoec_magic = 0;
string g_qm_ftmoec_symbol = "";
string g_qm_ftmoec_run_id = "";
long   g_qm_ftmoec_start_msc = 0;
long   g_qm_ftmoec_end_msc = 0;
long   g_qm_ftmoec_expected_start_msc = 0;
long   g_qm_ftmoec_expected_end_msc = 0;
long   g_qm_ftmoec_init_clock_msc = 0;
long   g_qm_ftmoec_actual_first_tick_msc = 0;
long   g_qm_ftmoec_actual_last_tick_msc = 0;
int    g_qm_ftmoec_expected_tester_model = -1;
string g_qm_ftmoec_execution_manifest_path = "";
string g_qm_ftmoec_execution_manifest_sha256 = "";
string g_qm_ftmoec_prague_proof_path = "";
string g_qm_ftmoec_prague_proof_sha256 = "";
double g_qm_ftmoec_start_balance = 0.0;
long   g_qm_ftmoec_source_sequence = 0;
long   g_qm_ftmoec_account_leverage = 0;
string g_qm_ftmoec_account_currency = "";
long   g_qm_ftmoec_account_margin_mode = -1;

int g_qm_ftmoec_order_fh = INVALID_HANDLE;
int g_qm_ftmoec_deal_fh = INVALID_HANDLE;
int g_qm_ftmoec_account_fh = INVALID_HANDLE;
int g_qm_ftmoec_checkpoint_fh = INVALID_HANDLE;
int g_qm_ftmoec_modification_fh = INVALID_HANDLE;

string g_qm_ftmoec_order_path = "";
string g_qm_ftmoec_deal_path = "";
string g_qm_ftmoec_account_path = "";
string g_qm_ftmoec_checkpoint_path = "";
string g_qm_ftmoec_modification_path = "";
string g_qm_ftmoec_receipt_path = "";
string g_qm_ftmoec_status_path = "";

string g_qm_ftmoec_failures[];
ulong  g_qm_ftmoec_callback_deals[];
ulong  g_qm_ftmoec_callback_orders[];
int    g_qm_ftmoec_callback_order_masks[]; // ADD=1, UPDATE=2, TERMINAL/HISTORY=4
string g_qm_ftmoec_order_buffer_rows[];
long   g_qm_ftmoec_order_buffer_times[];
int    g_qm_ftmoec_order_buffer_priorities[];
ulong  g_qm_ftmoec_order_buffer_ids[];
ulong  g_qm_ftmoec_prestart_deals[];
ulong  g_qm_ftmoec_prestart_orders[];
ulong  g_qm_ftmoec_swap_position_ids[];
ulong  g_qm_ftmoec_swap_position_tickets[];
double g_qm_ftmoec_swap_values[];

long   g_qm_ftmoec_boundary_msc[];
long   g_qm_ftmoec_boundary_sequence[];
double g_qm_ftmoec_boundary_balance[];
double g_qm_ftmoec_boundary_equity[];
double g_qm_ftmoec_boundary_swaps[];
string g_qm_ftmoec_boundary_swap_vectors[];
double g_qm_ftmoec_boundary_margin[];
double g_qm_ftmoec_boundary_margin_free[];
double g_qm_ftmoec_boundary_margin_level[];
int    g_qm_ftmoec_boundary_positions[];
int    g_qm_ftmoec_boundary_orders[];

int g_qm_ftmoec_order_rows = 0;
int g_qm_ftmoec_deal_rows = 0;
int g_qm_ftmoec_account_rows = 0;
int g_qm_ftmoec_checkpoint_rows = 0;
int g_qm_ftmoec_modification_rows = 0;

struct QM_FTMOEC_SltpIntent
  {
   long   trigger_time_msc;
   long   source_sequence;
   ulong  ticket;
   ulong  position_id;
   double old_sl;
   double old_tp;
   double new_sl;
   double new_tp;
   string reason;
   bool   result_snapshot_valid;
   bool   send_ok;
   uint   retcode;
   ulong  request_id;
   bool   request_callback_seen;
   bool   position_callback_seen;
   uint   callback_retcode;
   ulong  callback_request_id;
   ulong  correlated_sl_exit_deal;
   double correlated_sl_exit_price;
  };
QM_FTMOEC_SltpIntent g_qm_ftmoec_sltp_intents[];

bool QM_FTMOEC_CommonFileSha256(const string file_name, string &hash_hex);

long QM_FTMOEC_NextSequence()
  {
   ++g_qm_ftmoec_source_sequence;
   return g_qm_ftmoec_source_sequence;
  }

double QM_FTMOEC_Cents(const double value)
  {
   return MathRound(value * 100.0) / 100.0;
  }

bool QM_FTMOEC_IsCentExact(const double value)
  {
   return MathIsValidNumber(value) &&
          MathAbs(value - QM_FTMOEC_Cents(value)) <= 0.0000001;
  }

string QM_FTMOEC_EscapeJson(const string value)
  {
   string escaped = value;
   StringReplace(escaped, "\\", "\\\\");
   StringReplace(escaped, "\"", "\\\"");
   StringReplace(escaped, "\r", "\\r");
   StringReplace(escaped, "\n", "\\n");
   StringReplace(escaped, "\t", "\\t");
   return escaped;
  }

string QM_FTMOEC_Number(const double value, const int digits = 16)
  {
   if(!MathIsValidNumber(value))
      return "null";
   return DoubleToString(value, digits);
  }

void QM_FTMOEC_Fail(const string reason)
  {
   if(reason == "")
      return;
   const int count = ArraySize(g_qm_ftmoec_failures);
   for(int i = 0; i < count; ++i)
      if(g_qm_ftmoec_failures[i] == reason)
         return;
   ArrayResize(g_qm_ftmoec_failures, count + 1);
   g_qm_ftmoec_failures[count] = reason;
  }

string QM_FTMOEC_FailureText()
  {
   string value = "";
   const int count = ArraySize(g_qm_ftmoec_failures);
   for(int i = 0; i < count; ++i)
     {
      if(i > 0)
         value += "|";
      value += g_qm_ftmoec_failures[i];
     }
   return value;
  }

bool QM_FTMOEC_SafeRunId(const string value)
  {
   const int length = StringLen(value);
   if(length < 16 || length > 96 || StringFind(value, "..") >= 0)
      return false;
   for(int i = 0; i < length; ++i)
     {
      const ushort ch = StringGetCharacter(value, i);
      const bool alpha = (ch >= 'A' && ch <= 'Z') ||
                         (ch >= 'a' && ch <= 'z');
      const bool digit = (ch >= '0' && ch <= '9');
      if(!alpha && !digit && ch != '_' && ch != '-')
         return false;
      if((i == 0 || i == length - 1) && !alpha && !digit)
         return false;
     }
   return true;
  }

bool QM_FTMOEC_ExpectedSleeve(const int ea_id,
                              const string symbol,
                              const ENUM_TIMEFRAMES period)
  {
   if(ea_id == 9936)
      return symbol == "USDJPY.DWX" && period == PERIOD_H1;
   if(ea_id == 10145)
      return symbol == "XAUUSD.DWX" && period == PERIOD_D1;
   if(ea_id == 13108)
      return symbol == "XTIUSD.DWX" && period == PERIOD_D1;
   return false;
  }

long QM_FTMOEC_NowMsc()
  {
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick) && tick.time_msc > 0)
      return tick.time_msc;
   return ((long)TimeCurrent()) * 1000;
  }

bool QM_FTMOEC_TimeWithinContract(const long time_msc)
  {
   return time_msc >= g_qm_ftmoec_expected_start_msc &&
          time_msc <= g_qm_ftmoec_expected_end_msc;
  }

string QM_FTMOEC_Path(const string schema)
  {
   const string suffix = (schema == QM_FTMOEC_RECEIPT_SCHEMA ||
                          schema == QM_FTMOEC_STATUS_SCHEMA) ? ".json" :
                                                               ".jsonl";
   return StringFormat("QM\\ftmo_event_complete\\%s_%s_QM5_%d%s",
                       schema,
                       g_qm_ftmoec_run_id,
                       g_qm_ftmoec_ea_id,
                       suffix);
  }

bool QM_FTMOEC_IsSha256(const string value)
  {
   if(StringLen(value) != 64)
      return false;
   bool all_zero = true;
   for(int i = 0; i < 64; ++i)
     {
      const ushort ch = StringGetCharacter(value, i);
      const bool digit = ch >= '0' && ch <= '9';
      const bool lower = ch >= 'a' && ch <= 'f';
      const bool upper = ch >= 'A' && ch <= 'F';
      if(!digit && !lower && !upper)
         return false;
      if(ch != '0')
         all_zero = false;
     }
   return !all_zero;
  }

bool QM_FTMOEC_HashMatches(const string actual, const string expected)
  {
   string left = actual;
   string right = expected;
   StringToLower(left);
   StringToLower(right);
   return left == right;
  }

bool QM_FTMOEC_SafeContractPath(const string value)
  {
   return StringFind(value, "QM\\ftmo_event_complete\\contracts\\") == 0 &&
          StringFind(value, "..") < 0 &&
          StringFind(value, ":") < 0 &&
          StringLen(value) > 45 &&
          StringSubstr(value, StringLen(value) - 5) == ".json";
  }

bool QM_FTMOEC_NoPriorRunArtifacts()
  {
   const string paths[] =
     {
      g_qm_ftmoec_order_path,
      g_qm_ftmoec_deal_path,
      g_qm_ftmoec_account_path,
      g_qm_ftmoec_checkpoint_path,
      g_qm_ftmoec_modification_path,
      g_qm_ftmoec_receipt_path,
      g_qm_ftmoec_status_path,
      g_qm_ftmoec_receipt_path + ".tmp",
      g_qm_ftmoec_status_path + ".tmp"
     };
   for(int i = 0; i < ArraySize(paths); ++i)
      if(paths[i] != "" && FileIsExist(paths[i], FILE_COMMON))
         return false;
   return true;
  }

void QM_FTMOEC_CloseDataFiles()
  {
   if(g_qm_ftmoec_order_fh != INVALID_HANDLE)
     {
      FileFlush(g_qm_ftmoec_order_fh);
      FileClose(g_qm_ftmoec_order_fh);
      g_qm_ftmoec_order_fh = INVALID_HANDLE;
     }
   if(g_qm_ftmoec_deal_fh != INVALID_HANDLE)
     {
      FileFlush(g_qm_ftmoec_deal_fh);
      FileClose(g_qm_ftmoec_deal_fh);
      g_qm_ftmoec_deal_fh = INVALID_HANDLE;
     }
   if(g_qm_ftmoec_account_fh != INVALID_HANDLE)
     {
      FileFlush(g_qm_ftmoec_account_fh);
      FileClose(g_qm_ftmoec_account_fh);
      g_qm_ftmoec_account_fh = INVALID_HANDLE;
     }
   if(g_qm_ftmoec_checkpoint_fh != INVALID_HANDLE)
     {
      FileFlush(g_qm_ftmoec_checkpoint_fh);
      FileClose(g_qm_ftmoec_checkpoint_fh);
      g_qm_ftmoec_checkpoint_fh = INVALID_HANDLE;
     }
   if(g_qm_ftmoec_modification_fh != INVALID_HANDLE)
     {
      FileFlush(g_qm_ftmoec_modification_fh);
      FileClose(g_qm_ftmoec_modification_fh);
      g_qm_ftmoec_modification_fh = INVALID_HANDLE;
     }
  }

bool QM_FTMOEC_OpenDataFiles()
  {
   g_qm_ftmoec_order_path = QM_FTMOEC_Path(QM_FTMOEC_ORDER_SCHEMA);
   g_qm_ftmoec_deal_path = QM_FTMOEC_Path(QM_FTMOEC_DEAL_SCHEMA);
   g_qm_ftmoec_account_path = QM_FTMOEC_Path(QM_FTMOEC_ACCOUNT_SCHEMA);
   g_qm_ftmoec_checkpoint_path = QM_FTMOEC_Path(QM_FTMOEC_CHECKPOINT_SCHEMA);
   g_qm_ftmoec_modification_path = QM_FTMOEC_Path(QM_FTMOEC_MODIFICATION_SCHEMA);
   g_qm_ftmoec_receipt_path = QM_FTMOEC_Path(QM_FTMOEC_RECEIPT_SCHEMA);
   g_qm_ftmoec_status_path = QM_FTMOEC_Path(QM_FTMOEC_STATUS_SCHEMA);

   // Run IDs are single-use.  Never truncate or replace prior evidence.
   if(!QM_FTMOEC_NoPriorRunArtifacts())
     {
      QM_FTMOEC_Fail("RUN_ID_ALREADY_HAS_EVIDENCE");
      return false;
     }

   const int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON;
   g_qm_ftmoec_order_fh = FileOpen(g_qm_ftmoec_order_path, flags);
   g_qm_ftmoec_deal_fh = FileOpen(g_qm_ftmoec_deal_path, flags);
   g_qm_ftmoec_account_fh = FileOpen(g_qm_ftmoec_account_path, flags);
   g_qm_ftmoec_checkpoint_fh = FileOpen(g_qm_ftmoec_checkpoint_path, flags);
   g_qm_ftmoec_modification_fh = FileOpen(g_qm_ftmoec_modification_path, flags);
   if(g_qm_ftmoec_order_fh == INVALID_HANDLE ||
      g_qm_ftmoec_deal_fh == INVALID_HANDLE ||
      g_qm_ftmoec_account_fh == INVALID_HANDLE ||
      g_qm_ftmoec_checkpoint_fh == INVALID_HANDLE ||
      g_qm_ftmoec_modification_fh == INVALID_HANDLE)
     {
      QM_FTMOEC_Fail("COMMON_FILE_OPEN_FAILED");
      QM_FTMOEC_CloseDataFiles();
      return false;
     }

   return true;
  }

int QM_FTMOEC_UlongIndex(const ulong &values[], const ulong value)
  {
   const int count = ArraySize(values);
   for(int i = 0; i < count; ++i)
      if(values[i] == value)
         return i;
   return -1;
  }

int QM_FTMOEC_OrderCallbackIndex(const ulong order_id)
  {
   int index = QM_FTMOEC_UlongIndex(g_qm_ftmoec_callback_orders, order_id);
   if(index >= 0)
      return index;
   const int count = ArraySize(g_qm_ftmoec_callback_orders);
   ArrayResize(g_qm_ftmoec_callback_orders, count + 1);
   ArrayResize(g_qm_ftmoec_callback_order_masks, count + 1);
   g_qm_ftmoec_callback_orders[count] = order_id;
   g_qm_ftmoec_callback_order_masks[count] = 0;
   return count;
  }

string QM_FTMOEC_SideFromOrderType(const long order_type)
  {
   if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_LIMIT ||
      order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_STOP_LIMIT)
      return "BUY";
   if(order_type == ORDER_TYPE_SELL || order_type == ORDER_TYPE_SELL_LIMIT ||
      order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_STOP_LIMIT)
      return "SELL";
   return "";
  }

string QM_FTMOEC_SideFromDealType(const long deal_type)
  {
   if(deal_type == DEAL_TYPE_BUY)
      return "BUY";
   if(deal_type == DEAL_TYPE_SELL)
      return "SELL";
   return "";
  }

string QM_FTMOEC_OrderTypeName(const long order_type)
  {
   if(order_type == ORDER_TYPE_BUY) return "BUY";
   if(order_type == ORDER_TYPE_SELL) return "SELL";
   if(order_type == ORDER_TYPE_BUY_LIMIT) return "BUY_LIMIT";
   if(order_type == ORDER_TYPE_SELL_LIMIT) return "SELL_LIMIT";
   if(order_type == ORDER_TYPE_BUY_STOP) return "BUY_STOP";
   if(order_type == ORDER_TYPE_SELL_STOP) return "SELL_STOP";
   if(order_type == ORDER_TYPE_BUY_STOP_LIMIT) return "BUY_STOP_LIMIT";
   if(order_type == ORDER_TYPE_SELL_STOP_LIMIT) return "SELL_STOP_LIMIT";
   return "";
  }

string QM_FTMOEC_OrderEventName(const long order_state, const bool setup)
  {
   if(setup)
      return "PLACED";
   if(order_state == ORDER_STATE_FILLED)
      return "FILLED";
   if(order_state == ORDER_STATE_CANCELED)
      return "CANCELLED";
   if(order_state == ORDER_STATE_EXPIRED)
      return "EXPIRED";
   if(order_state == ORDER_STATE_PARTIAL)
      return "PARTIAL_FILL";
   return "";
  }

string QM_FTMOEC_DealEntryName(const long entry)
  {
   if(entry == DEAL_ENTRY_IN)
      return "IN";
   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      return "OUT";
   return "";
  }

string QM_FTMOEC_DealReasonName(const long reason)
  {
   if(reason == DEAL_REASON_EXPERT) return "EXPERT";
   if(reason == DEAL_REASON_SL) return "SL";
   if(reason == DEAL_REASON_TP) return "TP";
   if(reason == DEAL_REASON_SO) return "STOP_OUT";
   return "";
  }

string QM_FTMOEC_PositionSwapsJson()
  {
   ulong ids[];
   double amounts[];
   const int positions = PositionsTotal();
   for(int i = 0; i < positions; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_qm_ftmoec_symbol ||
         PositionGetInteger(POSITION_MAGIC) != g_qm_ftmoec_magic)
         continue;
      const int accepted = ArraySize(ids);
      ArrayResize(ids, accepted + 1);
      ArrayResize(amounts, accepted + 1);
      ids[accepted] = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      amounts[accepted] = PositionGetDouble(POSITION_SWAP);
     }
   const int count = ArraySize(ids);
   for(int i = 1; i < count; ++i)
     {
      const ulong id = ids[i];
      const double amount = amounts[i];
      int j = i - 1;
      while(j >= 0 && ids[j] > id)
        {
         ids[j + 1] = ids[j];
         amounts[j + 1] = amounts[j];
         --j;
        }
      ids[j + 1] = id;
      amounts[j + 1] = amount;
     }
   string rows = "[";
   for(int i = 0; i < count; ++i)
     {
      if(i > 0)
         rows += ",";
      rows += StringFormat("{\"position_id\":%I64u,\"amount\":%.2f}",
                           ids[i],amounts[i]);
     }
   rows += "]";
   return rows;
  }

bool QM_FTMOEC_MarginState(double &margin,
                            double &margin_free,
                            double &margin_level)
  {
   margin = AccountInfoDouble(ACCOUNT_MARGIN);
   margin_free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(!MathIsValidNumber(margin) || margin < 0.0 ||
      !MathIsValidNumber(margin_free) || margin_free < 0.0 ||
      !MathIsValidNumber(margin_level) || margin_level < 0.0)
     {
      QM_FTMOEC_Fail("INVALID_MARGIN_STATE");
      return false;
     }
   return true;
  }

bool QM_FTMOEC_AccountState(double &balance,
                            double &equity,
                            int &position_count,
                            int &order_count,
                            double &position_swaps)
  {
   balance = AccountInfoDouble(ACCOUNT_BALANCE);
   equity = AccountInfoDouble(ACCOUNT_EQUITY);
   position_count = 0;
   order_count = 0;
   position_swaps = 0.0;
   if(!QM_FTMOEC_IsCentExact(balance) || !QM_FTMOEC_IsCentExact(equity))
      QM_FTMOEC_Fail("NON_CENT_ACCOUNT_MONEY");

   const int positions = PositionsTotal();
   for(int i = 0; i < positions; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
        {
         QM_FTMOEC_Fail("POSITION_SELECTION_FAILED");
         continue;
        }
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol != g_qm_ftmoec_symbol || magic != g_qm_ftmoec_magic)
        {
         QM_FTMOEC_Fail("FOREIGN_POSITION_OR_MAGIC");
         continue;
        }
      const double swap = PositionGetDouble(POSITION_SWAP);
      if(!QM_FTMOEC_IsCentExact(swap))
         QM_FTMOEC_Fail("NON_CENT_POSITION_SWAP");
      position_swaps += swap;
      ++position_count;
     }

   const int orders = OrdersTotal();
   for(int i = 0; i < orders; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
        {
         QM_FTMOEC_Fail("ORDER_SELECTION_FAILED");
         continue;
        }
      const string symbol = OrderGetString(ORDER_SYMBOL);
      const long magic = OrderGetInteger(ORDER_MAGIC);
      if(symbol != g_qm_ftmoec_symbol || magic != g_qm_ftmoec_magic)
        {
         QM_FTMOEC_Fail("FOREIGN_ORDER_OR_MAGIC");
         continue;
        }
      ++order_count;
     }
   if(!QM_FTMOEC_IsCentExact(position_swaps))
      QM_FTMOEC_Fail("NON_CENT_POSITION_SWAP_TOTAL");
   return ArraySize(g_qm_ftmoec_failures) == 0;
  }

void QM_FTMOEC_WriteCheckpoint(const string kind,
                               const long time_msc,
                               const long source_sequence,
                               const string deal_ids,
                               const double balance,
                               const double equity,
                               const int position_count,
                               const int order_count,
                               const string position_swaps,
                               const double margin,
                               const double margin_free,
                               const double margin_level)
  {
   if(!QM_FTMOEC_TimeWithinContract(time_msc) ||
      (kind == "START" && time_msc != g_qm_ftmoec_expected_start_msc) ||
      (kind == "END" && time_msc != g_qm_ftmoec_expected_end_msc))
     {
      QM_FTMOEC_Fail("CHECKPOINT_OUTSIDE_CONTRACT_WINDOW");
      return;
     }
   if(g_qm_ftmoec_checkpoint_fh == INVALID_HANDLE)
     {
      QM_FTMOEC_Fail("CHECKPOINT_HANDLE_INVALID");
      return;
     }
   const string row = StringFormat(
      "{\"schema\":\"%s\",\"run_id\":\"%s\",\"ea_id\":%d,"
      "\"symbol\":\"%s\",\"magic\":%I64d,\"time_msc\":%I64d,"
      "\"time_basis\":\"%s\","
      "\"source_sequence\":%I64d,\"kind\":\"%s\",\"deal_ids\":%s,"
      "\"balance\":%.2f,\"equity\":%.2f,\"open_positions\":%d,"
      "\"pending_orders\":%d,\"position_swaps\":%s,\"margin\":%s,"
      "\"margin_free\":%s,\"margin_level\":%s,\"account_leverage\":%I64d,"
      "\"account_currency\":\"%s\",\"account_margin_mode\":%I64d}\r\n",
      QM_FTMOEC_CHECKPOINT_SCHEMA,QM_FTMOEC_EscapeJson(g_qm_ftmoec_run_id),
      g_qm_ftmoec_ea_id,QM_FTMOEC_EscapeJson(g_qm_ftmoec_symbol),
      g_qm_ftmoec_magic,time_msc,QM_FTMOEC_TIME_BASIS,source_sequence,kind,
      deal_ids,balance,equity,
      position_count,order_count,position_swaps,QM_FTMOEC_Number(margin),
      QM_FTMOEC_Number(margin_free),QM_FTMOEC_Number(margin_level),
      g_qm_ftmoec_account_leverage,
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_account_currency),
      g_qm_ftmoec_account_margin_mode);
   if(FileWriteString(g_qm_ftmoec_checkpoint_fh, row) != (uint)StringLen(row))
      QM_FTMOEC_Fail("CHECKPOINT_WRITE_FAILED");
   ++g_qm_ftmoec_checkpoint_rows;
  }

void QM_FTMOEC_WriteCurrentCheckpoint(const string kind, const long time_msc)
  {
   double balance = 0.0;
   double equity = 0.0;
   double swaps = 0.0;
   int positions = 0;
   int orders = 0;
   double margin = 0.0;
   double margin_free = 0.0;
   double margin_level = 0.0;
   QM_FTMOEC_AccountState(balance, equity, positions, orders, swaps);
   QM_FTMOEC_MarginState(margin, margin_free, margin_level);
   QM_FTMOEC_WriteCheckpoint(kind,time_msc,QM_FTMOEC_NextSequence(),"[]",
                             balance,equity,positions,orders,
                             QM_FTMOEC_PositionSwapsJson(),margin,margin_free,
                             margin_level);
  }

int QM_FTMOEC_SwapIndex(const ulong position_id)
  {
   return QM_FTMOEC_UlongIndex(g_qm_ftmoec_swap_position_ids, position_id);
  }

void QM_FTMOEC_ObservePositionSwaps(const long time_msc)
  {
   if(!g_qm_ftmoec_active)
      return;
   if(!QM_FTMOEC_TimeWithinContract(time_msc))
     {
      QM_FTMOEC_Fail("ACCOUNT_EVENT_OUTSIDE_CONTRACT_WINDOW");
      return;
     }
   const int positions = PositionsTotal();
   for(int i = 0; i < positions; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
        {
         QM_FTMOEC_Fail("POSITION_SELECTION_FAILED");
         continue;
        }
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol != g_qm_ftmoec_symbol || magic != g_qm_ftmoec_magic)
        {
         QM_FTMOEC_Fail("FOREIGN_POSITION_OR_MAGIC");
         continue;
        }
      const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const double swap = PositionGetDouble(POSITION_SWAP);
      if(position_id == 0 || !QM_FTMOEC_IsCentExact(swap))
        {
         QM_FTMOEC_Fail("INVALID_POSITION_SWAP_MARK");
         continue;
        }
      int index = QM_FTMOEC_SwapIndex(position_id);
      bool changed = false;
      if(index < 0)
        {
         index = ArraySize(g_qm_ftmoec_swap_position_ids);
         ArrayResize(g_qm_ftmoec_swap_position_ids, index + 1);
         ArrayResize(g_qm_ftmoec_swap_position_tickets, index + 1);
         ArrayResize(g_qm_ftmoec_swap_values, index + 1);
         g_qm_ftmoec_swap_position_ids[index] = position_id;
         g_qm_ftmoec_swap_position_tickets[index] = ticket;
         g_qm_ftmoec_swap_values[index] = swap;
         changed = true; // explicit zero anchor is part of the absolute stream
        }
      else if(MathAbs(g_qm_ftmoec_swap_values[index] - swap) > 0.0000001)
        {
         g_qm_ftmoec_swap_position_tickets[index] = ticket;
         g_qm_ftmoec_swap_values[index] = swap;
         changed = true;
        }
      if(changed)
        {
         if(g_qm_ftmoec_account_fh == INVALID_HANDLE)
           {
            QM_FTMOEC_Fail("ACCOUNT_EVENT_HANDLE_INVALID");
            continue;
           }
         const long sequence = QM_FTMOEC_NextSequence();
         const string row = StringFormat(
            "{\"schema\":\"%s\",\"run_id\":\"%s\",\"ea_id\":%d,"
            "\"symbol\":\"%s\",\"magic\":%I64d,\"time_msc\":%I64d,"
            "\"time_basis\":\"%s\","
            "\"source_sequence\":%I64d,\"event_id\":\"SWAP_%I64d\","
            "\"kind\":\"POSITION_SWAP_MARK\",\"position_id\":%I64u,"
            "\"position_ticket\":%I64u,\"amount\":%.2f,"
            "\"observed_at_time_msc\":%I64d,\"effective_time_msc\":null,"
            "\"effective_time_basis\":\"UNRESOLVED_EXTERNAL_PRAGUE_RECONCILIATION_REQUIRED\","
            "\"prague_midnight_proof_sha256\":\"%s\"}\r\n",
            QM_FTMOEC_ACCOUNT_SCHEMA,QM_FTMOEC_EscapeJson(g_qm_ftmoec_run_id),
            g_qm_ftmoec_ea_id,QM_FTMOEC_EscapeJson(g_qm_ftmoec_symbol),
            g_qm_ftmoec_magic,time_msc,QM_FTMOEC_TIME_BASIS,sequence,sequence,
            position_id,ticket,swap,
            time_msc,g_qm_ftmoec_prague_proof_sha256);
         if(FileWriteString(g_qm_ftmoec_account_fh, row) !=
            (uint)StringLen(row))
            QM_FTMOEC_Fail("ACCOUNT_EVENT_WRITE_FAILED");
         ++g_qm_ftmoec_account_rows;
        }
     }
  }

void QM_FTMOEC_CaptureDealBoundary(const long time_msc)
  {
   double balance = 0.0;
   double equity = 0.0;
   double swaps = 0.0;
   int positions = 0;
   int orders = 0;
   double margin = 0.0;
   double margin_free = 0.0;
   double margin_level = 0.0;
   QM_FTMOEC_AccountState(balance, equity, positions, orders, swaps);
   QM_FTMOEC_MarginState(margin, margin_free, margin_level);

   int index = ArraySize(g_qm_ftmoec_boundary_msc) - 1;
   if(index >= 0 && time_msc < g_qm_ftmoec_boundary_msc[index])
     {
      QM_FTMOEC_Fail("LATE_OR_NONMONOTONE_DEAL_CALLBACK");
      return;
     }
   if(index < 0 || time_msc > g_qm_ftmoec_boundary_msc[index])
     {
      index = ArraySize(g_qm_ftmoec_boundary_msc);
      ArrayResize(g_qm_ftmoec_boundary_msc, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_sequence, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_balance, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_equity, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_swaps, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_swap_vectors, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_margin, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_margin_free, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_margin_level, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_positions, index + 1);
      ArrayResize(g_qm_ftmoec_boundary_orders, index + 1);
      g_qm_ftmoec_boundary_msc[index] = time_msc;
     }
   // Equal-millisecond deals deliberately replace the provisional snapshot.
   // The final callback in the proven group is the exact DEAL_BOUNDARY state.
   g_qm_ftmoec_boundary_sequence[index] = QM_FTMOEC_NextSequence();
   g_qm_ftmoec_boundary_balance[index] = balance;
   g_qm_ftmoec_boundary_equity[index] = equity;
   g_qm_ftmoec_boundary_swaps[index] = swaps;
   g_qm_ftmoec_boundary_swap_vectors[index] = QM_FTMOEC_PositionSwapsJson();
   g_qm_ftmoec_boundary_margin[index] = margin;
   g_qm_ftmoec_boundary_margin_free[index] = margin_free;
   g_qm_ftmoec_boundary_margin_level[index] = margin_level;
   g_qm_ftmoec_boundary_positions[index] = positions;
   g_qm_ftmoec_boundary_orders[index] = orders;
  }

bool QM_FTMOEC_OrderSelected(const ulong order_id,
                             bool &historical,
                             string &symbol,
                             long &magic,
                             long &order_type,
                             long &order_state,
                             long &reason,
                             double &volume_initial,
                             double &volume_current,
                             long &setup_msc,
                             long &done_msc)
  {
   historical = false;
   if(OrderSelect(order_id))
     {
      symbol = OrderGetString(ORDER_SYMBOL);
      magic = OrderGetInteger(ORDER_MAGIC);
      order_type = OrderGetInteger(ORDER_TYPE);
      order_state = OrderGetInteger(ORDER_STATE);
      reason = OrderGetInteger(ORDER_REASON);
      volume_initial = OrderGetDouble(ORDER_VOLUME_INITIAL);
      volume_current = OrderGetDouble(ORDER_VOLUME_CURRENT);
      setup_msc = OrderGetInteger(ORDER_TIME_SETUP_MSC);
      done_msc = 0;
      return true;
     }
   if(HistoryOrderSelect(order_id))
     {
      historical = true;
      symbol = HistoryOrderGetString(order_id, ORDER_SYMBOL);
      magic = HistoryOrderGetInteger(order_id, ORDER_MAGIC);
      order_type = HistoryOrderGetInteger(order_id, ORDER_TYPE);
      order_state = HistoryOrderGetInteger(order_id, ORDER_STATE);
      reason = HistoryOrderGetInteger(order_id, ORDER_REASON);
      volume_initial = HistoryOrderGetDouble(order_id, ORDER_VOLUME_INITIAL);
      volume_current = HistoryOrderGetDouble(order_id, ORDER_VOLUME_CURRENT);
      setup_msc = HistoryOrderGetInteger(order_id, ORDER_TIME_SETUP_MSC);
      done_msc = HistoryOrderGetInteger(order_id, ORDER_TIME_DONE_MSC);
      return true;
     }
   return false;
  }

void QM_FTMOEC_RecordOrderCallback(const MqlTradeTransaction &trans)
  {
   if(trans.order == 0)
     {
      QM_FTMOEC_Fail("ORDER_CALLBACK_WITHOUT_ORDER_ID");
      return;
     }
   int bit = 0;
   string event = EnumToString(trans.type);
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
      bit = 1;
   else if(trans.type == TRADE_TRANSACTION_ORDER_UPDATE)
     {
      bit = 2;
      // MT5 exposes setup/done milliseconds, not an exact modification time.
      // Keeping the observed row is useful, but it cannot authorize COMPLETE.
      QM_FTMOEC_Fail("ORDER_MODIFICATION_TIME_UNPROVABLE");
     }
   else if(trans.type == TRADE_TRANSACTION_HISTORY_ADD)
      bit = 4;
   else
      return;

   const int callback_index = QM_FTMOEC_OrderCallbackIndex(trans.order);
   if((g_qm_ftmoec_callback_order_masks[callback_index] & bit) != 0)
      QM_FTMOEC_Fail("DUPLICATE_ORDER_LIFECYCLE_CALLBACK");
   g_qm_ftmoec_callback_order_masks[callback_index] |= bit;

   bool historical = false;
   string symbol = "";
   long magic = 0;
   long order_type = trans.order_type;
   long order_state = trans.order_state;
   long reason = 0;
   double volume_initial = trans.volume;
   double volume_current = trans.volume;
   long setup_msc = 0;
   long done_msc = 0;
   if(!QM_FTMOEC_OrderSelected(trans.order,historical,symbol,magic,order_type,
                               order_state,reason,volume_initial,volume_current,
                               setup_msc,done_msc))
     {
      QM_FTMOEC_Fail("ORDER_CALLBACK_NOT_SELECTABLE");
      symbol = trans.symbol;
      magic = g_qm_ftmoec_magic;
     }
   if(symbol != g_qm_ftmoec_symbol || magic != g_qm_ftmoec_magic)
      QM_FTMOEC_Fail("FOREIGN_ORDER_CALLBACK");
   ulong selected_position_id = 0;
   ulong selected_position_by_id = 0;
   double selected_price = trans.price;
   double selected_stop_limit = trans.price_trigger;
   double selected_sl = trans.price_sl;
   double selected_tp = trans.price_tp;
   long selected_expiration_msc = (long)trans.time_expiration * 1000;
   if(historical)
     {
      selected_position_id =
         (ulong)HistoryOrderGetInteger(trans.order, ORDER_POSITION_ID);
      selected_position_by_id =
         (ulong)HistoryOrderGetInteger(trans.order, ORDER_POSITION_BY_ID);
      selected_price = HistoryOrderGetDouble(trans.order, ORDER_PRICE_OPEN);
      selected_stop_limit =
         HistoryOrderGetDouble(trans.order, ORDER_PRICE_STOPLIMIT);
      selected_sl = HistoryOrderGetDouble(trans.order, ORDER_SL);
      selected_tp = HistoryOrderGetDouble(trans.order, ORDER_TP);
      selected_expiration_msc =
         (long)HistoryOrderGetInteger(trans.order, ORDER_TIME_EXPIRATION) * 1000;
     }
   else if(OrderSelect(trans.order))
     {
      selected_position_id = (ulong)OrderGetInteger(ORDER_POSITION_ID);
      selected_position_by_id = (ulong)OrderGetInteger(ORDER_POSITION_BY_ID);
      selected_price = OrderGetDouble(ORDER_PRICE_OPEN);
      selected_stop_limit = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
      selected_sl = OrderGetDouble(ORDER_SL);
      selected_tp = OrderGetDouble(ORDER_TP);
      selected_expiration_msc =
         (long)OrderGetInteger(ORDER_TIME_EXPIRATION) * 1000;
     }
   const string side = QM_FTMOEC_SideFromOrderType(order_type);
   const string canonical_type = QM_FTMOEC_OrderTypeName(order_type);
   string canonical_event = "";
   if(bit == 1)
      canonical_event = "PLACED";
   else if(bit == 2)
      canonical_event = order_state == ORDER_STATE_PARTIAL ? "PARTIAL_FILL" :
                                                           "MODIFIED";
   else
      canonical_event = QM_FTMOEC_OrderEventName(order_state, false);
   if(side == "" || canonical_type == "" || canonical_event == "")
     {
      QM_FTMOEC_Fail("UNSUPPORTED_ORDER_TYPE");
      return;
     }
   if(volume_initial <= 0.0 || volume_current < 0.0 ||
      !MathIsValidNumber(volume_initial) || !MathIsValidNumber(volume_current) ||
      selected_price <= 0.0 || !MathIsValidNumber(selected_price) ||
      selected_stop_limit < 0.0 || !MathIsValidNumber(selected_stop_limit) ||
      selected_sl < 0.0 || !MathIsValidNumber(selected_sl) ||
      selected_tp < 0.0 || !MathIsValidNumber(selected_tp))
      QM_FTMOEC_Fail("INVALID_ORDER_VALUE");

   long event_msc = setup_msc;
   string time_source = "ORDER_TIME_SETUP_MSC";
   if(bit == 4 && done_msc > 0)
     {
      event_msc = done_msc;
      time_source = "ORDER_TIME_DONE_MSC";
     }
   if(bit == 2 || event_msc <= 0)
     {
      event_msc = ((long)TimeCurrent()) * 1000;
      time_source = "CALLBACK_SECOND_ONLY";
      QM_FTMOEC_Fail("ORDER_CALLBACK_MILLISECOND_MISSING");
     }

   const string position_id = selected_position_id == 0 ? "null" :
                                                   (string)selected_position_id;
   const long observation_sequence = QM_FTMOEC_NextSequence();
   const string row = StringFormat(
      "{\"schema\":\"%s\",\"run_id\":\"%s\",\"ea_id\":%d,"
      "\"symbol\":\"%s\",\"magic\":%I64d,\"time_msc\":%I64d,"
      "\"time_basis\":\"%s\","
      "\"source_sequence\":FTMOEC_SEQUENCE_REQUIRED,"
      "\"callback_observation_sequence\":%I64d,"
      "\"order_id\":%I64u,\"position_id\":%s,"
      "\"event\":\"%s\",\"type\":\"%s\",\"volume_initial\":%s,"
      "\"volume_remaining\":%s,\"price\":%s,\"stop_limit\":%s,"
      "\"sl\":%s,\"tp\":%s,\"source\":\"CALLBACK\","
      "\"time_msc_source\":\"%s\",\"callback_type\":\"%s\","
      "\"order_state\":\"%s\",\"order_reason\":\"%s\","
      "\"position_by_id\":%I64u,\"expiration_msc\":%I64d}\r\n",
      QM_FTMOEC_ORDER_SCHEMA,QM_FTMOEC_EscapeJson(g_qm_ftmoec_run_id),
      g_qm_ftmoec_ea_id,QM_FTMOEC_EscapeJson(symbol),magic,event_msc,
      QM_FTMOEC_TIME_BASIS,observation_sequence,
      trans.order,position_id,canonical_event,canonical_type,
      QM_FTMOEC_Number(volume_initial),QM_FTMOEC_Number(volume_current),
      QM_FTMOEC_Number(selected_price),QM_FTMOEC_Number(selected_stop_limit),
      QM_FTMOEC_Number(selected_sl),QM_FTMOEC_Number(selected_tp),
      time_source,event,EnumToString((ENUM_ORDER_STATE)order_state),
      EnumToString((ENUM_ORDER_REASON)reason),selected_position_by_id,
      selected_expiration_msc);
   const int buffered = ArraySize(g_qm_ftmoec_order_buffer_rows);
   if(ArrayResize(g_qm_ftmoec_order_buffer_rows, buffered + 1) != buffered + 1 ||
      ArrayResize(g_qm_ftmoec_order_buffer_times, buffered + 1) != buffered + 1 ||
      ArrayResize(g_qm_ftmoec_order_buffer_priorities, buffered + 1) !=
         buffered + 1 ||
      ArrayResize(g_qm_ftmoec_order_buffer_ids, buffered + 1) != buffered + 1)
     {
      QM_FTMOEC_Fail("ORDER_EVENT_BUFFER_ALLOCATION_FAILED");
      return;
     }
   g_qm_ftmoec_order_buffer_rows[buffered] = row;
   g_qm_ftmoec_order_buffer_times[buffered] = event_msc;
   g_qm_ftmoec_order_buffer_priorities[buffered] = bit == 1 ? 1 :
                                                    (bit == 2 ? 2 : 3);
   g_qm_ftmoec_order_buffer_ids[buffered] = trans.order;
  }

void QM_FTMOEC_WriteBufferedOrderEvents()
  {
   const int count = ArraySize(g_qm_ftmoec_order_buffer_rows);
   if(count != ArraySize(g_qm_ftmoec_order_buffer_times) ||
      count != ArraySize(g_qm_ftmoec_order_buffer_priorities) ||
      count != ArraySize(g_qm_ftmoec_order_buffer_ids))
     {
      QM_FTMOEC_Fail("ORDER_EVENT_BUFFER_CARDINALITY_MISMATCH");
      return;
     }
   for(int i = 1; i < count; ++i)
     {
      const string row = g_qm_ftmoec_order_buffer_rows[i];
      const long time_msc = g_qm_ftmoec_order_buffer_times[i];
      const int priority = g_qm_ftmoec_order_buffer_priorities[i];
      const ulong order_id = g_qm_ftmoec_order_buffer_ids[i];
      int j = i - 1;
      while(j >= 0 &&
            (g_qm_ftmoec_order_buffer_times[j] > time_msc ||
             (g_qm_ftmoec_order_buffer_times[j] == time_msc &&
              g_qm_ftmoec_order_buffer_priorities[j] > priority) ||
             (g_qm_ftmoec_order_buffer_times[j] == time_msc &&
              g_qm_ftmoec_order_buffer_priorities[j] == priority &&
              g_qm_ftmoec_order_buffer_ids[j] > order_id)))
        {
         g_qm_ftmoec_order_buffer_rows[j + 1] =
            g_qm_ftmoec_order_buffer_rows[j];
         g_qm_ftmoec_order_buffer_times[j + 1] =
            g_qm_ftmoec_order_buffer_times[j];
         g_qm_ftmoec_order_buffer_priorities[j + 1] =
            g_qm_ftmoec_order_buffer_priorities[j];
         g_qm_ftmoec_order_buffer_ids[j + 1] =
            g_qm_ftmoec_order_buffer_ids[j];
         --j;
        }
      g_qm_ftmoec_order_buffer_rows[j + 1] = row;
      g_qm_ftmoec_order_buffer_times[j + 1] = time_msc;
      g_qm_ftmoec_order_buffer_priorities[j + 1] = priority;
      g_qm_ftmoec_order_buffer_ids[j + 1] = order_id;
     }

   for(int i = 0; i < count; ++i)
     {
      if(!QM_FTMOEC_TimeWithinContract(g_qm_ftmoec_order_buffer_times[i]))
         QM_FTMOEC_Fail("ORDER_EVENT_OUTSIDE_CONTRACT_WINDOW");
      string row = g_qm_ftmoec_order_buffer_rows[i];
      if(StringReplace(row,"FTMOEC_SEQUENCE_REQUIRED",(string)(i + 1)) != 1)
        {
         QM_FTMOEC_Fail("ORDER_EVENT_SEQUENCE_MATERIALIZATION_FAILED");
         continue;
        }
      if(g_qm_ftmoec_order_fh == INVALID_HANDLE ||
         FileWriteString(g_qm_ftmoec_order_fh, row) != (uint)StringLen(row))
         QM_FTMOEC_Fail("ORDER_EVENT_WRITE_FAILED");
      ++g_qm_ftmoec_order_rows;
     }
  }

void QM_FTMOEC_RecordDealCallback(const MqlTradeTransaction &trans)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(trans.deal == 0 || !HistoryDealSelect(trans.deal))
     {
      QM_FTMOEC_Fail("DEAL_CALLBACK_NOT_IN_HISTORY");
      return;
     }
   const long deal_type = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
     {
      QM_FTMOEC_Fail("FOREIGN_CASHFLOW_CALLBACK");
      return;
     }
   if(QM_FTMOEC_UlongIndex(g_qm_ftmoec_callback_deals, trans.deal) >= 0)
     {
      QM_FTMOEC_Fail("DUPLICATE_DEAL_CALLBACK");
      return;
     }
   const int count = ArraySize(g_qm_ftmoec_callback_deals);
   ArrayResize(g_qm_ftmoec_callback_deals, count + 1);
   g_qm_ftmoec_callback_deals[count] = trans.deal;
   QM_FTMOEC_NextSequence(); // preserve cross-artifact observation ordering

   const string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   const long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   const long time_msc = HistoryDealGetInteger(trans.deal, DEAL_TIME_MSC);
   if(symbol != g_qm_ftmoec_symbol || magic != g_qm_ftmoec_magic)
      QM_FTMOEC_Fail("FOREIGN_DEAL_CALLBACK");
   if(time_msc <= 0)
     {
      QM_FTMOEC_Fail("DEAL_TIME_MSC_MISSING");
      return;
     }
   QM_FTMOEC_ObservePositionSwaps(time_msc);
   QM_FTMOEC_CaptureDealBoundary(time_msc);
  }

bool QM_FTMOEC_MoveSL(const ulong ticket,
                      const double new_sl,
                      const string reason)
  {
   if(!g_qm_ftmoec_active)
      return QM_TM_MoveSL(ticket, new_sl, reason);

   ulong position_id = 0;
   double old_sl = 0.0;
   double old_tp = 0.0;
   if(PositionSelectByTicket(ticket) &&
      PositionGetString(POSITION_SYMBOL) == g_qm_ftmoec_symbol &&
      PositionGetInteger(POSITION_MAGIC) == g_qm_ftmoec_magic)
     {
      position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      old_sl = PositionGetDouble(POSITION_SL);
      old_tp = PositionGetDouble(POSITION_TP);
     }
   else
      QM_FTMOEC_Fail("SLTP_INTENT_POSITION_IDENTITY_INVALID");

   const int index = ArraySize(g_qm_ftmoec_sltp_intents);
   const bool allocated =
      ArrayResize(g_qm_ftmoec_sltp_intents, index + 1) == index + 1;
   if(!allocated)
      QM_FTMOEC_Fail("SLTP_INTENT_ALLOCATION_FAILED");
   else
     {
      ZeroMemory(g_qm_ftmoec_sltp_intents[index]);
      g_qm_ftmoec_sltp_intents[index].trigger_time_msc = QM_FTMOEC_NowMsc();
      g_qm_ftmoec_sltp_intents[index].source_sequence = QM_FTMOEC_NextSequence();
      g_qm_ftmoec_sltp_intents[index].ticket = ticket;
      g_qm_ftmoec_sltp_intents[index].position_id = position_id;
      g_qm_ftmoec_sltp_intents[index].old_sl = old_sl;
      g_qm_ftmoec_sltp_intents[index].old_tp = old_tp;
      g_qm_ftmoec_sltp_intents[index].new_sl = new_sl;
      g_qm_ftmoec_sltp_intents[index].new_tp = old_tp;
      g_qm_ftmoec_sltp_intents[index].reason = reason;
     }

   const bool ok = QM_TM_MoveSL(ticket, new_sl, reason);
   if(!allocated)
      return ok;

   // The exact normalized request/result arrives in TRADE_TRANSACTION_REQUEST.
   // Capture only the pre-existing function's return here; no common trade
   // helper state or additional send is introduced.
   g_qm_ftmoec_sltp_intents[index].send_ok = ok;
   const QM_FTMOEC_SltpIntent intent = g_qm_ftmoec_sltp_intents[index];
   if(intent.position_id == 0 || intent.trigger_time_msc <= 0 ||
      intent.new_sl <= 0.0 || !MathIsValidNumber(intent.new_sl) ||
      !MathIsValidNumber(intent.new_tp))
      QM_FTMOEC_Fail("SLTP_INTENT_CAPTURE_INVALID");
   return ok;
  }

void QM_FTMOEC_RecordSltpCallback(const MqlTradeTransaction &trans,
                                  const MqlTradeRequest &request,
                                  const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_REQUEST &&
      request.action == TRADE_ACTION_SLTP)
     {
      int match = -1;
      for(int i = ArraySize(g_qm_ftmoec_sltp_intents) - 1; i >= 0; --i)
        {
         const QM_FTMOEC_SltpIntent intent = g_qm_ftmoec_sltp_intents[i];
         if(!intent.request_callback_seen && intent.ticket == request.position &&
            MathAbs(intent.new_sl - request.sl) <= 0.0000000001 &&
            MathAbs(intent.new_tp - request.tp) <= 0.0000000001)
           {
            match = i;
            break;
           }
        }
      if(match < 0)
        {
         QM_FTMOEC_Fail("UNMATCHED_SLTP_REQUEST_CALLBACK");
         return;
        }
      g_qm_ftmoec_sltp_intents[match].request_callback_seen = true;
      g_qm_ftmoec_sltp_intents[match].result_snapshot_valid = true;
      g_qm_ftmoec_sltp_intents[match].new_sl = request.sl;
      g_qm_ftmoec_sltp_intents[match].new_tp = request.tp;
      g_qm_ftmoec_sltp_intents[match].retcode = result.retcode;
      g_qm_ftmoec_sltp_intents[match].request_id = result.request_id;
      g_qm_ftmoec_sltp_intents[match].callback_retcode = result.retcode;
      g_qm_ftmoec_sltp_intents[match].callback_request_id = result.request_id;
      if(g_qm_ftmoec_sltp_intents[match].send_ok !=
         QM_TradeContextAcceptedRetcode(result.retcode))
         QM_FTMOEC_Fail("SLTP_REQUEST_CALLBACK_RESULT_MISMATCH");
      return;
     }

   if(trans.type != TRADE_TRANSACTION_POSITION)
      return;
   for(int i = ArraySize(g_qm_ftmoec_sltp_intents) - 1; i >= 0; --i)
     {
      const QM_FTMOEC_SltpIntent intent = g_qm_ftmoec_sltp_intents[i];
      if(!intent.send_ok || intent.position_callback_seen ||
         intent.ticket != trans.position)
         continue;
      if(MathAbs(intent.new_sl - trans.price_sl) <= 0.0000000001 &&
         MathAbs(intent.new_tp - trans.price_tp) <= 0.0000000001)
        {
         g_qm_ftmoec_sltp_intents[i].position_callback_seen = true;
         return;
        }
     }
  }

void QM_FTMOEC_OnTradeTransaction(const MqlTradeTransaction &trans,
                                   const MqlTradeRequest &request,
                                   const MqlTradeResult &result)
  {
   if(!g_qm_ftmoec_active)
      return;
   if(trans.type == TRADE_TRANSACTION_REQUEST &&
      request.action == TRADE_ACTION_MODIFY)
      QM_FTMOEC_Fail("ORDER_MODIFICATION_REQUEST_UNCORRELATED");
   QM_FTMOEC_RecordSltpCallback(trans, request, result);
   QM_FTMOEC_RecordOrderCallback(trans);
   QM_FTMOEC_RecordDealCallback(trans);
   if(g_qm_ftmoec_actual_first_tick_msc > 0)
      QM_FTMOEC_ObservePositionSwaps(QM_FTMOEC_NowMsc());
   else
      QM_FTMOEC_Fail("TRADE_CALLBACK_BEFORE_FIRST_TICK");
  }

void QM_FTMOEC_OnTick()
  {
   if(!g_qm_ftmoec_active)
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.time_msc <= 0)
     {
      QM_FTMOEC_Fail("TICK_TIME_MSC_MISSING");
      return;
     }
   if(g_qm_ftmoec_actual_first_tick_msc == 0)
      g_qm_ftmoec_actual_first_tick_msc = tick.time_msc;
   if(g_qm_ftmoec_actual_last_tick_msc > tick.time_msc)
      QM_FTMOEC_Fail("NONMONOTONE_TICK_TIME_MSC");
   g_qm_ftmoec_actual_last_tick_msc = tick.time_msc;
   if(!QM_FTMOEC_TimeWithinContract(tick.time_msc))
      QM_FTMOEC_Fail("TICK_OUTSIDE_CONTRACT_WINDOW");
   QM_FTMOEC_ObservePositionSwaps(tick.time_msc);
  }

void QM_FTMOEC_OnTimer()
  {
   if(g_qm_ftmoec_active && g_qm_ftmoec_actual_first_tick_msc > 0)
      QM_FTMOEC_ObservePositionSwaps(QM_FTMOEC_NowMsc());
  }

void QM_FTMOEC_SortTickets(ulong &tickets[], long &times[])
  {
   const int count = ArraySize(tickets);
   for(int i = 1; i < count; ++i)
     {
      const ulong ticket = tickets[i];
      const long event_time = times[i];
      int j = i - 1;
      while(j >= 0 && (times[j] > event_time ||
                       (times[j] == event_time && tickets[j] > ticket)))
        {
         tickets[j + 1] = tickets[j];
         times[j + 1] = times[j];
         --j;
        }
      tickets[j + 1] = ticket;
      times[j + 1] = event_time;
     }
  }

void QM_FTMOEC_WriteHistoryDeals()
  {
   ulong tickets[];
   long times[];
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
        {
         QM_FTMOEC_Fail("HISTORY_DEAL_TICKET_ZERO");
         continue;
        }
      if(QM_FTMOEC_UlongIndex(g_qm_ftmoec_prestart_deals, deal) >= 0)
         continue;
      const long time_msc = HistoryDealGetInteger(deal, DEAL_TIME_MSC);
      if(time_msc < g_qm_ftmoec_start_msc)
         QM_FTMOEC_Fail("UNSNAPSHOTTED_DEAL_PREDATES_START");
      if(time_msc > g_qm_ftmoec_end_msc)
         QM_FTMOEC_Fail("DEAL_AFTER_END_BOUNDARY");
      const int count = ArraySize(tickets);
      ArrayResize(tickets, count + 1);
      ArrayResize(times, count + 1);
      tickets[count] = deal;
      times[count] = time_msc;
     }
   QM_FTMOEC_SortTickets(tickets, times);

   long group_times[];
   double group_nets[];
   string group_deal_ids[];
   ulong group_position_ids[];
   int trading_deals = 0;
   const int count = ArraySize(tickets);
   for(int i = 0; i < count; ++i)
     {
      const ulong deal = tickets[i];
      const long deal_type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
        {
         QM_FTMOEC_Fail("FOREIGN_CASHFLOW_AFTER_START");
         continue;
        }
      const string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
      const long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
      const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      const ulong order_id = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
      const ulong position_id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      const long reason = HistoryDealGetInteger(deal, DEAL_REASON);
      const double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      const double price = HistoryDealGetDouble(deal, DEAL_PRICE);
      const double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      const double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      const double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
      const double fee = HistoryDealGetDouble(deal, DEAL_FEE);
      const string side = QM_FTMOEC_SideFromDealType(deal_type);
      const string canonical_entry = QM_FTMOEC_DealEntryName(entry);
      const string canonical_reason = QM_FTMOEC_DealReasonName(reason);
      ResetLastError();
      const long order_type = HistoryOrderGetInteger(order_id, ORDER_TYPE);
      if(GetLastError() != 0)
         QM_FTMOEC_Fail("DEAL_ORDER_NOT_IN_HISTORY");
      const string order_type_name = QM_FTMOEC_OrderTypeName(order_type);
      const string execution_mode =
         (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL) ?
         "MARKET" : "PENDING";

      if(symbol != g_qm_ftmoec_symbol || magic != g_qm_ftmoec_magic)
         QM_FTMOEC_Fail("FOREIGN_DEAL_OR_MAGIC");
      if(position_id == 0 || order_id == 0 || side == "" || volume <= 0.0 ||
         price <= 0.0 || !MathIsValidNumber(volume) || !MathIsValidNumber(price))
         QM_FTMOEC_Fail("INVALID_DEAL_IDENTITY_OR_VALUE");
      if(entry == DEAL_ENTRY_INOUT)
         QM_FTMOEC_Fail("INOUT_REVERSAL_UNSUPPORTED");
      if(canonical_entry == "")
         QM_FTMOEC_Fail("UNSUPPORTED_DEAL_ENTRY");
      if(canonical_reason == "")
         QM_FTMOEC_Fail("UNSUPPORTED_DEAL_REASON");
      if(order_type_name == "")
         QM_FTMOEC_Fail("UNSUPPORTED_DEAL_ORDER_TYPE");
      if(!QM_FTMOEC_IsCentExact(profit) ||
         !QM_FTMOEC_IsCentExact(commission) ||
         !QM_FTMOEC_IsCentExact(swap) ||
         !QM_FTMOEC_IsCentExact(fee))
         QM_FTMOEC_Fail("NON_CENT_DEAL_MONEY");
      const int callback_index =
         QM_FTMOEC_UlongIndex(g_qm_ftmoec_callback_deals, deal);
      if(callback_index < 0)
         QM_FTMOEC_Fail("MISSING_DEAL_CALLBACK");

      // The authoritative history stream is sorted by (time_msc, deal_id).
      // Its sequence is local to this artifact and therefore monotone even if
      // the tester delivered equal-millisecond callbacks in another order.
      const long sequence = i + 1;
      const string row = StringFormat(
         "{\"schema\":\"%s\",\"run_id\":\"%s\",\"ea_id\":%d,"
         "\"symbol\":\"%s\",\"magic\":%I64d,\"time_msc\":%I64d,"
         "\"time_basis\":\"%s\","
         "\"source_sequence\":%I64d,\"deal_id\":%I64u,\"order_id\":%I64u,"
         "\"position_id\":%I64u,\"entry\":\"%s\",\"side\":\"%s\","
         "\"execution_mode\":\"%s\",\"reason\":\"%s\",\"volume\":%s,"
         "\"price\":%s,\"profit\":%.2f,\"commission\":%.2f,"
         "\"swap\":%.2f,\"fee\":%.2f,\"order_type\":\"%s\","
         "\"raw_entry\":\"%s\"}\r\n",
         QM_FTMOEC_DEAL_SCHEMA,QM_FTMOEC_EscapeJson(g_qm_ftmoec_run_id),
         g_qm_ftmoec_ea_id,QM_FTMOEC_EscapeJson(symbol),magic,times[i],
         QM_FTMOEC_TIME_BASIS,sequence,
         deal,order_id,position_id,canonical_entry,side,execution_mode,
         canonical_reason,QM_FTMOEC_Number(volume),QM_FTMOEC_Number(price),
         profit,commission,swap,fee,order_type_name,
         EnumToString((ENUM_DEAL_ENTRY)entry));
      if(FileWriteString(g_qm_ftmoec_deal_fh, row) != (uint)StringLen(row))
         QM_FTMOEC_Fail("DEAL_EVENT_WRITE_FAILED");
      ++g_qm_ftmoec_deal_rows;
      ++trading_deals;

      int group = ArraySize(group_times) - 1;
      if(group < 0 || group_times[group] != times[i])
        {
         group = ArraySize(group_times);
         ArrayResize(group_times, group + 1);
         ArrayResize(group_nets, group + 1);
         ArrayResize(group_deal_ids, group + 1);
         group_times[group] = times[i];
         group_nets[group] = 0.0;
         group_deal_ids[group] = "[" + (string)deal + "]";
         ArrayResize(group_position_ids, 0);
        }
      else
         group_deal_ids[group] =
            StringSubstr(group_deal_ids[group],0,
                         StringLen(group_deal_ids[group]) - 1) +
            "," + (string)deal + "]";
      if(QM_FTMOEC_UlongIndex(group_position_ids, position_id) >= 0)
         QM_FTMOEC_Fail("AMBIGUOUS_SAME_MSC_POSITION_LIFECYCLE");
      else
        {
         const int group_positions = ArraySize(group_position_ids);
         ArrayResize(group_position_ids, group_positions + 1);
         group_position_ids[group_positions] = position_id;
        }
      group_nets[group] += profit + commission + swap + fee;
     }

   if(trading_deals != ArraySize(g_qm_ftmoec_callback_deals))
      QM_FTMOEC_Fail("DEAL_CALLBACK_HISTORY_CARDINALITY_MISMATCH");
   if(ArraySize(group_times) != ArraySize(g_qm_ftmoec_boundary_msc))
      QM_FTMOEC_Fail("DEAL_BOUNDARY_GROUP_CARDINALITY_MISMATCH");

   double expected_balance = g_qm_ftmoec_start_balance;
   const int groups = ArraySize(group_times);
   for(int i = 0; i < groups; ++i)
     {
      expected_balance = QM_FTMOEC_Cents(expected_balance + group_nets[i]);
      if(i >= ArraySize(g_qm_ftmoec_boundary_msc) ||
         g_qm_ftmoec_boundary_msc[i] != group_times[i])
        {
         QM_FTMOEC_Fail("DEAL_BOUNDARY_TIME_MISMATCH");
         continue;
        }
      if(!QM_FTMOEC_IsCentExact(group_nets[i]) ||
         MathAbs(expected_balance - g_qm_ftmoec_boundary_balance[i]) > 0.0000001)
         QM_FTMOEC_Fail("DEAL_BOUNDARY_BALANCE_MISMATCH");
      QM_FTMOEC_WriteCheckpoint("DEAL_BOUNDARY",group_times[i],
                                g_qm_ftmoec_boundary_sequence[i],
                                group_deal_ids[i],
                                g_qm_ftmoec_boundary_balance[i],
                                g_qm_ftmoec_boundary_equity[i],
                                g_qm_ftmoec_boundary_positions[i],
                                g_qm_ftmoec_boundary_orders[i],
                                g_qm_ftmoec_boundary_swap_vectors[i],
                                g_qm_ftmoec_boundary_margin[i],
                                g_qm_ftmoec_boundary_margin_free[i],
                                g_qm_ftmoec_boundary_margin_level[i]);
     }
  }

void QM_FTMOEC_WriteHistoryOrders()
  {
   ulong tickets[];
   long times[];
   const int total = HistoryOrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong order_id = HistoryOrderGetTicket(i);
      if(order_id == 0)
        {
         QM_FTMOEC_Fail("HISTORY_ORDER_TICKET_ZERO");
         continue;
        }
      const long setup_msc = HistoryOrderGetInteger(order_id, ORDER_TIME_SETUP_MSC);
      const long done_msc = HistoryOrderGetInteger(order_id, ORDER_TIME_DONE_MSC);
      if(QM_FTMOEC_UlongIndex(g_qm_ftmoec_prestart_orders, order_id) >= 0)
         continue;
      if(setup_msc < g_qm_ftmoec_start_msc && done_msc < g_qm_ftmoec_start_msc)
         QM_FTMOEC_Fail("UNSNAPSHOTTED_ORDER_PREDATES_START");
      if(setup_msc > g_qm_ftmoec_end_msc || done_msc > g_qm_ftmoec_end_msc)
         QM_FTMOEC_Fail("ORDER_AFTER_END_BOUNDARY");
      const int count = ArraySize(tickets);
      ArrayResize(tickets, count + 1);
      ArrayResize(times, count + 1);
      tickets[count] = order_id;
      times[count] = setup_msc;
     }
   QM_FTMOEC_SortTickets(tickets, times);

   const int count = ArraySize(tickets);
   for(int i = 0; i < count; ++i)
     {
      const ulong order_id = tickets[i];
      const long setup_msc = HistoryOrderGetInteger(order_id, ORDER_TIME_SETUP_MSC);
      const long done_msc = HistoryOrderGetInteger(order_id, ORDER_TIME_DONE_MSC);
      const int callback_index =
         QM_FTMOEC_UlongIndex(g_qm_ftmoec_callback_orders, order_id);
      if(callback_index < 0 ||
         (g_qm_ftmoec_callback_order_masks[callback_index] & 1) == 0 ||
         (g_qm_ftmoec_callback_order_masks[callback_index] & 4) == 0)
         QM_FTMOEC_Fail("INCOMPLETE_ORDER_LIFECYCLE_CALLBACKS");
      if(setup_msc <= 0 || done_msc <= 0 || done_msc < setup_msc)
         QM_FTMOEC_Fail("INCOMPLETE_ORDER_HISTORY_LIFECYCLE");

      // Rows were emitted from the correlated ORDER_ADD / HISTORY_ADD callback
      // pair, enriched from this authoritative history record.  Re-emitting the
      // same lifecycle here would create duplicate replay events.
     }
   if(count != ArraySize(g_qm_ftmoec_callback_orders))
      QM_FTMOEC_Fail("ORDER_CALLBACK_HISTORY_CARDINALITY_MISMATCH");
   QM_FTMOEC_WriteBufferedOrderEvents();
  }

void QM_FTMOEC_ReconcileAndWriteSltpModifications()
  {
   const int intent_count = ArraySize(g_qm_ftmoec_sltp_intents);
   const int deal_count = HistoryDealsTotal();
   for(int i = 0; i < deal_count; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         HistoryDealGetInteger(deal, DEAL_TYPE) != DEAL_TYPE_BUY &&
         HistoryDealGetInteger(deal, DEAL_TYPE) != DEAL_TYPE_SELL)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT &&
         HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT_BY)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_REASON) != DEAL_REASON_SL)
         continue;
      const ulong position_id =
         (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      const long deal_time_msc = HistoryDealGetInteger(deal, DEAL_TIME_MSC);
      int latest = -1;
      for(int j = 0; j < intent_count; ++j)
        {
         const QM_FTMOEC_SltpIntent intent = g_qm_ftmoec_sltp_intents[j];
         if(intent.send_ok && intent.position_id == position_id &&
            intent.trigger_time_msc <= deal_time_msc &&
            (latest < 0 ||
             intent.trigger_time_msc >=
                g_qm_ftmoec_sltp_intents[latest].trigger_time_msc))
            latest = j;
        }
      if(latest >= 0)
        {
         g_qm_ftmoec_sltp_intents[latest].correlated_sl_exit_deal = deal;
         g_qm_ftmoec_sltp_intents[latest].correlated_sl_exit_price =
            HistoryDealGetDouble(deal, DEAL_PRICE);
        }
     }

   for(int i = 0; i < intent_count; ++i)
     {
      const QM_FTMOEC_SltpIntent intent = g_qm_ftmoec_sltp_intents[i];
      if(!intent.result_snapshot_valid || !intent.request_callback_seen ||
         intent.callback_retcode != intent.retcode ||
         intent.callback_request_id != intent.request_id)
         QM_FTMOEC_Fail("SLTP_INTENT_REQUEST_RECONCILIATION_INCOMPLETE");
      if(intent.send_ok && !intent.position_callback_seen)
         QM_FTMOEC_Fail("SLTP_POSITION_CALLBACK_MISSING");
      if(intent.send_ok && !QM_TradeContextAcceptedRetcode(intent.retcode))
         QM_FTMOEC_Fail("SLTP_ACCEPTED_RETCODE_INVALID");
      if(!intent.send_ok && QM_TradeContextAcceptedRetcode(intent.retcode))
         QM_FTMOEC_Fail("SLTP_REJECTED_RETCODE_INVALID");
      if(g_qm_ftmoec_modification_fh == INVALID_HANDLE)
        {
         QM_FTMOEC_Fail("POSITION_MODIFICATION_HANDLE_INVALID");
         continue;
        }
      const string row = StringFormat(
         "{\"schema\":\"%s\",\"run_id\":\"%s\",\"ea_id\":%d,"
         "\"symbol\":\"%s\",\"magic\":%I64d,\"time_msc\":%I64d,"
         "\"time_basis\":\"%s\",\"source_sequence\":%I64d,"
         "\"modification_id\":\"SLTP_%I64d\",\"ticket\":%I64u,"
         "\"position_id\":%I64u,\"old_sl\":%s,\"new_sl\":%s,"
         "\"old_tp\":%s,\"new_tp\":%s,\"reason\":\"%s\","
         "\"send_ok\":%s,\"retcode\":%u,\"request_id\":%I64u,"
         "\"request_callback_seen\":%s,\"position_callback_seen\":%s,"
         "\"callback_retcode\":%u,\"callback_request_id\":%I64u,"
         "\"correlated_sl_exit_deal\":%I64u,"
         "\"correlated_sl_exit_price\":%s}\r\n",
         QM_FTMOEC_MODIFICATION_SCHEMA,
         QM_FTMOEC_EscapeJson(g_qm_ftmoec_run_id),g_qm_ftmoec_ea_id,
         QM_FTMOEC_EscapeJson(g_qm_ftmoec_symbol),g_qm_ftmoec_magic,
         intent.trigger_time_msc,QM_FTMOEC_TIME_BASIS,intent.source_sequence,
         intent.source_sequence,intent.ticket,intent.position_id,
         QM_FTMOEC_Number(intent.old_sl),QM_FTMOEC_Number(intent.new_sl),
         QM_FTMOEC_Number(intent.old_tp),QM_FTMOEC_Number(intent.new_tp),
         QM_FTMOEC_EscapeJson(intent.reason),intent.send_ok ? "true" : "false",
         intent.retcode,intent.request_id,
         intent.request_callback_seen ? "true" : "false",
         intent.position_callback_seen ? "true" : "false",
         intent.callback_retcode,intent.callback_request_id,
         intent.correlated_sl_exit_deal,
         QM_FTMOEC_Number(intent.correlated_sl_exit_price));
      if(FileWriteString(g_qm_ftmoec_modification_fh, row) !=
         (uint)StringLen(row))
         QM_FTMOEC_Fail("POSITION_MODIFICATION_WRITE_FAILED");
      ++g_qm_ftmoec_modification_rows;
     }
  }

bool QM_FTMOEC_CommonFileSha256(const string file_name, string &hash_hex)
  {
   hash_hex = "";
   const int handle = FileOpen(file_name,
                               FILE_READ | FILE_BIN | FILE_SHARE_READ |
                               FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;
   const int size = (int)FileSize(handle);
   if(size < 0)
     {
      FileClose(handle);
      return false;
     }
   uchar bytes[];
   if(ArrayResize(bytes, size) != size ||
      (size > 0 && FileReadArray(handle, bytes, 0, size) != size))
     {
      FileClose(handle);
      return false;
     }
   FileClose(handle);
   if(size == 0)
     {
      // CryptEncode behavior for a zero-length source is terminal-build
      // dependent.  Bind an intentionally empty optional stream explicitly.
      hash_hex =
         "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
      return true;
     }
   uchar digest[];
   uchar key[];
   ArrayResize(key, 0);
   const int digest_size = CryptEncode(CRYPT_HASH_SHA256, bytes, key, digest);
   if(digest_size != 32)
      return false;
   for(int i = 0; i < digest_size; ++i)
      hash_hex += StringFormat("%02x", digest[i]);
   return true;
  }

bool QM_FTMOEC_WriteTerminalStatus(const bool complete,
                                   const int deinit_reason,
                                   const string order_sha256,
                                   const string deal_sha256,
                                   const string account_sha256,
                                   const string checkpoint_sha256,
                                   const string modification_sha256)
  {
   const int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON;
   const string path = complete ? g_qm_ftmoec_receipt_path :
                                  g_qm_ftmoec_status_path;
   const string temp_path = path + ".tmp";
   if(FileIsExist(temp_path, FILE_COMMON))
      return false;
   const int handle = FileOpen(temp_path, flags);
   if(handle == INVALID_HANDLE)
      return false;
   const string payload = StringFormat(
      "{\"schema\":\"%s\",\"complete\":%s,\"run_id\":\"%s\","
      "\"ea_id\":%d,\"symbol\":\"%s\",\"magic\":%I64d,"
      "\"start_time_msc\":%I64d,\"end_time_msc\":%I64d,"
      "\"time_basis\":\"%s\","
      "\"orders_sha256\":\"%s\",\"deals_sha256\":\"%s\","
      "\"account_events_sha256\":\"%s\",\"checkpoints_sha256\":\"%s\","
      "\"modifications_sha256\":\"%s\","
      "\"modification_observation_complete\":%s,"
      "\"history_select_complete\":%s,\"end_flat\":%s,"
      "\"normal_deinit_complete\":%s,\"tester_model_contract\":%d,"
      "\"tester_model_runtime_observed\":false,"
      "\"tester_model_verification_basis\":\"HASH_BOUND_EXECUTION_MANIFEST_EXTERNAL_RUNNER\","
      "\"execution_manifest_hash_verified\":true,"
      "\"expected_broker_wall_start_msc\":%I64d,"
      "\"expected_broker_wall_end_msc\":%I64d,"
      "\"init_clock_broker_wall_msc\":%I64d,"
      "\"init_clock_provenance\":\"TIMECURRENT_AT_ONINIT_NOT_A_TICK_BOUNDARY\","
      "\"actual_first_tick_broker_wall_msc\":%I64d,"
      "\"actual_last_tick_broker_wall_msc\":%I64d,"
      "\"raw_evidence_window_semantics\":\"EXACT_BROKER_WALL_TESTER_DATE_RANGE\","
      "\"prague_boundary_day_policy\":\"PARTIAL_BOUNDARY_DAYS_PRESERVED_IN_RAW_EVIDENCE\","
      "\"producer_window_transform\":\"NONE\","
      "\"strategy_truth_window_preserved\":true,"
      "\"execution_manifest_path\":\"%s\","
      "\"execution_manifest_sha256\":\"%s\","
      "\"prague_midnight_proof_path\":\"%s\","
      "\"prague_midnight_proof_sha256\":\"%s\","
      "\"prague_midnight_proof_hash_verified\":true,"
      "\"prague_midnight_proof_semantically_consumed_by_producer\":false,"
      "\"swap_effective_timing_basis\":\"OBSERVATION_ONLY_EFFECTIVE_TIME_NULL\","
      "\"swap_effective_timing_complete\":false,"
      "\"external_prague_swap_timing_reconciliation_required\":true,"
      "\"external_completed_tester_report_required\":true,"
      "\"external_completed_tester_report_verified_by_producer\":false,"
      "\"admission_authority\":\"NONE\","
      "\"expected_account_currency\":\"USD\","
      "\"account_currency\":\"%s\","
      "\"expected_account_margin_mode\":%d,"
      "\"account_margin_mode\":%I64d,"
      "\"expected_account_leverage\":%d,"
      "\"account_contract_verification_basis\":\"HASH_BOUND_EXECUTION_MANIFEST_EXTERNAL_RUNNER_AND_PRODUCER_EXACT_COMPARE\","
      "\"account_leverage\":%I64d,\"producer_status\":\"%s\","
      "\"failure_count\":%d,\"failure_reasons\":\"%s\","
      "\"deinit_reason\":%d,\"order_rows\":%d,\"deal_rows\":%d,"
      "\"account_event_rows\":%d,\"checkpoint_rows\":%d,"
      "\"modifications_rows\":%d,"
      "\"order_file\":\"%s\",\"deal_file\":\"%s\","
      "\"account_event_file\":\"%s\",\"checkpoint_file\":\"%s\","
      "\"modifications_file\":\"%s\"}\r\n",
      complete ? QM_FTMOEC_RECEIPT_SCHEMA : QM_FTMOEC_STATUS_SCHEMA,
      complete ? "true" : "false",QM_FTMOEC_EscapeJson(g_qm_ftmoec_run_id),
      g_qm_ftmoec_ea_id,QM_FTMOEC_EscapeJson(g_qm_ftmoec_symbol),
      g_qm_ftmoec_magic,g_qm_ftmoec_start_msc,g_qm_ftmoec_end_msc,
      QM_FTMOEC_TIME_BASIS,order_sha256,
      deal_sha256,account_sha256,checkpoint_sha256,modification_sha256,
      complete ? "true" : "false",
      g_qm_ftmoec_history_select_complete ? "true" : "false",
      complete ? "true" : "false",
      g_qm_ftmoec_on_tester_seen ? "true" : "false",
      g_qm_ftmoec_expected_tester_model,g_qm_ftmoec_expected_start_msc,
      g_qm_ftmoec_expected_end_msc,g_qm_ftmoec_init_clock_msc,
      g_qm_ftmoec_actual_first_tick_msc,g_qm_ftmoec_actual_last_tick_msc,
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_execution_manifest_path),
      g_qm_ftmoec_execution_manifest_sha256,
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_prague_proof_path),
      g_qm_ftmoec_prague_proof_sha256,
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_account_currency),
      (int)ACCOUNT_MARGIN_MODE_RETAIL_HEDGING,g_qm_ftmoec_account_margin_mode,
      100,
      g_qm_ftmoec_account_leverage,
      complete ? "PRODUCER_COMPLETE" : "INCOMPLETE",
      ArraySize(g_qm_ftmoec_failures),
      QM_FTMOEC_EscapeJson(QM_FTMOEC_FailureText()),deinit_reason,
      g_qm_ftmoec_order_rows,g_qm_ftmoec_deal_rows,g_qm_ftmoec_account_rows,
      g_qm_ftmoec_checkpoint_rows,g_qm_ftmoec_modification_rows,
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_order_path),
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_deal_path),
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_account_path),
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_checkpoint_path),
      QM_FTMOEC_EscapeJson(g_qm_ftmoec_modification_path));
   const uint written = FileWriteString(handle, payload);
   FileFlush(handle);
   const bool exact = written == (uint)StringLen(payload) &&
                      (long)FileSize(handle) == (long)written;
   FileClose(handle);
   if(!exact || FileIsExist(path, FILE_COMMON) ||
      !FileMove(temp_path,FILE_COMMON,path,FILE_COMMON))
     {
      return false;
     }
   return FileIsExist(path, FILE_COMMON);
  }

bool QM_FTMOEC_Init(const bool enabled,
                     const string run_id,
                     const int ea_id,
                     const long magic,
                     const double risk_fixed,
                     const double risk_percent,
                     const long expected_start_msc,
                     const long expected_end_msc,
                     const int expected_tester_model,
                     const string expected_account_currency,
                     const int expected_account_margin_mode,
                     const int expected_account_leverage,
                     const string execution_manifest_path,
                     const string execution_manifest_sha256,
                     const string prague_proof_path,
                     const string prague_proof_sha256)
  {
   g_qm_ftmoec_active = false;
   g_qm_ftmoec_complete = false;
   g_qm_ftmoec_history_select_complete = false;
   g_qm_ftmoec_on_tester_seen = false;
   if(!enabled)
      return true; // default path: no file IO, history scan, or account scan

   ArrayResize(g_qm_ftmoec_failures, 0);
   ArrayResize(g_qm_ftmoec_callback_deals, 0);
   ArrayResize(g_qm_ftmoec_callback_orders, 0);
   ArrayResize(g_qm_ftmoec_callback_order_masks, 0);
   ArrayResize(g_qm_ftmoec_order_buffer_rows, 0);
   ArrayResize(g_qm_ftmoec_order_buffer_times, 0);
   ArrayResize(g_qm_ftmoec_order_buffer_priorities, 0);
   ArrayResize(g_qm_ftmoec_order_buffer_ids, 0);
   ArrayResize(g_qm_ftmoec_prestart_deals, 0);
   ArrayResize(g_qm_ftmoec_prestart_orders, 0);
   ArrayResize(g_qm_ftmoec_swap_position_ids, 0);
   ArrayResize(g_qm_ftmoec_swap_position_tickets, 0);
   ArrayResize(g_qm_ftmoec_swap_values, 0);
   ArrayResize(g_qm_ftmoec_boundary_msc, 0);
   ArrayResize(g_qm_ftmoec_boundary_sequence, 0);
   ArrayResize(g_qm_ftmoec_boundary_balance, 0);
   ArrayResize(g_qm_ftmoec_boundary_equity, 0);
   ArrayResize(g_qm_ftmoec_boundary_swaps, 0);
   ArrayResize(g_qm_ftmoec_boundary_swap_vectors, 0);
   ArrayResize(g_qm_ftmoec_boundary_margin, 0);
   ArrayResize(g_qm_ftmoec_boundary_margin_free, 0);
   ArrayResize(g_qm_ftmoec_boundary_margin_level, 0);
   ArrayResize(g_qm_ftmoec_boundary_positions, 0);
   ArrayResize(g_qm_ftmoec_boundary_orders, 0);
   ArrayResize(g_qm_ftmoec_sltp_intents, 0);
   g_qm_ftmoec_source_sequence = 0;
   g_qm_ftmoec_order_rows = 0;
   g_qm_ftmoec_deal_rows = 0;
   g_qm_ftmoec_account_rows = 0;
   g_qm_ftmoec_checkpoint_rows = 0;
   g_qm_ftmoec_modification_rows = 0;
   g_qm_ftmoec_init_clock_msc = 0;
   g_qm_ftmoec_actual_first_tick_msc = 0;
   g_qm_ftmoec_actual_last_tick_msc = 0;

   if(MQLInfoInteger(MQL_TESTER) == 0)
      return false; // tester-only: never create evidence in chart/live mode
   if(!QM_FTMOEC_SafeRunId(run_id) ||
      StringFind(run_id, "REQUIRED") >= 0 ||
      StringFind(run_id, "PLACEHOLDER") >= 0)
      return false;
   if(!QM_FTMOEC_ExpectedSleeve(ea_id, _Symbol, (ENUM_TIMEFRAMES)_Period))
      return false;
   if(ea_id == 20181 || magic <= 0)
      return false;
   g_qm_ftmoec_ea_id = ea_id;
   g_qm_ftmoec_magic = magic;
   g_qm_ftmoec_symbol = _Symbol;
   g_qm_ftmoec_run_id = run_id;
   if(expected_start_msc <= 0 || expected_end_msc <= expected_start_msc ||
      expected_tester_model != 4 ||
      expected_account_currency != "USD" ||
      expected_account_margin_mode != (int)ACCOUNT_MARGIN_MODE_RETAIL_HEDGING ||
      expected_account_leverage != 100 ||
      !QM_FTMOEC_SafeContractPath(execution_manifest_path) ||
      !QM_FTMOEC_IsSha256(execution_manifest_sha256) ||
      !QM_FTMOEC_SafeContractPath(prague_proof_path) ||
      !QM_FTMOEC_IsSha256(prague_proof_sha256))
      return false;
   string actual_execution_sha256 = "";
   string actual_prague_sha256 = "";
   if(!QM_FTMOEC_CommonFileSha256(execution_manifest_path,
                                  actual_execution_sha256) ||
      !QM_FTMOEC_HashMatches(actual_execution_sha256,
                             execution_manifest_sha256) ||
      !QM_FTMOEC_CommonFileSha256(prague_proof_path,actual_prague_sha256) ||
      !QM_FTMOEC_HashMatches(actual_prague_sha256,prague_proof_sha256))
      return false;
   g_qm_ftmoec_expected_start_msc = expected_start_msc;
   g_qm_ftmoec_expected_end_msc = expected_end_msc;
   g_qm_ftmoec_expected_tester_model = expected_tester_model;
   g_qm_ftmoec_execution_manifest_path = execution_manifest_path;
   g_qm_ftmoec_execution_manifest_sha256 = actual_execution_sha256;
   g_qm_ftmoec_prague_proof_path = prague_proof_path;
   g_qm_ftmoec_prague_proof_sha256 = actual_prague_sha256;
   if(MathAbs(risk_fixed - 1000.0) > 0.0000001 ||
      MathAbs(risk_percent) > 0.0000001)
      return false;
   g_qm_ftmoec_account_currency = AccountInfoString(ACCOUNT_CURRENCY);
   g_qm_ftmoec_account_margin_mode =
      AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(g_qm_ftmoec_account_currency != expected_account_currency ||
      g_qm_ftmoec_account_margin_mode != expected_account_margin_mode)
      return false;

   g_qm_ftmoec_account_leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   if(g_qm_ftmoec_account_leverage != expected_account_leverage)
      return false;
   g_qm_ftmoec_start_msc = g_qm_ftmoec_expected_start_msc;
   g_qm_ftmoec_end_msc = g_qm_ftmoec_expected_end_msc;
   // OnInit has no current-tick guarantee.  Record its explicit clock source
   // for audit only; the first OnTick hook proves the actual market boundary.
   g_qm_ftmoec_init_clock_msc = ((long)TimeCurrent()) * 1000;
   g_qm_ftmoec_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(!QM_FTMOEC_OpenDataFiles())
      return false;
   g_qm_ftmoec_active = true;

   // Identity snapshot distinguishes the tester's initial balance/history from
   // any cashflow created after START, even if both share the same millisecond.
   if(!HistorySelect(0, TimeCurrent()))
      QM_FTMOEC_Fail("PRESTART_HISTORY_SNAPSHOT_FAILED");
   else
     {
      const int pre_deals = HistoryDealsTotal();
      ArrayResize(g_qm_ftmoec_prestart_deals, pre_deals);
      for(int i = 0; i < pre_deals; ++i)
         g_qm_ftmoec_prestart_deals[i] = HistoryDealGetTicket(i);
      const int pre_orders = HistoryOrdersTotal();
      ArrayResize(g_qm_ftmoec_prestart_orders, pre_orders);
      for(int i = 0; i < pre_orders; ++i)
         g_qm_ftmoec_prestart_orders[i] = HistoryOrderGetTicket(i);
     }

   double balance = 0.0;
   double equity = 0.0;
   double swaps = 0.0;
   int positions = 0;
   int orders = 0;
   double margin = 0.0;
   double margin_free = 0.0;
   double margin_level = 0.0;
   QM_FTMOEC_AccountState(balance,equity,positions,orders,swaps);
   QM_FTMOEC_MarginState(margin,margin_free,margin_level);
   if(positions != 0 || orders != 0)
      QM_FTMOEC_Fail("NONFLAT_START_STATE");
   QM_FTMOEC_WriteCheckpoint("START",g_qm_ftmoec_start_msc,
                             QM_FTMOEC_NextSequence(),"[]",balance,equity,
                             positions,orders,QM_FTMOEC_PositionSwapsJson(),
                             margin,margin_free,margin_level);
   return true;
  }

void QM_FTMOEC_OnTester()
  {
   if(g_qm_ftmoec_active)
      g_qm_ftmoec_on_tester_seen = true;
  }

void QM_FTMOEC_Shutdown(const int deinit_reason)
  {
   if(!g_qm_ftmoec_active)
      return;
   if(!g_qm_ftmoec_on_tester_seen)
      QM_FTMOEC_Fail("ONTESTER_COMPLETION_CALLBACK_MISSING");
   if(g_qm_ftmoec_actual_first_tick_msc <= 0 ||
      g_qm_ftmoec_actual_last_tick_msc < g_qm_ftmoec_actual_first_tick_msc ||
      !QM_FTMOEC_TimeWithinContract(g_qm_ftmoec_actual_first_tick_msc) ||
      !QM_FTMOEC_TimeWithinContract(g_qm_ftmoec_actual_last_tick_msc))
      QM_FTMOEC_Fail("TESTER_TICK_COVERAGE_OUTSIDE_CONTRACT_WINDOW");
   if(g_qm_ftmoec_actual_last_tick_msc > 0)
      QM_FTMOEC_ObservePositionSwaps(g_qm_ftmoec_actual_last_tick_msc);

   double balance = 0.0;
   double equity = 0.0;
   double swaps = 0.0;
   int positions = 0;
   int orders = 0;
   double margin = 0.0;
   double margin_free = 0.0;
   double margin_level = 0.0;
   QM_FTMOEC_AccountState(balance,equity,positions,orders,swaps);
   QM_FTMOEC_MarginState(margin,margin_free,margin_level);
   if(positions != 0 || orders != 0)
      QM_FTMOEC_Fail("OPEN_EXPOSURE_OR_PENDING_ORDER_AT_END");

   if(!HistorySelect((datetime)(g_qm_ftmoec_start_msc / 1000),
                     (datetime)(g_qm_ftmoec_end_msc / 1000 + 1)))
      QM_FTMOEC_Fail("HISTORY_SELECT_FAILED");
   else
     {
      g_qm_ftmoec_history_select_complete = true;
      QM_FTMOEC_WriteHistoryDeals();
      QM_FTMOEC_WriteHistoryOrders();
      QM_FTMOEC_ReconcileAndWriteSltpModifications();
     }
   QM_FTMOEC_WriteCheckpoint("END",g_qm_ftmoec_end_msc,
                             QM_FTMOEC_NextSequence(),"[]",
                             balance,equity,positions,orders,
                             QM_FTMOEC_PositionSwapsJson(),margin,margin_free,
                             margin_level);
   if(!QM_FTMOEC_IsCentExact(balance) ||
      !QM_FTMOEC_IsCentExact(equity) ||
      MathAbs(balance - equity) > 0.0000001)
      QM_FTMOEC_Fail("END_ACCOUNT_MONEY_NOT_FLAT_OR_CENT_EXACT");
   // A COMPLETE run must contain actual trading history.  Account events and
   // position modifications may legitimately be empty (for example, an
   // intraday sleeve with no swap and no accepted trailing modification).
   if(g_qm_ftmoec_order_rows <= 0 || g_qm_ftmoec_deal_rows <= 0 ||
      g_qm_ftmoec_checkpoint_rows < 3)
      QM_FTMOEC_Fail("TRADING_HISTORY_EMPTY_OR_INCOMPLETE");

   QM_FTMOEC_CloseDataFiles();
   string order_sha256 = "";
   string deal_sha256 = "";
   string account_sha256 = "";
   string checkpoint_sha256 = "";
   string modification_sha256 = "";
   if(!QM_FTMOEC_CommonFileSha256(g_qm_ftmoec_order_path, order_sha256) ||
      !QM_FTMOEC_CommonFileSha256(g_qm_ftmoec_deal_path, deal_sha256) ||
      !QM_FTMOEC_CommonFileSha256(g_qm_ftmoec_account_path, account_sha256) ||
      !QM_FTMOEC_CommonFileSha256(g_qm_ftmoec_checkpoint_path,
                                  checkpoint_sha256) ||
      !QM_FTMOEC_CommonFileSha256(g_qm_ftmoec_modification_path,
                                  modification_sha256))
      QM_FTMOEC_Fail("DATA_ARTIFACT_SHA256_FAILED");
   g_qm_ftmoec_complete = (ArraySize(g_qm_ftmoec_failures) == 0);
   if(g_qm_ftmoec_complete)
     {
      if(!QM_FTMOEC_WriteTerminalStatus(true,deinit_reason,order_sha256,
                                        deal_sha256,account_sha256,
                                        checkpoint_sha256,
                                        modification_sha256))
        {
         g_qm_ftmoec_complete = false;
         QM_FTMOEC_Fail("COMPLETE_RECEIPT_PUBLISH_FAILED");
         QM_FTMOEC_WriteTerminalStatus(false,deinit_reason,order_sha256,
                                       deal_sha256,account_sha256,
                                       checkpoint_sha256,
                                       modification_sha256);
        }
     }
   else
     {
      QM_FTMOEC_WriteTerminalStatus(false,deinit_reason,order_sha256,deal_sha256,
                                    account_sha256,checkpoint_sha256,
                                    modification_sha256);
     }
   g_qm_ftmoec_active = false;
  }

#endif // QM_MOD_FTMO_STANDALONE_EVENT_COMPLETE_MQH
