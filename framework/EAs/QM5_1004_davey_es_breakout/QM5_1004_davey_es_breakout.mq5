#property strict
#property version   "5.0"
#property description "QM5_1004 Davey ES Breakout (SRC01_S04) baseline build"

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// Strategy Card ID: SRC01_S04
// Source: Davey Ch13 "A Walk-Forward Primer", pp.117-121.

input group "QuantMechanica V5 Framework"
input int    ea_id                    = 1004;
input int    magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT             = 0.0;
input double RISK_FIXED               = 1000.0;
input double PORTFOLIO_WEIGHT         = 1.0;

input group "News"
input QM_NewsMode news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   friday_close_enabled     = true;
input int    friday_close_hour_broker = 21;

input group "Strategy"
input int    X                        = 9;
input int    Y                        = 5;
input double Z_usd_per_contract       = 600.0;
input double ES_usd_per_point         = 50.0;

enum StrategySignal
  {
   STRAT_NONE = 0,
   STRAT_LONG = 1,
   STRAT_SHORT = 2
  };

CTrade g_trade;

datetime g_last_bar_open_time = 0;
datetime g_last_eval_bar_time = 0;

bool IsNewBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 0);
   if(bar_time <= 0 || bar_time == g_last_bar_open_time)
      return false;
   g_last_bar_open_time = bar_time;
   return true;
  }

double StopDistancePrice()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || ES_usd_per_point <= 0.0 || Z_usd_per_contract <= 0.0)
      return 0.0;

   // Card §8: Z is USD-per-ES-contract; ES 1 point ~= $50 -> Z/50 points baseline mapping.
   const double stop_points = Z_usd_per_contract / ES_usd_per_point;
   return stop_points * point;
  }

bool SelectFrameworkPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket, double &open_price)
  {
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
      ticket = t;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
     }
   return false;
  }

// Card §4 (p.119 corrected code): short on fresh X-day high close, long on fresh Y-day low close.
StrategySignal Strategy_EntrySignal()
  {
   if(Bars(_Symbol, _Period) < MathMax(X, Y) + 5)
      return STRAT_NONE;

   const double close_1 = iClose(_Symbol, _Period, 1);
   if(close_1 <= 0.0)
      return STRAT_NONE;

   const int hi_shift = iHighest(_Symbol, _Period, MODE_CLOSE, X, 1);
   const int lo_shift = iLowest(_Symbol, _Period, MODE_CLOSE, Y, 1);
   if(hi_shift < 0 || lo_shift < 0)
      return STRAT_NONE;

   const double highest_close = iClose(_Symbol, _Period, hi_shift);
   const double lowest_close  = iClose(_Symbol, _Period, lo_shift);
   const double eps = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 0.5;

   if(close_1 >= (highest_close - eps))
      return STRAT_SHORT;
   if(close_1 <= (lowest_close + eps))
      return STRAT_LONG;
   return STRAT_NONE;
  }

// Card §7: no trailing/partial/BE management; keep only fixed stop discipline.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price;
   if(!SelectFrameworkPosition(ptype, ticket, open_price))
      return;

   const double stop_dist = StopDistancePrice();
   if(stop_dist <= 0.0 || open_price <= 0.0)
      return;

   double new_sl = 0.0;
   if(ptype == POSITION_TYPE_BUY)
      new_sl = NormalizeDouble(open_price - stop_dist, _Digits);
   else if(ptype == POSITION_TYPE_SELL)
      new_sl = NormalizeDouble(open_price + stop_dist, _Digits);
   else
      return;

   g_trade.PositionModify(_Symbol, new_sl, 0.0);
  }

// Card §5: no standalone exit signal; exits are stop-loss or opposite-side reversal.
bool Strategy_ExitSignal(const StrategySignal entry_signal)
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price;
   if(!SelectFrameworkPosition(ptype, ticket, open_price))
      return false;

   if((ptype == POSITION_TYPE_BUY && entry_signal == STRAT_SHORT) ||
      (ptype == POSITION_TYPE_SELL && entry_signal == STRAT_LONG))
     {
      return g_trade.PositionClose(ticket);
     }

   return false;
  }

void PlaceEntry(const StrategySignal signal)
  {
   if(signal == STRAT_NONE)
      return;

   const double stop_dist = StopDistancePrice();
   if(stop_dist <= 0.0)
      return;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   req.symbol_slot = magic_slot_offset;
   req.reason = "davey_es_breakout_entry";
   req.expiration_seconds = 0;

   if(signal == STRAT_LONG)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(req.price - stop_dist, _Digits);
      req.tp = 0.0; // Card §5: no profit target.
     }
   else
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(req.price + stop_dist, _Digits);
      req.tp = 0.0; // Card §5: no profit target.
     }

   ulong ticket = 0;
   QM_Entry(req, ticket);
  }

int OnInit()
  {
   if(!QM_FrameworkInit(ea_id,
                        magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        news_mode,
                        friday_close_enabled,
                        friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(!IsNewBar())
      return;

   const datetime closed_bar_time = iTime(_Symbol, _Period, 1);
   if(closed_bar_time <= 0 || closed_bar_time == g_last_eval_bar_time)
      return;
   g_last_eval_bar_time = closed_bar_time;

   const StrategySignal entry_signal = Strategy_EntrySignal();
   const bool exited = Strategy_ExitSignal(entry_signal);

   Strategy_ManageOpenPosition();

   if(exited)
      PlaceEntry(entry_signal);
   else
      PlaceEntry(entry_signal);
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

