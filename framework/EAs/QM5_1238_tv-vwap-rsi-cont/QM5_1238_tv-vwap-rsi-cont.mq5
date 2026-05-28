#property strict
#property version   "5.0"
#property description "QM5_1238 TradingView VWAP RSI Continuation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1238;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M15;
input int             strategy_atr_period         = 14;
input int             strategy_rsi_period         = 14;
input double          strategy_vwap_touch_atr     = 0.15;
input double          strategy_stop_atr_mult      = 1.20;
input double          strategy_tp_r_mult          = 1.50;
input double          strategy_be_trigger_r       = 1.00;
input int             strategy_max_hold_bars      = 16;
input int             strategy_london_start_hour  = 7;
input int             strategy_london_end_hour    = 17;
input int             strategy_london_offset_hours = 0;
input double          strategy_min_range_h1_atr   = 0.60;
input int             strategy_spread_days        = 20;
input double          strategy_spread_mult        = 2.0;

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

bool SameBrokerDay(const datetime a, const datetime b)
  {
   MqlDateTime da;
   MqlDateTime db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year == db.year && da.mon == db.mon && da.day == db.day);
  }

int LondonHourFromBrokerTime(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time + strategy_london_offset_hours * 3600, dt);
   return dt.hour;
  }

bool InLondonEntryWindow()
  {
   const datetime signal_time = iTime(_Symbol, strategy_timeframe, 1);
   if(signal_time <= 0)
      return false;
   const int hour = LondonHourFromBrokerTime(signal_time);
   return (hour >= strategy_london_start_hour && hour < strategy_london_end_hour);
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

bool SessionStats(const int target_shift, double &vwap, double &session_high, double &session_low)
  {
   vwap = 0.0;
   session_high = 0.0;
   session_low = 0.0;

   const datetime anchor = iTime(_Symbol, strategy_timeframe, target_shift);
   if(anchor <= 0)
      return false;

   double pv_sum = 0.0;
   double vol_sum = 0.0;
   bool initialized = false;

   const int max_bars = 120;
   for(int shift = target_shift; shift < target_shift + max_bars; ++shift)
     {
      const datetime t = iTime(_Symbol, strategy_timeframe, shift);
      if(t <= 0 || !SameBrokerDay(t, anchor))
         break;

      const double high = iHigh(_Symbol, strategy_timeframe, shift);
      const double low = iLow(_Symbol, strategy_timeframe, shift);
      const double close = iClose(_Symbol, strategy_timeframe, shift);
      const long tick_volume = iVolume(_Symbol, strategy_timeframe, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0)
         continue;

      if(!initialized)
        {
         session_high = high;
         session_low = low;
         initialized = true;
        }
      else
        {
         if(high > session_high)
            session_high = high;
         if(low < session_low)
            session_low = low;
        }

      const double volume = (tick_volume > 0) ? (double)tick_volume : 1.0;
      pv_sum += ((high + low + close) / 3.0) * volume;
      vol_sum += volume;
     }

   if(!initialized || vol_sum <= 0.0)
      return false;

   vwap = pv_sum / vol_sum;
   return (vwap > 0.0 && session_high >= session_low);
  }

double MedianSpreadForEntryHour()
  {
   const datetime entry_bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(entry_bar_time <= 0 || strategy_spread_days <= 0)
      return 0.0;

   MqlDateTime entry_dt;
   TimeToStruct(entry_bar_time, entry_dt);

   const int max_shift = MathMax(1, strategy_spread_days * 96);
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

   if(strategy_timeframe != PERIOD_M15)
      return false;
   if(Bars(_Symbol, strategy_timeframe) < 140 || Bars(_Symbol, PERIOD_H1) < strategy_atr_period + 5)
      return false;
   if(FridayEntryWindowBlocked() || !InLondonEntryWindow())
      return false;

   ulong existing_ticket;
   ENUM_POSITION_TYPE existing_type;
   datetime existing_time;
   if(SelectOurPosition(existing_ticket, existing_type, existing_time))
      return false;

   double session_vwap = 0.0;
   double session_high = 0.0;
   double session_low = 0.0;
   if(!SessionStats(1, session_vwap, session_high, session_low))
      return false;

   const double atr_m15 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double rsi = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   if(atr_m15 <= 0.0 || atr_h1 <= 0.0 || rsi <= 0.0)
      return false;
   if((session_high - session_low) < strategy_min_range_h1_atr * atr_h1)
      return false;

   const double median_spread = MedianSpreadForEntryHour();
   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread > 0.0 && current_spread > median_spread * strategy_spread_mult)
      return false;

   const double open_1 = iOpen(_Symbol, strategy_timeframe, 1);
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double low_2 = iLow(_Symbol, strategy_timeframe, 2);
   const double high_2 = iHigh(_Symbol, strategy_timeframe, 2);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open_1 <= 0.0 || close_1 <= 0.0 || low_2 <= 0.0 || high_2 <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = strategy_stop_atr_mult * atr_m15;
   if(stop_distance <= point)
      return false;

   if(close_1 > session_vwap &&
      low_2 <= session_vwap + strategy_vwap_touch_atr * atr_m15 &&
      close_1 > open_1 &&
      rsi >= 50.0 && rsi <= 70.0)
     {
      req.type = QM_BUY;
      req.sl = NormalizeDouble(ask - stop_distance, _Digits);
      req.tp = NormalizeDouble(ask + strategy_tp_r_mult * stop_distance, _Digits);
      if(req.sl <= 0.0 || req.sl >= ask - point || req.tp <= ask + point)
         return false;
      req.reason = "vwap_rsi_cont_long";
      return true;
     }

   if(close_1 < session_vwap &&
      high_2 >= session_vwap - strategy_vwap_touch_atr * atr_m15 &&
      close_1 < open_1 &&
      rsi >= 30.0 && rsi <= 50.0)
     {
      req.type = QM_SELL;
      req.sl = NormalizeDouble(bid + stop_distance, _Digits);
      req.tp = NormalizeDouble(bid - strategy_tp_r_mult * stop_distance, _Digits);
      if(req.sl <= bid + point || req.tp >= bid - point)
         return false;
      req.reason = "vwap_rsi_cont_short";
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

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open_price <= 0.0 || current_sl <= 0.0 || bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double risk = open_price - current_sl;
      if(risk > point && (bid - open_price) >= strategy_be_trigger_r * risk)
        {
         const double be_sl = NormalizeDouble(open_price, _Digits);
         if(be_sl > current_sl + point * 0.5)
            QM_TM_SendSLTPModify(ticket, be_sl, current_tp, "vwap_rsi_be_long");
        }
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      const double risk = current_sl - open_price;
      if(risk > point && (open_price - ask) >= strategy_be_trigger_r * risk)
        {
         const double be_sl = NormalizeDouble(open_price, _Digits);
         if(be_sl < current_sl - point * 0.5)
            QM_TM_SendSLTPModify(ticket, be_sl, current_tp, "vwap_rsi_be_short");
        }
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

   double session_vwap = 0.0;
   double session_high = 0.0;
   double session_low = 0.0;
   if(!SessionStats(1, session_vwap, session_high, session_low))
      return false;

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   if(close_1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && close_1 < session_vwap)
      g_exit_now = true;
   else if(ptype == POSITION_TYPE_SELL && close_1 > session_vwap)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1238\",\"ea\":\"QM5_1238_tv-vwap-rsi-cont\"}");
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
