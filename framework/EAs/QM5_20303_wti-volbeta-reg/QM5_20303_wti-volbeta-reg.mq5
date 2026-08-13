#property strict
#property version   "5.0"
#property description "QM5_20303 WTI Self-Relative Smooth-Volatility-Beta Regime"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20303 - WTI Self-Relative Smooth-Volatility-Beta Regime
// -----------------------------------------------------------------------------
// Source lineage: Hollstein, Prokopczuk & Tharann (2021) define a monthly
// smooth aggregate-volatility beta commodity characteristic and report a
// positive high-minus-low baseline spread. This EA is a disclosed price-native
// time-series translation, not a replication of their option-derived factor.
// At each genuine broker-month transition it:
//   1. loads exactly 545 synchronized completed XTI/XNG D1 closes;
//   2. forms two disjoint blocks of exactly 272 chronological simple returns;
//   3. independently builds an inverse-volatility common-energy factor,
//      two-sigma jump-zeroed 20-return volatility changes, and 252-row OLS;
//   4. buys WTI when recent smooth-volatility beta is higher, sells when lower,
//      and consumes a tie or invalid state flat. XNG is read-only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20303;
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
input int    strategy_returns_per_block        = 272;
input int    strategy_ols_observations         = 252;
input int    strategy_recent_block_offset      = 272;
input int    strategy_history_bars_d1          = 545;
input int    strategy_rv_window_d1             = 20;
input double strategy_jump_exclusion_z         = 2.0;
input int    strategy_min_smooth_days          = 200;
input int    strategy_max_endpoint_gap_days    = 10;
input double strategy_beta_tolerance           = 1.0e-12;
input int    strategy_atr_period_d1             = 20;
input double strategy_atr_sl_mult               = 3.5;
input int    strategy_max_hold_days             = 40;
input int    strategy_max_spread_points         = 1500;

const string g_strategy_symbol = "XTIUSD.DWX";
const string g_factor_symbol   = "XNGUSD.DWX";

bool   g_monthly_rebalance_bar  = false;
bool   g_cache_signal_valid     = false;
int    g_cache_signal           = 0;
int    g_cache_month_key        = 0;
int    g_last_attempt_month_key = 0;
string g_attempt_state_key      = "";
datetime g_decision_bar_time    = 0;
double g_cache_recent_beta       = 0.0;
double g_cache_preceding_beta    = 0.0;
double g_cache_beta_difference   = 0.0;
double g_cache_recent_xti_weight = 0.0;
double g_cache_recent_xng_weight = 0.0;
double g_cache_preceding_xti_weight = 0.0;
double g_cache_preceding_xng_weight = 0.0;
int    g_cache_rate_count        = 0;
int    g_cache_recent_ols_rows   = 0;
int    g_cache_preceding_ols_rows = 0;
int    g_cache_recent_smooth_days = 0;
int    g_cache_preceding_smooth_days = 0;
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
   g_cache_recent_beta = 0.0;
   g_cache_preceding_beta = 0.0;
   g_cache_beta_difference = 0.0;
   g_cache_recent_xti_weight = 0.0;
   g_cache_recent_xng_weight = 0.0;
   g_cache_preceding_xti_weight = 0.0;
   g_cache_preceding_xng_weight = 0.0;
   g_cache_rate_count = 0;
   g_cache_recent_ols_rows = 0;
   g_cache_preceding_ols_rows = 0;
   g_cache_recent_smooth_days = 0;
   g_cache_preceding_smooth_days = 0;
   g_cache_state_reason = "not_evaluated";
  }

bool Strategy_RollingSampleStd(const double &values[],
                               const int end_index,
                               const int window,
                               double &stddev)
  {
   stddev = 0.0;
   const int first = end_index - window + 1;
   if(window < 2 || first < 0 || end_index >= ArraySize(values))
      return false;

   double sum = 0.0;
   for(int i = first; i <= end_index; ++i)
     {
      if(!MathIsValidNumber(values[i]))
         return false;
      sum += values[i];
     }
   const double mean = sum / (double)window;

   double ss = 0.0;
   for(int i = first; i <= end_index; ++i)
     {
      const double centered = values[i] - mean;
      ss += centered * centered;
     }
   stddev = MathSqrt(ss / (double)(window - 1));
   return (stddev > 0.0 && MathIsValidNumber(stddev));
  }

