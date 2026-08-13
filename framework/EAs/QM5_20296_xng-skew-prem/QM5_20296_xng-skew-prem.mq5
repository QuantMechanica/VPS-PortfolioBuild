#property strict
#property version   "5.0"
#property description "QM5_20296 XNG Skewness Premium"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20296 - XNG Skewness Premium
// -----------------------------------------------------------------------------
// Source lineage: Fernandez-Perez, Frijns, Fuertes & Miffre (2018) define
// twelve-month Pearson return skewness, document a negative cross-sectional
// commodity premium, and include natural gas. The outright XNG zero-pivot time-
// series rule below is a transparent, locked QM hypothesis, not a source result.
// At each genuine broker-month transition:
//   1. select adjacent completed D1 closes wholly inside the prior 12 months;
//   2. calculate population mean, variance, and third central moment;
//   3. normalize the third moment into raw Pearson skewness;
//   4. buy negative skew, sell positive skew, and consume near-zero flat.
// Runtime uses native XNGUSD.DWX price and broker data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20296;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_months          = 12;
input int    strategy_history_bars_d1          = 500;
input int    strategy_min_return_observations  = 180;
input int    strategy_max_return_observations  = 280;
input double strategy_variance_floor           = 1.0e-12;
input double strategy_skew_tolerance           = 1.0e-12;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 40;
input int    strategy_max_spread_points        = 2500;

const string g_strategy_symbol = "XNGUSD.DWX";

bool   g_monthly_rebalance_bar  = false;
bool   g_cache_signal_valid     = false;
int    g_cache_signal           = 0;
int    g_cache_month_key        = 0;
int    g_last_attempt_month_key = 0;
string g_attempt_state_key      = "";
double g_cache_skew             = 0.0;
double g_cache_mean             = 0.0;
double g_cache_variance         = 0.0;
double g_cache_third_moment     = 0.0;
int    g_cache_return_count     = 0;
string g_cache_state_reason     = "uninitialized";

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_strategy_symbol &&
           _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
  }

int Strategy_MonthKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_ShiftMonthKey(const int month_key, const int month_delta)
  {
   const int year = month_key / 100;
   const int month = month_key % 100;
   if(year < 1900 || month < 1 || month > 12)
      return 0;

   const int serial = year * 12 + (month - 1) + month_delta;
   if(serial < 1900 * 12)
      return 0;
   return (serial / 12) * 100 + (serial % 12) + 1;
  }

datetime Strategy_MonthStartForKey(const int month_key)
  {
   const int year = month_key / 100;
   const int month = month_key % 100;
   if(year < 1900 || month < 1 || month > 12)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = year;
   parts.mon = month;
   parts.day = 1;
   return StructToTime(parts);
  }

int Strategy_FormationMonthIndex(const int month_key,
                                 const int first_month_key)
  {
   for(int i = 0; i < strategy_lookback_months; ++i)
     {
      if(Strategy_ShiftMonthKey(first_month_key, i) == month_key)
         return i;
     }
   return -1;
  }

bool Strategy_IsOwnedPosition()
  {
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

bool Strategy_IsManagedPosition()
  {
   return (Strategy_IsOwnedPosition() &&
           PositionGetString(POSITION_SYMBOL) == g_strategy_symbol);
  }

int Strategy_OwnedPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedPosition())
         ++count;
     }
   return count;
  }

bool Strategy_OwnedPositionStateValid()
  {
   if(Strategy_OwnedPositionCount() != 1)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsOwnedPosition())
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_strategy_symbol)
         return false;
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type != POSITION_TYPE_BUY && position_type != POSITION_TYPE_SELL)
         return false;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened <= 0 || opened > TimeCurrent())
         return false;
      const double stop_loss = PositionGetDouble(POSITION_SL);
      const double take_profit = PositionGetDouble(POSITION_TP);
      if(stop_loss <= 0.0 || !MathIsValidNumber(stop_loss))
         return false;
      if(take_profit != 0.0 || !MathIsValidNumber(take_profit))
         return false;
      return true;
     }
   return false;
  }

