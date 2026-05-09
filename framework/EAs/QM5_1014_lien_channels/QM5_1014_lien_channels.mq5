#property strict
#property version   "5.0"
#property description "QM5_1014 Lien Channels narrow-range breakout (SRC04_S08)"
// Strategy Card: SRC04_S08 (lien-channels), CEO G0 APPROVED 2026-05-01.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

//--- Framework inputs --------------------------------------------------------

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1014;
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
input int    channel_lookback             = 16;    // Card S4: N-bar lookback (16 ~ 4h M15 Asian session)
input double channel_max_pips             = 30.0;  // Card S4: upper width bound (Lien examples 12/18/30)
input double channel_min_pips             = 10.0;  // Card S4: lower width bound (noise filter)
input double entry_offset_pips            = 10.0;  // Card S4 Rule 2: breakout offset "by 10 pips"
input int    management_mode              = 0;     // Card S5: 0=conservative (TP1+BE+trail), 1=lien_2r_full_exit
input double tp1_rr                       = 1.0;   // Card S5: conservative partial-close at 1R
input double tp_full_rr                   = 2.0;   // Card S5 Rule 4: "double the amount risked"
input int    trail_method                 = 0;     // Card S8: 0=two_bar_extreme, 1=three_bar_extreme

//--- Globals -----------------------------------------------------------------

CTrade   g_trade;
datetime g_last_bar_time = 0;

//--- Utility -----------------------------------------------------------------

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

//--- Position / Order helpers ------------------------------------------------

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
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
      return true;
     }
   return false;
  }

bool HasOurPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
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
   const int magic = QM_FrameworkMagic();
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
      g_trade.OrderDelete(ticket);
     }
  }

//--- Channel computation -----------------------------------------------------

bool ComputeChannel(double &ch_high, double &ch_low, double &width_pips)
  {
   ch_high = 0.0;
   ch_low = 0.0;
   width_pips = 0.0;

   if(channel_lookback < 2)
      return false;

   // Card S4: N-bar horizontal range over completed bars (shift 1..N)
   const int idx_high = iHighest(_Symbol, _Period, MODE_HIGH, channel_lookback, 1);
   const int idx_low  = iLowest(_Symbol, _Period, MODE_LOW, channel_lookback, 1);
   if(idx_high < 0 || idx_low < 0)
      return false;

   ch_high = iHigh(_Symbol, _Period, idx_high);
   ch_low  = iLow(_Symbol, _Period, idx_low);
   if(ch_high <= 0.0 || ch_low <= 0.0 || ch_high <= ch_low)
      return false;

   const double pip = PipSize();
   if(pip <= 0.0)
      return false;

   width_pips = (ch_high - ch_low) / pip;
   return true;
  }

//--- 4-Module Strategy Functions ---------------------------------------------

// Card S4: evaluate channel validity for bracket entry.
// Returns channel bounds; bracket placement handled by PlaceBracketOrders.
bool Strategy_EntrySignal(double &ch_high, double &ch_low)
  {
   double width_pips = 0.0;
   if(!ComputeChannel(ch_high, ch_low, width_pips))
      return false;

   // Card S4: channel_min_pips <= width <= channel_max_pips
   if(width_pips < channel_min_pips || width_pips > channel_max_pips)
      return false;

   return true;
  }

// Card S4: place bracket stop orders at channel boundaries +/- offset.
// Both sides share the same risk (channel_width + offset) so lot size is identical.
bool PlaceBracketOrders(const double ch_high, const double ch_low)
  {
   const double pip = PipSize();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip <= 0.0 || point <= 0.0)
      return false;

   const double offset = entry_offset_pips * pip;

   // Card S4 Rule 2: buy stop above upper channel line
   const double entry_buy = ch_high + offset;
   // Card S4 Rule 3: stop at lower channel line
   const double sl_buy    = ch_low;
   const double risk_buy  = entry_buy - sl_buy;
   // Card S5: TP at tp_full_rr * risk (serves as R-reference in conservative mode too)
   const double tp_buy    = entry_buy + tp_full_rr * risk_buy;

   // Card S4 Rule 4: short rules are the reverse
   const double entry_sell = ch_low - offset;
   const double sl_sell    = ch_high;
   const double risk_sell  = sl_sell - entry_sell;
   const double tp_sell    = entry_sell - tp_full_rr * risk_sell;

   if(risk_buy <= 0.0 || risk_sell <= 0.0)
      return false;
   if(entry_sell <= 0.0 || tp_sell <= 0.0)
      return false;

   const double sl_points = risk_buy / point;
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());

   bool ok = false;
   ok |= g_trade.BuyStop(lots, entry_buy, _Symbol, sl_buy, tp_buy,
                          ORDER_TIME_GTC, 0, "SRC04_S08_BUY");
   ok |= g_trade.SellStop(lots, entry_sell, _Symbol, sl_sell, tp_sell,
                           ORDER_TIME_GTC, 0, "SRC04_S08_SELL");
   return ok;
  }

