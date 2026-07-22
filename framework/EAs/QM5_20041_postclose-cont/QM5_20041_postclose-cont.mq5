#property strict
#property version   "5.0"
#property description "QM5_20041 cash-session post-close continuation"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20041_postclose-cont, G0 APPROVED 2026-07-22.
// Exchange clocks, DST, daily breaks, rollover and financing boundaries are
// accepted only from one hash-pinned governed schedule; no numeric value is
// invented in the EA.

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20041;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_variant_id        = "POSTCLOSE_CONT_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M15;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 1.0;
input int    strategy_hold_minutes      = 240;
input int    strategy_safety_buffer_minutes = 15;
input double strategy_min_stop_to_friction = 4.0;
input double strategy_max_cost_r        = 0.10;
input double strategy_round_turn_commission_usd_per_lot = 0.0;
input string strategy_schedule_file     = "QM5_20041_exchange_financing_schedule.csv";
input string strategy_schedule_sha256   = "";
input string strategy_schedule_version  = "";
input string strategy_calendar_valid_through = "2025.12.31";
input string strategy_tzdb_version      = "";

int      g_session_date_key[];
datetime g_cash_open_utc[];
datetime g_cash_close_utc[];
datetime g_next_break_utc[];
datetime g_rollover_utc[];
datetime g_financing_utc[];
datetime g_local_day_end_utc[];
string   g_exchange_source_url[];
string   g_broker_source_url[];

bool     g_dependencies_attempted = false;
bool     g_schedule_ready = false;
int      g_pending_session_index = -1;
int      g_pending_side = 0;
datetime g_pending_entry_bar_utc = 0;
ulong    g_pending_entry_tick_msc = 0;
datetime g_pending_exit_utc = 0;
double   g_pending_atr = 0.0;
bool     g_session_attempted = false;
datetime g_active_exit_broker = 0;

string Strategy_Trimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

string Strategy_Upper(string value)
  {
   StringToUpper(value);
   return value;
  }

bool Strategy_IsSha256(const string value)
  {
   if(StringLen(value) != 64)
      return false;
   const string hex = "0123456789abcdefABCDEF";
   for(int i = 0; i < 64; ++i)
     {
      if(StringFind(hex, StringSubstr(value, i, 1)) < 0)
         return false;
     }
   return true;
  }

