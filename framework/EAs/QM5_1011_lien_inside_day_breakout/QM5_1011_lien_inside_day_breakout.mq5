#property strict
#property version   "5.0"
#property description "QM5_1011 lien-inside-day-breakout (SRC04_S05)"
// Strategy Card ID: SRC04_S05 (lien-inside-day-breakout), CEO G0 APPROVED 2026-05-01.

#include <QM/QM_Common.mqh>
#include <QM/QM_StopRules.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1011;
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
input int    strategy_inside_days_min    = 2;    // Card §4 (PDF p.123): "at least two inside days".
input double strategy_breakout_offset_pips = 10.0; // Card §4 rule 2 (PDF pp.123-124): 10 pips above/below previous inside day.
input double strategy_reverse_offset_pips  = 10.0; // Card §4 rule 3 (PDF pp.123-124): stop-and-reverse 10 pips beyond nearest inside day.
input double strategy_tp1_rr             = 2.0;  // Card §5 rule 4 (PDF p.123): take profit at double risk.
input double strategy_reverse_lots       = 1.0;  // Card §7 + §12: V5 default is 1; 2-lot variant is P3 sweep only.
input int    strategy_order_expiry_hours = 26;   // Card §4: bracket valid for next session.

CTrade   g_trade;
datetime g_last_bar_time = 0;
bool     g_reversal_done = false;
double   g_reverse_trigger_long = 0.0;
double   g_reverse_trigger_short = 0.0;
ulong    g_tp1_ticket = 0;

int StrategyMagic()
  {
   return QM_Magic(qm_ea_id, qm_magic_slot_offset);
  }

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

bool IsInsideDay(const int shift)
  {
   const double h = iHigh(_Symbol, _Period, shift);
   const double l = iLow(_Symbol, _Period, shift);
   const double hp = iHigh(_Symbol, _Period, shift + 1);
   const double lp = iLow(_Symbol, _Period, shift + 1);
   if(h <= 0.0 || l <= 0.0 || hp <= 0.0 || lp <= 0.0)
      return false;
   return (h <= hp && l >= lp);
  }

int CountInsideStreak()
  {
   int count = 0;
   for(int s = 1; s < 100; ++s)
     {
      if(!IsInsideDay(s))
         break;
      count++;
     }
   return count;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket, double &open_price, double &volume, double &sl)
  {
   const int magic = StrategyMagic();
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
      volume = PositionGetDouble(POSITION_VOLUME);
      sl = PositionGetDouble(POSITION_SL);
      return true;
     }
   return false;
  }

void CancelOurPendingOrders()
  {
   const int magic = StrategyMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
         continue;

      MqlTradeRequest req;
      MqlTradeResult res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_REMOVE;
      req.order = ticket;
      req.magic = magic;
      OrderSend(req, res);
     }
  }

bool PlaceStopOrder(const ENUM_ORDER_TYPE order_type, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - sl) / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action = TRADE_ACTION_PENDING;
   req.symbol = _Symbol;
   req.magic = StrategyMagic();
   req.type = order_type;
   req.volume = lots;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.deviation = 20;
   req.type_time = ORDER_TIME_SPECIFIED;
   req.expiration = TimeCurrent() + (strategy_order_expiry_hours * 3600);
   req.type_filling = ORDER_FILLING_RETURN;
   req.comment = "SRC04_S05";

   if(!OrderSend(req, res))
      return false;
   return (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED);
  }

void StageBracketOrders()
  {
   const int streak = CountInsideStreak();
   if(streak < strategy_inside_days_min)
      return;

   // Card §4 (PDF pp.123-124): "previous inside day" = oldest in cluster, "nearest" = most recent.
   const int oldest_shift = streak;
   const int newest_shift = 1;

   const double prev_high = iHigh(_Symbol, _Period, oldest_shift);
   const double prev_low = iLow(_Symbol, _Period, oldest_shift);
   const double near_high = iHigh(_Symbol, _Period, newest_shift);
   const double near_low = iLow(_Symbol, _Period, newest_shift);
   const double pip = PipSize();
   if(prev_high <= 0.0 || prev_low <= 0.0 || near_high <= 0.0 || near_low <= 0.0 || pip <= 0.0)
      return;

   const double buy_entry = prev_high + strategy_breakout_offset_pips * pip;
   const double sell_entry = prev_low - strategy_breakout_offset_pips * pip;
   const double buy_sl = near_low - strategy_reverse_offset_pips * pip;
   const double sell_sl = near_high + strategy_reverse_offset_pips * pip;

   CancelOurPendingOrders();
   const bool buy_ok = PlaceStopOrder(ORDER_TYPE_BUY_STOP, buy_entry, buy_sl);
   const bool sell_ok = PlaceStopOrder(ORDER_TYPE_SELL_STOP, sell_entry, sell_sl);
   if(!buy_ok && !sell_ok)
      return;

   g_reversal_done = false;
   g_reverse_trigger_long = buy_sl;
   g_reverse_trigger_short = sell_sl;
   g_tp1_ticket = 0;
  }

