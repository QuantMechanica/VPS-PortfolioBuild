#property strict
#property version   "5.0"
#property description "QM5_1425 Classical Triple Bottom Reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1425
// Classical Triple Bottom Reversal (H4)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1425_classical-triple-bottom-reversal-h4.md
// Edwards & Magee Technical Analysis of Stock Trends 10th ed. Ch. 7 / Bulkowski Ch. 81
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1425;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf                    = PERIOD_H4;
input int    strategy_atr_period                     = 14;
input int    strategy_fractal_wing_bars              = 1;
input int    strategy_lookback_min_bars              = 60;
input int    strategy_lookback_max_bars              = 200;
input int    strategy_trough_spacing_min_bars        = 25;
input int    strategy_trough_spacing_max_bars        = 120;
input double strategy_trough_depth_atr               = 0.50;
input double strategy_trough_equal_atr               = 0.50;
input double strategy_peak_amplitude_min_atr         = 1.50;
input double strategy_peak_equal_atr                 = 0.40;
input double strategy_neckline_slope_max_atr         = 0.05;
input int    strategy_downtrend_lookback_bars        = 40;
input double strategy_downtrend_slope_max_atr        = -0.10;
input double strategy_prior_break_filter_atr         = 0.30;
input double strategy_breakout_buffer_atr            = 0.40;
input int    strategy_breakout_recency_bars          = 12;
input double strategy_tp1_close_fraction             = 0.50;
input double strategy_tp1_ratio                      = 0.50;
input int    strategy_failure_exit_bars              = 8;
input double strategy_failure_exit_buffer_atr        = 0.30;
input int    strategy_time_stop_bars                 = 30;
input double strategy_sl_buffer_atr                  = 0.40;
input double strategy_sl_cap_atr                     = 4.00;
input bool   strategy_macro_bias_enabled             = true;
input int    strategy_macro_sma_period               = 50;
input int    strategy_reuse_guard_bars               = 40;
input bool   strategy_spread_filter_enabled          = true;
input double strategy_spread_max_atr                 = 0.20;

const int STRATEGY_TROUGH_CONTEXT_BARS = 20;
const int STRATEGY_NEWS_WINDOW_BARS    = 2;
const int STRATEGY_MAX_FETCH_BARS      = 2048;

bool     g_active_setup_valid   = false;
bool     g_pending_setup_valid  = false;
double   g_active_tp1_price     = 0.0;
bool     g_tp1_done             = false;
double   g_active_neckline      = 0.0;
double   g_invalidation_price   = 0.0;
datetime g_pattern_block_until  = 0;

bool     g_candidate_setup_valid = false;
double   g_candidate_tp1_price   = 0.0;
double   g_candidate_neckline    = 0.0;
double   g_candidate_invalidation_price = 0.0;

struct StrategyPivot
{
   int      shift;
   datetime time;
   double   price;
};

double Strategy_NormalizePrice(const double price)
{
   return QM_StopRulesNormalizePrice(_Symbol, price);
}

