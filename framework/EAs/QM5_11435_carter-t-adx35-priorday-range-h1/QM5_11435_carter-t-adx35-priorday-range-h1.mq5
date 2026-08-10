#property strict
#property version   "5.0"
#property description "QM5_11435 Carter-T ADX<35 Prior-Day Range OCO Stop Entry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11435
// Source: Thomas Carter, "20 Multi-Timeframe Trading Systems", Strategy #11.
// Card: cards_approved/QM5_11435_carter-t-adx35-priorday-range-h1.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11435;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_adx_period             = 14;
input double strategy_adx_threshold          = 35.0;
input double strategy_offset_pips            = 15.0;
input double strategy_tp_pips                = 60.0;
input double strategy_sl_pips                = 30.0;
input double strategy_sl_cap_pips            = 40.0;
input int    strategy_eod_cancel_hour_broker = 18;
input int    strategy_max_spread_pips        = 20;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Always allows management (OCO
// cancel-other-on-fill, EOD cancel) of an already-open position or a pending
// bracket leg; spread cap applies only to fresh bracket placement.
bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic > 0)
   {
      if(QM_EntryHasOpenPosition(magic, _Symbol))
         return false;
      if(QM_EntryHasPendingOrder(magic, _Symbol, ORDER_TYPE_BUY_STOP))
         return false;
      if(QM_EntryHasPendingOrder(magic, _Symbol, ORDER_TYPE_SELL_STOP))
         return false;
   }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(spread_cap <= 0.0)
      return true;
   if((ask - bid) > spread_cap)
      return true;

   return false;
}

// Places the OCO BUYSTOP/SELLSTOP bracket directly (two orders, not one) and
// always returns false — the single-req wiring contract does not fit a
// bracket pair, so this hook issues both legs itself via QM_TM_OpenPosition.
// The framework's own pending-order duplicate guard (QM_EntryHasPendingOrder,
// scoped per order type) makes re-calling this every new bar idempotent.
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
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   double adx_1 = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx_1 <= 0.0 || adx_1 >= strategy_adx_threshold)
      return false;

   double prior_day_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed
   double prior_day_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed
   if(prior_day_high <= 0.0 || prior_day_low <= 0.0)
      return false;

   double offset_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_offset_pips));
   double sl_pips_final = MathMin(strategy_sl_pips, strategy_sl_cap_pips);
   double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(sl_pips_final));
   double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_tp_pips));
   if(offset_dist <= 0.0 || sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   double buy_entry  = prior_day_high + offset_dist;
   double sell_entry = prior_day_low - offset_dist;

   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = buy_entry - sl_dist;
   buy_req.tp = buy_entry + tp_dist;
   buy_req.reason = "CARTER_ADX_PRIORDAY_BUYSTOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = 0;
   ulong buy_ticket = 0;
   QM_TM_OpenPosition(buy_req, buy_ticket);

   QM_EntryRequest sell_req;
   sell_req.type = QM_SELL_STOP;
   sell_req.price = sell_entry;
   sell_req.sl = sell_entry + sl_dist;
   sell_req.tp = sell_entry - tp_dist;
   sell_req.reason = "CARTER_ADX_PRIORDAY_SELLSTOP";
   sell_req.symbol_slot = qm_magic_slot_offset;
   sell_req.expiration_seconds = 0;
   ulong sell_ticket = 0;
   QM_TM_OpenPosition(sell_req, sell_ticket);

   return false;
}

// OCO: once one leg fills, cancel the other. EOD: cancel any unfilled leg at
// strategy_eod_cancel_hour_broker.
void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   if(QM_EntryHasOpenPosition(magic, _Symbol))
   {
      for(int i = OrdersTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         QM_OrderType type = QM_OrderTypeFromMT5((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
         if(QM_OrderTypeIsStop(type) || QM_OrderTypeIsLimit(type))
            QM_TM_RemovePendingOrder(ticket, "oco_other_side_filled");
      }
      return;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_eod_cancel_hour_broker)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      QM_OrderType type = QM_OrderTypeFromMT5((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
      if(QM_OrderTypeIsStop(type) || QM_OrderTypeIsLimit(type))
         QM_TM_RemovePendingOrder(ticket, "eod_cancel_unfilled_bracket");
   }
}

// SL/TP are set on each stop order at placement; no discretionary exit.
bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

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

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

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
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
