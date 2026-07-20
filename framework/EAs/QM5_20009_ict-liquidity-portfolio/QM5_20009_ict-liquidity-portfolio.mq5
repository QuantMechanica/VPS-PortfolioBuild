#property strict
#property version   "5.0"
#property description "QM5_20009 ICT Liquidity Portfolio"

#include <QM/QM_Common.mqh>
#include <QM/QM_FTMOGovernorClient.mqh>
#include "ICT_LiquidityRules.mqh"

// Frozen research build contract v5.  One attachment owns exactly one symbol,
// one sleeve and one registry magic.  All signal decisions use closed Bid bars.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20009;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk controls"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News (entry only)"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 23;

input group "Stress controls"
input double qm_stress_reject_probability  = 0.0;

input group "Frozen sleeve"
input ICT_StrategyMode strategy_mode       = ICT_MODE_INDEX_MSS_FVG;
input int    strategy_replay_bars_index    = 2500;
input int    strategy_replay_bars_fx       = 10000;

input group "Sleeve A preregistered star"
input int    strategy_a_pivot_wing         = 2;
input int    strategy_a_reclaim_bars       = 3;
input int    strategy_a_max_bars_to_mss    = 9;
input double strategy_a_min_fvg_atr        = 0.05;
input double strategy_a_sl_buffer_atr      = 0.10;
input double strategy_a_min_rr             = 2.0;

input group "Sleeve B preregistered star"
input int    strategy_b_pivot_wing         = 2;
input int    strategy_b_reclaim_bars       = 3;
input int    strategy_b_max_bars_to_mss    = 12;
input double strategy_b_min_fvg_atr        = 0.05;
input double strategy_b_sl_buffer_atr      = 0.10;
input double strategy_b_min_rr             = 2.0;

input group "FTMO Governor"
// These identities come only from an OWNER-signed deploy manifest.  Empty
// defaults intentionally make every unconfigured non-tester attachment inert.
input string strategy_governor_policy_id   = "";
input string strategy_challenge_instance_id = "";
input int    strategy_governor_heartbeat_max_age_seconds = 5;

enum ICT_AttemptPersistenceState
  {
   ICT_ATTEMPT_NONE      = 0,
   ICT_ATTEMPT_CONSUMED  = 1,
   ICT_ATTEMPT_SUBMITTED = 2
  };

datetime g_last_closed_bar = 0;
double   g_strategy_governor_scale = 0.0;
string   g_strategy_last_governor_block = "";
datetime g_strategy_last_governor_log = 0;
string   g_last_reconstruction_signature = "";
string   g_strategy_last_fx_incomplete_signature = "";
int      g_tester_attempt_state = ICT_ATTEMPT_NONE;
int      g_tester_attempt_budget_key = 0;
datetime g_tester_attempt_event_time = 0;
uint     g_tester_attempt_level_hash = 0;
uint     g_tester_attempt_reference_hash = 0;
MqlRates g_strategy_closed_rates[];
int      g_strategy_closed_rate_count = 0;
int      g_strategy_replay_budget_key = 0;
bool     g_strategy_replay_cache_ready = false;
double   g_strategy_replay_point = 0.0;
double   g_strategy_replay_tick_size = 0.0;
int      g_strategy_replay_failure_count = 0;
datetime g_strategy_replay_retry_not_before = 0;
ICT_LevelRange g_strategy_index_opening_range;
ICT_LevelRange g_strategy_fx_asian_range;
ICT_SequenceResult g_strategy_cached_sequence;
bool               g_strategy_virtual_limit_active = false;
datetime           g_strategy_virtual_limit_deadline = 0;
datetime           g_strategy_virtual_limit_last_gate_time = 0;
ICT_SequenceResult g_strategy_virtual_limit_signal;
QM_EntryRequest    g_strategy_virtual_limit_request;
bool               g_strategy_own_timer_active = false;

bool Strategy_IsIntegerStarValue(const int value,
                                 const int low,
                                 const int center,
                                 const int high)
  {
   return value == low || value == center || value == high;
  }

bool Strategy_IsDoubleStarValue(const double value,
                                const double low,
                                const double center,
                                const double high)
  {
   return MathAbs(value - low) < 1e-12 ||
          MathAbs(value - center) < 1e-12 ||
          MathAbs(value - high) < 1e-12;
  }

bool Strategy_ParametersValid()
  {
   if(qm_ea_id != 20009 || PORTFOLIO_WEIGHT <= 0.0 ||
      !MathIsValidNumber(PORTFOLIO_WEIGHT))
      return false;
   if(strategy_replay_bars_index != 2500 || strategy_replay_bars_fx != 10000)
      return false;
   if(!qm_friday_close_enabled || qm_friday_close_hour_broker != 23)
      return false;
   // The research/live boundary uses one frozen, real FTMO entry-news profile.
   // DXZ compliance is only a framework placeholder and is not admissible here.
   if(qm_news_temporal != QM_NEWS_TEMPORAL_PRE30_POST30 ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_FTMO ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high" ||
      qm_news_mode_legacy != QM_NEWS_OFF)
      return false;

   if(!Strategy_IsIntegerStarValue(strategy_a_pivot_wing, 1, 2, 3) ||
      !Strategy_IsIntegerStarValue(strategy_a_reclaim_bars, 1, 3, 5) ||
      !Strategy_IsIntegerStarValue(strategy_a_max_bars_to_mss, 6, 9, 12) ||
      !Strategy_IsDoubleStarValue(strategy_a_min_fvg_atr, 0.0, 0.05, 0.10) ||
      !Strategy_IsDoubleStarValue(strategy_a_sl_buffer_atr, 0.05, 0.10, 0.15) ||
      !Strategy_IsDoubleStarValue(strategy_a_min_rr, 1.5, 2.0, 2.5))
      return false;

   if(!Strategy_IsIntegerStarValue(strategy_b_pivot_wing, 1, 2, 3) ||
      !Strategy_IsIntegerStarValue(strategy_b_reclaim_bars, 1, 3, 5) ||
      !Strategy_IsIntegerStarValue(strategy_b_max_bars_to_mss, 6, 12, 18) ||
      !Strategy_IsDoubleStarValue(strategy_b_min_fvg_atr, 0.0, 0.05, 0.10) ||
      !Strategy_IsDoubleStarValue(strategy_b_sl_buffer_atr, 0.05, 0.10, 0.15) ||
      !Strategy_IsDoubleStarValue(strategy_b_min_rr, 1.5, 2.0, 2.5))
      return false;

   const int a_deviations =
      (strategy_a_pivot_wing != 2 ? 1 : 0) +
      (strategy_a_reclaim_bars != 3 ? 1 : 0) +
      (strategy_a_max_bars_to_mss != 9 ? 1 : 0) +
      (MathAbs(strategy_a_min_fvg_atr - 0.05) > 1e-12 ? 1 : 0) +
      (MathAbs(strategy_a_sl_buffer_atr - 0.10) > 1e-12 ? 1 : 0) +
      (MathAbs(strategy_a_min_rr - 2.0) > 1e-12 ? 1 : 0);
   const int b_deviations =
      (strategy_b_pivot_wing != 2 ? 1 : 0) +
      (strategy_b_reclaim_bars != 3 ? 1 : 0) +
      (strategy_b_max_bars_to_mss != 12 ? 1 : 0) +
      (MathAbs(strategy_b_min_fvg_atr - 0.05) > 1e-12 ? 1 : 0) +
      (MathAbs(strategy_b_sl_buffer_atr - 0.10) > 1e-12 ? 1 : 0) +
      (MathAbs(strategy_b_min_rr - 2.0) > 1e-12 ? 1 : 0);

   // Tester permits only the preregistered center or one active-sleeve axis at
   // a time.  Non-tester operation is center-only; no selected neighbor may
   // silently become a deployment parameter.
   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      if(strategy_mode == ICT_MODE_INDEX_MSS_FVG &&
         (a_deviations > 1 || b_deviations != 0))
         return false;
      if(strategy_mode == ICT_MODE_FX_SESSION_SWEEP &&
         (b_deviations > 1 || a_deviations != 0))
         return false;
     }
   else if(a_deviations != 0 || b_deviations != 0)
      return false;

   if(MQLInfoInteger(MQL_TESTER) != 0)
      return MathIsValidNumber(RISK_FIXED) && RISK_FIXED > 0.0 &&
             MathIsValidNumber(RISK_PERCENT) && RISK_PERCENT == 0.0;
   return true;
  }

bool Strategy_SymbolMagicAndTimeframeValid()
  {
   if(strategy_mode == ICT_MODE_INDEX_MSS_FVG)
     {
      if((ENUM_TIMEFRAMES)_Period != PERIOD_M1)
        {
         Print("QM5_20009_INPUT_TIMEFRAME_MISMATCH: sleeve A requires M1");
         return false;
        }
      if(_Symbol == "NDX.DWX" && qm_magic_slot_offset == 0)
         return true;
      if(_Symbol == "GDAXI.DWX" && qm_magic_slot_offset == 1)
         return true;
      Print("QM5_20009_SYMBOL_MAGIC_MISMATCH: A requires NDX.DWX/slot0 or GDAXI.DWX/slot1");
      return false;
     }

   if(strategy_mode == ICT_MODE_FX_SESSION_SWEEP)
     {
      if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
        {
         Print("QM5_20009_INPUT_TIMEFRAME_MISMATCH: sleeve B requires M5");
         return false;
        }
      if(_Symbol == "GBPUSD.DWX" && qm_magic_slot_offset == 2)
         return true;
      if(_Symbol == "EURUSD.DWX" && qm_magic_slot_offset == 5)
         return true;
      Print("QM5_20009_SYMBOL_MAGIC_MISMATCH: B requires GBPUSD.DWX/slot2 or EURUSD.DWX/slot5");
      return false;
     }

   Print("QM5_20009_UNKNOWN_STRATEGY_MODE");
   return false;
  }

int Strategy_ExpectedRegistryMagic()
  {
   if(_Symbol == "NDX.DWX" && qm_magic_slot_offset == 0)
      return 200090000;
   if(_Symbol == "GDAXI.DWX" && qm_magic_slot_offset == 1)
      return 200090001;
   if(_Symbol == "GBPUSD.DWX" && qm_magic_slot_offset == 2)
      return 200090002;
   if(_Symbol == "EURUSD.DWX" && qm_magic_slot_offset == 5)
      return 200090005;
   return -1;
  }