datetime Strategy_CurrentEntryTime()
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsManagedPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest <= 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

void Strategy_CloseOwnedPositions(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsOwnedPosition())
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points >= 0 && spread_points <= strategy_max_spread_points);
  }

bool Strategy_MonthAlreadyEntered(const int month_key)
  {
   if(month_key <= 0 || g_last_attempt_month_key == month_key)
      return true;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsOwnedPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKeyForTime(opened) == month_key)
         return true;
     }

   MqlDateTime start_parts;
   ZeroMemory(start_parts);
   start_parts.year = month_key / 100;
   start_parts.mon = month_key % 100;
   start_parts.day = 1;
   const datetime month_start = StructToTime(start_parts);
   if(month_start <= 0 || !HistorySelect(month_start, TimeCurrent()))
      return true;

   const int deal_count = HistoryDealsTotal();
   for(int i = deal_count - 1; i >= 0; --i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_MonthKeyForTime(deal_time) == month_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_month_key = 0;
   if(g_attempt_state_key == "" || !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_month_key = Strategy_MonthKeyForTime(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_month_key = (int)MathRound(stored);
   if(current_month_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_month_key >= 190001 &&
      stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }

   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key, (double)month_key) <= 0)
      return false;
   GlobalVariablesFlush();
   g_last_attempt_month_key = month_key;
   return true;
  }

void Strategy_ResetCachedState()
  {
   g_cache_signal_valid = false;
   g_cache_signal = 0;
   g_cache_skew = 0.0;
   g_cache_mean = 0.0;
   g_cache_variance = 0.0;
   g_cache_third_moment = 0.0;
   g_cache_return_count = 0;
   g_cache_state_reason = "not_evaluated";
  }

