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
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
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

datetime g_last_closed_bar = 0;
double   g_strategy_governor_scale = 0.0;
string   g_strategy_last_governor_block = "";
datetime g_strategy_last_governor_log = 0;
string   g_last_reconstruction_signature = "";

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
      if(_Symbol == "EURUSD.DWX")
        {
         // Frozen universe member, deliberately non-runnable until CEO+CTO
         // allocate its missing registry/magic slot.  No user override exists.
         Print("QM5_20009_EURUSD_MAGIC_NOT_REGISTERED: registry update required before build/run");
         return false;
        }
      Print("QM5_20009_SYMBOL_MAGIC_MISMATCH: B currently permits GBPUSD.DWX/slot2; EURUSD slot is absent");
      return false;
     }

   Print("QM5_20009_UNKNOWN_STRATEGY_MODE");
   return false;
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
                     result);
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
                           london);
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
                           new_york);
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
   MqlRates rates[];
   int count = 0;
   if(!Strategy_LoadClosedRates(rates, count))
     {
      ICT_ResetSequence(result);
      result.outcome = "REPLAY_HISTORY_UNAVAILABLE";
      return false;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = point;
   if(point <= 0.0 || tick_size <= 0.0)
     {
      ICT_ResetSequence(result);
      result.outcome = "SYMBOL_PRICE_UNIT_UNAVAILABLE";
      return false;
     }

   if(strategy_mode == ICT_MODE_INDEX_MSS_FVG)
      return Strategy_ReconstructIndex(rates, count, tick_size, point, result);
   return Strategy_ReconstructFx(rates, count, tick_size, point, result);
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

bool Strategy_HistoryBudgetClear(const int budget_key)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || budget_key <= 0)
      return false;
   const datetime now = TimeCurrent();
   const int lookback_days = (strategy_mode == ICT_MODE_INDEX_MSS_FVG) ? 4 : 24;
   if(!HistorySelect(now - lookback_days * 86400, now))
     {
      QM_LogEvent(QM_ERROR,
                  "ICT_HISTORY_RECONSTRUCTION_FAILED",
                  StringFormat("{\"budget_key\":%d}", budget_key));
      return false;
     }

   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0 || HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol ||
         (int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      const int deal_key = (strategy_mode == ICT_MODE_INDEX_MSS_FVG)
                           ? ICT_NYDateKey(deal_time)
                           : ICT_TradingWeekKey(deal_time);
      if(deal_key == budget_key)
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

bool Strategy_QuoteAllowsFreshLimit(const ICT_SequenceResult &signal)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid ||
      signal.entry <= 0.0 || signal.stop <= 0.0 || signal.target <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double current_spread = MathMax(0.0, ask - bid);
   const double minimum_distance = MathMax(0.0, (double)stops_level * point) + current_spread;
   if(signal.direction > 0)
     {
      // Ask at/below the proximal edge means the earliest FVG was already
      // touched when it became eligible; this attempt gets no later rescue.
      if(ask <= signal.entry || ask - signal.entry <= minimum_distance)
         return false;
      if(signal.stop >= signal.entry || signal.target <= signal.entry)
         return false;
     }
   else
     {
      if(bid >= signal.entry || signal.entry - bid <= minimum_distance)
         return false;
      if(signal.stop <= signal.entry || signal.target >= signal.entry)
         return false;
     }
   if(MathAbs(signal.entry - signal.stop) <= minimum_distance)
      return false;
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
   if(!signal.signal_valid || !signal.consumed || signal.ambiguous ||
      !Strategy_QuoteAllowsFreshLimit(signal))
      return false;
   const int expiration_seconds = Strategy_SecondsUntilSessionEnd(signal);
   if(expiration_seconds <= 0)
      return false;

   request.type = (signal.direction > 0) ? QM_BUY_LIMIT : QM_SELL_LIMIT;
   request.price = NormalizeDouble(signal.entry, _Digits);
   request.sl = NormalizeDouble(signal.stop, _Digits);
   request.tp = NormalizeDouble(signal.target, _Digits);
   request.reason = (strategy_mode == ICT_MODE_INDEX_MSS_FVG)
                    ? "ICTA_OR_MSS_FVG"
                    : ((signal.session == ICT_SESSION_LONDON)
                       ? "ICTB_LDN_MSS_FVG"
                       : "ICTB_NY_MSS_FVG");
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = expiration_seconds;

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

   const ENUM_TIMEFRAMES expected_timeframe =
      (strategy_mode == ICT_MODE_INDEX_MSS_FVG) ? PERIOD_M1 : PERIOD_M5;
   if(!QM_FrameworkDeclareExecutionContract(expected_timeframe,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "PORTFOLIO_SAFETY_AFTER_CARD_DAILY_HARD_FLAT"))
      return INIT_FAILED;

   // Snapshot the already-closed bar on attachment.  Historical reconstruction
   // may advance an incomplete sequence, but can never submit its old FVG.
   g_last_closed_bar = iTime(_Symbol, expected_timeframe, 1); // perf-allowed: one closed-bar bootstrap read.
   ICT_SequenceResult reconstructed;
   if(Strategy_Reconstruct(reconstructed))
      Strategy_LogReconstruction(reconstructed);
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
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Management is deliberately first: session cancels and daily hard flats
   // cannot be suppressed by news, session, history or governor entry filters.
   Strategy_ManageExposure();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(!QM_KillSwitchCheck())
      return;

   const datetime closed_bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: O(1) new-closed-bar gate.
   if(closed_bar <= 0 || closed_bar == g_last_closed_bar)
      return;
   g_last_closed_bar = closed_bar;
   QM_EquityStreamOnNewBar();

   ICT_SequenceResult signal;
   if(!Strategy_Reconstruct(signal))
      return; // fail closed when bounded bars are unavailable.
   Strategy_LogReconstruction(signal);
   if(!signal.signal_valid || signal.fvg_bar_time != closed_bar)
      return; // no historical or later-FVG rescue after a restart.
   if(Strategy_HasPositionOrPending() || !Strategy_HistoryBudgetClear(signal.budget_key))
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

   ulong out_ticket = 0;
   bool opened = false;
   if(MQLInfoInteger(MQL_TESTER) != 0)
      opened = QM_TM_OpenPosition(request, out_ticket);
   else
     {
      const double scaled_risk_percent = RISK_PERCENT * g_strategy_governor_scale;
      opened = scaled_risk_percent > 0.0 &&
               QM_TM_OpenPosition(request,
                                  out_ticket,
                                  0,
                                  QM_RISK_MODE_PERCENT,
                                  scaled_risk_percent);
     }
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
