#property strict
#property version   "5.0"
#property description "QM5_1039 singh-swap-fly (SRC06_S12)"
// Strategy Card ID: SRC06_S12 (singh-swap-fly), APPROVED; Friday-close waiver ratified for EA 1039 only.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1039;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false; // OWNER+CEO ratified waiver for SRC06_S12 / EA 1039 (QUA-1527, QUA-1563).
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf         = PERIOD_D1; // Card §8 default tf=D1.
input double pattern_body_pct_min         = 0.50;      // Card §8 default.
input int    sl_lookback_bars             = 10;        // Card §8 default.
input double be_trigger_rr                = 1.0;       // Card §5 + §8 default.
input double full_exit_rr                 = 3.0;       // Card §5 optional + §8 default.
input double swap_min_pips_per_day        = 1.0;       // Card §8 default.
input bool   enable_full_exit_rr          = true;      // Card §5: optional discretionary 1:3 path.

CTrade g_trade;
datetime g_last_signal_bar_time = 0;

int StrategyMagic()
  {
   return QM_Magic(qm_ea_id, qm_magic_slot_offset);
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

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket, double &open_price, double &sl, double &tp)
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
      return true;
     }
   return false;
  }

bool IsStrongBody(const double o, const double c, const double h, const double l)
  {
   const double range = h - l;
   if(range <= 0.0)
      return false;
   const double body = MathAbs(c - o);
   return ((body / range) >= pattern_body_pct_min);
  }

bool IsThreeWhiteSoldiers(const int shift_start)
  {
   for(int i = 0; i < 3; ++i)
     {
      const int s = shift_start + i;
      const double o = iOpen(_Symbol, strategy_tf, s);
      const double c = iClose(_Symbol, strategy_tf, s);
      const double h = iHigh(_Symbol, strategy_tf, s);
      const double l = iLow(_Symbol, strategy_tf, s);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         return false;
      if(c <= o || !IsStrongBody(o, c, h, l))
         return false;
      if(i > 0)
        {
         const double prev_o = iOpen(_Symbol, strategy_tf, s + 1);
         const double prev_c = iClose(_Symbol, strategy_tf, s + 1);
         if(c <= prev_c)
            return false;
         const double prev_low_body = MathMin(prev_o, prev_c);
         const double prev_high_body = MathMax(prev_o, prev_c);
         if(o < prev_low_body || o > prev_high_body)
            return false;
        }
     }
   return true;
  }

bool IsThreeBlackCrows(const int shift_start)
  {
   for(int i = 0; i < 3; ++i)
     {
      const int s = shift_start + i;
      const double o = iOpen(_Symbol, strategy_tf, s);
      const double c = iClose(_Symbol, strategy_tf, s);
      const double h = iHigh(_Symbol, strategy_tf, s);
      const double l = iLow(_Symbol, strategy_tf, s);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
         return false;
      if(c >= o || !IsStrongBody(o, c, h, l))
         return false;
      if(i > 0)
        {
         const double prev_o = iOpen(_Symbol, strategy_tf, s + 1);
         const double prev_c = iClose(_Symbol, strategy_tf, s + 1);
         if(c >= prev_c)
            return false;
         const double prev_low_body = MathMin(prev_o, prev_c);
         const double prev_high_body = MathMax(prev_o, prev_c);
         if(o < prev_low_body || o > prev_high_body)
            return false;
        }
     }
   return true;
  }

bool SwapAllows(const bool is_long)
  {
   const double pip = PipSize();
   if(pip <= 0.0)
      return false;
   // Card §4/§6: require positive carry and configurable minimum pips/day threshold.
   const double raw = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG) : SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
   const double in_pips = raw / pip;
   return (in_pips >= swap_min_pips_per_day);
  }

bool SubmitMarketOrder(const ENUM_ORDER_TYPE order_type, const double sl, const double tp, const string reason)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (order_type == ORDER_TYPE_BUY) ? ask : bid;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || sl <= 0.0 || point <= 0.0)
      return false;

   const double sl_points = MathAbs(entry - sl) / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.magic = StrategyMagic();
   req.type = order_type;
   req.volume = lots;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = (tp > 0.0) ? QM_StopRulesNormalizePrice(_Symbol, tp) : 0.0;
   req.type_filling = ORDER_FILLING_FOK;
   req.deviation = 20;
   req.comment = reason;

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

   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price = 0.0, sl = 0.0, tp = 0.0;
   if(GetOurPosition(ptype, ticket, open_price, sl, tp) || HasOurPendingOrder())
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_signal_bar_time)
      return false;

   const bool long_setup = IsThreeWhiteSoldiers(1);   // Card §4 LONG setup.
   const bool short_setup = IsThreeBlackCrows(1);     // Card §4 SHORT setup.
   if(!long_setup && !short_setup)
      return false;

   double sl_price = 0.0;
   double tp_price = 0.0;
   bool sent = false;

   if(long_setup && SwapAllows(true))
     {
      const int low_idx = iLowest(_Symbol, strategy_tf, MODE_LOW, sl_lookback_bars, 1);
      sl_price = iLow(_Symbol, strategy_tf, low_idx);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(enable_full_exit_rr && ask > 0.0 && sl_price > 0.0)
         tp_price = ask + (full_exit_rr * (ask - sl_price));
      sent = SubmitMarketOrder(ORDER_TYPE_BUY, sl_price, tp_price, "SRC06_S12_LONG");
     }
   else if(short_setup && SwapAllows(false))
     {
      const int high_idx = iHighest(_Symbol, strategy_tf, MODE_HIGH, sl_lookback_bars, 1);
      sl_price = iHigh(_Symbol, strategy_tf, high_idx);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(enable_full_exit_rr && bid > 0.0 && sl_price > 0.0)
         tp_price = bid - (full_exit_rr * (sl_price - bid));
      sent = SubmitMarketOrder(ORDER_TYPE_SELL, sl_price, tp_price, "SRC06_S12_SHORT");
     }

   if(sent)
      g_last_signal_bar_time = bar_time;

   return sent;
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   double open_price = 0.0, sl_now = 0.0, tp = 0.0;
   if(!GetOurPosition(ptype, ticket, open_price, sl_now, tp))
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
   if(favorable < (be_trigger_rr * risk))
      return;

   // Card §5/§7: move stop to break-even once trade reaches +1R (configurable by be_trigger_rr).
   const double be = NormalizeDouble(open_price, _Digits);
   const bool already_be = (MathAbs(sl_now - be) <= (2.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)));
   if(already_be)
      return;

   g_trade.SetExpertMagicNumber(StrategyMagic());
   g_trade.PositionModify(_Symbol, be, tp);
  }

bool Strategy_ExitSignal()
  {
   // Card §5: exits are by stop/TP mechanics; no extra discretionary close logic in EA core.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC06_S12\",\"ea\":\"QM5_1039_singh_swap_fly\"}");
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

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