datetime Strategy_ParseUtcTimestamp(string value)
  {
   value = Strategy_Trimmed(value);
   const int n = StringLen(value);
   if(n < 2 || StringSubstr(value, n - 1, 1) != "Z")
      return 0;
   value = StringSubstr(value, 0, n - 1);
   StringReplace(value, "-", ".");
   StringReplace(value, "T", " ");
   return StringToTime(value);
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_ParseDateKey(string value)
  {
   value = Strategy_Trimmed(value);
   StringReplace(value, "-", ".");
   return Strategy_DateKey(StringToTime(value + " 00:00"));
  }

bool Strategy_ValidExchangeSource(const string symbol, const string url)
  {
   if(StringFind(url, "https") != 0 || StringFind(url, "://") <= 0)
      return false;
   if(symbol == "GDAXI.DWX")
      return (StringFind(url, "xetra.com") > 0 || StringFind(url, "deutsche-boerse.com") > 0);
   if(symbol == "UK100.DWX")
      return (StringFind(url, "londonstockexchange.com") > 0);
   return false;
  }

bool Strategy_ValidBrokerSource(const string url)
  {
   return (StringFind(url, "https") == 0 && StringFind(url, "://") > 0 &&
           StringFind(url, "darwinex.com") > 0);
  }

bool Strategy_CommonFileSha256(const string file_name, string &hash_hex)
  {
   hash_hex = "";
   const int handle = FileOpen(file_name,
                               FILE_READ | FILE_BIN | FILE_SHARE_READ | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;
   const int size = (int)FileSize(handle);
   if(size <= 0)
     {
      FileClose(handle);
      return false;
     }
   uchar bytes[];
   if(ArrayResize(bytes, size) != size || FileReadArray(handle, bytes, 0, size) != size)
     {
      FileClose(handle);
      return false;
     }
   FileClose(handle);
   uchar digest[];
   uchar key[];
   ArrayResize(key, 0);
   const int digest_size = CryptEncode(CRYPT_HASH_SHA256, bytes, key, digest);
   if(digest_size <= 0)
      return false;
   for(int i = 0; i < digest_size; ++i)
      hash_hex += StringFormat("%02X", digest[i]);
   return true;
  }

bool Strategy_AppendSchedule(const int date_key,
                             const datetime cash_open_utc,
                             const datetime cash_close_utc,
                             const datetime next_break_utc,
                             const datetime rollover_utc,
                             const datetime financing_utc,
                             const datetime local_day_end_utc,
                             const string exchange_source_url,
                             const string broker_source_url)
  {
   const int n = ArraySize(g_session_date_key);
   if(ArrayResize(g_session_date_key, n + 1) != n + 1 ||
      ArrayResize(g_cash_open_utc, n + 1) != n + 1 ||
      ArrayResize(g_cash_close_utc, n + 1) != n + 1 ||
      ArrayResize(g_next_break_utc, n + 1) != n + 1 ||
      ArrayResize(g_rollover_utc, n + 1) != n + 1 ||
      ArrayResize(g_financing_utc, n + 1) != n + 1 ||
      ArrayResize(g_local_day_end_utc, n + 1) != n + 1 ||
      ArrayResize(g_exchange_source_url, n + 1) != n + 1 ||
      ArrayResize(g_broker_source_url, n + 1) != n + 1)
      return false;
   g_session_date_key[n] = date_key;
   g_cash_open_utc[n] = cash_open_utc;
   g_cash_close_utc[n] = cash_close_utc;
   g_next_break_utc[n] = next_break_utc;
   g_rollover_utc[n] = rollover_utc;
   g_financing_utc[n] = financing_utc;
   g_local_day_end_utc[n] = local_day_end_utc;
   g_exchange_source_url[n] = exchange_source_url;
   g_broker_source_url[n] = broker_source_url;
   return true;
  }

bool Strategy_LoadSchedule()
  {
   ArrayResize(g_session_date_key, 0);
   ArrayResize(g_cash_open_utc, 0);
   ArrayResize(g_cash_close_utc, 0);
   ArrayResize(g_next_break_utc, 0);
   ArrayResize(g_rollover_utc, 0);
   ArrayResize(g_financing_utc, 0);
   ArrayResize(g_local_day_end_utc, 0);
   ArrayResize(g_exchange_source_url, 0);
   ArrayResize(g_broker_source_url, 0);
   if(strategy_variant_id != "POSTCLOSE_CONT_BASELINE" ||
      strategy_signal_tf != PERIOD_M15 || strategy_atr_period != 14 ||
      strategy_atr_stop_mult != 1.0 || strategy_hold_minutes != 240 ||
      strategy_safety_buffer_minutes != 15 || strategy_min_stop_to_friction != 4.0 ||
      strategy_max_cost_r != 0.10 || StringLen(strategy_schedule_version) == 0 ||
      Strategy_ParseDateKey(strategy_calendar_valid_through) != 20251231 ||
      StringLen(strategy_tzdb_version) == 0 || !Strategy_IsSha256(strategy_schedule_sha256))
      return false;

   string actual_hash = "";
   if(!Strategy_CommonFileSha256(strategy_schedule_file, actual_hash) ||
      Strategy_Upper(actual_hash) != Strategy_Upper(strategy_schedule_sha256))
      return false;
   const int handle = FileOpen(strategy_schedule_file,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   int gdaxi_rows = 0;
   int uk_rows = 0;
   int gdaxi_first = 0;
   int uk_first = 0;
   int gdaxi_last = 0;
   int uk_last = 0;
   int gdaxi_previous = 0;
   int uk_previous = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string symbol = Strategy_Trimmed(FileReadString(handle));
      const string date_text = Strategy_Trimmed(FileReadString(handle));
      const string open_text = Strategy_Trimmed(FileReadString(handle));
      const string close_text = Strategy_Trimmed(FileReadString(handle));
      const string break_text = Strategy_Trimmed(FileReadString(handle));
      const string rollover_text = Strategy_Trimmed(FileReadString(handle));
      const string financing_text = Strategy_Trimmed(FileReadString(handle));
      const string day_end_text = Strategy_Trimmed(FileReadString(handle));
      const string valid_through_text = Strategy_Trimmed(FileReadString(handle));
      const string exchange_source_url = Strategy_Trimmed(FileReadString(handle));
      const string broker_source_url = Strategy_Trimmed(FileReadString(handle));
      string retrieved_date = Strategy_Trimmed(FileReadString(handle));
      const string exchange_source_sha256 = Strategy_Trimmed(FileReadString(handle));
      const string broker_source_sha256 = Strategy_Trimmed(FileReadString(handle));
      const string tzdb_version = Strategy_Trimmed(FileReadString(handle));
      const string schedule_version = Strategy_Trimmed(FileReadString(handle));

      if(symbol == "symbol" && date_text == "local_date")
         continue;
      if(symbol == "" && date_text == "")
         continue;

      const int date_key = Strategy_ParseDateKey(date_text);
      const datetime cash_open_utc = Strategy_ParseUtcTimestamp(open_text);
      const datetime cash_close_utc = Strategy_ParseUtcTimestamp(close_text);
      const datetime next_break_utc = Strategy_ParseUtcTimestamp(break_text);
      const datetime rollover_utc = Strategy_ParseUtcTimestamp(rollover_text);
      const datetime financing_utc = Strategy_ParseUtcTimestamp(financing_text);
      const datetime local_day_end_utc = Strategy_ParseUtcTimestamp(day_end_text);
      const bool routed = (symbol == "GDAXI.DWX" || symbol == "UK100.DWX");
      const int previous_date = (symbol == "GDAXI.DWX") ? gdaxi_previous : uk_previous;
      StringReplace(retrieved_date, "-", ".");
      if(!routed || date_key <= 0 || date_key <= previous_date ||
         cash_open_utc <= 0 || cash_close_utc <= cash_open_utc ||
         cash_close_utc - cash_open_utc > 12 * 60 * 60 ||
         ((long)cash_close_utc % (15 * 60)) != 0 ||
         next_break_utc <= cash_close_utc || rollover_utc <= cash_close_utc ||
         financing_utc <= cash_close_utc || local_day_end_utc <= cash_close_utc ||
         local_day_end_utc - cash_open_utc > 24 * 60 * 60 ||
         Strategy_ParseDateKey(valid_through_text) != 20251231 ||
         !Strategy_ValidExchangeSource(symbol, exchange_source_url) ||
         !Strategy_ValidBrokerSource(broker_source_url) || StringToTime(retrieved_date) <= 0 ||
         !Strategy_IsSha256(exchange_source_sha256) || !Strategy_IsSha256(broker_source_sha256) ||
         tzdb_version != strategy_tzdb_version || schedule_version != strategy_schedule_version)
        {
         valid = false;
         break;
        }

      if(symbol == "GDAXI.DWX")
        {
         if(gdaxi_rows == 0)
            gdaxi_first = date_key;
         gdaxi_last = date_key;
         gdaxi_previous = date_key;
         ++gdaxi_rows;
        }
      else
        {
         if(uk_rows == 0)
            uk_first = date_key;
         uk_last = date_key;
         uk_previous = date_key;
         ++uk_rows;
        }
      if(symbol == _Symbol &&
         !Strategy_AppendSchedule(date_key, cash_open_utc, cash_close_utc,
                                  next_break_utc, rollover_utc, financing_utc,
                                  local_day_end_utc, exchange_source_url,
                                  broker_source_url))
        {
         valid = false;
         break;
        }
     }
   FileClose(handle);
   return (valid && gdaxi_rows > 0 && uk_rows > 0 && ArraySize(g_session_date_key) > 0 &&
           gdaxi_first / 10000 <= 2018 && uk_first / 10000 <= 2018 &&
           gdaxi_last / 10000 >= 2025 && uk_last / 10000 >= 2025);
  }

bool Strategy_EnsureDependencies()
  {
   if(g_dependencies_attempted)
      return g_schedule_ready;
   g_dependencies_attempted = true;
   g_schedule_ready = Strategy_LoadSchedule();
   if(!g_schedule_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"schedule\":\"%s\",\"version\":\"%s\",\"tzdb\":\"%s\",\"symbol\":\"%s\"}",
                               strategy_schedule_file, strategy_schedule_version,
                               strategy_tzdb_version, _Symbol));
   return g_schedule_ready;
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "GDAXI.DWX" || symbol == "UK100.DWX");
  }

