#property strict
#property version   "5.0"
#property description "QM5_20044 Prior-cash-close gap HiLo fade"

#include <QM/QM_Common.mqh>

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
input int    qm_ea_id                   = 9999;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;     // live setfiles use 0.5; tester keeps this disabled
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; framework news gate fails closed if older
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
input string strategy_variant_id        = "GAP_HILO_FADE_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M30;
input int    strategy_d1_atr_period     = 20;
input double strategy_gap_atr_min       = 0.25;
input double strategy_gap_atr_max       = 1.25;
input int    strategy_hilo_period       = 10;
input int    strategy_m30_atr_period    = 14;
input double strategy_extreme_atr_tolerance = 0.10;
input double strategy_stop_atr_offset   = 0.25;
input double strategy_stop_atr_min      = 0.75;
input double strategy_stop_atr_max      = 1.50;
input double strategy_min_reward_r      = 1.25;
input int    strategy_cash_open_hour_new_york = 9;
input int    strategy_cash_open_minute_new_york = 30;
input int    strategy_cash_close_hour_new_york = 16;
input int    strategy_cash_close_minute_new_york = 0;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points = 0;

int      g_state_session_date_key = 0;
int      g_attempt_date_key = 0;
int      g_armed_side = 0;
bool     g_session_consumed = false;
double   g_prior_cash_close = 0.0;
double   g_session_high = 0.0;
double   g_session_low = 0.0;

#define STRATEGY_DIAG_SESSION_REJECT  1
#define STRATEGY_DIAG_SESSION_READY   2
#define STRATEGY_DIAG_GAP_STATE       4
#define STRATEGY_DIAG_HILO_PREREQ     8
#define STRATEGY_DIAG_HILO_OUTCOME   16
#define STRATEGY_DIAG_STATE_RUNTIME  32

int      g_diagnostic_date_key = 0;
uint     g_diagnostic_mask = 0;
int      g_diagnostic_candidate_count = 0;
datetime g_diagnostic_last_entry_bar_utc = 0;
double   g_diagnostic_last_candidate_close = 0.0;
double   g_diagnostic_last_prior_high_average = 0.0;
double   g_diagnostic_last_prior_low_average = 0.0;
double   g_diagnostic_last_extreme_distance = 0.0;
double   g_diagnostic_last_extreme_limit = 0.0;

bool     g_pending_signal = false;
int      g_pending_side = 0;
datetime g_pending_entry_bar_utc = 0;
double   g_pending_sl = 0.0;
double   g_pending_tp = 0.0;

void Strategy_LogEntryReject(const int date_key,
                             const datetime entry_bar_utc,
                             const string detail,
                             const string diagnostics = "")
  {
   QM_LogEvent(QM_WARN,
               "ENTRY_REJECTED",
               StringFormat("{\"result\":\"STRATEGY_HOOK_REJECTED\",\"symbol\":\"%s\",\"reason\":\"GAP_HILO_FADE\",\"detail\":\"%s\",\"date_key\":%d,\"entry_bar_utc\":%I64d,\"broker_now\":%I64d%s}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            date_key,
                            (long)entry_bar_utc,
                            (long)TimeCurrent(),
                            diagnostics));
  }

void Strategy_ResetDiagnosticsForDate(const int date_key)
  {
   if(date_key == g_diagnostic_date_key)
      return;
   g_diagnostic_date_key = date_key;
   g_diagnostic_mask = 0;
   g_diagnostic_candidate_count = 0;
   g_diagnostic_last_entry_bar_utc = 0;
   g_diagnostic_last_candidate_close = 0.0;
   g_diagnostic_last_prior_high_average = 0.0;
   g_diagnostic_last_prior_low_average = 0.0;
   g_diagnostic_last_extreme_distance = 0.0;
   g_diagnostic_last_extreme_limit = 0.0;
  }

bool Strategy_ClaimDiagnostic(const int date_key,
                              const uint diagnostic_bit)
  {
   Strategy_ResetDiagnosticsForDate(date_key);
   if((g_diagnostic_mask & diagnostic_bit) != 0)
      return false;
   g_diagnostic_mask |= diagnostic_bit;
   return true;
  }

void Strategy_LogSessionStateReject(const int date_key,
                                    const string detail,
                                    const string diagnostics = "")
  {
   if(!Strategy_ClaimDiagnostic(date_key, STRATEGY_DIAG_SESSION_REJECT))
      return;
   QM_LogEvent(QM_WARN,
               "SESSION_STATE_REJECTED",
               StringFormat("{\"symbol\":\"%s\",\"detail\":\"%s\",\"date_key\":%d%s}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            date_key,
                            diagnostics));
  }

