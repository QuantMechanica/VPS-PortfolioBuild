#property strict
#property version   "5.0"
#property description "QM5_1010 lien-waiting-deal (SRC04_S04)"
// Strategy Card: SRC04_S04 (lien-waiting-deal), CEO G0 APPROVED 2026-05-01.

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1010;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 1.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    range_start_gmt_hour         = 6;     // Card §3/§4: 06:00 GMT.
input int    range_end_gmt_hour           = 7;     // Card §3/§4: 07:00 GMT.
input int    entry_window_end_gmt_hour    = 21;    // Card §4: default end window.
input int    spike_threshold_pips         = 25;    // Card §4 rule 1.
input int    entry_offset_pips            = 10;    // Card §4 rule 3.
input int    stop_offset_pips             = 25;    // Card §4 rule 4.
input int    tp1_pips                     = 50;    // Card §5 rule 5 TP1.
input double tp2_rr                       = 3.0;   // Card §5: TP2 at 3R.
input int    range_validity_min_pips      = 0;     // Card §6 optional filter.
input bool   gbpusd_only                  = true;  // Card §6: GBPUSD-default deployment.
input int    pending_expiration_minutes   = 120;   // Card §4: session-scoped pending staging.

enum StrategyState
  {
   STATE_BUILD_RANGE = 0,
   STATE_WAIT_SPIKE,
   STATE_WAIT_REVERSE_SHORT,
   STATE_WAIT_REVERSE_LONG,
   STATE_PENDING_PLACED,
   STATE_DONE
  };

CTrade        g_trade;
datetime      g_last_bar_time = 0;
int           g_session_day_key = -1;
StrategyState g_state = STATE_BUILD_RANGE;
double        g_range_high = 0.0;
double        g_range_low = 0.0;
bool          g_tp1_done = false;

int StrategyMagic()
  {
   // Hard rule: magic via framework resolver only.
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
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

int DayKeyUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = StrategyMagic();
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = StrategyMagic();
   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

void CancelOurPendingOrders()
  {
   const int magic = StrategyMagic();
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
      if(ot != ORDER_TYPE_BUY_STOP && ot != ORDER_TYPE_SELL_STOP)
         continue;

      MqlTradeRequest req;
      MqlTradeResult res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_REMOVE;
      req.order = t;
      req.magic = magic;
      const bool sent = OrderSend(req, res);
      if(!sent || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED))
         QM_LogEvent(QM_WARN, "PENDING_CANCEL_FAIL", StringFormat("{\"order\":%I64u,\"retcode\":%u}", t, res.retcode));
     }
  }

bool SymbolAllowedByCard()
  {
   if(!gbpusd_only)
      return true;

   // Card §6: default deployment is GBPUSD-only.
   string s = _Symbol;
   StringToUpper(s);
   return (StringFind(s, "GBPUSD") >= 0);
  }

void ResetSession(const datetime now_utc)
  {
   g_session_day_key = DayKeyUTC(now_utc);
   g_state = STATE_BUILD_RANGE;
   g_range_high = 0.0;
   g_range_low = 0.0;
   g_tp1_done = false;
   CancelOurPendingOrders();
  }

