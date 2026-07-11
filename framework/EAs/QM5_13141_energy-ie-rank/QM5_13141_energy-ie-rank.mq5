#property strict
#property version   "5.0"
#property description "QM5_13141 XTI XNG Idiosyncratic-Exceedance Rank"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13141 - XTI/XNG Monthly Idiosyncratic-Exceedance Rank
// -----------------------------------------------------------------------------
// Monthly structural energy basket translated from Han et al. (2023):
//   - use synchronized simple returns from the six completed broker months
//   - residualize each energy leg on an equal-weight XTI/XNG/XAU/XAG factor
//     and its square
//   - rank P(z >= +0.5) - P(z <= -0.5), buying low IE and selling high IE
//   - split package stop-risk toward equal dollar notional and reject material
//     post-rounding notional mismatch
// XAU and XAG are read-only factor members. Runtime is Darwinex-native OHLC.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13141;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_months    = 6;
input int    strategy_history_bars       = 220;
input int    strategy_min_return_observations = 100;
input double strategy_tail_threshold_sigma = 0.5;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.5;
input double strategy_max_notional_mismatch_pct = 20.0;
input int    strategy_max_hold_days      = 40;
input int    strategy_xti_max_spread_pts = 1500;
input int    strategy_xng_max_spread_pts = 3000;
input int    strategy_deviation_points   = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";
string g_factor_xau = "XAUUSD.DWX";
string g_factor_xag = "XAGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_last_entry_month_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xti_ie = 0.0;
double   g_cache_xng_ie = 0.0;
double   g_cache_ie_difference = 0.0;
int      g_cache_observations = 0;
double   g_cache_notional_mismatch_pct = 0.0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_xng)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xti && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xti && strategy_xti_max_spread_pts > 0)
      return (spread_points <= strategy_xti_max_spread_pts);
   if(symbol == g_leg_xng && strategy_xng_max_spread_pts > 0)
      return (spread_points <= strategy_xng_max_spread_pts);
   return true;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenPairLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         ++count;
     }
   return count;
  }

datetime Strategy_CurrentPairEntryTime()
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

bool Strategy_PairCompositionValid()
  {
   int xti_side = 0;
   int xng_side = 0;
   int pair_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int side = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      if(symbol == g_leg_xti)
        {
         if(xti_side != 0)
            return false;
         xti_side = side;
        }
      else if(symbol == g_leg_xng)
        {
         if(xng_side != 0)
            return false;
         xng_side = side;
        }
      else
         return false;
      ++pair_count;
     }
   return (pair_count == 2 && xti_side != 0 && xng_side != 0 && xti_side == -xng_side);
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

int Strategy_PreviousMonthKey(const int month_key,
                              const int months_back)
  {
   const int year = month_key / 100;
   const int month = month_key % 100;
   if(year <= 0 || month < 1 || month > 12 || months_back <= 0)
      return 0;
   const int serial = year * 12 + month - 1 - months_back;
   if(serial <= 0)
      return 0;
   return (serial / 12) * 100 + (serial % 12) + 1;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
   g_pair_entry_time = 0;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int xti_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   const int xng_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
   return (magic == xti_magic || magic == xng_magic);
  }

bool Strategy_MonthAlreadyEntered(const int month_key)
  {
   if(month_key <= 0 || g_last_entry_month_key == month_key)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
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
      const long magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!Strategy_IsPairMagic(magic))
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

