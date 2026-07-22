#property strict
#property version   "5.0"
#property description "QM5_20038 session-anchored VWAP two-sigma reversion"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20038_vwap2s-revert, G0 APPROVED 2026-07-22.
// OOS entry is impossible unless a frozen, hash-verified DEV side proof and
// official cash-session calendar both validate for the chart symbol.

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
input int    qm_ea_id                   = 20038;
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
input string strategy_variant_id        = "VWAP2S_REVERT_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input double strategy_max_cost_r        = 0.10;
input double strategy_round_turn_commission_usd_per_lot = 0.0;
input string strategy_cash_calendar_file = "QM5_20038_us_cash_calendar.csv";
input string strategy_cash_calendar_sha256 = "";
input string strategy_calendar_valid_through = "2025.12.31";
input string strategy_tzdb_version      = "";
input string strategy_dev_guard_file    = "QM5_20038_vwap2s_dev_guard.csv";
input string strategy_dev_guard_sha256  = "";
input string strategy_expected_dev_code_sha256 = "";
input string strategy_expected_dev_inputs_sha256 = "";
input string strategy_expected_dev_data_sha256 = "";

int      g_cash_date_key[];
datetime g_cash_open_utc[];
datetime g_cash_close_utc[];
bool     g_dependencies_attempted = false;
bool     g_calendar_ready = false;
bool     g_guard_artifact_ready = false;
bool     g_guard_long_pass = false;
bool     g_guard_short_pass = false;

int      g_state_session_key = 0;
int      g_state_calendar_index = -1;
datetime g_state_through_utc = 0;
double   g_sum_volume = 0.0;
double   g_sum_price_volume = 0.0;
double   g_sum_price2_volume = 0.0;
double   g_session_vwap = 0.0;
double   g_session_sigma = 0.0;
double   g_slope_changes[];
bool     g_estimator_valid = true;
bool     g_long_attempted = false;
bool     g_short_attempted = false;

int      g_pending_side = 0;
datetime g_pending_entry_utc = 0;
double   g_pending_vwap = 0.0;
double   g_pending_sigma = 0.0;
datetime g_active_close_broker = 0;

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

bool Strategy_ParseBoolean(const string value, bool &parsed)
  {
   if(value == "1" || value == "true" || value == "TRUE")
     {
      parsed = true;
      return true;
     }
   if(value == "0" || value == "false" || value == "FALSE")
     {
      parsed = false;
      return true;
     }
   return false;
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

datetime Strategy_NewYorkLocal(const datetime utc)
  {
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 60 * 60 : 5 * 60 * 60);
  }

bool Strategy_NewYorkOpenMatches(const datetime utc, const int date_key)
  {
   const datetime local = Strategy_NewYorkLocal(utc);
   MqlDateTime parts;
   if(!TimeToStruct(local, parts))
      return false;
   return (Strategy_DateKey(local) == date_key && parts.hour == 9 &&
           parts.min == 30 && parts.sec == 0);
  }

bool Strategy_ValidNewYorkClose(const datetime utc,
                                const int date_key,
                                int &close_minutes)
  {
   close_minutes = 0;
   const datetime local = Strategy_NewYorkLocal(utc);
   MqlDateTime parts;
   if(!TimeToStruct(local, parts) || Strategy_DateKey(local) != date_key || parts.sec != 0)
      return false;
   close_minutes = parts.hour * 60 + parts.min;
   return (close_minutes > 9 * 60 + 30 && close_minutes <= 16 * 60);
  }

