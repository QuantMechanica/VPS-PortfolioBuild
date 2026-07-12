#property strict
#property version   "5.0"
#property description "QM5_13205 XAU XAG state-dependent quantile envelope"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13205 - XAU/XAG state-dependent conditional-quantile envelope
//
// The load-bearing signal is NOT an OLS residual or fixed-ratio z-score.
// Each monthly model fits tau=10/50/90 percent simple quantile regressions by
// minimizing Koenker-Bassett asymmetric check loss over the exact constrained
// pairwise-slope breakpoints. Weekly observations beyond the frozen monthly
// tail lines open a beta-target-notional XAU/XAG package; the median, a time
// stop, hard ATR stops, or composition failure closes it.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13205;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_formation_bars          = 504;
input int    strategy_history_bars            = 700;
input double strategy_beta_min                = 0.25;
input double strategy_beta_max                = 3.00;
input double strategy_slope_unique_epsilon    = 1.0e-10;
input double strategy_min_beta_span           = 0.05;
input double strategy_min_band_width          = 0.010;
input double strategy_entry_band_mult         = 0.00;
input int    strategy_max_endpoint_gap_days   = 10;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 4.0;
input int    strategy_max_hold_days           = 70;
input int    strategy_xau_max_spread_pts      = 1500;
input int    strategy_xag_max_spread_pts      = 500;
input double strategy_max_hedge_error_pct     = 20.0;
input int    strategy_deviation_points        = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_monthly_refit_bar = false;
bool     g_weekly_signal_bar = false;
bool     g_model_ready = false;
bool     g_signal_ready = false;
int      g_model_month_key = 0;
int      g_signal_week_key = 0;
int      g_last_entry_week_key = 0;
datetime g_pair_entry_time = 0;
string   g_attempt_state_key = "";

double g_alpha_10 = 0.0;
double g_beta_10 = 0.0;
double g_alpha_50 = 0.0;
double g_beta_50 = 0.0;
double g_alpha_90 = 0.0;
double g_beta_90 = 0.0;
double g_model_x_min = 0.0;
double g_model_x_max = 0.0;

double g_signal_x = 0.0;
double g_signal_y = 0.0;
double g_signal_q10 = 0.0;
double g_signal_q50 = 0.0;
double g_signal_q90 = 0.0;
double g_signal_band_width = 0.0;
double g_signal_entry_beta = 0.0;
int    g_signal_pair_direction = 0; // +1 long residual, -1 short residual.

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xau)
      return 0;
   if(symbol == g_leg_xag)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xau && _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double spread_points = (ask - bid) / point;
   if(symbol == g_leg_xau)
      return (spread_points <= (double)strategy_xau_max_spread_pts);
   if(symbol == g_leg_xag)
      return (spread_points <= (double)strategy_xag_max_spread_pts);
   return false;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_MagicChecked(qm_ea_id, slot, symbol));
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
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest <= 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

bool Strategy_PairCompositionValid()
  {
   int xau_count = 0;
   int xag_count = 0;
   ENUM_POSITION_TYPE xau_type = (ENUM_POSITION_TYPE)-1;
   ENUM_POSITION_TYPE xag_type = (ENUM_POSITION_TYPE)-1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(symbol == g_leg_xau)
        {
         ++xau_count;
         xau_type = type;
        }
      else if(symbol == g_leg_xag)
        {
         ++xag_count;
         xag_type = type;
        }
     }
   return (xau_count == 1 && xag_count == 1 && xau_type != xag_type &&
           (xau_type == POSITION_TYPE_BUY || xau_type == POSITION_TYPE_SELL) &&
           (xag_type == POSITION_TYPE_BUY || xag_type == POSITION_TYPE_SELL));
  }

int Strategy_CurrentPairDirection()
  {
   if(!Strategy_PairCompositionValid())
      return 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition() ||
         PositionGetString(POSITION_SYMBOL) != g_leg_xag)
         continue;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return (type == POSITION_TYPE_BUY ? 1 : -1);
     }
   return 0;
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

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_WeekKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   const int days_since_monday = (parts.day_of_week + 6) % 7;
   const datetime monday = value - (datetime)((long)days_since_monday * 86400);
   MqlDateTime monday_parts;
   if(monday <= 0 || !TimeToStruct(monday, monday_parts))
      return 0;
   return monday_parts.year * 1000 + monday_parts.day_of_year;
  }