bool Strategy_ValidateInputs()
{
   const int fetch_bars = strategy_lookback_max_bars
                          + strategy_downtrend_lookback_bars
                          + STRATEGY_TROUGH_CONTEXT_BARS + 8;
   return (strategy_tf == PERIOD_H4
           && strategy_atr_period > 1
           && strategy_fractal_wing_bars >= 1
           && strategy_lookback_min_bars >= 3
           && strategy_lookback_max_bars >= strategy_lookback_min_bars
           && strategy_trough_spacing_min_bars >= 1
           && strategy_trough_spacing_max_bars >= strategy_trough_spacing_min_bars
           && strategy_trough_depth_atr > 0.0
           && strategy_trough_equal_atr >= 0.0
           && strategy_peak_amplitude_min_atr > 0.0
           && strategy_peak_equal_atr >= 0.0
           && strategy_neckline_slope_max_atr >= 0.0
           && strategy_downtrend_lookback_bars >= 2
           && strategy_downtrend_slope_max_atr <= 0.0
           && strategy_prior_break_filter_atr >= 0.0
           && strategy_breakout_buffer_atr > 0.0
           && strategy_breakout_recency_bars > 0
           && strategy_tp1_close_fraction > 0.0
           && strategy_tp1_close_fraction < 1.0
           && strategy_tp1_ratio > 0.0
           && strategy_tp1_ratio < 1.0
           && strategy_failure_exit_bars >= 0
           && strategy_failure_exit_buffer_atr >= 0.0
           && strategy_time_stop_bars > 0
           && strategy_sl_buffer_atr > 0.0
           && strategy_sl_cap_atr > 0.0
           && (!strategy_macro_bias_enabled || strategy_macro_sma_period > 1)
           && strategy_reuse_guard_bars >= 0
           && (!strategy_spread_filter_enabled || strategy_spread_max_atr > 0.0)
           && fetch_bars <= STRATEGY_MAX_FETCH_BARS);
}

string Strategy_StateKey(const string field)
{
   return StringFormat("QM5.%d.%d.%s", qm_ea_id, QM_FrameworkMagic(), field);
}

void Strategy_DeleteSetupState()
{
   GlobalVariableDel(Strategy_StateKey("state"));
   GlobalVariableDel(Strategy_StateKey("neck"));
   GlobalVariableDel(Strategy_StateKey("tp1"));
   GlobalVariableDel(Strategy_StateKey("invalid"));
   GlobalVariableDel(Strategy_StateKey("tp1done"));
   g_active_setup_valid = false;
   g_pending_setup_valid = false;
   g_active_neckline = 0.0;
   g_active_tp1_price = 0.0;
   g_invalidation_price = 0.0;
   g_tp1_done = false;
}

void Strategy_PersistSetup(const int state)
{
   GlobalVariableSet(Strategy_StateKey("state"), (double)state);
   GlobalVariableSet(Strategy_StateKey("neck"), g_active_neckline);
   GlobalVariableSet(Strategy_StateKey("tp1"), g_active_tp1_price);
   GlobalVariableSet(Strategy_StateKey("invalid"), g_invalidation_price);
   GlobalVariableSet(Strategy_StateKey("tp1done"), g_tp1_done ? 1.0 : 0.0);
}

void Strategy_PersistBlockUntil()
{
   if(g_pattern_block_until > 0)
      GlobalVariableSet(Strategy_StateKey("block"), (double)g_pattern_block_until);
   else
      GlobalVariableDel(Strategy_StateKey("block"));
}

bool Strategy_LoadPersistedSetup()
{
   const string state_key = Strategy_StateKey("state");
   if(!GlobalVariableCheck(state_key)
      || !GlobalVariableCheck(Strategy_StateKey("neck"))
      || !GlobalVariableCheck(Strategy_StateKey("tp1"))
      || !GlobalVariableCheck(Strategy_StateKey("invalid")))
      return false;

   const int state = (int)GlobalVariableGet(state_key);
   if(state != 1 && state != 2)
      return false;

   g_active_neckline = GlobalVariableGet(Strategy_StateKey("neck"));
   g_active_tp1_price = GlobalVariableGet(Strategy_StateKey("tp1"));
   g_invalidation_price = GlobalVariableGet(Strategy_StateKey("invalid"));
   g_tp1_done = (GlobalVariableCheck(Strategy_StateKey("tp1done"))
                 && GlobalVariableGet(Strategy_StateKey("tp1done")) > 0.5);
   g_pending_setup_valid = (state == 1);
   g_active_setup_valid = (state == 2);
   return (g_active_neckline > 0.0
           && g_active_tp1_price > 0.0
           && g_invalidation_price > 0.0);
}

