#property strict
#property version   "5.0"
#property description "QM5_1433 Wyckoff Phase-E Mark-Up Continuation H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1433;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 14;
input int    strategy_min_range_bars     = 60;
input int    strategy_max_range_bars     = 300;
input int    strategy_prerange_bars      = 50;
input int    strategy_pivot_window       = 10;
input double strategy_pivot_min_atr      = 0.7;
input double strategy_range_min_atr      = 3.0;
input double strategy_range_max_atr      = 12.0;
input double strategy_range_slope_atr    = 0.03;
input double strategy_prerange_slope_atr = -0.08;
input double strategy_break_buffer_atr   = 0.5;
input double strategy_markup_min_atr     = 1.5;
input double strategy_pullback_min_atr   = 0.8;
input double strategy_pullback_max_frac  = 0.75;
input double strategy_support_tol_atr    = 0.5;
input double strategy_trend_slope_atr    = 0.05;
input double strategy_failure_tol_atr    = 0.3;
input double strategy_min_trend_atr      = 2.0;
input double strategy_entry_buffer_atr   = 0.2;
input double strategy_sl_buffer_atr      = 0.4;
input double strategy_sl_cap_atr         = 3.5;
input double strategy_spread_max_atr     = 0.20;
input int    strategy_reuse_guard_bars   = 30;
input int    strategy_time_stop_h4_bars  = 45;
input int    strategy_failure_h4_bars    = 12;
input double strategy_partial_fraction   = 0.60;

double   g_active_range_high = 0.0;
double   g_active_tp1 = 0.0;
double   g_active_tp2 = 0.0;
bool     g_partial_done = false;
datetime g_last_pattern_time = 0;
datetime g_entry_time = 0;

double CloseAt(const MqlRates &rates[], const int shift)
  {
   return rates[shift - 1].close;
  }

double OpenAt(const MqlRates &rates[], const int shift)
  {
   return rates[shift - 1].open;
  }

double HighAt(const MqlRates &rates[], const int shift)
  {
   return rates[shift - 1].high;
  }

double LowAt(const MqlRates &rates[], const int shift)
  {
   return rates[shift - 1].low;
  }

datetime TimeAt(const MqlRates &rates[], const int shift)
  {
   return rates[shift - 1].time;
  }

double LinearSlopeClose(const MqlRates &rates[], const int start_shift, const int bars)
  {
   if(bars < 2)
      return 0.0;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_x2 = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double x = (double)i;
      const double y = CloseAt(rates, start_shift + bars - 1 - i);
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
     }

   const double n = (double)bars;
   const double den = n * sum_x2 - sum_x * sum_x;
   if(MathAbs(den) < 1e-12)
      return 0.0;
   return (n * sum_xy - sum_x * sum_y) / den;
  }

bool IsSignificantPivotHigh(const MqlRates &rates[], const int shift, const int bars_total, const double atr)
  {
   if(shift <= 3 || shift + strategy_pivot_window > bars_total)
      return false;
   if(!(HighAt(rates, shift) > HighAt(rates, shift - 1) &&
        HighAt(rates, shift) > HighAt(rates, shift - 2) &&
        HighAt(rates, shift) > HighAt(rates, shift + 1) &&
        HighAt(rates, shift) > HighAt(rates, shift + 2)))
      return false;

   double low_min = LowAt(rates, shift);
   for(int s = shift - strategy_pivot_window; s <= shift + strategy_pivot_window; ++s)
     {
      if(s < 1 || s > bars_total)
         continue;
      low_min = MathMin(low_min, LowAt(rates, s));
     }
   return (HighAt(rates, shift) - low_min >= strategy_pivot_min_atr * atr);
  }

bool IsSignificantPivotLow(const MqlRates &rates[], const int shift, const int bars_total, const double atr)
  {
   if(shift <= 3 || shift + strategy_pivot_window > bars_total)
      return false;
   if(!(LowAt(rates, shift) < LowAt(rates, shift - 1) &&
        LowAt(rates, shift) < LowAt(rates, shift - 2) &&
        LowAt(rates, shift) < LowAt(rates, shift + 1) &&
        LowAt(rates, shift) < LowAt(rates, shift + 2)))
      return false;

   double high_max = HighAt(rates, shift);
   for(int s = shift - strategy_pivot_window; s <= shift + strategy_pivot_window; ++s)
     {
      if(s < 1 || s > bars_total)
         continue;
      high_max = MathMax(high_max, HighAt(rates, s));
     }
   return (high_max - LowAt(rates, shift) >= strategy_pivot_min_atr * atr);
  }

