#property strict
#property version   "5.0"
#property description "QM5_20297 XNG Historical-Kurtosis Premium"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20297 - XNG Historical-Kurtosis Premium
// -----------------------------------------------------------------------------
// Source lineage: Hollstein, Prokopczuk & Tharann (2021) define prior-year
// Pearson historical kurtosis, document a positive full-sample cross-sectional
// commodity premium, use monthly sorts, and include XNG. The outright XNG
// benchmark-three time-series rule below is a locked QM hypothesis, not a
// source-tested XNG rule.
// At each genuine broker-month transition:
//   1. load exactly 253 completed D1 closes and form 252 simple returns;
//   2. calculate sample variance (/251) and fourth central moment (/252);
//   3. normalize the fourth moment into raw Pearson kurtosis;
//   4. buy above three, sell below three, and consume a numerical tie flat.
// Runtime uses native XNGUSD.DWX price and broker data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20297;
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
input int    strategy_lookback_d1             = 252;
input int    strategy_history_bars            = 320;
input int    strategy_max_endpoint_gap_days   = 10;
input double strategy_variance_floor          = 1.0e-12;
input double strategy_kurtosis_benchmark      = 3.0;
input double strategy_kurtosis_tolerance      = 1.0e-12;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input int    strategy_max_hold_days           = 40;
input int    strategy_max_spread_points       = 2500;

const string g_strategy_symbol = "XNGUSD.DWX";

bool   g_monthly_rebalance_bar  = false;
bool   g_cache_signal_valid     = false;
int    g_cache_signal           = 0;
int    g_cache_month_key        = 0;
int    g_last_attempt_month_key = 0;
string g_attempt_state_key      = "";
datetime g_decision_bar_time    = 0;
double g_cache_kurtosis         = 0.0;
double g_cache_mean             = 0.0;
double g_cache_variance         = 0.0;
double g_cache_fourth_moment    = 0.0;
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
   g_cache_kurtosis = 0.0;
   g_cache_mean = 0.0;
   g_cache_variance = 0.0;
   g_cache_fourth_moment = 0.0;
   g_cache_return_count = 0;
   g_cache_state_reason = "not_evaluated";
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &signal)
  {
   signal = 0;
   if(decision_bar_time <= 0 ||
      strategy_lookback_d1 != 252 ||
      strategy_history_bars != 320 ||
      strategy_max_endpoint_gap_days != 10 ||
      MathAbs(strategy_variance_floor - 1.0e-12) > 1.0e-22 ||
      MathAbs(strategy_kurtosis_benchmark - 3.0) > 1.0e-12 ||
      MathAbs(strategy_kurtosis_tolerance - 1.0e-12) > 1.0e-22)
     {
      g_cache_state_reason = "bad_kurtosis_contract";
      return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int required_closes = strategy_lookback_d1 + 1;
   const int requested = MathMax(strategy_history_bars, required_closes);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded completed-D1 read only on the monthly decision bar.
                                PERIOD_D1,
                                1,
                                requested,
                                rates);
   if(copied < required_closes)
     {
      g_cache_state_reason = "insufficient_completed_history";
      return false;
     }

   const datetime newest_completed_time = rates[0].time;
   if(newest_completed_time <= 0 || newest_completed_time >= decision_bar_time)
     {
      g_cache_state_reason = "invalid_completed_endpoint";
      return false;
     }
   const long endpoint_gap = (long)(decision_bar_time - newest_completed_time);
   const long maximum_gap = (long)strategy_max_endpoint_gap_days * 86400;
   if(endpoint_gap < 0 || endpoint_gap > maximum_gap)
     {
      g_cache_state_reason = "stale_completed_endpoint";
      return false;
     }

   double returns[];
   if(ArrayResize(returns, strategy_lookback_d1) != strategy_lookback_d1)
     {
      g_cache_state_reason = "return_buffer_failed";
      return false;
     }

   int return_count = 0;
   double return_sum = 0.0;
   for(int i = strategy_lookback_d1; i >= 1; --i)
     {
      const datetime older_time = rates[i].time;
      const datetime newer_time = rates[i - 1].time;
      const double older_close = rates[i].close;
      const double newer_close = rates[i - 1].close;
      if(older_time <= 0 || newer_time <= older_time ||
         older_close <= 0.0 || newer_close <= 0.0 ||
         !MathIsValidNumber(older_close) || !MathIsValidNumber(newer_close))
        {
         g_cache_state_reason = "invalid_chronological_close";
         return false;
        }

      const double daily_return = newer_close / older_close - 1.0;
      if(!MathIsValidNumber(daily_return))
        {
         g_cache_state_reason = "invalid_simple_return";
         return false;
        }
      returns[return_count++] = daily_return;
      return_sum += daily_return;
     }

   if(return_count != strategy_lookback_d1 || return_count < 2)
     {
      g_cache_state_reason = "wrong_return_count";
      return false;
     }

   const double mean = return_sum / (double)return_count;
   if(!MathIsValidNumber(mean))
     {
      g_cache_state_reason = "invalid_return_mean";
      return false;
     }

   double squared_sum = 0.0;
   double fourth_sum = 0.0;
   for(int i = 0; i < return_count; ++i)
     {
      const double centered = returns[i] - mean;
      const double squared = centered * centered;
      squared_sum += squared;
      fourth_sum += squared * squared;
     }

   const double sample_variance = squared_sum / (double)(return_count - 1);
   const double fourth_moment = fourth_sum / (double)return_count;
   if(!MathIsValidNumber(sample_variance) ||
      !MathIsValidNumber(fourth_moment) ||
      sample_variance <= strategy_variance_floor ||
      fourth_moment <= 0.0)
     {
      g_cache_state_reason = "invalid_source_moments";
      return false;
     }

   const double variance_squared = sample_variance * sample_variance;
   const double kurtosis = fourth_moment / variance_squared;
   if(!MathIsValidNumber(variance_squared) ||
      variance_squared <= 0.0 ||
      !MathIsValidNumber(kurtosis) ||
      kurtosis <= 0.0)
     {
      g_cache_state_reason = "invalid_pearson_kurtosis";
      return false;
     }

   g_cache_kurtosis = kurtosis;
   g_cache_mean = mean;
   g_cache_variance = sample_variance;
   g_cache_fourth_moment = fourth_moment;
   g_cache_return_count = return_count;

   if(kurtosis > strategy_kurtosis_benchmark + strategy_kurtosis_tolerance)
      signal = 1;
   else if(kurtosis < strategy_kurtosis_benchmark - strategy_kurtosis_tolerance)
      signal = -1;
   else
     {
      g_cache_state_reason = "benchmark_tie";
      return true;
     }
   g_cache_state_reason = (signal > 0) ? "qualified_long" : "qualified_short";
   return true;
  }

