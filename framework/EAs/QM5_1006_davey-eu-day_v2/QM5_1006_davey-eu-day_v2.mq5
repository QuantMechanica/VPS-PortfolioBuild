#property strict
#property version   "5.1"
#property description "QM5_1006 Davey EU Day v2 (SRC01_S02)"
// Strategy Card: SRC01_S02 (davey-eu-day), CEO G0 APPROVED 2026-04-27.
// QUA-1607 v2 scope: entry-only gate relaxation after validated P2 zero-trade review.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1006;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_xb                  = 5;      // Card §8 + §4, pp. 259-261 (App C): highest/lowest window.
input int    strategy_xb2                 = 80;     // Card §8 + §4, pp. 259-261: momentum lookback close[xb2].
input int    strategy_pipadd              = 8;      // Card §8 + §4, pp. 259-261: limit offset pipadd/10000.
input double strategy_stopl_usd           = 425.0;  // Card §8 + §5, pp. 259-261; Ch18 p.157: fixed dollar stop.
input double strategy_proft_usd           = 5000.0; // Card §8 + §5, pp. 259-261; Ch18 p.157: fixed dollar target.
input int    strategy_time_cutoff_hhmm    = 2000;   // QUA-1607 entry-only v2: widen session gate to increase eligible H1 bars while preserving Card trigger structure (§4 + §6, pp. 259-261).

CTrade   g_trade;
datetime g_last_bar_time = 0;
datetime g_last_session_bar_time = 0;
bool     g_trade_taken_today = false;

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0)
      return false;
   if(t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

void RefreshTradeDayState()
  {
   // Card Build Notes: tradestoday reset occurs on the new session-start H1 bar at 13:00 broker.
   const datetime bar_t = iTime(_Symbol, _Period, 1);
   if(bar_t <= 0)
      return;

   if(Hhmm(bar_t) == 1300 && bar_t != g_last_session_bar_time)
     {
      // Card §4 + §6, pp. 259-261: tradestoday resets on session/day change.
      g_last_session_bar_time = bar_t;
      g_trade_taken_today = false;
     }
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
      g_trade_taken_today = true;
      return true;
     }

   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

bool CancelOurPendingOrders()
  {
   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT)
         continue;

      if(!g_trade.OrderDelete(t))
         all_ok = false;
     }
   return all_ok;
  }

double TickValuePriceDistancePerLot(const double dollars)
  {
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(dollars <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return (dollars * tick_size / tick_value);
  }

double HighestHigh(const int bars)
  {
   if(bars <= 0)
      return 0.0;
   double hi = -DBL_MAX;
   for(int i = 1; i <= bars; ++i)
      hi = MathMax(hi, iHigh(_Symbol, _Period, i));
   return hi;
  }

double LowestLow(const int bars)
  {
   if(bars <= 0)
      return 0.0;
   double lo = DBL_MAX;
   for(int i = 1; i <= bars; ++i)
      lo = MathMin(lo, iLow(_Symbol, _Period, i));
   return lo;
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

   RefreshTradeDayState();

   // Card §6, pp. 259-261: one-trade-per-day + time-of-day gate.
   if(g_trade_taken_today)
      return false;

   const datetime bar_t = iTime(_Symbol, _Period, 1);
   if(bar_t <= 0 || Hhmm(bar_t) >= strategy_time_cutoff_hhmm)
      return false;

   if(strategy_xb < 1 || strategy_xb2 < 1)
      return false;

   const double c1 = iClose(_Symbol, _Period, 1);
   const double cmom = iClose(_Symbol, _Period, 1 + strategy_xb2);
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   if(c1 <= 0.0 || cmom <= 0.0 || h1 <= 0.0 || l1 <= 0.0)
      return false;

   const double hi = HighestHigh(strategy_xb);
   const double lo = LowestLow(strategy_xb);
   if(hi <= 0.0 || lo <= 0.0)
      return false;

   const double pip_offset = strategy_pipadd / 10000.0;
   const double stop_dist = TickValuePriceDistancePerLot(strategy_stopl_usd);
   const double tp_dist = TickValuePriceDistancePerLot(strategy_proft_usd);
   if(pip_offset <= 0.0 || stop_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   // Card §4, pp. 259-261: short limit at high + pipadd when fresh high and momentum down.
   if(h1 >= hi && c1 < cmom)
     {
      req.type = QM_SELL;
      req.price = h1 + pip_offset;
      req.sl = req.price + stop_dist;
      req.tp = req.price - tp_dist;
      req.reason = "SRC01_S02_SHORT_LIMIT";
      return true;
     }

   // Card §4, pp. 259-261: long limit at low - pipadd when fresh low and momentum up.
   if(l1 <= lo && c1 > cmom)
     {
      req.type = QM_BUY;
      req.price = l1 - pip_offset;
      req.sl = req.price - stop_dist;
      req.tp = req.price + tp_dist;
      req.reason = "SRC01_S02_LONG_LIMIT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card §7, pp. 259-261: no trailing/partial/BE logic.
  }

bool Strategy_ExitSignal()
  {
   // Card §5 + §12: no discretionary exit signal; exits via SL/TP and framework Friday close.
   return false;
  }

bool PlaceLimitEntry(const QM_EntryRequest &req)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   const double sl_points = MathAbs(req.price - req.sl) / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   bool ok = false;
   if(req.type == QM_BUY)
      ok = g_trade.BuyLimit(lots, req.price, _Symbol, req.sl, req.tp, ORDER_TIME_GTC, 0, req.reason);
   else
      ok = g_trade.SellLimit(lots, req.price, _Symbol, req.sl, req.tp, ORDER_TIME_GTC, 0, req.reason);

   if(ok)
      g_trade_taken_today = true;
   return ok;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC01_S02\",\"ea\":\"QM5_1006_davey_eu_day_v2\"}");
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

   RefreshTradeDayState();

   ENUM_POSITION_TYPE ptype;
   double price_open;
   ulong ticket;
   GetOurPosition(ptype, price_open, ticket);

   if(!IsNewBar())
      return;

   // Card Build Notes: cancel unfilled day-strategy limit orders on the next H1 bar.
   CancelOurPendingOrders();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   if(HasOurPendingOrder())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
      PlaceLimitEntry(req);
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
