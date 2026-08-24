#property strict
#property version   "5.0"
#property description "QM5_1416 Classical Bear Flag Continuation H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1416
// Classical Bear-Flag Continuation (H1)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1416_classical-bear-flag-continuation-h1.md
// Edwards & Magee Technical Analysis of Stock Trends 10th ed. Ch. 9
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1416;
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
input double strategy_pole_slope_min_atr             = -0.20;
input double strategy_pole_max_pullback_pct          = 0.35;
input bool   strategy_volume_filter_enabled          = true;
input double strategy_pole_volume_mult               = 1.20;
input int    strategy_pole_volume_prior_bars         = 60;
input int    strategy_flag_min_bars                  = 5;
input int    strategy_flag_max_bars                  = 18;
input double strategy_flag_slope_min_atr             = 0.005;
input double strategy_flag_slope_max_atr             = 0.10;
input double strategy_flag_containment_pct           = 0.80;
input double strategy_flag_channel_tol_atr           = 0.30;
input double strategy_flag_max_retrace_pct           = 0.50;
input double strategy_flag_volume_mult               = 0.80;
input double strategy_breakout_buffer_atr            = 0.40;
input int    strategy_pending_valid_bars              = 8;
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

const int STRATEGY_STATE_VERSION = 1;

bool     g_active_setup_valid = false;
double   g_active_tp1_price = 0.0;
bool     g_tp1_done = false;
double   g_active_lower_slope = 0.0;
double   g_active_lower_at_setup = 0.0;
datetime g_active_setup_bar_time = 0;
datetime g_active_flag_origin_time = 0;
int      g_active_flag_bars_at_setup = 0;
datetime g_pattern_block_until = 0;
bool     g_state_recovery_failed = false;

struct StrategyPivot
{
   int    shift;
   double price;
};

double Strategy_NormalizePrice(const double price)
{
   return QM_StopRulesNormalizePrice(_Symbol, price);
}