void Strategy_LogRuntimeStateReject(const int date_key,
                                    const string detail,
                                    const datetime current_bar_utc,
                                    const string diagnostics = "")
  {
   if(!Strategy_ClaimDiagnostic(date_key, STRATEGY_DIAG_STATE_RUNTIME))
      return;
   QM_LogEvent(QM_WARN,
               "SESSION_RUNTIME_REJECTED",
               StringFormat("{\"symbol\":\"%s\",\"detail\":\"%s\",\"date_key\":%d,\"current_bar_utc\":%I64d%s}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            date_key,
                            (long)current_bar_utc,
                            diagnostics));
  }

bool     g_m30_have_previous = false;
double   g_m30_previous_close = 0.0;
int      g_m30_tr_count = 0;
double   g_m30_seed_sum = 0.0;
double   g_m30_atr = 0.0;
double   g_recent_high[10];
double   g_recent_low[10];
int      g_recent_count = 0;

bool     g_d1_have_previous = false;
double   g_d1_previous_close = 0.0;
int      g_d1_tr_count = 0;
double   g_d1_seed_sum = 0.0;
double   g_d1_atr = 0.0;
int      g_history_through_date_key = 0;
bool     g_history_state_valid = false;

void Strategy_LogHiloOutcome(const int date_key,
                             const string outcome)
  {
   if(!Strategy_ClaimDiagnostic(date_key, STRATEGY_DIAG_HILO_OUTCOME))
      return;
   QM_LogEvent(QM_INFO,
               "HILO_WINDOW_STATE",
               StringFormat("{\"symbol\":\"%s\",\"outcome\":\"%s\",\"date_key\":%d,\"armed_side\":%d,\"candidate_count\":%d,\"last_entry_bar_utc\":%I64d,\"last_close\":%.8f,\"prior_high_average\":%.8f,\"prior_low_average\":%.8f,\"session_high\":%.8f,\"session_low\":%.8f,\"m30_atr\":%.8f,\"extreme_distance\":%.8f,\"extreme_limit\":%.8f}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(outcome),
                            date_key,
                            g_armed_side,
                            g_diagnostic_candidate_count,
                            (long)g_diagnostic_last_entry_bar_utc,
                            g_diagnostic_last_candidate_close,
                            g_diagnostic_last_prior_high_average,
                            g_diagnostic_last_prior_low_average,
                            g_session_high,
                            g_session_low,
                            g_m30_atr,
                            g_diagnostic_last_extreme_distance,
                            g_diagnostic_last_extreme_limit));
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime Strategy_NewYorkLocal(const datetime utc)
  {
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 60 * 60 : 5 * 60 * 60);
  }

