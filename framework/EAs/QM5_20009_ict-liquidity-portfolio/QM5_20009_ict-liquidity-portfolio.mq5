#property strict
#property version   "5.0"
#property description "QM5_20009 ICT Liquidity Portfolio"

#include <QM/QM_Common.mqh>
#include <QM/QM_FTMOGovernorClient.mqh>
#include "ICT_LiquidityRules.mqh"

// Frozen research build contract v2.  One attachment owns exactly one symbol,
// one sleeve and one registry magic.  All signal decisions use closed Bid bars.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20009;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
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

input group "Stress"
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
ICT_LevelRange g_strategy_index_opening_range;
ICT_LevelRange g_strategy_fx_previous_week;
ICT_SequenceResult g_strategy_cached_sequence;

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
   if(strategy_replay_bars_index < 1200 || strategy_replay_bars_index > 5000 ||
      strategy_replay_bars_fx < 5000 || strategy_replay_bars_fx > 15000)
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
      if(strategy_mode == ICT_MODE_FX_WEEKLY_SWEEP &&
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

   if(strategy_mode == ICT_MODE_FX_WEEKLY_SWEEP)
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

bool Strategy_AddChronologicalDate(const int date_key,
                                   int &dates[],
                                   int &date_count)
  {
   for(int i = 0; i < date_count; ++i)
      if(dates[i] == date_key)
         return true;
   if(date_count >= ArraySize(dates))
      return false;
   dates[date_count++] = date_key;
   return true;
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

   const int current_week_key = ICT_TradingWeekKey(rates[count - 1].time);
   const int previous_week_key = ICT_ShiftDateKey(current_week_key, -7);
   ICT_LevelRange previous_week;
   int distinct_dates = 0;
   if(!ICT_CollectPreviousTradingWeek(rates,
                                      count,
                                      previous_week_key,
                                      tick_size,
                                      previous_week,
                                      distinct_dates))
     {
      result.budget_key = current_week_key;
      result.outcome = "PREVIOUS_WEEK_INCOMPLETE";
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

   int session_dates[8];
   ArrayInitialize(session_dates, 0);
   int session_date_count = 0;
   for(int i = 0; i < count; ++i)
     {
      if(ICT_TradingWeekKey(rates[i].time) != current_week_key)
         continue;
      MqlDateTime ny;
      ZeroMemory(ny);
      TimeToStruct(ICT_BrokerToNewYork(rates[i].time), ny);
      if(ny.day_of_week < 1 || ny.day_of_week > 5)
         continue;
      Strategy_AddChronologicalDate(ICT_NYDateKey(rates[i].time),
                                    session_dates,
                                    session_date_count);
     }

   bool found_consumed = false;
   ICT_SequenceResult earliest;
   ICT_ResetSequence(earliest);
   for(int d = 0; d < session_date_count; ++d)
     {
      const int date_key = session_dates[d];

      ICT_LevelRange asian;
      const int previous_date = ICT_ShiftDateKey(date_key, -1);
      if(ICT_CollectNYRange(rates,
                            count,
                            previous_date,
                            20 * 60,
                            24 * 60,
                            48,
                            tick_size,
                            asian))
        {
         ICT_SequenceResult london;
         ICT_BuildSequence(rates,
                           count,
                           date_key,
                           current_week_key,
                           ICT_SESSION_LONDON,
                           2 * 60,
                           5 * 60,
                           PeriodSeconds(PERIOD_M5),
                           previous_week.low,
                           previous_week.high,
                           asian.high,
                           asian.low,
                           previous_week.fingerprint,
                           asian.fingerprint,
                           pivot_wing,
                           reclaim_bars,
                           max_bars_to_mss,
                           min_fvg_atr,
                           sl_buffer_atr,
                           min_rr,
                           tick_size,
                           point,
                           london,
                           0,
                           count - 1,
                           0);
         if(london.consumed &&
            (!found_consumed || london.event_bar_time < earliest.event_bar_time))
           {
            Strategy_CopySequence(london, earliest);
            found_consumed = true;
           }
        }

      ICT_LevelRange london_reference;
      if(ICT_CollectNYRange(rates,
                            count,
                            date_key,
                            2 * 60,
                            5 * 60,
                            36,
                            tick_size,
                            london_reference))
        {
         ICT_SequenceResult new_york;
         ICT_BuildSequence(rates,
                           count,
                           date_key,
                           current_week_key,
                           ICT_SESSION_NEW_YORK,
                           7 * 60,
                           10 * 60,
                           PeriodSeconds(PERIOD_M5),
                           previous_week.low,
                           previous_week.high,
                           london_reference.high,
                           london_reference.low,
                           previous_week.fingerprint,
                           london_reference.fingerprint,
                           pivot_wing,
                           reclaim_bars,
                           max_bars_to_mss,
                           min_fvg_atr,
                           sl_buffer_atr,
                           min_rr,
                           tick_size,
                           point,
                           new_york,
                           0,
                           count - 1,
                           0);
         if(new_york.consumed &&
            (!found_consumed || new_york.event_bar_time < earliest.event_bar_time))
           {
            Strategy_CopySequence(new_york, earliest);
            found_consumed = true;
           }
        }
     }

   if(found_consumed)
      Strategy_CopySequence(earliest, result);
   else
     {
      result.budget_key = current_week_key;
      result.frozen_level_hash = previous_week.fingerprint;
      result.outcome = "NO_ELIGIBLE_WEEKLY_RECLAIM";
     }
   return true;
  }

bool Strategy_Reconstruct(ICT_SequenceResult &result)
  {
   g_strategy_replay_cache_ready = false;
   g_strategy_replay_budget_key = 0;
   g_strategy_closed_rate_count = 0;
   ArrayFree(g_strategy_closed_rates);
   ICT_ResetRange(g_strategy_index_opening_range);
   ICT_ResetRange(g_strategy_fx_previous_week);
   ICT_ResetSequence(g_strategy_cached_sequence);

   if(!Strategy_LoadClosedRates(g_strategy_closed_rates,
                                g_strategy_closed_rate_count))
     {
      ICT_ResetSequence(result);
      result.outcome = "REPLAY_HISTORY_UNAVAILABLE";
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
      return false;

   const datetime newest_time =
      g_strategy_closed_rates[g_strategy_closed_rate_count - 1].time;
   g_strategy_replay_budget_key = Strategy_BudgetKeyAtTime(newest_time);
   if(g_strategy_replay_budget_key <= 0 ||
      result.budget_key != g_strategy_replay_budget_key)
     {
      ICT_ResetSequence(result);
      result.outcome = "REPLAY_BUDGET_MISMATCH";
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
      int distinct_dates = 0;
      ICT_CollectPreviousTradingWeek(g_strategy_closed_rates,
                                     g_strategy_closed_rate_count,
                                     ICT_ShiftDateKey(g_strategy_replay_budget_key, -7),
                                     g_strategy_replay_tick_size,
                                     g_strategy_fx_previous_week,
                                     distinct_dates);
     }

   Strategy_CopySequence(result, g_strategy_cached_sequence);
   g_strategy_replay_cache_ready = true;
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
   if(ICT_IsEventBarInSession(bar,
                              date_key,
                              7 * 60,
                              10 * 60,
                              PeriodSeconds(PERIOD_M5)))
      return ICT_SESSION_NEW_YORK;
   return ICT_SESSION_NONE;
  }

bool Strategy_RebuildFxSession(const int date_key,
                               const ICT_SessionKind session,
                               ICT_SequenceResult &result)
  {
   const bool london = session == ICT_SESSION_LONDON;
   if(!london && session != ICT_SESSION_NEW_YORK)
      return false;

   const int reference_date = london ? ICT_ShiftDateKey(date_key, -1)
                                     : date_key;
   const int reference_start = london ? 20 * 60 : 2 * 60;
   const int reference_end = london ? 24 * 60 : 5 * 60;
   const int reference_bars = london ? 48 : 36;
   int reference_first = -1;
   int reference_last = -1;
   if(!Strategy_FindNYWindowBounds(reference_date,
                                   reference_start,
                                   reference_end,
                                   false,
                                   PeriodSeconds(PERIOD_M5),
                                   reference_first,
                                   reference_last))
      return false;

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
      return false;

   const int session_start = london ? 2 * 60 : 7 * 60;
   const int session_end = london ? 5 * 60 : 10 * 60;
   int event_first = -1;
   int event_last = -1;
   if(!Strategy_FindNYWindowBounds(date_key,
                                   session_start,
                                   session_end,
                                   true,
                                   PeriodSeconds(PERIOD_M5),
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
   ICT_BuildSequence(g_strategy_closed_rates,
                     g_strategy_closed_rate_count,
                     date_key,
                     g_strategy_replay_budget_key,
                     session,
                     session_start,
                     session_end,
                     PeriodSeconds(PERIOD_M5),
                     g_strategy_fx_previous_week.low,
                     g_strategy_fx_previous_week.high,
                     reference.high,
                     reference.low,
                     g_strategy_fx_previous_week.fingerprint,
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
   return true;
  }

bool Strategy_UpdateFxCache(const MqlRates &bar)
  {
   if(!g_strategy_fx_previous_week.valid)
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
   if(!Strategy_RebuildFxSession(date_key, current_session, updated))
      return true; // An incomplete reference or session is a normal no-event state.

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
   if(closed_bar <= 0 || !g_strategy_replay_cache_ready)
     {
      result.outcome = "REPLAY_CACHE_NOT_READY";
      return false;
     }

   const int current_budget_key = Strategy_BudgetKeyAtTime(closed_bar);
   if(current_budget_key != g_strategy_replay_budget_key)
      return Strategy_Reconstruct(result); // one full replay at the budget edge.

   if(!Strategy_AppendAndAdvanceCache(closed_bar))
     {
      g_strategy_replay_cache_ready = false; // fail closed; restart rebuilds it.
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

bool Strategy_HasPositionOrPending()
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

int Strategy_BudgetKeyAtTime(const datetime event_time)
  {
   return (strategy_mode == ICT_MODE_INDEX_MSS_FVG)
          ? ICT_NYDateKey(event_time)
          : ICT_TradingWeekKey(event_time);
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

bool Strategy_ClaimAttempt(const ICT_SequenceResult &signal)
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
      return false;
     }
   GlobalVariablesFlush();
   return true;
  }

bool Strategy_HistoryBudgetClear(const ICT_SequenceResult &signal)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || signal.budget_key <= 0 ||
      !Strategy_BindConsumedAttempt(signal))
      return false;
   const datetime now = TimeCurrent();
   const int lookback_days = (strategy_mode == ICT_MODE_INDEX_MSS_FVG) ? 4 : 24;
   if(!HistorySelect(now - lookback_days * 86400, now))
     {
      QM_LogEvent(QM_ERROR,
                  "ICT_HISTORY_RECONSTRUCTION_FAILED",
                  StringFormat("{\"budget_key\":%d}", signal.budget_key));
      return false;
     }

   const int order_total = HistoryOrdersTotal();
   if(order_total < 0)
      return false;
   for(int i = 0; i < order_total; ++i)
     {
      ResetLastError();
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         return false;
      const string order_symbol = HistoryOrderGetString(ticket, ORDER_SYMBOL);
      const int order_magic = (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC);
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
      const datetime setup_time =
         (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP);
      const string order_comment = HistoryOrderGetString(ticket, ORDER_COMMENT);
      if(GetLastError() != 0)
         return false;
      if(order_symbol != _Symbol || order_magic != magic ||
         !Strategy_IsOurPendingType(order_type))
         continue;
      if(setup_time <= 0)
         return false;
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
      return false;
   for(int i = 0; i < deal_total; ++i)
     {
      ResetLastError();
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         return false;
      const string deal_symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      const int deal_magic = (int)HistoryDealGetInteger(ticket, DEAL_MAGIC);
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(GetLastError() != 0)
         return false;
      if(deal_symbol != _Symbol || deal_magic != magic)
         continue;
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      if(deal_time <= 0)
         return false;
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

   // Cancellation and hard flats intentionally precede all entry-only filters.
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         !Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time <= 0 || Strategy_ShouldCancelOrder(setup_time, now))
         QM_TM_RemovePendingOrder(ticket, "ict_session_pending_cancel");
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

bool Strategy_QuoteAllowsFreshLimit(const int direction,
                                    const double entry,
                                    const double stop,
                                    const double target)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   MqlTick quote;
   ZeroMemory(quote);
   if(!SymbolInfoTick(_Symbol, quote))
      return false;
   const double ask = quote.ask;
   const double bid = quote.bid;
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid ||
      entry <= 0.0 || stop <= 0.0 || target <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum_distance = MathMax(0.0, (double)stops_level * point);
   const double comparison_epsilon = point * 1e-7;
   if(direction > 0)
     {
      // Ask at/below the proximal edge means the earliest FVG was already
      // touched when it became eligible; this attempt gets no later rescue.
      if(ask <= entry || ask - entry + comparison_epsilon < minimum_distance)
         return false;
      if(stop >= entry || target <= entry)
         return false;
      if(entry - stop + comparison_epsilon < minimum_distance ||
         target - entry + comparison_epsilon < minimum_distance)
         return false;
     }
   else
     {
      if(bid >= entry || entry - bid + comparison_epsilon < minimum_distance)
         return false;
      if(stop <= entry || target >= entry)
         return false;
      if(stop - entry + comparison_epsilon < minimum_distance ||
         entry - target + comparison_epsilon < minimum_distance)
         return false;
     }
   return true;
  }

bool Strategy_AssignPendingExpiration(const int expiration_seconds,
                                      QM_EntryRequest &request)
  {
   if(expiration_seconds <= 0)
      return false;
   long expiration_modes = 0;
   if(!SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE, expiration_modes))
      return false;
   if((expiration_modes & (long)SYMBOL_EXPIRATION_SPECIFIED) != 0)
     {
      request.expiration_seconds = expiration_seconds;
      return true;
     }
   if((expiration_modes & (long)SYMBOL_EXPIRATION_GTC) == 0)
      return false;

   // The one-second timer and per-tick safety path enforce the same session
   // cancellation when the broker does not accept ORDER_TIME_SPECIFIED.
   request.expiration_seconds = 0;
   QM_LogEvent(QM_INFO,
               "ICT_PENDING_EXPIRATION_GTC_FALLBACK",
               StringFormat("{\"seconds_until_session_end\":%d}",
                            expiration_seconds));
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
                                QM_EntryRequest &request)
  {
   Strategy_InitRequest(request);
   if(!signal.signal_valid || !signal.consumed || signal.ambiguous)
      return false;
   const int expiration_seconds = Strategy_SecondsUntilSessionEnd(signal);
   if(expiration_seconds <= 0)
      return false;

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
   if(!Strategy_AssignPendingExpiration(expiration_seconds, request))
      return false;

   if(!Strategy_QuoteAllowsFreshLimit(signal.direction,
                                      request.price,
                                      request.sl,
                                      request.tp))
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
   return risk > 0.0 && reward > 0.0 && reward / risk + 1e-12 >= min_rr;
  }

bool Strategy_EntryNewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
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
         Strategy_BindConsumedAttempt(reconstructed);
     }
   else
      QM_LogEvent(QM_WARN, "ICT_RESTART_RECONSTRUCTION_NOT_READY", "{}");

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"ea\":\"QM5_20009_ict-liquidity-portfolio\",\"mode\":%d}",
                            (int)strategy_mode));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   ArrayFree(g_strategy_closed_rates);
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Kill-switch -> Friday sweep -> card cancels/flats, all before entry gates.
   if(!Strategy_RunMandatorySafety())
      return;

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
   if(!Strategy_BuildEntryRequest(signal, request))
     {
      QM_LogEvent(QM_INFO,
                  "ICT_EARLIEST_FVG_VOID",
                  StringFormat("{\"budget_key\":%d,\"fvg_time\":%I64d,\"reason\":\"touched_or_broker_distance\"}",
                               signal.budget_key,
                               (long)signal.fvg_bar_time));
      return;
     }

   // Everything below this line is entry-only.  It must never suppress the
   // management section at the start of OnTick.
   const datetime broker_now = TimeCurrent();
   if(!Strategy_EntryNewsAllows(broker_now))
      return;
   if(!Strategy_GovernorAllowsEntry())
      return;

   double scaled_risk_percent = 0.0;
   if(MQLInfoInteger(MQL_TESTER) == 0)
     {
      scaled_risk_percent = RISK_PERCENT * g_strategy_governor_scale;
      if(scaled_risk_percent <= 0.0)
         return;
     }
   // Persist SUBMITTED before entering the framework order path. Rejection,
   // broker failure, expiry or later cancellation can never reopen this budget.
   if(!Strategy_ClaimAttempt(signal))
      return;

   ulong out_ticket = 0;
   bool opened = false;
   if(MQLInfoInteger(MQL_TESTER) != 0)
      opened = QM_TM_OpenPosition(request, out_ticket);
   else
      opened = QM_TM_OpenPosition(request,
                                  out_ticket,
                                  0,
                                  QM_RISK_MODE_PERCENT,
                                  scaled_risk_percent);
   QM_LogEvent(opened ? QM_INFO : QM_WARN,
               "ICT_ENTRY_RESULT",
               StringFormat("{\"opened\":%s,\"ticket\":%I64u,\"budget_key\":%d,\"mode\":%d,\"session\":%d,\"fvg_time\":%I64d,\"governor_scale\":%.8f}",
                            opened ? "true" : "false",
                            out_ticket,
                            signal.budget_key,
                            (int)strategy_mode,
                            (int)signal.session,
                            (long)signal.fvg_bar_time,
                            g_strategy_governor_scale));
  }

void OnTimer()
  {
   // Retry mandatory cancellation/flat paths even when this symbol has no tick.
   Strategy_RunMandatorySafety();
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
