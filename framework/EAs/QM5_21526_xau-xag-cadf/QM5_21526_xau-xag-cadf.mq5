#property strict
#property version   "5.0"
#property description "QM5_21526 annual-frozen XAU XAG CADF residual reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy code is confined to the Strategy_* helpers/hooks. Framework
// lifecycle, kill-switch, risk, news, Friday-close and telemetry wiring below
// remains the canonical V5 skeleton contract.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 21526;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
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
input int    strategy_training_bars       = 252;
input double strategy_cadf_critical       = -3.343;
input double strategy_entry_z             = 1.0;
input double strategy_exit_z              = 0.5;
input double strategy_beta_min            = 0.10;
input double strategy_beta_max            = 3.00;
input double strategy_half_life_min        = 2.0;
input double strategy_half_life_max        = 30.0;
input int    strategy_history_bars_d1     = 900;
input int    strategy_max_endpoint_gap_days = 10;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.5;
input int    strategy_xau_max_spread_points = 1500;
input int    strategy_xag_max_spread_points = 1500;
input int    strategy_deviation_points    = 20;

#define STRATEGY_TRAINING_COUNT 252

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";
bool   g_basket_scope_ready = false;

bool     g_model_built = false;
bool     g_model_admissible = false;
int      g_model_year = -1;
datetime g_model_anchor = 0;
double   g_model_alpha = 0.0;
double   g_model_beta = 0.0;
double   g_model_residual_mean = 0.0;
double   g_model_residual_sigma = 0.0;
double   g_model_cadf_t = 0.0;
double   g_model_theta = 0.0;
double   g_model_half_life = 0.0;

bool     g_state_ready = false;
datetime g_state_host_bar = 0;
datetime g_signal_time = 0;
datetime g_previous_signal_time = 0;
double   g_residual_z = 0.0;
double   g_previous_z = 0.0;

string   g_attempt_key = "";
datetime g_last_attempt_signal = 0;

string Strategy_BoolJson(const bool value)
  {
   return value ? "true" : "false";
  }

bool Strategy_ValueIs(const double value, const double expected)
  {
   return (MathAbs(value - expected) <= 1.0e-9);
  }

int Strategy_Year(const datetime value)
  {
   if(value <= 0)
      return -1;
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.year;
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xau)
      return 0;
   if(symbol == g_leg_xag)
      return 1;
   return -1;
  }

bool Strategy_IsHostSymbol()
  {
   return (_Symbol == g_leg_xau);
  }

int Strategy_MagicForSlot(const int slot)
  {
   if(slot == 0)
      return QM_MagicChecked(21526, 0, g_leg_xau);
   if(slot == 1)
      return QM_MagicChecked(21526, 1, g_leg_xag);
   return -1;
  }

bool Strategy_IsOwnedMagic(const long magic)
  {
   const int xau_magic = Strategy_MagicForSlot(0);
   const int xag_magic = Strategy_MagicForSlot(1);
   return ((xau_magic > 0 && magic == (long)xau_magic) ||
           (xag_magic > 0 && magic == (long)xag_magic));
  }

bool Strategy_IsOwnedPosition()
  {
   return Strategy_IsOwnedMagic(PositionGetInteger(POSITION_MAGIC));
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   string allowed[2] = {"XAUUSD.DWX", "XAGUSD.DWX"};
   for(int i = 0; i < 2; ++i)
      if(!SymbolSelect(allowed[i], true))
         return false;

   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_D1, strategy_history_bars_d1);
   g_basket_scope_ready = true;
   return true;
  }

