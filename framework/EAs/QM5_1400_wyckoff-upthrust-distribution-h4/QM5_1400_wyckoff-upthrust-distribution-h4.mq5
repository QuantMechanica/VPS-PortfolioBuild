#property strict
#property version   "5.0"
#property description "QM5_1400 Wyckoff Upthrust After Distribution H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1400;
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
input int    strategy_range_bars         = 60;
input int    strategy_atr_period         = 14;
input double strategy_range_atr_mult     = 4.0;
input int    strategy_required_pivots    = 3;
input double strategy_pivot_band_atr     = 0.3;
input double strategy_volume_decline     = 0.85;
input double strategy_breakout_atr       = 0.3;
input double strategy_wick_ratio_min     = 0.55;
input double strategy_volume_spike       = 1.4;
input int    strategy_sma_period         = 200;
input int    strategy_sma_compare_shift  = 40;
input double strategy_sl_atr_buffer      = 0.3;
input double strategy_max_sl_atr         = 3.0;
input double strategy_tp1_range_frac     = 0.2;
input double strategy_tp2_range_mult     = 0.5;
input int    strategy_time_stop_bars     = 80;
input double strategy_spread_atr_mult    = 0.25;
input int    strategy_news_h4_bars       = 2;

double   g_entry_tr_low = 0.0;
double   g_entry_tr_high = 0.0;
double   g_entry_upthrust_high = 0.0;
double   g_entry_tp1 = 0.0;
datetime g_entry_time = 0;
datetime g_last_used_window_start = 0;
bool     g_tp1_done = false;