datetime TodayUTCAt(const datetime now_utc, const int hh)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(now_utc, dt);
   dt.hour = hh;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool PlaceStopOrder(const ENUM_ORDER_TYPE type, const double entry, const double sl, const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
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
   req.type = type;
   req.volume = lots;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.deviation = 20;
   req.type_time = ORDER_TIME_SPECIFIED;
   req.expiration = TimeCurrent() + (pending_expiration_minutes * 60);
   req.type_filling = ORDER_FILLING_RETURN;
   req.comment = "SRC04_S04";

   if(!OrderSend(req, res))
      return false;

   return (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED);
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

   if(!SymbolAllowedByCard())
      return false;

   ulong pos_ticket;
   if(GetOurPosition(pos_ticket) || HasOurPendingOrder())
      return false;

   const datetime now_utc = TimeGMT();
   const int day_key = DayKeyUTC(now_utc);
   if(day_key != g_session_day_key)
      ResetSession(now_utc);

   const datetime range_start_utc = TodayUTCAt(now_utc, range_start_gmt_hour);
   const datetime range_end_utc = TodayUTCAt(now_utc, range_end_gmt_hour);
   const datetime entry_end_utc = TodayUTCAt(now_utc, entry_window_end_gmt_hour);

   if(now_utc < range_start_utc)
      return false;

   if(now_utc < range_end_utc)
     {
      // Card §4: collect 06:00-07:00 GMT high/low for session range.
      const double h1 = iHigh(_Symbol, _Period, 1);
      const double l1 = iLow(_Symbol, _Period, 1);
      if(h1 > 0.0 && (g_range_high <= 0.0 || h1 > g_range_high))
         g_range_high = h1;
      if(l1 > 0.0 && (g_range_low <= 0.0 || l1 < g_range_low))
         g_range_low = l1;
      return false;
     }

   if(g_range_high <= 0.0 || g_range_low <= 0.0 || g_range_high <= g_range_low)
      return false;

   const double pip = PipSize();
   if(pip <= 0.0)
      return false;

   if(range_validity_min_pips > 0)
     {
      const double range_pips = (g_range_high - g_range_low) / pip;
      if(range_pips < range_validity_min_pips)
        {
         g_state = STATE_DONE;
         return false;
        }
     }

   if(now_utc > entry_end_utc)
     {
      g_state = STATE_DONE;
      CancelOurPendingOrders();
      return false;
     }

   const double trigger_up = g_range_high + spike_threshold_pips * pip;
   const double trigger_down = g_range_low - spike_threshold_pips * pip;
   const double bar_high = iHigh(_Symbol, _Period, 1);
   const double bar_low = iLow(_Symbol, _Period, 1);

   if(g_state == STATE_BUILD_RANGE)
      g_state = STATE_WAIT_SPIKE;

   // Card §4: first spike side arms the matching reverse sequence.
   if(g_state == STATE_WAIT_SPIKE)
     {
      if(bar_high > trigger_up)
         g_state = STATE_WAIT_REVERSE_SHORT;
      else if(bar_low < trigger_down)
         g_state = STATE_WAIT_REVERSE_LONG;
      return false;
     }

   const double risk_pips = (entry_offset_pips + stop_offset_pips);

   if(g_state == STATE_WAIT_REVERSE_SHORT && bar_low < g_range_low)
     {
      // Card §4 short: reverse through low, sell-stop below low; Card §5 TP1/TP2.
      req.type = QM_SELL;
      req.price = g_range_low - entry_offset_pips * pip;
      req.sl = g_range_low + stop_offset_pips * pip;
      req.tp = req.price - (risk_pips * tp2_rr * pip);
      req.reason = "SRC04_S04_SHORT";
      return true;
     }

   if(g_state == STATE_WAIT_REVERSE_LONG && bar_high > g_range_high)
     {
      // Card §4 long: reverse through high, buy-stop above high; Card §5 TP1/TP2.
      req.type = QM_BUY;
      req.price = g_range_high + entry_offset_pips * pip;
      req.sl = g_range_high - stop_offset_pips * pip;
      req.tp = req.price + (risk_pips * tp2_rr * pip);
      req.reason = "SRC04_S04_LONG";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   if(!GetOurPosition(ticket) || !PositionSelectByTicket(ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl_now = PositionGetDouble(POSITION_SL);
   const double tp_now = PositionGetDouble(POSITION_TP);
   const double vol = PositionGetDouble(POSITION_VOLUME);
   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   const double tp1_dist = QM_StopRulesPipsToPriceDistance(_Symbol, tp1_pips);
   if(tp1_dist <= 0.0 || point <= 0.0)
      return;

   bool tp1_reached = false;
   if(ptype == POSITION_TYPE_BUY)
      tp1_reached = (bid - open_price >= tp1_dist);
   else
      tp1_reached = (open_price - ask >= tp1_dist);

   // Card §5: at +50 pips close half and move stop to breakeven.
   if(tp1_reached && !g_tp1_done)
     {
      g_trade.SetExpertMagicNumber(StrategyMagic());
      if(vol >= (2.0 * min_lot))
         g_trade.PositionClosePartial(_Symbol, vol * 0.5, 20);

      const double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price);
      g_trade.PositionModify(_Symbol, be_sl, tp_now);
      g_tp1_done = true;
      return;
     }

   // Ensure BE stop remains after partial event.
   if(g_tp1_done)
     {
      if(ptype == POSITION_TYPE_BUY && sl_now < (open_price - point))
        {
         g_trade.SetExpertMagicNumber(StrategyMagic());
         g_trade.PositionModify(_Symbol, QM_StopRulesNormalizePrice(_Symbol, open_price), tp_now);
        }
      if(ptype == POSITION_TYPE_SELL && (sl_now <= 0.0 || sl_now > (open_price + point)))
        {
         g_trade.SetExpertMagicNumber(StrategyMagic());
         g_trade.PositionModify(_Symbol, QM_StopRulesNormalizePrice(_Symbol, open_price), tp_now);
        }
     }
  }

bool Strategy_ExitSignal()
  {
   // Card §5: no discretionary close signal; exits via SL/TP/BE and framework Friday close.
   return false;
  }

bool PlaceEntryStopOrder(const QM_EntryRequest &req)
  {
   if(req.price <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   const ENUM_ORDER_TYPE type = (req.type == QM_BUY) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
   const bool ok = PlaceStopOrder(type, req.price, req.sl, req.tp);
   if(ok)
      g_state = STATE_PENDING_PLACED;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC04_S04\",\"ea\":\"QM5_1010_lien_waiting_deal\"}");
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

   if(!IsNewBar())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
      PlaceEntryStopOrder(req);
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
