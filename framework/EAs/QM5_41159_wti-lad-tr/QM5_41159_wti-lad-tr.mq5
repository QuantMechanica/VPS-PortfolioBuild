#property strict
#property version   "5.0"
#property description "QM5_41159 WTI Thirteen-Month LAD Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41159 - WTI Thirteen-Month Least-Absolute-Deviation Trend
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - reconstruct thirteen consecutive completed broker-month-end closes
//   - take logarithms and enumerate all 78 pairwise slope breakpoints
//   - profile a median intercept and absolute-loss objective for each slope
//   - take the median of all slopes tied at the minimum objective
//   - follow the strict least-absolute-deviation slope sign for one month
//   - consume before fallible gates; never enter late or retry
// The exact exhaustive estimator is a transparent QM mechanization. Runtime uses
// MT5-native XTIUSD.DWX price, calendar, ATR, and execution state only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41159;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_price_points        = 13;
input int    strategy_history_bars_d1      = 800;
input int    strategy_entry_grace_minutes  = 180;
input int    strategy_endpoint_stale_days  = 10;
input double strategy_loss_tie_tolerance   = 1.0e-12;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_days        = 40;
input int    strategy_max_spread_points    = 1500;

const string g_symbol = "XTIUSD.DWX";

int      g_last_attempt_month_key = 0;
string   g_attempt_state_key       = "";
bool     g_decision_bar            = false;
bool     g_late_decision           = false;
int      g_decision_month_key      = 0;
datetime g_decision_bar_time       = 0;
int      g_decision_label_offset   = 0;
int      g_current_month_bar_count = 0;
bool     g_signal_valid            = false;
int      g_signal_direction        = 0;
int      g_endpoint_count          = 0;
int      g_candidate_slope_count   = 0;
int      g_objective_count         = 0;
int      g_minimizer_count         = 0;
datetime g_oldest_endpoint_time    = 0;
datetime g_newest_endpoint_time    = 0;
double   g_lad_intercept           = 0.0;
double   g_minimum_loss            = 0.0;
double   g_lad_slope               = 0.0;
int      g_validation_month_key    = 0;
bool     g_validation_signal_valid = false;
int      g_validation_direction    = 0;
string   g_signal_state            = "idle";

// -----------------------------------------------------------------------------
// Structural helpers.
// -----------------------------------------------------------------------------

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_symbol && _Period == PERIOD_D1);
  }

int Strategy_DateKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_MonthKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_NextMonthKey(const int month_key)
  {
   int year = month_key / 100;
   int month = month_key % 100;
   if(year < 1900 || month < 1 || month > 12)
      return 0;
   ++month;
   if(month > 12)
     {
      month = 1;
      ++year;
     }
   return year * 100 + month;
  }

int Strategy_LabelOffsetSeconds(const datetime current_bar_time,
                                const datetime broker_now)
  {
   if(current_bar_time <= 0 || broker_now < current_bar_time)
      return -1;
   const int raw_date = Strategy_DateKeyForTime(current_bar_time);
   const int broker_date = Strategy_DateKeyForTime(broker_now);
   if(raw_date <= 0 || broker_date <= 0)
      return -1;
   if(raw_date == broker_date)
      return 0;
   if(Strategy_DateKeyForTime(current_bar_time + (datetime)86400) ==
      broker_date)
      return 86400;
   return -1;
  }

datetime Strategy_NormalizedLabel(const datetime raw_label,
                                  const int label_offset)
  {
   if(raw_label <= 0 || (label_offset != 0 && label_offset != 86400))
      return 0;
   return raw_label + (datetime)label_offset;
  }

bool Strategy_EntryWithinGrace(const datetime current_bar_time,
                               const datetime broker_now)
  {
   if(current_bar_time <= 0 || broker_now < current_bar_time)
      return false;
   const long elapsed = (long)(broker_now - current_bar_time);
   return (elapsed <=
           (long)strategy_entry_grace_minutes * 60L);
  }

