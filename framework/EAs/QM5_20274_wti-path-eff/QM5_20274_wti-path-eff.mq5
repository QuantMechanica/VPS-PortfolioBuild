#property strict
#property version   "5.0"
#property description "QM5_20274 WTI Monthly Path-Efficiency Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20274 - WTI Monthly Path-Efficiency Trend
// -----------------------------------------------------------------------------
// Source lineage: Moskowitz, Ooi & Pedersen (2012) monthly WTI own-return trend.
// At each broker-month transition:
//   1. derive thirteen consecutive completed WTI month-end closes from D1 data;
//   2. form twelve chronological adjacent monthly log returns;
//   3. sum the signed returns and their full absolute path length;
//   4. follow the net direction only when abs(net)/path is at least 0.25.
// The path-efficiency gate is a transparent QM mechanization, not an author
// rule. Runtime uses native XTIUSD.DWX price and broker data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20274;
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
input int    strategy_endpoint_count      = 13;
input double strategy_efficiency_threshold = 0.25;
input int    strategy_history_bars_d1     = 800;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.5;
input int    strategy_max_hold_days       = 40;
input int    strategy_max_spread_points   = 1500;

const string g_strategy_symbol = "XTIUSD.DWX";

bool   g_monthly_rebalance_bar  = false;
bool   g_cache_signal_valid     = false;
int    g_cache_signal           = 0;
int    g_cache_month_key        = 0;
int    g_last_attempt_month_key = 0;
string g_attempt_state_key      = "";
double g_cache_net_return       = 0.0;
double g_cache_path_length      = 0.0;
double g_cache_efficiency       = 0.0;
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

bool Strategy_MonthHasOwnedEntry(const int month_key)
  {
   if(month_key <= 0)
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

bool Strategy_AreConsecutiveMonths(const int &month_keys[],
                                   const int start,
                                   const int count)
  {
   if(start < 0 || count <= 1 || start + count > ArraySize(month_keys))
      return false;

   for(int offset = 1; offset < count; ++offset)
     {
      const int prior_key = month_keys[start + offset - 1];
      int expected_year = prior_key / 100;
      int expected_month = prior_key % 100 + 1;
      if(expected_month > 12)
        {
         expected_month = 1;
         ++expected_year;
        }
      const int expected_key = expected_year * 100 + expected_month;
      if(month_keys[start + offset] != expected_key)
         return false;
     }
   return true;
  }

bool Strategy_LoadMonthlyCloses(double &closes[])
  {
   ArrayResize(closes, 0);
   if(strategy_endpoint_count != 13 || strategy_history_bars_d1 != 800)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_history_bars_d1, rates); // perf-allowed: bounded bulk read reached only from the new-month D1 gate.
   if(copied <= 0)
      return false;

   double month_end_closes[];
   datetime month_end_times[];
   int month_keys[];
   ArrayResize(month_end_closes, copied);
   ArrayResize(month_end_times, copied);
   ArrayResize(month_keys, copied);
   int month_count = 0;

   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time <= 0 || (i > 0 && rates[i].time <= rates[i - 1].time))
         return false;
      const double close_value = rates[i].close;
      if(close_value <= 0.0 || !MathIsValidNumber(close_value))
         return false;
      const int month_key = Strategy_MonthKeyForTime(rates[i].time);
      if(month_key <= 0)
         return false;

      if(month_count <= 0 || month_keys[month_count - 1] != month_key)
        {
         month_keys[month_count] = month_key;
         month_end_closes[month_count] = close_value;
         month_end_times[month_count] = rates[i].time;
         ++month_count;
        }
      else
        {
         month_end_closes[month_count - 1] = close_value;
         month_end_times[month_count - 1] = rates[i].time;
        }
     }

   const int required_closes = strategy_endpoint_count;
   if(required_closes != 13 || month_count < required_closes)
      return false;

   const int start = month_count - required_closes;
   if(!Strategy_AreConsecutiveMonths(month_keys, start, required_closes))
      return false;
   for(int i = start + 1; i < month_count; ++i)
      if(month_end_times[i] <= month_end_times[i - 1])
         return false;
   const int expected_previous_month =
      QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(expected_previous_month <= 0 ||
      month_keys[month_count - 1] != expected_previous_month)
      return false;

   ArrayResize(closes, required_closes);
   for(int i = 0; i < required_closes; ++i)
      closes[i] = month_end_closes[start + i];
   return true;
  }

void Strategy_ResetCachedState()
  {
   g_cache_signal_valid = false;
   g_cache_signal = 0;
   g_cache_net_return = 0.0;
   g_cache_path_length = 0.0;
   g_cache_efficiency = 0.0;
   g_cache_state_reason = "not_evaluated";
  }

