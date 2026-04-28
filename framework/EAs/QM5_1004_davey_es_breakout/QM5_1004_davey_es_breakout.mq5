#property strict
#property version   "5.0"
#property description "QM5_1004 Davey ES Breakout (SRC01_S04)"
// Strategy Card: SRC01_S04 (davey-es-breakout), CEO G0 APPROVED.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1004;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    breakout_lookback            = 20;   // Card §6
input int    strategy_atr_period                   = 14;   // Card §6
input double atr_stop_mult                = 2.0;  // Card §4/§6

CTrade   g_trade;
datetime g_last_bar_time = 0;

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, double &price_open, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   price_open = 0.0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      ticket = t;
      return true;
     }

   return false;
  }

double ResolveStopDistancePrice()
  {
   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(_Symbol, strategy_atr_period, 1, atr_value))
      return 0.0;

   // Card §4: protective ATR stop from entry.
   const double stop_distance = atr_value * atr_stop_mult;
   if(stop_distance <= 0.0)
      return 0.0;
   return stop_distance;
  }

bool HasLongBreakoutSignal()
  {
   if(breakout_lookback < 2)
      return false;

   // Card §3: previous bar close must break above prior lookback highs.
   const int hh_shift = iHighest(_Symbol, _Period, MODE_HIGH, breakout_lookback, 2);
   if(hh_shift < 0)
      return false;

   const double trigger_close = iClose(_Symbol, _Period, 1);
   const double prior_high = iHigh(_Symbol, _Period, hh_shift);
   return (trigger_close > 0.0 && prior_high > 0.0 && trigger_close > prior_high);
  }

bool HasShortBreakoutSignal()
  {
   if(breakout_lookback < 2)
      return false;

   // Card §3: previous bar close must break below prior lookback lows.
   const int ll_shift = iLowest(_Symbol, _Period, MODE_LOW, breakout_lookback, 2);
   if(ll_shift < 0)
      return false;

   const double trigger_close = iClose(_Symbol, _Period, 1);
   const double prior_low = iLow(_Symbol, _Period, ll_shift);
   return (trigger_close > 0.0 && prior_low > 0.0 && trigger_close < prior_low);
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

   const double stop_distance = ResolveStopDistancePrice();
   if(stop_distance <= 0.0)
      return false;

   if(HasLongBreakoutSignal())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
      req.reason = "SRC01_S04_LONG_BREAKOUT";
      return (req.sl > 0.0);
     }

   if(HasShortBreakoutSignal())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, entry, stop_distance);
      req.reason = "SRC01_S04_SHORT_BREAKOUT";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card §4: no trailing/partial logic; maintain protective stop only.
   ENUM_POSITION_TYPE ptype;
   double price_open;
   ulong ticket;
   if(!GetOurPosition(ptype, price_open, ticket))
      return;

   const double stop_distance = ResolveStopDistancePrice();
   if(stop_distance <= 0.0)
      return;

   const QM_OrderType side = (ptype == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
   const double sl = QM_StopRulesStopFromDistance(_Symbol, side, price_open, stop_distance);
   if(sl <= 0.0)
      return;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   g_trade.PositionModify(_Symbol, sl, 0.0);
  }

bool Strategy_ExitSignal()
  {
   // Card §4/§8: no standalone close signal.
   return false;
  }

bool ExecuteEntrySignal(const QM_EntryRequest &req)
  {
   const double entry = (req.type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || req.sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - req.sl) / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   if(req.type == QM_BUY)
      return g_trade.Buy(lots, _Symbol, 0.0, req.sl, 0.0, req.reason);
   return g_trade.Sell(lots, _Symbol, 0.0, req.sl, 0.0, req.reason);
  }

bool ProcessSignalWithReversal(const QM_EntryRequest &req)
  {
   ENUM_POSITION_TYPE ptype;
   double price_open;
   ulong ticket;

   if(GetOurPosition(ptype, price_open, ticket))
     {
      const bool want_buy = (req.type == QM_BUY);
      const bool have_buy = (ptype == POSITION_TYPE_BUY);
      if(want_buy == have_buy)
         return false;

      // Card §3/§4: opposite breakout closes and reverses.
      g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
      if(!g_trade.PositionClose(ticket))
         return false;
     }

   return ExecuteEntrySignal(req);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC01_S04\",\"ea\":\"QM5_1004_davey_es_breakout\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(!IsNewBar())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
      ProcessSignalWithReversal(req);
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
