#property strict
#property version   "5.0"
#property description "QM5_1442 Wyckoff Phase-E Mark-Up Multi-Pullback H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1442;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_atr_period         = 20;
input int    strategy_sma_period         = 20;
input int    strategy_d1_sma_period      = 50;
input int    strategy_d1_slope_bars      = 10;
input int    strategy_anchor_min_bars    = 30;
input int    strategy_anchor_max_bars    = 200;
input int    strategy_range_lookback     = 30;
input int    strategy_swing_lookback     = 8;
input int    strategy_linreg_period      = 30;
input int    strategy_recovery_min_bars  = 2;
input int    strategy_recovery_max_bars  = 12;
input int    strategy_reentry_spacing    = 8;
input int    strategy_time_stop_bars     = 30;
input double strategy_break_atr_mult     = 0.50;
input double strategy_higher_low_atr     = 0.10;
input double strategy_pullback_min_atr   = 0.60;
input double strategy_pullback_max_atr   = 1.80;
input double strategy_slope_atr_mult     = 0.04;
input double strategy_spread_atr_mult    = 0.15;
input double strategy_entry_buffer_atr   = 0.15;
input double strategy_sl_atr_mult        = 0.30;
input double strategy_sl_cap_atr_mult    = 2.50;
input double strategy_tp1_atr_mult       = 0.10;
input double strategy_tp2_pullback_mult  = 1.50;
input double strategy_trail_break_atr    = 0.20;