datetime Strategy_FirstHostBarOfMonth(const datetime reference_time)
  {
   if(reference_time <= 0)
      return 0;
   const int reference_shift = iBarShift(_Symbol, PERIOD_D1,
                                         reference_time, false); // perf-allowed: bounded restart reconstruction.
   if(reference_shift < 0)
      return 0;
   const datetime reference_bar = iTime(_Symbol, PERIOD_D1, // perf-allowed: one bounded calendar anchor.
                                        reference_shift); // perf-allowed: one bounded calendar anchor.
   const int month_key = Strategy_MonthKey(reference_bar);
   if(reference_bar <= 0 || month_key <= 0)
      return 0;

   datetime first_bar = reference_bar;
   for(int shift = reference_shift + 1;
       shift <= reference_shift + 35; ++shift)
     {
      const datetime candidate = iTime(_Symbol, PERIOD_D1, // perf-allowed: at most 35 D1 calendar probes on restart.
                                       shift); // perf-allowed: at most 35 D1 calendar probes on restart.
      if(candidate <= 0)
         return 0;
      if(Strategy_MonthKey(candidate) != month_key)
         break;
      first_bar = candidate;
     }
   return first_bar;
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_%s_QR_ATTEMPT_WEEK", qm_ea_id, g_leg_xau);
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_entry_week_key = 0;
   const int current_week = Strategy_WeekKey(reference_time);
   if(current_week <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int stored_week = (int)GlobalVariableGet(g_attempt_state_key);
   // Tester replays can move calendar time backwards while terminal globals
   // survive. A future marker cannot belong to this run and is removed.
   if(stored_week > 0 && stored_week <= current_week)
      g_last_entry_week_key = stored_week;
   else
      GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int week_key)
  {
   if(week_key <= 0)
      return false;
   if(g_attempt_state_key == "")
      g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_entry_week_key = week_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)week_key) > 0);
  }

bool Strategy_LoadSynchronizedLogPairs(const datetime decision_bar_time,
                                       const int required_pairs,
                                       double &x_values[],
                                       double &y_values[],
                                       datetime &pair_times[])
  {
   if(decision_bar_time <= 0 || required_pairs <= 0)
      return false;
   const int copy_bars = (required_pairs > 1 ? strategy_history_bars : 30);
   if(copy_bars < required_pairs)
      return false;

   MqlRates xau_rates[];
   MqlRates xag_rates[];
   ArraySetAsSeries(xau_rates, true);
   ArraySetAsSeries(xag_rates, true);
   const int xau_decision_shift = iBarShift(g_leg_xau, PERIOD_D1,
                                            decision_bar_time, false); // perf-allowed: one anchor lookup per bounded history copy.
   const int xag_decision_shift = iBarShift(g_leg_xag, PERIOD_D1,
                                            decision_bar_time, false); // perf-allowed: one anchor lookup per bounded history copy.
   if(xau_decision_shift < 0 || xag_decision_shift < 0)
      return false;
   const datetime xau_anchor_time = iTime(g_leg_xau, PERIOD_D1, // perf-allowed: validate strict decision cutoff.
                                          xau_decision_shift); // perf-allowed: validate strict decision cutoff.
   const datetime xag_anchor_time = iTime(g_leg_xag, PERIOD_D1, // perf-allowed: validate strict decision cutoff.
                                          xag_decision_shift); // perf-allowed: validate strict decision cutoff.
   if(xau_anchor_time <= 0 || xag_anchor_time <= 0 ||
      xau_anchor_time > decision_bar_time ||
      xag_anchor_time > decision_bar_time)
      return false;
   const int xau_start_shift = xau_decision_shift +
      (xau_anchor_time == decision_bar_time ? 1 : 0);
   const int xag_start_shift = xag_decision_shift +
      (xag_anchor_time == decision_bar_time ? 1 : 0);
   // Anchor both copies immediately before the requested decision bar. This
   // makes a mid-month reconstruction reproduce the original month window.
   const int xau_count = CopyRates(g_leg_xau, PERIOD_D1, // perf-allowed: bounded monthly/restart/weekly history copy.
                                   xau_start_shift,
                                   copy_bars, xau_rates); // perf-allowed
   const int xag_count = CopyRates(g_leg_xag, PERIOD_D1, // perf-allowed: bounded monthly/restart/weekly history copy.
                                   xag_start_shift,
                                   copy_bars, xag_rates); // perf-allowed
   if(xau_count < required_pairs || xag_count < required_pairs)
      return false;

   if(ArrayResize(x_values, required_pairs) != required_pairs ||
      ArrayResize(y_values, required_pairs) != required_pairs ||
      ArrayResize(pair_times, required_pairs) != required_pairs)
      return false;

   int xau_index = 0;
   int xag_index = 0;
   int common_count = 0;
   while(xau_index < xau_count && xag_index < xag_count &&
         common_count < required_pairs)
     {
      const datetime xau_time = xau_rates[xau_index].time;
      const datetime xag_time = xag_rates[xag_index].time;
      if(xau_time <= 0 || xag_time <= 0)
         return false;
      if(xau_time == xag_time)
        {
         const double xau_close = xau_rates[xau_index].close;
         const double xag_close = xag_rates[xag_index].close;
         if(xau_close <= 0.0 || xag_close <= 0.0 ||
            !MathIsValidNumber(xau_close) || !MathIsValidNumber(xag_close))
            return false;
         if(common_count > 0 && xau_time >= pair_times[common_count - 1])
            return false;
         const double x = MathLog(xau_close);
         const double y = MathLog(xag_close);
         if(!MathIsValidNumber(x) || !MathIsValidNumber(y))
            return false;
         pair_times[common_count] = xau_time;
         x_values[common_count] = x;
         y_values[common_count] = y;
         ++common_count;
         ++xau_index;
         ++xag_index;
         continue;
        }
      // Series arrays are newest-to-oldest; discard the newer unmatched bar.
      if(xau_time > xag_time)
         ++xau_index;
      else
         ++xag_index;
     }

   if(common_count != required_pairs || pair_times[0] >= decision_bar_time)
      return false;
   const long gap = (long)(decision_bar_time - pair_times[0]);
   if(gap < 0 || gap > (long)strategy_max_endpoint_gap_days * 86400)
      return false;
   return true;
  }