datetime Strategy_NewYorkLocalToUtc(const int date_key,
                                    const int hour,
                                    const int minute)
  {
   if(date_key < 19000101 || hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   parts.hour = hour;
   parts.min = minute;
   datetime utc = StructToTime(parts) + 5 * 60 * 60;
   if(QM_IsUSDSTUTC(utc))
      utc -= 60 * 60;
   return utc;
  }

int Strategy_ShiftDateKey(const int date_key, const int days)
  {
   if(date_key < 19000101)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   return Strategy_DateKey(StructToTime(parts) + days * 24 * 60 * 60);
  }

bool Strategy_IsUtcWeekday(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

bool Strategy_ResolveCashSession(const int date_key,
                                 datetime &open_utc,
                                 datetime &close_utc)
  {
   open_utc = Strategy_NewYorkLocalToUtc(date_key,
                                         strategy_cash_open_hour_new_york,
                                         strategy_cash_open_minute_new_york);
   close_utc = Strategy_NewYorkLocalToUtc(date_key,
                                          strategy_cash_close_hour_new_york,
                                          strategy_cash_close_minute_new_york);
   return (open_utc > 0 && close_utc - open_utc == 390 * 60 &&
           Strategy_IsUtcWeekday(open_utc));
  }

int Strategy_PreviousWeekdayDateKey(const int date_key)
  {
   int candidate = Strategy_ShiftDateKey(date_key, -1);
   for(int days_back = 1; days_back <= 7 && candidate > 0; ++days_back)
     {
      datetime open_utc = 0;
      datetime close_utc = 0;
      if(Strategy_ResolveCashSession(candidate, open_utc, close_utc))
         return candidate;
      candidate = Strategy_ShiftDateKey(candidate, -1);
     }
   return 0;
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "SP500.DWX" || symbol == "WS30.DWX");
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

double Strategy_TickNormalizedPrice(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return NormalizeDouble(MathRound(price / tick_size) * tick_size, digits);
  }

bool Strategy_CopyNormalSession(const int date_key,
                                 MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   datetime open_utc = 0;
   datetime close_utc = 0;
   if(!Strategy_ResolveCashSession(date_key, open_utc, close_utc))
      return false;
   const datetime from_broker = QM_UTCToBroker(open_utc);
   const datetime through_broker = QM_UTCToBroker(close_utc - 1);
   if(from_broker <= 0 || through_broker <= from_broker)
      return false;
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, from_broker, through_broker, rates); // perf-allowed: exact normal cash-session bars, read only during once-per-session state warmup.
   if(copied != 13)
      return false;
   for(int i = 0; i < 13; ++i)
     {
      if(QM_BrokerToUTC(rates[i].time) !=
         open_utc + i * 30 * 60 ||
         rates[i].open <= 0.0 || rates[i].high < rates[i].low ||
         rates[i].low <= 0.0 || rates[i].close <= 0.0)
         return false;
     }
   return true;
  }

double Strategy_TrueRange(const double high,
                          const double low,
                          const double previous_close,
                          const bool have_previous)
  {
   double value = high - low;
   if(have_previous)
     {
      value = MathMax(value, MathAbs(high - previous_close));
      value = MathMax(value, MathAbs(low - previous_close));
     }
   return value;
  }

void Strategy_PushRecent(const MqlRates &rate)
  {
   if(g_recent_count < 10)
     {
      g_recent_high[g_recent_count] = rate.high;
      g_recent_low[g_recent_count] = rate.low;
      ++g_recent_count;
      return;
     }
   for(int i = 0; i < 9; ++i)
     {
      g_recent_high[i] = g_recent_high[i + 1];
      g_recent_low[i] = g_recent_low[i + 1];
     }
   g_recent_high[9] = rate.high;
   g_recent_low[9] = rate.low;
  }

bool Strategy_AdvanceM30State(const MqlRates &rate)
  {
   const double tr = Strategy_TrueRange(rate.high,
                                        rate.low,
                                        g_m30_previous_close,
                                        g_m30_have_previous);
   if(tr <= 0.0)
      return false;
   ++g_m30_tr_count;
   if(g_m30_tr_count <= 14)
     {
      g_m30_seed_sum += tr;
      if(g_m30_tr_count == 14)
         g_m30_atr = g_m30_seed_sum / 14.0;
     }
   else
      g_m30_atr = (g_m30_atr * 13.0 + tr) / 14.0;
   g_m30_previous_close = rate.close;
   g_m30_have_previous = true;
   Strategy_PushRecent(rate);
   return true;
  }

bool Strategy_AdvanceD1State(const double high,
                             const double low,
                             const double close)
  {
   const double tr = Strategy_TrueRange(high,
                                        low,
                                        g_d1_previous_close,
                                        g_d1_have_previous);
   if(tr <= 0.0 || close <= 0.0)
      return false;
   ++g_d1_tr_count;
   if(g_d1_tr_count <= 20)
     {
      g_d1_seed_sum += tr;
      if(g_d1_tr_count == 20)
         g_d1_atr = g_d1_seed_sum / 20.0;
     }
   else
      g_d1_atr = (g_d1_atr * 19.0 + tr) / 20.0;
   g_d1_previous_close = close;
   g_d1_have_previous = true;
   return true;
  }

void Strategy_ResetHistoryState()
  {
   g_m30_have_previous = false;
   g_m30_previous_close = 0.0;
   g_m30_tr_count = 0;
   g_m30_seed_sum = 0.0;
   g_m30_atr = 0.0;
   g_recent_count = 0;
   ArrayInitialize(g_recent_high, 0.0);
   ArrayInitialize(g_recent_low, 0.0);

   g_d1_have_previous = false;
   g_d1_previous_close = 0.0;
   g_d1_tr_count = 0;
   g_d1_seed_sum = 0.0;
   g_d1_atr = 0.0;
  }

bool Strategy_WarmHistoryThrough(const int prior_date_key)
  {
   Strategy_ResetHistoryState();
   g_history_through_date_key = 0;
   g_history_state_valid = false;
   if(prior_date_key < 20180101)
      return false;

   MqlRates rates[];
   int date_key = 20180101;
   while(date_key > 0 && date_key <= prior_date_key)
     {
      // Fixed-session eligibility requires all thirteen M30 bars. A weekday
      // without them is a closure/early close and is not part of the warmup.
      if(Strategy_CopyNormalSession(date_key, rates))
        {
         double session_high = -DBL_MAX;
         double session_low = DBL_MAX;
         for(int i = 0; i < 13; ++i)
           {
            session_high = MathMax(session_high, rates[i].high);
            session_low = MathMin(session_low, rates[i].low);
            if(!Strategy_AdvanceM30State(rates[i]))
               return false;
           }
         if(!Strategy_AdvanceD1State(session_high, session_low, rates[12].close))
            return false;
        }
      const int next_date_key = Strategy_ShiftDateKey(date_key, 1);
      if(next_date_key <= date_key)
         return false;
      date_key = next_date_key;
     }
   g_history_state_valid =
      (g_d1_tr_count >= 20 && g_d1_atr > 0.0 &&
       g_m30_tr_count >= 14 && g_m30_atr > 0.0 &&
        g_recent_count == 10 && g_m30_previous_close > 0.0);
   if(g_history_state_valid)
      g_history_through_date_key = prior_date_key;
   return g_history_state_valid;
  }

double Strategy_RecentHighAverage()
  {
   if(g_recent_count != 10)
      return 0.0;
   double total = 0.0;
   for(int i = 0; i < 10; ++i)
      total += g_recent_high[i];
   return total / 10.0;
  }

double Strategy_RecentLowAverage()
  {
   if(g_recent_count != 10)
      return 0.0;
   double total = 0.0;
   for(int i = 0; i < 10; ++i)
      total += g_recent_low[i];
   return total / 10.0;
  }

bool Strategy_TradeGeometryAndVolumeAllow(const double entry_price,
                                          const double stop_price,
                                          const double target_price,
                                          double &out_lots,
                                          string &out_reject_detail)
  {
   out_lots = 0.0;
   out_reject_detail = "";
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(RISK_FIXED != 1000.0 || RISK_PERCENT != 0.0)
     {
      out_reject_detail = "risk_mode_invalid";
      return false;
     }
   if(point <= 0.0 || tick_size <= 0.0 ||
      entry_price <= 0.0 || stop_price <= 0.0 || target_price <= 0.0)
     {
      out_reject_detail = "invalid_geometry_inputs";
      return false;
     }

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   if(stop_distance <= 0.0 || target_distance <= 0.0)
     {
      out_reject_detail = "non_positive_distance";
      return false;
     }

   const double sl_points = stop_distance / point;
   const double tp_points = target_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || tp_points <= 0.0 ||
      sl_points < (double)stop_level || tp_points < (double)stop_level)
     {
      out_reject_detail = "broker_stop_level";
      return false;
     }

   const double lots = QM_LotsForRisk(_Symbol,
                                      sl_points,
                                      QM_RISK_MODE_FIXED,
                                      RISK_FIXED);
   out_lots = lots;
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0)
     {
      out_reject_detail = "risk_sizing_unavailable";
      return false;
     }
   if(volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0)
     {
      out_reject_detail = "invalid_volume_metadata";
      return false;
     }
   if(lots < volume_min || lots > volume_max)
     {
      out_reject_detail = "sized_volume_out_of_range";
      return false;
     }
   const double aligned_steps = (lots - volume_min) / volume_step;
   if(MathAbs(aligned_steps - MathRound(aligned_steps)) > 1.0e-6)
     {
      out_reject_detail = "sized_volume_step_misaligned";
      return false;
     }
   return true;
  }