bool Strategy_NonTesterGovernorConfigValid()
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return true;

   QM_FTMO_GovernorPolicy policy;
   if(!QM_FTMO_SelectPolicy(strategy_governor_policy_id, policy) ||
      !QM_FTMO_IsExactPolicy(policy) ||
      !QM_FTMO_IdentifierValid(strategy_challenge_instance_id) ||
      strategy_governor_heartbeat_max_age_seconds != 5 ||
      !MathIsValidNumber(RISK_FIXED) || RISK_FIXED != 0.0 ||
      !MathIsValidNumber(RISK_PERCENT) || RISK_PERCENT <= 0.0)
      return false;
   if(strategy_governor_policy_id == "FTMO_2S_P1_100K_V2" &&
      MathAbs(RISK_PERCENT - 0.15) > 0.000000001)
      return false;
   if(strategy_governor_policy_id == "FTMO_2S_P2_100K_V2" &&
      MathAbs(RISK_PERCENT - 0.105) > 0.000000001)
      return false;
   if(strategy_governor_policy_id == "FTMO_2S_FUNDED_100K_V2" &&
      RISK_PERCENT > 0.10 + 0.000000001)
      return false;
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" ||
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) !=
       ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return false;
   return true;
  }

bool Strategy_GovernorAllowsEntry()
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      g_strategy_governor_scale = 1.0;
      return true;
     }

   double scale = 0.0;
   string block_reason = "GOVERNOR_UNKNOWN";
   const bool allowed = QM_FTMO_ReadGovernorScale(
      strategy_governor_policy_id,
      strategy_challenge_instance_id,
      strategy_governor_heartbeat_max_age_seconds,
      scale,
      block_reason);
   if(!allowed)
     {
      g_strategy_governor_scale = 0.0;
      const datetime now_broker = TimeCurrent();
      if(block_reason != g_strategy_last_governor_block ||
         now_broker - g_strategy_last_governor_log >= 60)
        {
         g_strategy_last_governor_block = block_reason;
         g_strategy_last_governor_log = now_broker;
         QM_LogEvent(QM_WARN,
                     "ICT_GOVERNOR_ENTRY_BLOCK",
                     StringFormat("{\"reason\":\"%s\",\"policy_id\":\"%s\"}",
                                  QM_LoggerEscapeJson(block_reason),
                                  QM_LoggerEscapeJson(strategy_governor_policy_id)));
        }
      return false;
     }

   g_strategy_governor_scale = scale;
   g_strategy_last_governor_block = "";
   return true;
  }

void Strategy_ModeParameters(int &pivot_wing,
                             int &reclaim_bars,
                             int &max_bars_to_mss,
                             double &min_fvg_atr,
                             double &sl_buffer_atr,
                             double &min_rr)
  {
   if(strategy_mode == ICT_MODE_INDEX_MSS_FVG)
     {
      pivot_wing = strategy_a_pivot_wing;
      reclaim_bars = strategy_a_reclaim_bars;
      max_bars_to_mss = strategy_a_max_bars_to_mss;
      min_fvg_atr = strategy_a_min_fvg_atr;
      sl_buffer_atr = strategy_a_sl_buffer_atr;
      min_rr = strategy_a_min_rr;
      return;
     }
   pivot_wing = strategy_b_pivot_wing;
   reclaim_bars = strategy_b_reclaim_bars;
   max_bars_to_mss = strategy_b_max_bars_to_mss;
   min_fvg_atr = strategy_b_min_fvg_atr;
   sl_buffer_atr = strategy_b_sl_buffer_atr;
   min_rr = strategy_b_min_rr;
  }

bool Strategy_LoadClosedRates(MqlRates &rates[], int &count)
  {
   const int requested = (strategy_mode == ICT_MODE_INDEX_MSS_FVG)
                         ? strategy_replay_bars_index
                         : strategy_replay_bars_fx;
   ArraySetAsSeries(rates, false);
   count = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, requested, rates); // perf-allowed: bounded deterministic restart replay; closed bars only.
   ArraySetAsSeries(rates, false);
   const int minimum = (strategy_mode == ICT_MODE_INDEX_MSS_FVG) ? 60 : 1000;
   return count >= minimum;
  }

bool Strategy_ReconstructIndex(const MqlRates &rates[],
                               const int count,
                               const double tick_size,
                               const double point,
                               ICT_SequenceResult &result)
  {
   ICT_ResetSequence(result);
   if(count <= 0)
      return false;
   const int date_key = ICT_NYDateKey(rates[count - 1].time);

   ICT_LevelRange opening_range;
   if(!ICT_CollectNYRange(rates,
                          count,
                          date_key,
                          9 * 60 + 30,
                          10 * 60,
                          30,
                          tick_size,
                          opening_range))
     {
      result.ny_date_key = date_key;
      result.budget_key = date_key;
      result.outcome = "OPENING_RANGE_INCOMPLETE";
      return true;
     }

   int pivot_wing = 0;
   int reclaim_bars = 0;
   int max_bars_to_mss = 0;
   double min_fvg_atr = 0.0;
   double sl_buffer_atr = 0.0;
   double min_rr = 0.0;
   Strategy_ModeParameters(pivot_wing,
                           reclaim_bars,
                           max_bars_to_mss,
                           min_fvg_atr,
                           sl_buffer_atr,
                           min_rr);

   ICT_BuildSequence(rates,
                     count,
                     date_key,
                     date_key,
                     ICT_SESSION_INDEX_AM,
                     10 * 60,
                     11 * 60,
                     PeriodSeconds(PERIOD_M1),
                     opening_range.low,
                     opening_range.high,
                     opening_range.high,
                     opening_range.low,
                     opening_range.fingerprint,
                     opening_range.fingerprint,
                     pivot_wing,
                     reclaim_bars,
                     max_bars_to_mss,
                     min_fvg_atr,
                     sl_buffer_atr,
                     min_rr,
                     tick_size,
                     point,
                     result,
                     0,
                     count - 1,
                     0);
   return true;
  }

void Strategy_CopySequence(const ICT_SequenceResult &source,
                           ICT_SequenceResult &destination)
  {
   destination.consumed = source.consumed;
   destination.ambiguous = source.ambiguous;
   destination.signal_valid = source.signal_valid;
   destination.direction = source.direction;
   destination.session = source.session;
   destination.budget_key = source.budget_key;
   destination.ny_date_key = source.ny_date_key;
   destination.event_bar_time = source.event_bar_time;
   destination.penetration_bar_time = source.penetration_bar_time;
   destination.reclaim_bar_time = source.reclaim_bar_time;
   destination.mss_bar_time = source.mss_bar_time;
   destination.fvg_bar_time = source.fvg_bar_time;
   destination.swept_extreme = source.swept_extreme;
   destination.pivot_price = source.pivot_price;
   destination.entry = source.entry;
   destination.stop = source.stop;
   destination.target = source.target;
   destination.atr = source.atr;
   destination.observed_spread = source.observed_spread;
   destination.session_end_minute = source.session_end_minute;
   destination.frozen_level_hash = source.frozen_level_hash;
   destination.reference_hash = source.reference_hash;
   destination.outcome = source.outcome;
  }

bool Strategy_ReconstructFx(const MqlRates &rates[],
                            const int count,
                            const double tick_size,
                            const double point,
                            ICT_SequenceResult &result)
  {
   ICT_ResetSequence(result);
   if(count <= 0)
      return false;

   const int date_key = ICT_NYDateKey(rates[count - 1].time);
   const int reference_date = ICT_ShiftDateKey(date_key, -1);
   ICT_LevelRange asian_range;
   if(!ICT_CollectNYRange(rates,
                          count,
                          reference_date,
                          20 * 60,
                          24 * 60,
                          48,
                          tick_size,
                          asian_range))
     {
      result.budget_key = date_key;
      result.ny_date_key = date_key;
      result.outcome = "ASIAN_REFERENCE_INCOMPLETE";
      return true;
     }

   int pivot_wing = 0;
   int reclaim_bars = 0;
   int max_bars_to_mss = 0;
   double min_fvg_atr = 0.0;
   double sl_buffer_atr = 0.0;
   double min_rr = 0.0;
   Strategy_ModeParameters(pivot_wing,
                           reclaim_bars,
                           max_bars_to_mss,
                           min_fvg_atr,
                           sl_buffer_atr,
                           min_rr);

   ICT_BuildSequence(rates,
                     count,
                     date_key,
                     date_key,
                     ICT_SESSION_LONDON,
                     2 * 60,
                     5 * 60,
                     PeriodSeconds(PERIOD_M5),
                     asian_range.low,
                     asian_range.high,
                     asian_range.high,
                     asian_range.low,
                     asian_range.fingerprint,
                     asian_range.fingerprint,
                     pivot_wing,
                     reclaim_bars,
                     max_bars_to_mss,
                     min_fvg_atr,
                     sl_buffer_atr,
                     min_rr,
                     tick_size,
                     point,
                     result,
                     0,
                     count - 1,
                     0);
   return true;
  }

void Strategy_ScheduleReplayRetry()
  {
   g_strategy_replay_failure_count =
      MathMin(g_strategy_replay_failure_count + 1, 16);
   int retry_bars = 1;
   const int exponent = MathMin(g_strategy_replay_failure_count - 1, 6);
   for(int i = 0; i < exponent; ++i)
      retry_bars *= 2;
   const int retry_cap = (strategy_mode == ICT_MODE_INDEX_MSS_FVG) ? 60 : 12;
   retry_bars = MathMin(retry_bars, retry_cap);
   const datetime anchor = (g_last_closed_bar > 0)
                           ? g_last_closed_bar
                           : iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   g_strategy_replay_retry_not_before =
      (anchor > 0) ? anchor + retry_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period)
                   : 0;
  }

void Strategy_ResetReplayRetry()
  {
   g_strategy_replay_failure_count = 0;
   g_strategy_replay_retry_not_before = 0;
  }

