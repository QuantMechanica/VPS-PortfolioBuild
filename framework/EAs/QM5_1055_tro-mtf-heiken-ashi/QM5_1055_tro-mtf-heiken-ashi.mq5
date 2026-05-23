#property strict
#property version   "5.0"
#property description "QM5_1055 TRO Multi-TimeFrame Heiken Ashi"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1055;
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
input int    strategy_has_period         = 6;
input int    strategy_ha_lookback_bars   = 80;
input int    strategy_sl_buffer_points   = 15;
input int    strategy_spread_cap_points  = 20;
input bool   strategy_exit_on_h1_flip    = false;
input bool   strategy_use_session_filter = false;
input int    strategy_london_start_hour  = 7;
input int    strategy_ny_end_hour        = 21;

#define QM5_1055_HA_CACHE_MAX 8

string   g_ha_cache_key[QM5_1055_HA_CACHE_MAX];
datetime g_ha_cache_bar_time[QM5_1055_HA_CACHE_MAX];
int      g_ha_cache_dir[QM5_1055_HA_CACHE_MAX];
double   g_ha_cache_open[QM5_1055_HA_CACHE_MAX];
double   g_ha_cache_high[QM5_1055_HA_CACHE_MAX];
double   g_ha_cache_low[QM5_1055_HA_CACHE_MAX];
double   g_ha_cache_close[QM5_1055_HA_CACHE_MAX];
int      g_ha_cache_count = 0;

double QmNormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

int QmBrokerHour()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
  }

bool QmHasOurPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool QmReadOhlc(const string symbol,
                const ENUM_TIMEFRAMES tf,
                const int shift,
                const bool smoothed,
                double &open_price,
                double &high_price,
                double &low_price,
                double &close_price)
  {
   if(shift < 1)
      return false;

   if(smoothed)
     {
      open_price = QM_EMA(symbol, tf, strategy_has_period, shift, PRICE_OPEN);
      high_price = QM_EMA(symbol, tf, strategy_has_period, shift, PRICE_HIGH);
      low_price = QM_EMA(symbol, tf, strategy_has_period, shift, PRICE_LOW);
      close_price = QM_EMA(symbol, tf, strategy_has_period, shift, PRICE_CLOSE);
     }
   else
     {
      open_price = iOpen(symbol, tf, shift);
      high_price = iHigh(symbol, tf, shift);
      low_price = iLow(symbol, tf, shift);
      close_price = iClose(symbol, tf, shift);
     }

   return (open_price > 0.0 && high_price > 0.0 && low_price > 0.0 && close_price > 0.0);
  }

bool QmHeikenAshiCandle(const string symbol,
                        const ENUM_TIMEFRAMES tf,
                        const int shift,
                        const bool smoothed,
                        double &ha_open,
                        double &ha_high,
                        double &ha_low,
                        double &ha_close)
  {
   if(shift < 1)
      return false;

   const int bars = Bars(symbol, tf);
   if(bars <= shift + 3)
      return false;

   int start_shift = shift + MathMax(strategy_ha_lookback_bars, 3);
   if(start_shift > bars - 1)
      start_shift = bars - 1;

   double prev_ha_open = 0.0;
   double prev_ha_close = 0.0;
   for(int i = start_shift; i >= shift; --i)
     {
      double o = 0.0, h = 0.0, l = 0.0, c = 0.0;
      if(!QmReadOhlc(symbol, tf, i, smoothed, o, h, l, c))
         return false;

      const double cur_ha_close = (o + h + l + c) / 4.0;
      const double cur_ha_open = (i == start_shift) ? ((o + c) / 2.0) : ((prev_ha_open + prev_ha_close) / 2.0);
      const double cur_ha_high = MathMax(h, MathMax(cur_ha_open, cur_ha_close));
      const double cur_ha_low = MathMin(l, MathMin(cur_ha_open, cur_ha_close));

      prev_ha_open = cur_ha_open;
      prev_ha_close = cur_ha_close;

      if(i == shift)
        {
         ha_open = cur_ha_open;
         ha_high = cur_ha_high;
         ha_low = cur_ha_low;
         ha_close = cur_ha_close;
         return true;
        }
     }

   return false;
  }

int QmHaDirection(const ENUM_TIMEFRAMES tf, const bool smoothed)
  {
   double ha_open = 0.0, ha_high = 0.0, ha_low = 0.0, ha_close = 0.0;
   if(!QmHeikenAshiCandle(_Symbol, tf, 1, smoothed, ha_open, ha_high, ha_low, ha_close))
      return 0;
   if(ha_close > ha_open)
      return 1;
   if(ha_close < ha_open)
      return -1;
   return 0;
  }