bool Strategy_LoadSignalState(int &signal)
  {
   signal = 0;
   if(strategy_lookback_months != 12 ||
      strategy_history_bars_d1 != 500 ||
      strategy_min_return_observations != 180 ||
      strategy_max_return_observations != 280 ||
      MathAbs(strategy_variance_floor - 1.0e-12) > 1.0e-22 ||
      MathAbs(strategy_skew_tolerance - 1.0e-12) > 1.0e-22)
     {
      g_cache_state_reason = "bad_skew_contract";
      return false;
     }

   const int current_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int calendar_previous_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   const int expected_previous_month =
      Strategy_ShiftMonthKey(current_month, -1);
   const int first_formation_month =
      Strategy_ShiftMonthKey(current_month, -strategy_lookback_months);
   const datetime formation_start =
      Strategy_MonthStartForKey(first_formation_month);
   const datetime formation_end =
      Strategy_MonthStartForKey(current_month);
   if(current_month <= 0 ||
      calendar_previous_month <= 0 ||
      calendar_previous_month != expected_previous_month ||
      first_formation_month <= 0 ||
      formation_start <= 0 ||
      formation_end <= formation_start)
     {
      g_cache_state_reason = "invalid_month_calendar";
      return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: monthly bounded structural estimator, reviewer-signed at Q01.
                PERIOD_D1,
                1,
                strategy_history_bars_d1,
                rates); // perf-allowed: bounded completed-D1 read reached only from the genuine new-month gate.
   if(copied <= 0)
     {
      g_cache_state_reason = "history_unavailable";
      return false;
     }

   bool covered_months[];
   ArrayResize(covered_months, strategy_lookback_months);
   for(int month_index = 0;
       month_index < strategy_lookback_months;
       ++month_index)
      covered_months[month_index] = false;

   double returns[];
   ArrayResize(returns, copied);
   int return_count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time <= 0 ||
         (i > 0 && rates[i].time <= rates[i - 1].time))
        {
         g_cache_state_reason = "non_increasing_daily_time";
         return false;
        }
     }

   for(int i = 1; i < copied; ++i)
     {
      const datetime prior_time = rates[i - 1].time;
      const datetime current_time = rates[i].time;
      const bool prior_in_window =
         (prior_time >= formation_start && prior_time < formation_end);
      const bool current_in_window =
         (current_time >= formation_start && current_time < formation_end);
      if(!prior_in_window || !current_in_window)
         continue;

      const int current_key = Strategy_MonthKeyForTime(current_time);
      const int month_index =
         Strategy_FormationMonthIndex(current_key, first_formation_month);
      if(month_index < 0 || month_index >= strategy_lookback_months)
        {
         g_cache_state_reason = "return_month_outside_formation";
         return false;
        }

      const double prior_close = rates[i - 1].close;
      const double current_close = rates[i].close;
      if(prior_close <= 0.0 ||
         current_close <= 0.0 ||
         !MathIsValidNumber(prior_close) ||
         !MathIsValidNumber(current_close))
        {
         g_cache_state_reason = "invalid_return_close";
         return false;
        }

      const double daily_return = MathLog(current_close / prior_close);
      if(!MathIsValidNumber(daily_return))
        {
         g_cache_state_reason = "invalid_daily_return";
         return false;
        }

      returns[return_count++] = daily_return;
      covered_months[month_index] = true;
     }

   if(return_count < strategy_min_return_observations ||
      return_count > strategy_max_return_observations)
     {
      g_cache_state_reason = "return_count_out_of_bounds";
      return false;
     }

   for(int month_index = 0;
       month_index < strategy_lookback_months;
       ++month_index)
     {
      if(!covered_months[month_index])
        {
         g_cache_state_reason = "missing_formation_month";
         return false;
        }
     }

   double mean = 0.0;
   for(int i = 0; i < return_count; ++i)
      mean += returns[i];
   mean /= (double)return_count;
   if(!MathIsValidNumber(mean))
     {
      g_cache_state_reason = "invalid_return_mean";
      return false;
     }

   double second_moment = 0.0;
   double third_moment = 0.0;
   for(int i = 0; i < return_count; ++i)
     {
      const double centered = returns[i] - mean;
      const double squared = centered * centered;
      second_moment += squared;
      third_moment += squared * centered;
     }
   second_moment /= (double)return_count;
   third_moment /= (double)return_count;
   if(!MathIsValidNumber(second_moment) ||
      !MathIsValidNumber(third_moment) ||
      second_moment <= strategy_variance_floor)
     {
      g_cache_state_reason = "invalid_population_moments";
      return false;
     }

   const double skew_denominator = MathPow(second_moment, 1.5);
   const double skew = third_moment / skew_denominator;
   if(!MathIsValidNumber(skew_denominator) ||
      skew_denominator <= 0.0 ||
      !MathIsValidNumber(skew))
     {
      g_cache_state_reason = "invalid_pearson_skewness";
      return false;
     }

   g_cache_skew = skew;
   g_cache_mean = mean;
   g_cache_variance = second_moment;
   g_cache_third_moment = third_moment;
   g_cache_return_count = return_count;
   if(MathAbs(skew) <= strategy_skew_tolerance)
     {
      g_cache_state_reason = "near_zero_skew";
      return true;
     }

   signal = (skew < 0.0) ? 1 : -1;
   g_cache_state_reason =
      (signal > 0) ? "qualified_long" : "qualified_short";
   return true;
  }

void Strategy_DetectMonthlyRebalance_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_month_key = 0;
   Strategy_ResetCachedState();

   const int current_day_key =
      QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   const int previous_bar_day_key =
      QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1);
   const int current_month_key = current_day_key / 100;
   const int previous_bar_month_key = previous_bar_day_key / 100;
   const int calendar_current_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int calendar_previous_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);

   if(current_day_key <= 0 ||
      previous_bar_day_key <= 0 ||
      current_month_key <= 0 ||
      previous_bar_month_key <= 0 ||
      current_month_key == previous_bar_month_key ||
      current_month_key != calendar_current_month ||
      previous_bar_month_key != calendar_previous_month)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
  }