bool Strategy_ValidCashCalendarSource(const string url)
  {
   if(StringFind(url, "https") != 0 || StringFind(url, "://") <= 0)
      return false;
   return (StringFind(url, "nyse.com") > 0 || StringFind(url, "nasdaqtrader.com") > 0);
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

bool Strategy_AppendCashSession(const int date_key,
                                const datetime open_utc,
                                const datetime close_utc)
  {
   const int n = ArraySize(g_cash_date_key);
   if(ArrayResize(g_cash_date_key, n + 1) != n + 1 ||
      ArrayResize(g_cash_open_utc, n + 1) != n + 1 ||
      ArrayResize(g_cash_close_utc, n + 1) != n + 1)
      return false;
   g_cash_date_key[n] = date_key;
   g_cash_open_utc[n] = open_utc;
   g_cash_close_utc[n] = close_utc;
   return true;
  }

bool Strategy_LoadCashCalendar()
  {
   ArrayResize(g_cash_date_key, 0);
   ArrayResize(g_cash_open_utc, 0);
   ArrayResize(g_cash_close_utc, 0);
   if(strategy_variant_id != "VWAP2S_REVERT_BASELINE" ||
      strategy_signal_tf != PERIOD_M5 || strategy_max_cost_r != 0.10 ||
      Strategy_ParseDateKey(strategy_calendar_valid_through) != 20251231 ||
      StringLen(strategy_tzdb_version) == 0 ||
      !Strategy_IsSha256(strategy_cash_calendar_sha256))
      return false;

   string actual_hash = "";
   if(!Strategy_CommonFileSha256(strategy_cash_calendar_file, actual_hash) ||
      Strategy_Upper(actual_hash) != Strategy_Upper(strategy_cash_calendar_sha256))
      return false;

   const int handle = FileOpen(strategy_cash_calendar_file,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   int rows = 0;
   int previous_date_key = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string date_text = Strategy_Trimmed(FileReadString(handle));
      const string open_text = Strategy_Trimmed(FileReadString(handle));
      const string close_text = Strategy_Trimmed(FileReadString(handle));
      const string valid_through_text = Strategy_Trimmed(FileReadString(handle));
      const string source_url = Strategy_Trimmed(FileReadString(handle));
      string retrieved_date = Strategy_Trimmed(FileReadString(handle));
      const string source_sha256 = Strategy_Trimmed(FileReadString(handle));
      const string tzdb_version = Strategy_Trimmed(FileReadString(handle));

      if(rows == 0 && date_text == "ny_date" && open_text == "open_utc")
         continue;
      if(date_text == "" && open_text == "" && close_text == "")
         continue;

      const int date_key = Strategy_ParseDateKey(date_text);
      const datetime open_utc = Strategy_ParseUtcTimestamp(open_text);
      const datetime close_utc = Strategy_ParseUtcTimestamp(close_text);
      int close_minutes = 0;
      StringReplace(retrieved_date, "-", ".");
      if(date_key <= 0 || date_key <= previous_date_key || open_utc <= 0 || close_utc <= open_utc ||
         !Strategy_NewYorkOpenMatches(open_utc, date_key) ||
         !Strategy_ValidNewYorkClose(close_utc, date_key, close_minutes) ||
         close_utc - open_utc > 390 * 60 ||
         Strategy_ParseDateKey(valid_through_text) != 20251231 ||
         !Strategy_ValidCashCalendarSource(source_url) || StringToTime(retrieved_date) <= 0 ||
         !Strategy_IsSha256(source_sha256) || tzdb_version != strategy_tzdb_version ||
         !Strategy_AppendCashSession(date_key, open_utc, close_utc))
        {
         valid = false;
         break;
        }
      previous_date_key = date_key;
      ++rows;
     }
   FileClose(handle);
   return (valid && rows > 0 && g_cash_date_key[0] / 10000 <= 2018 &&
           g_cash_date_key[rows - 1] / 10000 >= 2025);
  }

int Strategy_FindCashSession(const int date_key)
  {
   int lo = 0;
   int hi = ArraySize(g_cash_date_key);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_cash_date_key[mid] < date_key)
         lo = mid + 1;
      else
         hi = mid;
     }
   if(lo < ArraySize(g_cash_date_key) && g_cash_date_key[lo] == date_key)
      return lo;
   return -1;
  }