int Strategy_FindObservationSession(const datetime observation_bar_utc)
  {
   int lo = 0;
   int hi = ArraySize(g_cash_close_utc);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_cash_close_utc[mid] < observation_bar_utc)
         lo = mid + 1;
      else
         hi = mid;
     }
   if(lo < ArraySize(g_cash_close_utc) && g_cash_close_utc[lo] == observation_bar_utc)
      return lo;
   return -1;
  }

int Strategy_FindEntrySession(const datetime entry_utc)
  {
   int lo = 0;
   int hi = ArraySize(g_cash_close_utc);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_cash_close_utc[mid] <= entry_utc)
         lo = mid + 1;
      else
         hi = mid;
     }
   const int index = lo - 1;
   if(index >= 0 && entry_utc < g_local_day_end_utc[index])
      return index;
   return -1;
  }

bool Strategy_FindOurPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void Strategy_RecoverAttempt(const int session_index)
  {
   g_session_attempted = false;
   const datetime from_broker = QM_UTCToBroker(g_cash_close_utc[session_index]);
   if(from_broker <= 0 || !HistorySelect(from_broker, TimeCurrent()))
     {
      g_session_attempted = true;
      return;
     }
   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < HistoryDealsTotal(); ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind == DEAL_ENTRY_IN || entry_kind == DEAL_ENTRY_INOUT)
        {
         g_session_attempted = true;
         return;
        }
     }
  }