bool Strategy_IsOwnedPosition()
  {
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_FrameworkMagic());
  }

int Strategy_OwnedPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
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
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_symbol)
         return false;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double take_profit = PositionGetDouble(POSITION_TP);
      if(take_profit != 0.0 || !MathIsValidNumber(take_profit))
         return false;
      if((type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL) ||
         opened <= 0 || opened > TimeCurrent() ||
         volume <= 0.0 || !MathIsValidNumber(volume) ||
         open_price <= 0.0 || !MathIsValidNumber(open_price) ||
         stop_price <= 0.0 || !MathIsValidNumber(stop_price))
         return false;
      if(type == POSITION_TYPE_BUY && stop_price >= open_price)
         return false;
      if(type == POSITION_TYPE_SELL && stop_price <= open_price)
         return false;
      return true;
     }
   return false;
  }

datetime Strategy_CurrentEntryTime()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      return (datetime)PositionGetInteger(POSITION_TIME);
     }
   return 0;
  }

void Strategy_CloseOwnedPositions(const QM_ExitReason reason)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_SpreadAllowed()
  {
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points >= 0 &&
           spread_points <= strategy_max_spread_points);
  }

bool Strategy_MonthAlreadyEntered(const int month_key)
  {
   if(month_key <= 0)
      return true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKeyForTime(opened) == month_key)
         return true;
     }

   const datetime now = TimeCurrent();
   const datetime history_start = now - (long)100 * 86400;
   if(history_start <= 0 || !HistorySelect(history_start, now))
      return true;
   const int magic = QM_FrameworkMagic();
   const int deal_count = HistoryDealsTotal();
   for(int index = deal_count - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_MonthKeyForTime(deal_time) == month_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_month_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int current_month_key =
      Strategy_MonthKeyForTime(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_month_key = (int)MathRound(stored);
   if(current_month_key > 0 && MathIsValidNumber(stored) &&
      stored_month_key >= 190001 &&
      stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }
   // Tester globals can outlive a later historical run.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;
   // Stay fail-closed in-process even if terminal persistence fails.
   g_last_attempt_month_key = month_key;
   return (GlobalVariableSet(g_attempt_state_key,
                             (double)month_key) > 0);
  }

bool Strategy_BarCloseValid(const MqlRates &bar)
  {
   return (bar.time > 0 &&
           bar.close > 0.0 &&
           MathIsValidNumber(bar.close));
  }

void Strategy_ResetDecisionState()
  {
   g_decision_bar = false;
   g_late_decision = false;
   g_decision_month_key = 0;
   g_decision_bar_time = 0;
   g_decision_label_offset = 0;
   g_current_month_bar_count = 0;
   g_signal_valid = false;
   g_signal_direction = 0;
   g_endpoint_count = 0;
   g_candidate_slope_count = 0;
   g_objective_count = 0;
   g_minimizer_count = 0;
   g_oldest_endpoint_time = 0;
   g_newest_endpoint_time = 0;
   g_lad_intercept = 0.0;
   g_minimum_loss = 0.0;
   g_lad_slope = 0.0;
   g_signal_state = "idle";
  }

void Strategy_DetectDecisionClock_OnNewBar()
  {
   Strategy_ResetDecisionState();
   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar) ||
      current_bar.time <= 0)
      return;

   const datetime broker_now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(current_bar.time, broker_now);
   if(label_offset < 0)
      return;
   const datetime normalized_current =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   const int current_month_key =
      Strategy_MonthKeyForTime(normalized_current);
   if(current_month_key <= 0 ||
      current_month_key != Strategy_MonthKeyForTime(broker_now) ||
      Strategy_DateKeyForTime(normalized_current) !=
         Strategy_DateKeyForTime(broker_now))
      return;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded month-clock scan behind the sole QM_IsNewBar branch.
                PERIOD_D1,
                1,
                strategy_history_bars_d1,
                bars);
   if(copied <= 0)
      return;

   int current_month_count = 0;
   while(current_month_count < copied &&
         Strategy_MonthKeyForTime(
            Strategy_NormalizedLabel(bars[current_month_count].time,
                                     label_offset)) == current_month_key)
      ++current_month_count;
   if(current_month_count >= copied)
      return;

   const int prior_month_key =
      Strategy_MonthKeyForTime(
         Strategy_NormalizedLabel(bars[current_month_count].time,
                                  label_offset));
   if(prior_month_key <= 0 ||
      Strategy_NextMonthKey(prior_month_key) != current_month_key)
      return;

   g_decision_bar = true;
   g_decision_month_key = current_month_key;
   g_decision_bar_time = current_bar.time;
   g_decision_label_offset = label_offset;
   g_current_month_bar_count = current_month_count;
   g_late_decision =
      (current_month_count > 0 ||
       !Strategy_EntryWithinGrace(current_bar.time, broker_now));
  }