double Strategy_EmpiricalQuantile(double &values[], const double tau)
  {
   const int count = ArraySize(values);
   if(count <= 0 || tau <= 0.0 || tau >= 1.0)
      return 0.0;
   ArraySort(values);
   int index = (int)MathCeil(tau * (double)count) - 1;
   if(index < 0)
      index = 0;
   if(index >= count)
      index = count - 1;
   return values[index];
  }

bool Strategy_ProfileCheckLoss(const double &x_values[],
                               const double &y_values[],
                               const double beta,
                               const double tau,
                               double &alpha,
                               double &loss)
  {
   alpha = 0.0;
   loss = 0.0;
   const int count = ArraySize(x_values);
   if(count <= 1 || ArraySize(y_values) != count ||
      !MathIsValidNumber(beta) || tau <= 0.0 || tau >= 1.0)
      return false;
   double residuals[];
   if(ArrayResize(residuals, count) != count)
      return false;
   for(int i = 0; i < count; ++i)
     {
      residuals[i] = y_values[i] - beta * x_values[i];
      if(!MathIsValidNumber(residuals[i]))
         return false;
     }
   alpha = Strategy_EmpiricalQuantile(residuals, tau);
   if(!MathIsValidNumber(alpha))
      return false;
   for(int i = 0; i < count; ++i)
     {
      const double error = y_values[i] - alpha - beta * x_values[i];
      loss += (error >= 0.0 ? tau * error : (tau - 1.0) * error);
     }
   return (MathIsValidNumber(loss) && loss >= 0.0);
  }

bool Strategy_BuildSlopeCandidates(const double &x_values[],
                                   const double &y_values[],
                                   double &candidates[])
  {
   const int count = ArraySize(x_values);
   if(count != strategy_formation_bars || ArraySize(y_values) != count)
      return false;
   const int max_candidates = count * (count - 1) / 2 + 2;
   if(ArrayResize(candidates, max_candidates) != max_candidates)
      return false;
   int used = 0;
   candidates[used++] = strategy_beta_min;
   candidates[used++] = strategy_beta_max;
   for(int i = 0; i < count - 1; ++i)
     {
      for(int j = i + 1; j < count; ++j)
        {
         const double dx = x_values[i] - x_values[j];
         if(MathAbs(dx) <= strategy_slope_unique_epsilon)
            continue;
         const double slope = (y_values[i] - y_values[j]) / dx;
         if(!MathIsValidNumber(slope) || slope < strategy_beta_min ||
            slope > strategy_beta_max)
            continue;
         candidates[used++] = slope;
        }
     }
   if(used < 3 || ArrayResize(candidates, used) != used)
      return false;
   ArraySort(candidates);
   int unique_count = 0;
   for(int i = 0; i < used; ++i)
     {
      if(unique_count == 0 ||
         MathAbs(candidates[i] - candidates[unique_count - 1]) >
         strategy_slope_unique_epsilon)
         candidates[unique_count++] = candidates[i];
     }
   if(unique_count < 3 || ArrayResize(candidates, unique_count) != unique_count)
      return false;
   return true;
  }

