#property strict
#property version   "5.0"
#property description "QM5_1417 Classical Pennant Continuation H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1417
// Classical Pennant Continuation (H1)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1417_classical-pennant-continuation-h1.md
// Edwards & Magee Technical Analysis of Stock Trends 10th ed. Ch. 9
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1417;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

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
input int    strategy_penn_min_bars                  = 5;
input int    strategy_penn_max_bars                  = 15;
input double strategy_penn_slope_symmetry_max        = 0.40;
input double strategy_penn_range_min_atr             = 1.50;
input double strategy_penn_range_max_atr             = 4.00;
input double strategy_penn_apex_dist_min             = 0.20;
input double strategy_penn_apex_dist_max             = 0.80;
input double strategy_penn_max_retrace_pct           = 0.50;
input double strategy_penn_volume_mult               = 0.75;
input double strategy_breakout_buffer_atr            = 0.40;
input double strategy_tp1_close_fraction             = 0.50;
input double strategy_tp1_ratio                      = 0.50;
input int    strategy_failure_exit_bars              = 5;
input int    strategy_time_stop_bars                 = 18;
input double strategy_sl_buffer_atr                  = 0.30;
input double strategy_sl_cap_atr                     = 2.00;
input bool   strategy_macro_bias_enabled             = true;
input int    strategy_macro_sma_period               = 200;
input int    strategy_reuse_guard_bars               = 10;
input bool   strategy_spread_filter_enabled          = true;
input double strategy_spread_max_atr                 = 0.25;

int      g_h_atr_h1 = INVALID_HANDLE;
int      g_h_sma_h4 = INVALID_HANDLE;

const int STRATEGY_PENDING_VALID_BARS = 6;

bool     g_active_setup_valid = false;
double   g_active_tp1_price = 0.0;
bool     g_tp1_done = false;
double   g_active_upper_slope = 0.0;
double   g_active_upper_intercept = 0.0;
double   g_active_lower_slope = 0.0;
double   g_active_lower_intercept = 0.0;
double   g_active_line_x_at_setup = 0.0;
datetime g_active_setup_bar_time = 0;
datetime g_active_entry_time = 0;
datetime g_pattern_block_until = 0;

bool     g_candidate_setup_valid = false;
double   g_candidate_tp1_price = 0.0;
double   g_candidate_upper_slope = 0.0;
double   g_candidate_upper_intercept = 0.0;
double   g_candidate_lower_slope = 0.0;
double   g_candidate_lower_intercept = 0.0;
double   g_candidate_line_x_at_setup = 0.0;
datetime g_candidate_setup_bar_time = 0;

struct StrategyPivot
{
   int    shift;
   double price;
};

double Strategy_NormalizePrice(const double price)
{
   return QM_StopRulesNormalizePrice(_Symbol, price);
}

bool Strategy_InitIndicators()
{
   g_h_atr_h1 = iATR(_Symbol, strategy_tf, strategy_atr_period);
   if(g_h_atr_h1 == INVALID_HANDLE)
   {
      PrintFormat("QM5_%d: failed to create H1 ATR handle", qm_ea_id);
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
   if(g_h_atr_h1 != INVALID_HANDLE) { IndicatorRelease(g_h_atr_h1); g_h_atr_h1 = INVALID_HANDLE; }
   if(g_h_sma_h4 != INVALID_HANDLE) { IndicatorRelease(g_h_sma_h4); g_h_sma_h4 = INVALID_HANDLE; }
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
      if(cand == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic) continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      ticket = cand;
      return true;
   }
   return false;
}

void Strategy_ClearActiveSetup()
{
   g_active_setup_valid = false;
   g_active_tp1_price = 0.0;
   g_tp1_done = false;
   g_active_upper_slope = 0.0;
   g_active_upper_intercept = 0.0;
   g_active_lower_slope = 0.0;
   g_active_lower_intercept = 0.0;
   g_active_line_x_at_setup = 0.0;
   g_active_setup_bar_time = 0;
   g_active_entry_time = 0;
}