// Card S5: conservative management (TP1 + BE + trail) or 2R full exit.
void Strategy_ManageOpenPosition(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return;

   // lien_2r_full_exit: TP at 2R handles everything
   if(management_mode == 1)
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl_now     = PositionGetDouble(POSITION_SL);
   const double tp_now     = PositionGetDouble(POSITION_TP);
   const double vol        = PositionGetDouble(POSITION_VOLUME);
   const double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double min_lot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double vol_step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(point <= 0.0 || tp_now <= 0.0)
      return;

   // Derive 1R from the 2R TP set at entry
   const double risk_price = MathAbs(tp_now - open_price) / tp_full_rr;
   if(risk_price <= 0.0)
      return;

   g_trade.SetExpertMagicNumber(QM_FrameworkMagic());
   double new_sl = sl_now;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double target_1r = open_price + tp1_rr * risk_price;
      const bool   tp1_hit   = (bid >= target_1r);
      const bool   at_be     = (sl_now >= open_price - 2.0 * point);

      // Card S5: close half at TP1, move remainder to BE
      if(tp1_hit && !at_be && vol >= 2.0 * min_lot)
        {
         double half = MathFloor(vol / 2.0 / vol_step) * vol_step;
         if(half >= min_lot && half < vol)
            g_trade.PositionClosePartial(ticket, half, 20);
        }

      if(tp1_hit)
         new_sl = MathMax(new_sl, open_price);

      // Card S8: trail remainder after BE reached
      if(tp1_hit || at_be)
        {
         const int trail_bar = (trail_method == 1) ? 3 : 2;
         const double trail_val = iLow(_Symbol, _Period, trail_bar);
         if(trail_val > 0.0)
            new_sl = MathMax(new_sl, trail_val);
        }
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      const double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double target_1r = open_price - tp1_rr * risk_price;
      const bool   tp1_hit   = (ask <= target_1r);
      const bool   at_be     = (sl_now > 0.0 && sl_now <= open_price + 2.0 * point);

      if(tp1_hit && !at_be && vol >= 2.0 * min_lot)
        {
         double half = MathFloor(vol / 2.0 / vol_step) * vol_step;
         if(half >= min_lot && half < vol)
            g_trade.PositionClosePartial(ticket, half, 20);
        }

      if(tp1_hit)
         new_sl = (new_sl <= 0.0) ? open_price : MathMin(new_sl, open_price);

      if(tp1_hit || at_be)
        {
         const int trail_bar = (trail_method == 1) ? 3 : 2;
         const double trail_val = iHigh(_Symbol, _Period, trail_bar);
         if(trail_val > 0.0)
            new_sl = (new_sl <= 0.0) ? trail_val : MathMin(new_sl, trail_val);
        }
     }

   if(new_sl > 0.0 && MathAbs(new_sl - sl_now) > 2.0 * point)
      g_trade.PositionModify(ticket, new_sl, tp_now);
  }

// Card S5: no standalone exit signal; exits via SL/TP/trail
bool Strategy_ExitSignal(ulong ticket)
  {
   return false;
  }

//--- Event handlers ----------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC04_S08\",\"slug\":\"lien-channels\"}");
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

   // Card S6: single-position discipline — cancel unfilled bracket side on fill
   ulong pos_ticket;
   if(GetOurPosition(pos_ticket) && HasOurPendingOrders())
      CancelOurPendingOrders();

   if(!IsNewBar())
      return;

   // Manage existing position
   if(GetOurPosition(pos_ticket))
     {
      Strategy_ManageOpenPosition(pos_ticket);
      return;
     }

   // No position: cancel stale bracket, re-evaluate channel, place new bracket
   CancelOurPendingOrders();

   double ch_high = 0.0, ch_low = 0.0;
   if(Strategy_EntrySignal(ch_high, ch_low))
      PlaceBracketOrders(ch_high, ch_low);
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