bool Strategy_Reconstruct(ICT_SequenceResult &result)
  {
   const int previous_budget_key = g_strategy_replay_budget_key;
   const int attempted_budget_key = (g_last_closed_bar > 0)
                                    ? Strategy_BudgetKeyAtTime(g_last_closed_bar)
                                    : 0;
   if(attempted_budget_key != previous_budget_key)
      Strategy_ResetReplayRetry();
   g_strategy_replay_cache_ready = false;
   g_strategy_replay_budget_key = attempted_budget_key;
   g_strategy_closed_rate_count = 0;
   ArrayFree(g_strategy_closed_rates);
   ICT_ResetRange(g_strategy_index_opening_range);
   ICT_ResetRange(g_strategy_fx_asian_range);
   ICT_ResetSequence(g_strategy_cached_sequence);

   if(!Strategy_LoadClosedRates(g_strategy_closed_rates,
                                g_strategy_closed_rate_count))
     {
      ICT_ResetSequence(result);
      result.outcome = "REPLAY_HISTORY_UNAVAILABLE";
      Strategy_ScheduleReplayRetry();
      return false;
     }

   g_strategy_replay_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_strategy_replay_tick_size = SymbolInfoDouble(_Symbol,
                                                   SYMBOL_TRADE_TICK_SIZE);
   if(g_strategy_replay_tick_size <= 0.0)
      g_strategy_replay_tick_size = g_strategy_replay_point;
   if(g_strategy_replay_point <= 0.0 || g_strategy_replay_tick_size <= 0.0)
     {
      ICT_ResetSequence(result);
      result.outcome = "SYMBOL_PRICE_UNIT_UNAVAILABLE";
      Strategy_ScheduleReplayRetry();
      return false;
     }

   bool reconstructed = false;
   if(strategy_mode == ICT_MODE_INDEX_MSS_FVG)
      reconstructed = Strategy_ReconstructIndex(g_strategy_closed_rates,
                                                 g_strategy_closed_rate_count,
                                                 g_strategy_replay_tick_size,
                                                 g_strategy_replay_point,
                                                 result);
   else
      reconstructed = Strategy_ReconstructFx(g_strategy_closed_rates,
                                              g_strategy_closed_rate_count,
                                              g_strategy_replay_tick_size,
                                              g_strategy_replay_point,
                                              result);
   if(!reconstructed)
     {
      Strategy_ScheduleReplayRetry();
      return false;
     }

   const datetime newest_time =
      g_strategy_closed_rates[g_strategy_closed_rate_count - 1].time;
   g_strategy_replay_budget_key = Strategy_BudgetKeyAtTime(newest_time);
   if(g_strategy_replay_budget_key <= 0 ||
      result.budget_key != g_strategy_replay_budget_key)
     {
      ICT_ResetSequence(result);
      result.outcome = "REPLAY_BUDGET_MISMATCH";
      Strategy_ScheduleReplayRetry();
      return false;
     }

   if(strategy_mode == ICT_MODE_INDEX_MSS_FVG)
      ICT_CollectNYRange(g_strategy_closed_rates,
                         g_strategy_closed_rate_count,
                         g_strategy_replay_budget_key,
                         9 * 60 + 30,
                         10 * 60,
                         30,
                         g_strategy_replay_tick_size,
                         g_strategy_index_opening_range);
   else
     {
      ICT_CollectNYRange(g_strategy_closed_rates,
                         g_strategy_closed_rate_count,
                         ICT_ShiftDateKey(g_strategy_replay_budget_key, -1),
                         20 * 60,
                         24 * 60,
                         48,
                         g_strategy_replay_tick_size,
                         g_strategy_fx_asian_range);
     }

   Strategy_CopySequence(result, g_strategy_cached_sequence);
   g_strategy_replay_cache_ready = true;
   Strategy_ResetReplayRetry();
   return true;
  }

int Strategy_ReplayRequestedBars()
  {
   return (strategy_mode == ICT_MODE_INDEX_MSS_FVG)
          ? strategy_replay_bars_index
          : strategy_replay_bars_fx;
  }

int Strategy_LogicalHistoryFirstIndex()
  {
   return MathMax(0,
                  g_strategy_closed_rate_count - Strategy_ReplayRequestedBars());
  }

bool Strategy_FindNYWindowBounds(const int ny_date_key,
                                 const int start_minute,
                                 const int end_minute,
                                 const bool event_window,
                                 const int timeframe_seconds,
                                 int &first_index,
                                 int &last_index)
  {
   first_index = -1;
   last_index = -1;
   const int history_first = Strategy_LogicalHistoryFirstIndex();
   for(int i = g_strategy_closed_rate_count - 1; i >= history_first; --i)
     {
      const int bar_date_key = ICT_NYDateKey(g_strategy_closed_rates[i].time);
      if(bar_date_key > ny_date_key)
         continue;
      if(bar_date_key < ny_date_key)
         break;

      bool in_window = false;
      if(event_window)
         in_window = ICT_IsEventBarInSession(g_strategy_closed_rates[i],
                                              ny_date_key,
                                              start_minute,
                                              end_minute,
                                              timeframe_seconds);
      else
        {
         const int minute = ICT_NYMinute(g_strategy_closed_rates[i].time);
         in_window = minute >= start_minute && minute < end_minute;
        }
      if(!in_window)
         continue;
      if(last_index < 0)
         last_index = i;
      first_index = i;
     }
   return first_index >= 0 && last_index >= first_index;
  }

void Strategy_AccumulateIndexOpeningRange(const MqlRates &bar)
  {
   if(ICT_NYDateKey(bar.time) != g_strategy_replay_budget_key)
      return;
   const int minute = ICT_NYMinute(bar.time);
   if(minute < 9 * 60 + 30 || minute >= 10 * 60)
      return;

   if(g_strategy_index_opening_range.bars == 0)
     {
      g_strategy_index_opening_range.high = bar.high;
      g_strategy_index_opening_range.low = bar.low;
     }
   else
     {
      g_strategy_index_opening_range.high =
         MathMax(g_strategy_index_opening_range.high, bar.high);
      g_strategy_index_opening_range.low =
         MathMin(g_strategy_index_opening_range.low, bar.low);
     }
   ++g_strategy_index_opening_range.bars;
   g_strategy_index_opening_range.valid =
      g_strategy_index_opening_range.bars == 30 &&
      g_strategy_index_opening_range.high > g_strategy_index_opening_range.low;
   g_strategy_index_opening_range.fingerprint =
      g_strategy_index_opening_range.valid
      ? ICT_RangeFingerprint(g_strategy_replay_budget_key,
                             g_strategy_index_opening_range.bars,
                             g_strategy_index_opening_range.low,
                             g_strategy_index_opening_range.high,
                             g_strategy_replay_tick_size)
      : 0;
  }

void Strategy_SetIndexWaitingState(ICT_SequenceResult &result)
  {
   ICT_ResetSequence(result);
   result.session = g_strategy_index_opening_range.valid
                    ? ICT_SESSION_INDEX_AM
                    : ICT_SESSION_NONE;
   result.budget_key = g_strategy_replay_budget_key;
   result.ny_date_key = g_strategy_replay_budget_key;
   if(g_strategy_index_opening_range.valid)
     {
      result.session_end_minute = 11 * 60;
      result.frozen_level_hash = g_strategy_index_opening_range.fingerprint;
      result.reference_hash = g_strategy_index_opening_range.fingerprint;
      result.outcome = "NO_EVENT";
     }
   else
      result.outcome = "OPENING_RANGE_INCOMPLETE";
  }

bool Strategy_UpdateIndexCache(const MqlRates &bar)
  {
   Strategy_AccumulateIndexOpeningRange(bar);
   if(!g_strategy_index_opening_range.valid)
     {
      Strategy_SetIndexWaitingState(g_strategy_cached_sequence);
      return true;
     }

   const bool current_event = ICT_IsEventBarInSession(bar,
                                                       g_strategy_replay_budget_key,
                                                       10 * 60,
                                                       11 * 60,
                                                       PeriodSeconds(PERIOD_M1));
   if(!current_event)
     {
      if(!g_strategy_cached_sequence.consumed)
         Strategy_SetIndexWaitingState(g_strategy_cached_sequence);
      return true;
     }

   int event_first = -1;
   int event_last = -1;
   if(!Strategy_FindNYWindowBounds(g_strategy_replay_budget_key,
                                   10 * 60,
                                   11 * 60,
                                   true,
                                   PeriodSeconds(PERIOD_M1),
                                   event_first,
                                   event_last))
      return false;

   int pivot_wing = 0;
   int reclaim_bars = 0;
   int max_bars_to_mss = 0;
   double min_fvg_atr = 0.0;
   double sl_buffer_atr = 0.0;
   double min_rr = 0.0;
   Strategy_ModeParameters(pivot_wing,
                           reclaim_bars,
                           max_bars_to_mss,
                           min_fvg_atr,
                           sl_buffer_atr,
                           min_rr);

   ICT_SequenceResult updated;
   ICT_BuildSequence(g_strategy_closed_rates,
                     g_strategy_closed_rate_count,
                     g_strategy_replay_budget_key,
                     g_strategy_replay_budget_key,
                     ICT_SESSION_INDEX_AM,
                     10 * 60,
                     11 * 60,
                     PeriodSeconds(PERIOD_M1),
                     g_strategy_index_opening_range.low,
                     g_strategy_index_opening_range.high,
                     g_strategy_index_opening_range.high,
                     g_strategy_index_opening_range.low,
                     g_strategy_index_opening_range.fingerprint,
                     g_strategy_index_opening_range.fingerprint,
                     pivot_wing,
                     reclaim_bars,
                     max_bars_to_mss,
                     min_fvg_atr,
                     sl_buffer_atr,
                     min_rr,
                     g_strategy_replay_tick_size,
                     g_strategy_replay_point,
                     updated,
                     event_first,
                     event_last,
                     Strategy_LogicalHistoryFirstIndex());
   if(g_strategy_cached_sequence.consumed &&
      (!updated.consumed ||
       updated.event_bar_time != g_strategy_cached_sequence.event_bar_time ||
       updated.frozen_level_hash != g_strategy_cached_sequence.frozen_level_hash ||
       updated.reference_hash != g_strategy_cached_sequence.reference_hash))
     {
      QM_LogEvent(QM_ERROR,
                  "ICT_INCREMENTAL_EVENT_DRIFT",
                  "{\"mode\":0,\"reason\":\"consumed_event_changed\"}");
      return false;
     }
   Strategy_CopySequence(updated, g_strategy_cached_sequence);
   return true;
  }

ICT_SessionKind Strategy_EventSessionForBar(const MqlRates &bar)
  {
   const int date_key = ICT_NYDateKey(bar.time);
   if(ICT_IsEventBarInSession(bar,
                              date_key,
                              2 * 60,
                              5 * 60,
                              PeriodSeconds(PERIOD_M5)))
      return ICT_SESSION_LONDON;
   return ICT_SESSION_NONE;
  }

