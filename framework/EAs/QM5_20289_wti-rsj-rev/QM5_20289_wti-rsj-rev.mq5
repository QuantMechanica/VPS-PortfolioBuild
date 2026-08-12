#property strict
#property version   "5.0"
#property description "QM5_20289 WTI Signed-Semivariance Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20289 - WTI Signed-Semivariance Reversal
// -----------------------------------------------------------------------------
// Source lineage: Kiss & Ferreira Batista Martins (2025) define normalized
// realized signed semivariance (RSJ), document a negative cross-sectional
// commodity premium, and include WTI. The outright WTI zero-pivot time-series
// reversal below is a transparent, locked QM hypothesis, not a source result.
// At each genuine broker-month transition:
//   1. select adjacent completed D1 closes wholly inside the prior month;
//   2. sum squared positive and negative log returns separately;
//   3. normalize their difference by total realized variance;
//   4. buy negative RSJ, sell positive RSJ, and consume exact zero flat.
// Runtime uses native XTIUSD.DWX price and broker data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20289;
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
input int    strategy_lookback_months          = 1;
input int    strategy_min_return_observations  = 15;
input int    strategy_max_return_observations  = 25;
input double strategy_rsj_tolerance            = 1.0e-12;
input int    strategy_history_bars_d1          = 80;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 40;
input int    strategy_max_spread_points        = 1500;

const string g_strategy_symbol = "XTIUSD.DWX";

bool   g_monthly_rebalance_bar  = false;
bool   g_cache_signal_valid     = false;
int    g_cache_signal           = 0;
int    g_cache_month_key        = 0;
int    g_last_attempt_month_key = 0;
string g_attempt_state_key      = "";
double g_cache_rsj              = 0.0;
double g_cache_rv_plus          = 0.0;
double g_cache_rv_minus         = 0.0;
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
   g_cache_rsj = 0.0;
   g_cache_rv_plus = 0.0;
   g_cache_rv_minus = 0.0;
   g_cache_return_count = 0;
   g_cache_state_reason = "not_evaluated";
  }

bool Strategy_LoadSignalState(int &signal)
  {
   signal = 0;
   if(strategy_lookback_months != 1 ||
      strategy_min_return_observations != 15 ||
      strategy_max_return_observations != 25 ||
      MathAbs(strategy_rsj_tolerance - 1.0e-12) > 1.0e-22 ||
      strategy_history_bars_d1 != 80)
     {
      g_cache_state_reason = "bad_rsj_contract";
      return false;
     }

   const int expected_previous_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, strategy_lookback_months);
   const int current_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(expected_previous_month <= 0 ||
      current_month <= 0 ||
      expected_previous_month == current_month)
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

   int first_prior_index = -1;
   int last_prior_index = -1;
   bool left_prior_month = false;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time <= 0 ||
         (i > 0 && rates[i].time <= rates[i - 1].time))
        {
         g_cache_state_reason = "non_increasing_daily_time";
         return false;
        }

      const int month_key = Strategy_MonthKeyForTime(rates[i].time);
      if(month_key <= 0)
        {
         g_cache_state_reason = "invalid_daily_month";
         return false;
        }

      if(month_key == expected_previous_month)
        {
         if(left_prior_month)
           {
            g_cache_state_reason = "disjoint_prior_month";
            return false;
           }
         if(rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
           {
            g_cache_state_reason = "invalid_prior_month_close";
            return false;
           }
         if(first_prior_index < 0)
            first_prior_index = i;
         last_prior_index = i;
        }
      else if(first_prior_index >= 0)
         left_prior_month = true;
     }

   if(first_prior_index < 0 || last_prior_index <= first_prior_index)
     {
      g_cache_state_reason = "prior_month_not_reconstructed";
      return false;
     }

   const int return_count = last_prior_index - first_prior_index;
   if(return_count < strategy_min_return_observations ||
      return_count > strategy_max_return_observations)
     {
      g_cache_state_reason = "return_count_out_of_bounds";
      return false;
     }

   double rv_plus = 0.0;
   double rv_minus = 0.0;
   for(int i = first_prior_index + 1; i <= last_prior_index; ++i)
     {
      const int prior_key = Strategy_MonthKeyForTime(rates[i - 1].time);
      const int current_key = Strategy_MonthKeyForTime(rates[i].time);
      if(prior_key != expected_previous_month ||
         current_key != expected_previous_month)
        {
         g_cache_state_reason = "return_crosses_month_boundary";
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
      const double squared_return = daily_return * daily_return;
      if(!MathIsValidNumber(daily_return) ||
         !MathIsValidNumber(squared_return) ||
         squared_return < 0.0)
        {
         g_cache_state_reason = "invalid_daily_return";
         return false;
        }

      if(daily_return > 0.0)
         rv_plus += squared_return;
      else if(daily_return < 0.0)
         rv_minus += squared_return;
     }

   const double total_variance = rv_plus + rv_minus;
   if(!MathIsValidNumber(rv_plus) ||
      !MathIsValidNumber(rv_minus) ||
      !MathIsValidNumber(total_variance) ||
      rv_plus < 0.0 ||
      rv_minus < 0.0 ||
      total_variance <= 0.0)
     {
      g_cache_state_reason = "invalid_total_variance";
      return false;
     }

   const double rsj = (rv_plus - rv_minus) / total_variance;
   if(!MathIsValidNumber(rsj) ||
      rsj < -1.0 - strategy_rsj_tolerance ||
      rsj > 1.0 + strategy_rsj_tolerance)
     {
      g_cache_state_reason = "rsj_out_of_bounds";
      return false;
     }

   g_cache_rsj = rsj;
   g_cache_rv_plus = rv_plus;
   g_cache_rv_minus = rv_minus;
   g_cache_return_count = return_count;
   if(rsj == 0.0)
     {
      g_cache_state_reason = "exact_zero_rsj";
      return true;
     }

   signal = (rsj < 0.0) ? 1 : -1;
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
               StringFormat("{\"month\":%d,\"valid\":%s,\"signal\":%d,\"rsj\":%.12f,\"rv_plus\":%.12e,\"rv_minus\":%.12e,\"returns\":%d,\"state\":\"%s\"}",
                            g_cache_month_key,
                            g_cache_signal_valid ? "true" : "false",
                            g_cache_signal,
                            g_cache_rsj,
                            g_cache_rv_plus,
                            g_cache_rv_minus,
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
   if(!Strategy_IsHostChart() || qm_ea_id != 20289 ||
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
   if(strategy_lookback_months != 1 ||
      strategy_min_return_observations != 15 ||
      strategy_max_return_observations != 25 ||
      MathAbs(strategy_rsj_tolerance - 1.0e-12) > 1.0e-22)
      return true;
   if(strategy_history_bars_d1 != 80)
      return true;
   if(strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 40 ||
      strategy_max_spread_points != 1500)
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
   req.reason = "QM5_20289_WTI_RSJ_REV";
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
   req.reason = (g_cache_signal > 0) ? "RSJ_REV_XTI_LONG" : "RSJ_REV_XTI_SHORT";
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
      StringFormat("QM5_20289_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
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
                          MathMax(80, strategy_history_bars_d1));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20289\",\"ea\":\"wti-rsj-rev\",\"stat\":\"prior_month_absolute_rsj_reversal\"}");
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
