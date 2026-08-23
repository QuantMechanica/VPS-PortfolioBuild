#property strict
#property version   "5.0"
#property description "QM5_12932 Wyckoff Phase-E Mark-down Continuation H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12932 Wyckoff Phase-E Mark-down Continuation H4
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12932;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf             = PERIOD_H4;
input int             strategy_atr_period            = 14;
input int             strategy_d1_sma_period         = 50;
input int             strategy_range_min_duration    = 50;
input int             strategy_range_max_lookback    = 300;
input double          strategy_range_min_amp_atr     = 3.0;
input double          strategy_range_max_amp_atr     = 14.0;
input double          strategy_containment_min_ratio = 0.80;
input double          strategy_break_threshold_atr   = 0.50;
input double          strategy_pre_trend_min_slope   = 0.08;
input double          strategy_min_markdown_atr      = 1.50;
input double          strategy_min_pullback_atr      = 0.80;
input double          strategy_max_retrace_ratio     = 0.75;
input double          strategy_resistance_tol_atr    = 0.50;
input double          strategy_trend_max_slope       = -0.05;
input double          strategy_min_trend_dist_atr    = 2.00;
input double          strategy_max_spread_atr        = 0.20;
input int             strategy_pattern_reuse_bars    = 20;
input double          strategy_sl_max_atr            = 3.50;
input double          strategy_sl_buffer_atr         = 0.50;
input int             strategy_time_stop_bars        = 50;

datetime g_last_entry_time = 0;
datetime g_last_range_start_time = 0;
double   g_last_range_L = 0.0;
double   g_last_range_U = 0.0;

// -----------------------------------------------------------------------------
// Helper routines
// -----------------------------------------------------------------------------

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                double &tp,
                                datetime &open_time)
{
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
   }
   return false;
}

double Strategy_LinearRegressionSlope(const ENUM_TIMEFRAMES tf, const int start_shift, const int count)
{
   if(count <= 1) return 0.0;
   double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_xx = 0.0;
   for(int i = 0; i < count; ++i)
   {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol, tf, start_shift + (count - 1 - i), bar)) return 0.0;
      const double x = (double)i;
      const double y = bar.close;
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_xx += x * x;
   }
   const double denom = (count * sum_xx - sum_x * sum_x);
   if(MathAbs(denom) < 1e-12) return 0.0;
   return (count * sum_xy - sum_x * sum_y) / denom;
}