bool Strategy_ConfigurationAuthorized()
  {
   return (qm_ea_id == 21526 && qm_magic_slot_offset == 0 &&
           qm_rng_seed == 42 && Strategy_ValueIs(RISK_PERCENT, 0.0) &&
           Strategy_ValueIs(RISK_FIXED, 1000.0) &&
           Strategy_ValueIs(PORTFOLIO_WEIGHT, 1.0) &&
           qm_news_temporal == QM_NEWS_TEMPORAL_OFF &&
           qm_news_compliance == QM_NEWS_COMPLIANCE_NONE &&
           qm_news_mode_legacy == QM_NEWS_OFF &&
           qm_news_stale_max_hours == 336 && qm_news_min_impact == "high" &&
           !qm_friday_close_enabled && qm_friday_close_hour_broker == 21 &&
           Strategy_ValueIs(qm_stress_reject_probability, 0.0) &&
           strategy_training_bars == STRATEGY_TRAINING_COUNT &&
           Strategy_ValueIs(strategy_cadf_critical, -3.343) &&
           Strategy_ValueIs(strategy_entry_z, 1.0) &&
           Strategy_ValueIs(strategy_exit_z, 0.5) &&
           Strategy_ValueIs(strategy_beta_min, 0.10) &&
           Strategy_ValueIs(strategy_beta_max, 3.00) &&
           Strategy_ValueIs(strategy_half_life_min, 2.0) &&
           Strategy_ValueIs(strategy_half_life_max, 30.0) &&
           strategy_history_bars_d1 == 900 &&
           strategy_max_endpoint_gap_days == 10 &&
           strategy_atr_period_d1 == 20 &&
           Strategy_ValueIs(strategy_atr_sl_mult, 3.5) &&
           strategy_xau_max_spread_points == 1500 &&
           strategy_xag_max_spread_points == 1500 &&
           strategy_deviation_points == 20);
  }

bool Strategy_SeriesDescending(const datetime &times[], const int count)
  {
   if(count <= 0)
      return false;
   for(int i = 0; i < count; ++i)
     {
      if(times[i] <= 0)
         return false;
      if(i > 0 && times[i] >= times[i - 1])
         return false;
     }
   return true;
  }

bool Strategy_CopyAnnualTraining(const int target_year,
                                 double &xau_training[],
                                 double &xag_training[],
                                 datetime &anchor_time)
  {
   anchor_time = 0;
   ArrayResize(xau_training, 0);
   ArrayResize(xag_training, 0);
   if(target_year < 1970 || !Strategy_EnsureBasketScope())
      return false;

   datetime xau_times[];
   datetime xag_times[];
   double xau_closes[];
   double xag_closes[];
   ArraySetAsSeries(xau_times, true);
   ArraySetAsSeries(xag_times, true);
   ArraySetAsSeries(xau_closes, true);
   ArraySetAsSeries(xag_closes, true);

   // perf-allowed: bounded raw D1 reconstruction occurs once per broker year
   // (and once after restart) and is never called from an ungated tick loop.
   const int xau_time_count = CopyTime(g_leg_xau, PERIOD_D1, 0, strategy_history_bars_d1, xau_times); // perf-allowed: annual D1 anchor reconstruction.
   const int xag_time_count = CopyTime(g_leg_xag, PERIOD_D1, 0, strategy_history_bars_d1, xag_times); // perf-allowed: annual D1 synchronization.
   const int xau_close_count = CopyClose(g_leg_xau, PERIOD_D1, 0, strategy_history_bars_d1, xau_closes); // perf-allowed: annual D1 formation sample.
   const int xag_close_count = CopyClose(g_leg_xag, PERIOD_D1, 0, strategy_history_bars_d1, xag_closes); // perf-allowed: annual D1 formation sample.
   if(xau_time_count < STRATEGY_TRAINING_COUNT + 2 ||
      xag_time_count < STRATEGY_TRAINING_COUNT + 2 ||
      xau_close_count != xau_time_count || xag_close_count != xag_time_count)
      return false;
   if(!Strategy_SeriesDescending(xau_times, xau_time_count) ||
      !Strategy_SeriesDescending(xag_times, xag_time_count))
      return false;

   int anchor_index = -1;
   for(int i = 0; i < xau_time_count; ++i)
     {
      const int year = Strategy_Year(xau_times[i]);
      if(year == target_year)
         anchor_index = i;
      else if(year < target_year && anchor_index >= 0)
         break;
     }
   if(anchor_index < 0 || anchor_index + 1 >= xau_time_count ||
      Strategy_Year(xau_times[anchor_index + 1]) >= target_year)
      return false;

   anchor_time = xau_times[anchor_index];
   double newest_xau[STRATEGY_TRAINING_COUNT];
   double newest_xag[STRATEGY_TRAINING_COUNT];
   int found = 0;
   int xag_index = 0;
   for(int xau_index = anchor_index + 1;
       xau_index < xau_time_count && found < STRATEGY_TRAINING_COUNT;
       ++xau_index)
     {
      const datetime wanted = xau_times[xau_index];
      while(xag_index < xag_time_count && xag_times[xag_index] > wanted)
         ++xag_index;
      if(xag_index >= xag_time_count)
         break;
      if(xag_times[xag_index] != wanted)
         continue;
      if(wanted >= anchor_time || xau_closes[xau_index] <= 0.0 ||
         xag_closes[xag_index] <= 0.0 ||
         !MathIsValidNumber(xau_closes[xau_index]) ||
         !MathIsValidNumber(xag_closes[xag_index]))
         return false;
      newest_xau[found] = xau_closes[xau_index];
      newest_xag[found] = xag_closes[xag_index];
      ++found;
     }
   if(found != STRATEGY_TRAINING_COUNT)
      return false;

   ArrayResize(xau_training, STRATEGY_TRAINING_COUNT);
   ArrayResize(xag_training, STRATEGY_TRAINING_COUNT);
   for(int newest_index = 0; newest_index < STRATEGY_TRAINING_COUNT; ++newest_index)
     {
      const int chronological_index = STRATEGY_TRAINING_COUNT - 1 - newest_index;
      xau_training[chronological_index] = newest_xau[newest_index];
      xag_training[chronological_index] = newest_xag[newest_index];
     }
   return true;
  }

