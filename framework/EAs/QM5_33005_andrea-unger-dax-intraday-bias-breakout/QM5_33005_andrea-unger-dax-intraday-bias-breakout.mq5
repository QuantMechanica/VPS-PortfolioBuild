#property strict
#property version   "5.0"
#property description "QM5_33005 Andrea Unger DAX Intraday Bias Breakout"
// Strategy Card: QM5_33005 (andrea-unger-dax-intraday-bias-breakout), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_33005
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 33005;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
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
input int    strategy_range_start_hhmm    = 1000; // 09:00 CET = 10:00 Broker
input int    strategy_range_end_hhmm      = 1030; // 09:30 CET = 10:30 Broker (breakout order time)
input int    strategy_exit_time_hhmm      = 1830; // 17:30 CET = 18:30 Broker (intraday close)
input double strategy_breakout_offset     = 3.0;  // Index points beyond range extreme
input double strategy_sl_fraction         = 0.60; // 0.60x Range30 SL
input double strategy_tp_fraction         = 1.80; // 1.80x Range30 TP (1:3.0 R:R)
input int    strategy_atr_period          = 14;
input double strategy_spread_atr_mult     = 1.8;

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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
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

   const datetime bar_0_time = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: M15 bar timing behind QM_IsNewBar()
   if(bar_0_time <= 0) return false;

   const int bar_0_hhmm = GetBarHhmm(bar_0_time);

   // Order placement occurs strictly at the open of the range-end bar (10:30 broker / 09:31 CET)
   if(bar_0_hhmm != strategy_range_end_hhmm)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // Purge any older pending orders before placing fresh daily breakout bracket
   CancelOurPendingOrders("daily_range_breakout_refresh");

   if(QM_TM_OpenPositionCount(magic) > 0 || HasOurPendingOrder())
      return false;

   // Bar [1] = 10:15 M15 bar (09:15 CET), Bar [2] = 10:00 M15 bar (09:00 CET)
   const double h1 = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed: closed-M15 30m range extreme behind QM_IsNewBar()
   const double l1 = iLow(_Symbol, PERIOD_M15, 1);  // perf-allowed: closed-M15 30m range extreme behind QM_IsNewBar()
   const double h2 = iHigh(_Symbol, PERIOD_M15, 2); // perf-allowed: closed-M15 30m range extreme behind QM_IsNewBar()
   const double l2 = iLow(_Symbol, PERIOD_M15, 2);  // perf-allowed: closed-M15 30m range extreme behind QM_IsNewBar()
   if(h1 <= 0.0 || l1 <= 0.0 || h2 <= 0.0 || l2 <= 0.0)
      return false;

   const double high_30 = MathMax(h1, h2);
   const double low_30  = MathMin(l1, l2);
   const double range_30 = high_30 - low_30;
   if(range_30 <= 0.0)
      return false;

   const double buy_trigger  = high_30 + strategy_breakout_offset;
   const double sell_trigger = low_30  - strategy_breakout_offset;
   const double sl_dist      = strategy_sl_fraction * range_30;
   const double tp_dist      = strategy_tp_fraction * range_30;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   if(buy_trigger <= ask + point || sell_trigger >= bid - point)
      return false;

   // Expiration in seconds until intraday session close (18:30 broker)
   MqlDateTime dt_now;
   TimeToStruct(bar_0_time, dt_now);
   const int expiry_seconds = (strategy_exit_time_hhmm / 100 - dt_now.hour) * 3600 +
                              (strategy_exit_time_hhmm % 100 - dt_now.min) * 60;
   if(expiry_seconds <= 0)
      return false;

   // Build Buy Stop request
   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = QM_StopRulesNormalizePrice(_Symbol, buy_trigger);
   buy_req.sl = QM_StopRulesNormalizePrice(_Symbol, buy_trigger - sl_dist);
   buy_req.tp = QM_StopRulesNormalizePrice(_Symbol, buy_trigger + tp_dist);
   buy_req.reason = "QM5_33005_DAX_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = expiry_seconds;

   // Build Sell Stop request
   req.type = QM_SELL_STOP;
   req.price = QM_StopRulesNormalizePrice(_Symbol, sell_trigger);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sell_trigger + sl_dist);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, sell_trigger - tp_dist);
   req.reason = "QM5_33005_DAX_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;

   // Place Buy Stop directly; return true so framework places Sell Stop
   ulong buy_ticket = 0;
   const bool ok = QM_TM_OpenPosition(buy_req, buy_ticket);
   return ok;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int pos_count = QM_TM_OpenPositionCount(magic);
   if(pos_count > 0)
   {
      // OCO enforcement: cancel opposite pending stop order once a position is active
      CancelOurPendingOrders("oco_cancel");
   }

   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);

   // Intraday Session Close: Force close all positions at 17:30 CET (18:30 broker)
   if(hhmm >= strategy_exit_time_hhmm)
   {
      CancelOurPendingOrders("session_end_cancel");

      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
      }
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
