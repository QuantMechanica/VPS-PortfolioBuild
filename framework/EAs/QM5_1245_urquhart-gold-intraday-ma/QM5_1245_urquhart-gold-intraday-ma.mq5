#property strict
#property version   "5.0"
#property description "QM5_1245 Urquhart Gold Intraday MA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1245;
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
input int             strategy_fast_sma_period    = 20;
input int             strategy_slow_sma_period    = 160;
input int             strategy_atr_period         = 96;
input double          strategy_initial_stop_atr   = 2.0;
input bool            strategy_use_trailing_stop  = true;
input double          strategy_trail_trigger_r    = 1.0;
input double          strategy_trail_atr_mult     = 1.5;
input int             strategy_max_hold_bars      = 48;
input int             strategy_session_start_hour = 7;
input int             strategy_session_end_hour   = 22;
input int             strategy_min_history_bars   = 260;

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

bool IsSupportedSymbol()
  {
   return (_Symbol == "XAUUSD.DWX");
  }

bool IsEntrySession()
  {
   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(bar_time <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   return (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
  }

bool Strategy_NoTradeFilter()
  {
   if(!IsSupportedSymbol())
      return true;
   if(_Period != strategy_timeframe)
      return true;
   if(strategy_timeframe != PERIOD_M15)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_fast_sma_period <= 1 || strategy_slow_sma_period <= strategy_fast_sma_period)
      return true;
   if(strategy_atr_period <= 1 || strategy_initial_stop_atr <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0)
      return true;

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

   if(Strategy_NoTradeFilter())
      return false;
   if(!IsEntrySession())
      return false;
   if(Bars(_Symbol, strategy_timeframe) < MathMax(strategy_min_history_bars, strategy_slow_sma_period + strategy_atr_period + 5))
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(SelectOurPosition(ticket, ptype, open_time))
      return false;

   if(g_exit_now && g_last_exit_bar == iTime(_Symbol, strategy_timeframe, 0))
      return false;

   const double fast_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double fast_2 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 2);
   const double slow_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1);
   const double slow_2 = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 2);
   const double atr_1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0 ||
      atr_1 <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = strategy_initial_stop_atr * atr_1;
   if(stop_distance <= point)
      return false;

   const bool cross_up = (fast_1 > slow_1 && fast_2 <= slow_2);
   const bool cross_down = (fast_1 < slow_1 && fast_2 >= slow_2);

   if(cross_up)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(ask - stop_distance, _Digits);
      req.reason = "urquhart_gold_ma_long";
      return (req.sl > 0.0 && req.sl < ask - point);
     }

   if(cross_down)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(bid + stop_distance, _Digits);
      req.reason = "urquhart_gold_ma_short";
      return (req.sl > bid + point);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_use_trailing_stop)
      return;

   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 0);
   if(bar_time <= 0 || bar_time == g_last_manage_bar)
      return;
   g_last_manage_bar = bar_time;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!SelectOurPosition(ticket, ptype, open_time))
      return;

   const double atr_1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(atr_1 <= 0.0 || open_price <= 0.0 || current_sl <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return;

   const double initial_r = strategy_initial_stop_atr * atr_1;
   const double trail_distance = strategy_trail_atr_mult * atr_1;
   if(initial_r <= point || trail_distance <= point)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      if((bid - open_price) < strategy_trail_trigger_r * initial_r)
         return;

      const double trail_sl = NormalizeDouble(bid - trail_distance, _Digits);
      if(trail_sl > current_sl + point * 0.5 && trail_sl < bid - point)
         QM_TM_SendSLTPModify(ticket, trail_sl, current_tp, "urquhart_gold_ma_trail_long");
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      if((open_price - ask) < strategy_trail_trigger_r * initial_r)
         return;

      const double trail_sl = NormalizeDouble(ask + trail_distance, _Digits);
      if(trail_sl < current_sl - point * 0.5 && trail_sl > ask + point)
         QM_TM_SendSLTPModify(ticket, trail_sl, current_tp, "urquhart_gold_ma_trail_short");
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
   const double fast_2 = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 2);
   const double slow_1 = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1);
   const double slow_2 = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 2);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0)
      return false;

   const bool cross_up = (fast_1 > slow_1 && fast_2 <= slow_2);
   const bool cross_down = (fast_1 < slow_1 && fast_2 >= slow_2);

   if(ptype == POSITION_TYPE_BUY && cross_down)
      g_exit_now = true;
   else if(ptype == POSITION_TYPE_SELL && cross_up)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1245\",\"ea\":\"QM5_1245_urquhart-gold-intraday-ma\"}");
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