bool Strategy_LoadMonthlyEndpoints(const int current_month_key,
                                          const int label_offset,
                                          double &closes[],
                                          datetime &endpoint_times[])
  {
   ArrayResize(closes, 0);
   ArrayResize(endpoint_times, 0);
   if(current_month_key <= 0 ||
      strategy_price_points != 13 ||
      strategy_history_bars_d1 != 800 ||
      strategy_endpoint_stale_days != 10 ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: one bounded thirteen-month scan behind a consumed monthly attempt or monthly restart validation.
                PERIOD_D1,
                1,
                strategy_history_bars_d1,
                bars);
   if(copied <= 0)
      return false;

   double reverse_closes[];
   datetime reverse_times[];
   int reverse_month_keys[];
   if(ArrayResize(reverse_closes, strategy_price_points) !=
         strategy_price_points ||
      ArrayResize(reverse_times, strategy_price_points) !=
         strategy_price_points ||
      ArrayResize(reverse_month_keys, strategy_price_points) !=
         strategy_price_points)
      return false;

   int endpoint_count = 0;
   int last_month_key = 0;
   bool completed_history_started = false;
   for(int index = 0;
       index < copied && endpoint_count < strategy_price_points;
       ++index)
     {
      if(index > 0 && bars[index - 1].time <= bars[index].time)
         return false;
      if(!Strategy_BarCloseValid(bars[index]))
         return false;

      const datetime normalized_label =
         Strategy_NormalizedLabel(bars[index].time, label_offset);
      const int month_key =
         Strategy_MonthKeyForTime(normalized_label);
      if(normalized_label <= 0 || month_key <= 0)
         return false;

      if(month_key == current_month_key)
        {
         if(completed_history_started)
            return false;
         continue;
        }
      completed_history_started = true;

      if(endpoint_count <= 0 || month_key != last_month_key)
        {
         if(endpoint_count == 0)
           {
            if(Strategy_NextMonthKey(month_key) != current_month_key)
               return false;
           }
         else if(Strategy_NextMonthKey(month_key) != last_month_key)
            return false;

         reverse_closes[endpoint_count] = bars[index].close;
         reverse_times[endpoint_count] = normalized_label;
         reverse_month_keys[endpoint_count] = month_key;
         last_month_key = month_key;
         ++endpoint_count;
        }
     }

   if(endpoint_count != strategy_price_points ||
      endpoint_count != 13)
      return false;

   const datetime broker_now = TimeCurrent();
   const long newest_age =
      (long)(broker_now - reverse_times[0]);
   if(broker_now <= 0 || reverse_times[0] <= 0 ||
      newest_age < 0 ||
      newest_age > (long)strategy_endpoint_stale_days * 86400L)
      return false;

   if(ArrayResize(closes, endpoint_count) != endpoint_count ||
      ArrayResize(endpoint_times, endpoint_count) != endpoint_count)
      return false;

   int chronological_month_keys[];
   if(ArrayResize(chronological_month_keys, endpoint_count) !=
      endpoint_count)
      return false;
   for(int index = 0; index < endpoint_count; ++index)
     {
      const int reverse_index = endpoint_count - 1 - index;
      closes[index] = reverse_closes[reverse_index];
      endpoint_times[index] = reverse_times[reverse_index];
      chronological_month_keys[index] =
         reverse_month_keys[reverse_index];
      if(closes[index] <= 0.0 ||
         !MathIsValidNumber(closes[index]) ||
         endpoint_times[index] <= 0 ||
         (index > 0 &&
          endpoint_times[index] <= endpoint_times[index - 1]))
         return false;
      if(index > 0 &&
         Strategy_NextMonthKey(chronological_month_keys[index - 1]) !=
            chronological_month_keys[index])
         return false;
     }

   if(Strategy_NextMonthKey(
         chronological_month_keys[endpoint_count - 1]) !=
      current_month_key)
      return false;
   return true;
  }

