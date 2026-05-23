#property strict
#property version   "5.0"
#property description "QM5_1237 TradingView SuperTrend ATR Flip"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1237;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_H1;
input int             strategy_atr_period      = 10;
input double          strategy_st_mult         = 3.0;
input int             strategy_ema_period      = 200;
input int             strategy_median_atr_bars = 240;
input double          strategy_atr_floor_mult  = 0.60;
input int             strategy_max_hold_bars   = 96;
input int             strategy_spread_days     = 20;
input double          strategy_spread_mult     = 2.0;

datetime g_last_manage_bar = 0;
datetime g_last_exit_bar   = 0;
bool     g_exit_now        = false;

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double MedianAtr()
  {
   if(strategy_median_atr_bars < 1)
      return 0.0;

   double values[];
   ArrayResize(values, strategy_median_atr_bars);
   int count = 0;
   for(int shift = 1; shift <= strategy_median_atr_bars; ++shift)
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(atr > 0.0)
        {
         values[count] = atr;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;
   ArrayResize(values, count);
   ArraySort(values);

   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

double MedianSpreadForEntryHour()
  {
   const datetime entry_bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(entry_bar_time <= 0 || strategy_spread_days <= 0)
      return 0.0;

   MqlDateTime entry_dt;
   TimeToStruct(entry_bar_time, entry_dt);

   const int max_shift = MathMax(1, strategy_spread_days * 24);
   double values[];
   ArrayResize(values, max_shift);
   int count = 0;
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const datetime t = iTime(_Symbol, strategy_timeframe, shift);
      if(t <= 0)
         continue;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      if(dt.hour != entry_dt.hour)
         continue;

      const double spread = (double)iSpread(_Symbol, strategy_timeframe, shift);
      if(spread > 0.0)
        {
         values[count] = spread;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;
   ArrayResize(values, count);
   ArraySort(values);

   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool ReadSuperTrend(const int target_shift, double &line, int &direction)
  {
   line = 0.0;
   direction = 0;

   const int warmup = MathMax(strategy_median_atr_bars, strategy_ema_period) + 20;
   if(Bars(_Symbol, strategy_timeframe) < warmup + target_shift + 5)
      return false;

   double final_upper = 0.0;
   double final_lower = 0.0;
   int dir = 0;

   for(int shift = warmup + target_shift; shift >= target_shift; --shift)
     {
      const double high = iHigh(_Symbol, strategy_timeframe, shift);
      const double low = iLow(_Symbol, strategy_timeframe, shift);
      const double close = iClose(_Symbol, strategy_timeframe, shift);
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         return false;

      const double midpoint = (high + low) * 0.5;
      const double basic_upper = midpoint + strategy_st_mult * atr;
      const double basic_lower = midpoint - strategy_st_mult * atr;

      if(dir == 0)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         dir = (close >= midpoint) ? 1 : -1;
        }
      else
        {
         const double prev_final_upper = final_upper;
         const double prev_final_lower = final_lower;
         const double prev_close = iClose(_Symbol, strategy_timeframe, shift + 1);

         final_upper = (basic_upper < prev_final_upper || prev_close > prev_final_upper) ? basic_upper : prev_final_upper;
         final_lower = (basic_lower > prev_final_lower || prev_close < prev_final_lower) ? basic_lower : prev_final_lower;

         if(dir < 0 && close > final_upper)
            dir = 1;
         else if(dir > 0 && close < final_lower)
            dir = -1;
        }

      line = (dir > 0) ? final_lower : final_upper;
      direction = dir;
     }

   return (line > 0.0 && direction != 0);
  }

bool FridayEntryWindowBlocked()
  {
   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(bar_time <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   return (dt.day_of_week == 5 && dt.hour >= qm_friday_close_hour_broker - 2);
  }

bool Strategy_NoTradeFilter()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(SelectOurPosition(ticket, ptype, open_time))
      return false;

   return FridayEntryWindowBlocked();
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

   if(strategy_timeframe != PERIOD_H1)
      return false;
   if(Bars(_Symbol, strategy_timeframe) < strategy_median_atr_bars + strategy_ema_period + 10)
      return false;
   if(FridayEntryWindowBlocked())
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double median_atr = MedianAtr();
   if(atr <= 0.0 || median_atr <= 0.0 || atr <= median_atr * strategy_atr_floor_mult)
      return false;

   const double median_spread = MedianSpreadForEntryHour();
   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread > 0.0 && current_spread > median_spread * strategy_spread_mult)
      return false;

   double st_line_1 = 0.0;
   double st_line_2 = 0.0;
   int dir_1 = 0;
   int dir_2 = 0;
   if(!ReadSuperTrend(1, st_line_1, dir_1) || !ReadSuperTrend(2, st_line_2, dir_2))
      return false;

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double ema_200 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(close_1 <= 0.0 || ema_200 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(dir_2 < 0 && dir_1 > 0 && close_1 > ema_200)
     {
      const double disaster_sl = ask - strategy_st_mult * atr;
      req.type = QM_BUY;
      req.sl = NormalizeDouble(MathMax(st_line_1, disaster_sl), _Digits);
      if(req.sl <= 0.0 || req.sl >= ask - point)
         return false;
      req.reason = "SUPERTrend_flip_long";
      return true;
     }

   if(dir_2 > 0 && dir_1 < 0 && close_1 < ema_200)
     {
      const double disaster_sl = bid + strategy_st_mult * atr;
      req.type = QM_SELL;
      req.sl = NormalizeDouble(MathMin(st_line_1, disaster_sl), _Digits);
      if(req.sl <= bid + point)
         return false;
      req.reason = "SUPERTrend_flip_short";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 0);
   if(bar_time <= 0 || bar_time == g_last_manage_bar)
      return;
   g_last_manage_bar = bar_time;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!SelectOurPosition(ticket, ptype, open_time))
      return;

   double st_line = 0.0;
   int dir = 0;
   if(!ReadSuperTrend(1, st_line, dir))
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || st_line <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY && st_line < bid - point)
     {
      if(current_sl <= 0.0 || st_line > current_sl + point * 0.5)
         QM_TM_MoveSL(ticket, st_line, "supertrend_trail_long");
     }
   else if(ptype == POSITION_TYPE_SELL && st_line > ask + point)
     {
      if(current_sl <= 0.0 || st_line < current_sl - point * 0.5)
         QM_TM_MoveSL(ticket, st_line, "supertrend_trail_short");
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 0);
   if(bar_time <= 0)
      return false;
   if(bar_time == g_last_exit_bar)
      return g_exit_now;

   g_last_exit_bar = bar_time;
   g_exit_now = false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!SelectOurPosition(ticket, ptype, open_time))
      return false;

   const int open_shift = iBarShift(_Symbol, strategy_timeframe, open_time, false);
   if(open_shift >= strategy_max_hold_bars)
     {
      g_exit_now = true;
      return true;
     }

   double st_line_1 = 0.0;
   double st_line_2 = 0.0;
   int dir_1 = 0;
   int dir_2 = 0;
   if(!ReadSuperTrend(1, st_line_1, dir_1) || !ReadSuperTrend(2, st_line_2, dir_2))
      return false;

   if(ptype == POSITION_TYPE_BUY && dir_2 > 0 && dir_1 < 0)
      g_exit_now = true;
   else if(ptype == POSITION_TYPE_SELL && dir_2 < 0 && dir_1 > 0)
      g_exit_now = true;

   return g_exit_now;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1237\",\"ea\":\"QM5_1237_tv-supertrend-atr\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
