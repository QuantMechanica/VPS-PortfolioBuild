#property strict
#property version   "5.0"
#property description "QM5_1236 GitHub Donchian 55 Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1236;
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
input int    strategy_entry_channel_days = 55;
input int    strategy_exit_channel_days  = 20;
input int    strategy_atr_period         = 20;
input int    strategy_atr_median_days    = 120;
input double strategy_atr_median_mult    = 0.70;
input double strategy_atr_sl_mult        = 2.50;
input double strategy_trail_after_r      = 1.00;
input int    strategy_max_hold_bars      = 120;
input int    strategy_min_history_bars   = 120;
input int    strategy_spread_median_days = 60;
input double strategy_spread_mult        = 2.00;
input bool   strategy_use_trend_filter   = false;
input int    strategy_fast_sma_period    = 100;
input int    strategy_slow_sma_period    = 200;

datetime g_last_entry_d1_bar = 0;
datetime g_last_exit_d1_bar = 0;

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_Channel(const ENUM_TIMEFRAMES tf, const int start_shift, const int bars,
                      double &highest, double &lowest)
  {
   highest = -DBL_MAX;
   lowest = DBL_MAX;
   if(bars <= 0 || start_shift <= 0)
      return false;

   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double high_i = iHigh(_Symbol, tf, shift);
      const double low_i = iLow(_Symbol, tf, shift);
      if(high_i <= 0.0 || low_i <= 0.0 || high_i < low_i)
         return false;
      if(high_i > highest)
         highest = high_i;
      if(low_i < lowest)
         lowest = low_i;
     }

   return (highest > 0.0 && lowest > 0.0 && highest > lowest);
  }

double Strategy_MedianAtr()
  {
   const int days = MathMin(strategy_atr_median_days, 256);
   if(days <= 0)
      return 0.0;

   double values[256];
   int count = 0;
   for(int shift = 1; shift <= days; ++shift)
     {
      const double atr_i = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr_i <= 0.0)
         continue;
      values[count] = atr_i;
      ++count;
     }
   if(count < MathMin(20, days))
      return 0.0;

   for(int i = 1; i < count; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0 || strategy_spread_median_days <= 0 || strategy_spread_mult <= 0.0)
      return true;

   const int days = MathMin(strategy_spread_median_days, 256);
   int values[256];
   int count = 0;
   for(int shift = 1; shift <= days; ++shift)
     {
      const long spread_i = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread_i <= 0)
         continue;
      values[count] = (int)spread_i;
      ++count;
     }
   if(count < MathMin(20, days))
      return true;

   for(int i = 1; i < count; ++i)
     {
      const int key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }

   const double median = ((count % 2) == 1)
                         ? (double)values[count / 2]
                         : 0.5 * (double)(values[(count / 2) - 1] + values[count / 2]);
   return ((double)current_spread <= median * strategy_spread_mult);
  }

bool Strategy_TrendAllowsDirection(const int direction)
  {
   if(!strategy_use_trend_filter)
      return true;

   const double fast = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1);
   const double slow = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 1);
   if(fast <= 0.0 || slow <= 0.0)
      return false;
   if(direction > 0)
      return (fast > slow);
   if(direction < 0)
      return (fast < slow);
   return false;
  }

bool Strategy_SelectOpenPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype,
                                 double &open_price, double &current_sl,
                                 datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   open_time = 0;

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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int Strategy_BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   int held = 0;
   for(int shift = 1; shift <= strategy_max_hold_bars + 5; ++shift)
     {
      const datetime t = iTime(_Symbol, PERIOD_D1, shift);
      if(t <= 0)
         break;
      if(t >= open_time)
         ++held;
     }
   return held;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Bars(_Symbol, PERIOD_D1) < MathMax(strategy_min_history_bars, strategy_slow_sma_period) + 5)
      return true;
   if(strategy_entry_channel_days <= 0 || strategy_exit_channel_days <= 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_median_days <= 0)
      return true;
   if(strategy_atr_median_mult <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_trail_after_r <= 0.0 || strategy_max_hold_bars <= 0)
      return true;
   if(strategy_use_trend_filter && (strategy_fast_sma_period <= 0 || strategy_slow_sma_period <= 0))
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(d1_bar <= 0 || d1_bar == g_last_entry_d1_bar)
      return false;
   g_last_entry_d1_bar = d1_bar;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);
   if(close_1 <= 0.0)
      return false;

   double entry_high = 0.0;
   double entry_low = 0.0;
   if(!Strategy_Channel(PERIOD_D1, 2, strategy_entry_channel_days, entry_high, entry_low))
      return false;

   const double atr_now = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double atr_median = Strategy_MedianAtr();
   if(atr_now <= 0.0 || atr_median <= 0.0)
      return false;
   if(atr_now <= atr_median * strategy_atr_median_mult)
      return false;

   int direction = 0;
   if(close_1 > entry_high)
      direction = 1;
   else if(close_1 < entry_low)
      direction = -1;
   else
      return false;

   if(!Strategy_TrendAllowsDirection(direction))
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1236_DONCHIAN55_LONG" : "QM5_1236_DONCHIAN55_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOpenPosition(ticket, ptype, open_price, current_sl, open_time))
      return;

   if(open_price <= 0.0 || current_sl <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const double initial_r = MathAbs(open_price - current_sl);
   if(initial_r <= 0.0)
      return;

   const double profit_distance = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(profit_distance < initial_r * strategy_trail_after_r)
      return;

   double exit_high = 0.0;
   double exit_low = 0.0;
   if(!Strategy_Channel(PERIOD_D1, 1, strategy_exit_channel_days, exit_high, exit_low))
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   if(is_buy)
     {
      const double new_sl = NormalizeDouble(exit_low, _Digits);
      if(new_sl > 0.0 && new_sl > current_sl + point * 0.5 && new_sl < market_price)
         QM_TM_MoveSL(ticket, new_sl, "trail_to_20_day_low_after_1r");
     }
   else
     {
      const double new_sl = NormalizeDouble(exit_high, _Digits);
      if(new_sl > 0.0 && new_sl < current_sl - point * 0.5 && new_sl > market_price)
         QM_TM_MoveSL(ticket, new_sl, "trail_to_20_day_high_after_1r");
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOpenPosition(ticket, ptype, open_price, current_sl, open_time))
      return false;

   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(d1_bar <= 0 || d1_bar == g_last_exit_d1_bar)
      return false;
   g_last_exit_d1_bar = d1_bar;

   if(Strategy_BarsHeld(open_time) >= strategy_max_hold_bars)
      return true;

   double exit_high = 0.0;
   double exit_low = 0.0;
   if(!Strategy_Channel(PERIOD_D1, 2, strategy_exit_channel_days, exit_high, exit_low))
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);
   if(close_1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && close_1 < exit_low)
      return true;
   if(ptype == POSITION_TYPE_SELL && close_1 > exit_high)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1236\",\"ea\":\"gh-donchian-55\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