bool Strategy_LadSignal(const double &closes[],
                        int &direction,
                        int &endpoint_count,
                        int &candidate_slope_count,
                        int &objective_count,
                        int &minimizer_count,
                        double &lad_intercept,
                        double &minimum_loss,
                        double &lad_slope)
  {
   direction = 0;
   endpoint_count = ArraySize(closes);
   candidate_slope_count = 0;
   objective_count = 0;
   minimizer_count = 0;
   lad_intercept = 0.0;
   minimum_loss = 0.0;
   lad_slope = 0.0;

   const int point_count = strategy_price_points;
   const int expected_candidates =
      point_count * (point_count - 1) / 2;
   if(point_count != 13 || endpoint_count != point_count ||
      expected_candidates != 78 ||
      strategy_loss_tie_tolerance != 1.0e-12)
      return false;

   double log_prices[];
   if(ArrayResize(log_prices, point_count) != point_count)
      return false;
   for(int index = 0; index < point_count; ++index)
     {
      if(closes[index] <= 0.0 ||
         !MathIsValidNumber(closes[index]))
         return false;
      log_prices[index] = MathLog(closes[index]);
      if(!MathIsValidNumber(log_prices[index]))
         return false;
     }

   double candidate_slopes[];
   double candidate_losses[];
   if(ArrayResize(candidate_slopes, expected_candidates) !=
         expected_candidates ||
      ArrayResize(candidate_losses, expected_candidates) !=
         expected_candidates)
      return false;

   // Lexicographic (older index, newer index) enumeration is card-locked.
   for(int older = 0; older < point_count - 1; ++older)
     {
      for(int newer = older + 1; newer < point_count; ++newer)
        {
         const int month_distance = newer - older;
         if(month_distance <= 0 ||
            candidate_slope_count < 0 ||
            candidate_slope_count >= expected_candidates)
            return false;
         const double slope =
            (log_prices[newer] - log_prices[older]) /
            (double)month_distance;
         if(!MathIsValidNumber(slope))
            return false;
         candidate_slopes[candidate_slope_count] = slope;
         ++candidate_slope_count;
        }
     }
   if(candidate_slope_count != expected_candidates)
      return false;

   // For fixed slope b, the LAD intercept is the median residual. Evaluate
   // every residual-order breakpoint instead of using an iterative solver.
   for(int candidate = 0;
       candidate < candidate_slope_count;
       ++candidate)
     {
      const double slope = candidate_slopes[candidate];
      double residuals[];
      if(ArrayResize(residuals, point_count) != point_count)
         return false;
      for(int index = 0; index < point_count; ++index)
        {
         residuals[index] =
            log_prices[index] - slope * (double)index;
         if(!MathIsValidNumber(residuals[index]))
            return false;
        }
      ArraySort(residuals);
      for(int index = 0; index < point_count; ++index)
        {
         if(!MathIsValidNumber(residuals[index]) ||
            (index > 0 && residuals[index] < residuals[index - 1]))
            return false;
        }

      const int intercept_index = point_count / 2;
      if(intercept_index != 6)
         return false;
      const double intercept = residuals[intercept_index];
      if(!MathIsValidNumber(intercept))
         return false;

      double loss = 0.0;
      for(int index = 0; index < point_count; ++index)
        {
         const double error =
            log_prices[index] - intercept - slope * (double)index;
         const double term = MathAbs(error);
         if(!MathIsValidNumber(error) ||
            !MathIsValidNumber(term) || term < 0.0)
            return false;
         loss += term;
         if(!MathIsValidNumber(loss) || loss < 0.0)
            return false;
        }

      candidate_losses[candidate] = loss;
      if(objective_count == 0 || loss < minimum_loss)
         minimum_loss = loss;
      ++objective_count;
     }
   if(objective_count != expected_candidates ||
      !MathIsValidNumber(minimum_loss) || minimum_loss < 0.0)
      return false;

   double minimizers[];
   if(ArrayResize(minimizers, expected_candidates) != expected_candidates)
      return false;
   for(int candidate = 0;
       candidate < candidate_slope_count;
       ++candidate)
     {
      if(MathAbs(candidate_losses[candidate] - minimum_loss) <=
         strategy_loss_tie_tolerance)
        {
         if(minimizer_count < 0 ||
            minimizer_count >= expected_candidates)
            return false;
         minimizers[minimizer_count] = candidate_slopes[candidate];
         ++minimizer_count;
        }
     }
   if(minimizer_count <= 0 ||
      ArrayResize(minimizers, minimizer_count) != minimizer_count)
      return false;
   ArraySort(minimizers);
   for(int index = 0; index < minimizer_count; ++index)
     {
      if(!MathIsValidNumber(minimizers[index]) ||
         (index > 0 && minimizers[index] < minimizers[index - 1]))
         return false;
     }

   const int center = minimizer_count / 2;
   if((minimizer_count % 2) == 1)
      lad_slope = minimizers[center];
   else
     {
      if(center <= 0 || center >= minimizer_count)
         return false;
      lad_slope =
         minimizers[center - 1] / 2.0 + minimizers[center] / 2.0;
     }
   if(!MathIsValidNumber(lad_slope))
      return false;

   // Profile the reporting intercept at the final median minimizer and prove
   // the resulting point remains on the locked minimum-loss face.
   double final_residuals[];
   if(ArrayResize(final_residuals, point_count) != point_count)
      return false;
   for(int index = 0; index < point_count; ++index)
     {
      final_residuals[index] =
         log_prices[index] - lad_slope * (double)index;
      if(!MathIsValidNumber(final_residuals[index]))
         return false;
     }
   ArraySort(final_residuals);
   lad_intercept = final_residuals[6];
   if(!MathIsValidNumber(lad_intercept))
      return false;

   double final_loss = 0.0;
   for(int index = 0; index < point_count; ++index)
     {
      const double term =
         MathAbs(log_prices[index] - lad_intercept -
                 lad_slope * (double)index);
      if(!MathIsValidNumber(term) || term < 0.0)
         return false;
      final_loss += term;
      if(!MathIsValidNumber(final_loss) || final_loss < 0.0)
         return false;
     }
   if(MathAbs(final_loss - minimum_loss) >
      strategy_loss_tie_tolerance)
      return false;

   if(lad_slope > 0.0)
      direction = 1;
   else if(lad_slope < 0.0)
      direction = -1;
   return true;
  }