bool Strategy_AdfOneLagTStat(const double &residuals[],
                             const int count,
                             double &rho,
                             double &t_stat)
  {
   rho = 0.0;
   t_stat = 0.0;
   if(count != STRATEGY_TRAINING_COUNT)
      return false;

   double n = 0.0;
   double sx1 = 0.0;
   double sx2 = 0.0;
   double sx1x1 = 0.0;
   double sx1x2 = 0.0;
   double sx2x2 = 0.0;
   double sy = 0.0;
   double sx1y = 0.0;
   double sx2y = 0.0;
   for(int i = 2; i < count; ++i)
     {
      const double dependent = residuals[i] - residuals[i - 1];
      const double lagged_level = residuals[i - 1];
      const double lagged_delta = residuals[i - 1] - residuals[i - 2];
      n += 1.0;
      sx1 += lagged_level;
      sx2 += lagged_delta;
      sx1x1 += lagged_level * lagged_level;
      sx1x2 += lagged_level * lagged_delta;
      sx2x2 += lagged_delta * lagged_delta;
      sy += dependent;
      sx1y += lagged_level * dependent;
      sx2y += lagged_delta * dependent;
     }

   const double determinant =
      n * (sx1x1 * sx2x2 - sx1x2 * sx1x2)
      - sx1 * (sx1 * sx2x2 - sx2 * sx1x2)
      + sx2 * (sx1 * sx1x2 - sx2 * sx1x1);
   if(n <= 3.0 || MathAbs(determinant) <= 1.0e-20 ||
      !MathIsValidNumber(determinant))
      return false;

   const double inv00 = (sx1x1 * sx2x2 - sx1x2 * sx1x2) / determinant;
   const double inv01 = (sx2 * sx1x2 - sx1 * sx2x2) / determinant;
   const double inv02 = (sx1 * sx1x2 - sx2 * sx1x1) / determinant;
   const double inv11 = (n * sx2x2 - sx2 * sx2) / determinant;
   const double inv12 = (sx1 * sx2 - n * sx1x2) / determinant;
   const double inv22 = (n * sx1x1 - sx1 * sx1) / determinant;

   const double intercept = inv00 * sy + inv01 * sx1y + inv02 * sx2y;
   rho = inv01 * sy + inv11 * sx1y + inv12 * sx2y;
   const double psi = inv02 * sy + inv12 * sx1y + inv22 * sx2y;
   double sse = 0.0;
   for(int i = 2; i < count; ++i)
     {
      const double dependent = residuals[i] - residuals[i - 1];
      const double lagged_level = residuals[i - 1];
      const double lagged_delta = residuals[i - 1] - residuals[i - 2];
      const double error = dependent -
                           (intercept + rho * lagged_level + psi * lagged_delta);
      sse += error * error;
     }

   const double variance = sse / (n - 3.0);
   const double rho_variance = variance * inv11;
   if(rho_variance <= 0.0 || !MathIsValidNumber(rho_variance) ||
      !MathIsValidNumber(rho))
      return false;
   t_stat = rho / MathSqrt(rho_variance);
   return MathIsValidNumber(t_stat);
  }