bool Strategy_TickMid(const MqlTick &tick, double &mid)
  {
   mid = 0.0;
   if(tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      return false;
   mid = 0.5 * (tick.bid + tick.ask);
   return (mid > 0.0 && MathIsValidNumber(mid));
  }

double Strategy_TickNormalizedPrice(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, MathRound(price / tick_size) * tick_size);
  }

bool Strategy_FirstSessionMid(const int session_index, double &mid)
  {
   mid = 0.0;
   ulong cursor = (ulong)g_cash_open_utc[session_index] * 1000;
   const ulong stop_msc = (ulong)g_cash_close_utc[session_index] * 1000;
   const ulong chunk_width = 5 * 60 * 1000;
   long previous_msc = 0;
   while(cursor <= stop_msc)
     {
      ulong chunk_end = cursor + chunk_width - 1;
      if(chunk_end < cursor || chunk_end > stop_msc)
         chunk_end = stop_msc;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, cursor, chunk_end);
      if(copied < 0)
         return false;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
         if(Strategy_TickMid(ticks[i], mid))
            return true;
        }
      if(chunk_end == stop_msc)
         break;
      cursor = chunk_end + 1;
     }
   return false;
  }

bool Strategy_LastSessionMid(const int session_index, double &mid)
  {
   mid = 0.0;
   const ulong start_msc = (ulong)g_cash_open_utc[session_index] * 1000;
   ulong window_end = (ulong)g_cash_close_utc[session_index] * 1000;
   const ulong chunk_width = 5 * 60 * 1000;
   while(window_end >= start_msc)
     {
      ulong window_start = start_msc;
      if(window_end - start_msc + 1 > chunk_width)
         window_start = window_end - chunk_width + 1;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO,
                                        window_start, window_end);
      if(copied < 0)
         return false;
      long previous_msc = 0;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
        }
      for(int i = copied - 1; i >= 0; --i)
        {
         if(Strategy_TickMid(ticks[i], mid))
            return true;
        }
      if(window_start == start_msc)
         break;
      window_end = window_start - 1;
     }
   return false;
  }

