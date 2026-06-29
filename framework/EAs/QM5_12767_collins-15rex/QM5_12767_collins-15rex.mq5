#property strict
#property version   "5.0"
#property description "QM5_12767 Collins 1.5 Daily Range Expansion - WTI"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12767 - Collins 1.5 Daily Range Expansion - WTI
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - if prior close is above SMA(25), arm a buy stop at today's open + 1.5x
//     prior D1 range
//   - if prior close is below SMA(25), arm a sell stop at today's open - 1.5x
//     prior D1 range
//   - opposite range band is the hard protective stop
// Runtime uses MT5 OHLC only; no futures curve, inventory, EIA, CSV, or API feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12767;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_range_mult             = 1.5;
input int    strategy_sma_period             = 25;
input int    strategy_atr_period             = 14;
input double strategy_abnormal_range_atr_cap = 5.0;
input int    strategy_pending_expiry_hours   = 24;
input int    strategy_max_hold_days          = 10;
input int    strategy_max_spread_points      = 1000;
input int    strategy_min_stop_points        = 10;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_IsStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_HasPendingStop()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelPendingStops(const string reason)
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
      if(!Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12767_COLLINS_15REX";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(3600, strategy_pending_expiry_hours * 3600);
  }

bool Strategy_LoadDailyState(double &current_open,
                             double &prior_close,
                             double &prior_range,
                             double &sma_value,
                             double &atr_value)
  {
   current_open = 0.0;
   prior_close = 0.0;
   prior_range = 0.0;
   sma_value = 0.0;
   atr_value = 0.0;

   const int warmup = MathMax(strategy_sma_period, strategy_atr_period) + 5;
   if(Bars(_Symbol, PERIOD_D1) < warmup) // perf-allowed: bounded D1 warmup guard.
      return false;

   current_open = iOpen(_Symbol, PERIOD_D1, 0); // perf-allowed: Collins next-open reference.
   const double prior_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: prior D1 range.
   const double prior_low = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: prior D1 range.
   prior_close = iClose(_Symbol, PERIOD_D1, 1);            // perf-allowed: prior D1 SMA regime gate.
   if(current_open <= 0.0 || prior_high <= 0.0 || prior_low <= 0.0 ||
      prior_high <= prior_low || prior_close <= 0.0)
      return false;

   prior_range = prior_high - prior_low;
   sma_value = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(prior_range <= 0.0 || sma_value <= 0.0 || atr_value <= 0.0)
      return false;

   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_range_mult <= 0.0)
      return true;
   if(strategy_sma_period <= 1 || strategy_atr_period <= 0)
      return true;
   if(strategy_abnormal_range_atr_cap <= 0.0)
      return true;
   if(strategy_pending_expiry_hours <= 0 || strategy_max_hold_days <= 0)
      return true;
   if(strategy_max_spread_points < 0 || strategy_min_stop_points <= 0)
      return true;
   return false;
  }

bool Strategy_BuildStopRequest(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(Strategy_HasOpenPosition() || Strategy_HasPendingStop())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double current_open = 0.0;
   double prior_close = 0.0;
   double prior_range = 0.0;
   double sma_value = 0.0;
   double atr_value = 0.0;
   if(!Strategy_LoadDailyState(current_open, prior_close, prior_range, sma_value, atr_value))
      return false;

   if(prior_range > strategy_abnormal_range_atr_cap * atr_value)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double stop_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_points = MathMax((double)strategy_min_stop_points, stop_level_points + 2.0);
   const double entry_distance = strategy_range_mult * prior_range;
   if(entry_distance < min_points * point)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(prior_close > sma_value)
     {
      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, current_open + entry_distance);
      req.sl = QM_TM_NormalizePrice(_Symbol, current_open - entry_distance);
      req.reason = "COLLINS_15REX_BUY_STOP";
      if(req.price <= ask + min_points * point)
         return false;
      if(req.sl <= 0.0 || req.sl >= req.price)
         return false;
     }
   else if(prior_close < sma_value)
     {
      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, current_open - entry_distance);
      req.sl = QM_TM_NormalizePrice(_Symbol, current_open + entry_distance);
      req.reason = "COLLINS_15REX_SELL_STOP";
      if(req.price >= bid - min_points * point)
         return false;
      if(req.sl <= 0.0 || req.sl <= req.price)
         return false;
     }
   else
      return false;

   req.tp = 0.0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12767\",\"ea\":\"collins-15rex\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   Strategy_CancelPendingStops("new_d1_reprice");

   if(Strategy_HasOpenPosition() || Strategy_HasPendingStop())
      return;

   QM_EntryRequest req;
   if(Strategy_BuildStopRequest(req))
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