bool Strategy_OuHalfLife(const double &residuals[],
                         const int count,
                         const double residual_mean,
                         double &theta,
                         double &half_life)
  {
   theta = 0.0;
   half_life = 0.0;
   if(count != STRATEGY_TRAINING_COUNT)
      return false;

   double sxx = 0.0;
   double sxy = 0.0;
   for(int i = 1; i < count; ++i)
     {
      const double lagged_centered = residuals[i - 1] - residual_mean;
      const double delta = residuals[i] - residuals[i - 1];
      sxx += lagged_centered * lagged_centered;
      sxy += lagged_centered * delta;
     }
   if(sxx <= 1.0e-20 || !MathIsValidNumber(sxx) || !MathIsValidNumber(sxy))
      return false;
   theta = sxy / sxx;
   if(theta >= 0.0 || !MathIsValidNumber(theta))
      return false;
   half_life = -MathLog(2.0) / theta;
   return (half_life > 0.0 && MathIsValidNumber(half_life));
  }

void Strategy_ResetModel(const int target_year)
  {
   g_model_built = false;
   g_model_admissible = false;
   g_model_year = target_year;
   g_model_anchor = 0;
   g_model_alpha = 0.0;
   g_model_beta = 0.0;
   g_model_residual_mean = 0.0;
   g_model_residual_sigma = 0.0;
   g_model_cadf_t = 0.0;
   g_model_theta = 0.0;
   g_model_half_life = 0.0;
  }

bool Strategy_FitAnnualModel(const int target_year)
  {
   Strategy_ResetModel(target_year);
   double xau_training[];
   double xag_training[];
   datetime anchor = 0;
   if(!Strategy_CopyAnnualTraining(target_year, xau_training, xag_training, anchor))
      return false;

   // Once the exact pre-year formation sample exists, every arithmetic or
   // admission failure is frozen for the year; no intrayear rescue refit.
   g_model_built = true;
   g_model_anchor = anchor;

   double log_xau[STRATEGY_TRAINING_COUNT];
   double log_xag[STRATEGY_TRAINING_COUNT];
   double sum_x = 0.0;
   double sum_y = 0.0;
   for(int i = 0; i < STRATEGY_TRAINING_COUNT; ++i)
     {
      log_xau[i] = MathLog(xau_training[i]);
      log_xag[i] = MathLog(xag_training[i]);
      if(!MathIsValidNumber(log_xau[i]) || !MathIsValidNumber(log_xag[i]))
         return false;
      sum_x += log_xag[i];
      sum_y += log_xau[i];
     }

   const double mean_x = sum_x / (double)STRATEGY_TRAINING_COUNT;
   const double mean_y = sum_y / (double)STRATEGY_TRAINING_COUNT;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int i = 0; i < STRATEGY_TRAINING_COUNT; ++i)
     {
      const double dx = log_xag[i] - mean_x;
      const double dy = log_xau[i] - mean_y;
      sxx += dx * dx;
      sxy += dx * dy;
     }
   if(sxx <= 1.0e-20 || !MathIsValidNumber(sxx) || !MathIsValidNumber(sxy))
      return false;

   g_model_beta = sxy / sxx;
   g_model_alpha = mean_y - g_model_beta * mean_x;
   if(!MathIsValidNumber(g_model_beta) || !MathIsValidNumber(g_model_alpha))
      return false;

   double residuals[STRATEGY_TRAINING_COUNT];
   double residual_sum = 0.0;
   for(int i = 0; i < STRATEGY_TRAINING_COUNT; ++i)
     {
      residuals[i] = log_xau[i] - g_model_alpha - g_model_beta * log_xag[i];
      if(!MathIsValidNumber(residuals[i]))
         return false;
      residual_sum += residuals[i];
     }
   g_model_residual_mean = residual_sum / (double)STRATEGY_TRAINING_COUNT;

   double variance_sum = 0.0;
   for(int i = 0; i < STRATEGY_TRAINING_COUNT; ++i)
     {
      const double centered = residuals[i] - g_model_residual_mean;
      variance_sum += centered * centered;
     }
   g_model_residual_sigma =
      MathSqrt(variance_sum / (double)(STRATEGY_TRAINING_COUNT - 1));
   if(g_model_residual_sigma <= 1.0e-10 ||
      !MathIsValidNumber(g_model_residual_sigma))
      return false;

   double rho = 0.0;
   if(!Strategy_AdfOneLagTStat(residuals,
                               STRATEGY_TRAINING_COUNT,
                               rho,
                               g_model_cadf_t))
      return false;
   if(!Strategy_OuHalfLife(residuals,
                           STRATEGY_TRAINING_COUNT,
                           g_model_residual_mean,
                           g_model_theta,
                           g_model_half_life))
      return false;

   const bool beta_pass =
      (g_model_beta >= strategy_beta_min && g_model_beta <= strategy_beta_max);
   const bool cadf_pass = (g_model_cadf_t <= strategy_cadf_critical);
   const bool half_life_pass =
      (g_model_theta < 0.0 &&
       g_model_half_life >= strategy_half_life_min &&
       g_model_half_life <= strategy_half_life_max);
   g_model_admissible = beta_pass && cadf_pass && half_life_pass;

   QM_LogEvent(g_model_admissible ? QM_INFO : QM_WARN,
               "PAIR_MODEL_FIT",
               StringFormat("{\"year\":%d,\"anchor\":%I64d,\"alpha\":%.10f,\"beta\":%.10f,\"residual_mean\":%.10f,\"residual_sigma\":%.10f,\"cadf_t\":%.6f,\"theta\":%.10f,\"half_life\":%.4f,\"beta_pass\":%s,\"cadf_pass\":%s,\"half_life_pass\":%s}",
                            target_year,
                            (long)g_model_anchor,
                            g_model_alpha,
                            g_model_beta,
                            g_model_residual_mean,
                            g_model_residual_sigma,
                            g_model_cadf_t,
                            g_model_theta,
                            g_model_half_life,
                            Strategy_BoolJson(beta_pass),
                            Strategy_BoolJson(cadf_pass),
                            Strategy_BoolJson(half_life_pass)));
   return g_model_admissible;
  }

