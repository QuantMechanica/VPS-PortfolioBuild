#property strict
#property version   "5.0"
#property description "QM5_33002 Larry Williams Volatility Expansion Breakout"
// Strategy Card: QM5_33002 (larry-williams-volatility-expansion-breakout), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_33002
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 33002;
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
input int    strategy_range_lookback      = 10;
input double strategy_compression_thresh  = 0.80;
input double strategy_breakout_fraction   = 0.60;
input double strategy_sl_fraction         = 0.50;
input int    strategy_max_hold_days       = 3;
input int    strategy_atr_period          = 14;
input double strategy_spread_atr_mult     = 1.8;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

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
   MqlDateTime dt;
   TimeToStruct(now, dt);
   const int hhmm = dt.hour * 100 + dt.min;
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
   req.expiration_seconds = 86400;

   // Purge stale unfilled orders on the new daily bar
   CancelOurPendingOrders("new_daily_bar_reset");

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0 || HasOurPendingOrder())
      return false;

   if(strategy_range_lookback <= 0 || strategy_breakout_fraction <= 0.0 || strategy_sl_fraction <= 0.0)
      return false;

   const int total_bars = iBars(_Symbol, PERIOD_D1);
   if(total_bars < strategy_range_lookback + 5)
      return false;

   const double high_1 = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-D1 range construction behind QM_IsNewBar()
   const double low_1 = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: closed-D1 range construction behind QM_IsNewBar()
   const double open_0 = iOpen(_Symbol, PERIOD_D1, 0);  // perf-allowed: current-D1 open price behind QM_IsNewBar()
   if(high_1 <= 0.0 || low_1 <= 0.0 || open_0 <= 0.0)
      return false;

   const double range_1 = high_1 - low_1;
   if(range_1 <= 0.0)
      return false;

   double sum_range = 0.0;
   for(int k = 1; k <= strategy_range_lookback; ++k)
   {
      const double h = iHigh(_Symbol, PERIOD_D1, k); // perf-allowed: closed-D1 range SMA loop behind QM_IsNewBar()
      const double l = iLow(_Symbol, PERIOD_D1, k);  // perf-allowed: closed-D1 range SMA loop behind QM_IsNewBar()
      if(h <= 0.0 || l <= 0.0 || h < l) return false;
      sum_range += (h - l);
   }
   const double sma_range = sum_range / (double)strategy_range_lookback;
   if(sma_range <= 0.0)
      return false;

   // Check Range Compression condition
   if(range_1 >= strategy_compression_thresh * sma_range)
      return false;

   const double buy_trigger = open_0 + strategy_breakout_fraction * range_1;
   const double sell_trigger = open_0 - strategy_breakout_fraction * range_1;
   const double sl_dist = strategy_sl_fraction * range_1;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || sl_dist <= 0.0)
      return false;

   if(buy_trigger <= ask + point || sell_trigger >= bid - point)
      return false;

   // Build Buy Stop request
   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = QM_StopRulesNormalizePrice(_Symbol, buy_trigger);
   buy_req.sl = QM_StopRulesNormalizePrice(_Symbol, buy_trigger - sl_dist);
   buy_req.tp = 0.0;
   buy_req.reason = "QM5_33002_VOL_EXP_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = 86400;

   // Build Sell Stop request
   req.type = QM_SELL_STOP;
   req.price = QM_StopRulesNormalizePrice(_Symbol, sell_trigger);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sell_trigger + sl_dist);
   req.tp = 0.0;
   req.reason = "QM5_33002_VOL_EXP_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 86400;

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
      // OCO enforcement: cancel unfilled opposite stop order once a trade is active
      CancelOurPendingOrders("oco_cancel");
   }

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
      if(open_time <= 0) continue;

      const int bars_held = iBarShift(_Symbol, PERIOD_D1, open_time, false);

      // Max Hold Exit: Force close after strategy_max_hold_days completed trading days
      if(strategy_max_hold_days > 0 && bars_held >= strategy_max_hold_days)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      // Bailout Exit: Close immediately at market on first profitable daily open
      if(bars_held >= 1)
      {
         const double open_0 = iOpen(_Symbol, PERIOD_D1, 0); // perf-allowed: daily open bailout check behind QM_IsNewBar()
         const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         if(ptype == POSITION_TYPE_BUY && open_0 > open_price)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
         else if(ptype == POSITION_TYPE_SELL && open_0 < open_price)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
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