void Strategy_StageCandidateSetup(const double tp1_price,
                                  const double upper_slope,
                                  const double upper_intercept,
                                  const double lower_slope,
                                  const double lower_intercept,
                                  const double line_x_at_setup,
                                  const datetime setup_bar_time)
{
   g_candidate_setup_valid = true;
   g_candidate_tp1_price = tp1_price;
   g_candidate_upper_slope = upper_slope;
   g_candidate_upper_intercept = upper_intercept;
   g_candidate_lower_slope = lower_slope;
   g_candidate_lower_intercept = lower_intercept;
   g_candidate_line_x_at_setup = line_x_at_setup;
   g_candidate_setup_bar_time = setup_bar_time;
}

void Strategy_CommitAcceptedSetup(const ulong pending_ticket)
{
   if(!g_candidate_setup_valid || pending_ticket == 0)
      return;

   g_active_setup_valid = true;
   g_active_tp1_price = g_candidate_tp1_price;
   g_tp1_done = false;
   g_active_upper_slope = g_candidate_upper_slope;
   g_active_upper_intercept = g_candidate_upper_intercept;
   g_active_lower_slope = g_candidate_lower_slope;
   g_active_lower_intercept = g_candidate_lower_intercept;
   g_active_line_x_at_setup = g_candidate_line_x_at_setup;
   g_active_setup_bar_time = g_candidate_setup_bar_time;
   g_active_entry_time = 0;
   g_candidate_setup_valid = false;
}

void Strategy_UpdateSetupLifecycle()
{
   ulong position_ticket = 0;
   if(Strategy_SelectOurPosition(position_ticket))
   {
      if(g_active_setup_valid && g_active_entry_time == 0)
      {
         g_active_entry_time = (datetime)PositionGetInteger(POSITION_TIME);
         const int tf_seconds = PeriodSeconds(strategy_tf);
         if(g_active_entry_time > 0 && tf_seconds > 0 && strategy_reuse_guard_bars > 0)
            g_pattern_block_until = g_active_entry_time + strategy_reuse_guard_bars * tf_seconds;
      }
      return;
   }

   ulong pending_ticket = 0;
   if(Strategy_SelectOurPendingOrder(pending_ticket))
      return;

   if(!g_active_setup_valid)
      return;

   // A setup that never became a position was cancelled or expired: that is
   // the card's invalidation event and starts the ten-bar reuse guard now.
   if(g_active_entry_time == 0 && strategy_reuse_guard_bars > 0)
   {
      const int tf_seconds = PeriodSeconds(strategy_tf);
      if(tf_seconds > 0)
         g_pattern_block_until = TimeCurrent() + strategy_reuse_guard_bars * tf_seconds;
   }
   Strategy_ClearActiveSetup();
}

bool Strategy_ReuseGuardActive()
{
   if(g_pattern_block_until > 0 && TimeCurrent() < g_pattern_block_until)
      return true;

   if(strategy_reuse_guard_bars <= 0) return false;

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 30 * 24 * 60 * 60, now)) return false;

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
      const int bars_since = iBarShift(_Symbol, strategy_tf, last_deal_time, false);
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

bool Strategy_MacroBias(const int direction)
{
   if(!strategy_macro_bias_enabled) return true;
   if(g_h_sma_h4 == INVALID_HANDLE) return true;

   double sma_vals[2];
   const int sma_copied = CopyBuffer(g_h_sma_h4, 0, 1, 2, sma_vals);
   if(sma_copied < 1) return false;
   if(sma_copied < 2) return false;

   MqlRates h1_rates[];
   ArraySetAsSeries(h1_rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, h1_rates) < 1) return false;

   if(direction > 0)
   {
      // Bullish: H4 SMA(200) rising AND H1 close > H4 SMA(200)
      return (sma_vals[1] > sma_vals[0] && h1_rates[0].close > sma_vals[1]);
   }
   else if(direction < 0)
   {
      // Bearish: H4 SMA(200) falling AND H1 close < H4 SMA(200)
      return (sma_vals[1] < sma_vals[0] && h1_rates[0].close < sma_vals[1]);
   }

   return false;
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