bool Strategy_EnsureAnnualModel(const int target_year)
  {
   if(g_model_year == target_year && g_model_built)
      return g_model_admissible;
   return Strategy_FitAnnualModel(target_year);
  }

bool Strategy_CopyLatestSynchronizedSignals(const datetime current_host_bar,
                                            datetime &latest_time,
                                            double &latest_xau,
                                            double &latest_xag,
                                            datetime &previous_time,
                                            double &previous_xau,
                                            double &previous_xag)
  {
   latest_time = 0;
   previous_time = 0;
   latest_xau = 0.0;
   latest_xag = 0.0;
   previous_xau = 0.0;
   previous_xag = 0.0;
   const int scan_count = MathMax(16, strategy_max_endpoint_gap_days + 4);
   datetime xau_times[];
   datetime xag_times[];
   double xau_closes[];
   double xag_closes[];
   ArraySetAsSeries(xau_times, true);
   ArraySetAsSeries(xag_times, true);
   ArraySetAsSeries(xau_closes, true);
   ArraySetAsSeries(xag_closes, true);

   // perf-allowed: bounded completed-D1 signal read, cached once per host bar.
   const int xau_time_count = CopyTime(g_leg_xau, PERIOD_D1, 1, scan_count, xau_times); // perf-allowed: once-per-host-D1 synchronized signal read.
   const int xag_time_count = CopyTime(g_leg_xag, PERIOD_D1, 1, scan_count, xag_times); // perf-allowed: once-per-host-D1 synchronized signal read.
   const int xau_close_count = CopyClose(g_leg_xau, PERIOD_D1, 1, scan_count, xau_closes); // perf-allowed: once-per-host-D1 frozen-model z-score.
   const int xag_close_count = CopyClose(g_leg_xag, PERIOD_D1, 1, scan_count, xag_closes); // perf-allowed: once-per-host-D1 frozen-model z-score.
   if(xau_time_count < 2 || xag_time_count < 2 ||
      xau_close_count != xau_time_count || xag_close_count != xag_time_count)
      return false;
   if(!Strategy_SeriesDescending(xau_times, xau_time_count) ||
      !Strategy_SeriesDescending(xag_times, xag_time_count))
      return false;

   int xag_index = 0;
   int found = 0;
   for(int xau_index = 0; xau_index < xau_time_count && found < 2; ++xau_index)
     {
      const datetime wanted = xau_times[xau_index];
      while(xag_index < xag_time_count && xag_times[xag_index] > wanted)
         ++xag_index;
      if(xag_index >= xag_time_count)
         break;
      if(xag_times[xag_index] != wanted)
         continue;
      if(wanted < g_model_anchor || wanted >= current_host_bar ||
         xau_closes[xau_index] <= 0.0 || xag_closes[xag_index] <= 0.0 ||
         !MathIsValidNumber(xau_closes[xau_index]) ||
         !MathIsValidNumber(xag_closes[xag_index]))
         continue;

      if(found == 0)
        {
         latest_time = wanted;
         latest_xau = xau_closes[xau_index];
         latest_xag = xag_closes[xag_index];
        }
      else
        {
         previous_time = wanted;
         previous_xau = xau_closes[xau_index];
         previous_xag = xag_closes[xag_index];
        }
      ++found;
     }

   if(found != 2 || previous_time >= latest_time || latest_time >= current_host_bar)
      return false;
   if(current_host_bar - latest_time >
      (long)strategy_max_endpoint_gap_days * 86400)
      return false;
   return true;
  }

