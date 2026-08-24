#property strict
#property version   "5.1"
#property description "QM5_1408 Classical Bull Flag Continuation H1"

#include <QM/QM_Common.mqh>

// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1408_classical-bull-flag-continuation-h1.md
// Edwards & Magee, Technical Analysis of Stock Trends, 10th ed., Ch. 9.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1408;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf                    = PERIOD_H1;
input int    strategy_atr_period                     = 14;
input int    strategy_fractal_wing_bars              = 1;
input int    strategy_pole_min_bars                  = 12;
input int    strategy_pole_max_bars                  = 36;
input double strategy_pole_min_atr                   = 4.0;
input double strategy_pole_slope_min_atr             = 0.20;
input double strategy_pole_max_pullback_pct          = 0.35;
input bool   strategy_volume_filter_enabled          = true;
input double strategy_pole_volume_mult               = 1.20;
input int    strategy_pole_volume_prior_bars         = 60;
input int    strategy_flag_min_bars                  = 5;
input int    strategy_flag_max_bars                  = 18;
input double strategy_flag_slope_min_atr             = -0.10;
input double strategy_flag_slope_max_atr             = -0.005;
input double strategy_flag_containment_pct           = 0.80;
input double strategy_flag_channel_tol_atr           = 0.30;
input double strategy_flag_max_retrace_pct           = 0.50;
input double strategy_flag_volume_mult               = 0.80;
input double strategy_breakout_buffer_atr            = 0.40;
input double strategy_tp1_close_fraction             = 0.50;
input double strategy_tp1_ratio                      = 0.50;
input int    strategy_failure_exit_bars              = 6;
input int    strategy_time_stop_bars                 = 24;
input double strategy_sl_buffer_atr                  = 0.30;
input double strategy_sl_cap_atr                     = 2.50;
input bool   strategy_macro_bias_enabled             = true;
input int    strategy_macro_sma_period               = 200;
input int    strategy_reuse_guard_bars               = 12;
input bool   strategy_spread_filter_enabled          = true;
input double strategy_spread_max_atr                 = 0.30;

const int STRATEGY_PENDING_VALID_BARS = 8;
const int STRATEGY_LIFECYCLE_NONE     = 0;
const int STRATEGY_LIFECYCLE_PENDING  = 1;
const int STRATEGY_LIFECYCLE_POSITION = 2;

int      g_h_atr_h1 = INVALID_HANDLE;
int      g_h_sma_h4 = INVALID_HANDLE;
string   g_state_prefix = "";
bool     g_setup_valid = false;
int      g_lifecycle_phase = STRATEGY_LIFECYCLE_NONE;
datetime g_setup_created_bar_time = 0;
datetime g_setup_pole_start_time = 0;
datetime g_setup_pole_end_time = 0;
double   g_active_upper_slope = 0.0;
double   g_active_upper_intercept = 0.0;
datetime g_active_upper_anchor_time = 0;
bool     g_tp1_done = false;
datetime g_pattern_block_until = 0;
bool     g_candidate_ready = false;
bool     g_restart_state_missing = false;

struct StrategyPivot
  {
   int    shift;
   double price;
  };

struct StrategySetupCandidate
  {
   datetime created_bar_time;
   datetime pole_start_time;
   datetime pole_end_time;
   datetime upper_anchor_time;
   double   upper_slope;
   double   upper_intercept;
   double   entry_price;
   double   initial_sl;
   double   full_tp;
  };

StrategySetupCandidate g_candidate;