bool Strategy_RebuildFxSession(const int date_key,
                               const ICT_SessionKind session,
                               ICT_SequenceResult &result,
                               string &failure_reason)
  {
   failure_reason = "invalid_session";
   if(session != ICT_SESSION_LONDON ||
      date_key != g_strategy_replay_budget_key)
      return false;

   const int reference_date = ICT_ShiftDateKey(date_key, -1);
   const int reference_start = 20 * 60;
   const int reference_end = 24 * 60;
   const int reference_bars = 48;
   int reference_first = -1;
   int reference_last = -1;
   if(!Strategy_FindNYWindowBounds(reference_date,
                                   reference_start,
                                   reference_end,
                                   false,
                                    PeriodSeconds(PERIOD_M5),
                                    reference_first,
                                    reference_last))
     {
      failure_reason = "ASIAN_REFERENCE_WINDOW_INCOMPLETE";
      return false;
     }

   ICT_LevelRange reference;
   if(!ICT_CollectNYRangeBounded(g_strategy_closed_rates,
                                 g_strategy_closed_rate_count,
                                 reference_first,
                                 reference_last,
                                 reference_date,
                                 reference_start,
                                 reference_end,
                                 reference_bars,
                                 g_strategy_replay_tick_size,
                                 reference))
     {
      failure_reason = "ASIAN_REFERENCE_INCOMPLETE";
      return false;
     }

   const int session_start = 2 * 60;
   const int session_end = 5 * 60;
   int event_first = -1;
   int event_last = -1;
   if(!Strategy_FindNYWindowBounds(date_key,
                                   session_start,
                                   session_end,
                                   true,
                                    PeriodSeconds(PERIOD_M5),
                                    event_first,
                                    event_last))
     {
      failure_reason = "SESSION_WINDOW_INCOMPLETE";
      return false;
     }

   int pivot_wing = 0;
   int reclaim_bars = 0;
   int max_bars_to_mss = 0;
   double min_fvg_atr = 0.0;
   double sl_buffer_atr = 0.0;
   double min_rr = 0.0;
   Strategy_ModeParameters(pivot_wing,
                           reclaim_bars,
                           max_bars_to_mss,
                           min_fvg_atr,
                           sl_buffer_atr,
                           min_rr);
   ICT_BuildSequence(g_strategy_closed_rates,
                     g_strategy_closed_rate_count,
                     date_key,
                     g_strategy_replay_budget_key,
                     session,
                     session_start,
                     session_end,
                     PeriodSeconds(PERIOD_M5),
                     reference.low,
                     reference.high,
                     reference.high,
                     reference.low,
                     reference.fingerprint,
                     reference.fingerprint,
                     pivot_wing,
                     reclaim_bars,
                     max_bars_to_mss,
                     min_fvg_atr,
                     sl_buffer_atr,
                     min_rr,
                     g_strategy_replay_tick_size,
                     g_strategy_replay_point,
                     result,
                     event_first,
                      event_last,
                      Strategy_LogicalHistoryFirstIndex());
   failure_reason = "ok";
   return true;
  }

bool Strategy_UpdateFxCache(const MqlRates &bar)
  {
   if(!g_strategy_fx_asian_range.valid)
      return true;
   const int date_key = ICT_NYDateKey(bar.time);
   const ICT_SessionKind current_session = Strategy_EventSessionForBar(bar);
   if(current_session == ICT_SESSION_NONE)
      return true;

   if(g_strategy_cached_sequence.consumed &&
      (g_strategy_cached_sequence.ny_date_key != date_key ||
       g_strategy_cached_sequence.session != current_session))
      return true;

   ICT_SequenceResult updated;
   string rebuild_failure = "";
   if(!Strategy_RebuildFxSession(date_key,
                                 current_session,
                                 updated,
                                 rebuild_failure))
     {
      // Incomplete reference/session data is a normal no-event state, but it
      // must be attributable. Log each date/session/reason combination once.
      const string incomplete_signature = StringFormat("%d|%d|%s",
                                                        date_key,
                                                        (int)current_session,
                                                        rebuild_failure);
      if(incomplete_signature != g_strategy_last_fx_incomplete_signature)
        {
         g_strategy_last_fx_incomplete_signature = incomplete_signature;
         QM_LogEvent(QM_INFO,
                     "ICT_FX_SESSION_INCOMPLETE",
                     StringFormat("{\"date_key\":%d,\"session\":%d,\"reason\":\"%s\"}",
                                  date_key,
                                  (int)current_session,
                                  QM_LoggerEscapeJson(rebuild_failure)));
        }
      return true;
     }
   g_strategy_last_fx_incomplete_signature = "";

   if(g_strategy_cached_sequence.consumed)
     {
      if(!updated.consumed ||
         updated.event_bar_time != g_strategy_cached_sequence.event_bar_time ||
         updated.frozen_level_hash != g_strategy_cached_sequence.frozen_level_hash ||
         updated.reference_hash != g_strategy_cached_sequence.reference_hash)
        {
         QM_LogEvent(QM_ERROR,
                     "ICT_INCREMENTAL_EVENT_DRIFT",
                     "{\"mode\":1,\"reason\":\"consumed_event_changed\"}");
         return false;
        }
      Strategy_CopySequence(updated, g_strategy_cached_sequence);
     }
   else if(updated.consumed)
      Strategy_CopySequence(updated, g_strategy_cached_sequence);
   return true;
  }

bool Strategy_AppendAndAdvanceCache(const datetime closed_bar)
  {
   if(g_strategy_closed_rate_count <= 0)
      return false;
   const datetime cached_last_time =
      g_strategy_closed_rates[g_strategy_closed_rate_count - 1].time;
   const int cached_shift = iBarShift(_Symbol,
                                      (ENUM_TIMEFRAMES)_Period,
                                      cached_last_time,
                                      true);
   if(cached_shift < 2)
      return false;
   const int missing = cached_shift - 1;
   MqlRates delta[];
   ArraySetAsSeries(delta, false);
   const int copied = CopyRates(_Symbol,
                                (ENUM_TIMEFRAMES)_Period,
                                1,
                                missing,
                                delta); // closed-bar delta only; never a full replay.
   ArraySetAsSeries(delta, false);
   if(copied != missing || delta[missing - 1].time != closed_bar ||
      delta[0].time <= cached_last_time)
      return false;

   const int new_count = g_strategy_closed_rate_count + missing;
   const int reserve = Strategy_ReplayRequestedBars() +
                       ((strategy_mode == ICT_MODE_INDEX_MSS_FVG) ? 1600 : 2200);
   if(ArrayResize(g_strategy_closed_rates, new_count, reserve) != new_count)
      return false;

   datetime previous_time = cached_last_time;
   for(int i = 0; i < missing; ++i)
     {
      if(delta[i].time <= previous_time ||
         Strategy_BudgetKeyAtTime(delta[i].time) != g_strategy_replay_budget_key)
         return false;
      g_strategy_closed_rates[g_strategy_closed_rate_count] = delta[i];
      ++g_strategy_closed_rate_count;
      previous_time = delta[i].time;
      const bool advanced = (strategy_mode == ICT_MODE_INDEX_MSS_FVG)
                            ? Strategy_UpdateIndexCache(delta[i])
                            : Strategy_UpdateFxCache(delta[i]);
      if(!advanced)
         return false;
     }
   return true;
  }

bool Strategy_ReconstructCached(const datetime closed_bar,
                                ICT_SequenceResult &result)
  {
   ICT_ResetSequence(result);
   if(closed_bar <= 0)
     {
      result.outcome = "REPLAY_CACHE_NOT_READY";
      return false;
     }

   const int current_budget_key = Strategy_BudgetKeyAtTime(closed_bar);
   if(!g_strategy_replay_cache_ready)
     {
      if(current_budget_key != g_strategy_replay_budget_key)
         return Strategy_Reconstruct(result); // retry only at a new budget edge.
      if(g_strategy_replay_retry_not_before > 0 &&
         closed_bar >= g_strategy_replay_retry_not_before)
        {
         QM_LogEvent(QM_WARN,
                     "ICT_REPLAY_CACHE_RECOVERY",
                     StringFormat("{\"budget_key\":%d,\"failure_count\":%d}",
                                  current_budget_key,
                                  g_strategy_replay_failure_count));
         return Strategy_Reconstruct(result); // bounded closed-bar backoff recovery.
        }
      result.outcome = "REPLAY_CACHE_NOT_READY";
      return false;
     }
   if(current_budget_key != g_strategy_replay_budget_key)
      return Strategy_Reconstruct(result); // one full replay at the budget edge.

   if(!Strategy_AppendAndAdvanceCache(closed_bar))
     {
      g_strategy_replay_cache_ready = false; // fail closed until bounded recovery.
      Strategy_ScheduleReplayRetry();
      result.outcome = "REPLAY_CACHE_CONTINUITY_FAILED";
      QM_LogEvent(QM_ERROR,
                  "ICT_INCREMENTAL_CACHE_FAILED",
                  StringFormat("{\"budget_key\":%d,\"closed_bar\":%I64d}",
                               current_budget_key,
                               (long)closed_bar));
      return false;
     }
   Strategy_CopySequence(g_strategy_cached_sequence, result);
   return true;
  }

bool Strategy_IsOurPendingType(const ENUM_ORDER_TYPE type)
  {
   return type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT;
  }

bool Strategy_HasBrokerPositionOrPending()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true; // fail closed.

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic &&
         Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
    return false;
  }

bool Strategy_HasPositionOrPending()
  {
   return g_strategy_virtual_limit_active ||
          Strategy_HasBrokerPositionOrPending();
  }

int Strategy_BudgetKeyAtTime(const datetime event_time)
  {
   return ICT_NYDateKey(event_time);
  }

uint Strategy_StringFingerprint(const string value)
  {
   uint hash = 2166136261;
   for(int i = 0; i < StringLen(value); ++i)
      hash = (hash ^ (uint)StringGetCharacter(value, i)) * 16777619;
   return hash;
  }

string Strategy_AttemptKeyBase(const ICT_SequenceResult &signal)
  {
   const long account_login = AccountInfoInteger(ACCOUNT_LOGIN);
   const int magic = QM_FrameworkMagic();
   if(account_login <= 0 || magic <= 0 || signal.budget_key <= 0)
      return "";
   const uint server_hash = Strategy_StringFingerprint(AccountInfoString(ACCOUNT_SERVER));
   return StringFormat("Q09A_%08X_%I64d_%d_%d_%d",
                       server_hash,
                       account_login,
                       magic,
                       (int)strategy_mode,
                       signal.budget_key);
  }

string Strategy_AttemptHistoryComment(const ICT_SequenceResult &signal)
  {
   return StringFormat("I09:%d:%08X:%08X",
                       signal.budget_key,
                       signal.frozen_level_hash,
                       signal.reference_hash);
  }

void Strategy_LogAttemptStateIssue(const string event_name,
                                   const ICT_SequenceResult &signal,
                                   const string reason,
                                   const int stored_state,
                                   const datetime stored_event_time,
                                   const uint stored_level_hash,
                                   const uint stored_reference_hash)
  {
   QM_LogEvent(QM_ERROR,
               event_name,
               StringFormat("{\"reason\":\"%s\",\"budget_key\":%d,\"current_event_time\":%I64d,\"current_level_hash\":%u,\"current_reference_hash\":%u,\"stored_state\":%d,\"stored_event_time\":%I64d,\"stored_level_hash\":%u,\"stored_reference_hash\":%u}",
                            QM_LoggerEscapeJson(reason),
                            signal.budget_key,
                            (long)signal.event_bar_time,
                            signal.frozen_level_hash,
                            signal.reference_hash,
                            stored_state,
                            (long)stored_event_time,
                            stored_level_hash,
                            stored_reference_hash));
  }

bool Strategy_AttemptIdentityValid(const ICT_SequenceResult &signal)
  {
   return signal.consumed && signal.budget_key > 0 &&
          signal.event_bar_time > 0 && signal.frozen_level_hash != 0 &&
          signal.reference_hash != 0;
  }