bool Strategy_FitQuantile(const double &x_values[],
                          const double &y_values[],
                          const double &candidates[],
                          const double tau,
                          double &alpha,
                          double &beta)
  {
   alpha = 0.0;
   beta = 0.0;
   const int candidate_count = ArraySize(candidates);
   if(candidate_count < 3)
      return false;
   int left = 0;
   int right = candidate_count - 1;
   while(left < right)
     {
      const int middle = left + (right - left) / 2;
      double alpha_left = 0.0;
      double loss_left = 0.0;
      double alpha_right = 0.0;
      double loss_right = 0.0;
      if(!Strategy_ProfileCheckLoss(x_values, y_values,
                                    candidates[middle], tau,
                                    alpha_left, loss_left) ||
         !Strategy_ProfileCheckLoss(x_values, y_values,
                                    candidates[middle + 1], tau,
                                    alpha_right, loss_right))
         return false;
      if(loss_left <= loss_right + 1.0e-14)
         right = middle;
      else
         left = middle + 1;
     }
   double final_loss = 0.0;
   beta = candidates[left];
   if(!Strategy_ProfileCheckLoss(x_values, y_values, beta, tau,
                                 alpha, final_loss))
      return false;
   // Bound hits signal that the constrained optimum is unresolved; fail closed.
   if(beta <= strategy_beta_min + strategy_slope_unique_epsilon ||
      beta >= strategy_beta_max - strategy_slope_unique_epsilon)
      return false;
   return (MathIsValidNumber(alpha) && MathIsValidNumber(beta));
  }

bool Strategy_EnvelopeOrderedAt(const double x_value)
  {
   const double q10 = g_alpha_10 + g_beta_10 * x_value;
   const double q50 = g_alpha_50 + g_beta_50 * x_value;
   const double q90 = g_alpha_90 + g_beta_90 * x_value;
   return (MathIsValidNumber(q10) && MathIsValidNumber(q50) &&
            MathIsValidNumber(q90) && q10 < q50 && q50 < q90);
  }

bool Strategy_UpdateSignalFromModel(const double x_value,
                                    const double y_value,
                                    const int week_key)
  {
   g_signal_ready = false;
   g_signal_pair_direction = 0;
   g_signal_entry_beta = 0.0;
   if(!g_model_ready || week_key <= 0 ||
      !MathIsValidNumber(x_value) || !MathIsValidNumber(y_value) ||
      !Strategy_EnvelopeOrderedAt(x_value))
      return false;

   g_signal_x = x_value;
   g_signal_y = y_value;
   g_signal_q10 = g_alpha_10 + g_beta_10 * x_value;
   g_signal_q50 = g_alpha_50 + g_beta_50 * x_value;
   g_signal_q90 = g_alpha_90 + g_beta_90 * x_value;
   g_signal_band_width = g_signal_q90 - g_signal_q10;
   if(!MathIsValidNumber(g_signal_band_width) ||
      g_signal_band_width < strategy_min_band_width)
      return false;
   g_signal_week_key = week_key;
   const double upper_trigger =
      g_signal_q90 + strategy_entry_band_mult * g_signal_band_width;
   const double lower_trigger =
      g_signal_q10 - strategy_entry_band_mult * g_signal_band_width;
   if(y_value > upper_trigger)
     {
      g_signal_pair_direction = -1; // SELL XAG, BUY XAU.
      g_signal_entry_beta = g_beta_90;
     }
   else if(y_value < lower_trigger)
     {
      g_signal_pair_direction = 1;  // BUY XAG, SELL XAU.
      g_signal_entry_beta = g_beta_10;
     }
   g_signal_ready = true;
   return true;
  }