void Strategy_ClearPending()
  {
   g_pending_signal = false;
   g_pending_side = 0;
   g_pending_entry_bar_utc = 0;
   g_pending_sl = 0.0;
   g_pending_tp = 0.0;
  }

bool Strategy_InitializeSession(const int date_key,
                                 const MqlRates &current_bar)
  {
   Strategy_ResetDiagnosticsForDate(date_key);
   g_state_session_date_key = 0;
   g_armed_side = 0;
   g_session_consumed = false;
   g_prior_cash_close = 0.0;
   g_session_high = 0.0;
   g_session_low = 0.0;
   datetime open_utc = 0;
   datetime close_utc = 0;
   const int prior_date_key = Strategy_PreviousWeekdayDateKey(date_key);
   if(date_key <= 0 || prior_date_key <= 0)
     {
      Strategy_LogSessionStateReject(date_key,
                                     "invalid_session_date",
                                     StringFormat(",\"prior_date_key\":%d",
                                                  prior_date_key));
      return false;
     }
   if(!Strategy_ResolveCashSession(date_key, open_utc, close_utc))
     {
      Strategy_LogSessionStateReject(date_key,
                                     "cash_session_resolution_failed");
      return false;
     }
   const datetime current_bar_utc = QM_BrokerToUTC(current_bar.time);
   if(current_bar_utc != open_utc)
     {
      Strategy_LogSessionStateReject(date_key,
                                     "cash_open_bar_mismatch",
                                     StringFormat(",\"current_bar_utc\":%I64d,\"open_utc\":%I64d",
                                                  (long)current_bar_utc,
                                                  (long)open_utc));
      return false;
     }

   if(!g_history_state_valid ||
      g_history_through_date_key != prior_date_key)
     {
      if(!Strategy_WarmHistoryThrough(prior_date_key))
        {
         Strategy_LogSessionStateReject(date_key,
                                        "history_warmup_failed",
                                        StringFormat(",\"prior_date_key\":%d,\"history_state_valid\":%s,\"history_through_date_key\":%d,\"m30_tr_count\":%d,\"d1_tr_count\":%d,\"recent_count\":%d,\"m30_atr\":%.8f,\"d1_atr\":%.8f",
                                                     prior_date_key,
                                                     g_history_state_valid ? "true" : "false",
                                                     g_history_through_date_key,
                                                     g_m30_tr_count,
                                                     g_d1_tr_count,
                                                     g_recent_count,
                                                     g_m30_atr,
                                                     g_d1_atr));
         return false;
        }
     }

   g_state_session_date_key = date_key;
   g_prior_cash_close = g_m30_previous_close;
   const double cash_open = current_bar.open;
   if(g_prior_cash_close <= 0.0 || cash_open <= 0.0 || g_d1_atr <= 0.0)
     {
      Strategy_LogSessionStateReject(date_key,
                                     "invalid_session_anchors",
                                     StringFormat(",\"prior_cash_close\":%.8f,\"cash_open\":%.8f,\"d1_atr\":%.8f",
                                                  g_prior_cash_close,
                                                  cash_open,
                                                  g_d1_atr));
      return false;
     }
   if(Strategy_ClaimDiagnostic(date_key, STRATEGY_DIAG_SESSION_READY))
      QM_LogEvent(QM_INFO,
                  "SESSION_STATE_READY",
                  StringFormat("{\"symbol\":\"%s\",\"date_key\":%d,\"prior_date_key\":%d,\"open_utc\":%I64d,\"close_utc\":%I64d,\"history_through_date_key\":%d,\"m30_tr_count\":%d,\"d1_tr_count\":%d,\"recent_count\":%d,\"prior_cash_close\":%.8f,\"cash_open\":%.8f,\"m30_atr\":%.8f,\"d1_atr\":%.8f}",
                               QM_LoggerEscapeJson(_Symbol),
                               date_key,
                               prior_date_key,
                               (long)open_utc,
                               (long)close_utc,
                               g_history_through_date_key,
                               g_m30_tr_count,
                               g_d1_tr_count,
                               g_recent_count,
                               g_prior_cash_close,
                               cash_open,
                               g_m30_atr,
                               g_d1_atr));
   const double gap = cash_open - g_prior_cash_close;
   const double gap_ratio = MathAbs(gap) / g_d1_atr;
   g_session_high = cash_open;
   g_session_low = cash_open;
   const bool gap_eligible =
      (gap != 0.0 && gap_ratio >= strategy_gap_atr_min &&
       gap_ratio <= strategy_gap_atr_max);
   if(gap_eligible)
      g_armed_side = (gap > 0.0) ? -1 : 1;
   if(Strategy_ClaimDiagnostic(date_key, STRATEGY_DIAG_GAP_STATE))
      QM_LogEvent(QM_INFO,
                  "GAP_STATE",
                  StringFormat("{\"symbol\":\"%s\",\"date_key\":%d,\"eligible\":%s,\"armed_side\":%d,\"prior_cash_close\":%.8f,\"cash_open\":%.8f,\"gap\":%.8f,\"d1_atr\":%.8f,\"gap_ratio\":%.8f,\"gap_atr_min\":%.8f,\"gap_atr_max\":%.8f}",
                               QM_LoggerEscapeJson(_Symbol),
                               date_key,
                               gap_eligible ? "true" : "false",
                               g_armed_side,
                               g_prior_cash_close,
                               cash_open,
                               gap,
                               g_d1_atr,
                               gap_ratio,
                               strategy_gap_atr_min,
                               strategy_gap_atr_max));
   if(!gap_eligible)
      return true;
   return true;
  }

