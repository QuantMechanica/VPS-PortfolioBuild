#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1383;
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
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_swing_window       = 50;
input int    strategy_macro_window       = 200;
input int    strategy_min_swing_age      = 10;
input int    strategy_atr_period         = 14;
input double strategy_swing_d1_atr_mult  = 3.0;
input double strategy_approach_atr       = 0.40;
input double strategy_tag_atr            = 0.20;
input double strategy_body_ratio         = 0.40;
input double strategy_spread_atr         = 0.40;
input double strategy_sl_atr             = 0.80;
input double strategy_max_sl_atr         = 2.50;
input double strategy_tp_cap_atr         = 5.00;
input double strategy_min_tp_atr         = 2.00;
input double strategy_be_atr             = 1.50;
input double strategy_invalidation_atr   = 0.50;
input int    strategy_time_stop_bars     = 36;
input int    strategy_cooldown_bars      = 24;

double   g_active_level        = 0.0;
double   g_active_shallow      = 0.0;
int      g_active_direction    = 0;
datetime g_active_open_bar     = 0;
datetime g_last_peak_time      = 0;
datetime g_last_trough_time    = 0;
int      g_last_peak_rotation  = 0;
int      g_last_trough_rotation = 0;
datetime g_cooldown_until      = 0;
datetime g_last_history_check  = 0;

bool QS_FindExtreme(const bool want_high, const int window, int &out_shift, double &out_price)
  {
   out_shift = -1;
   out_price = want_high ? -DBL_MAX : DBL_MAX;
   for(int shift = 1; shift <= window; ++shift)
     {
      const double price = want_high ? iHigh(_Symbol, strategy_tf, shift) : iLow(_Symbol, strategy_tf, shift);
      if(price <= 0.0)
         continue;
      if((want_high && price > out_price) || (!want_high && price < out_price))
        {
         out_price = price;
         out_shift = shift;
        }
     }
   return (out_shift > 0 && out_price > 0.0 && out_price != DBL_MAX && out_price != -DBL_MAX);
  }

double QS_Sq9Level(const double swing_price, const int rotation_steps, const bool project_down)
  {
   if(swing_price <= 0.0)
      return 0.0;
   const double root = MathSqrt(swing_price);
   const double delta = 0.5 * (double)rotation_steps;
   const double adjusted = project_down ? (root - delta) : (root + delta);
   if(adjusted <= 0.0)
      return 0.0;
   return adjusted * adjusted;
  }

bool QS_BodyOK(const double open1, const double close1, const double high1, const double low1)
  {
   const double range = high1 - low1;
   if(range <= 0.0)
      return false;
   return (MathAbs(close1 - open1) / range >= strategy_body_ratio);
  }

void QS_UpdateCooldown()
  {
   const datetime now = TimeCurrent();
   const datetime from_time = (g_last_history_check > 0) ? g_last_history_check : (now - 86400 * 30);
   g_last_history_check = now;
   if(!HistorySelect(from_time, now))
      return;

   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) != DEAL_REASON_SL)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const datetime until_time = deal_time + (datetime)(strategy_cooldown_bars * PeriodSeconds(strategy_tf));
      if(until_time > g_cooldown_until)
         g_cooldown_until = until_time;
     }
  }