double Strategy_NormalizePrice(const double price)
  {
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

int Strategy_PeriodSeconds()
  {
   const int seconds = PeriodSeconds(strategy_tf);
   return (seconds > 0) ? seconds : 3600;
  }

string Strategy_StateKey(const string suffix)
  {
   return g_state_prefix + suffix;
  }

void Strategy_ResetMemoryState()
  {
   g_setup_valid = false;
   g_lifecycle_phase = STRATEGY_LIFECYCLE_NONE;
   g_setup_created_bar_time = 0;
   g_setup_pole_start_time = 0;
   g_setup_pole_end_time = 0;
   g_active_upper_slope = 0.0;
   g_active_upper_intercept = 0.0;
   g_active_upper_anchor_time = 0;
   g_tp1_done = false;
   g_candidate_ready = false;
   g_restart_state_missing = false;
   ZeroMemory(g_candidate);
  }

void Strategy_PersistState()
  {
   if(g_state_prefix == "")
      return;
   GlobalVariableSet(Strategy_StateKey("setup"), g_setup_valid ? 1.0 : 0.0);
   GlobalVariableSet(Strategy_StateKey("phase"), (double)g_lifecycle_phase);
   GlobalVariableSet(Strategy_StateKey("created"), (double)g_setup_created_bar_time);
   GlobalVariableSet(Strategy_StateKey("pole_start"), (double)g_setup_pole_start_time);
   GlobalVariableSet(Strategy_StateKey("pole_end"), (double)g_setup_pole_end_time);
   GlobalVariableSet(Strategy_StateKey("upper_slope"), g_active_upper_slope);
   GlobalVariableSet(Strategy_StateKey("upper_int"), g_active_upper_intercept);
   GlobalVariableSet(Strategy_StateKey("upper_anchor"), (double)g_active_upper_anchor_time);
   GlobalVariableSet(Strategy_StateKey("tp1_done"), g_tp1_done ? 1.0 : 0.0);
   GlobalVariableSet(Strategy_StateKey("block_until"), (double)g_pattern_block_until);
   GlobalVariablesFlush();
  }

double Strategy_LoadStateValue(const string suffix, const double fallback)
  {
   const string key = Strategy_StateKey(suffix);
   if(!GlobalVariableCheck(key))
      return fallback;
   return GlobalVariableGet(key);
  }

void Strategy_LoadState()
  {
   Strategy_ResetMemoryState();
   g_setup_valid = (Strategy_LoadStateValue("setup", 0.0) > 0.5);
   g_lifecycle_phase = (int)MathRound(Strategy_LoadStateValue("phase", 0.0));
   g_setup_created_bar_time = (datetime)MathRound(Strategy_LoadStateValue("created", 0.0));
   g_setup_pole_start_time = (datetime)MathRound(Strategy_LoadStateValue("pole_start", 0.0));
   g_setup_pole_end_time = (datetime)MathRound(Strategy_LoadStateValue("pole_end", 0.0));
   g_active_upper_slope = Strategy_LoadStateValue("upper_slope", 0.0);
   g_active_upper_intercept = Strategy_LoadStateValue("upper_int", 0.0);
   g_active_upper_anchor_time = (datetime)MathRound(Strategy_LoadStateValue("upper_anchor", 0.0));
   g_tp1_done = (Strategy_LoadStateValue("tp1_done", 0.0) > 0.5);
   g_pattern_block_until = (datetime)MathRound(Strategy_LoadStateValue("block_until", 0.0));
   if(g_lifecycle_phase < STRATEGY_LIFECYCLE_NONE ||
      g_lifecycle_phase > STRATEGY_LIFECYCLE_POSITION)
      Strategy_ResetMemoryState();
  }

bool Strategy_InitIndicators()
  {
   g_h_atr_h1 = iATR(_Symbol, strategy_tf, strategy_atr_period);
   if(g_h_atr_h1 == INVALID_HANDLE)
     {
      PrintFormat("QM5_%d: failed to create ATR handle", qm_ea_id);
      return false;
     }
   if(strategy_macro_bias_enabled)
     {
      g_h_sma_h4 = iMA(_Symbol, PERIOD_H4, strategy_macro_sma_period, 0, MODE_SMA, PRICE_CLOSE);
      if(g_h_sma_h4 == INVALID_HANDLE)
        {
         PrintFormat("QM5_%d: failed to create H4 SMA handle", qm_ea_id);
         return false;
        }
     }
   return true;
  }

void Strategy_ReleaseIndicators()
  {
   if(g_h_atr_h1 != INVALID_HANDLE)
     {
      IndicatorRelease(g_h_atr_h1);
      g_h_atr_h1 = INVALID_HANDLE;
     }
   if(g_h_sma_h4 != INVALID_HANDLE)
     {
      IndicatorRelease(g_h_sma_h4);
      g_h_sma_h4 = INVALID_HANDLE;
     }
  }

bool Strategy_SelectOurPosition(ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      return true;
     }
   ticket = 0;
   return false;
  }

bool Strategy_SelectOurPendingOrder(ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = OrderGetTicket(i);
      if(candidate == 0 || !OrderSelect(candidate))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP)
         continue;
      ticket = candidate;
      return true;
     }
   ticket = 0;
   return false;
  }