bool Strategy_PrepareCandidateEntry(const MqlRates &candidate,
                                    const datetime entry_bar_utc)
  {
   const double prior_high_average = Strategy_RecentHighAverage();
   const double prior_low_average = Strategy_RecentLowAverage();
   if(prior_high_average <= 0.0 || prior_low_average <= 0.0)
     {
      if(Strategy_ClaimDiagnostic(g_state_session_date_key,
                                  STRATEGY_DIAG_HILO_PREREQ))
         QM_LogEvent(QM_WARN,
                     "HILO_STATE_REJECTED",
                     StringFormat("{\"symbol\":\"%s\",\"detail\":\"recent_average_unavailable\",\"date_key\":%d,\"entry_bar_utc\":%I64d,\"recent_count\":%d,\"prior_high_average\":%.8f,\"prior_low_average\":%.8f}",
                                  QM_LoggerEscapeJson(_Symbol),
                                  g_state_session_date_key,
                                  (long)entry_bar_utc,
                                  g_recent_count,
                                  prior_high_average,
                                  prior_low_average));
      return false;
     }

   g_session_high = MathMax(g_session_high, candidate.high);
   g_session_low = MathMin(g_session_low, candidate.low);
   const bool state_advanced = Strategy_AdvanceM30State(candidate);
   if(!state_advanced || g_m30_atr <= 0.0)
     {
      if(Strategy_ClaimDiagnostic(g_state_session_date_key,
                                  STRATEGY_DIAG_HILO_PREREQ))
         QM_LogEvent(QM_WARN,
                     "HILO_STATE_REJECTED",
                     StringFormat("{\"symbol\":\"%s\",\"detail\":\"m30_state_unavailable\",\"date_key\":%d,\"entry_bar_utc\":%I64d,\"state_advanced\":%s,\"m30_tr_count\":%d,\"m30_atr\":%.8f}",
                                  QM_LoggerEscapeJson(_Symbol),
                                  g_state_session_date_key,
                                  (long)entry_bar_utc,
                                  state_advanced ? "true" : "false",
                                  g_m30_tr_count,
                                  g_m30_atr));
      return false;
     }

   ++g_diagnostic_candidate_count;
   g_diagnostic_last_entry_bar_utc = entry_bar_utc;
   g_diagnostic_last_candidate_close = candidate.close;
   g_diagnostic_last_prior_high_average = prior_high_average;
   g_diagnostic_last_prior_low_average = prior_low_average;
   g_diagnostic_last_extreme_limit =
      strategy_extreme_atr_tolerance * g_m30_atr;
   bool qualifies = false;
   if(g_armed_side < 0)
     {
      g_diagnostic_last_extreme_distance = candidate.close - g_session_low;
      qualifies = (candidate.close < prior_low_average &&
                   g_diagnostic_last_extreme_distance <=
                   g_diagnostic_last_extreme_limit);
     }
   else if(g_armed_side > 0)
     {
      g_diagnostic_last_extreme_distance = g_session_high - candidate.close;
      qualifies = (candidate.close > prior_high_average &&
                   g_diagnostic_last_extreme_distance <=
                   g_diagnostic_last_extreme_limit);
     }
   if(!qualifies)
      return false;

   Strategy_LogHiloOutcome(g_state_session_date_key, "QUALIFIED");
   g_session_consumed = true;
   g_attempt_date_key = g_state_session_date_key;

   MqlTick current_tick;
   if(!SymbolInfoTick(_Symbol, current_tick) ||
      current_tick.ask <= 0.0 || current_tick.bid <= 0.0 ||
      current_tick.ask < current_tick.bid)
     {
      Strategy_LogEntryReject(g_attempt_date_key,
                              entry_bar_utc,
                              "invalid_quote",
                              StringFormat(",\"bid\":%.8f,\"ask\":%.8f",
                                           current_tick.bid,
                                           current_tick.ask));
      return false;
     }
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
     {
      Strategy_LogEntryReject(g_attempt_date_key,
                              entry_bar_utc,
                              "invalid_tick_size",
                              StringFormat(",\"tick_size\":%.8f", tick_size));
      return false;
     }

   double entry = 0.0;
   double stop = 0.0;
   const double target = Strategy_TickNormalizedPrice(g_prior_cash_close);
   if(g_armed_side < 0)
     {
      entry = current_tick.bid;
      stop = Strategy_TickNormalizedPrice(candidate.high +
                                          strategy_stop_atr_offset * g_m30_atr);
      if(entry >= stop || target >= entry || g_session_low <= target)
        {
         Strategy_LogEntryReject(g_attempt_date_key,
                                 entry_bar_utc,
                                 "short_fill_or_target_geometry_invalid",
                                 StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"session_low\":%.8f",
                                              entry, stop, target, g_session_low));
         return false;
        }
     }
   else
     {
      entry = current_tick.ask;
      stop = Strategy_TickNormalizedPrice(candidate.low -
                                          strategy_stop_atr_offset * g_m30_atr);
      if(entry <= stop || target <= entry || g_session_high >= target)
        {
         Strategy_LogEntryReject(g_attempt_date_key,
                                 entry_bar_utc,
                                 "long_fill_or_target_geometry_invalid",
                                 StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"session_high\":%.8f",
                                              entry, stop, target, g_session_high));
         return false;
        }
     }

   const double stop_distance = MathAbs(entry - stop);
   const double target_distance = MathAbs(target - entry);
   const double epsilon = tick_size * 1.0e-9;
   if(stop_distance <= 0.0 ||
       stop_distance + epsilon < strategy_stop_atr_min * g_m30_atr ||
       stop_distance - epsilon > strategy_stop_atr_max * g_m30_atr ||
       target_distance + epsilon < strategy_min_reward_r * stop_distance)
     {
      Strategy_LogEntryReject(g_attempt_date_key,
                              entry_bar_utc,
                              "card_geometry_not_met",
                              StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"atr\":%.8f,\"stop_atr\":%.8f,\"reward_r\":%.8f",
                                           entry,
                                           stop,
                                           target,
                                           g_m30_atr,
                                           g_m30_atr > 0.0
                                           ? stop_distance / g_m30_atr
                                           : 0.0,
                                           stop_distance > 0.0
                                           ? target_distance / stop_distance
                                           : 0.0));
      return false;
     }

   double lots = 0.0;
   string geometry_reject = "";
   if(!Strategy_TradeGeometryAndVolumeAllow(entry,
                                            stop,
                                            target,
                                            lots,
                                            geometry_reject))
     {
      Strategy_LogEntryReject(g_attempt_date_key,
                              entry_bar_utc,
                              geometry_reject,
                              StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"lots\":%.8f",
                                           entry, stop, target, lots));
      return false;
     }

   g_pending_signal = true;
   g_pending_side = g_armed_side;
   g_pending_entry_bar_utc = entry_bar_utc;
   g_pending_sl = stop;
   g_pending_tp = target;
   return true;
  }