void Strategy_LoadPersistedBlockUntil()
{
   const string key = Strategy_StateKey("block");
   g_pattern_block_until = GlobalVariableCheck(key)
                           ? (datetime)GlobalVariableGet(key) : 0;
   if(g_pattern_block_until > 0 && TimeCurrent() >= g_pattern_block_until)
   {
      g_pattern_block_until = 0;
      GlobalVariableDel(key);
   }
}

bool Strategy_SelectOurPosition(ulong &ticket)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong cand = PositionGetTicket(i);
      if(cand == 0 || !PositionSelectByTicket(cand)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ticket = cand;
      return true;
   }
   return false;
}

bool Strategy_SelectOurPendingOrder(ulong &ticket)
{
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong cand = OrderGetTicket(i);
      if(cand == 0 || !OrderSelect(cand)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic) continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP) continue;
      ticket = cand;
      return true;
   }
   return false;
}

void Strategy_ActivateFilledSetup(const ulong position_ticket)
{
   if(position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      return;

   g_pending_setup_valid = false;
   g_active_setup_valid = true;
   const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int tf_seconds = PeriodSeconds(strategy_tf);
   if(strategy_reuse_guard_bars > 0 && tf_seconds > 0)
      g_pattern_block_until = entry_time + strategy_reuse_guard_bars * tf_seconds;
   Strategy_PersistSetup(2);
   Strategy_PersistBlockUntil();
}

bool Strategy_RestoreExecutionState()
{
   Strategy_LoadPersistedBlockUntil();

   ulong position_ticket = 0;
   ulong pending_ticket = 0;
   const bool has_position = Strategy_SelectOurPosition(position_ticket);
   const bool has_pending = Strategy_SelectOurPendingOrder(pending_ticket);
   if(!has_position && !has_pending)
   {
      Strategy_DeleteSetupState();
      return true;
   }

   if(!Strategy_LoadPersistedSetup())
   {
      QM_LogEvent(QM_ERROR, "EA_SETUP_STATE_MISSING",
                  StringFormat("{\"position\":%s,\"pending\":%s}",
                               has_position ? "true" : "false",
                               has_pending ? "true" : "false"));
      return false;
   }

   if(has_position)
      Strategy_ActivateFilledSetup(position_ticket);
   else
   {
      g_pending_setup_valid = true;
      g_active_setup_valid = false;
      Strategy_PersistSetup(1);
   }
   return true;
}

void Strategy_SyncExecutionState()
{
   ulong position_ticket = 0;
   if(Strategy_SelectOurPosition(position_ticket))
   {
      if(!g_active_setup_valid && Strategy_LoadPersistedSetup())
         Strategy_ActivateFilledSetup(position_ticket);
      return;
   }

   ulong pending_ticket = 0;
   if(Strategy_SelectOurPendingOrder(pending_ticket))
   {
      if(!g_pending_setup_valid)
         Strategy_LoadPersistedSetup();
      g_pending_setup_valid = true;
      g_active_setup_valid = false;
      return;
   }

   if(g_active_setup_valid || g_pending_setup_valid)
      Strategy_DeleteSetupState();
}

bool Strategy_ReuseGuardActive()
{
   if(g_pattern_block_until > 0 && TimeCurrent() < g_pattern_block_until)
      return true;

   if(strategy_reuse_guard_bars <= 0) return false;

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 60 * 24 * 60 * 60, now)) return false;

   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   datetime last_deal_time = 0;
   for(int i = total - 1; i >= 0; --i)
   {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
      {
         const datetime dtime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(dtime > last_deal_time) last_deal_time = dtime;
         break;
      }
   }
   if(last_deal_time > 0)
   {
      const int bars_since = iBarShift(_Symbol, strategy_tf, last_deal_time, false); // perf-allowed: one bounded history lookup
      if(bars_since >= 0 && bars_since < strategy_reuse_guard_bars)
         return true;
   }
   return false;
}

bool Strategy_SpreadAcceptable(const double atr)
{
   if(!strategy_spread_filter_enabled) return true;
   if(atr <= 0.0) return false;
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   return (spread <= strategy_spread_max_atr * atr);
}