bool Strategy_RemoveOurPendingOrders(const string reason)
  {
   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP)
         continue;
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return all_ok;
  }

void Strategy_ClearSetupState()
  {
   const datetime block_until = g_pattern_block_until;
   Strategy_ResetMemoryState();
   g_pattern_block_until = block_until;
   Strategy_PersistState();
  }

void Strategy_InvalidateSetup(const string reason)
  {
   Strategy_RemoveOurPendingOrders(reason);
   const datetime current_bar = iTime(_Symbol, strategy_tf, 0); // perf-allowed: fixed current-bar timestamp at one lifecycle transition.
   const datetime basis = (current_bar > 0) ? current_bar : TimeCurrent();
   g_pattern_block_until = basis +
      (long)MathMax(0, strategy_reuse_guard_bars) * Strategy_PeriodSeconds();
   Strategy_ClearSetupState();
   PrintFormat("QM5_%d: bull-flag setup invalidated: %s", qm_ea_id, reason);
  }

bool Strategy_ReuseGuardActive()
  {
   if(g_pattern_block_until > 0 && TimeCurrent() < g_pattern_block_until)
      return true;
   if(strategy_reuse_guard_bars <= 0)
      return false;
   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 30 * 24 * 60 * 60, now))
      return false;
   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0 ||
         HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol ||
         (int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic ||
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      const int bars_since = iBarShift(_Symbol, strategy_tf, deal_time, false); // perf-allowed: one bounded history-derived reuse check on the entry path.
      return (bars_since >= 0 && bars_since < strategy_reuse_guard_bars);
     }
   return false;
  }

bool Strategy_ReadAtr(double &atr)
  {
   atr = 0.0;
   if(g_h_atr_h1 == INVALID_HANDLE)
      return false;
   double values[1];
   const int copied = CopyBuffer(g_h_atr_h1, 0, 1, 1, values);
   if(copied < 1)
      return false;
   if(ArraySize(values) < 1)
      return false;
   atr = values[0];
   return (atr > 0.0 && MathIsValidNumber(atr));
  }

bool Strategy_SpreadAcceptable(const double atr)
  {
   if(!strategy_spread_filter_enabled)
      return true;
   if(atr <= 0.0)
      return false;
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   return (spread <= strategy_spread_max_atr * atr);
  }

bool Strategy_MacroBias()
  {
   if(!strategy_macro_bias_enabled)
      return true;
   if(g_h_sma_h4 == INVALID_HANDLE)
      return false;
   double sma_values[2];
   const int copied_sma = CopyBuffer(g_h_sma_h4, 0, 1, 2, sma_values);
   if(copied_sma < 2)
      return false;
   if(ArraySize(sma_values) < 2)
      return false;
   MqlRates h1_rates[];
   ArraySetAsSeries(h1_rates, true);
   const int copied_rates = CopyRates(_Symbol, strategy_tf, 1, 1, h1_rates); // perf-allowed: one closed strategy bar, entry path only.
   if(copied_rates < 1 || ArraySize(h1_rates) < 1)
      return false;
   // CopyBuffer stores older shift 2 at [0], newer shift 1 at [1].
   const bool sma_rising = (sma_values[1] >= sma_values[0]);
   const bool price_above = (h1_rates[0].close > sma_values[1]);
   return (sma_rising && price_above);
  }

bool Strategy_FitLinearRegression(const MqlRates &rates[],
                                  const int start_shift,
                                  const int count,
                                  double &out_slope)
  {
   out_slope = 0.0;
   const int rates_size = ArraySize(rates);
   if(count < 2 || start_shift < 0 || start_shift + count > rates_size)
      return false;
   double sum_x = 0.0, sum_y = 0.0, sum_xx = 0.0, sum_xy = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const int index = start_shift + count - 1 - i;
      if(index < 0 || index >= rates_size)
         return false;
      const double x = (double)i;
      const double y = rates[index].close;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }
   const double denominator = (double)count * sum_xx - sum_x * sum_x;
   if(MathAbs(denominator) < 1e-12)
      return false;
   out_slope = ((double)count * sum_xy - sum_x * sum_y) / denominator;
   return true;
  }