bool Strategy_CheckBearishReversalBar(const MqlRates &bar1, const MqlRates &bar2)
{
   const double body1 = MathAbs(bar1.close - bar1.open);
   const double body2 = MathAbs(bar2.close - bar2.open);
   const double range1 = bar1.high - bar1.low;

   // 1. Bearish Engulfing
   if(bar1.close < bar1.open && bar2.close > bar2.open)
   {
      if(bar1.open >= bar2.close && bar1.close <= bar2.open)
         return true;
   }

   // 2. Shooting Star
   if(range1 > 0.0)
   {
      const double upper_shadow = bar1.high - MathMax(bar1.open, bar1.close);
      const double lower_shadow = MathMin(bar1.open, bar1.close) - bar1.low;
      if(upper_shadow >= 2.0 * body1 && lower_shadow <= 0.30 * range1 && body1 > 0.0)
         return true;
   }

   // 3. Dark Cloud Cover
   if(bar2.close > bar2.open && bar1.close < bar1.open)
   {
      if(bar1.open >= bar2.close && bar1.close < (bar2.open + bar2.close) * 0.5 && bar1.close > bar2.open)
         return true;
   }

   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != strategy_signal_tf) return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid) return false;
   const double spread = ask - bid;
   if(strategy_max_spread_atr > 0.0 && spread > strategy_max_spread_atr * atr) return false;

   MqlRates bar1, bar2;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 1, bar1) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 2, bar2))
      return false;

   const int tf_seconds = PeriodSeconds(strategy_signal_tf);
   if(g_last_entry_time > 0 && (bar1.time - g_last_entry_time < strategy_pattern_reuse_bars * tf_seconds))
      return false;

   // Gate 7: Bearish Reversal Bar Trigger on bar 1
   if(!Strategy_CheckBearishReversalBar(bar1, bar2)) return false;

   // Gate 8: Slope of Trend Confirmation over 30 H4 bars <= -0.05 * ATR
   const double slope30 = Strategy_LinearRegressionSlope(strategy_signal_tf, 1, 30);
   if(slope30 > strategy_trend_max_slope * atr) return false;

   // Gate 9: Macro Bias Gate D1 SMA(50) falling
   const double sma_d1_1 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double sma_d1_2 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 2);
   if(sma_d1_1 <= 0.0 || sma_d1_2 <= 0.0 || sma_d1_1 >= sma_d1_2) return false;

   // Range detection scan (Gate 1): look for range ending 6..60 bars ago
   bool range_found = false;
   double best_U = 0.0;
   double best_L = 0.0;
   datetime best_range_start_time = 0;
   int best_break_bar = 0;
   double best_lowest_low = 0.0;

   for(int range_end = 6; range_end <= 60; range_end += 5)
   {
      for(int duration = strategy_range_min_duration; duration <= 120; duration += 10)
      {
         const int range_start = range_end + duration - 1;
         if(range_start > strategy_range_max_lookback) break;

         MqlRates start_bar;
         if(!QM_ReadBar(_Symbol, strategy_signal_tf, range_start, start_bar)) continue;

         double highest_high = -1.0;
         double lowest_low = 1e9;
         for(int i = range_end; i <= range_start; ++i)
         {
            MqlRates b;
            if(!QM_ReadBar(_Symbol, strategy_signal_tf, i, b)) break;
            if(b.high > highest_high) highest_high = b.high;
            if(b.low < lowest_low) lowest_low = b.low;
         }

         if(highest_high <= 0.0 || lowest_low >= 1e9) continue;
         const double amp = highest_high - lowest_low;
         if(amp < strategy_range_min_amp_atr * atr || amp > strategy_range_max_amp_atr * atr) continue;

         // Containment check
         int contained_bars = 0;
         const double lower_bound = lowest_low - 0.30 * atr;
         const double upper_bound = highest_high + 0.30 * atr;
         for(int i = range_end; i <= range_start; ++i)
         {
            MqlRates b;
            if(!QM_ReadBar(_Symbol, strategy_signal_tf, i, b)) break;
            if(b.close >= lower_bound && b.close <= upper_bound)
               contained_bars++;
         }
         const double containment_ratio = (double)contained_bars / (double)duration;
         if(containment_ratio < strategy_containment_min_ratio) continue;

         // Phase-D break check: close < lowest_low - 0.5 * ATR in [6, range_end]
         int break_bar = 0;
         for(int i = range_end; i >= 6; --i)
         {
            MqlRates b;
            if(!QM_ReadBar(_Symbol, strategy_signal_tf, i, b)) break;
            if(b.close < lowest_low - strategy_break_threshold_atr * atr)
            {
               break_bar = i;
               break;
            }
         }
         if(break_bar == 0) continue;

         // Gate 2: Pre-range uptrend over 80 bars ending at range_start
         const double pre_slope = Strategy_LinearRegressionSlope(strategy_signal_tf, range_start, 80);
         if(pre_slope < strategy_pre_trend_min_slope * atr) continue;

         // Gate 3: Initial markdown completed: lowest low post-break <= L - 1.5 * ATR
         double lowest_post_break = 1e9;
         for(int i = break_bar; i >= 1; --i)
         {
            MqlRates b;
            if(!QM_ReadBar(_Symbol, strategy_signal_tf, i, b)) break;
            if(b.low < lowest_post_break) lowest_post_break = b.low;
         }
         if(lowest_post_break > lowest_low - strategy_min_markdown_atr * atr) continue;

         // Gate 4: Pullback rally: current_high >= lowest_post_break + 0.8 * ATR
         if(bar1.high < lowest_post_break + strategy_min_pullback_atr * atr) continue;

         // Gate 5: Pullback retracement bound: (current_high - lowest_low) / (L - lowest_low) <= 0.75
         const double markdown_depth = lowest_low - lowest_post_break;
         if(markdown_depth <= 0.0) continue;
         const double retrace_ratio = (bar1.high - lowest_post_break) / markdown_depth;
         if(retrace_ratio > strategy_max_retrace_ratio) continue;

         // Gate 6: At-resistance test: bar1.high within 0.5 * ATR of lowest_low
         if(MathAbs(bar1.high - lowest_low) > strategy_resistance_tol_atr * atr &&
            bar1.high < lowest_low - strategy_resistance_tol_atr * atr)
            continue;

         // Gate 10: No false failure: no close > U + 0.3 * ATR since break
         bool false_failure = false;
         for(int i = break_bar; i >= 1; --i)
         {
            MqlRates b;
            if(!QM_ReadBar(_Symbol, strategy_signal_tf, i, b)) break;
            if(b.close > highest_high + 0.30 * atr)
            {
               false_failure = true;
               break;
            }
         }
         if(false_failure) continue;

         // Gate 11: Minimum trend distance: U - bar1.high >= 2.0 * ATR
         if((highest_high - bar1.high) < strategy_min_trend_dist_atr * atr) continue;

         // Range-validity uniqueness check: must not reuse the same range start time
         if(g_last_range_start_time > 0 && start_bar.time == g_last_range_start_time) continue;

         range_found = true;
         best_U = highest_high;
         best_L = lowest_low;
         best_range_start_time = start_bar.time;
         best_break_bar = break_bar;
         best_lowest_low = lowest_post_break;
         break;
      }
      if(range_found) break;
   }

   if(!range_found) return false;

   // Local pullback rally high (last 10 H4 bars)
   double max_high_10 = bar1.high;
   for(int i = 2; i <= 10; ++i)
   {
      MqlRates b;
      if(!QM_ReadBar(_Symbol, strategy_signal_tf, i, b)) break;
      if(b.high > max_high_10) max_high_10 = b.high;
   }

   const double entry = bid;
   double initial_sl = max_high_10 + strategy_sl_buffer_atr * atr;
   const double sl_cap = entry + strategy_sl_max_atr * atr;
   if(initial_sl > sl_cap) initial_sl = sl_cap;

   const double range_amp = best_U - best_L;
   const double tp = entry - range_amp; // TP1 measured move

   initial_sl = QM_StopRulesNormalizePrice(_Symbol, initial_sl);
   const double normalized_tp = QM_StopRulesNormalizePrice(_Symbol, tp);

   if(initial_sl > entry && normalized_tp > 0.0 && normalized_tp < entry)
   {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = initial_sl;
      req.tp = normalized_tp;
      req.reason = "WYCKOFF_PHASE_E_MARKDOWN_SHORT";
      g_last_entry_time = bar1.time;
      g_last_range_start_time = best_range_start_time;
      g_last_range_L = best_L;
      g_last_range_U = best_U;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price, sl, tp;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return;
   if(open_price <= 0.0 || position_type != POSITION_TYPE_SELL) return;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0) return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;

   const double profit = open_price - ask;

   // TP1 reached check: if profit >= (U - L), move SL to entry (breakeven)
   if(g_last_range_U > g_last_range_L)
   {
      const double range_amp = g_last_range_U - g_last_range_L;
      if(profit >= range_amp)
      {
         const double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price);
         if(sl > be_sl + point * 0.5)
         {
            QM_TM_MoveSL(ticket, be_sl, "wyckoff_phase_e_tp1_be");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price, sl, tp;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, tp, open_time))
      return false;

   const int tf_seconds = PeriodSeconds(strategy_signal_tf);
   if(tf_seconds > 0 && strategy_time_stop_bars > 0 && open_time > 0)
   {
      // Time-stop: 50 H4 bars after entry
      if(TimeCurrent() - open_time >= strategy_time_stop_bars * tf_seconds)
         return true;
   }

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf)) return false;

   // Pattern-failure hard exit: if H4 close re-crosses L + 0.3 * ATR within first 12 bars after entry
   if(open_time > 0 && (TimeCurrent() - open_time <= 12 * tf_seconds) && g_last_range_L > 0.0)
   {
      const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
      MqlRates bar1;
      if(QM_ReadBar(_Symbol, strategy_signal_tf, 1, bar1) && atr > 0.0)
      {
         if(bar1.close > g_last_range_L + 0.30 * atr)
            return true;
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
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   QM_FrameworkTrackOpenPositionMae();
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

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf)) return;
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