bool Strategy_MacroBias()
{
   if(!strategy_macro_bias_enabled) return true;
   const double sma_newer = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1, PRICE_CLOSE);
   const double sma_older = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 2, PRICE_CLOSE);
   if(sma_newer == EMPTY_VALUE || sma_older == EMPTY_VALUE
      || sma_newer <= 0.0 || sma_older <= 0.0)
      return false;

   // D1 SMA(50) flat or rising at the entry bar: shift 1 >= shift 2.
   return (sma_newer >= sma_older);
}

bool Strategy_FitLinearRegression(const MqlRates &rates[], const int start_shift, const int count, double &out_slope)
{
   out_slope = 0.0;
   if(count < 2 || start_shift < 0 || start_shift + count > ArraySize(rates))
      return false;

   double sum_x = 0.0, sum_y = 0.0, sum_xx = 0.0, sum_xy = 0.0;
   for(int i = 0; i < count; ++i)
   {
      const int idx = start_shift + count - 1 - i;
      const double y = rates[idx].close;
      const double x = (double)i;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
   }
   const double denom = (double)count * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12) return false;
   out_slope = ((double)count * sum_xy - sum_x * sum_y) / denom;
   return true;
}

bool Strategy_IsSignificantTrough(const MqlRates &rates[],
                                  const int pivot_shift,
                                  const double atr)
{
   const int half_window = STRATEGY_TROUGH_CONTEXT_BARS / 2;
   const int rates_size = ArraySize(rates);
   if(atr <= 0.0 || half_window < 1
      || pivot_shift - half_window < 1
      || pivot_shift + half_window >= rates_size)
      return false;

   double surrounding_low = DBL_MAX;
   int surrounding_count = 0;
   for(int s = pivot_shift - half_window; s <= pivot_shift + half_window; ++s)
   {
      if(s == pivot_shift) continue;
      surrounding_low = MathMin(surrounding_low, rates[s].low);
      surrounding_count++;
   }
   return (surrounding_count == STRATEGY_TROUGH_CONTEXT_BARS
           && rates[pivot_shift].low
              <= surrounding_low - strategy_trough_depth_atr * atr);
}

