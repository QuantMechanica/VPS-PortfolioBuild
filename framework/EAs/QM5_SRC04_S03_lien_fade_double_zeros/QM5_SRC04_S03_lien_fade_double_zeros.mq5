#property strict
#property version   "5.0"
#property description "SRC04_S03 lien-fade-double-zeros v1 (P1 build)"
// Strategy Card: SRC04_S03 (lien-fade-double-zeros), CEO G0 APPROVED.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 4303;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
enum QM5_RiskModeInput
  {
   QM5_RISK_MODE_AUTO = 0,
   QM5_RISK_MODE_FIXED = 1,
   QM5_RISK_MODE_PERCENT = 2
  };
input QM5_RiskModeInput qm_risk_mode      = QM5_RISK_MODE_AUTO;
input double RISK_PERCENT                 = 1.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    trend_ma_period              = 20;   // Card Sec 4 (15m, 20SMA trend filter), PDF p.113
input double entry_offset_pips            = 12.0; // Card Sec 4 (10-15 pip stop-entry offset), PDF p.113
input double stop_offset_pips             = 20.0; // Card Sec 4/Sec 5 (20 pip stop from figure), PDF p.113
input double stage_max_distance_pips      = 50.0; // Card Sec 4 (staging proximity bound chosen for implementation)
input bool   triple_zero_only             = false; // Card Sec 6/Sec 8 optional triple-zero optimization, PDF p.113/p.115
input bool   use_ma_trail_variant         = false; // Card Sec 5 alt trailing variant (MA+offset), PDF p.114
input int    order_expiration_minutes     = 60;    // Card Sec 4 staged stop-order lifecycle

CTrade   g_trade;
datetime g_last_bar_time = 0;

int StrategyMagic()
  {
   // Hard rule: magic derived via framework schema, never hand-computed.
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

double SMAAtShift(const int period, const int shift)
  {
   const int handle = iMA(_Symbol, _Period, period, 0, MODE_SMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   const int copied = CopyBuffer(handle, 0, shift, 1, buffer);
   IndicatorRelease(handle);
   if(copied < 1)
      return 0.0;
   return buffer[0];
  }

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double RoundStep()
  {
   const double pip = PipSize();
   if(pip <= 0.0)
      return 0.0;
   if(triple_zero_only)
      return pip * 1000.0;
   return pip * 100.0;
  }

double NearestRound(const double price)
  {
   const double step = RoundStep();
   if(step <= 0.0)
      return 0.0;
   return MathRound(price / step) * step;
  }

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
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
      ticket = t;
      return true;
     }
   return false;
  }