bool Strategy_IsFirstTradableTick(const datetime entry_bar_utc,
                                  const MqlTick &current_tick)
  {
   double current_mid = 0.0;
   if(!Strategy_TickMid(current_tick, current_mid))
      return false;
   ulong cursor = (ulong)entry_bar_utc * 1000;
   const ulong stop_msc = (ulong)current_tick.time_msc;
   if(stop_msc < cursor)
      return false;
   const ulong chunk_width = 60 * 1000;
   while(cursor <= stop_msc)
     {
      ulong chunk_end = cursor + chunk_width - 1;
      if(chunk_end < cursor || chunk_end > stop_msc)
         chunk_end = stop_msc;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, cursor, chunk_end);
      if(copied < 0)
         return false;
      long previous_msc = 0;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
         double mid = 0.0;
         if(Strategy_TickMid(ticks[i], mid))
            return ((ulong)ticks[i].time_msc == (ulong)current_tick.time_msc);
        }
      if(chunk_end == stop_msc)
         break;
      cursor = chunk_end + 1;
     }
   return false;
  }

bool Strategy_BindVerifiedExit(const int session_index,
                               const datetime entry_utc,
                               datetime &exit_utc)
  {
   exit_utc = 0;
   const datetime boundary_utc = (g_next_break_utc[session_index] < g_rollover_utc[session_index])
                                 ? g_next_break_utc[session_index]
                                 : g_rollover_utc[session_index];
   const datetime safety_exit_utc = boundary_utc - strategy_safety_buffer_minutes * 60;
   const datetime scheduled_exit_utc = entry_utc + strategy_hold_minutes * 60;
   exit_utc = (scheduled_exit_utc < safety_exit_utc)
              ? scheduled_exit_utc
              : safety_exit_utc;
   if(entry_utc <= g_cash_close_utc[session_index] || exit_utc <= entry_utc ||
      exit_utc >= g_financing_utc[session_index] ||
      exit_utc >= g_local_day_end_utc[session_index])
     {
      exit_utc = 0;
      return false;
     }
   return true;
  }