bool Strategy_PathEfficiencySignal(const double &closes[], int &signal)
  {
   signal = 0;
   const int point_count = strategy_endpoint_count;
   const int interval_count = point_count - 1;
   if(point_count != 13 ||
      interval_count != 12 ||
      MathAbs(strategy_efficiency_threshold - 0.25) > 1.0e-12 ||
      ArraySize(closes) != point_count)
     {
      g_cache_state_reason = "bad_path_efficiency_contract";
      return false;
     }

   double net_return = 0.0;
   double path_length = 0.0;

   for(int i = 0; i < interval_count; ++i)
     {
      const double start_close = closes[i];
      const double end_close = closes[i + 1];
      if(start_close <= 0.0 || end_close <= 0.0 ||
         !MathIsValidNumber(start_close) || !MathIsValidNumber(end_close))
        {
         g_cache_state_reason = "bad_monthly_close";
         return false;
        }
      const double ratio = end_close / start_close;
      if(ratio <= 0.0 || !MathIsValidNumber(ratio))
        {
         g_cache_state_reason = "bad_monthly_ratio";
         return false;
        }
      const double monthly_return = MathLog(ratio);
      if(!MathIsValidNumber(monthly_return))
        {
         g_cache_state_reason = "invalid_monthly_log_return";
         return false;
        }

      net_return += monthly_return;
      path_length += MathAbs(monthly_return);
      if(!MathIsValidNumber(net_return) ||
         !MathIsValidNumber(path_length) ||
         path_length < 0.0)
        {
         g_cache_state_reason = "invalid_path_accumulator";
         return false;
        }
     }

   g_cache_net_return = net_return;
   g_cache_path_length = path_length;
   if(path_length <= 0.0)
     {
      g_cache_efficiency = 0.0;
      g_cache_state_reason = "zero_absolute_path";
      return true;
     }

   const double efficiency = MathAbs(net_return) / path_length;
   if(!MathIsValidNumber(efficiency) ||
      efficiency < 0.0 ||
      efficiency > 1.0 + 1.0e-10)
     {
      g_cache_state_reason = "invalid_path_efficiency";
      return false;
     }
   g_cache_efficiency = efficiency;

   if(net_return > 0.0 &&
      efficiency >= strategy_efficiency_threshold)
     {
      signal = 1;
      g_cache_state_reason = "qualified_long";
     }
   else if(net_return < 0.0 &&
           efficiency >= strategy_efficiency_threshold)
     {
      signal = -1;
      g_cache_state_reason = "qualified_short";
     }
   else if(net_return == 0.0)
      g_cache_state_reason = "zero_net_return";
   else
      g_cache_state_reason = "below_efficiency_threshold";
   return true;
  }

bool Strategy_LoadSignalState(int &signal)
  {
   signal = 0;
   double monthly_closes[];
   if(!Strategy_LoadMonthlyCloses(monthly_closes))
     {
      g_cache_state_reason = "invalid_monthly_history";
      return false;
     }
   return Strategy_PathEfficiencySignal(monthly_closes, signal);
  }

void Strategy_DetectMonthlyRebalance_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_month_key = 0;
   Strategy_ResetCachedState();

   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 || current_month_key == prior_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
  }

void Strategy_PrepareMonthlySignal()
  {
   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0)
      return;
   if(g_last_attempt_month_key == g_cache_month_key)
     {
      g_cache_state_reason = "month_already_consumed";
      return;
     }
   if(!Strategy_RecordMonthAttempt(g_cache_month_key))
     {
      g_cache_state_reason = "attempt_persist_failed";
      return;
     }
   if(Strategy_MonthHasOwnedEntry(g_cache_month_key))
     {
      g_cache_state_reason = "owned_entry_already_exists";
      return;
     }

   g_cache_signal_valid = Strategy_LoadSignalState(g_cache_signal);
   QM_LogEvent(QM_INFO,
               "MONTHLY_STATE",
               StringFormat("{\"month\":%d,\"valid\":%s,\"signal\":%d,\"net_return\":%.12f,\"path_length\":%.12f,\"efficiency\":%.12f,\"state\":\"%s\"}",
                            g_cache_month_key,
                            g_cache_signal_valid ? "true" : "false",
                            g_cache_signal,
                            g_cache_net_return,
                            g_cache_path_length,
                            g_cache_efficiency,
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
   if(!Strategy_IsHostChart() || qm_ea_id != 20274 ||
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
   if(strategy_endpoint_count != 13 ||
      MathAbs(strategy_efficiency_threshold - 0.25) > 1.0e-12)
      return true;
   if(strategy_history_bars_d1 != 800)
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
   req.reason = "QM5_20274_WTI_PATH_EFFICIENCY";
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
   req.reason = (g_cache_signal > 0) ? "PATH_EFFICIENCY_XTI_LONG" : "PATH_EFFICIENCY_XTI_SHORT";
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
      StringFormat("QM5_20274_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
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
                          MathMax(400, strategy_history_bars_d1));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20274\",\"ea\":\"wti-path-eff\"}");
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