void ExecuteReverse(const ENUM_POSITION_TYPE ptype, const ulong ticket)
  {
   if(g_reversal_done)
      return;

   const double rev_mult = MathMax(1.0, strategy_reverse_lots);

   g_trade.SetExpertMagicNumber(StrategyMagic());
   if(!g_trade.PositionClose(ticket))
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   req.type = (ptype == POSITION_TYPE_BUY) ? QM_SELL : QM_BUY;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   req.price = (req.type == QM_BUY) ? ask : bid;
   if(req.price <= 0.0)
      return;
   req.sl = (ptype == POSITION_TYPE_BUY) ? g_reverse_trigger_short : g_reverse_trigger_long;
   req.tp = 0.0;
   req.reason = (ptype == POSITION_TYPE_BUY) ? "SRC04_S05_REV_SHORT" : "SRC04_S05_REV_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Card §5 (PDF p.124): stop-and-reverse executes immediately after opposite-side breach.
   ulong out_ticket = 0;
   if(QM_Entry(req, out_ticket) == QM_ENTRY_OK)
     {
      g_reversal_done = true;
      g_tp1_ticket = 0;
      if(rev_mult > 1.0)
         QM_LogEvent(QM_INFO, "REV_LOTS_SWEEP_REQUESTED", StringFormat("{\"requested_mult\":%.2f}", rev_mult));
     }
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price = 0.0, volume = 0.0, sl = 0.0;
   if(!GetOurPosition(ptype, ticket, open_price, volume, sl))
      return;

   CancelOurPendingOrders();

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   // Card §5 (PDF p.124): false-breakout protection via stop-and-reverse at opposite nearest-inside extreme.
   if(ptype == POSITION_TYPE_BUY && bid <= g_reverse_trigger_long)
      ExecuteReverse(ptype, ticket);
   else if(ptype == POSITION_TYPE_SELL && ask >= g_reverse_trigger_short)
      ExecuteReverse(ptype, ticket);

   const double current_price = (ptype == POSITION_TYPE_BUY) ? bid : ask;
   const double risk = (ptype == POSITION_TYPE_BUY) ? (open_price - g_reverse_trigger_long) : (g_reverse_trigger_short - open_price);
   if(risk <= 0.0)
      return;

   // Card §5 rule 4 (PDF p.123): at +2R close half and move SL to breakeven.
   const double favorable = (ptype == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price);
   if(favorable < strategy_tp1_rr * risk || g_tp1_ticket == ticket)
      return;

   const double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vol_min <= 0.0 || vol_step <= 0.0)
      return;

   double close_vol = volume * 0.5;
   close_vol = MathFloor(close_vol / vol_step) * vol_step;
   close_vol = NormalizeDouble(close_vol, 8);
   if(close_vol < vol_min || (volume - close_vol) < vol_min)
      return;

   g_trade.SetExpertMagicNumber(StrategyMagic());
   if(!g_trade.PositionClosePartial(ticket, close_vol))
      return;

   const double be_sl = NormalizeDouble(open_price, _Digits);
   if(ptype == POSITION_TYPE_BUY && (sl <= 0.0 || sl < be_sl))
      g_trade.PositionModify(_Symbol, be_sl, 0.0);
   else if(ptype == POSITION_TYPE_SELL && (sl <= 0.0 || sl > be_sl))
      g_trade.PositionModify(_Symbol, be_sl, 0.0);

   g_tp1_ticket = ticket;
  }

void Strategy_EntrySignal()
  {
   StageBracketOrders();
  }

bool Strategy_ExitSignal()
  {
   // Card §5 + §7: no independent discretionary exit; SL/reversal/TP1-be and framework Friday-close govern exits.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC04_S05\",\"ea\":\"QM5_1011_lien_inside_day_breakout\"}");
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

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price = 0.0, volume = 0.0, sl = 0.0;
   if(GetOurPosition(ptype, ticket, open_price, volume, sl))
      return;

   if(!IsNewBar())
      return;

   Strategy_EntrySignal();
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