bool Strategy_RefreshFrozenState()
  {
   const datetime current_host_bar = iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: cheap D1 cache key.
   if(current_host_bar <= 0)
      return false;
   if(g_state_host_bar == current_host_bar)
      return g_state_ready;

   g_state_host_bar = current_host_bar;
   g_state_ready = false;
   g_signal_time = 0;
   g_previous_signal_time = 0;
   g_residual_z = 0.0;
   g_previous_z = 0.0;
   const int target_year = Strategy_Year(current_host_bar);
   if(!Strategy_EnsureAnnualModel(target_year))
      return false;

   double latest_xau = 0.0;
   double latest_xag = 0.0;
   double previous_xau = 0.0;
   double previous_xag = 0.0;
   if(!Strategy_CopyLatestSynchronizedSignals(current_host_bar,
                                               g_signal_time,
                                               latest_xau,
                                               latest_xag,
                                               g_previous_signal_time,
                                               previous_xau,
                                               previous_xag))
      return false;

   const double latest_residual =
      MathLog(latest_xau) - g_model_alpha - g_model_beta * MathLog(latest_xag);
   const double previous_residual =
      MathLog(previous_xau) - g_model_alpha - g_model_beta * MathLog(previous_xag);
   g_residual_z =
      (latest_residual - g_model_residual_mean) / g_model_residual_sigma;
   g_previous_z =
      (previous_residual - g_model_residual_mean) / g_model_residual_sigma;
   g_state_ready =
      (MathIsValidNumber(g_residual_z) && MathIsValidNumber(g_previous_z));
   return g_state_ready;
  }

bool Strategy_SpreadWithinCap(const string symbol, const int max_points)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid || max_points <= 0)
      return false;
   const double spread_points = (ask - bid) / point;
   return (MathIsValidNumber(spread_points) &&
           spread_points >= 0.0 && spread_points <= (double)max_points);
  }

int Strategy_OpenPairLegCount()
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