bool Strategy_RefitMonthlyModel(const datetime decision_bar_time,
                                const int month_key,
                                const int week_key)
  {
   g_model_ready = false;
   g_signal_ready = false;
   const int required_pairs = strategy_formation_bars + 1;
   double all_x[];
   double all_y[];
   datetime all_times[];
   if(!Strategy_LoadSynchronizedLogPairs(decision_bar_time, required_pairs,
                                         all_x, all_y, all_times))
      return false;

   double formation_x[];
   double formation_y[];
   if(ArrayResize(formation_x, strategy_formation_bars) != strategy_formation_bars ||
      ArrayResize(formation_y, strategy_formation_bars) != strategy_formation_bars)
      return false;
   g_model_x_min = all_x[1];
   g_model_x_max = all_x[1];
   for(int i = 0; i < strategy_formation_bars; ++i)
     {
      formation_x[i] = all_x[i + 1];
      formation_y[i] = all_y[i + 1];
      g_model_x_min = MathMin(g_model_x_min, formation_x[i]);
      g_model_x_max = MathMax(g_model_x_max, formation_x[i]);
     }
   if(g_model_x_max - g_model_x_min <= strategy_slope_unique_epsilon)
      return false;

   double candidates[];
   if(!Strategy_BuildSlopeCandidates(formation_x, formation_y, candidates))
      return false;
   if(!Strategy_FitQuantile(formation_x, formation_y, candidates, 0.10,
                            g_alpha_10, g_beta_10) ||
      !Strategy_FitQuantile(formation_x, formation_y, candidates, 0.50,
                            g_alpha_50, g_beta_50) ||
      !Strategy_FitQuantile(formation_x, formation_y, candidates, 0.90,
                            g_alpha_90, g_beta_90))
      return false;
   if(g_beta_90 <= g_beta_10 + strategy_min_beta_span)
      return false;

   g_model_ready = true;
   if(!Strategy_EnvelopeOrderedAt(g_model_x_min) ||
      !Strategy_EnvelopeOrderedAt(g_model_x_max) ||
      !Strategy_EnvelopeOrderedAt(all_x[0]))
     {
      g_model_ready = false;
      return false;
     }
   g_model_month_key = month_key;
   return Strategy_UpdateSignalFromModel(all_x[0], all_y[0], week_key);
  }

bool Strategy_LoadWeeklySignal(const datetime decision_bar_time,
                               const int week_key)
  {
   double latest_x[];
   double latest_y[];
   datetime latest_time[];
   if(!Strategy_LoadSynchronizedLogPairs(decision_bar_time, 1,
                                         latest_x, latest_y, latest_time))
      return false;
   return Strategy_UpdateSignalFromModel(latest_x[0], latest_y[0], week_key);
  }

bool Strategy_RestoreMonthlyModel(const datetime decision_bar_time,
                                  const int month_key,
                                  const int week_key)
  {
   const datetime month_anchor =
      Strategy_FirstHostBarOfMonth(decision_bar_time);
   const int anchor_week = Strategy_WeekKey(month_anchor);
   if(month_anchor <= 0 || Strategy_MonthKey(month_anchor) != month_key ||
      anchor_week <= 0 ||
      !Strategy_RefitMonthlyModel(month_anchor, month_key, anchor_week))
      return false;
   if(month_anchor == decision_bar_time)
      return true;
   return Strategy_LoadWeeklySignal(decision_bar_time, week_key);
  }

void Strategy_AdvanceSignalOnNewBar()
  {
   g_monthly_refit_bar = false;
   g_weekly_signal_bar = false;
   g_signal_ready = false;

   MqlRates decision_rates[1];
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, decision_rates) != 1 || // perf-allowed
      decision_rates[0].time <= 0)
      return;
   const datetime decision_time = decision_rates[0].time;
   const datetime previous_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: one prior D1 timestamp on the new-bar calendar gate.
   if(previous_time <= 0)
      return;

   const int current_month = Strategy_MonthKey(decision_time);
   const int previous_month = Strategy_MonthKey(previous_time);
   const int current_week = Strategy_WeekKey(decision_time);
   const int previous_week = Strategy_WeekKey(previous_time);
   if(current_month <= 0 || previous_month <= 0 ||
      current_week <= 0 || previous_week <= 0)
      return;
   g_monthly_refit_bar = (current_month != previous_month);
   g_weekly_signal_bar = (current_week != previous_week);

   if(g_monthly_refit_bar)
      Strategy_RefitMonthlyModel(decision_time, current_month, current_week);
   else if(!g_model_ready || g_model_month_key != current_month)
      Strategy_RestoreMonthlyModel(decision_time, current_month, current_week);
   else if(g_weekly_signal_bar && g_model_ready)
      Strategy_LoadWeeklySignal(decision_time, current_week);
  }