bool QS_Setup(const bool bullish, double &out_level, double &out_shallow, double &out_swing_target, datetime &out_swing_time, int &out_rotation)
  {
   int peak_shift = -1;
   int trough_shift = -1;
   int macro_high_shift = -1;
   int macro_low_shift = -1;
   double peak = 0.0;
   double trough = 0.0;
   double macro_high = 0.0;
   double macro_low = 0.0;
   if(!QS_FindExtreme(true, strategy_swing_window, peak_shift, peak) ||
      !QS_FindExtreme(false, strategy_swing_window, trough_shift, trough) ||
      !QS_FindExtreme(true, strategy_macro_window, macro_high_shift, macro_high) ||
      !QS_FindExtreme(false, strategy_macro_window, macro_low_shift, macro_low))
      return false;

   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double close2 = iClose(_Symbol, strategy_tf, 2);
   const double open1 = iOpen(_Symbol, strategy_tf, 1);
   const double high1 = iHigh(_Symbol, strategy_tf, 1);
   const double low1 = iLow(_Symbol, strategy_tf, 1);
   const double atr_h4 = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || open1 <= 0.0 || high1 <= low1 || atr_h4 <= 0.0 || atr_d1 <= 0.0)
      return false;
   if((peak - trough) < strategy_swing_d1_atr_mult * atr_d1)
      return false;

   const double macro_mid = (macro_high + macro_low) * 0.5;
   if(bullish)
     {
      if(close1 <= macro_mid || peak_shift < strategy_min_swing_age)
         return false;
      for(int rotation = 1; rotation <= 3; ++rotation)
        {
         const double level = QS_Sq9Level(peak, rotation, true);
         if(level <= 0.0)
            continue;
         if(MathAbs(close1 - level) > strategy_approach_atr * atr_h4)
            continue;
         if((peak - close1) < strategy_min_tp_atr * atr_h4 && rotation == 1)
            continue;
         if(close1 <= level || low1 > level + strategy_tag_atr * atr_h4)
            continue;
         if(close1 <= open1 || close1 <= close2 || !QS_BodyOK(open1, close1, high1, low1))
            continue;
         out_level = level;
         out_shallow = (rotation > 1) ? QS_Sq9Level(peak, rotation - 1, true) : 0.0;
         out_swing_target = peak;
         out_swing_time = iTime(_Symbol, strategy_tf, peak_shift);
         out_rotation = rotation;
         return true;
        }
     }
   else
     {
      if(close1 >= macro_mid || trough_shift < strategy_min_swing_age)
         return false;
      for(int rotation = 1; rotation <= 3; ++rotation)
        {
         const double level = QS_Sq9Level(trough, rotation, false);
         if(level <= 0.0)
            continue;
         if(MathAbs(close1 - level) > strategy_approach_atr * atr_h4)
            continue;
         if((close1 - trough) < strategy_min_tp_atr * atr_h4 && rotation == 1)
            continue;
         if(close1 >= level || high1 < level - strategy_tag_atr * atr_h4)
            continue;
         if(close1 >= open1 || close1 >= close2 || !QS_BodyOK(open1, close1, high1, low1))
            continue;
         out_level = level;
         out_shallow = (rotation > 1) ? QS_Sq9Level(trough, rotation - 1, false) : 0.0;
         out_swing_target = trough;
         out_swing_time = iTime(_Symbol, strategy_tf, trough_shift);
         out_rotation = rotation;
         return true;
        }
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   if(dt.hour >= 22 || dt.hour < 6)
      return true;
   if(g_cooldown_until > 0 && now < g_cooldown_until)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   return ((ask - bid) >= strategy_spread_atr * atr);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   QS_UpdateCooldown();
   if(g_cooldown_until > 0 && TimeCurrent() < g_cooldown_until)
      return false;

   double level = 0.0;
   double shallow = 0.0;
   double swing_target = 0.0;
   datetime swing_time = 0;
   int rotation = 0;
   int direction = 0;
   if(QS_Setup(true, level, shallow, swing_target, swing_time, rotation))
      direction = 1;
   else if(QS_Setup(false, level, shallow, swing_target, swing_time, rotation))
      direction = -1;
   else
      return false;

   if(direction > 0 && g_last_peak_time == swing_time && g_last_peak_rotation == rotation)
      return false;
   if(direction < 0 && g_last_trough_time == swing_time && g_last_trough_rotation == rotation)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   double sl = (direction > 0) ? (level - strategy_sl_atr * atr) : (level + strategy_sl_atr * atr);
   const double max_sl = strategy_max_sl_atr * atr;
   if(direction > 0 && entry - sl > max_sl)
      sl = entry - max_sl;
   if(direction < 0 && sl - entry > max_sl)
      sl = entry + max_sl;

   double tp = swing_target;
   if(direction > 0 && tp - entry > strategy_tp_cap_atr * atr)
      tp = entry + strategy_tp_cap_atr * atr;
   if(direction < 0 && entry - tp > strategy_tp_cap_atr * atr)
      tp = entry - strategy_tp_cap_atr * atr;
   if(direction > 0 && (tp <= entry || sl >= entry))
      return false;
   if(direction < 0 && (tp >= entry || sl <= entry))
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = (direction > 0) ? "sq9_support_bounce_h4" : "sq9_resistance_reject_h4";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_active_level = level;
   g_active_shallow = shallow;
   g_active_direction = direction;
   g_active_open_bar = iTime(_Symbol, strategy_tf, 0);
   if(direction > 0)
     {
      g_last_peak_time = swing_time;
      g_last_peak_rotation = rotation;
     }
   else
     {
      g_last_trough_time = swing_time;
      g_last_trough_rotation = rotation;
     }
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved >= strategy_be_atr * atr)
        {
         if((is_buy && (current_sl <= 0.0 || current_sl < open_price)) ||
            (!is_buy && (current_sl <= 0.0 || current_sl > open_price)))
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "sq9_be_ratchet");
        }

      if(g_active_shallow > 0.0)
        {
         if(is_buy && market >= g_active_shallow && (current_sl <= 0.0 || current_sl < g_active_shallow))
            QM_TM_MoveSL(ticket, NormalizeDouble(g_active_shallow, _Digits), "sq9_trail_shallower_level");
         if(!is_buy && market <= g_active_shallow && (current_sl <= 0.0 || current_sl > g_active_shallow))
            QM_TM_MoveSL(ticket, NormalizeDouble(g_active_shallow, _Digits), "sq9_trail_shallower_level");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_bars = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(held_bars >= strategy_time_stop_bars)
         return true;

      const double close1 = iClose(_Symbol, strategy_tf, 1);
      if(g_active_level > 0.0)
        {
         if(is_buy && close1 < g_active_level - strategy_invalidation_atr * atr)
            return true;
         if(!is_buy && close1 > g_active_level + strategy_invalidation_atr * atr)
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_mode == QM_NEWS_OFF)
      return false;
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode);
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
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
