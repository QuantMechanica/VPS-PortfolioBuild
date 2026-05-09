#property strict
#property version   "5.0"
#property description "QM5_1014 lien-channels (SRC04_S08)"
// Strategy Card ID: SRC04_S08 (lien-channels), CEO G0 APPROVED 2026-05-01.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1014;
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
input int    channel_lookback_bars        = 16;   // Card §4 (CHANNEL_LOOKBACK default).
input double channel_min_pips             = 10.0; // Card §4 (CHANNEL_MIN_PIPS default).
input double channel_max_pips             = 30.0; // Card §4 (CHANNEL_MAX_PIPS default).
input double entry_offset_pips            = 10.0; // Card §4 rule 2 + reverse-rule mirror.
input int    pending_validity_bars        = 1;    // Card §4: bracket valid for next session/bar cycle.
input bool   conservative_management       = true; // Card §5 + §7 default: TP1+BE+trail; false => full 2R.
input double tp1_rr                        = 1.0; // Card §5 commentary: exit half at amount risked.
input double tp_full_rr                    = 2.0; // Card §5 rule 4 verbatim: double risk.

CTrade   g_trade;
datetime g_last_bar_time = 0;
ulong    g_tp1_done_ticket = 0;

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
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket, double &open_price, double &volume, double &sl, double &tp)
  {
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
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
      if(!sent)
         QM_LogEvent(QM_WARN, "PENDING_CANCEL_SEND_FAIL", StringFormat("{\"order\":%I64u,\"retcode\":%u}", t, res.retcode));
     }
  }

bool ComputeChannel(double &channel_high, double &channel_low)
  {
   if(channel_lookback_bars < 2)
      return false;

   channel_high = -DBL_MAX;
   channel_low = DBL_MAX;

   for(int shift = 1; shift <= channel_lookback_bars; ++shift)
     {
      const double h = iHigh(_Symbol, _Period, shift);
      const double l = iLow(_Symbol, _Period, shift);
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(h > channel_high)
         channel_high = h;
      if(l < channel_low)
         channel_low = l;
     }

   return (channel_high > channel_low);
  }

bool PlaceStopOrder(const ENUM_ORDER_TYPE order_type, const double entry, const double sl, const double tp)
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
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = (tp > 0.0) ? NormalizeDouble(tp, _Digits) : 0.0;
   req.deviation = 20;
   req.type_time = ORDER_TIME_SPECIFIED;
   req.expiration = TimeCurrent() + (pending_validity_bars * PeriodSeconds(_Period));
   req.type_filling = ORDER_FILLING_RETURN;
   req.comment = "SRC04_S08";

   if(!OrderSend(req, res))
      return false;

   return (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED);
  }

void StageBracketOrders()
  {
   double channel_high = 0.0;
   double channel_low = 0.0;
   if(!ComputeChannel(channel_high, channel_low))
      return;

   const double pip = PipSize();
   if(pip <= 0.0)
      return;

   const double channel_width_pips = (channel_high - channel_low) / pip;
   // Card §4 rule 1 + parameter block: trade only narrow channels in configured pip band.
   if(channel_width_pips < channel_min_pips || channel_width_pips > channel_max_pips)
      return;

   // Card §4 rules 2/4 (PDF pp.139-140): bracket at channel +/- 10 pips, short side mirrored.
   const double buy_entry = channel_high + entry_offset_pips * pip;
   const double sell_entry = channel_low - entry_offset_pips * pip;
   const double buy_sl = channel_low;
   const double sell_sl = channel_high;

   const double buy_risk = buy_entry - buy_sl;
   const double sell_risk = sell_sl - sell_entry;
   if(buy_risk <= 0.0 || sell_risk <= 0.0)
      return;

   const double buy_tp = conservative_management ? 0.0 : (buy_entry + tp_full_rr * buy_risk);
   const double sell_tp = conservative_management ? 0.0 : (sell_entry - tp_full_rr * sell_risk);

   CancelOurPendingOrders();
   const bool buy_ok = PlaceStopOrder(ORDER_TYPE_BUY_STOP, buy_entry, buy_sl, buy_tp);
   const bool sell_ok = PlaceStopOrder(ORDER_TYPE_SELL_STOP, sell_entry, sell_sl, sell_tp);
   if(!buy_ok && !sell_ok)
      return;

   g_tp1_done_ticket = 0;
  }

void ApplyConservativeManagement(const ENUM_POSITION_TYPE ptype,
                                 const ulong ticket,
                                 const double open_price,
                                 const double volume,
                                 const double sl_now)
  {
   if(!conservative_management)
      return;

   if(sl_now <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   const double risk = (ptype == POSITION_TYPE_BUY) ? (open_price - sl_now) : (sl_now - open_price);
   if(risk <= 0.0)
      return;

   const double favorable = (ptype == POSITION_TYPE_BUY) ? (bid - open_price) : (open_price - ask);
   const bool tp1_hit = (favorable >= tp1_rr * risk);

   g_trade.SetExpertMagicNumber(StrategyMagic());

   if(tp1_hit && g_tp1_done_ticket != ticket)
     {
      const double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(vol_min > 0.0 && vol_step > 0.0)
        {
         double close_vol = MathFloor((volume * 0.5) / vol_step) * vol_step;
         close_vol = NormalizeDouble(close_vol, 8);
         if(close_vol >= vol_min && (volume - close_vol) >= vol_min)
            g_trade.PositionClosePartial(ticket, close_vol);
        }

      const double be = NormalizeDouble(open_price, _Digits);
      g_trade.PositionModify(_Symbol, be, 0.0);
      g_tp1_done_ticket = ticket;
     }

   if(g_tp1_done_ticket != ticket)
      return;

   // Card §5 + §7 (conservative mode): trail remainder; implementation default = 2-bar extreme.
   double new_sl = sl_now;
   if(ptype == POSITION_TYPE_BUY)
     {
      const double low2 = iLow(_Symbol, _Period, 2);
      if(low2 > 0.0)
         new_sl = MathMax(new_sl, low2);
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      const double high2 = iHigh(_Symbol, _Period, 2);
      if(high2 > 0.0)
         new_sl = MathMin(new_sl, high2);
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point > 0.0 && MathAbs(new_sl - sl_now) > (2.0 * point))
      g_trade.PositionModify(_Symbol, NormalizeDouble(new_sl, _Digits), 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price = 0.0, volume = 0.0, sl = 0.0, tp = 0.0;
   if(!GetOurPosition(ptype, ticket, open_price, volume, sl, tp))
      return;

   // Card §7: one active position after first trigger; cancel opposite bracket side.
   CancelOurPendingOrders();
   ApplyConservativeManagement(ptype, ticket, open_price, volume, sl);
  }

void Strategy_EntrySignal()
  {
   if(HasOurPendingOrder())
      return;
   StageBracketOrders();
  }

bool Strategy_ExitSignal()
  {
   // Card §5: exits are mechanical via SL/TP and conservative management rules only.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC04_S08\",\"ea\":\"QM5_1014_lien_channels\"}");
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
   double open_price = 0.0, volume = 0.0, sl = 0.0, tp = 0.0;
   if(GetOurPosition(ptype, ticket, open_price, volume, sl, tp))
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
