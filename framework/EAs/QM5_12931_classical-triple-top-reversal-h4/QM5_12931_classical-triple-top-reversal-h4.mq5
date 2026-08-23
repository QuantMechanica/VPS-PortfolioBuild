#property strict
#property version   "5.0"
#property description "QM5_12931 Classical Triple Top Reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12931
// Classical Triple Top Reversal (H4)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_12931_classical-triple-top-reversal-h4.md
// Edwards & Magee Technical Analysis of Stock Trends 10th ed. Ch. 7 / Bulkowski Ch. 80
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12931;
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
input int    strategy_peak_spacing_min_bars          = 25;
input int    strategy_peak_spacing_max_bars          = 120;
input double strategy_peak_height_atr                = 0.50;
input double strategy_peak_equal_atr                 = 0.50;
input double strategy_trough_amplitude_min_atr       = 1.50;
input double strategy_trough_equal_atr               = 0.40;
input double strategy_neckline_slope_max_atr         = 0.05;
input int    strategy_uptrend_lookback_bars          = 40;
input double strategy_uptrend_slope_min_atr          = 0.10;
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
double   g_active_peak_mean = 0.0;
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
   const int sma_copied = CopyBuffer(g_h_sma_d1, 0, 1, 2, sma_vals);
   if(sma_copied < 1) return false;
   if(sma_copied < 2) return false;

   // D1 SMA(50) flat or falling at entry bar: SMA[1] <= SMA[2]
   return (sma_vals[0] <= sma_vals[1]);
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
   const int atr_copied = CopyBuffer(g_h_atr_h4, 0, 1, 1, atr_buf);
   if(atr_copied < 1)
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

   const int n_highs = ArraySize(highs);
   const int n_lows = ArraySize(lows);
   if(n_highs < 3 || n_lows < 2)
      return false;

   // Search for valid P1, P2, P3 (highs array is ordered newest to oldest: highs[i].shift < highs[i+1].shift)
   // We look for three peaks P3 (newest), P2 (middle), P1 (oldest)
   for(int i3 = 0; i3 < n_highs - 2; ++i3)
   {
      const int s_p3 = highs[i3].shift;
      const double p_p3 = highs[i3].price;

      // P3 breakout recency check: breakout must occur within strategy_breakout_recency_bars of P3
      if(s_p3 > strategy_breakout_recency_bars + 20)
         continue;

      for(int i2 = i3 + 1; i2 < n_highs - 1; ++i2)
      {
         const int s_p2 = highs[i2].shift;
         const double p_p2 = highs[i2].price;
         if(s_p2 <= s_p3) continue;

         for(int i1 = i2 + 1; i1 < n_highs; ++i1)
         {
            const int s_p1 = highs[i1].shift;
            const double p_p1 = highs[i1].price;
            if(s_p1 <= s_p2) continue;

            // Gate 1: Pairwise peak spacing: bar_index(P1) - bar_index(P3) in [25, 120]
            const int spacing = s_p1 - s_p3;
            if(spacing < strategy_peak_spacing_min_bars || spacing > strategy_peak_spacing_max_bars)
               continue;

            // Gate 2: Equal-height of peaks: max(P1,P2,P3) - min(P1,P2,P3) <= 0.5 * ATR
            const double max_p = MathMax(p_p1, MathMax(p_p2, p_p3));
            const double min_p = MathMin(p_p1, MathMin(p_p2, p_p3));
            if((max_p - min_p) > strategy_peak_equal_atr * atr)
               continue;

            // Gate 3: Intervening troughs T12 (between P1 and P2) and T23 (between P2 and P3)
            int t12_idx = -1;
            double t12_price = 1e9;
            int t12_shift = -1;
            for(int l = 0; l < n_lows; ++l)
            {
               if(lows[l].shift > s_p2 && lows[l].shift < s_p1)
               {
                  if(lows[l].price < t12_price)
                  {
                     t12_price = lows[l].price;
                     t12_shift = lows[l].shift;
                     t12_idx = l;
                  }
               }
            }

            int t23_idx = -1;
            double t23_price = 1e9;
            int t23_shift = -1;
            for(int l = 0; l < n_lows; ++l)
            {
               if(lows[l].shift > s_p3 && lows[l].shift < s_p2)
               {
                  if(lows[l].price < t23_price)
                  {
                     t23_price = lows[l].price;
                     t23_shift = lows[l].shift;
                     t23_idx = l;
                  }
               }
            }

            if(t12_idx < 0 || t23_idx < 0)
               continue;

            // Trough amplitude: min(P1, P2, P3) - max(T12, T23) >= 1.5 * ATR
            const double max_t = MathMax(t12_price, t23_price);
            if((min_p - max_t) < strategy_trough_amplitude_min_atr * atr)
               continue;

            // Trough equality: |T12 - T23| <= 0.4 * ATR
            if(MathAbs(t12_price - t23_price) > strategy_trough_equal_atr * atr)
               continue;

            // Gate 4: Neckline = (T12 + T23) / 2.0
            const double neckline = (t12_price + t23_price) / 2.0;
            const double trough_slope = MathAbs(t23_price - t12_price) / (double)MathMax(1, t12_shift - t23_shift);
            if(trough_slope > strategy_neckline_slope_max_atr * atr)
               continue;

            // Gate 5: Prior uptrend context: linear regression slope over 40 bars ending at P1 >= +0.10 * ATR/bar
            double ut_slope = 0.0;
            if(!Strategy_FitLinearRegression(rates, s_p1, strategy_uptrend_lookback_bars, ut_slope))
               continue;
            if(ut_slope < strategy_uptrend_slope_min_atr * atr)
               continue;

            // Gate 6: No prior neckline break: between P3 and shift 2, no close < neckline - 0.3 * ATR
            bool prior_break = false;
            for(int s = s_p3 - 1; s >= 2; --s)
            {
               if(rates[s].close < neckline - strategy_prior_break_filter_atr * atr)
               {
                  prior_break = true;
                  break;
               }
            }
            if(prior_break)
               continue;

            // Invalidation check: if any bar after P3 exceeded max_p + 0.3 * ATR, pattern invalidated
            bool invalidated = false;
            for(int s = s_p3 - 1; s >= 1; --s)
            {
               if(rates[s].high > max_p + 0.3 * atr)
               {
                  invalidated = true;
                  break;
               }
            }
            if(invalidated)
               continue;

            // Breakout trigger: on closed bar (shift 1), close[1] <= neckline - 0.4 * ATR and close[2] > neckline - 0.4 * ATR
            const double trigger_level = neckline - strategy_breakout_buffer_atr * atr;
            if(rates[1].close > trigger_level || rates[2].close <= trigger_level)
               continue;

            // Pattern confirmed and triggered!
            const double mean_p = (p_p1 + p_p2 + p_p3) / 3.0;
            const double amplitude = mean_p - neckline;
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            const double entry_price = bid;
            const double raw_sl = max_p + strategy_sl_buffer_atr * atr;
            const double sl = Strategy_NormalizePrice(raw_sl);
            const double tp = Strategy_NormalizePrice(entry_price - amplitude);

            // Cap check
            if((sl - entry_price) > strategy_sl_cap_atr * atr)
               continue;

            if(sl <= entry_price || tp >= entry_price)
               continue;

            req.type = QM_SELL;
            req.price = entry_price;
            req.sl = sl;
            req.tp = tp;
            req.reason = "QM5_12931_TripleTop";

            g_active_setup_valid = true;
            g_active_neckline = neckline;
            g_active_peak_mean = mean_p;
            g_active_tp1_price = Strategy_NormalizePrice(entry_price - amplitude * strategy_tp1_ratio);
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

   // Partial close at TP1 (50% measured move) + Move SL to BE
   if(!g_tp1_done && g_active_tp1_price > 0.0 && current_price <= g_active_tp1_price)
   {
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double close_vol = MathFloor((volume * strategy_tp1_close_fraction) / step_lot) * step_lot;
      if(close_vol >= min_lot && (volume - close_vol) >= min_lot)
      {
         QM_TM_PartialClose(ticket, close_vol, QM_EXIT_STRATEGY);
      }
      g_tp1_done = true;

      // Move SL to open price (Break-even)
      const double be_sl = Strategy_NormalizePrice(open_price);
      if(be_sl < current_sl || current_sl == 0.0)
      {
         QM_TM_MoveSL(ticket, be_sl, "QM5_12931_BE");
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

   // 2. Pattern-failure hard exit: if H4 close > neckline + 0.3 * ATR within first 8 bars
   if(bars_open <= strategy_failure_exit_bars && g_active_setup_valid)
   {
      double atr_buf[1];
      const int atr_copied = CopyBuffer(g_h_atr_h4, 0, 1, 1, atr_buf);
      if(atr_copied < 1) return false;
      if(atr_buf[0] > 0.0)
      {
         const double atr = atr_buf[0];
         MqlRates r[1];
         if(CopyRates(_Symbol, strategy_tf, 1, 1, r) >= 1)
         {
            if(r[0].close > g_active_neckline + strategy_failure_exit_buffer_atr * atr)
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
   QM_FrameworkTrackOpenPositionMae();
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

   QM_EntryRequest req = {};
   ZeroMemory(req);
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