bool Strategy_ReadPersistentUint(const string key, uint &value)
  {
   value = 0;
   ResetLastError();
   const double raw = GlobalVariableGet(key);
   const int error = GetLastError();
   if(error != 0 || !MathIsValidNumber(raw) || raw < 0.0 || raw > 4294967295.0)
      return false;
   value = (uint)(long)MathRound(raw);
   return true;
  }

bool Strategy_LoadPersistentAttempt(const ICT_SequenceResult &signal,
                                    bool &exists,
                                    int &state,
                                    datetime &event_time,
                                    uint &level_hash,
                                    uint &reference_hash)
  {
   exists = false;
   state = ICT_ATTEMPT_NONE;
   event_time = 0;
   level_hash = 0;
   reference_hash = 0;
   const string base = Strategy_AttemptKeyBase(signal);
   if(base == "")
     {
      Strategy_LogAttemptStateIssue("ICT_ATTEMPT_STATE_INVALID",
                                    signal,
                                    "persistent_key_identity_unavailable",
                                    ICT_ATTEMPT_NONE,
                                    0,
                                    0,
                                    0);
      return false;
     }

   const string state_key = base + "_S";
   const string event_key = base + "_E";
   const string level_key = base + "_L";
   const string reference_key = base + "_R";
   const bool state_exists = GlobalVariableCheck(state_key);
   const bool event_exists = GlobalVariableCheck(event_key);
   const bool level_exists = GlobalVariableCheck(level_key);
   const bool reference_exists = GlobalVariableCheck(reference_key);
   if(!state_exists && !event_exists && !level_exists && !reference_exists)
      return true;
   if(!state_exists || !event_exists || !level_exists || !reference_exists)
     {
      Strategy_LogAttemptStateIssue("ICT_ATTEMPT_STATE_CORRUPT",
                                    signal,
                                    "partial_persistent_attempt_state",
                                    ICT_ATTEMPT_NONE,
                                    0,
                                    0,
                                    0);
      return false;
     }

   uint raw_state = 0;
   uint raw_event_time = 0;
   if(!Strategy_ReadPersistentUint(state_key, raw_state) ||
      !Strategy_ReadPersistentUint(event_key, raw_event_time) ||
      !Strategy_ReadPersistentUint(level_key, level_hash) ||
      !Strategy_ReadPersistentUint(reference_key, reference_hash) ||
      (raw_state != ICT_ATTEMPT_CONSUMED && raw_state != ICT_ATTEMPT_SUBMITTED) ||
      raw_event_time == 0)
     {
      Strategy_LogAttemptStateIssue("ICT_ATTEMPT_STATE_CORRUPT",
                                    signal,
                                    "unreadable_persistent_attempt_state",
                                    (int)raw_state,
                                    (datetime)raw_event_time,
                                    level_hash,
                                    reference_hash);
      return false;
     }
   exists = true;
   state = (int)raw_state;
   event_time = (datetime)raw_event_time;
   return true;
  }

bool Strategy_AttemptIdentityMatches(const ICT_SequenceResult &signal,
                                     const int stored_state,
                                     const datetime stored_event_time,
                                     const uint stored_level_hash,
                                     const uint stored_reference_hash,
                                     const string source)
  {
   if(stored_event_time != signal.event_bar_time)
     {
      Strategy_LogAttemptStateIssue("ICT_ATTEMPT_EVENT_DRIFT",
                                    signal,
                                    source + "_same_budget_event_drift",
                                    stored_state,
                                    stored_event_time,
                                    stored_level_hash,
                                    stored_reference_hash);
      return false;
     }
   if(stored_level_hash != signal.frozen_level_hash ||
      stored_reference_hash != signal.reference_hash)
     {
      Strategy_LogAttemptStateIssue("ICT_ATTEMPT_HASH_DRIFT",
                                    signal,
                                    source + "_same_budget_hash_drift",
                                    stored_state,
                                    stored_event_time,
                                    stored_level_hash,
                                    stored_reference_hash);
      return false;
     }
   return true;
  }

bool Strategy_BindConsumedAttempt(const ICT_SequenceResult &signal)
  {
   if(!Strategy_AttemptIdentityValid(signal))
     {
      Strategy_LogAttemptStateIssue("ICT_ATTEMPT_STATE_INVALID",
                                    signal,
                                    "invalid_consumed_attempt_identity",
                                    ICT_ATTEMPT_NONE,
                                    0,
                                    0,
                                    0);
      return false;
     }

   // Tester state is deliberately process-local. Terminal GlobalVariables are
   // shared across tester runs and would contaminate deterministic duplicates.
   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      if(g_tester_attempt_state == ICT_ATTEMPT_NONE ||
         g_tester_attempt_budget_key != signal.budget_key)
        {
         g_tester_attempt_state = ICT_ATTEMPT_CONSUMED;
         g_tester_attempt_budget_key = signal.budget_key;
         g_tester_attempt_event_time = signal.event_bar_time;
         g_tester_attempt_level_hash = signal.frozen_level_hash;
         g_tester_attempt_reference_hash = signal.reference_hash;
         return true;
        }
      if(!Strategy_AttemptIdentityMatches(signal,
                                          g_tester_attempt_state,
                                          g_tester_attempt_event_time,
                                          g_tester_attempt_level_hash,
                                          g_tester_attempt_reference_hash,
                                          "tester"))
         return false;
      return g_tester_attempt_state == ICT_ATTEMPT_CONSUMED;
     }

   bool exists = false;
   int stored_state = ICT_ATTEMPT_NONE;
   datetime stored_event_time = 0;
   uint stored_level_hash = 0;
   uint stored_reference_hash = 0;
   if(!Strategy_LoadPersistentAttempt(signal,
                                      exists,
                                      stored_state,
                                      stored_event_time,
                                      stored_level_hash,
                                      stored_reference_hash))
      return false;
   if(exists)
     {
      if(!Strategy_AttemptIdentityMatches(signal,
                                          stored_state,
                                          stored_event_time,
                                          stored_level_hash,
                                          stored_reference_hash,
                                          "live"))
         return false;
      return stored_state == ICT_ATTEMPT_CONSUMED;
     }

   const string base = Strategy_AttemptKeyBase(signal);
   if(base == "")
      return false;
   // Identity is written before state. A crash or failed write leaves a partial
   // record that subsequent reads treat as consumed/fail-closed.
   if(GlobalVariableSet(base + "_L", (double)signal.frozen_level_hash) == 0 ||
      GlobalVariableSet(base + "_R", (double)signal.reference_hash) == 0 ||
      GlobalVariableSet(base + "_E", (double)signal.event_bar_time) == 0 ||
      GlobalVariableSet(base + "_S", (double)ICT_ATTEMPT_CONSUMED) == 0)
     {
      Strategy_LogAttemptStateIssue("ICT_ATTEMPT_PERSIST_FAILED",
                                    signal,
                                    "consumed_state_write_failed",
                                    ICT_ATTEMPT_NONE,
                                    0,
                                    0,
                                    0);
      return false;
     }
   GlobalVariablesFlush();
   return true;
  }

void Strategy_DeletePersistentKeyIfPresent(const string key)
  {
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
  }

void Strategy_DeleteVirtualIntentFields(const ICT_SequenceResult &signal)
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return;
   const string base = Strategy_AttemptKeyBase(signal);
   if(base == "")
      return;
   Strategy_DeletePersistentKeyIfPresent(base + "_VD");
   Strategy_DeletePersistentKeyIfPresent(base + "_VP");
   Strategy_DeletePersistentKeyIfPresent(base + "_VW");
   Strategy_DeletePersistentKeyIfPresent(base + "_VT");
   Strategy_DeletePersistentKeyIfPresent(base + "_VX");
   Strategy_DeletePersistentKeyIfPresent(base + "_VF");
   GlobalVariablesFlush();
  }

bool Strategy_PersistVirtualIntentFields(const ICT_SequenceResult &signal,
                                         const QM_EntryRequest &request,
                                         const datetime deadline)
  {
   const string base = Strategy_AttemptKeyBase(signal);
   if(base == "" || deadline <= TimeCurrent() ||
      (signal.direction != 1 && signal.direction != -1) ||
      request.price <= 0.0 || request.sl <= 0.0 || request.tp <= 0.0 ||
      signal.fvg_bar_time <= 0)
      return false;

   // Intent fields are durable before the CONSUMED->SUBMITTED CAS. A crash
   // before the CAS cannot arm an order; a crash after it can restore exactly
   // this immutable intent without reconstructing a different opportunity.
   if(GlobalVariableSet(base + "_VD", (double)signal.direction) == 0 ||
      GlobalVariableSet(base + "_VP", request.price) == 0 ||
      GlobalVariableSet(base + "_VW", request.sl) == 0 ||
      GlobalVariableSet(base + "_VT", request.tp) == 0 ||
      GlobalVariableSet(base + "_VX", (double)deadline) == 0 ||
      GlobalVariableSet(base + "_VF", (double)signal.fvg_bar_time) == 0)
     {
      QM_LogEvent(QM_ERROR,
                  "ICT_VIRTUAL_LIMIT_PERSIST_FAILED",
                  StringFormat("{\"budget_key\":%d}", signal.budget_key));
      return false;
     }
   GlobalVariablesFlush();
   return true;
  }

bool Strategy_ClaimAttempt(const ICT_SequenceResult &signal,
                           const QM_EntryRequest &request,
                           const datetime deadline)
  {
   if(!Strategy_BindConsumedAttempt(signal))
      return false;

    if(MQLInfoInteger(MQL_TESTER) != 0)
      {
       g_tester_attempt_state = ICT_ATTEMPT_SUBMITTED;
      return true;
     }

   bool exists = false;
   int stored_state = ICT_ATTEMPT_NONE;
   datetime stored_event_time = 0;
   uint stored_level_hash = 0;
   uint stored_reference_hash = 0;
   if(!Strategy_LoadPersistentAttempt(signal,
                                      exists,
                                      stored_state,
                                      stored_event_time,
                                      stored_level_hash,
                                      stored_reference_hash) ||
      !exists || stored_state != ICT_ATTEMPT_CONSUMED ||
       !Strategy_AttemptIdentityMatches(signal,
                                       stored_state,
                                       stored_event_time,
                                       stored_level_hash,
                                       stored_reference_hash,
                                       "submit"))
      return false;

   if(!Strategy_PersistVirtualIntentFields(signal, request, deadline))
      return false;

    const string state_key = Strategy_AttemptKeyBase(signal) + "_S";
   ResetLastError();
    if(!GlobalVariableSetOnCondition(state_key,
                                    (double)ICT_ATTEMPT_SUBMITTED,
                                    (double)ICT_ATTEMPT_CONSUMED))
     {
      Strategy_LogAttemptStateIssue("ICT_ATTEMPT_SUBMIT_TRANSITION_FAILED",
                                    signal,
                                    "consumed_to_submitted_cas_failed",
                                    stored_state,
                                    stored_event_time,
                                    stored_level_hash,
                                     stored_reference_hash);
      Strategy_DeleteVirtualIntentFields(signal);
      return false;
     }
   GlobalVariablesFlush();
    return true;
  }