void Strategy_PrepareMonthlySignal()
  {
   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0)
      return;
   if(Strategy_MonthAlreadyEntered(g_cache_month_key))
     {
      g_cache_state_reason = "month_already_consumed";
      return;
     }
   if(!Strategy_RecordMonthAttempt(g_cache_month_key))
     {
      g_cache_state_reason = "attempt_persist_failed";
      return;
     }

   g_cache_signal_valid = Strategy_LoadSignalState(g_cache_signal);
   QM_LogEvent(QM_INFO,
               "MONTHLY_STATE",
               StringFormat("{\"month\":%d,\"valid\":%s,\"signal\":%d,\"skew\":%.12f,\"mean\":%.12e,\"variance\":%.12e,\"third_moment\":%.12e,\"returns\":%d,\"state\":\"%s\"}",
                             g_cache_month_key,
                             g_cache_signal_valid ? "true" : "false",
                             g_cache_signal,
                             g_cache_skew,
                             g_cache_mean,
                             g_cache_variance,
                             g_cache_third_moment,
                             g_cache_return_count,
                             g_cache_state_reason));
  }

bool Strategy_MaxHoldExceeded()
  {
   const datetime entry_time = Strategy_CurrentEntryTime();
   if(entry_time <= 0)
      return false;
   const long hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 20296 ||
      qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 || RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 || qm_news_min_impact != "high")
      return true;
   if(qm_stress_reject_probability != 0.0)
      return true;
   if(strategy_lookback_months != 12 ||
      strategy_min_return_observations != 180 ||
      strategy_max_return_observations != 280 ||
      MathAbs(strategy_variance_floor - 1.0e-12) > 1.0e-22 ||
      MathAbs(strategy_skew_tolerance - 1.0e-12) > 1.0e-22)
      return true;
   if(strategy_history_bars_d1 != 500)
      return true;
   if(strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 40 ||
      strategy_max_spread_points != 2500)
      return true;
   if(qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_20296_XNG_SKEW_PREM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar ||
      g_cache_month_key <= 0 ||
      g_cache_month_key != g_last_attempt_month_key)
      return false;
   if(Strategy_OwnedPositionCount() > 0)
      return false;
   if(!g_cache_signal_valid || g_cache_signal == 0 || !Strategy_SpreadAllowed())
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type = (g_cache_signal > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_cache_signal > 0) ? "SKEW_PREM_XNG_LONG" : "SKEW_PREM_XNG_SHORT";
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_value,
                                strategy_atr_sl_mult);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int position_count = Strategy_OwnedPositionCount();
   if(position_count <= 0)
      return;
   if(!Strategy_OwnedPositionStateValid())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   const datetime entry_time = Strategy_CurrentEntryTime();
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(entry_time <= 0 || entry_time > TimeCurrent())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   if(current_month_key > 0 &&
      Strategy_MonthKeyForTime(entry_time) != current_month_key)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_MaxHoldExceeded())
      Strategy_CloseOwnedPositions(QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

int OnInit()
  {
   SymbolSelect(g_strategy_symbol, true);

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

   g_attempt_state_key =
      StringFormat("QM5_20296_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   if((bool)MQLInfoInteger(MQL_TESTER))
     {
      if(GlobalVariableCheck(g_attempt_state_key))
         GlobalVariableDel(g_attempt_state_key);
      g_last_attempt_month_key = 0;
     }
   else
      Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1] = {g_strategy_symbol};
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                           MathMax(500, strategy_history_bars_d1));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20296\",\"ea\":\"xng-skew-prem\",\"stat\":\"prior_12m_absolute_pearson_skewness\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   g_monthly_rebalance_bar = false;
   if(new_bar)
      Strategy_DetectMonthlyRebalance_OnNewBar();

   // Lifecycle repair and prior-month liquidation precede every entry-only gate.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(!new_bar)
      return;
   if(g_monthly_rebalance_bar)
      Strategy_PrepareMonthlySignal();

   // The month attempt is persisted before news, spread, quote, sizing, and order gates.
   if(Strategy_NewsFilterHook(broker_now))
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
