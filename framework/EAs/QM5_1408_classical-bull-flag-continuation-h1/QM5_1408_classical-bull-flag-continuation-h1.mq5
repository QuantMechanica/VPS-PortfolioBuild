#property strict
#property version   "5.0"
#property description "QM5_1408 Classical Bull Flag Continuation H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1408
// Classical Bull-Flag Continuation (H1)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1408_classical-bull-flag-continuation-h1.md
// Edwards & Magee Technical Analysis of Stock Trends 10th ed. Ch. 9
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1408;
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

int      g_h_atr_h1 = INVALID_HANDLE;
int      g_h_sma_h4 = INVALID_HANDLE;

bool     g_active_setup_valid = false;
double   g_active_tp1_price = 0.0;
bool     g_tp1_done = false;
double   g_active_upper_slope = 0.0;
double   g_active_upper_intercept = 0.0;
int      g_active_flag_ref_shift = 0;
datetime g_active_entry_bar_time = 0;
datetime g_pattern_block_until = 0;

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
   if(g_h_sma_h4 == INVALID_HANDLE) return true;

   double sma_vals[2];
   if(CopyBuffer(g_h_sma_h4, 0, 1, 2, sma_vals) < 2) return false;

   MqlRates h1_rates[];
   ArraySetAsSeries(h1_rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, h1_rates) < 1) return false;

   // H4 SMA(200) is rising AND H1 close > H4 SMA(200)
   const bool sma_rising = (sma_vals[0] >= sma_vals[1]);
   const bool price_above = (h1_rates[0].close > sma_vals[0]);

   return (sma_rising && price_above);
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
   ulong existing_ticket = 0;
   if(Strategy_SelectOurPosition(existing_ticket))
      return false;

   if(Strategy_ReuseGuardActive())
      return false;

   double atr_val[1];
   if(CopyBuffer(g_h_atr_h1, 0, 1, 1, atr_val) < 1)
      return false;
   const double atr = atr_val[0];
   if(atr <= 0.0) return false;

   if(!Strategy_SpreadAcceptable(atr))
      return false;

   if(!Strategy_MacroBias())
      return false;

   const int needed_bars = strategy_pole_max_bars + strategy_flag_max_bars + strategy_pole_volume_prior_bars + 30;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, needed_bars, rates);
   if(copied < needed_bars) return false;

   // Breakout bar is candidate at shift 1
   const int breakout_shift = 1;

   // Test flag lengths N_flag in [5, 18]
   for(int n_flag = strategy_flag_min_bars; n_flag <= strategy_flag_max_bars; ++n_flag)
   {
      const int flag_start_shift = breakout_shift + 1; // start of flag (most recent bar before breakout)
      const int flag_end_shift = flag_start_shift + n_flag - 1; // oldest bar in flag
      const int pole_end_shift = flag_end_shift + 1; // end of flagpole

      // Test pole lengths N_pole in [12, 36]
      for(int n_pole = strategy_pole_min_bars; n_pole <= strategy_pole_max_bars; ++n_pole)
      {
         const int pole_start_shift = pole_end_shift + n_pole - 1;
         if(pole_start_shift + strategy_pole_volume_prior_bars >= copied)
            continue;

         // Phase 1: Flagpole Gates
         // 1. Cumulative move: close_end - close_start >= 4.0 * ATR
         const double pole_move = rates[pole_end_shift].close - rates[pole_start_shift].close;
         if(pole_move < strategy_pole_min_atr * atr)
            continue;

         // 2. Slope strength: slope_LR / ATR >= +0.20 per bar
         double pole_slope = 0.0;
         if(!Strategy_FitLinearRegression(rates, pole_end_shift, n_pole, pole_slope))
            continue;
         if(pole_slope / atr < strategy_pole_slope_min_atr)
            continue;

         // 3. Few-pullback gate: bars with close < close[k-1] <= 0.35 * N_pole
         int pullback_cnt = 0;
         double pole_high = rates[pole_end_shift].high;
         double pole_low = rates[pole_start_shift].low;
         for(int p = pole_start_shift; p >= pole_end_shift; --p)
         {
            if(p < pole_start_shift && rates[p].close < rates[p + 1].close)
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

         // Phase 2: Flag Channel Gates
         // 5. Counter-slope: slope_LR(close, flag) / ATR in [-0.10, -0.005]
         double flag_slope = 0.0;
         if(!Strategy_FitLinearRegression(rates, flag_start_shift, n_flag, flag_slope))
            continue;
         const double flag_slope_norm = flag_slope / atr;
         if(flag_slope_norm < strategy_flag_slope_min_atr || flag_slope_norm > strategy_flag_slope_max_atr)
            continue;

         // 7. Retracement bound: (highest_high_pole - lowest_low_flag) / (highest_high_pole - lowest_low_pole) <= 0.50
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
         const double flag_retrace = (pole_high - flag_low) / pole_height;
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

         if(ArraySize(highs) >= 2 && ArraySize(lows) >= 2)
         {
            if(!Strategy_FitPivotsLine(highs, ref_shift, upper_slope, upper_intercept))
               continue;
            if(!Strategy_FitPivotsLine(lows, ref_shift, lower_slope, lower_intercept))
               continue;

            // Parallel tolerance: |slope_upper - slope_lower| <= 0.30 * (|slope_upper| + |slope_lower|)
            const double slope_diff = MathAbs(upper_slope - lower_slope);
            const double slope_sum = MathAbs(upper_slope) + MathAbs(lower_slope);
            if(slope_sum > 1e-6 && slope_diff > 0.30 * slope_sum)
               continue;
         }
         else
         {
            // Use flag boundary regressions
            upper_slope = flag_slope;
            lower_slope = flag_slope;
            upper_intercept = flag_high;
            lower_intercept = flag_low;
         }

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

         // Phase 3: Breakout Trigger at shift 1
         const double x_now = (double)(ref_shift - breakout_shift);
         const double upper_line_now = upper_intercept + upper_slope * x_now;
         const double lower_line_now = lower_intercept + lower_slope * x_now;

         // Breakout condition: close > upper_TL(t_now) + 0.4 * ATR
         if(rates[breakout_shift].close <= upper_line_now + strategy_breakout_buffer_atr * atr)
            continue;

         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0) return false;

         // Stop Loss: lower_TL(t_break) - 0.3 * ATR
         double initial_sl = lower_line_now - strategy_sl_buffer_atr * atr;
         if(ask - initial_sl > strategy_sl_cap_atr * atr)
            initial_sl = ask - strategy_sl_cap_atr * atr;

         // TP: entry + flagpole length
         const double full_tp = ask + pole_height;

         req.type = QM_BUY;
         req.price = Strategy_NormalizePrice(ask);
         req.sl = Strategy_NormalizePrice(initial_sl);
         req.tp = Strategy_NormalizePrice(full_tp);
         req.reason = "BULL_FLAG_BRK";
         req.symbol_slot = qm_magic_slot_offset;

         g_active_tp1_price = Strategy_NormalizePrice(ask + strategy_tp1_ratio * pole_height);
         g_tp1_done = false;
         g_active_upper_slope = upper_slope;
         g_active_upper_intercept = upper_intercept;
         g_active_flag_ref_shift = ref_shift;
         g_active_entry_bar_time = rates[0].time;
         g_pattern_block_until = rates[0].time + strategy_reuse_guard_bars * PeriodSeconds(strategy_tf);

         return true;
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

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);

   // 1. Partial close at 50% of measured-move (TP1)
   if(!g_tp1_done && g_active_tp1_price > 0.0 && current_price >= g_active_tp1_price)
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
            // Move SL to Break-Even
            const double be_sl = Strategy_NormalizePrice(open_price);
            if(be_sl > current_sl)
            {
               trade.PositionModify(ticket, be_sl, PositionGetDouble(POSITION_TP));
            }
         }
      }
      else
      {
         g_tp1_done = true;
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

   // 1. Pattern-failure hard exit: if H1 close falls back inside flag channel within first 6 bars after entry
   if(bars_open >= 1 && bars_open <= strategy_failure_exit_bars && g_active_upper_intercept > 0.0)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, strategy_tf, 1, 1, rates) >= 1)
      {
         const int curr_shift = 1;
         const double x = (double)(g_active_flag_ref_shift - curr_shift);
         const double up_line = g_active_upper_intercept + g_active_upper_slope * x;
         if(rates[0].close < up_line)
         {
            PrintFormat("QM5_%d: Pattern failure exit triggered (close %G < %G)",
                        qm_ea_id, rates[0].close, up_line);
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

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
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
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

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

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
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
