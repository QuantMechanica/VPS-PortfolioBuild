#property strict
#property version   "5.0"
#property description "QM5_13134 XTI Memory-Enhanced Variance-Ratio Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13134 - XTI Memory-Enhanced Variance-Ratio Momentum
// -----------------------------------------------------------------------------
// Source baseline: Mehlitz & Auer (2024), R1-q2 short-memory momentum.
// At each broker-month transition:
//   1. derive 32 completed monthly log returns from D1 month-end closes;
//   2. calculate the q=2 Lo-MacKinlay heteroskedasticity-robust VR test;
//   3. continue the latest monthly return when persistence is significant;
//   4. reverse it when anti-persistence is significant; otherwise stay flat.
// Runtime uses native XTIUSD.DWX price/broker data only. No external feed or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13134;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_vr_window_months    = 32;
input int    strategy_vr_q                = 2;
input double strategy_significance_z      = 1.64485362695147;
input int    strategy_history_bars_d1     = 1200;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 35;
input int    strategy_max_spread_points   = 1500;

const string g_strategy_symbol = "XTIUSD.DWX";

bool   g_monthly_rebalance_bar = false;
bool   g_cache_signal_valid    = false;
int    g_cache_signal          = 0;
int    g_cache_month_key       = 0;
int    g_last_entry_month_key  = 0;
double g_cache_latest_return   = 0.0;
double g_cache_variance_ratio  = 0.0;
double g_cache_z               = 0.0;

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

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

int Strategy_ManagedPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         ++count;
     }
   return count;
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

void Strategy_CloseManagedPositions(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsManagedPosition())
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
   if(month_key <= 0 || g_last_entry_month_key == month_key)
      return true;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsManagedPosition())
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
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
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

bool Strategy_LoadMonthlyReturns(double &returns[])
  {
   ArrayResize(returns, 0);
   if(strategy_vr_window_months != 32 || strategy_history_bars_d1 < 800)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_history_bars_d1, rates); // perf-allowed: bounded bulk read reached only from the new-month D1 gate.
   if(copied <= 0)
      return false;

   double month_end_closes[];
   int month_keys[];
   ArrayResize(month_end_closes, copied);
   ArrayResize(month_keys, copied);
   int month_count = 0;

   for(int i = 0; i < copied; ++i)
     {
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
         ++month_count;
        }
      else
         month_end_closes[month_count - 1] = close_value;
     }

   const int required_closes = strategy_vr_window_months + 1;
   if(month_count < required_closes)
      return false;

   ArrayResize(returns, strategy_vr_window_months);
   const int start = month_count - required_closes;
   for(int i = 0; i < strategy_vr_window_months; ++i)
     {
      const double prior_close = month_end_closes[start + i];
      const double current_close = month_end_closes[start + i + 1];
      if(prior_close <= 0.0 || current_close <= 0.0)
         return false;
      const double monthly_return = MathLog(current_close / prior_close);
      if(!MathIsValidNumber(monthly_return))
         return false;
      returns[i] = monthly_return;
     }
   return true;
  }