bool SelectOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread = ask - bid;
   if(spread > strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1400_UTAD_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong existing_ticket = 0;
   if(SelectOurPosition(existing_ticket))
      return false;

   if(_Period != PERIOD_H4)
      return false;
   if(strategy_range_bars < 10 || strategy_required_pivots < 1)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int confirm_shift = 1;
   const int upthrust_shift = 2;
   const int window_start_shift = 3;
   const int window_end_shift = window_start_shift + strategy_range_bars - 1;
   const datetime window_start_time = iTime(_Symbol, PERIOD_H4, window_end_shift);
   if(window_start_time <= 0 || window_start_time == g_last_used_window_start)
      return false;

   double tr_high = -DBL_MAX;
   double tr_low = DBL_MAX;
   for(int i = window_start_shift; i <= window_end_shift; ++i)
     {
      const double h = iHigh(_Symbol, PERIOD_H4, i);
      const double l = iLow(_Symbol, PERIOD_H4, i);
      if(h <= 0.0 || l <= 0.0)
         return false;
      tr_high = MathMax(tr_high, h);
      tr_low = MathMin(tr_low, l);
     }

   const double range = tr_high - tr_low;
   if(range <= 0.0 || range > strategy_range_atr_mult * atr)
      return false;

   int pivot_highs = 0;
   int pivot_lows = 0;
   const double pivot_band = strategy_pivot_band_atr * atr;
   for(int i = window_start_shift + 1; i <= window_end_shift - 1; ++i)
     {
      const double h = iHigh(_Symbol, PERIOD_H4, i);
      const double hp = iHigh(_Symbol, PERIOD_H4, i + 1);
      const double hn = iHigh(_Symbol, PERIOD_H4, i - 1);
      const double l = iLow(_Symbol, PERIOD_H4, i);
      const double lp = iLow(_Symbol, PERIOD_H4, i + 1);
      const double ln = iLow(_Symbol, PERIOD_H4, i - 1);
      if(h >= hp && h >= hn && MathAbs(h - tr_high) <= pivot_band)
         ++pivot_highs;
      if(l <= lp && l <= ln && MathAbs(l - tr_low) <= pivot_band)
         ++pivot_lows;
     }
   if(pivot_highs < strategy_required_pivots || pivot_lows < strategy_required_pivots)
      return false;

   double recent_volume = 0.0;
   double early_volume = 0.0;
   for(int i = window_start_shift; i <= window_start_shift + 19; ++i)
      recent_volume += (double)iVolume(_Symbol, PERIOD_H4, i);
   for(int i = window_start_shift + 40; i <= window_start_shift + 59; ++i)
      early_volume += (double)iVolume(_Symbol, PERIOD_H4, i);
   recent_volume /= 20.0;
   early_volume /= 20.0;
   if(early_volume <= 0.0 || recent_volume >= strategy_volume_decline * early_volume)
      return false;

   const double up_high = iHigh(_Symbol, PERIOD_H4, upthrust_shift);
   const double up_low = iLow(_Symbol, PERIOD_H4, upthrust_shift);
   const double up_close = iClose(_Symbol, PERIOD_H4, upthrust_shift);
   const double confirm_close = iClose(_Symbol, PERIOD_H4, confirm_shift);
   if(up_high <= 0.0 || up_low <= 0.0 || up_close <= 0.0 || confirm_close <= 0.0)
      return false;

   const double up_range = up_high - up_low;
   if(up_range <= 0.0)
      return false;
   if(up_high <= tr_high + strategy_breakout_atr * atr)
      return false;
   if(up_close >= tr_high)
      return false;
   if((up_high - up_close) / up_range <= strategy_wick_ratio_min)
      return false;

   double prior_volume = 0.0;
   for(int i = 3; i <= 22; ++i)
      prior_volume += (double)iVolume(_Symbol, PERIOD_H4, i);
   prior_volume /= 20.0;
   const double up_volume = (double)iVolume(_Symbol, PERIOD_H4, upthrust_shift);
   if(prior_volume <= 0.0 || up_volume <= strategy_volume_spike * prior_volume)
      return false;

   const double sma_now = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 1);
   const double sma_then = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, strategy_sma_compare_shift);
   if(sma_now <= 0.0 || sma_then <= 0.0 || sma_now > sma_then)
      return false;

   if(confirm_close >= up_low)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || point <= 0.0)
      return false;

   const double sl = up_high + strategy_sl_atr_buffer * atr;
   const double sl_distance = sl - bid;
   if(sl_distance <= 0.0 || sl_distance > strategy_max_sl_atr * atr)
      return false;

   g_entry_tr_low = tr_low;
   g_entry_tr_high = tr_high;
   g_entry_upthrust_high = up_high;
   g_entry_tp1 = tr_low + strategy_tp1_range_frac * range;
   g_entry_time = TimeCurrent();
   g_last_used_window_start = window_start_time;
   g_tp1_done = false;

   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tr_low - strategy_tp2_range_mult * range, _Digits);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   if(!SelectOurPosition(ticket))
      return;
   if(g_tp1_done || g_entry_tp1 <= 0.0)
      return;
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
      return;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0 || ask > g_entry_tp1)
      return;

   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double half_volume = volume * 0.5;
   if(QM_TM_PartialClose(ticket, half_volume, QM_EXIT_STRATEGY))
     {
      g_tp1_done = true;
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      QM_TM_MoveSL(ticket, open_price, "QM5_1400_TP1_BE");
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!SelectOurPosition(ticket))
      return false;

   if(g_entry_upthrust_high > 0.0)
     {
      const double close1 = iClose(_Symbol, PERIOD_H4, 1);
      if(close1 > g_entry_upthrust_high)
         return true;
     }

   const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
   if(pos_time > 0 && strategy_time_stop_bars > 0)
     {
      const int bars_since_entry = iBarShift(_Symbol, PERIOD_H4, pos_time, false);
      if(bars_since_entry >= strategy_time_stop_bars)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_mode == QM_NEWS_OFF)
      return false;
   const int seconds = strategy_news_h4_bars * PeriodSeconds(PERIOD_H4);
   return !QM_NewsAllowsTrade(_Symbol, broker_time + seconds, qm_news_mode) ||
          !QM_NewsAllowsTrade(_Symbol, broker_time - seconds, qm_news_mode);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1400\",\"ea\":\"wyckoff_upthrust_distribution_h4\"}");
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