bool Strategy_FitPivotsLine(const StrategyPivot &pivots[],
                            const int ref_shift,
                            double &out_slope,
                            double &out_intercept)
  {
   out_slope = 0.0;
   out_intercept = 0.0;
   const int count = ArraySize(pivots);
   if(count < 2)
      return false;
   double sum_x = 0.0, sum_y = 0.0, sum_xx = 0.0, sum_xy = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double x = (double)(ref_shift - pivots[i].shift);
      const double y = pivots[i].price;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }
   const double denominator = (double)count * sum_xx - sum_x * sum_x;
   if(MathAbs(denominator) < 1e-12)
      return false;
   out_slope = ((double)count * sum_xy - sum_x * sum_y) / denominator;
   out_intercept = (sum_y - out_slope * sum_x) / (double)count;
   return true;
  }

void Strategy_FindFractals(const MqlRates &rates[],
                           const int start_shift,
                           const int count,
                           StrategyPivot &high_pivots[],
                           StrategyPivot &low_pivots[])
  {
   ArrayResize(high_pivots, 0);
   ArrayResize(low_pivots, 0);
   const int rates_size = ArraySize(rates);
   const int wing = MathMax(1, strategy_fractal_wing_bars);
   if(start_shift < 0 || count < 2 * wing + 1 || start_shift + count > rates_size)
      return;
   for(int shift = start_shift + count - 1 - wing;
       shift >= start_shift + wing; --shift)
     {
      if(shift - wing < 0 || shift + wing >= rates_size)
         continue;
      bool is_high = true;
      bool is_low = true;
      for(int side = 1; side <= wing; ++side)
        {
         if(rates[shift].high <= rates[shift - side].high ||
            rates[shift].high <= rates[shift + side].high)
            is_high = false;
         if(rates[shift].low >= rates[shift - side].low ||
            rates[shift].low >= rates[shift + side].low)
            is_low = false;
        }
      if(is_high)
        {
         const int size = ArraySize(high_pivots);
         ArrayResize(high_pivots, size + 1);
         high_pivots[size].shift = shift;
         high_pivots[size].price = rates[shift].high;
        }
      if(is_low)
        {
         const int size = ArraySize(low_pivots);
         ArrayResize(low_pivots, size + 1);
         low_pivots[size].shift = shift;
         low_pivots[size].price = rates[shift].low;
        }
     }
  }

bool Strategy_SetupMatchesActive(const datetime pole_start_time,
                                 const datetime pole_end_time)
  {
   if(!g_setup_valid)
      return true;
   return (pole_start_time == g_setup_pole_start_time &&
           pole_end_time == g_setup_pole_end_time);
  }