void Strategy_ProcessCandidate(const int date_key,
                               const datetime current_bar_utc)
  {
   if(date_key != g_state_session_date_key || !g_history_state_valid)
     {
      Strategy_LogRuntimeStateReject(date_key,
                                     "session_or_history_state_mismatch",
                                     current_bar_utc,
                                     StringFormat(",\"state_session_date_key\":%d,\"history_state_valid\":%s,\"history_through_date_key\":%d",
                                                  g_state_session_date_key,
                                                  g_history_state_valid ? "true" : "false",
                                                  g_history_through_date_key));
      return;
     }
   datetime open_utc = 0;
   datetime close_utc = 0;
   if(!Strategy_ResolveCashSession(date_key, open_utc, close_utc))
     {
      Strategy_LogRuntimeStateReject(date_key,
                                     "cash_session_resolution_failed",
                                     current_bar_utc);
      return;
     }
   if(current_bar_utc <= open_utc || current_bar_utc > close_utc)
     {
      Strategy_LogRuntimeStateReject(date_key,
                                     "candidate_outside_cash_session",
                                     current_bar_utc,
                                     StringFormat(",\"open_utc\":%I64d,\"close_utc\":%I64d",
                                                  (long)open_utc,
                                                  (long)close_utc));
      return;
     }

   MqlRates candidate[];
   ArraySetAsSeries(candidate, false);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, 1, candidate); // perf-allowed: one just-completed candidate bar under the framework new-bar event.
   if(copied != 1)
     {
      Strategy_LogRuntimeStateReject(date_key,
                                     "candidate_copy_failed",
                                     current_bar_utc,
                                     StringFormat(",\"copy_count\":%d", copied));
      g_session_consumed = true;
      g_history_state_valid = false;
      return;
     }
   const datetime candidate_bar_utc = QM_BrokerToUTC(candidate[0].time);
   if(candidate_bar_utc != current_bar_utc - 30 * 60 ||
      candidate_bar_utc < open_utc)
     {
      Strategy_LogRuntimeStateReject(date_key,
                                     "candidate_bar_mismatch",
                                     current_bar_utc,
                                     StringFormat(",\"candidate_bar_utc\":%I64d,\"expected_candidate_bar_utc\":%I64d,\"open_utc\":%I64d",
                                                  (long)candidate_bar_utc,
                                                  (long)(current_bar_utc - 30 * 60),
                                                  (long)open_utc));
      g_session_consumed = true;
      g_history_state_valid = false;
      return;
     }

   const int tr_count_before = g_m30_tr_count;
   if(current_bar_utc <= open_utc + 180 * 60 &&
      !g_session_consumed && g_armed_side != 0)
      Strategy_PrepareCandidateEntry(candidate[0], current_bar_utc);
   else
     {
      if(current_bar_utc > open_utc + 180 * 60 &&
         !g_session_consumed && g_armed_side != 0)
         Strategy_LogHiloOutcome(date_key, "WINDOW_EXHAUSTED");
      g_session_high = MathMax(g_session_high, candidate[0].high);
      g_session_low = MathMin(g_session_low, candidate[0].low);
      Strategy_AdvanceM30State(candidate[0]);
     }
   if(g_m30_tr_count != tr_count_before + 1)
     {
      Strategy_LogRuntimeStateReject(date_key,
                                     "m30_state_advance_count_mismatch",
                                     current_bar_utc,
                                     StringFormat(",\"tr_count_before\":%d,\"tr_count_after\":%d",
                                                  tr_count_before,
                                                  g_m30_tr_count));
      g_session_consumed = true;
      g_history_state_valid = false;
      return;
     }

   if(current_bar_utc == close_utc)
     {
      if(!Strategy_AdvanceD1State(g_session_high,
                                  g_session_low,
                                  candidate[0].close))
        {
         Strategy_LogRuntimeStateReject(date_key,
                                        "d1_state_advance_failed",
                                        current_bar_utc,
                                        StringFormat(",\"session_high\":%.8f,\"session_low\":%.8f,\"session_close\":%.8f,\"d1_tr_count\":%d,\"d1_atr\":%.8f",
                                                     g_session_high,
                                                     g_session_low,
                                                     candidate[0].close,
                                                     g_d1_tr_count,
                                                     g_d1_atr));
         g_history_state_valid = false;
         return;
        }
      g_history_through_date_key = date_key;
      g_history_state_valid = true;
     }
  }