bool Strategy_ValidateInputs()
{
   if(qm_ea_id != 1416 || strategy_tf != PERIOD_H1)
      return false;
   if(strategy_atr_period < 2 || strategy_fractal_wing_bars != 1)
      return false;
   if(strategy_pole_min_bars < 2 || strategy_pole_max_bars < strategy_pole_min_bars)
      return false;
   if(strategy_flag_min_bars < 5 || strategy_flag_max_bars < strategy_flag_min_bars)
      return false;
   if(strategy_pole_min_atr <= 0.0 || strategy_pole_slope_min_atr >= 0.0)
      return false;
   if(strategy_pole_max_pullback_pct < 0.0 || strategy_pole_max_pullback_pct > 1.0)
      return false;
   if(strategy_pole_volume_mult <= 0.0 || strategy_pole_volume_prior_bars < 1)
      return false;
   if(strategy_flag_slope_min_atr < 0.0 ||
      strategy_flag_slope_max_atr < strategy_flag_slope_min_atr)
      return false;
   if(strategy_flag_containment_pct <= 0.0 || strategy_flag_containment_pct > 1.0)
      return false;
   if(strategy_flag_channel_tol_atr < 0.0 ||
      strategy_flag_max_retrace_pct <= 0.0 || strategy_flag_max_retrace_pct > 1.0)
      return false;
   if(strategy_flag_volume_mult <= 0.0 || strategy_breakout_buffer_atr <= 0.0)
      return false;
   if(strategy_pending_valid_bars < 1 || strategy_tp1_ratio <= 0.0 || strategy_tp1_ratio >= 1.0)
      return false;
   if(strategy_tp1_close_fraction <= 0.0 || strategy_tp1_close_fraction >= 1.0)
      return false;
   if(strategy_failure_exit_bars < 1 || strategy_time_stop_bars <= strategy_failure_exit_bars)
      return false;
   if(strategy_sl_buffer_atr <= 0.0 || strategy_sl_cap_atr <= strategy_sl_buffer_atr)
      return false;
   if(strategy_macro_sma_period < 2 || strategy_reuse_guard_bars < 0)
      return false;
   if(strategy_spread_max_atr <= 0.0)
      return false;
   return true;
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

bool Strategy_SelectOurPendingSellStop(ulong &ticket)
{
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong cand = OrderGetTicket(i);
      if(cand == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      ticket = cand;
      return true;
   }
   return false;
}

string Strategy_StatePrefix()
{
   return StringFormat("Q1416.%I64d.%d.%s.",
                       (long)AccountInfoInteger(ACCOUNT_LOGIN),
                       QM_FrameworkMagic(),
                       _Symbol);
}

string Strategy_StateKey(const string field)
{
   return Strategy_StatePrefix() + field;
}

bool Strategy_WriteStateValue(const string field, const double value)
{
   return (GlobalVariableSet(Strategy_StateKey(field), value) != 0);
}

bool Strategy_ReadStateValue(const string field, double &value)
{
   const string key = Strategy_StateKey(field);
   if(!GlobalVariableCheck(key)) return false;
   value = GlobalVariableGet(key);
   return true;
}

bool Strategy_PersistState()
{
   double previous_generation = 0.0;
   Strategy_ReadStateValue("commit", previous_generation);
   const double generation = MathFloor(previous_generation) + 1.0;
   if(!Strategy_WriteStateValue("begin", generation)) return false;

   bool ok = true;
   ok = Strategy_WriteStateValue("version", STRATEGY_STATE_VERSION) && ok;
   ok = Strategy_WriteStateValue("active", g_active_setup_valid ? 1.0 : 0.0) && ok;
   ok = Strategy_WriteStateValue("tp1", g_active_tp1_price) && ok;
   ok = Strategy_WriteStateValue("tp1_done", g_tp1_done ? 1.0 : 0.0) && ok;
   ok = Strategy_WriteStateValue("lower_slope", g_active_lower_slope) && ok;
   ok = Strategy_WriteStateValue("lower_setup", g_active_lower_at_setup) && ok;
   ok = Strategy_WriteStateValue("setup_time", (double)g_active_setup_bar_time) && ok;
   ok = Strategy_WriteStateValue("flag_origin", (double)g_active_flag_origin_time) && ok;
   ok = Strategy_WriteStateValue("flag_bars", (double)g_active_flag_bars_at_setup) && ok;
   ok = Strategy_WriteStateValue("block_until", (double)g_pattern_block_until) && ok;
   if(!ok) return false;
   GlobalVariablesFlush();
   if(!Strategy_WriteStateValue("commit", generation)) return false;
   GlobalVariablesFlush();
   return true;
}

bool Strategy_RestoreState()
{
   double begin_value = 0.0;
   double commit_value = 0.0;
   double value = 0.0;
   if(!Strategy_ReadStateValue("begin", begin_value) ||
      !Strategy_ReadStateValue("commit", commit_value) ||
      begin_value != commit_value)
      return false;
   if(!Strategy_ReadStateValue("version", value) || (int)value != STRATEGY_STATE_VERSION)
      return false;

   if(!Strategy_ReadStateValue("active", value)) return false;
   g_active_setup_valid = (value > 0.5);
   if(!Strategy_ReadStateValue("tp1", g_active_tp1_price)) return false;
   if(!Strategy_ReadStateValue("tp1_done", value)) return false;
   g_tp1_done = (value > 0.5);
   if(!Strategy_ReadStateValue("lower_slope", g_active_lower_slope)) return false;
   if(!Strategy_ReadStateValue("lower_setup", g_active_lower_at_setup)) return false;
   if(!Strategy_ReadStateValue("setup_time", value)) return false;
   g_active_setup_bar_time = (datetime)(long)value;
   if(!Strategy_ReadStateValue("flag_origin", value)) return false;
   g_active_flag_origin_time = (datetime)(long)value;
   if(!Strategy_ReadStateValue("flag_bars", value)) return false;
   g_active_flag_bars_at_setup = (int)value;
   if(!Strategy_ReadStateValue("block_until", value)) return false;
   g_pattern_block_until = (datetime)(long)value;

   if(!g_active_setup_valid) return true;
   return (g_active_tp1_price > 0.0 &&
           g_active_lower_at_setup > 0.0 &&
           g_active_setup_bar_time > 0 &&
           g_active_flag_origin_time > 0 &&
           g_active_flag_bars_at_setup >= strategy_flag_min_bars);
}

void Strategy_ResetActiveSetup(const bool keep_block_until)
{
   g_active_setup_valid = false;
   g_active_tp1_price = 0.0;
   g_tp1_done = false;
   g_active_lower_slope = 0.0;
   g_active_lower_at_setup = 0.0;
   g_active_setup_bar_time = 0;
   g_active_flag_origin_time = 0;
   g_active_flag_bars_at_setup = 0;
   g_state_recovery_failed = false;
   if(!keep_block_until) g_pattern_block_until = 0;
}

void Strategy_BlockPatternReuse()
{
   const int tf_seconds = PeriodSeconds(strategy_tf);
   if(strategy_reuse_guard_bars > 0 && tf_seconds > 0)
      g_pattern_block_until = TimeCurrent() + strategy_reuse_guard_bars * tf_seconds;
}

bool Strategy_CancelPending(const ulong ticket, const string reason)
{
   CTrade trade;
   trade.SetExpertMagicNumber(QM_FrameworkMagic());
   if(!trade.OrderDelete(ticket))
   {
      PrintFormat("QM5_%d: pending cancel failed ticket=%I64u reason=%s retcode=%u",
                  qm_ea_id, ticket, reason, trade.ResultRetcode());
      return false;
   }
   PrintFormat("QM5_%d: pending SELL-STOP cancelled ticket=%I64u reason=%s",
               qm_ea_id, ticket, reason);
   Strategy_BlockPatternReuse();
   Strategy_ResetActiveSetup(true);
   Strategy_PersistState();
   return true;
}

void Strategy_ReconstructPositionFailClosed(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double take_profit = PositionGetDouble(POSITION_TP);
   if(open_price > 0.0 && take_profit > 0.0 && take_profit < open_price)
      g_active_tp1_price = open_price - strategy_tp1_ratio * (open_price - take_profit);
   // Without a committed tp1_done marker, another partial close could repeat
   // an already executed reduction. Disable partial management and close the
   // position at the next strategy-exit evaluation instead.
   g_tp1_done = true;
   g_active_setup_valid = false;
   g_active_lower_slope = 0.0;
   g_active_lower_at_setup = 0.0;
   g_state_recovery_failed = true;
   PrintFormat("QM5_%d: durable channel state unavailable for position %I64u; fail-closed exit armed",
               qm_ea_id, ticket);
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

bool Strategy_MacroBias()
{
   if(!strategy_macro_bias_enabled) return true;

   const double sma_newer = QM_SMA(_Symbol, PERIOD_H4, strategy_macro_sma_period, 1);
   const double sma_older = QM_SMA(_Symbol, PERIOD_H4, strategy_macro_sma_period, 2);
   if(sma_newer <= 0.0 || sma_older <= 0.0) return false;

   MqlRates h1_rates[];
   ArraySetAsSeries(h1_rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 1, 1, h1_rates); // perf-allowed: one closed H1 bar for point-in-time H4 bias alignment
   if(copied < 1 || ArraySize(h1_rates) < 1) return false;

   // H4 SMA(200) is falling AND H1 close < H4 SMA(200)
   const bool sma_falling = (sma_newer <= sma_older);
   const bool price_below = (h1_rates[0].close < sma_newer);

   return (sma_falling && price_below);
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

bool Strategy_BuildBearFlagSetup(QM_EntryRequest &req,
                                 const datetime required_flag_origin,
                                 int &out_flag_bars,
                                 double &out_tp1_price,
                                 double &out_lower_slope,
                                 double &out_lower_at_setup,
                                 datetime &out_setup_bar_time,
                                 datetime &out_flag_origin_time)
{
   out_flag_bars = 0;
   out_tp1_price = 0.0;
   out_lower_slope = 0.0;
   out_lower_at_setup = 0.0;
   out_setup_bar_time = 0;
   out_flag_origin_time = 0;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   if(!Strategy_SpreadAcceptable(atr))
      return false;

   if(!Strategy_MacroBias())
      return false;

   const int needed_bars = strategy_pole_max_bars + strategy_flag_max_bars + strategy_pole_volume_prior_bars + 30;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, needed_bars, rates); // perf-allowed: bounded once-per-H1-bar pole/flag geometry scan
   if(copied < needed_bars || ArraySize(rates) < needed_bars) return false;

   // Test flag lengths N_flag in [5, 18]
   for(int n_flag = strategy_flag_min_bars; n_flag <= strategy_flag_max_bars; ++n_flag)
   {
      const int flag_start_shift = 1; // most recent completed flag bar
      const int flag_end_shift = flag_start_shift + n_flag - 1; // oldest bar in flag
      const int pole_end_shift = flag_end_shift + 1; // end of flagpole
      const datetime flag_origin_time = rates[flag_end_shift].time;
      if(required_flag_origin > 0 && flag_origin_time != required_flag_origin)
         continue;

      // Test pole lengths N_pole in [12, 36]
      for(int n_pole = strategy_pole_min_bars; n_pole <= strategy_pole_max_bars; ++n_pole)
      {
         const int pole_start_shift = pole_end_shift + n_pole - 1;
         if(pole_start_shift + strategy_pole_volume_prior_bars >= copied)
            continue;

         // Phase 1: Flagpole Gates (Bearish Impulse Down)
         // 1. Cumulative move: close_start - close_end >= 4.0 * ATR
         const double pole_move = rates[pole_start_shift].close - rates[pole_end_shift].close;
         if(pole_move < strategy_pole_min_atr * atr)
            continue;

         // 2. Slope strength: slope_LR / ATR <= -0.20 per bar
         double pole_slope = 0.0;
         if(!Strategy_FitLinearRegression(rates, pole_end_shift, n_pole, pole_slope))
            continue;
         if(pole_slope / atr > strategy_pole_slope_min_atr) // must be <= -0.20
            continue;

         // 3. Few-pullback gate: bars with close > close[k-1] <= 0.35 * N_pole
         int pullback_cnt = 0;
         double pole_high = rates[pole_start_shift].high;
         double pole_low = rates[pole_end_shift].low;
         for(int p = pole_start_shift; p >= pole_end_shift; --p)
         {
            if(p < pole_start_shift && rates[p].close > rates[p + 1].close)
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

         // Phase 2: Flag Channel Gates (Upward Consolidation Channel)
         // 5. Counter-slope: slope_LR(close, flag) / ATR in [+0.005, +0.10]
         double flag_slope = 0.0;
         if(!Strategy_FitLinearRegression(rates, flag_start_shift, n_flag, flag_slope))
            continue;
         const double flag_slope_norm = flag_slope / atr;
         if(flag_slope_norm < strategy_flag_slope_min_atr || flag_slope_norm > strategy_flag_slope_max_atr)
            continue;

         // 7. Retracement bound: (highest_high_flag - lowest_low_pole) / (highest_high_pole - lowest_low_pole) <= 0.50
         double flag_low = rates[flag_start_shift].low;
         double flag_high = rates[flag_start_shift].high;
         long flag_vol_sum = 0;
         for(int f = flag_start_shift; f <= flag_end_shift; ++f)
         {
            if(rates[f].low < flag_low) flag_low = rates[f].low;
            if(rates[f].high > flag_high) flag_high = rates[f].high;
            flag_vol_sum += rates[f].tick_volume;
         }
         const double pole_height = pole_high - pole_low;
         if(pole_height <= 0.0) continue;
         const double flag_retrace = (flag_high - pole_low) / pole_height;
         if(flag_retrace > strategy_flag_max_retrace_pct)
            continue;

         // 8. Volume contraction: mean(vol, flag) <= 0.80 * mean(vol, pole)
         if(strategy_volume_filter_enabled && mean_pole_vol > 0.0)
         {
            const double mean_flag_vol = (double)flag_vol_sum / (double)n_flag;
            if(mean_flag_vol > strategy_flag_volume_mult * mean_pole_vol)
               continue;
         }

         // 6. Channel containment with fractal pivots
         StrategyPivot highs[], lows[];
         Strategy_FindFractals(rates, flag_start_shift, n_flag, highs, lows);

         double upper_slope = 0.0, upper_intercept = 0.0;
         double lower_slope = 0.0, lower_intercept = 0.0;
         const int ref_shift = flag_end_shift;

         // Card gate 6 is strict: both channel sides require at least two
         // Williams pivots. Flag-wide extrema/regression are not substitutes.
         if(ArraySize(highs) < 2 || ArraySize(lows) < 2)
            continue;
         if(!Strategy_FitPivotsLine(highs, ref_shift, upper_slope, upper_intercept))
            continue;
         if(!Strategy_FitPivotsLine(lows, ref_shift, lower_slope, lower_intercept))
            continue;

         // Parallel tolerance: |slope_upper - slope_lower| <= 0.30 * (|slope_upper| + |slope_lower|)
         const double slope_diff = MathAbs(upper_slope - lower_slope);
         const double slope_sum = MathAbs(upper_slope) + MathAbs(lower_slope);
         if(slope_sum <= 1e-6 || slope_diff > 0.30 * slope_sum)
            continue;

         // Containment check: >= 80% closes within boundaries
         int contain_cnt = 0;
         for(int f = flag_start_shift; f <= flag_end_shift; ++f)
         {
            const double x = (double)(ref_shift - f);
            const double up_line = upper_intercept + upper_slope * x;
            const double dn_line = lower_intercept + lower_slope * x;
            if(rates[f].close <= up_line + strategy_flag_channel_tol_atr * atr &&
               rates[f].close >= dn_line - strategy_flag_channel_tol_atr * atr)
            {
               contain_cnt++;
            }
         }
         if((double)contain_cnt / (double)n_flag < strategy_flag_containment_pct)
            continue;

         // Phase 3: arm the ATR-buffered SELL-STOP before breakdown. The
         // current H1 bar is shift 0; gates 1-8 use completed bars only.
         const int setup_shift = 0;
         const double x_now = (double)(ref_shift - setup_shift);
         const double lower_line_now = lower_intercept + lower_slope * x_now;
         const double upper_line_now = upper_intercept + upper_slope * x_now;

         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0) return false;

         const double entry_price = Strategy_NormalizePrice(
            lower_line_now - strategy_breakout_buffer_atr * atr);
         if(entry_price <= 0.0 || entry_price >= bid)
            continue; // never substitute a market sell after a gap/breakdown

         // Stop Loss: upper_TL(t_break) + 0.3 * ATR
         double initial_sl = upper_line_now + strategy_sl_buffer_atr * atr;
         if(initial_sl - entry_price > strategy_sl_cap_atr * atr)
            initial_sl = entry_price + strategy_sl_cap_atr * atr;
         initial_sl = Strategy_NormalizePrice(initial_sl);
         if(initial_sl <= entry_price)
            continue;

         // TP: entry - flagpole length
         const double full_tp = Strategy_NormalizePrice(entry_price - pole_height);
         if(full_tp <= 0.0 || full_tp >= entry_price)
            continue;

         req.type = QM_SELL_STOP;
         req.price = entry_price;
         req.sl = initial_sl;
         req.tp = full_tp;
         req.reason = "Q1416_BEAR_FLAG_STOP";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = strategy_pending_valid_bars * PeriodSeconds(strategy_tf);

         out_flag_bars = n_flag;
         out_tp1_price = Strategy_NormalizePrice(entry_price - strategy_tp1_ratio * pole_height);
         out_lower_slope = lower_slope;
         out_lower_at_setup = lower_line_now;
         out_setup_bar_time = rates[0].time;
         out_flag_origin_time = flag_origin_time;

         return true;
      }
   }

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ulong existing_ticket = 0;
   if(Strategy_SelectOurPosition(existing_ticket))
      return false;

   // The card's entry-only blackout is exactly +/-3 H1 bars. Framework axes
   // remain OFF so management and exits are never short-circuited by news.
   const bool news_allows_entry =
      !QM_NewsInWindow(TimeGMT(), _Symbol, 180, 180, "HIGH");

   ulong pending_ticket = 0;
   if(Strategy_SelectOurPendingSellStop(pending_ticket))
   {
      if(!g_active_setup_valid && !Strategy_RestoreState())
      {
         Strategy_CancelPending(pending_ticket, "restart_state_missing");
         return false;
      }
      if(!news_allows_entry)
      {
         Strategy_CancelPending(pending_ticket, "news_blackout");
         return false;
      }

      const int bars_since_setup = iBarShift(_Symbol, strategy_tf, g_active_setup_bar_time, false);
      if(bars_since_setup < 0 ||
         bars_since_setup >= strategy_pending_valid_bars ||
         g_active_flag_bars_at_setup + bars_since_setup > strategy_flag_max_bars)
      {
         Strategy_CancelPending(pending_ticket, "expired_or_flag_stale");
         return false;
      }

      QM_EntryRequest revalidated_req = {};
      int flag_bars = 0;
      double tp1_price = 0.0;
      double lower_slope = 0.0;
      double lower_at_setup = 0.0;
      datetime setup_bar_time = 0;
      datetime flag_origin_time = 0;
      if(!Strategy_BuildBearFlagSetup(revalidated_req,
                                      g_active_flag_origin_time,
                                      flag_bars,
                                      tp1_price,
                                      lower_slope,
                                      lower_at_setup,
                                      setup_bar_time,
                                      flag_origin_time))
      {
         Strategy_CancelPending(pending_ticket, "gate_revalidation_failed");
      }
      return false;
   }

   if(g_active_setup_valid)
   {
      // No position and no pending order means the order expired or was
      // externally removed. Treat that as invalidation and start the reuse guard.
      Strategy_BlockPatternReuse();
      Strategy_ResetActiveSetup(true);
      Strategy_PersistState();
      return false;
   }
   if(Strategy_ReuseGuardActive() || !news_allows_entry)
      return false;

   int flag_bars = 0;
   double tp1_price = 0.0;
   double lower_slope = 0.0;
   double lower_at_setup = 0.0;
   datetime setup_bar_time = 0;
   datetime flag_origin_time = 0;
   if(!Strategy_BuildBearFlagSetup(req,
                                   0,
                                   flag_bars,
                                   tp1_price,
                                   lower_slope,
                                   lower_at_setup,
                                   setup_bar_time,
                                   flag_origin_time))
      return false;

   g_active_setup_valid = true;
   g_active_tp1_price = tp1_price;
   g_tp1_done = false;
   g_active_lower_slope = lower_slope;
   g_active_lower_at_setup = lower_at_setup;
   g_active_setup_bar_time = setup_bar_time;
   g_active_flag_origin_time = flag_origin_time;
   g_active_flag_bars_at_setup = flag_bars;
   g_state_recovery_failed = false;
   return true;
}

void Strategy_ManageOpenPosition()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return;

   if(!g_active_setup_valid && !g_state_recovery_failed)
   {
      if(!Strategy_RestoreState() || !g_active_setup_valid)
         Strategy_ReconstructPositionFailClosed(ticket);
   }

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);
   const datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int tf_seconds = PeriodSeconds(strategy_tf);
   const datetime desired_block_until = position_time + strategy_reuse_guard_bars * tf_seconds;
   if(position_time > 0 && tf_seconds > 0 && desired_block_until > g_pattern_block_until)
   {
      g_pattern_block_until = desired_block_until;
      Strategy_PersistState();
   }

   // 1. Partial close at 50% of measured-move (TP1)
   if(!g_tp1_done && g_active_tp1_price > 0.0 && current_price <= g_active_tp1_price)
   {
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(min_lot <= 0.0 || lot_step <= 0.0) return;
      double close_vol = MathFloor((current_volume * strategy_tp1_close_fraction) / lot_step) * lot_step;
      if(close_vol >= min_lot && (current_volume - close_vol) >= min_lot)
      {
         CTrade trade;
         trade.SetExpertMagicNumber(QM_FrameworkMagic());
         if(trade.PositionClosePartial(ticket, close_vol))
         {
            g_tp1_done = true;
            // Move SL to Break-Even
            const double be_sl = Strategy_NormalizePrice(open_price);
            if(be_sl < current_sl || current_sl == 0.0)
               QM_TM_SendSLTPModify(ticket, be_sl, PositionGetDouble(POSITION_TP), "BEAR_FLAG_TP1_BE");
            if(!Strategy_PersistState())
               g_state_recovery_failed = true;
         }
      }
      else
      {
         g_tp1_done = true;
         if(!Strategy_PersistState())
            g_state_recovery_failed = true;
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
   if(g_state_recovery_failed)
   {
      PrintFormat("QM5_%d: fail-closed exit because durable channel state could not be reconstructed",
                  qm_ea_id);
      return true;
   }

   // 1. Pattern-failure hard exit: close re-enters the projected lower
   // channel boundary within the first six completed H1 bars after entry.
   if(bars_open >= 1 && bars_open <= strategy_failure_exit_bars &&
      g_active_setup_valid && g_active_lower_at_setup > 0.0)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      const int copied = CopyRates(_Symbol, strategy_tf, 1, 1, rates); // perf-allowed: one closed bar for card-mandated projected-channel failure exit
      if(copied >= 1 && ArraySize(rates) >= 1)
      {
         const int setup_shift = iBarShift(_Symbol, strategy_tf, g_active_setup_bar_time, false);
         if(setup_shift < 1)
         {
            g_state_recovery_failed = true;
            return true;
         }
         const int projected_bars = setup_shift - 1;
         const double dn_line = g_active_lower_at_setup +
                                g_active_lower_slope * (double)projected_bars;
         if(rates[0].close > dn_line)
         {
            PrintFormat("QM5_%d: Pattern failure exit triggered (close %G > %G)",
                        qm_ea_id, rates[0].close, dn_line);
            return true;
         }
      }
   }

   // 2. Time-stop: 24 H1 bars after entry
   if(bars_open >= strategy_time_stop_bars)
   {
      PrintFormat("QM5_%d: Time-stop exit triggered after %d bars", qm_ea_id, bars_open);
      return true;
   }

   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!Strategy_ValidateInputs())
   {
      PrintFormat("QM5_%d: invalid card parameter contract", qm_ea_id);
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        180, 180, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   // The custom +/-180 minute entry window needs the same authenticated
   // calendar owned by QM_NewsFilter even though the standard temporal axis
   // remains OFF to keep management reachable.
   if(!QM_NewsInit("D:\\QM\\data\\news_calendar",
                   qm_news_stale_max_hours,
                   180,
                   180,
                   qm_news_min_impact))
      return INIT_FAILED;

   ulong position_ticket = 0;
   ulong pending_ticket = 0;
   const bool has_position = Strategy_SelectOurPosition(position_ticket);
   const bool has_pending = Strategy_SelectOurPendingSellStop(pending_ticket);
   const bool restored = Strategy_RestoreState();
   if(has_position && (!restored || !g_active_setup_valid))
      Strategy_ReconstructPositionFailClosed(position_ticket);
   else if(has_pending && (!restored || !g_active_setup_valid))
      Strategy_CancelPending(pending_ticket, "oninit_state_missing");
   else if(!restored && !has_position && !has_pending)
   {
      Strategy_ResetActiveSetup(false);
      Strategy_PersistState();
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Strategy_PersistState();
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   const bool new_bar = QM_IsNewBar(_Symbol, strategy_tf);
   if(!new_bar) return;
   QM_EquityStreamOnNewBar();

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
      Strategy_BlockPatternReuse();
      Strategy_ResetActiveSetup(true);
      Strategy_PersistState();
      return;
   }

   QM_EntryRequest req = {};
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
      {
         if(!Strategy_PersistState())
         {
            ulong pending_ticket = 0;
            if(Strategy_SelectOurPendingSellStop(pending_ticket))
               Strategy_CancelPending(pending_ticket, "state_persist_failed");
         }
      }
      else
      {
         Strategy_ResetActiveSetup(false);
      }
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