bool Strategy_ExpectedDirectionForMonth(const int current_month_key,
                                        const int label_offset,
                                        int &direction)
  {
   direction = 0;
   if(current_month_key <= 0)
      return false;
   if(g_decision_month_key == current_month_key &&
      g_signal_valid && g_signal_direction != 0)
     {
      direction = g_signal_direction;
      return true;
     }
   if(g_validation_month_key == current_month_key)
     {
      direction = g_validation_direction;
      return (g_validation_signal_valid && direction != 0);
     }

   double closes[];
   datetime endpoint_times[];
   int endpoint_count = 0;
   int candidate_slope_count = 0;
   int objective_count = 0;
   int minimizer_count = 0;
   double lad_intercept = 0.0;
   double minimum_loss = 0.0;
   double lad_slope = 0.0;
   int calculated_direction = 0;
   const bool valid =
      Strategy_LoadMonthlyEndpoints(current_month_key,
                                    label_offset,
                                    closes,
                                    endpoint_times) &&
      Strategy_LadSignal(closes,
                         calculated_direction,
                         endpoint_count,
                         candidate_slope_count,
                         objective_count,
                         minimizer_count,
                         lad_intercept,
                         minimum_loss,
                         lad_slope);

   g_validation_month_key = current_month_key;
   g_validation_signal_valid = valid;
   g_validation_direction = calculated_direction;
   direction = calculated_direction;
   return (valid && direction != 0);
  }