void Strategy_VoidPersistedVirtualIntentOnInit(const ICT_SequenceResult &signal)
  {
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return;
   const string base = Strategy_AttemptKeyBase(signal);
   if(base == "")
      return;
   const bool has_virtual_fields =
      GlobalVariableCheck(base + "_VD") ||
      GlobalVariableCheck(base + "_VP") ||
      GlobalVariableCheck(base + "_VW") ||
      GlobalVariableCheck(base + "_VT") ||
      GlobalVariableCheck(base + "_VX") ||
      GlobalVariableCheck(base + "_VF");
   if(!has_virtual_fields)
      return;

   bool exists = false;
   int stored_state = ICT_ATTEMPT_NONE;
   datetime stored_event_time = 0;
   uint stored_level_hash = 0;
   uint stored_reference_hash = 0;
   const bool readable = Strategy_LoadPersistentAttempt(signal,
                                                         exists,
                                                         stored_state,
                                                         stored_event_time,
                                                         stored_level_hash,
                                                         stored_reference_hash);
   const bool exact_submitted = readable && exists &&
      stored_state == ICT_ATTEMPT_SUBMITTED &&
      Strategy_AttemptIdentityMatches(signal,
                                      stored_state,
                                      stored_event_time,
                                      stored_level_hash,
                                      stored_reference_hash,
                                      "restart_void");
   QM_LogEvent(exact_submitted ? QM_WARN : QM_ERROR,
               exact_submitted ? "ICT_VIRTUAL_LIMIT_RESTART_VOID"
                               : "ICT_VIRTUAL_LIMIT_PARTIAL_STATE_VOID",
               StringFormat("{\"budget_key\":%d,\"stored_state\":%d}",
                            signal.budget_key,
                            stored_state));
   // A restart cannot prove that no touch, news block, governor lock or stale
   // heartbeat happened while the EA was absent. Never resurrect the intent.
   Strategy_DeleteVirtualIntentFields(signal);
  }

bool Strategy_HistoryReadFailed(const ICT_SequenceResult &signal,
                                const string reason)
  {
   QM_LogEvent(QM_ERROR,
               "ICT_HISTORY_RECONSTRUCTION_FAILED",
               StringFormat("{\"budget_key\":%d,\"reason\":\"%s\"}",
                            signal.budget_key,
                            QM_LoggerEscapeJson(reason)));
   return false;
  }

bool Strategy_HistoryBudgetClear(const ICT_SequenceResult &signal)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || signal.budget_key <= 0 ||
      !Strategy_BindConsumedAttempt(signal))
      return false;
   const datetime now = TimeCurrent();
   const int lookback_days = 4;
   if(!HistorySelect(now - lookback_days * 86400, now))
      return Strategy_HistoryReadFailed(signal, "history_select_failed");

   const int order_total = HistoryOrdersTotal();
   if(order_total < 0)
      return Strategy_HistoryReadFailed(signal, "history_orders_total_invalid");
   for(int i = 0; i < order_total; ++i)
     {
      ResetLastError();
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         return Strategy_HistoryReadFailed(signal, "history_order_ticket_unavailable");
      const string order_symbol = HistoryOrderGetString(ticket, ORDER_SYMBOL);
      const int order_magic = (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC);
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
      const datetime setup_time =
         (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP);
      const string order_comment = HistoryOrderGetString(ticket, ORDER_COMMENT);
      if(GetLastError() != 0)
         return Strategy_HistoryReadFailed(signal, "history_order_properties_unavailable");
      if(order_symbol != _Symbol || order_magic != magic ||
         !Strategy_IsOurPendingType(order_type))
         continue;
      if(setup_time <= 0)
         return Strategy_HistoryReadFailed(signal, "history_order_setup_time_invalid");
      if(Strategy_BudgetKeyAtTime(setup_time) == signal.budget_key)
        {
         const string expected_comment = Strategy_AttemptHistoryComment(signal);
         if(StringFind(order_comment, "I09:") == 0 &&
            order_comment != expected_comment)
            Strategy_LogAttemptStateIssue("ICT_ATTEMPT_HISTORY_IDENTITY_DRIFT",
                                          signal,
                                          "same_budget_history_comment_drift",
                                          ICT_ATTEMPT_SUBMITTED,
                                          setup_time,
                                          0,
                                          0);
         return false;
        }
     }

   const int deal_total = HistoryDealsTotal();
   if(deal_total < 0)
      return Strategy_HistoryReadFailed(signal, "history_deals_total_invalid");
   for(int i = 0; i < deal_total; ++i)
     {
      ResetLastError();
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         return Strategy_HistoryReadFailed(signal, "history_deal_ticket_unavailable");
      const string deal_symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      const int deal_magic = (int)HistoryDealGetInteger(ticket, DEAL_MAGIC);
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(GetLastError() != 0)
         return Strategy_HistoryReadFailed(signal, "history_deal_properties_unavailable");
      if(deal_symbol != _Symbol || deal_magic != magic)
         continue;
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      if(deal_time <= 0)
         return Strategy_HistoryReadFailed(signal, "history_deal_time_invalid");
      if(Strategy_BudgetKeyAtTime(deal_time) == signal.budget_key)
         return false;
     }
   return true;
  }

bool Strategy_ShouldCancelOrder(const datetime setup_time,
                                const datetime now_time)
  {
   const int setup_date = ICT_NYDateKey(setup_time);
   const int now_date = ICT_NYDateKey(now_time);
   if(setup_date != now_date)
      return true;
   const int setup_minute = ICT_NYMinute(setup_time);
   const int now_minute = ICT_NYMinute(now_time);
   if(strategy_mode == ICT_MODE_INDEX_MSS_FVG)
      return now_minute >= 11 * 60;
   if(setup_minute >= 2 * 60 && setup_minute < 5 * 60)
      return now_minute >= 5 * 60;
   if(setup_minute >= 7 * 60 && setup_minute < 10 * 60)
      return now_minute >= 10 * 60;
   return true;
  }

void Strategy_ManageExposure()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   const datetime now = TimeCurrent();

   // This version never parks exposure-creating orders at the broker. Remove
   // any orphan left by an older binary before evaluating any entry gate.
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         !Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, "ict_server_pending_forbidden");
     }

   const int now_date = ICT_NYDateKey(now);
   const int now_minute = ICT_NYMinute(now);
   const int flat_minute = (strategy_mode == ICT_MODE_INDEX_MSS_FVG)
                           ? 15 * 60 + 55
                           : 16 * 60;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0 || ICT_NYDateKey(open_time) != now_date || now_minute >= flat_minute)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_RunMandatorySafety()
  {
   // Canonical V5 order: portfolio kill-switch first, then the framework
   // Friday sweep, then strategy-specific pending cancellation/hard flats.
   if(!QM_KillSwitchCheck())
      return false;
   const bool friday_close_handled = QM_FrameworkHandleFridayClose();
   Strategy_ManageExposure();
   return !friday_close_handled;
  }

double Strategy_NormalizeToTick(const double price, const int rounding_direction)
  {
   if(price <= 0.0)
      return 0.0;
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tick_size <= 0.0)
      return 0.0;

   const double tick_units = price / tick_size;
   double normalized_units = MathRound(tick_units);
   if(rounding_direction < 0)
      normalized_units = MathFloor(tick_units + 1e-12);
   else if(rounding_direction > 0)
      normalized_units = MathCeil(tick_units - 1e-12);
   return NormalizeDouble(normalized_units * tick_size, _Digits);
  }

bool Strategy_QuoteAllowsFreshVirtualLimit(const int direction,
                                           const double entry,
                                           const double stop,
                                           const double target,
                                           string &failure_reason)
  {
   failure_reason = "unknown";
   MqlTick quote;
   ZeroMemory(quote);
   if(!SymbolInfoTick(_Symbol, quote))
     {
      failure_reason = "quote_unavailable_at_eligibility";
      return false;
     }
   const double ask = quote.ask;
   const double bid = quote.bid;
   if(ask <= 0.0 || bid <= 0.0 || ask < bid ||
      entry <= 0.0 || stop <= 0.0 || target <= 0.0)
     {
      failure_reason = "quote_or_price_invalid_at_eligibility";
      return false;
     }
   if(direction > 0)
     {
      // Ask at/below the proximal edge means the earliest FVG was already
      // touched when it became eligible; this attempt gets no later rescue.
      if(ask <= entry)
        {
         failure_reason = "edge_already_touched_at_eligibility";
         return false;
        }
      if(stop >= entry || target <= entry)
        {
         failure_reason = "directional_geometry_invalid_at_eligibility";
         return false;
        }
     }
   else if(direction < 0)
     {
      if(bid >= entry)
        {
         failure_reason = "edge_already_touched_at_eligibility";
         return false;
        }
      if(stop <= entry || target >= entry)
        {
         failure_reason = "directional_geometry_invalid_at_eligibility";
         return false;
        }
     }
   else
     {
      failure_reason = "direction_invalid_at_eligibility";
      return false;
     }
   failure_reason = "ok";
   return true;
  }

int Strategy_SecondsUntilSessionEnd(const ICT_SequenceResult &signal)
  {
   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(ICT_BrokerToNewYork(TimeCurrent()), ny);
   const int now_seconds = ny.hour * 3600 + ny.min * 60 + ny.sec;
   return signal.session_end_minute * 60 - now_seconds;
  }

void Strategy_InitRequest(QM_EntryRequest &request)
  {
   request.type = QM_BUY_LIMIT;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;
  }

bool Strategy_BuildEntryRequest(const ICT_SequenceResult &signal,
                                QM_EntryRequest &request,
                                string &failure_reason)
  {
   failure_reason = "unknown";
   Strategy_InitRequest(request);
   if(!signal.signal_valid || !signal.consumed || signal.ambiguous)
     {
      failure_reason = "signal_invalid_or_ambiguous";
      return false;
     }
   const int expiration_seconds = Strategy_SecondsUntilSessionEnd(signal);
   if(expiration_seconds <= 0)
     {
      failure_reason = "session_closed";
      return false;
     }

   request.type = (signal.direction > 0) ? QM_BUY_LIMIT : QM_SELL_LIMIT;
   request.price = Strategy_NormalizeToTick(signal.entry, 0);
   // Stops are rounded away from the entry so grid alignment can never make
   // the frozen structural stop less conservative.
   request.sl = Strategy_NormalizeToTick(signal.stop,
                                         (signal.direction > 0) ? -1 : 1);
   request.tp = Strategy_NormalizeToTick(signal.target, 0);
   // Compact 30-character history identity: budget + both replay hashes.
    request.reason = Strategy_AttemptHistoryComment(signal);
    request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0; // virtual intent; never sent as a pending.

    if(!Strategy_QuoteAllowsFreshVirtualLimit(signal.direction,
                                              request.price,
                                              request.sl,
                                              request.tp,
                                              failure_reason))
      return false;

   const double risk = MathAbs(request.price - request.sl);
   const double reward = (signal.direction > 0) ? request.tp - request.price
                                                : request.price - request.tp;
   int pivot_wing = 0;
   int reclaim_bars = 0;
   int max_bars_to_mss = 0;
   double min_fvg_atr = 0.0;
   double sl_buffer_atr = 0.0;
   double min_rr = 0.0;
   Strategy_ModeParameters(pivot_wing,
                           reclaim_bars,
                           max_bars_to_mss,
                           min_fvg_atr,
                           sl_buffer_atr,
                           min_rr);
   if(risk <= 0.0 || reward <= 0.0 || reward / risk + 1e-12 < min_rr)
     {
      failure_reason = "rr_after_tick_rounding";
      return false;
     }
   failure_reason = "ok";
   return true;
  }

