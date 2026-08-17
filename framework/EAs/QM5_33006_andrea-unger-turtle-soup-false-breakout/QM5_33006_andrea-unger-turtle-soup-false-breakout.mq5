#property strict
#property version   "5.0"
#property description "QM5_33006 Andrea Unger Turtle Soup False Breakout Fade"
// Strategy Card: QM5_33006 (andrea-unger-turtle-soup-false-breakout), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_33006
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 33006;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.5;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_period     = 20;   // Donchian extreme lookback period (days)
input int    strategy_tp_lookback         = 10;   // Target extreme lookback period (days)
input int    strategy_buffer_ticks        = 1;    // Tick buffer for pending stop placement
input int    strategy_atr_period          = 14;   // Spread filter ATR period
input double strategy_spread_atr_mult     = 1.8;  // Spread filter threshold

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

void CancelOurPendingOrders(const string reason = "")
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic) continue;

      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP ||
         ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
      {
         CTrade trade;
         trade.OrderDelete(ticket);
      }
   }
}

bool HasOurPendingOrder()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic) continue;

      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP)
         return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
         return true;
   }
   return false;
}

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

   CancelOurPendingOrders("daily_new_bar_refresh");

   if(QM_TM_OpenPositionCount(magic) > 0 || HasOurPendingOrder())
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const int hh_idx = iHighest(_Symbol, PERIOD_D1, MODE_HIGH, strategy_lookback_period, 2);
   const int ll_idx = iLowest(_Symbol, PERIOD_D1, MODE_LOW, strategy_lookback_period, 2);
   if(hh_idx < 0 || ll_idx < 0)
      return false;

   const double high_20 = iHigh(_Symbol, PERIOD_D1, hh_idx); // perf-allowed: closed-D1 20-bar lookback extreme behind QM_IsNewBar()
   const double low_20  = iLow(_Symbol, PERIOD_D1, ll_idx);  // perf-allowed: closed-D1 20-bar lookback extreme behind QM_IsNewBar()
   const double high_1  = iHigh(_Symbol, PERIOD_D1, 1);       // perf-allowed: closed-D1 trigger bar high behind QM_IsNewBar()
   const double low_1   = iLow(_Symbol, PERIOD_D1, 1);        // perf-allowed: closed-D1 trigger bar low behind QM_IsNewBar()
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);      // perf-allowed: closed-D1 trigger bar close behind QM_IsNewBar()

   if(high_20 <= 0.0 || low_20 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || close_1 <= 0.0)
      return false;

   const double buffer = strategy_buffer_ticks * point;

   // Long condition: Low[1] < Low_20 AND Close[1] > Low_20 -> BUY_STOP at Low_20 + 1 tick
   if(low_1 < low_20 && close_1 > low_20)
   {
      const int tp_hh_idx = iHighest(_Symbol, PERIOD_D1, MODE_HIGH, strategy_tp_lookback, 1);
      if(tp_hh_idx < 0) return false;
      const double tp_price = iHigh(_Symbol, PERIOD_D1, tp_hh_idx); // perf-allowed: closed-D1 10-bar TP extreme behind QM_IsNewBar()
      const double buy_trigger = low_20 + buffer;
      const double sl_price    = low_1 - 2.0 * buffer;

      if(buy_trigger > ask + point && sl_price < buy_trigger && tp_price > buy_trigger)
      {
         req.type = QM_BUY_STOP;
         req.price = QM_StopRulesNormalizePrice(_Symbol, buy_trigger);
         req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_price);
         req.tp = QM_StopRulesNormalizePrice(_Symbol, tp_price);
         req.reason = "QM5_33006_LONG_TS";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 86400; // 24h
         return true;
      }
   }

   // Short condition: High[1] > High_20 AND Close[1] < High_20 -> SELL_STOP at High_20 - 1 tick
   if(high_1 > high_20 && close_1 < high_20)
   {
      const int tp_ll_idx = iLowest(_Symbol, PERIOD_D1, MODE_LOW, strategy_tp_lookback, 1);
      if(tp_ll_idx < 0) return false;
      const double tp_price = iLow(_Symbol, PERIOD_D1, tp_ll_idx); // perf-allowed: closed-D1 10-bar TP extreme behind QM_IsNewBar()
      const double sell_trigger = high_20 - buffer;
      const double sl_price     = high_1 + 2.0 * buffer;

      if(sell_trigger < bid - point && sl_price > sell_trigger && tp_price < sell_trigger)
      {
         req.type = QM_SELL_STOP;
         req.price = QM_StopRulesNormalizePrice(_Symbol, sell_trigger);
         req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_price);
         req.tp = QM_StopRulesNormalizePrice(_Symbol, tp_price);
         req.reason = "QM5_33006_SHORT_TS";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 86400; // 24h
         return true;
      }
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int pos_count = QM_TM_OpenPositionCount(magic);
   if(pos_count > 0)
   {
      CancelOurPendingOrders("oco_cancel");
   }
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
   {
      QM_EquityStreamOnNewBar();
   }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!is_new_bar) return;

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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