void Strategy_AdvanceStateOnNewBar()
  {
   Strategy_ClearPending();
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf)
      return;

   MqlRates current_bar[];
   ArraySetAsSeries(current_bar, false);
   if(CopyRates(_Symbol, strategy_signal_tf, 0, 1, current_bar) != 1) // perf-allowed: one current bar read under the single framework new-bar event.
      return;
   const datetime current_bar_utc = QM_BrokerToUTC(current_bar[0].time);
   if(current_bar_utc <= 0)
      return;
   const datetime current_ny = Strategy_NewYorkLocal(current_bar_utc);
   const int date_key = Strategy_DateKey(current_ny);
   datetime open_utc = 0;
   datetime close_utc = 0;
   if(!Strategy_ResolveCashSession(date_key, open_utc, close_utc))
      return;
   const long offset_seconds =
      (long)(current_bar_utc - open_utc);
   if(offset_seconds < 0 || offset_seconds > 390 * 60 ||
      offset_seconds % (30 * 60) != 0)
      return;

   if(offset_seconds == 0)
     {
       if(date_key == g_attempt_date_key)
          return;
      Strategy_InitializeSession(date_key, current_bar[0]);
      return;
     }
   Strategy_ProcessCandidate(date_key, current_bar_utc);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points < 0 || spread_points > strategy_max_spread_points);
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
   return (!Strategy_IsRoutedSymbol(_Symbol) ||
           _Period != strategy_signal_tf ||
           strategy_variant_id != "GAP_HILO_FADE_BASELINE" ||
           strategy_signal_tf != PERIOD_M30 ||
           strategy_d1_atr_period != 20 ||
           strategy_gap_atr_min != 0.25 ||
           strategy_gap_atr_max != 1.25 ||
           strategy_hilo_period != 10 ||
           strategy_m30_atr_period != 14 ||
           strategy_extreme_atr_tolerance != 0.10 ||
           strategy_stop_atr_offset != 0.25 ||
            strategy_stop_atr_min != 0.75 ||
            strategy_stop_atr_max != 1.50 ||
            strategy_min_reward_r != 1.25 ||
            strategy_cash_open_hour_new_york != 9 ||
            strategy_cash_open_minute_new_york != 30 ||
            strategy_cash_close_hour_new_york != 16 ||
            strategy_cash_close_minute_new_york != 0 ||
            strategy_max_spread_points < 0 ||
            RISK_FIXED != 1000.0 ||
           RISK_PERCENT != 0.0);
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

   if(!g_pending_signal || g_pending_entry_bar_utc <= 0)
      return false;

   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
     {
      Strategy_LogEntryReject(g_attempt_date_key,
                              g_pending_entry_bar_utc,
                              "position_already_open");
      Strategy_ClearPending();
      return false;
     }
   if(Strategy_WideSpread())
     {
      Strategy_LogEntryReject(g_attempt_date_key,
                              g_pending_entry_bar_utc,
                              "spread_limit_exceeded",
                              StringFormat(",\"spread_points\":%I64d,\"max_spread_points\":%d",
                                           SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
                                           strategy_max_spread_points));
      Strategy_ClearPending();
      return false;
     }

   req.type = (g_pending_side > 0) ? QM_BUY : QM_SELL;
   req.sl = g_pending_sl;
   req.tp = g_pending_tp;
   req.reason = (g_pending_side > 0)
                ? "GAP_HILO_FADE_LONG"
                : "GAP_HILO_FADE_SHORT";
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"symbol\":\"%s\",\"side\":\"%s\",\"date_key\":%d,\"entry_bar_utc\":%I64d,\"sl\":%.8f,\"tp\":%.8f}",
                            QM_LoggerEscapeJson(_Symbol),
                            g_pending_side > 0 ? "BUY" : "SELL",
                            g_attempt_date_key,
                            (long)g_pending_entry_bar_utc,
                            g_pending_sl,
                            g_pending_tp));
   Strategy_ClearPending();
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // The card freezes the signal-bar stop and prior-cash-close target.
   // No trail, break-even, partial, scale, averaging, or reversal is allowed.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_broker = 0;
   if(!Strategy_FindOurPosition(open_broker))
      return false;
   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime open_utc = QM_BrokerToUTC(open_broker);
   if(now_utc <= 0 || open_utc <= 0)
      return false;
   const datetime now_ny = Strategy_NewYorkLocal(now_utc);
   const datetime open_ny = Strategy_NewYorkLocal(open_utc);
   const int now_date = Strategy_DateKey(now_ny);
   const int open_date = Strategy_DateKey(open_ny);
   if(now_date <= 0 || open_date <= 0)
      return false;
   if(now_date > open_date)
      return true;
   if(now_date < open_date)
      return false;

   MqlDateTime parts;
   if(!TimeToStruct(now_ny, parts))
      return false;
   return (parts.hour * 60 + parts.min >= 15 * 60 + 55);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the governed central entry-only news gate
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

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"routed\":%s,\"period\":%d,\"signal_tf\":%d,\"variant\":\"%s\"}",
                            Strategy_IsRoutedSymbol(_Symbol) ? "true" : "false",
                            (int)_Period,
                            (int)strategy_signal_tf,
                            QM_LoggerEscapeJson(strategy_variant_id)));
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

   // The candidate closes at this new bar. Freeze the signal and consume the
   // exact next-bar opportunity before news can suppress (but never delay) it.
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
     {
      if(strategy_new_bar && g_pending_signal)
        {
         Strategy_LogEntryReject(g_attempt_date_key,
                                 g_pending_entry_bar_utc,
                                 "news_filter_block");
         Strategy_ClearPending();
        }
      return;
     }

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