bool Strategy_FindFractals(const MqlRates &rates[],
                           const int start_shift,
                           const int count,
                           const double atr,
                           StrategyPivot &high_pivots[],
                           StrategyPivot &low_pivots[])
{
   ArrayResize(high_pivots, 0);
   ArrayResize(low_pivots, 0);

   const int w = strategy_fractal_wing_bars;
   const int rates_size = ArraySize(rates);
   if(w < 1 || start_shift < 1 || count < 2 * w + 1
      || start_shift + count > rates_size)
      return false;

   // Series shifts increase into the past. Ascending shifts make both pivot
   // arrays deterministic newest-to-oldest, matching the T3/T2/T1 search.
   for(int s = start_shift + w; s <= start_shift + count - 1 - w; ++s)
   {
      // High pivot
      bool is_high = true;
      for(int k = 1; k <= w; ++k)
      {
         if(rates[s].high <= rates[s - k].high || rates[s].high <= rates[s + k].high)
         {
            is_high = false;
            break;
         }
      }
      if(is_high)
      {
         const int sz = ArraySize(high_pivots);
         ArrayResize(high_pivots, sz + 1);
         high_pivots[sz].shift = s;
         high_pivots[sz].time  = rates[s].time;
         high_pivots[sz].price = rates[s].high;
      }

      // Low pivot
      bool is_low = true;
      for(int k = 1; k <= w; ++k)
      {
         if(rates[s].low >= rates[s - k].low || rates[s].low >= rates[s + k].low)
         {
            is_low = false;
            break;
         }
      }
      if(is_low && Strategy_IsSignificantTrough(rates, s, atr))
      {
         const int sz = ArraySize(low_pivots);
         ArrayResize(low_pivots, sz + 1);
         low_pivots[sz].shift = s;
         low_pivots[sz].time  = rates[s].time;
         low_pivots[sz].price = rates[s].low;
      }
   }
   return true;
}

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   g_candidate_setup_valid = false;

   ulong existing_ticket = 0;
   if(Strategy_SelectOurPosition(existing_ticket))
      return false;
   if(Strategy_SelectOurPendingOrder(existing_ticket))
      return false;

   if(Strategy_ReuseGuardActive())
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr == EMPTY_VALUE || atr <= 0.0)
      return false;

   if(!Strategy_SpreadAcceptable(atr))
      return false;

   if(!Strategy_MacroBias())
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int fetch_bars = strategy_lookback_max_bars
                          + strategy_downtrend_lookback_bars
                          + STRATEGY_TROUGH_CONTEXT_BARS + 8;
   const int copied = CopyRates(_Symbol, strategy_tf, 0, fetch_bars, rates); // perf-allowed: bounded closed-bar structural window
   if(copied != fetch_bars || ArraySize(rates) < fetch_bars)
      return false;

   // Closed bars analysis starting from shift 1
   StrategyPivot highs[], lows[];
   if(!Strategy_FindFractals(rates, 1, strategy_lookback_max_bars,
                             atr, highs, lows))
      return false;

   const int n_lows = ArraySize(lows);
   const int n_highs = ArraySize(highs);
   if(n_lows < 3 || n_highs < 2)
      return false;

   // Significant lows are newest-to-oldest. Consecutive array elements are
   // therefore the card's three consecutive troughs T3, T2, T1.
   for(int i3 = 0; i3 < n_lows - 2; ++i3)
   {
      const int i2 = i3 + 1;
      const int i1 = i3 + 2;
      const int s_t3 = lows[i3].shift;
      const double p_t3 = lows[i3].price;
      const int s_t2 = lows[i2].shift;
      const double p_t2 = lows[i2].price;
      const int s_t1 = lows[i1].shift;
      const double p_t1 = lows[i1].price;

      if(!(s_t3 < s_t2 && s_t2 < s_t1))
         continue;

      // The oldest trough must sit inside the card's [60, 200] detector window.
      if(s_t1 < strategy_lookback_min_bars || s_t1 > strategy_lookback_max_bars)
         continue;

      // Gate 1: pairwise trough spacing in [25, 120] H4 bars.
      const int spacing = s_t1 - s_t3;
      if(spacing < strategy_trough_spacing_min_bars
         || spacing > strategy_trough_spacing_max_bars)
         continue;

      // Gate 2: all three significant troughs lie within half an ATR.
      const double max_t = MathMax(p_t1, MathMax(p_t2, p_t3));
      const double min_t = MathMin(p_t1, MathMin(p_t2, p_t3));
      if((max_t - min_t) > strategy_trough_equal_atr * atr)
         continue;

      // Gate 3: exactly one Williams pivot high in each trough interval.
      int p12_count = 0;
      int p23_count = 0;
      double p12_price = 0.0;
      double p23_price = 0.0;
      int p12_shift = -1;
      int p23_shift = -1;
      for(int h = 0; h < n_highs; ++h)
      {
         if(highs[h].shift > s_t2 && highs[h].shift < s_t1)
         {
            p12_count++;
            p12_price = highs[h].price;
            p12_shift = highs[h].shift;
         }
         else if(highs[h].shift > s_t3 && highs[h].shift < s_t2)
         {
            p23_count++;
            p23_price = highs[h].price;
            p23_shift = highs[h].shift;
         }
      }
      if(p12_count != 1 || p23_count != 1)
         continue;

      const double min_p = MathMin(p12_price, p23_price);
      if((min_p - max_t) < strategy_peak_amplitude_min_atr * atr)
         continue;
      if(MathAbs(p12_price - p23_price) > strategy_peak_equal_atr * atr)
         continue;

      // Gate 4: near-horizontal neckline through the two peaks.
      const double neckline = (p12_price + p23_price) / 2.0;
      const double peak_slope = MathAbs(p23_price - p12_price)
                                / (double)MathMax(1, p12_shift - p23_shift);
      if(peak_slope > strategy_neckline_slope_max_atr * atr)
         continue;

      // Gate 5: forty bars ending at T1 must have the card's down slope.
      double dt_slope = 0.0;
      if(!Strategy_FitLinearRegression(rates, s_t1,
                                       strategy_downtrend_lookback_bars,
                                       dt_slope)
         || dt_slope > strategy_downtrend_slope_max_atr * atr)
         continue;

      // Gate 6: no closed H4 bar has already crossed the neckline guard.
      bool prior_break = false;
      for(int s = s_t3 - 1; s >= 1; --s)
      {
         if(rates[s].close > neckline + strategy_prior_break_filter_atr * atr)
         {
            prior_break = true;
            break;
         }
      }
      if(prior_break)
         continue;

      const double invalidation_price = min_t - strategy_prior_break_filter_atr * atr;
      bool invalidated = false;
      for(int s = s_t3 - 1; s >= 1; --s)
      {
         if(rates[s].low < invalidation_price)
         {
            invalidated = true;
            break;
         }
      }
      if(invalidated)
         continue;

      const double mean_t = (p_t1 + p_t2 + p_t3) / 3.0;
      const double amplitude = neckline - mean_t;
      const double entry_price = Strategy_NormalizePrice(
         neckline + strategy_breakout_buffer_atr * atr);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double trough_sl = min_t - strategy_sl_buffer_atr * atr;
      const double capped_sl = entry_price - strategy_sl_cap_atr * atr;
      const double sl = Strategy_NormalizePrice(MathMax(trough_sl, capped_sl));
      const double tp = Strategy_NormalizePrice(entry_price + amplitude);
      const int tf_seconds = PeriodSeconds(strategy_tf);

      if(entry_price <= ask || sl >= entry_price || tp <= entry_price
         || tf_seconds <= 0)
         continue;

      req.type = QM_BUY_STOP;
      req.price = entry_price;
      req.sl = sl;
      req.tp = tp;
      req.reason = "QM5_1425_TB_BUYSTOP";
      req.symbol_slot = 0;
      req.expiration_seconds = strategy_breakout_recency_bars * tf_seconds;

      g_candidate_setup_valid = true;
      g_candidate_neckline = neckline;
      g_candidate_tp1_price = Strategy_NormalizePrice(
         entry_price + amplitude * strategy_tp1_ratio);
      g_candidate_invalidation_price = invalidation_price;
      return true;
   }

   return false;
}