bool BullishReversalBar(const MqlRates &rates[], const int shift)
  {
   const double high = HighAt(rates, shift);
   const double low = LowAt(rates, shift);
   const double range = high - low;
   if(range <= 0.0)
      return false;
   return (CloseAt(rates, shift) > OpenAt(rates, shift) &&
           CloseAt(rates, shift) - low >= 0.6 * range &&
           CloseAt(rates, shift) > CloseAt(rates, shift + 1));
  }

bool FindWyckoffPhaseE(double &entry_price, double &sl_price, double &tp1, double &tp2, double &range_high_out, datetime &pattern_time)
  {
   const int bars_needed = strategy_max_range_bars + strategy_prerange_bars + 80;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, rates);
   if(copied < strategy_min_range_bars + strategy_prerange_bars + 40)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(!BullishReversalBar(rates, 1))
      return false;

   const double d1_sma_1 = QM_SMA(_Symbol, PERIOD_D1, 50, 1);
   const double d1_sma_2 = QM_SMA(_Symbol, PERIOD_D1, 50, 2);
   if(d1_sma_1 <= 0.0 || d1_sma_2 <= 0.0 || d1_sma_1 < d1_sma_2)
      return false;

   if(g_last_pattern_time > 0)
     {
      const int elapsed = iBarShift(_Symbol, PERIOD_H4, g_last_pattern_time, true);
      if(elapsed >= 0 && elapsed < strategy_reuse_guard_bars)
         return false;
     }

   const int max_break_shift = MathMin(copied - strategy_prerange_bars - strategy_min_range_bars - 2, 85);
   for(int b_shift = 7; b_shift <= max_break_shift; ++b_shift)
     {
      double h_post = -DBL_MAX;
      int h_shift = -1;
      const int h_from = MathMax(2, b_shift - 25);
      const int h_to = b_shift - 3;
      for(int s = h_to; s >= h_from; --s)
        {
         if(HighAt(rates, s) > h_post)
           {
            h_post = HighAt(rates, s);
            h_shift = s;
           }
        }
      if(h_shift < 0)
         continue;

      double l_pullback = DBL_MAX;
      int l_shift = -1;
      const int l_from = MathMax(2, h_shift - 30);
      const int l_to = h_shift - 3;
      for(int s = l_to; s >= l_from; --s)
        {
         if(LowAt(rates, s) < l_pullback)
           {
            l_pullback = LowAt(rates, s);
            l_shift = s;
           }
        }
      if(l_shift < 2)
         continue;

      bool earlier_reversal = false;
      for(int s = l_shift - 1; s >= 2; --s)
        {
         if(BullishReversalBar(rates, s))
           {
            earlier_reversal = true;
            break;
           }
        }
      if(earlier_reversal)
         continue;

      for(int range_bars = strategy_min_range_bars; range_bars <= strategy_max_range_bars; ++range_bars)
        {
         const int range_start_shift = b_shift + range_bars;
         const int pre_start_shift = range_start_shift + strategy_prerange_bars;
         if(pre_start_shift > copied)
            break;

         double range_high = -DBL_MAX;
         double range_low = DBL_MAX;
         for(int s = b_shift + 1; s <= range_start_shift; ++s)
           {
            range_high = MathMax(range_high, HighAt(rates, s));
            range_low = MathMin(range_low, LowAt(rates, s));
           }

         const double range_amp = range_high - range_low;
         if(range_amp < strategy_range_min_atr * atr || range_amp > strategy_range_max_atr * atr)
            continue;
         if(range_amp < strategy_min_trend_atr * atr)
            continue;

         if(!(HighAt(rates, b_shift) > range_high + strategy_break_buffer_atr * atr &&
              CloseAt(rates, b_shift) > range_high))
            continue;

         bool prior_break = false;
         for(int s = b_shift + 1; s <= range_start_shift; ++s)
           {
            if(HighAt(rates, s) > range_high + strategy_break_buffer_atr * atr &&
               CloseAt(rates, s) > range_high)
              {
               prior_break = true;
               break;
              }
           }
         if(prior_break)
            continue;

         int high_touches = 0;
         int low_touches = 0;
         const double touch_tol = 0.25 * atr;
         for(int s = b_shift + 1; s <= range_start_shift; ++s)
           {
            if(IsSignificantPivotHigh(rates, s, copied, atr) && MathAbs(HighAt(rates, s) - range_high) <= touch_tol)
               ++high_touches;
            if(IsSignificantPivotLow(rates, s, copied, atr) && MathAbs(LowAt(rates, s) - range_low) <= touch_tol)
               ++low_touches;
           }
         if(high_touches < 3 || low_touches < 3)
            continue;

         const double range_slope = LinearSlopeClose(rates, b_shift + 1, range_bars);
         if(MathAbs(range_slope) > strategy_range_slope_atr * atr)
            continue;

         const double prerange_slope = LinearSlopeClose(rates, range_start_shift + 1, strategy_prerange_bars);
         if(prerange_slope > strategy_prerange_slope_atr * atr)
            continue;

         const double markup_leg = h_post - range_high;
         if(markup_leg < strategy_markup_min_atr * atr)
            continue;

         if(h_post - l_pullback < strategy_pullback_min_atr * atr)
            continue;
         if(l_pullback < h_post - strategy_pullback_max_frac * markup_leg)
            continue;
         if(MathAbs(l_pullback - range_high) > strategy_support_tol_atr * atr)
            continue;

         const double trend_slope = LinearSlopeClose(rates, b_shift, b_shift);
         if(trend_slope < strategy_trend_slope_atr * atr)
            continue;

         bool false_failure = false;
         for(int s = h_shift; s >= 1; --s)
           {
            if(CloseAt(rates, s) < range_low + strategy_failure_tol_atr * atr)
              {
               false_failure = true;
               break;
              }
           }
         if(false_failure)
            continue;

         const double trigger_close = CloseAt(rates, 1);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         entry_price = trigger_close + strategy_entry_buffer_atr * atr;
         if(ask > 0.0 && ask >= entry_price)
            entry_price = ask;

         const double structural_sl = MathMin(l_pullback, range_high) - strategy_sl_buffer_atr * atr;
         const double capped_sl = entry_price - strategy_sl_cap_atr * atr;
         sl_price = MathMax(structural_sl, capped_sl);
         tp1 = entry_price + markup_leg;
         tp2 = entry_price + 2.0 * markup_leg;
         range_high_out = range_high;
         pattern_time = TimeAt(rates, b_shift);
         return true;
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   return ((ask - bid) > strategy_spread_max_atr * atr);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   double entry_price = 0.0;
   double sl_price = 0.0;
   double tp1 = 0.0;
   double tp2 = 0.0;
   double range_high = 0.0;
   datetime pattern_time = 0;

   if(!FindWyckoffPhaseE(entry_price, sl_price, tp1, tp2, range_high, pattern_time))
      return false;

   ZeroMemory(req);
   req.type = QM_BUY_STOP;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask > 0.0 && ask >= entry_price)
     {
      req.type = QM_BUY;
      req.price = ask;
     }
   else
      req.price = entry_price;

   req.sl = sl_price;
   req.tp = tp2;
   req.reason = "QM5_1433_WYCKOFF_PHASE_E_MARKUP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 4 * 4 * 60 * 60;

   g_active_range_high = range_high;
   g_active_tp1 = tp1;
   g_active_tp2 = tp2;
   g_last_pattern_time = pattern_time;
   g_entry_time = TimeCurrent();
   g_partial_done = false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      if(g_active_tp1 <= 0.0 || g_partial_done)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid < g_active_tp1)
         continue;

      const double lots = PositionGetDouble(POSITION_VOLUME);
      const double partial_lots = lots * strategy_partial_fraction;
      if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_STRATEGY))
        {
         const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         QM_TM_MoveSL(ticket, entry, "wyckoff_tp1_break_even");
         if(g_active_tp2 > 0.0)
            QM_TM_MoveTP(ticket, g_active_tp2, "wyckoff_tp2_extended_measured_move");
         g_partial_done = true;
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_open = (int)((TimeCurrent() - pos_time) / (4 * 60 * 60));
      if(bars_open >= strategy_time_stop_h4_bars)
         return true;

      if(g_active_range_high > 0.0 && bars_open <= strategy_failure_h4_bars)
        {
         const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
         const double h4_close = iClose(_Symbol, PERIOD_H4, 1);
         if(atr > 0.0 && h4_close > 0.0 && h4_close < g_active_range_high - strategy_failure_tol_atr * atr)
            return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

   if(!QM_IsNewBar())
      return;

   QM_EntryRequest req;
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