bool Strategy_FitPivotsLine(const StrategyPivot &pivots[], const int ref_shift, double &out_slope, double &out_intercept)
{
   out_slope = 0.0;
   out_intercept = 0.0;
   const int n = ArraySize(pivots);
   if(n < 2) return false;

   double sum_x = 0.0, sum_y = 0.0, sum_xx = 0.0, sum_xy = 0.0;
   for(int i = 0; i < n; ++i)
   {
      const double x = (double)(ref_shift - pivots[i].shift);
      const double y = pivots[i].price;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
   }
   const double denom = (double)n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12) return false;
   out_slope = ((double)n * sum_xy - sum_x * sum_y) / denom;
   out_intercept = (sum_y - out_slope * sum_x) / (double)n;
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

   const int w = strategy_fractal_wing_bars;
   for(int s = start_shift + count - 1 - w; s >= start_shift + w; --s)
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
      if(is_low)
      {
         const int sz = ArraySize(low_pivots);
         ArrayResize(low_pivots, sz + 1);
         low_pivots[sz].shift = s;
         low_pivots[sz].price = rates[s].low;
      }
   }
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

   ulong pending_ticket = 0;
   if(Strategy_SelectOurPendingOrder(pending_ticket))
      return false;

   if(Strategy_ReuseGuardActive())
      return false;

   double atr_val[1];
   const int atr_copied = CopyBuffer(g_h_atr_h1, 0, 1, 1, atr_val);
   if(atr_copied < 1)
      return false;
   const double atr = atr_val[0];
   if(atr <= 0.0) return false;

   if(!Strategy_SpreadAcceptable(atr))
      return false;

   const int needed_bars = strategy_pole_max_bars + strategy_penn_max_bars + strategy_pole_volume_prior_bars + 30;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, needed_bars, rates);
   if(copied < needed_bars) return false;

   // Breakout candidate bar at shift 1
   const int breakout_shift = 1;

   // Test pennant lengths N_penn in [5, 15]
   for(int n_penn = strategy_penn_min_bars; n_penn <= strategy_penn_max_bars; ++n_penn)
   {
      const int penn_start_shift = breakout_shift + 1; // start of pennant (most recent bar before breakout)
      const int penn_end_shift = penn_start_shift + n_penn - 1; // oldest bar in pennant
      const int pole_end_shift = penn_end_shift + 1; // end of flagpole

      // Test pole lengths N_pole in [12, 36]
      for(int n_pole = strategy_pole_min_bars; n_pole <= strategy_pole_max_bars; ++n_pole)
      {
         const int pole_start_shift = pole_end_shift + n_pole - 1;
         if(pole_start_shift + strategy_pole_volume_prior_bars >= copied)
            continue;

         // Phase 1: Flagpole Gates
         // 1. Magnitude: |close_end - close_start| >= 4.0 * ATR
         const double pole_delta = rates[pole_end_shift].close - rates[pole_start_shift].close;
         if(MathAbs(pole_delta) < strategy_pole_min_atr * atr)
            continue;

         const int direction = (pole_delta > 0.0) ? 1 : -1;

         // 2. Slope strength: |slope_LR| / ATR >= 0.20 per bar
         double pole_slope = 0.0;
         if(!Strategy_FitLinearRegression(rates, pole_end_shift, n_pole, pole_slope))
            continue;
         if(direction > 0 && pole_slope / atr < strategy_pole_slope_min_atr)
            continue;
         if(direction < 0 && pole_slope / atr > -strategy_pole_slope_min_atr)
            continue;

         // 3. Few-pullback gate
         int pullback_cnt = 0;
         double pole_high = rates[pole_start_shift].high;
         double pole_low = rates[pole_start_shift].low;
         for(int p = pole_start_shift; p >= pole_end_shift; --p)
         {
            if(direction > 0 && p < pole_start_shift && rates[p].close < rates[p + 1].close)
               pullback_cnt++;
            else if(direction < 0 && p < pole_start_shift && rates[p].close > rates[p + 1].close)
               pullback_cnt++;

            if(rates[p].high > pole_high) pole_high = rates[p].high;
            if(rates[p].low < pole_low) pole_low = rates[p].low;
         }
         if((double)pullback_cnt / (double)n_pole > strategy_pole_max_pullback_pct)
            continue;

         // 4. Volume gate: mean(vol, pole) >= 1.20 * mean(vol, prior 60 bars)
         double mean_pole_vol = 0.0;
         if(strategy_volume_filter_enabled)
         {
            long pvol_sum = 0;
            for(int p = pole_end_shift; p <= pole_start_shift; ++p)
               pvol_sum += rates[p].tick_volume;
            mean_pole_vol = (double)pvol_sum / (double)n_pole;

            long prior_vol_sum = 0;
            for(int v = 1; v <= strategy_pole_volume_prior_bars; ++v)
               prior_vol_sum += rates[pole_start_shift + v].tick_volume;
            const double mean_prior_vol = (double)prior_vol_sum / (double)strategy_pole_volume_prior_bars;

            if(mean_prior_vol > 0.0 && mean_pole_vol < strategy_pole_volume_mult * mean_prior_vol)
               continue;
         }

         // Macro bias gate
         if(!Strategy_MacroBias(direction))
            continue;

         // Phase 2: Pennant Converge Gate
         double penn_low = rates[penn_start_shift].low;
         double penn_high = rates[penn_start_shift].high;
         long penn_vol_sum = 0;
         for(int f = penn_start_shift; f <= penn_end_shift; ++f)
         {
            if(rates[f].low < penn_low) penn_low = rates[f].low;
            if(rates[f].high > penn_high) penn_high = rates[f].high;
            penn_vol_sum += rates[f].tick_volume;
         }

         // 6. Range contraction: (highest_high - lowest_low) / ATR in [1.5, 4.0]
         const double penn_range = penn_high - penn_low;
         if(penn_range / atr < strategy_penn_range_min_atr || penn_range / atr > strategy_penn_range_max_atr)
            continue;

         // 8. Retracement bound
         const double pole_height = pole_high - pole_low;
         if(pole_height <= 0.0) continue;
         if(direction > 0)
         {
            const double retrace = (pole_high - penn_low) / pole_height;
            if(retrace > strategy_penn_max_retrace_pct) continue;
         }
         else
         {
            const double retrace = (penn_high - pole_low) / pole_height;
            if(retrace > strategy_penn_max_retrace_pct) continue;
         }

         // 9. Volume contraction: mean(vol, penn) <= 0.75 * mean(vol, pole)
         if(strategy_volume_filter_enabled && mean_pole_vol > 0.0)
         {
            const double mean_penn_vol = (double)penn_vol_sum / (double)n_penn;
            if(mean_penn_vol > strategy_penn_volume_mult * mean_pole_vol)
               continue;
         }

         // 5. Converging trendlines via fractal pivots
         StrategyPivot highs[], lows[];
         Strategy_FindFractals(rates, penn_start_shift, n_penn, highs, lows);

         double s_up = 0.0, up_intercept = 0.0;
         double s_lo = 0.0, lo_intercept = 0.0;
         const int ref_shift = penn_end_shift;

         if(ArraySize(highs) < 2 || ArraySize(lows) < 2)
            continue;
         if(!Strategy_FitPivotsLine(highs, ref_shift, s_up, up_intercept))
            continue;
         if(!Strategy_FitPivotsLine(lows, ref_shift, s_lo, lo_intercept))
            continue;

         // Converging trendlines: s_up < 0 (falling upper) and s_lo > 0 (rising lower)
         if(s_up >= 0.0 || s_lo <= 0.0)
            continue;

         // Slope symmetry: |s_up + s_lo| / (|s_up| + |s_lo|) <= 0.40
         const double symm = MathAbs(s_up + s_lo) / (MathAbs(s_up) + MathAbs(s_lo));
         if(symm > strategy_penn_slope_symmetry_max)
            continue;

         // 7. Apex distance
         const double denom_apex = s_up - s_lo;
         if(MathAbs(denom_apex) < 1e-12) continue;
         const double x_apex = (lo_intercept - up_intercept) / denom_apex;
         const double apex_dist_norm = (x_apex - (double)(ref_shift - breakout_shift)) / (double)n_penn;
         if(apex_dist_norm < strategy_penn_apex_dist_min || apex_dist_norm > strategy_penn_apex_dist_max)
            continue;

          // Phase 3: place the card-authorized stop order at the pennant edge.
          const double x_now = (double)(ref_shift - breakout_shift);
          const double upper_line_now = up_intercept + s_up * x_now;
          const double lower_line_now = lo_intercept + s_lo * x_now;
          const int tf_seconds = PeriodSeconds(strategy_tf);
          if(tf_seconds <= 0)
             return false;

          if(direction > 0)
          {
             // Long breakout: BUY-STOP above the projected upper boundary.
             const double trigger_price = MathMax(upper_line_now, penn_high) + strategy_breakout_buffer_atr * atr;
             const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
             if(ask <= 0.0 || trigger_price <= ask)
                continue;

             double initial_sl = lower_line_now - strategy_sl_buffer_atr * atr;
             if(trigger_price - initial_sl > strategy_sl_cap_atr * atr)
                initial_sl = trigger_price - strategy_sl_cap_atr * atr;

             const double full_tp = trigger_price + pole_height;

             req.type = QM_BUY_STOP;
             req.price = Strategy_NormalizePrice(trigger_price);
             req.sl = Strategy_NormalizePrice(initial_sl);
             req.tp = Strategy_NormalizePrice(full_tp);
             req.reason = "PENNANT_BULL_BRK";
             req.symbol_slot = qm_magic_slot_offset;
             req.expiration_seconds = STRATEGY_PENDING_VALID_BARS * tf_seconds;

             Strategy_StageCandidateSetup(
                Strategy_NormalizePrice(trigger_price + strategy_tp1_ratio * pole_height),
                s_up, up_intercept, s_lo, lo_intercept, x_now, rates[0].time);

             return true;
          }
          else
          {
             // Short breakout: SELL-STOP below the projected lower boundary.
             const double trigger_price = MathMin(lower_line_now, penn_low) - strategy_breakout_buffer_atr * atr;
             const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
             if(bid <= 0.0 || trigger_price >= bid)
                continue;

             double initial_sl = upper_line_now + strategy_sl_buffer_atr * atr;
             if(initial_sl - trigger_price > strategy_sl_cap_atr * atr)
                initial_sl = trigger_price + strategy_sl_cap_atr * atr;

             const double full_tp = trigger_price - pole_height;

             req.type = QM_SELL_STOP;
             req.price = Strategy_NormalizePrice(trigger_price);
             req.sl = Strategy_NormalizePrice(initial_sl);
             req.tp = Strategy_NormalizePrice(full_tp);
             req.reason = "PENNANT_BEAR_BRK";
             req.symbol_slot = qm_magic_slot_offset;
             req.expiration_seconds = STRATEGY_PENDING_VALID_BARS * tf_seconds;

             Strategy_StageCandidateSetup(
                Strategy_NormalizePrice(trigger_price - strategy_tp1_ratio * pole_height),
                s_up, up_intercept, s_lo, lo_intercept, x_now, rates[0].time);

             return true;
         }
      }
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
   {
      g_tp1_done = false;
      return;
   }

   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);

   // 1. Partial close at TP1 (50% measured move) + move SL to Break-Even
   if(!g_tp1_done && g_active_tp1_price > 0.0)
   {
      bool tp1_hit = false;
      if(pos_type == POSITION_TYPE_BUY && current_price >= g_active_tp1_price)
         tp1_hit = true;
      else if(pos_type == POSITION_TYPE_SELL && current_price <= g_active_tp1_price)
         tp1_hit = true;

      if(tp1_hit)
      {
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         const double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         double close_vol = MathFloor((current_volume * strategy_tp1_close_fraction) / lot_step) * lot_step;
         if(close_vol >= min_lot && (current_volume - close_vol) >= min_lot)
         {
            CTrade trade;
            trade.SetExpertMagicNumber(QM_FrameworkMagic());
            if(trade.PositionClosePartial(ticket, close_vol))
            {
               g_tp1_done = true;
               const double be_sl = Strategy_NormalizePrice(open_price);
               if(pos_type == POSITION_TYPE_BUY && (be_sl > current_sl || current_sl == 0.0))
                  trade.PositionModify(ticket, be_sl, PositionGetDouble(POSITION_TP));
               else if(pos_type == POSITION_TYPE_SELL && (be_sl < current_sl || current_sl == 0.0))
                  trade.PositionModify(ticket, be_sl, PositionGetDouble(POSITION_TP));
            }
         }
         else
         {
            g_tp1_done = true;
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;

   const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
   if(pos_time <= 0) return false;

   const int bars_open = iBarShift(_Symbol, strategy_tf, pos_time, false);

    // 1. Pattern-failure hard exit: if H1 close re-enters the advancing
    // converging triangle within the first five bars after entry.
    if(bars_open >= 1 && bars_open <= strategy_failure_exit_bars &&
       g_active_setup_valid && g_active_setup_bar_time > 0)
    {
       MqlRates rates[];
       ArraySetAsSeries(rates, true);
       if(CopyRates(_Symbol, strategy_tf, 1, 1, rates) >= 1)
       {
          const int bars_since_setup = iBarShift(_Symbol, strategy_tf, g_active_setup_bar_time, false);
          if(bars_since_setup < 0)
             return false;
          const double x = g_active_line_x_at_setup + (double)bars_since_setup;
          const double up_line = g_active_upper_intercept + g_active_upper_slope * x;
          const double dn_line = g_active_lower_intercept + g_active_lower_slope * x;
          const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

          if(pos_type == POSITION_TYPE_BUY && rates[0].close < up_line && rates[0].close > dn_line)
          {
             PrintFormat("QM5_%d: Pattern failure exit triggered (close %G inside %G..%G)",
                         qm_ea_id, rates[0].close, dn_line, up_line);
             return true;
          }
          else if(pos_type == POSITION_TYPE_SELL && rates[0].close > dn_line && rates[0].close < up_line)
          {
             PrintFormat("QM5_%d: Pattern failure exit triggered (close %G inside %G..%G)",
                         qm_ea_id, rates[0].close, dn_line, up_line);
             return true;
          }
      }
   }

   // 2. Time-stop: 18 H1 bars after entry
   if(bars_open >= strategy_time_stop_bars)
   {
      PrintFormat("QM5_%d: Time-stop exit triggered after %d bars", qm_ea_id, bars_open);
      return true;
   }

   return false;
}

bool Strategy_EntryNewsBlocked(const datetime broker_time)
{
   // Q09 control cells can explicitly disable the strategy temporal axis.
   if(qm_news_temporal == QM_NEWS_TEMPORAL_OFF)
      return false;

   if(!MQLInfoInteger(MQL_TESTER))
   {
      bool calendar_ok = false;
      const bool in_window = QM_NewsLiveInWindow(_Symbol, broker_time, 180, 180, calendar_ok);
      return (!calendar_ok || in_window);
   }

   if(!g_qm_news_loaded || !g_qm_news_available)
      return true;

   const datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      return true;
   return QM_NewsInWindow(utc_time, _Symbol, 180, 180, qm_news_min_impact);
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                         qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                         180, 180, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                         qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "V5_FRAMEWORK_DEFAULT_FRIDAY_CLOSE"))
      return INIT_FAILED;

   if(!Strategy_InitIndicators())
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Strategy_ReleaseIndicators();
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_UpdateSetupLifecycle();
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   // The card's ±180-minute high-impact blackout is entry-only. Protective
   // management and exits above remain reachable throughout the blackout.
   const datetime broker_now = TimeCurrent();
   if(Strategy_EntryNewsBlocked(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   QM_EntryRequest req = {};
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         Strategy_CommitAcceptedSetup(out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}