bool Strategy_IdiosyncraticExceedance(const double &asset_returns[],
                                      const double &factor_returns[],
                                      const int count,
                                      double &ie_measure)
  {
   ie_measure = 0.0;
   if(count < strategy_min_return_observations ||
      ArraySize(asset_returns) < count || ArraySize(factor_returns) < count)
      return false;

   // OLS normal equations for [1, market return, squared market return].
   double normal[3][4];
   for(int row = 0; row < 3; ++row)
      for(int col = 0; col < 4; ++col)
         normal[row][col] = 0.0;

   for(int sample = 0; sample < count; ++sample)
     {
      const double market_return = factor_returns[sample];
      const double y = asset_returns[sample];
      if(!MathIsValidNumber(market_return) || !MathIsValidNumber(y))
         return false;
      double x[3];
      x[0] = 1.0;
      x[1] = market_return;
      x[2] = market_return * market_return;
      if(!MathIsValidNumber(x[2]))
         return false;
      for(int row = 0; row < 3; ++row)
        {
         for(int col = 0; col < 3; ++col)
            normal[row][col] += x[row] * x[col];
         normal[row][3] += x[row] * y;
        }
     }

   double matrix_scale = 0.0;
   for(int row = 0; row < 3; ++row)
      for(int col = 0; col < 3; ++col)
         matrix_scale = MathMax(matrix_scale, MathAbs(normal[row][col]));
   if(matrix_scale <= 0.0 || !MathIsValidNumber(matrix_scale))
      return false;
   const double singular_floor = MathMax(1.0e-18, matrix_scale * 1.0e-14);

   // Deterministic Gauss-Jordan elimination with partial pivoting.
   for(int pivot_col = 0; pivot_col < 3; ++pivot_col)
     {
      int pivot_row = pivot_col;
      double pivot_abs = MathAbs(normal[pivot_col][pivot_col]);
      for(int candidate = pivot_col + 1; candidate < 3; ++candidate)
        {
         const double candidate_abs = MathAbs(normal[candidate][pivot_col]);
         if(candidate_abs > pivot_abs)
           {
            pivot_abs = candidate_abs;
            pivot_row = candidate;
           }
        }
      if(pivot_abs <= singular_floor || !MathIsValidNumber(pivot_abs))
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
      if(MathAbs(divisor) <= singular_floor || !MathIsValidNumber(divisor))
         return false;
      for(int col = pivot_col; col < 4; ++col)
         normal[pivot_col][col] /= divisor;

      for(int row = 0; row < 3; ++row)
        {
         if(row == pivot_col)
            continue;
         const double multiplier = normal[row][pivot_col];
         for(int col = pivot_col; col < 4; ++col)
            normal[row][col] -= multiplier * normal[pivot_col][col];
        }
     }

   const double alpha = normal[0][3];
   const double beta = normal[1][3];
   const double gamma = normal[2][3];
   if(!MathIsValidNumber(alpha) || !MathIsValidNumber(beta) ||
      !MathIsValidNumber(gamma))
      return false;

   double residuals[];
   if(ArrayResize(residuals, count) != count)
      return false;
   double residual_sum = 0.0;
   for(int sample = 0; sample < count; ++sample)
     {
      const double market_return = factor_returns[sample];
      residuals[sample] = asset_returns[sample] - alpha -
                          beta * market_return - gamma * market_return * market_return;
      if(!MathIsValidNumber(residuals[sample]))
         return false;
      residual_sum += residuals[sample];
     }

   const double residual_mean = residual_sum / (double)count;
   double residual_sq_sum = 0.0;
   for(int sample = 0; sample < count; ++sample)
     {
      const double centered = residuals[sample] - residual_mean;
      residual_sq_sum += centered * centered;
     }
   const double residual_std = MathSqrt(residual_sq_sum / (double)count);
   if(residual_std <= 0.0 || !MathIsValidNumber(residual_std))
      return false;

   int upper_count = 0;
   int lower_count = 0;
   const double tail_distance = strategy_tail_threshold_sigma * residual_std;
   for(int sample = 0; sample < count; ++sample)
     {
      const double centered = residuals[sample] - residual_mean;
      if(centered >= tail_distance)
         ++upper_count;
      if(centered <= -tail_distance)
         ++lower_count;
     }
   ie_measure = ((double)upper_count - (double)lower_count) / (double)count;
   return MathIsValidNumber(ie_measure);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_ie = 0.0;
   g_cache_xng_ie = 0.0;
   g_cache_ie_difference = 0.0;
   g_cache_observations = 0;

   const int decision_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   if(decision_month_key <= 0)
      return false;

   int expected_month_keys[];
   int month_observations[];
   if(ArrayResize(expected_month_keys, strategy_lookback_months) != strategy_lookback_months ||
      ArrayResize(month_observations, strategy_lookback_months) != strategy_lookback_months)
      return false;
   for(int month_index = 0; month_index < strategy_lookback_months; ++month_index)
     {
      expected_month_keys[month_index] = Strategy_PreviousMonthKey(decision_month_key,
                                                                  month_index + 1);
      month_observations[month_index] = 0;
      if(expected_month_keys[month_index] <= 0)
         return false;
     }

   MqlRates xti_rates[];
   MqlRates xng_rates[];
   MqlRates xau_rates[];
   MqlRates xag_rates[];
   ArraySetAsSeries(xti_rates, true);
   ArraySetAsSeries(xng_rates, true);
   ArraySetAsSeries(xau_rates, true);
   ArraySetAsSeries(xag_rates, true);
   const int xti_count = CopyRates(g_leg_xti, PERIOD_D1, 1, strategy_history_bars, xti_rates); // perf-allowed: bounded monthly D1 history.
   const int xng_count = CopyRates(g_leg_xng, PERIOD_D1, 1, strategy_history_bars, xng_rates); // perf-allowed: bounded monthly D1 history.
   const int xau_count = CopyRates(g_factor_xau, PERIOD_D1, 1, strategy_history_bars, xau_rates); // perf-allowed: bounded monthly read-only factor history.
   const int xag_count = CopyRates(g_factor_xag, PERIOD_D1, 1, strategy_history_bars, xag_rates); // perf-allowed: bounded monthly read-only factor history.
   if(xti_count < strategy_min_return_observations + 1 ||
      xng_count < strategy_min_return_observations + 1 ||
      xau_count < strategy_min_return_observations + 1 ||
      xag_count < strategy_min_return_observations + 1)
      return false;

   double xti_returns[];
   double xng_returns[];
   double factor_returns[];
   if(ArrayResize(xti_returns, strategy_history_bars) != strategy_history_bars ||
      ArrayResize(xng_returns, strategy_history_bars) != strategy_history_bars ||
      ArrayResize(factor_returns, strategy_history_bars) != strategy_history_bars)
      return false;

   int xti_index = 0;
   int xng_index = 0;
   int xau_index = 0;
   int xag_index = 0;
   int observation_count = 0;
   while(xti_index < xti_count - 1 && xng_index < xng_count - 1 &&
         xau_index < xau_count - 1 && xag_index < xag_count - 1)
     {
      const datetime xti_time = xti_rates[xti_index].time;
      const datetime xng_time = xng_rates[xng_index].time;
      const datetime xau_time = xau_rates[xau_index].time;
      const datetime xag_time = xag_rates[xag_index].time;
      datetime latest_time = xti_time;
      if(xng_time > latest_time)
         latest_time = xng_time;
      if(xau_time > latest_time)
         latest_time = xau_time;
      if(xag_time > latest_time)
         latest_time = xag_time;

      const bool common_time = (xti_time == xng_time && xti_time == xau_time &&
                                xti_time == xag_time && xti_time > 0);
      if(common_time)
        {
         const bool common_prior_time =
            (xti_rates[xti_index + 1].time == xng_rates[xng_index + 1].time &&
             xti_rates[xti_index + 1].time == xau_rates[xau_index + 1].time &&
             xti_rates[xti_index + 1].time == xag_rates[xag_index + 1].time &&
             xti_rates[xti_index + 1].time > 0);
         const int observation_month_key = Strategy_MonthKeyForTime(xti_time);
         int expected_index = -1;
         for(int month_index = 0; month_index < strategy_lookback_months; ++month_index)
           {
            if(observation_month_key == expected_month_keys[month_index])
              {
               expected_index = month_index;
               break;
              }
           }

         if(common_prior_time && expected_index >= 0)
           {
            const double xti_close = xti_rates[xti_index].close;
            const double xng_close = xng_rates[xng_index].close;
            const double xau_close = xau_rates[xau_index].close;
            const double xag_close = xag_rates[xag_index].close;
            const double xti_prior = xti_rates[xti_index + 1].close;
            const double xng_prior = xng_rates[xng_index + 1].close;
            const double xau_prior = xau_rates[xau_index + 1].close;
            const double xag_prior = xag_rates[xag_index + 1].close;
            if(xti_close <= 0.0 || xng_close <= 0.0 || xau_close <= 0.0 ||
               xag_close <= 0.0 || xti_prior <= 0.0 || xng_prior <= 0.0 ||
               xau_prior <= 0.0 || xag_prior <= 0.0)
               return false;

            const double xti_return = xti_close / xti_prior - 1.0;
            const double xng_return = xng_close / xng_prior - 1.0;
            const double xau_return = xau_close / xau_prior - 1.0;
            const double xag_return = xag_close / xag_prior - 1.0;
            if(!MathIsValidNumber(xti_return) || !MathIsValidNumber(xng_return) ||
               !MathIsValidNumber(xau_return) || !MathIsValidNumber(xag_return) ||
               observation_count >= strategy_history_bars)
               return false;

            xti_returns[observation_count] = xti_return;
            xng_returns[observation_count] = xng_return;
            factor_returns[observation_count] =
               0.25 * (xti_return + xng_return + xau_return + xag_return);
            if(!MathIsValidNumber(factor_returns[observation_count]))
               return false;
            ++observation_count;
            ++month_observations[expected_index];
           }

         ++xti_index;
         ++xng_index;
         ++xau_index;
         ++xag_index;
         continue;
        }

      if(xti_time == latest_time)
         ++xti_index;
      if(xng_time == latest_time)
         ++xng_index;
      if(xau_time == latest_time)
         ++xau_index;
      if(xag_time == latest_time)
         ++xag_index;
     }

   for(int month_index = 0; month_index < strategy_lookback_months; ++month_index)
      if(month_observations[month_index] <= 0)
         return false;
   if(observation_count < strategy_min_return_observations)
      return false;
   g_cache_observations = observation_count;

   if(!Strategy_IdiosyncraticExceedance(xti_returns,
                                        factor_returns,
                                        observation_count,
                                        g_cache_xti_ie))
      return false;
   if(!Strategy_IdiosyncraticExceedance(xng_returns,
                                        factor_returns,
                                        observation_count,
                                        g_cache_xng_ie))
      return false;

   g_cache_ie_difference = g_cache_xti_ie - g_cache_xng_ie;
   if(!MathIsValidNumber(g_cache_ie_difference))
      return false;
   if(g_cache_ie_difference < -1.0e-12)
      pair_direction = 1;  // Lower XTI IE: long XTI, short XNG.
   else if(g_cache_ie_difference > 1.0e-12)
      pair_direction = -1; // Lower XNG IE: short XTI, long XNG.
   return true;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   const datetime decision_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached timestamp on the D1 new-bar path.
   const datetime prior_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: exact first-tradable-bar monthly transition check.
   const int current_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   const int prior_month_key = Strategy_MonthKeyForTime(prior_bar_time);
   if(current_month_key <= 0 || prior_month_key <= 0 || current_month_key == prior_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(decision_bar_time,
                                                   g_cache_pair_direction);
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   const long hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
  }

double Strategy_CurrentEntryPrice(const string symbol,
                                  const QM_OrderType type)
  {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return 0.0;
   const double entry = QM_OrderTypeIsBuy(type) ? tick.ask : tick.bid;
   if(entry <= 0.0 || !MathIsValidNumber(entry))
      return 0.0;
   return entry;
  }

double Strategy_RiskWeightForEqualNotional(const string symbol,
                                           const QM_OrderType type)
  {
   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return 0.0;
   const double weight = strategy_atr_sl_mult * atr / entry;
   if(weight <= 0.0 || !MathIsValidNumber(weight))
      return 0.0;
   return weight;
  }

double Strategy_LotsForLeg(const string symbol,
                           const double risk_weight,
                           const double risk_weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * risk_weight / risk_weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

double Strategy_NotionalExposure(const string symbol,
                                 const QM_OrderType type,
                                 const double lots)
  {
   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(entry <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 || lots <= 0.0)
      return 0.0;
   const double one_price_unit_value = tick_value / tick_size;
   const double exposure = lots * entry * one_price_unit_value;
   if(exposure <= 0.0 || !MathIsValidNumber(exposure))
      return 0.0;
   return exposure;
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double lots,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || !Strategy_SpreadAllowed(symbol) || lots <= 0.0)
      return false;

   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry - stop_dist, digits)
                                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_13141_LONG_XTI_SHORT_XNG_IE"
                                            : "QM5_13141_SHORT_XTI_LONG_XNG_IE";

   const double xti_risk_weight = Strategy_RiskWeightForEqualNotional(g_leg_xti,
                                                                        xti_type);
   const double xng_risk_weight = Strategy_RiskWeightForEqualNotional(g_leg_xng,
                                                                        xng_type);
   const double risk_weight_sum = xti_risk_weight + xng_risk_weight;
   if(xti_risk_weight <= 0.0 || xng_risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return false;

   const double xti_lots = Strategy_LotsForLeg(g_leg_xti,
                                                xti_risk_weight,
                                                risk_weight_sum);
   const double xng_lots = Strategy_LotsForLeg(g_leg_xng,
                                                xng_risk_weight,
                                                risk_weight_sum);
   if(xti_lots <= 0.0 || xng_lots <= 0.0)
      return false;

   const double xti_notional = Strategy_NotionalExposure(g_leg_xti,
                                                          xti_type,
                                                          xti_lots);
   const double xng_notional = Strategy_NotionalExposure(g_leg_xng,
                                                          xng_type,
                                                          xng_lots);
   const double max_notional = MathMax(xti_notional, xng_notional);
   if(xti_notional <= 0.0 || xng_notional <= 0.0 || max_notional <= 0.0)
      return false;
   g_cache_notional_mismatch_pct =
      100.0 * MathAbs(xti_notional - xng_notional) / max_notional;
   if(!MathIsValidNumber(g_cache_notional_mismatch_pct) ||
      g_cache_notional_mismatch_pct > strategy_max_notional_mismatch_pct)
      return false;

   if(!Strategy_OpenLeg(g_leg_xti, xti_type, xti_lots, reason))
      return false;
   if(Strategy_OpenLeg(g_leg_xng, xng_type, xng_lots, reason))
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_lookback_months != 6)
      return true;
   if(strategy_history_bars < 180 || strategy_history_bars > 500)
      return true;
   if(strategy_min_return_observations < 60 ||
      strategy_min_return_observations >= strategy_history_bars)
      return true;
   if(MathAbs(strategy_tail_threshold_sigma - 0.5) > 1.0e-12)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_days <= 0)
      return true;
   if(strategy_max_notional_mismatch_pct <= 0.0 ||
      strategy_max_notional_mismatch_pct > 100.0)
      return true;
   if(strategy_xti_max_spread_pts < 0 || strategy_xng_max_spread_pts < 0 ||
      strategy_deviation_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13141_XTI_XNG_IE_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0)
      return false;
   if(Strategy_MonthAlreadyEntered(g_cache_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;

   if(Strategy_OpenPair(g_cache_pair_direction))
      g_last_entry_month_key = g_cache_month_key;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return;
   if(open_legs != 2 || !Strategy_PairCompositionValid())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(g_monthly_rebalance_bar)
     {
      datetime entry_time = g_pair_entry_time;
      if(entry_time <= 0)
         entry_time = Strategy_CurrentPairEntryTime();
      if(Strategy_MonthKeyForTime(entry_time) != g_cache_month_key)
        {
         Strategy_ClosePair(QM_EXIT_STRATEGY);
         return;
        }
     }

   if(Strategy_MaxHoldExceeded())
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xti, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xng, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xng, broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

int OnInit()
  {
   SymbolSelect(g_leg_xti, true);
   SymbolSelect(g_leg_xng, true);
   SymbolSelect(g_factor_xau, true);
   SymbolSelect(g_factor_xag, true);

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

   string basket_symbols[4] = {g_leg_xti, g_leg_xng, g_factor_xau, g_factor_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(320, strategy_history_bars + strategy_atr_period_d1 + 30));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13141\",\"ea\":\"energy-ie-rank\"}");
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
      Strategy_ClosePair(QM_EXIT_STRATEGY);
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