void Strategy_DetectMonthlyRebalance_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_month_key = 0;
   g_decision_bar_time = 0;
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

   MqlRates decision_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, decision_bar) ||
      decision_bar.time <= 0)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_decision_bar_time = decision_bar.time;
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

   g_cache_signal_valid =
      Strategy_LoadSignalState(g_decision_bar_time, g_cache_signal);
   QM_LogEvent(QM_INFO,
               "MONTHLY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"valid\":%s,\"signal\":%d,\"kurtosis\":%.12f,\"benchmark\":%.12f,\"mean\":%.12e,\"variance\":%.12e,\"fourth_moment\":%.12e,\"returns\":%d,\"state\":\"%s\"}",
                             g_cache_month_key,
                             (long)g_decision_bar_time,
                             g_cache_signal_valid ? "true" : "false",
                             g_cache_signal,
                             g_cache_kurtosis,
                             strategy_kurtosis_benchmark,
                             g_cache_mean,
                             g_cache_variance,
                             g_cache_fourth_moment,
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
   if(!Strategy_IsHostChart() || qm_ea_id != 20297 ||
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
   if(strategy_lookback_d1 != 252 ||
      strategy_history_bars != 320 ||
      strategy_max_endpoint_gap_days != 10 ||
      MathAbs(strategy_variance_floor - 1.0e-12) > 1.0e-22 ||
      MathAbs(strategy_kurtosis_benchmark - 3.0) > 1.0e-12 ||
      MathAbs(strategy_kurtosis_tolerance - 1.0e-12) > 1.0e-22)
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
   req.reason = "QM5_20297_XNG_KURT_PREM";
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
   req.reason = (g_cache_signal > 0) ? "KURT_PREM_XNG_LONG" : "KURT_PREM_XNG_SHORT";
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
      StringFormat("QM5_20297_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
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
                          MathMax(400, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20297\",\"ea\":\"xng-kurt-prem\",\"stat\":\"prior_252_return_absolute_pearson_kurtosis\"}");
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
