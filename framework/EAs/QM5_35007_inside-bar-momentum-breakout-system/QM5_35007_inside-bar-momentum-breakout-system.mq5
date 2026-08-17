#property strict
#property version   "5.0"
#property description "QM5_35007 Robopip Inside Bar Momentum Breakout System"
// Strategy Card: QM5_35007 (inside-bar-momentum-breakout-system), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_35007
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 35007;
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
input double strategy_buffer_pips         = 2.0;    // Entry buffer beyond mother bar high/low in pips
input double strategy_sl_ratio            = 0.20;   // Stop loss distance as ratio of mother range
input double strategy_tp_rr_mult          = 2.00;   // Take profit multiplier (1:2.0 R:R)
input int    strategy_atr_period          = 14;     // ATR period for spread filter
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_pending_expiry_bars = 3;      // Cancel unfulfilled pending orders after N bars

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool Strategy_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
}

void Strategy_RemoveExpiredPendingOrders()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_pending_expiry_bars <= 0)
      return;

   const int expiry_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_H4);
   if(expiry_seconds <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_STOP && ot != ORDER_TYPE_SELL_STOP &&
         ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && (now - setup_time) >= expiry_seconds)
         QM_TM_RemovePendingOrder(ticket, "inside_bar_pending_expired");
   }
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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
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
   req.expiration_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_H4);

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   // 1. Fetch completed bar data: Bar [1] = Inside Bar candidate, Bar [2] = Mother Bar
   const double high_1 = iHigh(_Symbol, PERIOD_H4, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double low_1  = iLow(_Symbol, PERIOD_H4, 1);  // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double high_2 = iHigh(_Symbol, PERIOD_H4, 2); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double low_2  = iLow(_Symbol, PERIOD_H4, 2);  // perf-allowed: closed-bar reference behind QM_IsNewBar()

   if(high_1 <= 0.0 || low_1 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0)
      return false;

   // 2. Inside Bar Condition: High[1] < High[2] AND Low[1] > Low[2]
   const bool is_inside_bar = (high_1 < high_2 && low_1 > low_2);
   if(!is_inside_bar)
      return false;

   const double mother_range = high_2 - low_2;
   if(mother_range <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double buffer = strategy_buffer_pips * pip_size;
   const double sl_dist = MathMax(strategy_sl_ratio * mother_range, 5.0 * pip_size);
   const double tp_dist = strategy_tp_rr_mult * mother_range;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double buy_trigger_price = high_2 + buffer;
   const double sell_trigger_price = low_2 - buffer;

   // Prefer pending stop orders per Card §3.2/§3.3; if price already broke out on open, place market order
   if(ask >= buy_trigger_price)
   {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, ask - sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, ask + tp_dist);
      req.reason = "inside_bar_buy_market_breakout";
      return true;
   }
   else if(bid <= sell_trigger_price)
   {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, bid + sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, bid - tp_dist);
      req.reason = "inside_bar_sell_market_breakout";
      return true;
   }
   else
   {
      // Place Buy Stop above mother high
      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, buy_trigger_price);
      req.sl = QM_TM_NormalizePrice(_Symbol, buy_trigger_price - sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, buy_trigger_price + tp_dist);
      req.reason = "inside_bar_buy_stop";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   Strategy_RemoveExpiredPendingOrders();

   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0 || open_price <= 0.0) continue;

         double r_dist = 0.0;
         if(current_sl > 0.0 && current_sl < open_price)
            r_dist = open_price - current_sl;
         else if(current_tp > open_price)
            r_dist = (current_tp - open_price) / strategy_tp_rr_mult;
         else
            r_dist = 20.0 * pip_size;

         // Break-even trigger at +1.0R open profit -> SL moved to Entry + 1 pip
         if((bid - open_price) >= r_dist)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price + 1.0 * pip_size);
            if(target_sl > current_sl + point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "inside_bar_be_plus_1");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || open_price <= 0.0) continue;

         double r_dist = 0.0;
         if(current_sl > open_price)
            r_dist = current_sl - open_price;
         else if(current_tp > 0.0 && current_tp < open_price)
            r_dist = (open_price - current_tp) / strategy_tp_rr_mult;
         else
            r_dist = 20.0 * pip_size;

         // Break-even trigger at +1.0R open profit -> SL moved to Entry - 1 pip
         if((open_price - ask) >= r_dist)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price - 1.0 * pip_size);
            if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "inside_bar_be_plus_1");
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