bool Strategy_FindSetup(StrategySetupCandidate &candidate)
  {
   ZeroMemory(candidate);
   if(strategy_pole_min_bars < 2 ||
      strategy_pole_max_bars < strategy_pole_min_bars ||
      strategy_flag_min_bars < 3 ||
      strategy_flag_max_bars < strategy_flag_min_bars ||
      strategy_pole_volume_prior_bars < 1)
      return false;
   double atr = 0.0;
   if(!Strategy_ReadAtr(atr) ||
      !Strategy_SpreadAcceptable(atr) ||
      !Strategy_MacroBias())
      return false;

   const int needed_bars = strategy_pole_max_bars + strategy_flag_max_bars +
                           strategy_pole_volume_prior_bars + 30;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, needed_bars, rates); // perf-allowed: bounded card lookback, entry path once per new strategy bar.
   const int rates_size = ArraySize(rates);
   if(copied < needed_bars || rates_size < needed_bars)
      return false;

   const int flag_start_shift = 1;
   for(int flag_bars = strategy_flag_min_bars;
       flag_bars <= strategy_flag_max_bars; ++flag_bars)
     {
      const int flag_end_shift = flag_start_shift + flag_bars - 1;
      const int pole_end_shift = flag_end_shift + 1;
      for(int pole_bars = strategy_pole_min_bars;
          pole_bars <= strategy_pole_max_bars; ++pole_bars)
        {
         const int pole_start_shift = pole_end_shift + pole_bars - 1;
         if(pole_start_shift + strategy_pole_volume_prior_bars >= rates_size)
            continue;
         const datetime pole_start_time = rates[pole_start_shift].time;
         const datetime pole_end_time = rates[pole_end_shift].time;
         if(!Strategy_SetupMatchesActive(pole_start_time, pole_end_time))
            continue;

         const double pole_move =
            rates[pole_end_shift].close - rates[pole_start_shift].close;
         if(pole_move < strategy_pole_min_atr * atr)
            continue;
         double pole_slope = 0.0;
         if(!Strategy_FitLinearRegression(rates, pole_end_shift,
                                          pole_bars, pole_slope) ||
            pole_slope / atr < strategy_pole_slope_min_atr)
            continue;

         int pullback_count = 0;
         double pole_high = rates[pole_end_shift].high;
         double pole_low = rates[pole_start_shift].low;
         for(int shift = pole_start_shift; shift >= pole_end_shift; --shift)
           {
            if(shift < pole_start_shift &&
               rates[shift].close < rates[shift + 1].close)
               ++pullback_count;
            if(rates[shift].high > pole_high)
               pole_high = rates[shift].high;
            if(rates[shift].low < pole_low)
               pole_low = rates[shift].low;
           }
         if((double)pullback_count / (double)pole_bars >
            strategy_pole_max_pullback_pct)
            continue;

         double mean_pole_volume = 0.0;
         if(strategy_volume_filter_enabled)
           {
            long pole_volume_sum = 0;
            for(int shift = pole_end_shift; shift <= pole_start_shift; ++shift)
               pole_volume_sum += rates[shift].tick_volume;
            mean_pole_volume = (double)pole_volume_sum / (double)pole_bars;
            long prior_volume_sum = 0;
            for(int offset = 1; offset <= strategy_pole_volume_prior_bars; ++offset)
               prior_volume_sum += rates[pole_start_shift + offset].tick_volume;
            const double mean_prior_volume =
               (double)prior_volume_sum / (double)strategy_pole_volume_prior_bars;
            if(mean_prior_volume > 0.0 &&
               mean_pole_volume < strategy_pole_volume_mult * mean_prior_volume)
               continue;
           }

         double flag_slope = 0.0;
         if(!Strategy_FitLinearRegression(rates, flag_start_shift,
                                          flag_bars, flag_slope))
            continue;
         const double flag_slope_atr = flag_slope / atr;
         if(flag_slope_atr < strategy_flag_slope_min_atr ||
            flag_slope_atr > strategy_flag_slope_max_atr)
            continue;

         double flag_low = rates[flag_start_shift].low;
         long flag_volume_sum = 0;
         for(int shift = flag_start_shift; shift <= flag_end_shift; ++shift)
           {
            if(rates[shift].low < flag_low)
               flag_low = rates[shift].low;
            flag_volume_sum += rates[shift].tick_volume;
           }
         const double pole_height = pole_high - pole_low;
         if(pole_height <= 0.0)
            continue;
         const double flag_retrace = (pole_high - flag_low) / pole_height;
         if(flag_retrace > strategy_flag_max_retrace_pct)
            continue;
         if(strategy_volume_filter_enabled && mean_pole_volume > 0.0)
           {
            const double mean_flag_volume =
               (double)flag_volume_sum / (double)flag_bars;
            if(mean_flag_volume >
               strategy_flag_volume_mult * mean_pole_volume)
               continue;
           }

         StrategyPivot high_pivots[];
         StrategyPivot low_pivots[];
         Strategy_FindFractals(rates, flag_start_shift, flag_bars,
                               high_pivots, low_pivots);
         // Card gate 6 is mandatory: no regression/window-boundary fallback.
         if(ArraySize(high_pivots) < 2 || ArraySize(low_pivots) < 2)
            continue;

         const int reference_shift = flag_end_shift;
         double upper_slope = 0.0, upper_intercept = 0.0;
         double lower_slope = 0.0, lower_intercept = 0.0;
         if(!Strategy_FitPivotsLine(high_pivots, reference_shift,
                                    upper_slope, upper_intercept) ||
            !Strategy_FitPivotsLine(low_pivots, reference_shift,
                                    lower_slope, lower_intercept))
            continue;
         const double slope_difference = MathAbs(upper_slope - lower_slope);
         const double slope_sum = MathAbs(upper_slope) + MathAbs(lower_slope);
         if(slope_difference > 0.30 * slope_sum)
            continue;

         int contained_closes = 0;
         for(int shift = flag_start_shift; shift <= flag_end_shift; ++shift)
           {
            const double x = (double)(reference_shift - shift);
            const double upper_line = upper_intercept + upper_slope * x;
            const double lower_line = lower_intercept + lower_slope * x;
            if(rates[shift].close <=
                  upper_line + strategy_flag_channel_tol_atr * atr &&
               rates[shift].close >=
                  lower_line - strategy_flag_channel_tol_atr * atr)
               ++contained_closes;
           }
         if((double)contained_closes / (double)flag_bars <
            strategy_flag_containment_pct)
            continue;

         const double current_x = (double)reference_shift;
         const double upper_now = upper_intercept + upper_slope * current_x;
         const double lower_now = lower_intercept + lower_slope * current_x;
         const double entry = Strategy_NormalizePrice(
            upper_now + strategy_breakout_buffer_atr * atr);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || entry <= ask)
            continue;
         double initial_sl = lower_now - strategy_sl_buffer_atr * atr;
         if(entry - initial_sl > strategy_sl_cap_atr * atr)
            initial_sl = entry - strategy_sl_cap_atr * atr;
         initial_sl = Strategy_NormalizePrice(initial_sl);
         const double full_tp =
            Strategy_NormalizePrice(entry + pole_height);
         if(initial_sl <= 0.0 || initial_sl >= entry || full_tp <= entry)
            continue;

         candidate.created_bar_time =
            g_setup_valid ? g_setup_created_bar_time : rates[0].time;
         candidate.pole_start_time = pole_start_time;
         candidate.pole_end_time = pole_end_time;
         candidate.upper_anchor_time = rates[reference_shift].time;
         candidate.upper_slope = upper_slope;
         candidate.upper_intercept = upper_intercept;
         candidate.entry_price = entry;
         candidate.initial_sl = initial_sl;
         candidate.full_tp = full_tp;
         return true;
        }
     }
   return false;
  }