bool Strategy_PackageValid(const int expected_residual_direction = 0)
  {
   int xau_count = 0;
   int xag_count = 0;
   ENUM_POSITION_TYPE xau_type = POSITION_TYPE_BUY;
   ENUM_POSITION_TYPE xag_type = POSITION_TYPE_BUY;
   const int xau_magic = Strategy_MagicForSlot(0);
   const int xag_magic = Strategy_MagicForSlot(1);
   if(xau_magic <= 0 || xag_magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsOwnedPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const long magic = PositionGetInteger(POSITION_MAGIC);
      const double stop = PositionGetDouble(POSITION_SL);
      if(stop <= 0.0 || !MathIsValidNumber(stop))
         return false;

      if(symbol == g_leg_xau && magic == (long)xau_magic)
        {
         ++xau_count;
         xau_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        }
      else if(symbol == g_leg_xag && magic == (long)xag_magic)
        {
         ++xag_count;
         xag_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        }
      else
         return false;
     }

   if(xau_count != 1 || xag_count != 1 || xau_type == xag_type)
      return false;
   if(expected_residual_direction > 0)
      return (xau_type == POSITION_TYPE_SELL && xag_type == POSITION_TYPE_BUY);
   if(expected_residual_direction < 0)
      return (xau_type == POSITION_TYPE_BUY && xag_type == POSITION_TYPE_SELL);
   return true;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

datetime Strategy_PairOldestOpenTime()
  {
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsOwnedPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

string Strategy_AttemptKey()
  {
   return StringFormat("QM5_21526_ATTEMPT_%I64d",
                       (long)AccountInfoInteger(ACCOUNT_LOGIN));
  }

void Strategy_LoadAttemptState()
  {
   g_attempt_key = Strategy_AttemptKey();
   g_last_attempt_signal = 0;
   if(!GlobalVariableCheck(g_attempt_key))
      return;
   const double stored = GlobalVariableGet(g_attempt_key);
   if(stored <= 0.0 || !MathIsValidNumber(stored))
      return;

   g_last_attempt_signal = (datetime)(long)stored;
   const datetime current_host_bar = iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: initialization-only tester hygiene.
   if(MQLInfoInteger(MQL_TESTER) && current_host_bar > 0 &&
      g_last_attempt_signal > current_host_bar)
     {
      GlobalVariableDel(g_attempt_key);
      GlobalVariablesFlush();
      g_last_attempt_signal = 0;
     }
  }

bool Strategy_AttemptMarkerIs(const datetime signal_time)
  {
   if(signal_time <= 0)
      return true;
   if(g_last_attempt_signal == signal_time)
      return true;
   if(g_attempt_key == "")
      g_attempt_key = Strategy_AttemptKey();
   if(!GlobalVariableCheck(g_attempt_key))
      return false;
   const double stored = GlobalVariableGet(g_attempt_key);
   return ((datetime)(long)stored == signal_time);
  }

bool Strategy_PersistAttempt(const datetime signal_time)
  {
   if(signal_time <= 0)
      return false;
   if(g_attempt_key == "")
      g_attempt_key = Strategy_AttemptKey();
   if(GlobalVariableSet(g_attempt_key, (double)(long)signal_time) == 0)
      return false;
   GlobalVariablesFlush();
   g_last_attempt_signal = signal_time;
   return true;
  }

string Strategy_SignalTag(const datetime signal_time, const int direction)
  {
   return StringFormat("Q21526%s%I64d",
                       direction > 0 ? "P" : "N",
                       (long)signal_time);
  }

bool Strategy_HistoryHasSignal(const datetime signal_time)
  {
   if(signal_time <= 0 || !HistorySelect(signal_time, TimeCurrent()))
      return true;
   const string positive_tag = Strategy_SignalTag(signal_time, 1);
   const string negative_tag = Strategy_SignalTag(signal_time, -1);
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         !Strategy_IsOwnedMagic(HistoryDealGetInteger(deal, DEAL_MAGIC)))
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      const string comment = HistoryDealGetString(deal, DEAL_COMMENT);
      if(comment == positive_tag || comment == negative_tag)
         return true;
     }
   return false;
  }

double Strategy_LotsForLeg(const string symbol,
                           const double risk_weight,
                           const double risk_weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_weight <= 0.0 ||
      risk_weight_sum <= 0.0 || !MathIsValidNumber(atr))
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * risk_weight / risk_weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0 ||
      !MathIsValidNumber(lots))
      return 0.0;
   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double risk_weight,
                      const double risk_weight_sum,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0 || !MathIsValidNumber(entry) ||
      !MathIsValidNumber(atr))
      return false;
   const double stop_distance = strategy_atr_sl_mult * atr;
   const double stop = QM_OrderTypeIsBuy(type) ? entry - stop_distance
                                               : entry + stop_distance;
   if(stop_distance <= 0.0 || stop <= 0.0 || !MathIsValidNumber(stop))
      return false;
   const double lots = Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(lots <= 0.0)
      return false;

   QM_BasketOrderRequest request;
   request.symbol = symbol;
   request.type = type;
   request.price = 0.0;
   request.sl = NormalizeDouble(stop, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   request.tp = 0.0;
   request.lots = lots;
   request.reason = reason;
   request.symbol_slot = slot;
   request.expiration_seconds = 0;
   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_deviation_points,
                                request,
                                ticket);
  }