bool QmCachedHeikenAshi(const ENUM_TIMEFRAMES tf,
                        const bool smoothed,
                        double &ha_open,
                        double &ha_high,
                        double &ha_low,
                        double &ha_close,
                        int &direction)
  {
   const datetime closed_bar_time = iTime(_Symbol, tf, 1);
   if(closed_bar_time <= 0)
      return false;

   const string key = StringFormat("%s|%d|%d", _Symbol, (int)tf, smoothed ? 1 : 0);
   for(int i = 0; i < g_ha_cache_count; ++i)
     {
      if(g_ha_cache_key[i] != key)
         continue;

      if(g_ha_cache_bar_time[i] == closed_bar_time)
        {
         ha_open = g_ha_cache_open[i];
         ha_high = g_ha_cache_high[i];
         ha_low = g_ha_cache_low[i];
         ha_close = g_ha_cache_close[i];
         direction = g_ha_cache_dir[i];
         return true;
        }

      if(!QmHeikenAshiCandle(_Symbol, tf, 1, smoothed, ha_open, ha_high, ha_low, ha_close))
         return false;

      direction = 0;
      if(ha_close > ha_open)
         direction = 1;
      else if(ha_close < ha_open)
         direction = -1;

      g_ha_cache_bar_time[i] = closed_bar_time;
      g_ha_cache_open[i] = ha_open;
      g_ha_cache_high[i] = ha_high;
      g_ha_cache_low[i] = ha_low;
      g_ha_cache_close[i] = ha_close;
      g_ha_cache_dir[i] = direction;
      return true;
     }

   if(g_ha_cache_count >= QM5_1055_HA_CACHE_MAX)
      return false;

   if(!QmHeikenAshiCandle(_Symbol, tf, 1, smoothed, ha_open, ha_high, ha_low, ha_close))
      return false;

   direction = 0;
   if(ha_close > ha_open)
      direction = 1;
   else if(ha_close < ha_open)
      direction = -1;

   const int slot = g_ha_cache_count;
   g_ha_cache_key[slot] = key;
   g_ha_cache_bar_time[slot] = closed_bar_time;
   g_ha_cache_open[slot] = ha_open;
   g_ha_cache_high[slot] = ha_high;
   g_ha_cache_low[slot] = ha_low;
   g_ha_cache_close[slot] = ha_close;
   g_ha_cache_dir[slot] = direction;
   g_ha_cache_count++;
   return true;
  }

int QmCachedHaDirection(const ENUM_TIMEFRAMES tf, const bool smoothed)
  {
   double ha_open = 0.0, ha_high = 0.0, ha_low = 0.0, ha_close = 0.0;
   int direction = 0;
   if(!QmCachedHeikenAshi(tf, smoothed, ha_open, ha_high, ha_low, ha_close, direction))
      return 0;
   return direction;
  }

bool Strategy_NoTradeFilter()
  {
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread_points > strategy_spread_cap_points)
      return true;

   if(strategy_use_session_filter)
     {
      const int hour = QmBrokerHour();
      if(hour < strategy_london_start_hour || hour >= strategy_ny_end_hour)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M15)
      return false;

   const int h4_dir = QmCachedHaDirection(PERIOD_H4, false);
   const int h1_dir = QmCachedHaDirection(PERIOD_H1, false);
   const int m15_dir = QmCachedHaDirection(PERIOD_M15, false);
   const int has_dir = QmCachedHaDirection(PERIOD_M15, true);

   if(h4_dir == 0 || h1_dir == 0 || m15_dir == 0 || has_dir == 0)
      return false;
   if(!(h4_dir == h1_dir && h1_dir == m15_dir && m15_dir == has_dir))
      return false;

   double h1_ha_open = 0.0, h1_ha_high = 0.0, h1_ha_low = 0.0, h1_ha_close = 0.0;
   int h1_ha_dir = 0;
   if(!QmCachedHeikenAshi(PERIOD_H1, false, h1_ha_open, h1_ha_high, h1_ha_low, h1_ha_close, h1_ha_dir))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(h4_dir > 0)
     {
      const double sl = QmNormalizePrice(h1_ha_low - strategy_sl_buffer_points * point);
      if(sl <= 0.0 || sl >= ask)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "TRO_MTF_HA_LONG";
      return true;
     }

   const double sl = QmNormalizePrice(h1_ha_high + strategy_sl_buffer_points * point);
   if(sl <= 0.0 || sl <= bid)
      return false;
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "TRO_MTF_HA_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close rule.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!QmHasOurPosition(ptype))
      return false;

   const int has_dir = QmCachedHaDirection(PERIOD_M15, true);
   if(has_dir == 0)
      return false;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   if(is_buy && has_dir < 0)
      return true;
   if(!is_buy && has_dir > 0)
      return true;

   if(strategy_exit_on_h1_flip)
     {
      const int h1_dir = QmCachedHaDirection(PERIOD_H1, false);
      if(is_buy && h1_dir < 0)
         return true;
      if(!is_buy && h1_dir > 0)
         return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1055\",\"ea\":\"QM5_1055_tro_mtf_heiken_ashi\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_M15))
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