bool Strategy_EntryNewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal == QM_NEWS_TEMPORAL_OFF &&
      qm_news_compliance == QM_NEWS_COMPLIANCE_NONE)
      return true;
   datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      utc_time = TimeGMT();
   if(utc_time <= 0)
      return false;
   // Card contract: entry-only blackout +/-3 H1 bars = 180/180 minutes.
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF &&
      QM_NewsInWindow(utc_time, _Symbol, 180, 180, qm_news_min_impact))
      return false;
   if(qm_news_compliance != QM_NEWS_COMPLIANCE_NONE &&
      !QM_NewsComplianceAllows(_Symbol, utc_time, qm_news_compliance))
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_candidate_ready = false;

   ulong position_ticket = 0;
   if(Strategy_SelectOurPosition(position_ticket))
      return false;
   if(g_lifecycle_phase == STRATEGY_LIFECYCLE_POSITION)
     {
      Strategy_ClearSetupState();
      return false;
     }
   if(!Strategy_EntryNewsAllows(TimeCurrent()))
      return false;

   ulong pending_ticket = 0;
   const bool has_pending = Strategy_SelectOurPendingOrder(pending_ticket);
   if(has_pending && !g_setup_valid)
     {
      Strategy_RemoveOurPendingOrders("orphan_pending_without_state");
      return false;
     }
   if(g_setup_valid)
     {
      const datetime expiry = g_setup_created_bar_time +
         (long)STRATEGY_PENDING_VALID_BARS * Strategy_PeriodSeconds();
      if(g_setup_created_bar_time <= 0 || TimeCurrent() >= expiry)
        {
         Strategy_InvalidateSetup("eight_bar_expiry");
         return false;
        }
     }
   else if(Strategy_ReuseGuardActive())
      return false;

   StrategySetupCandidate candidate;
   if(!Strategy_FindSetup(candidate))
     {
      if(g_setup_valid || has_pending)
         Strategy_InvalidateSetup("per_bar_revalidation_failed_or_flag_stale");
      return false;
     }
   if(has_pending &&
      !Strategy_RemoveOurPendingOrders("per_bar_reprice"))
      return false;

   const datetime expiry = candidate.created_bar_time +
      (long)STRATEGY_PENDING_VALID_BARS * Strategy_PeriodSeconds();
   const long seconds_remaining = (long)(expiry - TimeCurrent());
   if(seconds_remaining <= 0)
     {
      if(g_setup_valid)
         Strategy_InvalidateSetup("eight_bar_expiry");
      return false;
     }

   req.type = QM_BUY_STOP;
   req.price = candidate.entry_price;
   req.sl = candidate.initial_sl;
   req.tp = candidate.full_tp;
   req.reason = "BULL_FLAG_BUY_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   // The absolute lifetime is eight H1 bars, safely inside the int range.
   req.expiration_seconds = (int)seconds_remaining;
   g_candidate = candidate;
   g_candidate_ready = true;
   return true;
  }