bool HasOurPendingOrder()
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
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
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

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(0, order_expiration_minutes * 60);

   // Card Sec 6: no pyramiding/single-position discipline.
   ulong pos_ticket;
   if(GetOurPosition(pos_ticket))
      return false;

   // Keep one staged pending order; do not spam duplicate orders each bar.
   if(HasOurPendingOrder())
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double ma1 = SMAAtShift(trend_ma_period, 1);
   if(close1 <= 0.0 || ma1 <= 0.0)
      return false;

   const double pip = PipSize();
   if(pip <= 0.0)
      return false;

   const double round_px = NearestRound(close1);
   if(round_px <= 0.0)
      return false;

   const double dist_pips = MathAbs(close1 - round_px) / pip;
   if(dist_pips > stage_max_distance_pips)
      return false;

   const double entry_buy = round_px + (entry_offset_pips * pip);
   const double sl_buy = round_px - (stop_offset_pips * pip);
   const double tp_buy = entry_buy + MathAbs(entry_buy - sl_buy); // Card Sec 5 TP1 at 1R

   const double entry_sell = round_px - (entry_offset_pips * pip);
   const double sl_sell = round_px + (stop_offset_pips * pip);
   const double tp_sell = entry_sell - MathAbs(sl_sell - entry_sell); // Card Sec 5 TP1 at 1R

   // Card Sec 4 long: price below MA, stage buy-stop above figure.
   if(close1 < ma1 && close1 < round_px)
     {
      req.type = QM_BUY_STOP;
      req.price = entry_buy;
      req.sl = sl_buy;
      req.tp = tp_buy;
      req.reason = "SRC04_S03_LONG_STOP";
      return true;
     }

   // Card Sec 4 short: price above MA, stage sell-stop below figure.
   if(close1 > ma1 && close1 > round_px)
     {
      req.type = QM_SELL_STOP;
      req.price = entry_sell;
      req.sl = sl_sell;
      req.tp = tp_sell;
      req.reason = "SRC04_S03_SHORT_STOP";
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
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pip = PipSize();
   if(point <= 0.0 || pip <= 0.0)
      return;

   // Card Sec 5: risk amount is entry-offset + stop-offset around round number.
   const double one_r = (entry_offset_pips + stop_offset_pips) * pip;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double vol = PositionGetDouble(POSITION_VOLUME);
   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double new_sl = sl_now;
   if(ptype == POSITION_TYPE_BUY)
     {
      const bool tp1_reached = (bid - open_price >= one_r);
      const bool be_already = (sl_now >= (open_price - 2.0 * point));
      if(tp1_reached && !be_already && vol >= (2.0 * min_lot))
        {
         // Card Sec 5: close half at 1R and move remainder to BE.
         g_trade.SetExpertMagicNumber(StrategyMagic());
         g_trade.PositionClosePartial(_Symbol, vol * 0.5, 20);
        }
      if(tp1_reached)
         new_sl = MathMax(new_sl, open_price);
      if(use_ma_trail_variant)
        {
         const double ma = SMAAtShift(trend_ma_period, 1);
         if(ma > 0.0)
            new_sl = MathMax(new_sl, ma - 10.0 * pip); // Card Sec 5 alt trail from worked example.
        }
      else
        {
         const double low2 = iLow(_Symbol, _Period, 2);
         if(low2 > 0.0)
            new_sl = MathMax(new_sl, low2); // Card Sec 5 default 2-bar trail interpretation.
        }
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      const bool tp1_reached = (open_price - ask >= one_r);
      const bool be_already = (sl_now > 0.0 && sl_now <= (open_price + 2.0 * point));
      if(tp1_reached && !be_already && vol >= (2.0 * min_lot))
        {
         g_trade.SetExpertMagicNumber(StrategyMagic());
         g_trade.PositionClosePartial(_Symbol, vol * 0.5, 20);
        }
      if(tp1_reached)
         new_sl = (new_sl <= 0.0) ? open_price : MathMin(new_sl, open_price);
      if(use_ma_trail_variant)
        {
         const double ma = SMAAtShift(trend_ma_period, 1);
         if(ma > 0.0)
            new_sl = (new_sl <= 0.0) ? ma + 10.0 * pip : MathMin(new_sl, ma + 10.0 * pip);
        }
      else
        {
         const double high2 = iHigh(_Symbol, _Period, 2);
         if(high2 > 0.0)
            new_sl = (new_sl <= 0.0) ? high2 : MathMin(new_sl, high2);
        }
     }

   if(new_sl > 0.0 && MathAbs(new_sl - sl_now) > (2.0 * point))
     {
      g_trade.SetExpertMagicNumber(StrategyMagic());
      g_trade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
     }
  }

bool Strategy_ExitSignal()
  {
   // Card Sec 5 uses protective stop + TP1/BE/trailing path, no standalone discretionary exit.
   return false;
  }

bool ExecuteEntrySignal(const QM_EntryRequest &req)
  {
   ulong out_ticket = 0;
   return (QM_Entry(req, out_ticket) == QM_ENTRY_OK);
  }

int OnInit()
  {
   // Card Sec 7 + V5 hard rule: both risk inputs present; ENV selects active mode.
   QM5_RiskModeInput selected_mode = qm_risk_mode;
   if(selected_mode == QM5_RISK_MODE_AUTO)
      selected_mode = (MQLInfoInteger(MQL_TESTER) != 0) ? QM5_RISK_MODE_FIXED : QM5_RISK_MODE_PERCENT;

   double risk_percent = 0.0;
   double risk_fixed = 0.0;
   if(selected_mode == QM5_RISK_MODE_FIXED)
      risk_fixed = RISK_FIXED;
   else
      risk_percent = RISK_PERCENT;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        risk_percent,
                        risk_fixed,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC04_S03\",\"slug\":\"lien-fade-double-zeros\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   CancelOurPendingOrders();
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
      ExecuteEntrySignal(req);
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