bool Strategy_LoadDevGuardArtifact()
  {
   g_guard_long_pass = false;
   g_guard_short_pass = false;
   if(!Strategy_IsSha256(strategy_dev_guard_sha256) ||
      !Strategy_IsSha256(strategy_expected_dev_code_sha256) ||
      !Strategy_IsSha256(strategy_expected_dev_inputs_sha256) ||
      !Strategy_IsSha256(strategy_expected_dev_data_sha256))
      return false;

   string actual_hash = "";
   if(!Strategy_CommonFileSha256(strategy_dev_guard_file, actual_hash) ||
      Strategy_Upper(actual_hash) != Strategy_Upper(strategy_dev_guard_sha256))
      return false;

   const int handle = FileOpen(strategy_dev_guard_file,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   bool long_seen = false;
   bool short_seen = false;
   bool valid = true;
   int rows = 0;
   while(!FileIsEnding(handle))
     {
      const string symbol = Strategy_Trimmed(FileReadString(handle));
      const string side = Strategy_Upper(Strategy_Trimmed(FileReadString(handle)));
      const string revert_text = Strategy_Trimmed(FileReadString(handle));
      const string fail_text = Strategy_Trimmed(FileReadString(handle));
      const string expectancy_text = Strategy_Trimmed(FileReadString(handle));
      const string dev_start = Strategy_Trimmed(FileReadString(handle));
      const string dev_end = Strategy_Trimmed(FileReadString(handle));
      const string variant_id = Strategy_Trimmed(FileReadString(handle));
      const string code_sha256 = Strategy_Trimmed(FileReadString(handle));
      const string inputs_sha256 = Strategy_Trimmed(FileReadString(handle));
      const string data_sha256 = Strategy_Trimmed(FileReadString(handle));
      const string valid_through = Strategy_Trimmed(FileReadString(handle));
      const string frozen_text = Strategy_Trimmed(FileReadString(handle));

      if(rows == 0 && symbol == "symbol" && side == "SIDE")
         continue;
      if(symbol == "" && side == "")
         continue;
      ++rows;
      if(symbol != _Symbol)
         continue;

      const long revert_count = StringToInteger(revert_text);
      const long fail_count = StringToInteger(fail_text);
      const double net_expectancy = StringToDouble(expectancy_text);
      bool frozen_before_oos = false;
      const bool row_valid = ((side == "LONG" && !long_seen) ||
                              (side == "SHORT" && !short_seen)) &&
                             revert_count >= 0 && fail_count >= 0 &&
                             Strategy_ParseDateKey(dev_start) == 20180101 &&
                             Strategy_ParseDateKey(dev_end) == 20231231 &&
                             variant_id == "VWAP2S_REVERT_BASELINE" &&
                             Strategy_Upper(code_sha256) == Strategy_Upper(strategy_expected_dev_code_sha256) &&
                             Strategy_Upper(inputs_sha256) == Strategy_Upper(strategy_expected_dev_inputs_sha256) &&
                             Strategy_Upper(data_sha256) == Strategy_Upper(strategy_expected_dev_data_sha256) &&
                             Strategy_ParseDateKey(valid_through) == 20251231 &&
                             Strategy_ParseBoolean(frozen_text, frozen_before_oos) && frozen_before_oos;
      if(!row_valid)
        {
         valid = false;
         break;
        }

      const bool side_pass = (revert_count > fail_count && net_expectancy > 0.0);
      if(side == "LONG")
        {
         long_seen = true;
         g_guard_long_pass = side_pass;
        }
      else
        {
         short_seen = true;
         g_guard_short_pass = side_pass;
        }
     }
   FileClose(handle);
   return (valid && rows > 0 && long_seen && short_seen);
  }

bool Strategy_EnsureDependencies()
  {
   if(g_dependencies_attempted)
      return (g_calendar_ready && g_guard_artifact_ready);
   g_dependencies_attempted = true;
   g_calendar_ready = Strategy_LoadCashCalendar();
   g_guard_artifact_ready = Strategy_LoadDevGuardArtifact();
   if(!g_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"cash_calendar\":\"%s\",\"tzdb_version\":\"%s\"}",
                               strategy_cash_calendar_file, strategy_tzdb_version));
   if(!g_guard_artifact_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"dev_guard\":\"%s\",\"symbol\":\"%s\"}",
                               strategy_dev_guard_file, _Symbol));
   return (g_calendar_ready && g_guard_artifact_ready);
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "SP500.DWX" || symbol == "XAUUSD.DWX");
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