bool Strategy_IsPairMagic(const long magic)
  {
   return (magic == QM_MagicChecked(qm_ea_id, 0, g_leg_xau) ||
           magic == QM_MagicChecked(qm_ea_id, 1, g_leg_xag));
  }

bool Strategy_WeekAlreadyEntered(const int week_key,
                                 const datetime decision_bar_time)
  {
   if(week_key <= 0 || decision_bar_time <= 0)
      return true;
   if(g_last_entry_week_key == week_key)
      return true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;
      if(Strategy_WeekKey((datetime)PositionGetInteger(POSITION_TIME)) == week_key)
         return true;
     }

   const datetime history_start = decision_bar_time - (datetime)(21 * 86400);
   if(history_start <= 0 || !HistorySelect(history_start, TimeCurrent()))
      return true;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0 ||
         !Strategy_IsPairMagic(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC)))
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      if(Strategy_WeekKey((datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME)) ==
         week_key)
         return true;
     }
   return false;
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   return ((long)(TimeCurrent() - entry_time) >=
           (long)MathMax(1, strategy_max_hold_days) * 86400);
  }

double Strategy_RoundLotsDown(const string symbol, const double raw_lots)
  {
   const double minimum = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double maximum = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(raw_lots <= 0.0 || minimum <= 0.0 || maximum <= 0.0 || step <= 0.0)
      return 0.0;
   double lots = MathFloor((raw_lots + 1.0e-12) / step) * step;
   lots = MathMin(lots, maximum);
   if(lots < minimum)
      return 0.0;
   return NormalizeDouble(lots, 8);
  }