bool Strategy_EntryNewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2Fresh(_Symbol,
                                      broker_time,
                                      qm_news_temporal,
                                      qm_news_compliance);
    return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
  }

bool Strategy_ComputeVirtualLimitDeadline(const ICT_SequenceResult &signal,
                                          const datetime broker_now,
                                          datetime &deadline,
                                          string &failure_reason)
  {
   deadline = 0;
   failure_reason = "unknown";
   const int seconds_until_session_end = Strategy_SecondsUntilSessionEnd(signal);
   if(broker_now <= 0 || seconds_until_session_end <= 0)
     {
      failure_reason = "session_closed";
      return false;
     }
   const datetime session_deadline = broker_now + seconds_until_session_end;
   datetime next_news_block = 0;
   const QM_NewsBlockStartResult news_result = QM_NewsNextBlockStart(
      _Symbol,
      broker_now,
      session_deadline,
      qm_news_temporal,
      qm_news_compliance,
      next_news_block);
   if(news_result == QM_NEWS_BLOCKSTART_DATA_ERROR)
     {
      failure_reason = "news_boundary_data_error";
      return false;
     }
   deadline = session_deadline;
   if(news_result == QM_NEWS_BLOCKSTART_FOUND)
     {
      if(next_news_block <= broker_now)
        {
         failure_reason = "news_boundary_already_active";
         return false;
        }
      if(next_news_block < deadline)
         deadline = next_news_block;
     }
   if(deadline <= broker_now)
     {
      failure_reason = "immutable_deadline_invalid";
      return false;
     }
   failure_reason = "ok";
   return true;
  }

void Strategy_ResetVirtualLimitMemory()
  {
   g_strategy_virtual_limit_active = false;
   g_strategy_virtual_limit_deadline = 0;
   g_strategy_virtual_limit_last_gate_time = 0;
   ICT_ResetSequence(g_strategy_virtual_limit_signal);
   Strategy_InitRequest(g_strategy_virtual_limit_request);
  }

void Strategy_DisarmVirtualLimit(const string reason)
  {
   if(!g_strategy_virtual_limit_active)
      return;
   const int budget_key = g_strategy_virtual_limit_signal.budget_key;
   const datetime fvg_time = g_strategy_virtual_limit_signal.fvg_bar_time;
   Strategy_DeleteVirtualIntentFields(g_strategy_virtual_limit_signal);
   Strategy_ResetVirtualLimitMemory();
   QM_LogEvent(QM_INFO,
               "ICT_VIRTUAL_LIMIT_VOID",
               StringFormat("{\"reason\":\"%s\",\"budget_key\":%d,\"fvg_time\":%I64d}",
                            QM_LoggerEscapeJson(reason),
                            budget_key,
                            (long)fvg_time));
  }

bool Strategy_ArmVirtualLimit(const ICT_SequenceResult &signal,
                              const QM_EntryRequest &request,
                              const datetime deadline)
  {
   if(g_strategy_virtual_limit_active || deadline <= TimeCurrent())
      return false;
   if(!Strategy_ClaimAttempt(signal, request, deadline))
      return false;

   Strategy_CopySequence(signal, g_strategy_virtual_limit_signal);
   Strategy_InitRequest(g_strategy_virtual_limit_request);
   g_strategy_virtual_limit_request.type = request.type;
   g_strategy_virtual_limit_request.price = request.price;
   g_strategy_virtual_limit_request.sl = request.sl;
   g_strategy_virtual_limit_request.tp = request.tp;
   g_strategy_virtual_limit_request.reason = request.reason;
   g_strategy_virtual_limit_request.symbol_slot = request.symbol_slot;
   g_strategy_virtual_limit_request.expiration_seconds = 0;
   g_strategy_virtual_limit_deadline = deadline;
   g_strategy_virtual_limit_last_gate_time = TimeCurrent();
   g_strategy_virtual_limit_active = true;
   QM_LogEvent(QM_INFO,
               "ICT_VIRTUAL_LIMIT_ARMED",
               StringFormat("{\"budget_key\":%d,\"direction\":%d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"deadline\":%I64d}",
                            signal.budget_key,
                            signal.direction,
                            request.price,
                            request.sl,
                            request.tp,
                            (long)deadline));
   return true;
  }

bool Strategy_VirtualLimitGateAllows(const datetime broker_now,
                                     string &block_reason)
  {
   block_reason = "unknown";
   if(!g_strategy_virtual_limit_active)
     {
      block_reason = "not_armed";
      return false;
     }
   if(MQLInfoInteger(MQL_TESTER) == 0 &&
      (g_strategy_virtual_limit_last_gate_time <= 0 ||
       broker_now < g_strategy_virtual_limit_last_gate_time ||
       broker_now - g_strategy_virtual_limit_last_gate_time >
          strategy_governor_heartbeat_max_age_seconds))
     {
      block_reason = "gate_continuity_gap";
      return false;
     }
   if(broker_now <= 0 || g_strategy_virtual_limit_deadline <= 0 ||
      broker_now >= g_strategy_virtual_limit_deadline)
     {
      block_reason = "immutable_deadline";
      return false;
     }
   if(!Strategy_EntryNewsAllows(broker_now))
     {
      block_reason = "news_blackout";
      return false;
     }
   if(!Strategy_GovernorAllowsEntry())
     {
      block_reason = "governor_block";
      return false;
     }
   g_strategy_virtual_limit_last_gate_time = broker_now;
   block_reason = "allow";
   return true;
  }

bool Strategy_VirtualLimitTouched(const MqlTick &quote)
  {
   if(!g_strategy_virtual_limit_active || quote.ask <= 0.0 || quote.bid <= 0.0 ||
      quote.ask < quote.bid)
      return false;
   if(g_strategy_virtual_limit_signal.direction > 0)
      return quote.ask <= g_strategy_virtual_limit_request.price;
   return quote.bid >= g_strategy_virtual_limit_request.price;
  }

bool Strategy_BuildTriggeredMarketRequest(const MqlTick &quote,
                                          QM_EntryRequest &market_request,
                                          double &market_price,
                                          string &failure_reason)
  {
   failure_reason = "unknown";
   if(quote.ask <= 0.0 || quote.bid <= 0.0 || quote.ask < quote.bid)
     {
      failure_reason = "trigger_quote_invalid";
      return false;
     }
   market_price = (g_strategy_virtual_limit_signal.direction > 0)
                  ? quote.ask : quote.bid;
   const double broker_reference_price =
      (g_strategy_virtual_limit_signal.direction > 0) ? quote.bid : quote.ask;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stops_level = 0;
   if(market_price <= 0.0 || broker_reference_price <= 0.0 || point <= 0.0 ||
      !SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stops_level) ||
      stops_level < 0)
     {
      failure_reason = "trigger_quote_or_symbol_invalid";
      return false;
     }

   const double stop = g_strategy_virtual_limit_request.sl;
   const double target = g_strategy_virtual_limit_request.tp;
   const double minimum_distance = (double)stops_level * point;
   const double comparison_epsilon = point * 1e-7;
   double risk = 0.0;
   double reward = 0.0;
   double stop_distance = 0.0;
   double target_distance = 0.0;
   if(g_strategy_virtual_limit_signal.direction > 0)
     {
      risk = market_price - stop;
      reward = target - market_price;
      // Buy positions close on Bid, so broker stop constraints are measured
      // from Bid even though executable entry economics use Ask.
      stop_distance = broker_reference_price - stop;
      target_distance = target - broker_reference_price;
     }
   else
     {
      risk = stop - market_price;
      reward = market_price - target;
      // Sell positions close on Ask, so broker stop constraints are measured
      // from Ask even though executable entry economics use Bid.
      stop_distance = stop - broker_reference_price;
      target_distance = broker_reference_price - target;
     }
   if(risk <= 0.0 || reward <= 0.0)
     {
      failure_reason = "trigger_beyond_stop_or_target";
      return false;
     }
   if(stop_distance + comparison_epsilon < minimum_distance ||
      target_distance + comparison_epsilon < minimum_distance)
     {
      failure_reason = "trigger_broker_stop_distance";
      return false;
     }

   int pivot_wing = 0;
   int reclaim_bars = 0;
   int max_bars_to_mss = 0;
   double min_fvg_atr = 0.0;
   double sl_buffer_atr = 0.0;
   double min_rr = 0.0;
   Strategy_ModeParameters(pivot_wing,
                           reclaim_bars,
                           max_bars_to_mss,
                           min_fvg_atr,
                           sl_buffer_atr,
                           min_rr);
   if(reward / risk + 1e-12 < min_rr)
     {
      failure_reason = "trigger_rr_below_floor";
      return false;
     }

   Strategy_InitRequest(market_request);
   market_request.type = (g_strategy_virtual_limit_signal.direction > 0)
                         ? QM_BUY : QM_SELL;
   market_request.price = 0.0; // framework re-resolves the current atomic side.
   market_request.sl = stop;
   market_request.tp = target;
   market_request.reason = g_strategy_virtual_limit_request.reason;
   market_request.symbol_slot = g_strategy_virtual_limit_request.symbol_slot;
   market_request.expiration_seconds = 0;
   failure_reason = "ok";
   return true;
  }