bool Strategy_ComputeVolBetaBlock(const double &xti_returns[],
                                  const double &xng_returns[],
                                  const int block_offset,
                                  double &smooth_beta,
                                  double &xti_weight,
                                  double &xng_weight,
                                  int &ols_rows,
                                  int &smooth_days)
  {
   smooth_beta = 0.0;
   xti_weight = 0.0;
   xng_weight = 0.0;
   ols_rows = 0;
   smooth_days = 0;

   const int total_returns = ArraySize(xti_returns);
   if(total_returns != ArraySize(xng_returns) ||
      strategy_returns_per_block != 272 ||
      strategy_ols_observations != 252 ||
      strategy_rv_window_d1 != 20 ||
      strategy_returns_per_block - strategy_rv_window_d1 !=
         strategy_ols_observations ||
      block_offset < 0 ||
      block_offset + strategy_returns_per_block > total_returns)
      return false;

   const int rank_start = strategy_rv_window_d1;
   double xti_sum = 0.0;
   double xng_sum = 0.0;
   for(int local = rank_start; local < strategy_returns_per_block; ++local)
     {
      const int index = block_offset + local;
      if(!MathIsValidNumber(xti_returns[index]) ||
         !MathIsValidNumber(xng_returns[index]))
         return false;
      xti_sum += xti_returns[index];
      xng_sum += xng_returns[index];
     }
   const double xti_mean =
      xti_sum / (double)strategy_ols_observations;
   const double xng_mean =
      xng_sum / (double)strategy_ols_observations;

   double xti_ss = 0.0;
   double xng_ss = 0.0;
   for(int local = rank_start; local < strategy_returns_per_block; ++local)
     {
      const int index = block_offset + local;
      const double xti_centered = xti_returns[index] - xti_mean;
      const double xng_centered = xng_returns[index] - xng_mean;
      xti_ss += xti_centered * xti_centered;
      xng_ss += xng_centered * xng_centered;
     }
   const double xti_stddev =
      MathSqrt(xti_ss / (double)(strategy_ols_observations - 1));
   const double xng_stddev =
      MathSqrt(xng_ss / (double)(strategy_ols_observations - 1));
   if(xti_stddev <= 1.0e-12 || xng_stddev <= 1.0e-12 ||
      !MathIsValidNumber(xti_stddev) ||
      !MathIsValidNumber(xng_stddev))
      return false;

   const double inverse_vol_sum =
      1.0 / xti_stddev + 1.0 / xng_stddev;
   if(inverse_vol_sum <= 0.0 || !MathIsValidNumber(inverse_vol_sum))
      return false;
   xti_weight = (1.0 / xti_stddev) / inverse_vol_sum;
   xng_weight = (1.0 / xng_stddev) / inverse_vol_sum;
   if(xti_weight <= 0.0 || xng_weight <= 0.0 ||
      !MathIsValidNumber(xti_weight) ||
      !MathIsValidNumber(xng_weight) ||
      MathAbs(xti_weight + xng_weight - 1.0) > 1.0e-12)
      return false;

   double market_returns[];
   if(ArrayResize(market_returns, strategy_returns_per_block) !=
      strategy_returns_per_block)
      return false;
   for(int local = 0; local < strategy_returns_per_block; ++local)
     {
      const int index = block_offset + local;
      market_returns[local] =
         xti_weight * xti_returns[index] +
         xng_weight * xng_returns[index];
      if(!MathIsValidNumber(market_returns[local]))
         return false;
     }

   double market_sum = 0.0;
   for(int local = rank_start; local < strategy_returns_per_block; ++local)
      market_sum += market_returns[local];
   const double market_mean =
      market_sum / (double)strategy_ols_observations;

   double market_ss = 0.0;
   for(int local = rank_start; local < strategy_returns_per_block; ++local)
     {
      const double centered = market_returns[local] - market_mean;
      market_ss += centered * centered;
     }
   const double market_stddev =
      MathSqrt(market_ss / (double)(strategy_ols_observations - 1));
   if(market_stddev <= 1.0e-12 || !MathIsValidNumber(market_stddev))
      return false;

   const double jump_threshold =
      strategy_jump_exclusion_z * market_stddev;
   if(jump_threshold <= 0.0 || !MathIsValidNumber(jump_threshold))
      return false;

   double normal[3][4];
   for(int row = 0; row < 3; ++row)
      for(int col = 0; col < 4; ++col)
         normal[row][col] = 0.0;

   for(int local = rank_start; local < strategy_returns_per_block; ++local)
     {
      double rv_current = 0.0;
      double rv_previous = 0.0;
      if(!Strategy_RollingSampleStd(market_returns,
                                    local,
                                    strategy_rv_window_d1,
                                    rv_current) ||
         !Strategy_RollingSampleStd(market_returns,
                                    local - 1,
                                    strategy_rv_window_d1,
                                    rv_previous))
         return false;

      const bool jump_day =
         (MathAbs(market_returns[local] - market_mean) >= jump_threshold);
      const double smooth_change =
         jump_day ? 0.0 : rv_current - rv_previous;
      if(!jump_day)
         ++smooth_days;

      double x[3];
      x[0] = 1.0;
      x[1] = market_returns[local];
      x[2] = smooth_change;
      const double y = xti_returns[block_offset + local];
      if(!MathIsValidNumber(y) || !MathIsValidNumber(smooth_change))
         return false;

      for(int row = 0; row < 3; ++row)
        {
         for(int col = 0; col < 3; ++col)
            normal[row][col] += x[row] * x[col];
         normal[row][3] += x[row] * y;
        }
      ++ols_rows;
     }

   if(ols_rows != strategy_ols_observations ||
      smooth_days < strategy_min_smooth_days)
      return false;
   for(int row = 0; row < 3; ++row)
      for(int col = 0; col < 4; ++col)
         if(!MathIsValidNumber(normal[row][col]))
            return false;

   // Deterministic partial-pivot Gaussian elimination of the 3x3 normal
   // equation. A singular or nonfinite state consumes the month flat.
   for(int pivot_col = 0; pivot_col < 3; ++pivot_col)
     {
      int pivot_row = pivot_col;
      double pivot_abs = MathAbs(normal[pivot_col][pivot_col]);
      for(int candidate = pivot_col + 1; candidate < 3; ++candidate)
        {
         const double candidate_abs =
            MathAbs(normal[candidate][pivot_col]);
         if(candidate_abs > pivot_abs)
           {
            pivot_abs = candidate_abs;
            pivot_row = candidate;
           }
        }
      if(pivot_abs <= 1.0e-16 || !MathIsValidNumber(pivot_abs))
         return false;

      if(pivot_row != pivot_col)
        {
         for(int col = pivot_col; col < 4; ++col)
           {
            const double swap_value = normal[pivot_col][col];
            normal[pivot_col][col] = normal[pivot_row][col];
            normal[pivot_row][col] = swap_value;
           }
        }

      const double divisor = normal[pivot_col][pivot_col];
      if(MathAbs(divisor) <= 1.0e-16 || !MathIsValidNumber(divisor))
         return false;
      for(int col = pivot_col; col < 4; ++col)
         normal[pivot_col][col] /= divisor;

      for(int row = 0; row < 3; ++row)
        {
         if(row == pivot_col)
            continue;
         const double factor = normal[row][pivot_col];
         for(int col = pivot_col; col < 4; ++col)
            normal[row][col] -= factor * normal[pivot_col][col];
        }
     }

   smooth_beta = normal[2][3];
   return MathIsValidNumber(smooth_beta);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &signal)
  {
   signal = 0;
   if(decision_bar_time <= 0 ||
      strategy_returns_per_block != 272 ||
      strategy_ols_observations != 252 ||
      strategy_recent_block_offset != 272 ||
      strategy_history_bars_d1 != 545 ||
      strategy_rv_window_d1 != 20 ||
      MathAbs(strategy_jump_exclusion_z - 2.0) > 1.0e-12 ||
      strategy_min_smooth_days != 200 ||
      strategy_max_endpoint_gap_days != 10 ||
      MathAbs(strategy_beta_tolerance - 1.0e-12) > 1.0e-22)
     {
      g_cache_state_reason = "bad_volbeta_contract";
      return false;
     }

   MqlRates xti_rates[];
   MqlRates xng_rates[];
   ArraySetAsSeries(xti_rates, true);
   ArraySetAsSeries(xng_rates, true);
   const int xti_count = CopyRates(g_strategy_symbol, // perf-allowed: two bounded completed-D1 reads only on the monthly decision bar.
                                   PERIOD_D1,
                                   1,
                                   strategy_history_bars_d1,
                                   xti_rates);
   const int xng_count = CopyRates(g_factor_symbol, // perf-allowed: read-only synchronized factor history on the same monthly path.
                                   PERIOD_D1,
                                   1,
                                   strategy_history_bars_d1,
                                   xng_rates);
   if(xti_count != strategy_history_bars_d1 ||
      xng_count != strategy_history_bars_d1 ||
      ArraySize(xti_rates) != strategy_history_bars_d1 ||
      ArraySize(xng_rates) != strategy_history_bars_d1)
     {
      g_cache_state_reason = "insufficient_synchronized_history";
      return false;
     }

   const datetime newest_completed_time = xti_rates[0].time;
   if(newest_completed_time <= 0 ||
      newest_completed_time != xng_rates[0].time ||
      newest_completed_time >= decision_bar_time)
     {
      g_cache_state_reason = "invalid_completed_endpoint";
      return false;
     }
   const long endpoint_gap =
      (long)(decision_bar_time - newest_completed_time);
   const long maximum_gap =
      (long)strategy_max_endpoint_gap_days * 86400;
   if(endpoint_gap < 0 || endpoint_gap > maximum_gap)
     {
      g_cache_state_reason = "stale_completed_endpoint";
      return false;
     }

   for(int i = 0; i < strategy_history_bars_d1; ++i)
     {
      if(xti_rates[i].time <= 0 ||
         xti_rates[i].time != xng_rates[i].time ||
         xti_rates[i].close <= 0.0 ||
         xng_rates[i].close <= 0.0 ||
         !MathIsValidNumber(xti_rates[i].close) ||
         !MathIsValidNumber(xng_rates[i].close))
        {
         g_cache_state_reason = "invalid_synchronized_close";
         return false;
        }
      if(i + 1 < strategy_history_bars_d1 &&
         xti_rates[i].time <= xti_rates[i + 1].time)
        {
         g_cache_state_reason = "invalid_series_chronology";
         return false;
        }
     }

   const int total_returns =
      strategy_returns_per_block * 2;
   double xti_returns[];
   double xng_returns[];
   if(ArrayResize(xti_returns, total_returns) != total_returns ||
      ArrayResize(xng_returns, total_returns) != total_returns)
     {
      g_cache_state_reason = "return_allocation_failed";
      return false;
     }

   // CopyRates is newest-first; write the 544 simple returns oldest-first so
   // indices 0..271 are preceding and 272..543 are recent.
   for(int sample = 0; sample < total_returns; ++sample)
     {
      const int older_index = total_returns - sample;
      const int newer_index = older_index - 1;
      const double xti_value =
         xti_rates[newer_index].close / xti_rates[older_index].close - 1.0;
      const double xng_value =
         xng_rates[newer_index].close / xng_rates[older_index].close - 1.0;
      if(!MathIsValidNumber(xti_value) ||
         !MathIsValidNumber(xng_value))
        {
         g_cache_state_reason = "invalid_simple_return";
         return false;
        }
      xti_returns[sample] = xti_value;
      xng_returns[sample] = xng_value;
     }

   if(!Strategy_ComputeVolBetaBlock(xti_returns,
                                    xng_returns,
                                    0,
                                    g_cache_preceding_beta,
                                    g_cache_preceding_xti_weight,
                                    g_cache_preceding_xng_weight,
                                    g_cache_preceding_ols_rows,
                                    g_cache_preceding_smooth_days))
     {
      g_cache_state_reason = "invalid_preceding_volbeta";
      return false;
     }
   if(!Strategy_ComputeVolBetaBlock(xti_returns,
                                    xng_returns,
                                    strategy_recent_block_offset,
                                    g_cache_recent_beta,
                                    g_cache_recent_xti_weight,
                                    g_cache_recent_xng_weight,
                                    g_cache_recent_ols_rows,
                                    g_cache_recent_smooth_days))
     {
      g_cache_state_reason = "invalid_recent_volbeta";
      return false;
     }

   g_cache_beta_difference =
      g_cache_recent_beta - g_cache_preceding_beta;
   g_cache_rate_count = xti_count;
   if(g_cache_preceding_ols_rows != strategy_ols_observations ||
      g_cache_recent_ols_rows != strategy_ols_observations ||
      g_cache_preceding_smooth_days < strategy_min_smooth_days ||
      g_cache_recent_smooth_days < strategy_min_smooth_days ||
      !MathIsValidNumber(g_cache_beta_difference))
     {
      g_cache_state_reason = "invalid_beta_comparison";
      return false;
     }

   // Preserve the source's positive high-minus-low orientation in the
   // translated own-history state: high recent beta is long WTI.
   if(g_cache_beta_difference > strategy_beta_tolerance)
      signal = 1;
   else if(g_cache_beta_difference < -strategy_beta_tolerance)
      signal = -1;
   else
     {
      g_cache_state_reason = "volbeta_tie";
      return true;
     }
   g_cache_state_reason =
      (signal > 0) ? "qualified_long" : "qualified_short";
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
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"valid\":%s,\"signal\":%d,\"recent_beta\":%.12e,\"preceding_beta\":%.12e,\"difference\":%.12e,\"recent_xti_weight\":%.10f,\"recent_xng_weight\":%.10f,\"preceding_xti_weight\":%.10f,\"preceding_xng_weight\":%.10f,\"recent_ols_rows\":%d,\"preceding_ols_rows\":%d,\"recent_smooth_days\":%d,\"preceding_smooth_days\":%d,\"rates\":%d,\"state\":\"%s\"}",
                             g_cache_month_key,
                             (long)g_decision_bar_time,
                             g_cache_signal_valid ? "true" : "false",
                             g_cache_signal,
                             g_cache_recent_beta,
                             g_cache_preceding_beta,
                             g_cache_beta_difference,
                             g_cache_recent_xti_weight,
                             g_cache_recent_xng_weight,
                             g_cache_preceding_xti_weight,
                             g_cache_preceding_xng_weight,
                             g_cache_recent_ols_rows,
                             g_cache_preceding_ols_rows,
                             g_cache_recent_smooth_days,
                             g_cache_preceding_smooth_days,
                             g_cache_rate_count,
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
   if(!Strategy_IsHostChart() || qm_ea_id != 20303 ||
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
   if(strategy_returns_per_block != 272 ||
      strategy_ols_observations != 252 ||
      strategy_recent_block_offset != 272 ||
      strategy_history_bars_d1 != 545 ||
      strategy_rv_window_d1 != 20 ||
      MathAbs(strategy_jump_exclusion_z - 2.0) > 1.0e-12 ||
      strategy_min_smooth_days != 200 ||
      strategy_max_endpoint_gap_days != 10 ||
      MathAbs(strategy_beta_tolerance - 1.0e-12) > 1.0e-22)
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
   req.reason = "QM5_20303_WTI_VOLBETA_REGIME";
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
   req.reason = (g_cache_signal > 0) ? "VOLBETA_REGIME_XTI_LONG" : "VOLBETA_REGIME_XTI_SHORT";
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
   SymbolSelect(g_factor_symbol, true);

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
      StringFormat("QM5_20303_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   if((bool)MQLInfoInteger(MQL_TESTER))
     {
      if(GlobalVariableCheck(g_attempt_state_key))
         GlobalVariableDel(g_attempt_state_key);
      g_last_attempt_month_key = 0;
     }
   else
      Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[2] = {g_strategy_symbol, g_factor_symbol};
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20303\",\"ea\":\"wti-volbeta-reg\",\"stat\":\"two_disjoint_272_return_block_local_smooth_volatility_beta\",\"xng\":\"read_only\"}");
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