bool Strategy_OwnedPositionDirectionMatches(const int direction)
  {
   if(direction == 0)
      return false;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return ((direction > 0 && type == POSITION_TYPE_BUY) ||
              (direction < 0 && type == POSITION_TYPE_SELL));
     }
   return false;
  }

void Strategy_PrepareDecisionSignal()
  {
   if(!g_decision_bar || g_decision_month_key <= 0 ||
      g_decision_bar_time <= 0)
      return;
   if(g_decision_month_key == g_last_attempt_month_key)
     {
      g_signal_state = "month_already_consumed";
      return;
     }

   // Consume before history, arithmetic, news, spread, quote, ATR, sizing,
   // margin, or order gates. The broker-month clock is the sole prerequisite.
   if(!Strategy_RecordMonthAttempt(g_decision_month_key))
     {
      g_signal_state = "attempt_persist_failed";
      return;
     }

   if(Strategy_MonthAlreadyEntered(g_decision_month_key))
      g_signal_state = "entry_deal_already_exists";
   else if(g_late_decision)
      g_signal_state = "late_restart_consumed_flat";
   else
     {
      double closes[];
      datetime endpoint_times[];
      const bool endpoints_valid =
         Strategy_LoadMonthlyEndpoints(g_decision_month_key,
                                       g_decision_label_offset,
                                       closes,
                                       endpoint_times);
      if(endpoints_valid)
        {
         g_endpoint_count = ArraySize(closes);
         if(ArraySize(endpoint_times) == g_endpoint_count &&
            g_endpoint_count == strategy_price_points)
           {
            g_oldest_endpoint_time = endpoint_times[0];
            g_newest_endpoint_time =
               endpoint_times[g_endpoint_count - 1];
           }
        }

      g_signal_valid =
         endpoints_valid &&
         Strategy_LadSignal(closes,
                            g_signal_direction,
                            g_endpoint_count,
                            g_candidate_slope_count,
                            g_objective_count,
                            g_minimizer_count,
                            g_lad_intercept,
                            g_minimum_loss,
                            g_lad_slope);
      if(!g_signal_valid)
         g_signal_state = "lad_validation_failed";
      else if(g_lad_slope == 0.0)
         g_signal_state = "zero_lad_slope_flat";
      else if(g_signal_direction > 0)
         g_signal_state = "lad_wti_long";
      else if(g_signal_direction < 0)
         g_signal_state = "lad_wti_short";
      else
         g_signal_state = "invalid_direction_flat";

      g_validation_month_key = g_decision_month_key;
      g_validation_signal_valid = g_signal_valid;
      g_validation_direction = g_signal_direction;
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_month_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"endpoint_count\":%d,\"candidate_slope_count\":%d,\"objective_count\":%d,\"minimizer_count\":%d,\"oldest_endpoint\":%I64d,\"newest_endpoint\":%I64d,\"lad_intercept\":%.12e,\"minimum_loss\":%.12e,\"lad_slope\":%.12e,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_current_month_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_direction,
                            g_endpoint_count,
                            g_candidate_slope_count,
                            g_objective_count,
                            g_minimizer_count,
                            (long)g_oldest_endpoint_time,
                            (long)g_newest_endpoint_time,
                            g_lad_intercept,
                            g_minimum_loss,
                            g_lad_slope,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41159 ||
      qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 || RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high")
      return true;
   if(qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21 ||
      MathAbs(qm_stress_reject_probability) > 0.000000000001)
      return true;
   if(strategy_price_points != 13 ||
      strategy_history_bars_d1 != 800 ||
      strategy_entry_grace_minutes != 180 ||
      strategy_endpoint_stale_days != 10 ||
      strategy_loss_tie_tolerance != 1.0e-12 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 0.000000000001 ||
      strategy_max_hold_days != 40 ||
      strategy_max_spread_points != 1500)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry.
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_41159_WTI_LAD_TREND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_decision_bar || g_late_decision ||
      g_decision_month_key <= 0 ||
      g_decision_month_key != g_last_attempt_month_key ||
      !g_signal_valid || g_signal_direction == 0)
      return false;
   if(Strategy_OwnedPositionCount() > 0 ||
      !Strategy_SpreadAllowed())
      return false;

   const double atr_value =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type = (g_signal_direction > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_signal_direction > 0)
      ? "WTI_LAD_TREND_LONG"
      : "WTI_LAD_TREND_SHORT";
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_value,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if((req.type == QM_BUY && req.sl >= entry_price) ||
      (req.type == QM_SELL && req.sl <= entry_price))
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management.
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   const int owned_count = Strategy_OwnedPositionCount();
   if(owned_count <= 0)
      return;
   if(owned_count != 1 || !Strategy_OwnedPositionStateValid())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar) ||
      current_bar.time <= 0)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   const datetime now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(current_bar.time, now);
   const datetime normalized_current =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   const datetime opened = Strategy_CurrentEntryTime();
   const int current_month_key =
      Strategy_MonthKeyForTime(normalized_current);
   const int opened_month_key = Strategy_MonthKeyForTime(opened);
   if(label_offset < 0 || current_month_key <= 0 ||
      opened_month_key <= 0 || opened <= 0 || opened > now)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   if(opened_month_key != current_month_key)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   int expected_direction = 0;
   if(!Strategy_ExpectedDirectionForMonth(current_month_key,
                                          label_offset,
                                          expected_direction) ||
      !Strategy_OwnedPositionDirectionMatches(expected_direction))
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
   if((long)(now - opened) >= hold_seconds)
      Strategy_CloseOwnedPositions(QM_EXIT_TIME_STOP);
  }

// -----------------------------------------------------------------------------
// Trade Close and news hooks.
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// Framework wiring.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!SymbolSelect(g_symbol, true) ||
      !Strategy_IsHostChart() || qm_ea_id != 41159 ||
      qm_magic_slot_offset != 0)
      return INIT_PARAMETERS_INCORRECT;

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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_DISABLED,
         "Approved WTI least-absolute-deviation trend position holds through Fridays until the next broker month"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41159_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41159\",\"ea\":\"wti-lad-tr\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO,
               "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
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
   g_decision_bar = false;
   if(new_bar)
      Strategy_DetectDecisionClock_OnNewBar();

   // Lifecycle repair and next-month closure precede entry-only gates and
   // run every tick, so a failed close is retried until flat.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(!new_bar)
      return;
   if(g_decision_bar)
      Strategy_PrepareDecisionSignal();

   // Attempt persistence happens before this entry-only news check. Both
   // axes are card-locked OFF.
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