void Strategy_ProcessVirtualLimit(const bool allow_trigger)
  {
   if(!g_strategy_virtual_limit_active)
      return;
   datetime broker_now = allow_trigger ? TimeCurrent() : TimeTradeServer();
   if(broker_now <= 0)
      broker_now = TimeCurrent();
   string block_reason = "";
   if(!Strategy_VirtualLimitGateAllows(broker_now, block_reason))
     {
      Strategy_DisarmVirtualLimit(block_reason);
      return;
     }
   if(!allow_trigger)
      return; // timers invalidate only; entries require a fresh symbol tick.

   MqlTick quote;
   ZeroMemory(quote);
   if(!SymbolInfoTick(_Symbol, quote) || !Strategy_VirtualLimitTouched(quote))
      return;

   QM_EntryRequest market_request;
   double market_price = 0.0;
   string geometry_reason = "";
   if(!Strategy_BuildTriggeredMarketRequest(quote,
                                            market_request,
                                            market_price,
                                            geometry_reason))
     {
      Strategy_DisarmVirtualLimit(geometry_reason);
      return;
     }

   const int budget_key = g_strategy_virtual_limit_signal.budget_key;
   const ICT_SessionKind session = g_strategy_virtual_limit_signal.session;
   const datetime fvg_time = g_strategy_virtual_limit_signal.fvg_bar_time;
   const double intended_entry = g_strategy_virtual_limit_request.price;
   double scaled_risk_percent = 0.0;
   if(MQLInfoInteger(MQL_TESTER) == 0)
     {
      scaled_risk_percent = RISK_PERCENT * g_strategy_governor_scale;
      if(scaled_risk_percent <= 0.0)
        {
         Strategy_DisarmVirtualLimit("governor_scaled_risk_nonpositive");
         return;
        }
     }

   // Persistently consume before the broker call. A reject or crash can never
   // retry this event and can therefore never duplicate account exposure.
   Strategy_DisarmVirtualLimit("touch_consumed_before_send");
   ulong out_ticket = 0;
   bool opened = false;
   if(MQLInfoInteger(MQL_TESTER) != 0)
      opened = QM_TM_OpenPosition(market_request,
                                  out_ticket,
                                  0,
                                  0.0,
                                  QM_TRADE_SEND_ONCE);
   else
      opened = QM_TM_OpenPosition(market_request,
                                  out_ticket,
                                  0,
                                  QM_RISK_MODE_PERCENT,
                                  scaled_risk_percent,
                                  QM_TRADE_SEND_ONCE);
   QM_LogEvent(opened ? QM_INFO : QM_WARN,
               "ICT_ENTRY_RESULT",
               StringFormat("{\"opened\":%s,\"ticket\":%I64u,\"budget_key\":%d,\"mode\":%d,\"session\":%d,\"fvg_time\":%I64d,\"intended_limit\":%.8f,\"trigger_quote\":%.8f,\"governor_scale\":%.8f}",
                            opened ? "true" : "false",
                            out_ticket,
                            budget_key,
                            (int)strategy_mode,
                            (int)session,
                            (long)fvg_time,
                            intended_entry,
                            market_price,
                            g_strategy_governor_scale));
  }

void Strategy_LogReconstruction(const ICT_SequenceResult &result)
  {
   const string signature = StringFormat("%d|%d|%I64d|%I64d|%s",
                                         result.budget_key,
                                         (int)result.session,
                                         (long)result.event_bar_time,
                                         (long)result.fvg_bar_time,
                                         result.outcome);
   if(signature == g_last_reconstruction_signature)
      return;
   g_last_reconstruction_signature = signature;
   QM_LogEvent(QM_INFO,
               "ICT_RECONSTRUCTED_STATE",
               StringFormat("{\"mode\":%d,\"budget_key\":%d,\"session\":%d,\"consumed\":%s,\"ambiguous\":%s,\"signal_valid\":%s,\"event_time\":%I64d,\"fvg_time\":%I64d,\"level_hash\":%u,\"reference_hash\":%u,\"outcome\":\"%s\"}",
                            (int)strategy_mode,
                            result.budget_key,
                            (int)result.session,
                            result.consumed ? "true" : "false",
                            result.ambiguous ? "true" : "false",
                            result.signal_valid ? "true" : "false",
                            (long)result.event_bar_time,
                            (long)result.fvg_bar_time,
                            result.frozen_level_hash,
                            result.reference_hash,
                            QM_LoggerEscapeJson(result.outcome)));
  }

int OnInit()
  {
   Strategy_ResetVirtualLimitMemory();
   if(!Strategy_ParametersValid())
     {
      Print("QM5_20009_INVALID_OR_NON_PREREGISTERED_PARAMETERS");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!Strategy_SymbolMagicAndTimeframeValid())
      return INIT_PARAMETERS_INCORRECT;
   if(!Strategy_NonTesterGovernorConfigValid())
     {
      Print("QM5_20009_LIVE_GOVERNOR_CONFIG_INVALID");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   if(QM_FrameworkMagic() != Strategy_ExpectedRegistryMagic())
     {
      QM_LogEvent(QM_ERROR,
                  "ICT_REGISTRY_MAGIC_MISMATCH",
                  StringFormat("{\"expected\":%d,\"actual\":%d}",
                               Strategy_ExpectedRegistryMagic(),
                               QM_FrameworkMagic()));
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   bool contract_declared = false;
   if(strategy_mode == ICT_MODE_INDEX_MSS_FVG)
      contract_declared = QM_FrameworkDeclareExecutionContract(
         PERIOD_M1,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "PORTFOLIO_SAFETY_AFTER_CARD_DAILY_HARD_FLAT");
   else
      contract_declared = QM_FrameworkDeclareExecutionContract(
         PERIOD_M5,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "PORTFOLIO_SAFETY_AFTER_CARD_DAILY_HARD_FLAT");
   if(!contract_declared)
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   // Keep overdue cancels/flats alive across attachment or terminal restarts.
   // A failed safety action is retried by the one-second timer after init.
   Strategy_RunMandatorySafety();

   // Snapshot the already-closed bar on attachment.  Historical reconstruction
   // may advance an incomplete sequence, but can never submit its old FVG.
   g_last_closed_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: one closed-bar bootstrap read.
   ICT_SequenceResult reconstructed;
    if(Strategy_Reconstruct(reconstructed))
      {
       Strategy_LogReconstruction(reconstructed);
       if(reconstructed.consumed)
         {
          Strategy_VoidPersistedVirtualIntentOnInit(reconstructed);
          Strategy_BindConsumedAttempt(reconstructed);
         }
      }
   else
      QM_LogEvent(QM_WARN, "ICT_RESTART_RECONSTRUCTION_NOT_READY", "{}");

   if(MQLInfoInteger(MQL_TESTER) == 0)
     {
      ResetLastError();
      if(!EventSetTimer(1))
        {
         QM_LogEvent(QM_ERROR,
                     "ICT_SAFETY_TIMER_INIT_FAILED",
                     StringFormat("{\"error\":%d}", GetLastError()));
         QM_FrameworkShutdown();
         return INIT_FAILED;
        }
      g_strategy_own_timer_active = true;
     }

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"ea\":\"QM5_20009_ict-liquidity-portfolio\",\"mode\":%d}",
                            (int)strategy_mode));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   if(g_strategy_own_timer_active)
     {
      EventKillTimer();
      g_strategy_own_timer_active = false;
     }
   ArrayFree(g_strategy_closed_rates);
   QM_FrameworkShutdown();
   Strategy_ResetVirtualLimitMemory();
  }

void OnTick()
  {
   // Kill-switch -> Friday sweep -> card cancels/flats, all before entry gates.
   if(!Strategy_RunMandatorySafety())
     {
      Strategy_DisarmVirtualLimit("mandatory_safety_block");
      return;
     }

   // A virtual limit is checked on every quote, before the closed-bar gate.
   Strategy_ProcessVirtualLimit(true);

    const bool mode_new_bar = (strategy_mode == ICT_MODE_INDEX_MSS_FVG)
                             ? QM_IsNewBar(_Symbol, PERIOD_M1)
                             : QM_IsNewBar(_Symbol, PERIOD_M5);
   if(!mode_new_bar)
      return;
   const datetime closed_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: O(1) new-closed-bar gate.
   if(closed_bar <= 0 || closed_bar == g_last_closed_bar)
      return;
   g_last_closed_bar = closed_bar;
   QM_EquityStreamOnNewBar();

   ICT_SequenceResult signal;
   if(!Strategy_ReconstructCached(closed_bar, signal))
      return; // fail closed when the bounded incremental cache is unavailable.
   Strategy_LogReconstruction(signal);
   if(signal.consumed && !Strategy_BindConsumedAttempt(signal))
      return; // only the persisted first reclaim may progress on later bars.
   if(!signal.signal_valid || signal.fvg_bar_time != closed_bar)
      return; // no historical or later-FVG rescue after a restart.
   if(Strategy_HasPositionOrPending() || !Strategy_HistoryBudgetClear(signal))
      return;

   QM_EntryRequest request;
   string build_failure = "";
   if(!Strategy_BuildEntryRequest(signal, request, build_failure))
     {
       QM_LogEvent(QM_INFO,
                   "ICT_EARLIEST_FVG_VOID",
                  StringFormat("{\"budget_key\":%d,\"fvg_time\":%I64d,\"reason\":\"%s\"}",
                                signal.budget_key,
                               (long)signal.fvg_bar_time,
                               QM_LoggerEscapeJson(build_failure)));
       return;
      }

   // Everything below this line is entry-only.  It must never suppress the
   // management section at the start of OnTick.
   const datetime broker_now = TimeCurrent();
   if(!Strategy_EntryNewsAllows(broker_now))
     {
      QM_LogEvent(QM_INFO,
                  "ICT_EARLIEST_FVG_VOID",
                  StringFormat("{\"budget_key\":%d,\"fvg_time\":%I64d,\"reason\":\"news_blackout_at_eligibility\"}",
                               signal.budget_key,
                               (long)signal.fvg_bar_time));
      return;
     }
   if(!Strategy_GovernorAllowsEntry())
     {
      QM_LogEvent(QM_INFO,
                  "ICT_EARLIEST_FVG_VOID",
                  StringFormat("{\"budget_key\":%d,\"fvg_time\":%I64d,\"reason\":\"governor_block_at_eligibility\"}",
                               signal.budget_key,
                               (long)signal.fvg_bar_time));
      return;
     }
   datetime immutable_deadline = 0;
   string deadline_failure = "";
   if(!Strategy_ComputeVirtualLimitDeadline(signal,
                                            broker_now,
                                            immutable_deadline,
                                            deadline_failure))
     {
      QM_LogEvent(QM_WARN,
                  "ICT_VIRTUAL_LIMIT_DEADLINE_FAILED",
                  StringFormat("{\"budget_key\":%d,\"reason\":\"%s\"}",
                               signal.budget_key,
                               QM_LoggerEscapeJson(deadline_failure)));
      return;
     }
   if(!Strategy_ArmVirtualLimit(signal, request, immutable_deadline))
      QM_LogEvent(QM_WARN,
                  "ICT_VIRTUAL_LIMIT_ARM_FAILED",
                  StringFormat("{\"budget_key\":%d}", signal.budget_key));
  }

void OnTimer()
  {
   // Retry mandatory cancellation/flat paths even when this symbol has no tick.
   const bool safety_allows = Strategy_RunMandatorySafety();
   if(!safety_allows)
      Strategy_DisarmVirtualLimit("mandatory_safety_block");
   else
      Strategy_ProcessVirtualLimit(false);
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
