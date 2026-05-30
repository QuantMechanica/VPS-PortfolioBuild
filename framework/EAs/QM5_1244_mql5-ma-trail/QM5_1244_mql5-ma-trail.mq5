#property strict
#property version   "5.0"
#property description "QM5_1244 MQL5 Moving Average Trail"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1244;
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
input ENUM_TIMEFRAMES strategy_timeframe        = PERIOD_H1;
input int             strategy_fast_sma_period  = 50;
input int             strategy_slow_sma_period  = 200;
input int             strategy_atr_period       = 14;
input double          strategy_initial_stop_atr = 2.0;
input double          strategy_trail_trigger_r  = 1.0;
input double          strategy_trail_sma_atr    = 0.5;
input double          strategy_take_profit_r    = 2.5;
input int             strategy_max_hold_bars    = 96;
input int             strategy_min_history_bars = 260;
input double          strategy_min_sma_gap_atr  = 0.3;
input int             strategy_spread_days      = 20;
input double          strategy_spread_mult      = 2.0;

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
   if(Bars(_Symbol, strategy_timeframe) < strategy_min_history_bars)
      return false;
   if(FridayEntryWindowBlocked())
      return false;

   const double fast_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double fast_2 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 2);
   const double slow_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1);
   const double atr_1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double close_2 = iClose(_Symbol, strategy_timeframe, 2);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || atr_1 <= 0.0 ||
      close_1 <= 0.0 || close_2 <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(MathAbs(fast_1 - slow_1) < strategy_min_sma_gap_atr * atr_1)
      return false;

   const double median_spread = MedianSpreadForEntryHour();
   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread > 0.0 && current_spread > median_spread * strategy_spread_mult)
      return false;

   const double stop_distance = strategy_initial_stop_atr * atr_1;
   if(stop_distance <= point)
      return false;

   if(close_2 <= fast_2 && close_1 > fast_1 && fast_1 > slow_1)
     {
      req.type = QM_BUY;
      req.sl = NormalizeDouble(ask - stop_distance, _Digits);
      req.tp = NormalizeDouble(ask + strategy_take_profit_r * stop_distance, _Digits);
      if(req.sl <= 0.0 || req.sl >= ask - point || req.tp <= ask + point)
         return false;
      req.reason = "ma_trail_long";
      return true;
     }

   if(close_2 >= fast_2 && close_1 < fast_1 && fast_1 < slow_1)
     {
      req.type = QM_SELL;
      req.sl = NormalizeDouble(bid + stop_distance, _Digits);
      req.tp = NormalizeDouble(bid - strategy_take_profit_r * stop_distance, _Digits);
      if(req.sl <= bid + point || req.tp >= bid - point)
         return false;
      req.reason = "ma_trail_short";
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

   const double fast_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double atr_1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(fast_1 <= 0.0 || atr_1 <= 0.0 || open_price <= 0.0 || current_sl <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double initial_r = open_price - current_sl;
      if(initial_r <= point || (bid - open_price) < strategy_trail_trigger_r * initial_r)
         return;

      const double trail_sl = NormalizeDouble(fast_1 - strategy_trail_sma_atr * atr_1, _Digits);
      if(trail_sl > current_sl + point * 0.5 && trail_sl < bid - point)
         QM_TM_SendSLTPModify(ticket, trail_sl, current_tp, "ma_trail_long");
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      const double initial_r = current_sl - open_price;
      if(initial_r <= point || (open_price - ask) < strategy_trail_trigger_r * initial_r)
         return;

      const double trail_sl = NormalizeDouble(fast_1 + strategy_trail_sma_atr * atr_1, _Digits);
      if(trail_sl < current_sl - point * 0.5 && trail_sl > ask + point)
         QM_TM_SendSLTPModify(ticket, trail_sl, current_tp, "ma_trail_short");
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

   const double fast_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   if(fast_1 <= 0.0 || close_1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && close_1 < fast_1)
      g_exit_now = true;
   else if(ptype == POSITION_TYPE_SELL && close_1 > fast_1)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1244\",\"ea\":\"QM5_1244_mql5-ma-trail\"}");
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