void Strategy_RecoverSessionAttempts(const int calendar_index)
  {
   g_long_attempted = false;
   g_short_attempted = false;
   const datetime from_broker = QM_UTCToBroker(g_cash_open_utc[calendar_index]);
   if(from_broker <= 0 || !HistorySelect(from_broker, TimeCurrent()))
     {
      g_long_attempted = true;
      g_short_attempted = true;
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
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(deal_type == DEAL_TYPE_BUY)
         g_long_attempted = true;
      else if(deal_type == DEAL_TYPE_SELL)
         g_short_attempted = true;
     }

   for(int i = 0; i < HistoryOrdersTotal(); ++i)
     {
      const ulong order = HistoryOrderGetTicket(i);
      if(order == 0 || (int)HistoryOrderGetInteger(order, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(order, ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(order, ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY)
         g_long_attempted = true;
      else if(order_type == ORDER_TYPE_SELL)
         g_short_attempted = true;
     }
  }

void Strategy_ResetSessionState(const int calendar_index)
  {
   g_state_session_key = g_cash_date_key[calendar_index];
   g_state_calendar_index = calendar_index;
   g_state_through_utc = 0;
   g_sum_volume = 0.0;
   g_sum_price_volume = 0.0;
   g_sum_price2_volume = 0.0;
   g_session_vwap = 0.0;
   g_session_sigma = 0.0;
   ArrayResize(g_slope_changes, 0);
   g_estimator_valid = true;
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   g_pending_vwap = 0.0;
   g_pending_sigma = 0.0;
   Strategy_RecoverSessionAttempts(calendar_index);
  }

double Strategy_PriorSlopeMedian()
  {
   const int n = ArraySize(g_slope_changes);
   if(n <= 0)
      return 0.0;
   double sorted[];
   if(ArrayResize(sorted, n) != n)
      return 0.0;
   for(int i = 0; i < n; ++i)
      sorted[i] = g_slope_changes[i];
   ArraySort(sorted);
   if((n % 2) == 1)
      return sorted[n / 2];
   return 0.5 * (sorted[n / 2 - 1] + sorted[n / 2]);
  }

bool Strategy_AppendSlopeChange(const double slope_abs)
  {
   const int n = ArraySize(g_slope_changes);
   if(ArrayResize(g_slope_changes, n + 1) != n + 1)
      return false;
   g_slope_changes[n] = slope_abs;
   return true;
  }

bool Strategy_ProcessClosedBar(const MqlRates &bar,
                               const datetime bar_utc,
                               const datetime next_open_utc,
                               const bool allow_signal)
  {
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   g_pending_vwap = 0.0;
   g_pending_sigma = 0.0;
   if(!g_estimator_valid || bar.tick_volume <= 0 || bar.high <= 0.0 ||
      bar.low <= 0.0 || bar.close <= 0.0 || bar.high < bar.low)
     {
      g_estimator_valid = false;
      return false;
     }

   const double typical_price = (bar.high + bar.low + bar.close) / 3.0;
   const double volume = (double)bar.tick_volume;
   const double previous_vwap = g_session_vwap;
   g_sum_volume += volume;
   g_sum_price_volume += volume * typical_price;
   g_sum_price2_volume += volume * typical_price * typical_price;
   if(g_sum_volume <= 0.0)
     {
      g_estimator_valid = false;
      return false;
     }

   g_session_vwap = g_sum_price_volume / g_sum_volume;
   double variance = g_sum_price2_volume / g_sum_volume - g_session_vwap * g_session_vwap;
   if(variance < 0.0 && variance > -1.0e-10)
      variance = 0.0;
   g_session_sigma = (variance > 0.0) ? MathSqrt(variance) : 0.0;
   if(!MathIsValidNumber(g_session_vwap) || !MathIsValidNumber(g_session_sigma))
     {
      g_estimator_valid = false;
      return false;
     }

   bool shallow_slope = false;
   double slope_abs = 0.0;
   if(previous_vwap > 0.0)
     {
      slope_abs = MathAbs(g_session_vwap - previous_vwap);
      const double slope_ref = Strategy_PriorSlopeMedian();
      shallow_slope = (ArraySize(g_slope_changes) > 0 && slope_abs <= slope_ref);
      if(!Strategy_AppendSlopeChange(slope_abs))
        {
         g_estimator_valid = false;
         return false;
        }
     }

   g_state_through_utc = bar_utc;
   if(!allow_signal || !shallow_slope || g_session_sigma <= 0.0 ||
      next_open_utc >= g_cash_close_utc[g_state_calendar_index])
      return true;

   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return true;

   const double lower_band = g_session_vwap - 2.0 * g_session_sigma;
   const double upper_band = g_session_vwap + 2.0 * g_session_sigma;
   const bool long_tag = (bar.low <= lower_band);
   const bool short_tag = (bar.high >= upper_band);
   if(long_tag == short_tag)
      return true;

   if(long_tag && g_guard_long_pass && !g_long_attempted)
      g_pending_side = 1;
   else if(short_tag && g_guard_short_pass && !g_short_attempted)
      g_pending_side = -1;
   if(g_pending_side != 0)
     {
      g_pending_entry_utc = next_open_utc;
      g_pending_vwap = g_session_vwap;
      g_pending_sigma = g_session_sigma;
     }
   return true;
  }

bool Strategy_RebuildSessionState(const int calendar_index,
                                  const datetime current_open_utc)
  {
   Strategy_ResetSessionState(calendar_index);
   const datetime start_broker = QM_UTCToBroker(g_cash_open_utc[calendar_index]);
   const datetime stop_broker = QM_UTCToBroker(current_open_utc) - 1;
   if(start_broker <= 0 || stop_broker < start_broker)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol,
                                strategy_signal_tf,
                                start_broker,
                                stop_broker,
                                rates); // perf-allowed: bounded one-time session rebuild behind QM_IsNewBar.
   if(copied <= 0 || copied > 78)
      return false;

   datetime previous_utc = 0;
   int processed = 0;
   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      if(bar_utc < g_cash_open_utc[calendar_index] ||
         bar_utc >= g_cash_close_utc[calendar_index] || bar_utc >= current_open_utc)
         continue;
      if(previous_utc > 0 && bar_utc != previous_utc + 5 * 60)
         return false;
      const bool is_latest = (bar_utc + 5 * 60 == current_open_utc);
      if(!Strategy_ProcessClosedBar(rates[i], bar_utc, current_open_utc, is_latest))
         return false;
      previous_utc = bar_utc;
      ++processed;
     }
   return (processed > 0 && g_state_through_utc + 5 * 60 == current_open_utc);
  }

bool Strategy_AdvanceStateOnNewBar()
  {
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   if(!g_calendar_ready || !g_guard_artifact_ready ||
      !Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf)
      return false;

   MqlRates current_bar;
   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 1, closed_bar))
      return false;
   const datetime current_open_utc = QM_BrokerToUTC(current_bar.time);
   const datetime closed_bar_utc = QM_BrokerToUTC(closed_bar.time);
   const int date_key = Strategy_DateKey(Strategy_NewYorkLocal(closed_bar_utc));
   const int calendar_index = Strategy_FindCashSession(date_key);
   if(calendar_index < 0 || closed_bar_utc < g_cash_open_utc[calendar_index] ||
      closed_bar_utc >= g_cash_close_utc[calendar_index])
      return false;

   if(g_state_session_key != date_key || g_state_calendar_index != calendar_index ||
      g_state_through_utc == 0 || g_state_through_utc + 5 * 60 != closed_bar_utc)
      return Strategy_RebuildSessionState(calendar_index, current_open_utc);

   return Strategy_ProcessClosedBar(closed_bar,
                                    closed_bar_utc,
                                    current_open_utc,
                                    current_open_utc < g_cash_close_utc[calendar_index]);
  }