bool Strategy_VarianceRatioSignal(const double &returns[],
                                  int &signal,
                                  double &latest_return,
                                  double &variance_ratio,
                                  double &z_value)
  {
   signal = 0;
   latest_return = 0.0;
   variance_ratio = 0.0;
   z_value = 0.0;

   const int count = ArraySize(returns);
   if(count != strategy_vr_window_months || count != 32 || strategy_vr_q != 2)
      return false;

   double sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      if(!MathIsValidNumber(returns[i]))
         return false;
      sum += returns[i];
     }
   const double mean = sum / (double)count;

   double squared_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double delta = returns[i] - mean;
      squared_sum += delta * delta;
     }
   if(squared_sum <= 0.0 || !MathIsValidNumber(squared_sum))
      return false;

   double lag_cross_sum = 0.0;
   double robust_numerator = 0.0;
   for(int i = 1; i < count; ++i)
     {
      const double current_delta = returns[i] - mean;
      const double prior_delta = returns[i - 1] - mean;
      lag_cross_sum += current_delta * prior_delta;
      robust_numerator += current_delta * current_delta * prior_delta * prior_delta;
     }

   const double rho_one = lag_cross_sum / squared_sum;
   variance_ratio = 1.0 + rho_one; // q=2: weight on rho(1) is exactly one.
   const double robust_se = MathSqrt(robust_numerator / (squared_sum * squared_sum));
   if(robust_se <= 0.0 || !MathIsValidNumber(robust_se) ||
      !MathIsValidNumber(variance_ratio))
      return false;

   z_value = (variance_ratio - 1.0) / robust_se;
   latest_return = returns[count - 1];
   if(!MathIsValidNumber(z_value) || !MathIsValidNumber(latest_return))
      return false;

   if(MathAbs(z_value) <= strategy_significance_z || latest_return == 0.0)
      return true;

   const int momentum_sign = (latest_return > 0.0) ? 1 : -1;
   const int memory_sign = (z_value > 0.0) ? 1 : -1;
   signal = momentum_sign * memory_sign;
   return true;
  }

bool Strategy_LoadSignalState(int &signal)
  {
   signal = 0;
   double monthly_returns[];
   if(!Strategy_LoadMonthlyReturns(monthly_returns))
      return false;

   return Strategy_VarianceRatioSignal(monthly_returns,
                                       signal,
                                       g_cache_latest_return,
                                       g_cache_variance_ratio,
                                       g_cache_z);
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_signal_valid = false;
   g_cache_signal = 0;

   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 || current_month_key == prior_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(g_cache_signal);

   QM_LogEvent(QM_INFO,
               "VR_MONTHLY_SIGNAL",
               StringFormat("{\"month\":%d,\"valid\":%s,\"signal\":%d,\"latest_return\":%.10f,\"vr\":%.10f,\"z\":%.10f}",
                            g_cache_month_key,
                            g_cache_signal_valid ? "true" : "false",
                            g_cache_signal,
                            g_cache_latest_return,
                            g_cache_variance_ratio,
                            g_cache_z));
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
   if(!Strategy_IsHostChart() || qm_ea_id != 13134)
      return true;
   if(strategy_vr_window_months != 32 || strategy_vr_q != 2)
      return true;
   if(MathAbs(strategy_significance_z - 1.64485362695147) > 1.0e-12)
      return true;
   if(strategy_history_bars_d1 < 800 || strategy_history_bars_d1 > 2000)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_period_d1 > 120)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   if(strategy_max_spread_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13134_ENERGY_VR_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0)
      return false;
   if(Strategy_MonthAlreadyEntered(g_cache_month_key))
      return false;
   if(Strategy_ManagedPositionCount() > 0)
      return false;
   if(!g_cache_signal_valid || g_cache_signal == 0 || !Strategy_SpreadAllowed())
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type = (g_cache_signal > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_cache_signal > 0) ? "VR_MEMORY_XTI_LONG" : "VR_MEMORY_XTI_SHORT";
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
   const int position_count = Strategy_ManagedPositionCount();
   if(position_count <= 0)
      return;
   if(position_count > 1)
     {
      Strategy_CloseManagedPositions(QM_EXIT_STRATEGY);
      return;
     }

   const datetime entry_time = Strategy_CurrentEntryTime();
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(entry_time > 0 && current_month_key > 0 &&
      Strategy_MonthKeyForTime(entry_time) != current_month_key)
     {
      Strategy_CloseManagedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_MaxHoldExceeded())
      Strategy_CloseManagedPositions(QM_EXIT_TIME_STOP);
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

   string warmup_symbols[1] = {g_strategy_symbol};
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          MathMax(800, strategy_history_bars_d1));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13134\",\"ea\":\"energy-vr-mom\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
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
      Strategy_AdvanceSignal_OnNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseManagedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!new_bar)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         g_last_entry_month_key = g_cache_month_key;
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
