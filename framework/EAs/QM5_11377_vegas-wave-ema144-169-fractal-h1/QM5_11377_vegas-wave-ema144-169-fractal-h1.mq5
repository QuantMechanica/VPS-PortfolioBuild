#property strict
#property version   "5.0"
#property description "QM5_11377 Vegas Wave EMA144/169 tunnel fractal breakout H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11377 vegas-wave-ema144-169-fractal-h1
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11377_vegas-wave-ema144-169-fractal-h1.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11377;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period      = 144;
input int    strategy_ema_slow_period      = 169;
input int    strategy_fractal_side_bars    = 2;
input int    strategy_atr_period           = 14;
input double strategy_tp1_atr_mult         = 3.0;
input double strategy_tp2_atr_mult         = 5.0;
input double strategy_entry_buffer_pips    = 1.0;
input double strategy_sl_max_pips          = 30.0;
input int    strategy_pending_bars         = 4;
input int    strategy_session_start_hr     = 8;
input int    strategy_session_end_hr       = 19;
input double strategy_spread_cap_pips      = 20.0;

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hour = dt.hour;

   bool in_session = false;
   if(strategy_session_start_hr <= strategy_session_end_hr)
      in_session = (hour >= strategy_session_start_hr && hour < strategy_session_end_hr);
   else
      in_session = (hour >= strategy_session_start_hr || hour < strategy_session_end_hr);
   if(!in_session)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const int spread_cap_pips = (int)MathRound(strategy_spread_cap_pips);
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   for(int order_i = OrdersTotal() - 1; order_i >= 0; --order_i)
     {
      const ulong order_ticket = OrderGetTicket(order_i);
      if(order_ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return false;
     }

   if(strategy_fractal_side_bars < 2)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar state read
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || atr <= 0.0 || close1 <= 0.0)
      return false;

   const int center_shift = strategy_fractal_side_bars + 1;
   const double center_low = iLow(_Symbol, _Period, center_shift); // perf-allowed: bounded Williams fractal pivot
   const double center_high = iHigh(_Symbol, _Period, center_shift); // perf-allowed: bounded Williams fractal pivot
   if(center_low <= 0.0 || center_high <= 0.0)
      return false;

   bool down_fractal = true;
   bool up_fractal = true;
   for(int k = 1; k <= strategy_fractal_side_bars; ++k)
     {
      const double low_newer = iLow(_Symbol, _Period, center_shift - k); // perf-allowed: bounded Williams fractal pivot
      const double low_older = iLow(_Symbol, _Period, center_shift + k); // perf-allowed: bounded Williams fractal pivot
      const double high_newer = iHigh(_Symbol, _Period, center_shift - k); // perf-allowed: bounded Williams fractal pivot
      const double high_older = iHigh(_Symbol, _Period, center_shift + k); // perf-allowed: bounded Williams fractal pivot
      if(low_newer <= 0.0 || low_older <= 0.0 || high_newer <= 0.0 || high_older <= 0.0)
         return false;
      if(!(center_low < low_newer && center_low < low_older))
         down_fractal = false;
      if(!(center_high > high_newer && center_high > high_older))
         up_fractal = false;
     }

   const int buffer_pips = (int)MathRound(strategy_entry_buffer_pips);
   const int sl_cap_pips = (int)MathRound(strategy_sl_max_pips);
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, buffer_pips);
   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol, sl_cap_pips);
   if(buffer <= 0.0 || sl_cap <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double modeled_spread = (ask > bid) ? (ask - bid) : 0.0;

   if(close1 > ema_slow && down_fractal)
     {
      const double entry = center_high + buffer + modeled_spread;
      if(ask > 0.0 && entry <= ask)
         return false;
      double sl = ema_slow;
      if(sl >= entry)
         return false;
      if((entry - sl) > sl_cap)
         sl = entry - sl_cap;

      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr, strategy_tp2_atr_mult);
      req.reason = "vegas_long_down_fractal_breakout";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(_Period);
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
     }

   if(close1 < ema_fast && up_fractal)
     {
      const double entry = center_low - buffer;
      if(bid > 0.0 && entry >= bid)
         return false;
      double sl = ema_fast;
      if(sl <= entry)
         return false;
      if((sl - entry) > sl_cap)
         sl = entry + sl_cap;

      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr, strategy_tp2_atr_mult);
      req.reason = "vegas_short_up_fractal_breakout";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = strategy_pending_bars * PeriodSeconds(_Period);
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Partial close 50% at ATR x 3 and then move the remainder to break-even.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   const int trigger_pips = (int)MathRound((strategy_tp1_atr_mult * atr) / (point * pip_factor));
   if(trigger_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market_price <= 0.0 || volume <= 0.0)
         continue;

      const bool already_be = (current_sl > 0.0 &&
                               (is_buy ? (current_sl >= open_price - point * 0.5)
                                       : (current_sl <= open_price + point * 0.5)));
      if(already_be)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(moved < strategy_tp1_atr_mult * atr)
         continue;

      QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL);
      QM_TM_MoveToBreakEven(ticket, trigger_pips, 1);
     }
  }

// No discretionary close beyond SL, TP2, TP1 partial, break-even, and framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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

   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