void Strategy_CommitCandidateState()
  {
   if(!g_candidate_ready)
      return;
   g_setup_valid = true;
   g_lifecycle_phase = STRATEGY_LIFECYCLE_PENDING;
   g_setup_created_bar_time = g_candidate.created_bar_time;
   g_setup_pole_start_time = g_candidate.pole_start_time;
   g_setup_pole_end_time = g_candidate.pole_end_time;
   g_active_upper_slope = g_candidate.upper_slope;
   g_active_upper_intercept = g_candidate.upper_intercept;
   g_active_upper_anchor_time = g_candidate.upper_anchor_time;
   g_tp1_done = false;
   g_candidate_ready = false;
   Strategy_PersistState();
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return;
   const datetime position_time =
      (datetime)PositionGetInteger(POSITION_TIME);
   if(g_lifecycle_phase != STRATEGY_LIFECYCLE_POSITION)
     {
      g_lifecycle_phase = STRATEGY_LIFECYCLE_POSITION;
      const datetime cooldown_end = position_time +
         (long)MathMax(0, strategy_reuse_guard_bars) * Strategy_PeriodSeconds();
      if(cooldown_end > g_pattern_block_until)
         g_pattern_block_until = cooldown_end;
      Strategy_PersistState();
     }

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open_price <= 0.0 || current_price <= 0.0 || current_volume <= 0.0)
      return;
   if(!g_tp1_done && current_sl > 0.0 &&
      current_sl >= open_price - ((point > 0.0) ? point * 0.5 : 0.0))
     {
      g_tp1_done = true;
      Strategy_PersistState();
     }

   const double tp1_price = (current_tp > open_price)
      ? open_price + strategy_tp1_ratio * (current_tp - open_price)
      : 0.0;
   if(!g_tp1_done && tp1_price > open_price &&
      current_price >= tp1_price)
     {
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(min_lot <= 0.0 || lot_step <= 0.0)
         return;
      const double close_volume = QM_TM_NormalizeVolume(
         _Symbol, current_volume * strategy_tp1_close_fraction);
      if(close_volume >= min_lot &&
         current_volume - close_volume >= min_lot)
        {
         if(QM_TM_PartialClose(ticket, close_volume, QM_EXIT_PARTIAL))
           {
            g_tp1_done = true;
            Strategy_PersistState();
           }
        }
      else
        {
         g_tp1_done = true;
         Strategy_PersistState();
        }
     }

   if(g_tp1_done)
     {
      if(!PositionSelectByTicket(ticket))
         return;
      const double refreshed_sl = PositionGetDouble(POSITION_SL);
      if(refreshed_sl <= 0.0 || refreshed_sl < open_price)
         QM_TM_MoveSL(ticket, Strategy_NormalizePrice(open_price),
                      "bull_flag_tp1_break_even");
     }
  }