bool Strategy_OpenPair(const int residual_direction)
  {
   if(residual_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadWithinCap(g_leg_xau, strategy_xau_max_spread_points) ||
      !Strategy_SpreadWithinCap(g_leg_xag, strategy_xag_max_spread_points))
      return false;

   const double xau_weight = 1.0;
   const double xag_weight = MathAbs(g_model_beta);
   const double weight_sum = xau_weight + xag_weight;
   if(xag_weight <= 0.0 || weight_sum <= 0.0 || !MathIsValidNumber(weight_sum))
      return false;

   const bool positive_residual = (residual_direction > 0);
   const QM_OrderType xau_type = positive_residual ? QM_SELL : QM_BUY;
   const QM_OrderType xag_type = positive_residual ? QM_BUY : QM_SELL;
   const string reason = Strategy_SignalTag(g_signal_time, residual_direction);

   if(!Strategy_OpenLeg(g_leg_xau, xau_type, xau_weight, weight_sum, reason))
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }
   const bool xag_ok =
      Strategy_OpenLeg(g_leg_xag, xag_type, xag_weight, weight_sum, reason);
   if(xag_ok && Strategy_PackageValid(residual_direction))
      return true;

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();
   if(!Strategy_IsHostSymbol() || (ENUM_TIMEFRAMES)_Period != PERIOD_D1 ||
      Strategy_SlotForSymbol(_Symbol) != qm_magic_slot_offset ||
      !Strategy_ConfigurationAuthorized())
     {
      if(Strategy_OpenPairLegCount() > 0)
         Strategy_ClosePair(QM_EXIT_STRATEGY);
      return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_21526_CADF_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_OpenPairLegCount() > 0 || !Strategy_RefreshFrozenState())
      return false;

   int residual_direction = 0;
   if(g_previous_z < strategy_entry_z && g_residual_z >= strategy_entry_z)
      residual_direction = 1;
   else if(g_previous_z > -strategy_entry_z && g_residual_z <= -strategy_entry_z)
      residual_direction = -1;
   if(residual_direction == 0)
      return false;

   // Capture prior state, then durably consume the signal before deal-history,
   // spread, quote, ATR, sizing or order gates. No failed attempt can retry.
   const bool already_marked = Strategy_AttemptMarkerIs(g_signal_time);
   if(!Strategy_PersistAttempt(g_signal_time))
      return false;
   if(already_marked || Strategy_HistoryHasSignal(g_signal_time))
      return false;

   Strategy_OpenPair(residual_direction);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Frozen broker hard stops only: no trail, break-even, partial close,
   // scale-in, grid, martingale or pyramid.
  }

bool Strategy_ExitSignal()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return false;
   if(open_legs != 2 || !Strategy_PackageValid())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   const datetime current_host_bar = iTime(g_leg_xau, PERIOD_D1, 0); // perf-allowed: cheap rollover/cache guard.
   const datetime opened = Strategy_PairOldestOpenTime();
   const int current_year = Strategy_Year(current_host_bar);
   if(current_year < 0 || opened <= 0 || Strategy_Year(opened) != current_year ||
      (g_model_year >= 0 && g_model_year != current_year))
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   if(!Strategy_RefreshFrozenState())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }
   const int max_hold_days = (int)MathCeil(g_model_half_life);
   if(max_hold_days <= 0 ||
      TimeCurrent() - opened >= (long)max_hold_days * 86400)
     {
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
      return false;
     }
   if(MathAbs(g_residual_z) <= strategy_exit_z)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xau,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_leg_xag,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xau, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_xag, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Canonical V5 framework wiring.
// -----------------------------------------------------------------------------

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

   Strategy_EnsureBasketScope();
   Strategy_LoadAttemptState();
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
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