bool Strategy_CostAndVolumeAllow(const double entry_price,
                                 const double stop_price,
                                 const double target_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" || RISK_FIXED != 1000.0 ||
      RISK_PERCENT != 0.0 || point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid || entry_price <= 0.0 || stop_price <= 0.0 ||
      target_price <= 0.0 || strategy_round_turn_commission_usd_per_lot <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   const double spread_per_lot = ((ask - bid) / tick_size) * tick_value;
   if(risk_per_lot <= 0.0 || target_distance <= 0.0 ||
      (strategy_round_turn_commission_usd_per_lot + spread_per_lot) / risk_per_lot > strategy_max_cost_r)
      return false;

   const double sl_points = stop_distance / point;
   const double tp_points = target_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || tp_points <= 0.0 ||
      sl_points < (double)stop_level || tp_points < (double)stop_level)
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
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return false;
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      strategy_signal_tf != PERIOD_M5)
      return true;
   return !Strategy_EnsureDependencies();
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_pending_side == 0 || g_pending_entry_utc <= 0 ||
      g_pending_vwap <= 0.0 || g_pending_sigma <= 0.0 ||
      g_state_calendar_index < 0 ||
      g_pending_entry_utc >= g_cash_close_utc[g_state_calendar_index])
      return false;

   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      QM_BrokerToUTC(current_bar.time) != g_pending_entry_utc)
      return false;
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return false;

   const bool is_long = (g_pending_side > 0);
   if((is_long && g_long_attempted) || (!is_long && g_short_attempted))
      return false;
   if(is_long)
      g_long_attempted = true;
   else
      g_short_attempted = true;

   const double frozen_vwap = QM_StopRulesNormalizePrice(_Symbol, g_pending_vwap);
   const double frozen_stop = QM_StopRulesNormalizePrice(_Symbol,
                                                          is_long
                                                          ? g_pending_vwap - 3.0 * g_pending_sigma
                                                          : g_pending_vwap + 3.0 * g_pending_sigma);
   g_pending_side = 0;
   g_pending_entry_utc = 0;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double entry_price = is_long ? ask : bid;
   if(frozen_vwap <= 0.0 || frozen_stop <= 0.0 ||
      (is_long && !(frozen_stop < entry_price && entry_price < frozen_vwap)) ||
      (!is_long && !(frozen_vwap < entry_price && entry_price < frozen_stop)) ||
      !Strategy_CostAndVolumeAllow(entry_price, frozen_stop, frozen_vwap))
      return false;

   req.type = is_long ? QM_BUY : QM_SELL;
   req.sl = frozen_stop;
   req.tp = frozen_vwap;
   req.reason = is_long ? "VWAP2S_REVERT_LONG" : "VWAP2S_REVERT_SHORT";
   g_active_close_broker = QM_UTCToBroker(g_cash_close_utc[g_state_calendar_index]);
   return (g_active_close_broker > 0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      g_active_close_broker = 0;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      return false;
   if(g_active_close_broker <= 0)
     {
      if(!g_calendar_ready)
         return true;
      const datetime open_utc = QM_BrokerToUTC(open_time);
      const int date_key = Strategy_DateKey(Strategy_NewYorkLocal(open_utc));
      const int calendar_index = Strategy_FindCashSession(date_key);
      if(calendar_index < 0)
         return true;
      g_active_close_broker = QM_UTCToBroker(g_cash_close_utc[calendar_index]);
     }
   return (g_active_close_broker > 0 && TimeCurrent() >= g_active_close_broker);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The approved baseline retains the framework default news pause.
   return false;
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

   // Intraday cache: consume the M5 edge once, advance the estimator from the
   // single newly closed bar, then let news gate only the pending entry.
   const bool strategy_new_bar = QM_IsNewBar();
   if(strategy_new_bar)
      Strategy_AdvanceStateOnNewBar();

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

   if(!strategy_new_bar)
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