bool Strategy_PreparePackage(const double beta,
                             const QM_OrderType xau_type,
                             const QM_OrderType xag_type,
                             double &xau_lots,
                             double &xag_lots,
                             double &xau_stop,
                             double &xag_stop)
  {
   xau_lots = 0.0;
   xag_lots = 0.0;
   xau_stop = 0.0;
   xag_stop = 0.0;
   if(beta <= 0.0 || !MathIsValidNumber(beta))
      return false;

   const double xau_entry = QM_OrderTypeIsBuy(xau_type)
      ? SymbolInfoDouble(g_leg_xau, SYMBOL_ASK)
      : SymbolInfoDouble(g_leg_xau, SYMBOL_BID);
   const double xag_entry = QM_OrderTypeIsBuy(xag_type)
      ? SymbolInfoDouble(g_leg_xag, SYMBOL_ASK)
      : SymbolInfoDouble(g_leg_xag, SYMBOL_BID);
   const double xau_atr = QM_ATR(g_leg_xau, PERIOD_D1,
                                 strategy_atr_period_d1, 1);
   const double xag_atr = QM_ATR(g_leg_xag, PERIOD_D1,
                                 strategy_atr_period_d1, 1);
   const double xau_point = SymbolInfoDouble(g_leg_xau, SYMBOL_POINT);
   const double xag_point = SymbolInfoDouble(g_leg_xag, SYMBOL_POINT);
   if(xau_entry <= 0.0 || xag_entry <= 0.0 || xau_atr <= 0.0 ||
      xag_atr <= 0.0 || xau_point <= 0.0 || xag_point <= 0.0)
      return false;

   const double xau_stop_distance = strategy_atr_sl_mult * xau_atr;
   const double xag_stop_distance = strategy_atr_sl_mult * xag_atr;
   const int xau_digits = (int)SymbolInfoInteger(g_leg_xau, SYMBOL_DIGITS);
   const int xag_digits = (int)SymbolInfoInteger(g_leg_xag, SYMBOL_DIGITS);
   xau_stop = NormalizeDouble(QM_OrderTypeIsBuy(xau_type)
                              ? xau_entry - xau_stop_distance
                              : xau_entry + xau_stop_distance, xau_digits);
   xag_stop = NormalizeDouble(QM_OrderTypeIsBuy(xag_type)
                              ? xag_entry - xag_stop_distance
                              : xag_entry + xag_stop_distance, xag_digits);

   const double full_xau_lots =
      QM_LotsForRisk(g_leg_xau, xau_stop_distance / xau_point);
   const double full_xag_lots =
      QM_LotsForRisk(g_leg_xag, xag_stop_distance / xag_point);
   const double xau_contract =
      SymbolInfoDouble(g_leg_xau, SYMBOL_TRADE_CONTRACT_SIZE);
   const double xag_contract =
      SymbolInfoDouble(g_leg_xag, SYMBOL_TRADE_CONTRACT_SIZE);
   if(full_xau_lots <= 0.0 || full_xag_lots <= 0.0 ||
      xau_contract <= 0.0 || xag_contract <= 0.0)
      return false;

   const double xau_notional_per_lot = xau_contract * xau_entry;
   const double xag_notional_per_lot = xag_contract * xag_entry;
   if(xau_notional_per_lot <= 0.0 || xag_notional_per_lot <= 0.0)
      return false;
   // Model residual is ln(XAG) - beta*ln(XAU): target return notionals 1:beta.
   const double lot_ratio_xau_to_xag =
      beta * xag_notional_per_lot / xau_notional_per_lot;
   const double normalized_risk_per_xag_lot =
      lot_ratio_xau_to_xag / full_xau_lots + 1.0 / full_xag_lots;
   if(lot_ratio_xau_to_xag <= 0.0 || normalized_risk_per_xag_lot <= 0.0 ||
      !MathIsValidNumber(normalized_risk_per_xag_lot))
      return false;

   const double raw_xag_lots = 1.0 / normalized_risk_per_xag_lot;
   const double raw_xau_lots = lot_ratio_xau_to_xag * raw_xag_lots;
   xau_lots = Strategy_RoundLotsDown(g_leg_xau, raw_xau_lots);
   xag_lots = Strategy_RoundLotsDown(g_leg_xag, raw_xag_lots);
   if(xau_lots <= 0.0 || xag_lots <= 0.0)
      return false;

   const double normalized_stop_risk =
      xau_lots / full_xau_lots + xag_lots / full_xag_lots;
   const double actual_beta =
      xau_lots * xau_notional_per_lot /
      (xag_lots * xag_notional_per_lot);
   const double hedge_error_pct = 100.0 * MathAbs(actual_beta - beta) / beta;
   return (MathIsValidNumber(normalized_stop_risk) &&
           normalized_stop_risk <= 1.0 + 1.0e-8 &&
           MathIsValidNumber(hedge_error_pct) &&
           hedge_error_pct <= strategy_max_hedge_error_pct);
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double lots,
                      const double stop,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || lots <= 0.0 || stop <= 0.0)
      return false;
   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;
   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy,
                                strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int pair_direction, const double beta)
  {
   if(pair_direction == 0 || beta <= 0.0 || Strategy_OpenPairLegCount() > 0 ||
      !Strategy_SpreadAllowed(g_leg_xau) ||
      !Strategy_SpreadAllowed(g_leg_xag))
      return false;
   const bool long_residual = (pair_direction > 0);
   const QM_OrderType xau_type = long_residual ? QM_SELL : QM_BUY;
   const QM_OrderType xag_type = long_residual ? QM_BUY : QM_SELL;
   const string reason = long_residual
      ? "QM5_13205_LONG_QR_RESIDUAL"
      : "QM5_13205_SHORT_QR_RESIDUAL";

   double xau_lots = 0.0;
   double xag_lots = 0.0;
   double xau_stop = 0.0;
   double xag_stop = 0.0;
   if(!Strategy_PreparePackage(beta, xau_type, xag_type,
                               xau_lots, xag_lots, xau_stop, xag_stop))
      return false;
   const bool xau_ok = Strategy_OpenLeg(g_leg_xau, xau_type, xau_lots,
                                        xau_stop, reason);
   const bool xag_ok = Strategy_OpenLeg(g_leg_xag, xag_type, xag_lots,
                                        xag_stop, reason);
   if(xau_ok && xag_ok)
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }
   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_friday_close_enabled)
      return true;
   if(strategy_formation_bars != 504 ||
      (strategy_history_bars != 650 && strategy_history_bars != 700 &&
       strategy_history_bars != 800))
      return true;
   if(MathAbs(strategy_beta_min - 0.25) > 1.0e-12 ||
      MathAbs(strategy_beta_max - 3.00) > 1.0e-12 ||
      MathAbs(strategy_slope_unique_epsilon - 1.0e-10) > 1.0e-16 ||
      MathAbs(strategy_min_beta_span - 0.05) > 1.0e-12 ||
      MathAbs(strategy_min_band_width - 0.010) > 1.0e-12)
      return true;
   if((MathAbs(strategy_entry_band_mult - 0.00) > 1.0e-12 &&
       MathAbs(strategy_entry_band_mult - 0.10) > 1.0e-12 &&
       MathAbs(strategy_entry_band_mult - 0.25) > 1.0e-12) ||
      (strategy_max_endpoint_gap_days != 7 &&
       strategy_max_endpoint_gap_days != 10))
      return true;
   if((strategy_atr_period_d1 != 14 && strategy_atr_period_d1 != 20 &&
       strategy_atr_period_d1 != 30) ||
      (MathAbs(strategy_atr_sl_mult - 3.0) > 1.0e-12 &&
       MathAbs(strategy_atr_sl_mult - 4.0) > 1.0e-12 &&
       MathAbs(strategy_atr_sl_mult - 5.0) > 1.0e-12) ||
      (strategy_max_hold_days != 42 && strategy_max_hold_days != 70))
      return true;
   if((strategy_xau_max_spread_pts != 1000 &&
       strategy_xau_max_spread_pts != 1500 &&
       strategy_xau_max_spread_pts != 2500) ||
      (strategy_xag_max_spread_pts != 300 &&
       strategy_xag_max_spread_pts != 500 &&
       strategy_xag_max_spread_pts != 800) ||
      (MathAbs(strategy_max_hedge_error_pct - 10.0) > 1.0e-12 &&
       MathAbs(strategy_max_hedge_error_pct - 20.0) > 1.0e-12 &&
       MathAbs(strategy_max_hedge_error_pct - 30.0) > 1.0e-12) ||
      (strategy_deviation_points != 10 && strategy_deviation_points != 20 &&
       strategy_deviation_points != 50))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13205_XAU_XAG_QR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_weekly_signal_bar || !g_signal_ready ||
      g_signal_week_key <= 0 || g_signal_pair_direction == 0 ||
      g_signal_entry_beta <= 0.0 || Strategy_OpenPairLegCount() > 0)
      return false;
   MqlRates decision_rates[1];
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, decision_rates) != 1 || // perf-allowed
      decision_rates[0].time <= 0 ||
      Strategy_WeekAlreadyEntered(g_signal_week_key, decision_rates[0].time))
      return false;

   // A failed package is still this week's attempt in the current runtime.
   if(!Strategy_RecordAttemptState(g_signal_week_key))
      return false;
   Strategy_OpenPair(g_signal_pair_direction, g_signal_entry_beta);
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
   if(g_weekly_signal_bar && g_signal_ready)
     {
      const int direction = Strategy_CurrentPairDirection();
      if((direction > 0 && g_signal_y >= g_signal_q50) ||
         (direction < 0 && g_signal_y <= g_signal_q50))
        {
         Strategy_ClosePair(QM_EXIT_OPPOSITE_SIGNAL);
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      return (QM_NewsAllowsTrade2(g_leg_xau, broker_time,
                                  qm_news_temporal, qm_news_compliance) &&
              QM_NewsAllowsTrade2(g_leg_xag, broker_time,
                                  qm_news_temporal, qm_news_compliance));
     }
   return (QM_NewsAllowsTrade(g_leg_xau, broker_time, qm_news_mode_legacy) &&
           QM_NewsAllowsTrade(g_leg_xag, broker_time, qm_news_mode_legacy));
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

int OnInit()
  {
   SymbolSelect(g_leg_xau, true);
   SymbolSelect(g_leg_xag, true);
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
   if(QM_MagicChecked(qm_ea_id, 0, g_leg_xau) <= 0 ||
      QM_MagicChecked(qm_ea_id, 1, g_leg_xag) <= 0)
      return INIT_FAILED;

   string basket_symbols[2] = {g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1,
                          MathMax(800, strategy_history_bars));
   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: restart state anchor.
   Strategy_LoadAttemptState(current_bar_time);
   const int current_month = Strategy_MonthKey(current_bar_time);
   const int current_week = Strategy_WeekKey(current_bar_time);
   if(current_month > 0 && current_week > 0 && !Strategy_NoTradeFilter())
      Strategy_RestoreMonthlyModel(current_bar_time,
                                   current_month, current_week);
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_13205\",\"ea\":\"xau-xag-qc\"}");
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
   const bool entry_blocked = Strategy_NoTradeFilter();
   const bool new_bar = QM_IsNewBar();
   g_monthly_refit_bar = false;
   g_weekly_signal_bar = false;
   if(new_bar && !entry_blocked)
      Strategy_AdvanceSignalOnNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }
   // Invalid or unauthorized inputs block new risk but never bypass orphan,
   // median, or time-stop lifecycle management for an existing package.
   if(entry_blocked)
      return;
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