ulong    g_managed_ticket       = 0;
datetime g_entry_bar_time       = 0;
double   g_pullback_low         = 0.0;
double   g_leg_high_to_pullback = 0.0;
double   g_tp1_price            = 0.0;
double   g_tp2_price            = 0.0;
double   g_trail_fail_price     = 0.0;
bool     g_tp1_done             = false;
bool     g_tp2_done             = false;
datetime g_last_entry_signal_time = 0;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if((ask - bid) > strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1442_WYCKOFF_PHASE_E_REENTRY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != strategy_tf)
      return false;
   if(strategy_anchor_min_bars < 1 || strategy_anchor_max_bars <= strategy_anchor_min_bars)
      return false;

   const int needed = strategy_anchor_max_bars + strategy_range_lookback + strategy_swing_lookback + 5;
   MqlRates h4[];
   ArraySetAsSeries(h4, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, needed, h4); // perf-allowed: caller gates this hook with QM_IsNewBar().
   if(copied < needed)
      return false;

   const int k = 1;
   const double atr_k = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, k);
   if(atr_k <= 0.0)
      return false;

   int anchor = -1;
   double breakout_close = 0.0;
   for(int b = strategy_anchor_min_bars; b <= strategy_anchor_max_bars && b + strategy_range_lookback < copied; ++b)
     {
      double range_high = -DBL_MAX;
      for(int r = b + 1; r <= b + strategy_range_lookback && r < copied; ++r)
         range_high = MathMax(range_high, h4[r].high);

      const double atr_b = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, b);
      if(atr_b <= 0.0 || range_high <= 0.0)
         continue;

      if(h4[b].close > range_high + strategy_break_atr_mult * atr_b)
        {
         anchor = b;
         breakout_close = h4[b].close;
         break;
        }
     }
   if(anchor < 0)
      return false;

   double previous_swing_low = 0.0;
   for(int s = anchor - strategy_swing_lookback; s >= strategy_swing_lookback + 1; --s)
     {
      bool local_low = true;
      for(int d = 1; d <= strategy_swing_lookback; ++d)
        {
         if(h4[s].low > h4[s - d].low || h4[s].low > h4[s + d].low)
           {
            local_low = false;
            break;
           }
        }
      if(!local_low)
         continue;

      if(previous_swing_low > 0.0 && h4[s].low < previous_swing_low + strategy_higher_low_atr * atr_k)
         return false;
      previous_swing_low = h4[s].low;
     }

   int pullback_count = 0;
   int selected_j = -1;
   double prior_pullback_low = 0.0;
   double selected_leg_high = 0.0;
   for(int j = anchor - 5; j >= k + strategy_recovery_min_bars && j > 1; --j)
     {
      if(!(h4[j].low <= h4[j - 1].low && h4[j].low <= h4[j + 1].low))
         continue;
      if(h4[j].low <= breakout_close)
         continue;

      double leg_high = -DBL_MAX;
      for(int x = anchor; x >= j; --x)
         leg_high = MathMax(leg_high, h4[x].high);

      const double depth = leg_high - h4[j].low;
      if(depth < strategy_pullback_min_atr * atr_k || depth > strategy_pullback_max_atr * atr_k)
         continue;

      if(prior_pullback_low > 0.0 && h4[j].low < prior_pullback_low + strategy_higher_low_atr * atr_k)
         continue;

      int recovery_shift = -1;
      const int newest_recovery = MathMax(k, j - strategy_recovery_max_bars);
      const int oldest_recovery = j - strategy_recovery_min_bars;
      for(int rec = oldest_recovery; rec >= newest_recovery; --rec)
        {
         const double sma_rec = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, rec);
         if(sma_rec > 0.0 && h4[rec].close > h4[rec + 1].high && h4[rec].close > sma_rec)
           {
            recovery_shift = rec;
            break;
           }
        }

      prior_pullback_low = h4[j].low;
      ++pullback_count;
      if(recovery_shift == k && (pullback_count == 2 || pullback_count == 3))
        {
         selected_j = j;
         selected_leg_high = leg_high;
         break;
        }
     }

   if(selected_j < 0)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_x2 = 0.0;
   for(int n = 0; n < strategy_linreg_period; ++n)
     {
      const double xval = (double)n;
      const double yval = h4[strategy_linreg_period - n].close;
      sum_x += xval;
      sum_y += yval;
      sum_xy += xval * yval;
      sum_x2 += xval * xval;
     }
   const double denom = strategy_linreg_period * sum_x2 - sum_x * sum_x;
   if(denom == 0.0)
      return false;
   const double slope = (strategy_linreg_period * sum_xy - sum_x * sum_y) / denom;
   if(slope < strategy_slope_atr_mult * atr_k)
      return false;

   const double d1_sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double d1_sma_then = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1 + strategy_d1_slope_bars);
   if(d1_sma_now <= 0.0 || d1_sma_then <= 0.0 || d1_sma_now < d1_sma_then)
      return false;

   if(g_last_entry_signal_time > 0)
     {
      const int bars_since_prior = iBarShift(_Symbol, strategy_tf, g_last_entry_signal_time, false);
      if(bars_since_prior >= 0 && bars_since_prior < strategy_reentry_spacing)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double max_entry = h4[k].close + strategy_entry_buffer_atr * atr_k;
   if(ask <= 0.0 || ask > max_entry)
      return false;

   const double raw_sl = h4[selected_j].low - strategy_sl_atr_mult * atr_k;
   if(ask - raw_sl > strategy_sl_cap_atr_mult * atr_k)
      return false;

   req.sl = NormalizeDouble(raw_sl, _Digits);

   g_entry_bar_time = h4[k].time;
   g_pullback_low = h4[selected_j].low;
   g_leg_high_to_pullback = selected_leg_high;
   g_tp1_price = selected_leg_high + strategy_tp1_atr_mult * atr_k;
   g_tp2_price = ask + strategy_tp2_pullback_mult * (selected_leg_high - h4[selected_j].low);
   g_trail_fail_price = h4[selected_j].low - strategy_trail_break_atr * atr_k;
   g_tp1_done = false;
   g_tp2_done = false;
   g_last_entry_signal_time = h4[k].time;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      if(g_managed_ticket != ticket)
        {
         g_managed_ticket = ticket;
         g_tp1_done = false;
         g_tp2_done = false;
        }

      const double high0 = iHigh(_Symbol, strategy_tf, 0);
      const double low0 = iLow(_Symbol, strategy_tf, 0);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      if(!g_tp1_done && g_tp1_price > 0.0 && high0 >= g_tp1_price && volume > vmin)
        {
         if(QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL))
            g_tp1_done = true;
        }

      if(!g_tp2_done && g_tp2_price > 0.0 && bid >= g_tp2_price && volume > vmin)
        {
         if(QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL))
            g_tp2_done = true;
        }

      if(g_trail_fail_price > 0.0 && low0 < g_trail_fail_price)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(open_shift >= strategy_time_stop_bars)
         return true;
     }
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_1442\",\"card\":\"wyckoff-phase-e-mark-up-multi-pullback-h4\"}");
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