bool Strategy_AdvanceStateOnNewBar()
  {
   g_pending_session_index = -1;
   g_pending_side = 0;
   g_pending_entry_bar_utc = 0;
   g_pending_entry_tick_msc = 0;
   g_pending_exit_utc = 0;
   g_pending_atr = 0.0;
   if(!g_schedule_ready || !Strategy_IsRoutedSymbol(_Symbol) ||
      _Period != strategy_signal_tf || strategy_signal_tf != PERIOD_M15 ||
      !SymbolIsSynchronized(_Symbol))
      return false;

   MqlRates current_bar;
   MqlRates observation_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 1, observation_bar))
      return false;
   const datetime entry_bar_utc = QM_BrokerToUTC(current_bar.time);
   const datetime observation_bar_utc = QM_BrokerToUTC(observation_bar.time);
   const int session_index = Strategy_FindObservationSession(observation_bar_utc);
   if(session_index < 0 || entry_bar_utc != g_cash_close_utc[session_index] + 15 * 60 ||
      observation_bar.open <= 0.0 || observation_bar.high <= 0.0 ||
      observation_bar.low <= 0.0 || observation_bar.close <= 0.0)
      return false;

   Strategy_RecoverAttempt(session_index);
   if(g_session_attempted)
      return true;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) ||
      !Strategy_IsFirstTradableTick(entry_bar_utc, tick))
      return true;

   double cash_open_mid = 0.0;
   double cash_close_mid = 0.0;
   if(!Strategy_FirstSessionMid(session_index, cash_open_mid) ||
      !Strategy_LastSessionMid(session_index, cash_close_mid))
      return true;
   cash_open_mid = Strategy_TickNormalizedPrice(cash_open_mid);
   cash_close_mid = Strategy_TickNormalizedPrice(cash_close_mid);
   if(cash_open_mid <= 0.0 || cash_close_mid <= 0.0 || cash_open_mid == cash_close_mid)
      return true;

   const double frozen_atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const datetime entry_tick_utc = (datetime)(tick.time_msc / 1000);
   datetime verified_exit_utc = 0;
   if(frozen_atr <= 0.0 || !MathIsValidNumber(frozen_atr) ||
      !Strategy_BindVerifiedExit(session_index, entry_tick_utc, verified_exit_utc))
      return true;

   g_pending_session_index = session_index;
   g_pending_side = (cash_close_mid > cash_open_mid) ? 1 : -1;
   g_pending_entry_bar_utc = entry_bar_utc;
   g_pending_entry_tick_msc = (ulong)tick.time_msc;
   g_pending_exit_utc = verified_exit_utc;
   g_pending_atr = frozen_atr;
   return true;
  }

bool Strategy_CostAndVolumeAllow(const double entry_price,
                                 const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" || RISK_FIXED != 1000.0 ||
      RISK_PERCENT != 0.0 || point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid || entry_price <= 0.0 || stop_price <= 0.0 ||
      strategy_round_turn_commission_usd_per_lot <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double spread_price = ask - bid;
   const double commission_price = (strategy_round_turn_commission_usd_per_lot / tick_value) * tick_size;
   const double friction_price = spread_price + commission_price;
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   const double spread_per_lot = (spread_price / tick_size) * tick_value;
   if(stop_distance <= 0.0 || friction_price <= 0.0 ||
      stop_distance < strategy_min_stop_to_friction * friction_price ||
      risk_per_lot <= 0.0 ||
      (strategy_round_turn_commission_usd_per_lot + spread_per_lot) / risk_per_lot > strategy_max_cost_r)
      return false;

   const double sl_points = stop_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || sl_points < (double)stop_level)
      return false;

   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      lots < volume_min || lots > volume_max)
      return false;
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   return (MathAbs(aligned - lots) <= volume_step * 1.0e-6);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // TODO: e.g. "only trade London session" or "skip if ADX<20"
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // TODO: build req.type / req.price / req.sl / req.tp / req.reason /
   //       req.symbol_slot / req.expiration_seconds — set ALL fields (the
   //       caller ZeroMemory's req; symbol_slot stays 0 for single-symbol
   //       EAs). Lots are NOT part of QM_EntryRequest: sizing happens inside
   //       QM_Entry via QM_LotsForRisk from req.sl.
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // TODO: e.g.
   //   const int magic = QM_FrameworkMagic();
   //   for(int i = PositionsTotal() - 1; i >= 0; --i) {
   //       const ulong ticket = PositionGetTicket(i);
   //       if(!PositionSelectByTicket(ticket)) continue;
   //       if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
   //       QM_TM_MoveToBreakEven(ticket, /*trigger_pips=*/30, /*buffer=*/2);
   //       QM_TM_TrailATR(ticket, /*atr_period=*/14, /*atr_mult=*/2.0);
   //   }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // TODO: when to close manually (separate from SL/TP and trade management)
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
