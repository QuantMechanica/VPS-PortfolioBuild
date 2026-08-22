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

int      g_h_atr_h4 = INVALID_HANDLE;
int      g_h_sma_d1 = INVALID_HANDLE;

bool     g_active_setup_valid = false;
double   g_active_tp1_price = 0.0;
bool     g_tp1_done = false;
double   g_active_neckline = 0.0;
double   g_active_trough_mean = 0.0;
datetime g_pattern_block_until = 0;

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

bool Strategy_InitIndicators()
{
   g_h_atr_h4 = iATR(_Symbol, strategy_tf, strategy_atr_period);
   if(g_h_atr_h4 == INVALID_HANDLE)
   {
      PrintFormat("QM5_%d: failed to create H4 ATR handle", qm_ea_id);
      return false;
   }
   if(strategy_macro_bias_enabled)
   {
      g_h_sma_d1 = iMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 0, MODE_SMA, PRICE_CLOSE);
      if(g_h_sma_d1 == INVALID_HANDLE)
      {
         PrintFormat("QM5_%d: failed to create D1 SMA handle", qm_ea_id);
         return false;
      }
   }
   return true;
}

void Strategy_ReleaseIndicators()
{
   if(g_h_atr_h4 != INVALID_HANDLE) { IndicatorRelease(g_h_atr_h4); g_h_atr_h4 = INVALID_HANDLE; }
   if(g_h_sma_d1 != INVALID_HANDLE) { IndicatorRelease(g_h_sma_d1); g_h_sma_d1 = INVALID_HANDLE; }
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
   if(g_h_sma_d1 == INVALID_HANDLE) return true;

   double sma_vals[2];
   if(CopyBuffer(g_h_sma_d1, 0, 1, 2, sma_vals) < 2) return false;

   // D1 SMA(50) flat or rising at entry bar: SMA[1] >= SMA[2]
   return (sma_vals[0] >= sma_vals[1]);
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
      if(is_low)
      {
         const int sz = ArraySize(low_pivots);
         ArrayResize(low_pivots, sz + 1);
         low_pivots[sz].shift = s;
         low_pivots[sz].time  = rates[s].time;
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

   double atr_buf[1];
   if(CopyBuffer(g_h_atr_h4, 0, 1, 1, atr_buf) < 1)
      return false;
   const double atr = atr_buf[0];
   if(atr <= 0.0)
      return false;

   if(!Strategy_SpreadAcceptable(atr))
      return false;

   if(!Strategy_MacroBias())
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int fetch_bars = strategy_lookback_max_bars + 60;
   if(CopyRates(_Symbol, strategy_tf, 0, fetch_bars, rates) < fetch_bars)
      return false;

   // Closed bars analysis starting from shift 1
   StrategyPivot highs[], lows[];
   Strategy_FindFractals(rates, 1, strategy_lookback_max_bars, highs, lows);

   const int n_lows = ArraySize(lows);
   const int n_highs = ArraySize(highs);
   if(n_lows < 3 || n_highs < 2)
      return false;

   // Search for valid T1, T2, T3 (lows array is ordered newest to oldest: lows[i].shift < lows[i+1].shift)
   // We look for three troughs T3 (newest), T2 (middle), T1 (oldest)
   for(int i3 = 0; i3 < n_lows - 2; ++i3)
   {
      const int s_t3 = lows[i3].shift;
      const double p_t3 = lows[i3].price;

      // T3 breakout recency check: breakout must occur within strategy_breakout_recency_bars of T3
      if(s_t3 > strategy_breakout_recency_bars + 20)
         continue;

      for(int i2 = i3 + 1; i2 < n_lows - 1; ++i2)
      {
         const int s_t2 = lows[i2].shift;
         const double p_t2 = lows[i2].price;
         if(s_t2 <= s_t3) continue;

         for(int i1 = i2 + 1; i1 < n_lows; ++i1)
         {
            const int s_t1 = lows[i1].shift;
            const double p_t1 = lows[i1].price;
            if(s_t1 <= s_t2) continue;

            // Gate 1: Pairwise trough spacing: bar_index(T1) - bar_index(T3) in [25, 120]
            const int spacing = s_t1 - s_t3;
            if(spacing < strategy_trough_spacing_min_bars || spacing > strategy_trough_spacing_max_bars)
               continue;

            // Gate 2: Equal-depth of troughs: max(T1,T2,T3) - min(T1,T2,T3) <= 0.5 * ATR
            const double max_t = MathMax(p_t1, MathMax(p_t2, p_t3));
            const double min_t = MathMin(p_t1, MathMin(p_t2, p_t3));
            if((max_t - min_t) > strategy_trough_equal_atr * atr)
               continue;

            // Gate 3: Intervening peaks P12 (between T1 and T2) and P23 (between T2 and T3)
            int p12_idx = -1;
            double p12_price = -1.0;
            int p12_shift = -1;
            for(int h = 0; h < n_highs; ++h)
            {
               if(highs[h].shift > s_t2 && highs[h].shift < s_t1)
               {
                  if(highs[h].price > p12_price)
                  {
                     p12_price = highs[h].price;
                     p12_shift = highs[h].shift;
                     p12_idx = h;
                  }
               }
            }

            int p23_idx = -1;
            double p23_price = -1.0;
            int p23_shift = -1;
            for(int h = 0; h < n_highs; ++h)
            {
               if(highs[h].shift > s_t3 && highs[h].shift < s_t2)
               {
                  if(highs[h].price > p23_price)
                  {
                     p23_price = highs[h].price;
                     p23_shift = highs[h].shift;
                     p23_idx = h;
                  }
               }
            }

            if(p12_idx < 0 || p23_idx < 0)
               continue;

            // Peak amplitude: min(P12, P23) - max(T1, T2, T3) >= 1.5 * ATR
            const double min_p = MathMin(p12_price, p23_price);
            if((min_p - max_t) < strategy_peak_amplitude_min_atr * atr)
               continue;

            // Peak equality: |P12 - P23| <= 0.4 * ATR
            if(MathAbs(p12_price - p23_price) > strategy_peak_equal_atr * atr)
               continue;

            // Gate 4: Neckline = (P12 + P23) / 2.0
            const double neckline = (p12_price + p23_price) / 2.0;
            const double peak_slope = MathAbs(p23_price - p12_price) / (double)MathMax(1, p12_shift - p23_shift);
            if(peak_slope > strategy_neckline_slope_max_atr * atr)
               continue;

            // Gate 5: Prior downtrend context: linear regression slope over 40 bars ending at T1 <= -0.10 * ATR/bar
            double dt_slope = 0.0;
            if(!Strategy_FitLinearRegression(rates, s_t1, strategy_downtrend_lookback_bars, dt_slope))
               continue;
            if(dt_slope > strategy_downtrend_slope_max_atr * atr)
               continue;

            // Gate 6: No prior neckline break: between T3 and shift 2, no close > neckline + 0.3 * ATR
            bool prior_break = false;
            for(int s = s_t3 - 1; s >= 2; --s)
            {
               if(rates[s].close > neckline + strategy_prior_break_filter_atr * atr)
               {
                  prior_break = true;
                  break;
               }
            }
            if(prior_break)
               continue;

            // Invalidation check: if any bar after T3 dipped below min_t - 0.3 * ATR, pattern invalidated
            bool invalidated = false;
            for(int s = s_t3 - 1; s >= 1; --s)
            {
               if(rates[s].low < min_t - 0.3 * atr)
               {
                  invalidated = true;
                  break;
               }
            }
            if(invalidated)
               continue;

            // Breakout trigger: on closed bar (shift 1), close[1] >= neckline + 0.4 * ATR and close[2] < neckline + 0.4 * ATR
            const double trigger_level = neckline + strategy_breakout_buffer_atr * atr;
            if(rates[1].close < trigger_level || rates[2].close >= trigger_level)
               continue;

            // Pattern confirmed and triggered!
            const double mean_t = (p_t1 + p_t2 + p_t3) / 3.0;
            const double amplitude = neckline - mean_t;
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            const double entry_price = ask;
            const double raw_sl = min_t - strategy_sl_buffer_atr * atr;
            const double sl = Strategy_NormalizePrice(raw_sl);
            const double tp = Strategy_NormalizePrice(entry_price + amplitude);

            // Cap check
            if((entry_price - sl) > strategy_sl_cap_atr * atr)
               continue;

            if(sl >= entry_price || tp <= entry_price)
               continue;

            req.action = QM_ENTRY_BUY;
            req.price = entry_price;
            req.sl = sl;
            req.tp = tp;
            req.comment = "QM5_1425_TripleBottom";

            g_active_setup_valid = true;
            g_active_neckline = neckline;
            g_active_trough_mean = mean_t;
            g_active_tp1_price = Strategy_NormalizePrice(entry_price + amplitude * strategy_tp1_ratio);
            g_tp1_done = false;
            g_pattern_block_until = TimeCurrent() + strategy_reuse_guard_bars * PeriodSeconds(strategy_tf);

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
      return;

   if(!g_active_setup_valid)
      return;

   const double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);

   // Partial close at TP1 (50% measured move) + Move SL to BE
   if(!g_tp1_done && g_active_tp1_price > 0.0 && current_price >= g_active_tp1_price)
   {
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double close_vol = MathFloor((volume * strategy_tp1_close_fraction) / step_lot) * step_lot;
      if(close_vol >= min_lot && (volume - close_vol) >= min_lot)
      {
         QM_TM_ClosePositionPartial(ticket, close_vol, QM_EXIT_STRATEGY);
      }
      g_tp1_done = true;

      // Move SL to open price (Break-even)
      const double be_sl = Strategy_NormalizePrice(open_price);
      if(be_sl > current_sl)
      {
         QM_TM_ModifyPosition(ticket, be_sl, current_tp);
      }
   }
}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_open = iBarShift(_Symbol, strategy_tf, open_time, false);

   // 1. Time-stop: 30 H4 bars
   if(bars_open >= strategy_time_stop_bars)
      return true;

   // 2. Pattern-failure hard exit: if H4 close < neckline - 0.3 * ATR within first 8 bars
   if(bars_open <= strategy_failure_exit_bars && g_active_setup_valid)
   {
      double atr_buf[1];
      if(CopyBuffer(g_h_atr_h4, 0, 1, 1, atr_buf) >= 1 && atr_buf[0] > 0.0)
      {
         const double atr = atr_buf[0];
         MqlRates r[1];
         if(CopyRates(_Symbol, strategy_tf, 1, 1, r) >= 1)
         {
            if(r[0].close < g_active_neckline - strategy_failure_exit_buffer_atr * atr)
               return true;
         }
      }
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
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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

