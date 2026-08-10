#property strict
#property version   "5.0"
#property description "QM5_11457 Goodwin — 6-Day Extreme -> 3-Day Stop Entry (D1)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11457;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_extreme_lookback       = 6;
input int    strategy_stop_lookback          = 3;
input int    strategy_hold_bars              = 4;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input double strategy_atr_tp_mult            = 2.0;
input int    strategy_sl_cap_pips            = 100;
input int    strategy_max_spread_pips        = 25;

// -----------------------------------------------------------------------------
// Card: Andrew Goodwin, "Trading Secrets of the Inner Circle" (1997), Strategy
// 6. Source: D:/QM/strategy_farm/artifacts/cards_approved/
// QM5_11457_goodwin-6day-extreme-3day-stop-entry-d1.md
//
// A new extreme_lookback-bar closing extreme (weakness/strength) arms a
// stop-order entry at the stop_lookback-bar closing extreme in the recovery
// direction (BUYSTOP after a low, SELLSTOP after a high) -- only enter if
// price actually starts recovering. Re-evaluated and re-placed once per D1
// bar (cancel-and-replace) since the trigger condition and stop price both
// change daily. Fixed ATR(14) SL and TP; hard time exit after
// strategy_hold_bars D1 bars if neither TP nor SL was hit.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_extreme_lookback <= 0 ||
      strategy_stop_lookback <= 0 ||
      strategy_hold_bars <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 ||
      strategy_sl_cap_pips <= 0)
      return true;

   if(strategy_max_spread_pips > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double max_spread_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(ask > bid && max_spread_dist > 0.0 && (ask - bid) > max_spread_dist)
         return true;
     }
   return false;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_IsOurPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

void Strategy_CancelOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      MqlTradeRequest request;
      ZeroMemory(request);
      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;
      request.symbol = _Symbol;
      request.comment = reason;

      MqlTradeResult result;
      string error_class = BROKER_OTHER;
      const bool ok = QM_TradeContextSend(request, result, error_class);
      QM_LogEvent(ok ? QM_INFO : QM_WARN, "PENDING_CANCEL",
                  StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u}",
                               ticket, QM_LoggerEscapeJson(reason), ok ? "true" : "false", result.retcode));
     }
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOpenPosition())
      Strategy_CancelOurPendingStops("position_open_cancel_pending");
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_entry = iBarShift(_Symbol, PERIOD_CURRENT, open_time, false);
      if(bars_since_entry >= strategy_hold_bars)
         return true;
     }
   return false;
  }

// Re-evaluate once per D1 bar: cancel yesterday's unfilled pending order
// (price levels are stale) and, if the trigger condition still holds,
// arm a fresh stop order for today.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   Strategy_CancelOurPendingStops("daily_reevaluate");

   const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(close_1 <= 0.0)
      return false;

   double lowest6 = 0.0;
   double highest6 = 0.0;
   bool have6 = false;
   for(int s = 2; s <= strategy_extreme_lookback + 1; ++s)
     {
      const double c = iClose(_Symbol, PERIOD_CURRENT, s);
      if(c <= 0.0)
         continue;
      if(!have6)
        {
         lowest6 = c;
         highest6 = c;
         have6 = true;
        }
      else
        {
         if(c < lowest6) lowest6 = c;
         if(c > highest6) highest6 = c;
        }
     }
   if(!have6)
      return false;

   const bool long_trigger  = (close_1 < lowest6);
   const bool short_trigger = (close_1 > highest6);
   if(!long_trigger && !short_trigger)
      return false;

   double lowest3 = 0.0;
   double highest3 = 0.0;
   bool have3 = false;
   for(int s = 2; s <= strategy_stop_lookback + 1; ++s)
     {
      const double c = iClose(_Symbol, PERIOD_CURRENT, s);
      if(c <= 0.0)
         continue;
      if(!have3)
        {
         lowest3 = c;
         highest3 = c;
         have3 = true;
        }
      else
        {
         if(c < lowest3) lowest3 = c;
         if(c > highest3) highest3 = c;
        }
     }
   if(!have3)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(_Symbol, strategy_atr_period, 1, atr_value) || atr_value <= 0.0)
      return false;

   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double sl_dist_raw = atr_value * strategy_atr_sl_mult;
   const double sl_dist = (cap_dist > 0.0) ? MathMin(sl_dist_raw, cap_dist) : sl_dist_raw;
   const double tp_dist = atr_value * strategy_atr_tp_mult;
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   if(long_trigger)
     {
      const double stop_price = NormalizeDouble(highest3, _Digits);
      if(stop_price <= ask + point)
         return false;

      req.type = QM_BUY_STOP;
      req.price = stop_price;
      req.sl = NormalizeDouble(stop_price - sl_dist, _Digits);
      req.tp = NormalizeDouble(stop_price + tp_dist, _Digits);
      req.reason = "GOODWIN_6DAY_EXTREME_BUYSTOP";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   const double stop_price = NormalizeDouble(lowest3, _Digits);
   if(stop_price >= bid - point)
      return false;

   req.type = QM_SELL_STOP;
   req.price = stop_price;
   req.sl = NormalizeDouble(stop_price + sl_dist, _Digits);
   req.tp = NormalizeDouble(stop_price - tp_dist, _Digits);
   req.reason = "GOODWIN_6DAY_EXTREME_SELLSTOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
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
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }

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