void Strategy_CommitAcceptedSetup()
{
   if(!g_candidate_setup_valid)
      return;

   g_active_neckline = g_candidate_neckline;
   g_active_tp1_price = g_candidate_tp1_price;
   g_invalidation_price = g_candidate_invalidation_price;
   g_tp1_done = false;
   g_pending_setup_valid = true;
   g_active_setup_valid = false;
   Strategy_PersistSetup(1);
   g_candidate_setup_valid = false;
}

void Strategy_ManagePendingOrder()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPendingOrder(ticket))
      return;
   if(!g_pending_setup_valid && !Strategy_LoadPersistedSetup())
      return;

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, strategy_tf, 1, closed_bar))
      return;
   if(closed_bar.low >= g_invalidation_price)
      return;

   if(QM_TM_RemovePendingOrder(ticket, "QM5_1425_PATTERN_INVALIDATED"))
   {
      const int tf_seconds = PeriodSeconds(strategy_tf);
      if(strategy_reuse_guard_bars > 0 && tf_seconds > 0)
         g_pattern_block_until = TimeCurrent() + strategy_reuse_guard_bars * tf_seconds;
      Strategy_DeleteSetupState();
      Strategy_PersistBlockUntil();
   }
}

void Strategy_ManageOpenPosition()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return;

   if(!g_active_setup_valid)
      return;

   const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);

   // Partial close at TP1 (50% measured move) + Move SL to BE
   if(!g_tp1_done && g_active_tp1_price > 0.0 && current_price >= g_active_tp1_price)
   {
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(min_lot <= 0.0 || step_lot <= 0.0)
         return;
      double close_vol = MathFloor((volume * strategy_tp1_close_fraction) / step_lot) * step_lot;
      if(close_vol >= min_lot && (volume - close_vol) >= min_lot)
      {
         if(!QM_TM_PartialClose(ticket, close_vol, QM_EXIT_STRATEGY))
            return;
         g_tp1_done = true;
         Strategy_PersistSetup(2);

         // Move SL to open price (break-even) only after the partial succeeded.
         const double be_sl = Strategy_NormalizePrice(open_price);
         if(be_sl > current_sl)
            QM_TM_MoveSL(ticket, be_sl, "QM5_1425_BE");
      }
   }
}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_open = iBarShift(_Symbol, strategy_tf, open_time, false); // perf-allowed: one bounded position-age lookup
   if(bars_open < 0)
      return false;

   // 1. Time-stop: 30 H4 bars
   if(bars_open >= strategy_time_stop_bars)
      return true;

   // 2. Pattern-failure hard exit: if H4 close < neckline - 0.3 * ATR within first 8 bars
   if(bars_open <= strategy_failure_exit_bars && g_active_setup_valid)
   {
      const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
      if(atr != EMPTY_VALUE && atr > 0.0)
      {
         MqlRates closed_bar;
         if(QM_ReadBar(_Symbol, strategy_tf, 1, closed_bar)
            && closed_bar.close
               < g_active_neckline - strategy_failure_exit_buffer_atr * atr)
            return true;
      }
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

bool Strategy_EntryNewsAllows(const datetime broker_time)
{
   const int tf_seconds = PeriodSeconds(strategy_tf);
   if(broker_time <= 0 || tf_seconds <= 0)
      return false;
   const int window_minutes = (STRATEGY_NEWS_WINDOW_BARS * tf_seconds) / 60;
   if(window_minutes != 480)
      return false;

   if(!MQLInfoInteger(MQL_TESTER))
   {
      QM_NewsLiveSelfTest(_Symbol);
      bool calendar_ok = true;
      const bool in_window = QM_NewsLiveInWindow(
         _Symbol, broker_time, window_minutes, window_minutes, calendar_ok);
      return (calendar_ok && !in_window);
   }

   if(!g_qm_news_loaded
      && !QM_NewsInit("D:\\QM\\data\\news_calendar",
                      qm_news_stale_max_hours,
                      window_minutes,
                      window_minutes,
                      qm_news_min_impact))
      return false;
   if(!g_qm_news_available)
      return false;

   const datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      return false;
   // Keep the governed literal visible to D15 as well as to the runtime.
   return !QM_NewsInWindow(utc_time, _Symbol, 480, 480, "HIGH");
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   const int news_window_minutes =
      (STRATEGY_NEWS_WINDOW_BARS * PeriodSeconds(strategy_tf)) / 60;
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                         qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                         news_window_minutes, news_window_minutes,
                         qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                         qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H4,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   if(!Strategy_ValidateInputs())
   {
      QM_LogEvent(QM_ERROR, "EA_INPUT_STRATEGY_INVALID", "{}");
      return INIT_FAILED;
   }

   if(!Strategy_RestoreExecutionState())
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1425\"}");
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
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_SyncExecutionState();
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar(_Symbol, strategy_tf)) return;
   QM_EquityStreamOnNewBar();
   Strategy_ManagePendingOrder();

   // Both framework axes and the card's exact +/- two-H4-bar window gate
   // new entries only; open-position management and exits above never pause.
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !Strategy_EntryNewsAllows(broker_now)) return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         Strategy_CommitAcceptedSetup();
      else
         g_candidate_setup_valid = false;
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
   Strategy_SyncExecutionState();
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}