double Strategy_UpperLineAtShift(const int evaluation_shift)
  {
   if(!g_setup_valid || g_active_upper_anchor_time <= 0 ||
      !MathIsValidNumber(g_active_upper_slope) ||
      !MathIsValidNumber(g_active_upper_intercept))
      return 0.0;
   const int anchor_shift = iBarShift(
      _Symbol, strategy_tf, g_active_upper_anchor_time, false); // perf-allowed: persisted-anchor projection on one new-bar exit check.
   if(anchor_shift < evaluation_shift)
      return 0.0;
   return g_active_upper_intercept +
          g_active_upper_slope * (double)(anchor_shift - evaluation_shift);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;
   if(g_restart_state_missing)
     {
      PrintFormat("QM5_%d: fail-closed exit for missing restart state", qm_ea_id);
      return true;
     }
   const datetime position_time =
      (datetime)PositionGetInteger(POSITION_TIME);
   if(position_time <= 0)
      return false;
   const int bars_open = iBarShift(
      _Symbol, strategy_tf, position_time, false); // perf-allowed: position-age query on one new strategy bar.
   if(bars_open < 0)
      return false;

   if(bars_open >= 1 && bars_open <= strategy_failure_exit_bars)
     {
      const double upper_line = Strategy_UpperLineAtShift(1);
      MqlRates closed_bar[];
      ArraySetAsSeries(closed_bar, true);
      const int copied = CopyRates(_Symbol, strategy_tf, 1, 1, closed_bar); // perf-allowed: one closed bar on a new-bar exit check.
      if(upper_line > 0.0 && copied >= 1 &&
         ArraySize(closed_bar) >= 1 &&
         closed_bar[0].close < upper_line)
        {
         PrintFormat("QM5_%d: pattern failure (close %G < advancing line %G)",
                     qm_ea_id, closed_bar[0].close, upper_line);
         return true;
        }
     }
   if(bars_open >= strategy_time_stop_bars)
     {
      PrintFormat("QM5_%d: time stop after %d strategy bars",
                  qm_ea_id, bars_open);
      return true;
     }
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        180, 180,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   if(!Strategy_InitIndicators())
      return INIT_FAILED;

   g_state_prefix = StringFormat("QM5.1408.%I64d.%d.%s.",
                                 AccountInfoInteger(ACCOUNT_LOGIN),
                                 QM_FrameworkMagic(), _Symbol);
   Strategy_LoadState();
   ulong position_ticket = 0;
   ulong pending_ticket = 0;
   const bool has_position = Strategy_SelectOurPosition(position_ticket);
   const bool has_pending = Strategy_SelectOurPendingOrder(pending_ticket);
   if(!has_position && !has_pending)
     {
      const datetime pending_expiry = g_setup_created_bar_time +
         (long)STRATEGY_PENDING_VALID_BARS * Strategy_PeriodSeconds();
      if(g_setup_valid &&
         g_lifecycle_phase == STRATEGY_LIFECYCLE_PENDING &&
         g_setup_created_bar_time > 0 &&
         TimeCurrent() < pending_expiry)
        {
         // A news blackout may deliberately leave the setup disarmed. Keep
         // its durable geometry so the next H1 bar can revalidate/reprice it.
         Strategy_PersistState();
        }
      else
        {
         const datetime maximum_valid_block = TimeCurrent() +
            (long)MathMax(0, strategy_reuse_guard_bars) * Strategy_PeriodSeconds();
         if(g_pattern_block_until > maximum_valid_block)
            g_pattern_block_until = 0;
         Strategy_ClearSetupState();
        }
     }
   else if(has_pending && !g_setup_valid)
     {
      // Fail closed: an orphan order cannot be repriced after restart.
      Strategy_RemoveOurPendingOrders("restart_orphan_pending");
     }
   else if(has_position && !g_setup_valid)
     {
      // Durable geometry should exist for every filled strategy order. If
      // terminal globals were externally removed, close fail-closed rather
      // than silently disabling the six-bar pattern-failure protection.
      g_restart_state_missing = true;
      g_lifecycle_phase = STRATEGY_LIFECYCLE_POSITION;
      PrintFormat("QM5_%d: managed position has no durable setup state; fail-closed exit armed",
                  qm_ea_id);
     }
   else if(has_position &&
           g_lifecycle_phase != STRATEGY_LIFECYCLE_POSITION)
     {
      g_lifecycle_phase = STRATEGY_LIFECYCLE_POSITION;
      Strategy_PersistState();
     }
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   Strategy_PersistState();
   Strategy_ReleaseIndicators();
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   const bool is_new_strategy_bar =
      QM_IsNewBar(_Symbol, strategy_tf);

   // Protective management and exits precede the entry-only news block.
   Strategy_ManageOpenPosition();
   if(is_new_strategy_bar && Strategy_ExitSignal())
     {
      ulong ticket = 0;
      if(Strategy_SelectOurPosition(ticket) &&
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
         Strategy_PersistState();
      return;
     }

   const datetime broker_now = TimeCurrent();
   if(!Strategy_EntryNewsAllows(broker_now))
     {
      // A resting BUY_STOP is entry exposure; cancel it during blackout.
      Strategy_RemoveOurPendingOrders("entry_news_blackout");
      return;
     }
   if(!is_new_strategy_bar)
      return;
   QM_EquityStreamOnNewBar();
   if(Strategy_NoTradeFilter())
      return;

   QM_EntryRequest request;
   request.type = QM_BUY_STOP;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;
   if(Strategy_EntrySignal(request))
     {
      ulong order_ticket = 0;
      if(QM_TM_OpenPosition(request, order_ticket))
         Strategy_CommitCandidateState();
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(transaction, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
