#property strict
#property version   "5.0"
#property description "QM5_11068 ma-limit-pull"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11068;
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
input int    strategy_fast_ma_period      = 12;
input int    strategy_slow_ma_period      = 36;
input int    strategy_slope_lookback      = 3;
input int    strategy_atr_period          = 14;
input int    strategy_atr_long_period     = 96;
input double strategy_pullback_atr        = 0.35;
input double strategy_sl_atr_mult         = 1.2;
input double strategy_tp_atr_mult         = 1.8;
input int    strategy_order_expiry_bars   = 12;
input int    strategy_adx_period          = 14;
input double strategy_min_adx             = 18.0;
input double strategy_max_vol_expansion   = 2.0;
input double strategy_max_spread_stop_pct = 15.0;

// Return TRUE to BLOCK trading this tick. The card has no session filter; this
// hook implements only the spread guard while framework news handles events.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double stop_distance = atr_value * strategy_sl_atr_mult;
   const double spread = ask - bid;

   if(spread > 0.0 && stop_distance > 0.0 &&
      spread > (strategy_max_spread_stop_pct / 100.0) * stop_distance)
     {
      const int magic = QM_FrameworkMagic();
      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != magic)
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
            QM_TM_RemovePendingOrder(ticket, "spread_guard");
        }
      return true;
     }

   return false;
  }

// Caller guarantees QM_IsNewBar() == true. This refreshes one dynamic limit
// order per closed M5 bar while the MA trend and regime filters remain valid.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();

   if(QM_TM_OpenPositionCount(magic) > 0)
     {
      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != magic)
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
            QM_TM_RemovePendingOrder(ticket, "position_open");
        }
      return false;
     }

   if(strategy_fast_ma_period <= 1 || strategy_slow_ma_period <= 1 ||
      strategy_atr_period <= 1 || strategy_atr_long_period <= 1 ||
      strategy_adx_period <= 1)
      return false;

   const int slope_shift = 1 + ((strategy_slope_lookback > 0) ? strategy_slope_lookback : 1);
   const double fast_ma = QM_EMA(_Symbol, _Period, strategy_fast_ma_period, 1);
   const double slow_ma = QM_EMA(_Symbol, _Period, strategy_slow_ma_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_fast_ma_period, slope_shift);
   if(fast_ma <= 0.0 || slow_ma <= 0.0 || fast_prev <= 0.0)
      return false;

   int trend = 0;
   if(fast_ma > slow_ma && fast_ma > fast_prev)
      trend = 1;
   else if(fast_ma < slow_ma && fast_ma < fast_prev)
      trend = -1;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(strategy_min_adx > 0.0 && (adx <= 0.0 || adx < strategy_min_adx))
      trend = 0;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double atr_long = QM_ATR(_Symbol, _Period, strategy_atr_long_period, 1);
   if(atr_value <= 0.0 || atr_long <= 0.0)
      trend = 0;
   if(strategy_max_vol_expansion > 0.0 && atr_value > 0.0 && atr_long > 0.0 &&
      (atr_value / atr_long) > strategy_max_vol_expansion)
      trend = 0;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         QM_TM_RemovePendingOrder(ticket, "refresh_or_trend_cancel");
     }

   if(trend == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double offset = strategy_pullback_atr * atr_value;
   if(offset <= 0.0)
      return false;

   const int period_seconds = PeriodSeconds(_Period);
   if(strategy_order_expiry_bars > 0 && period_seconds > 0)
      req.expiration_seconds = strategy_order_expiry_bars * period_seconds;

   if(trend > 0)
     {
      req.type = QM_BUY_LIMIT;
      req.price = QM_StopRulesNormalizePrice(_Symbol, bid - offset);
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_value, strategy_sl_atr_mult);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr_value, strategy_tp_atr_mult);
      req.reason = "ma_limit_pull_buy";
     }
   else
     {
      req.type = QM_SELL_LIMIT;
      req.price = QM_StopRulesNormalizePrice(_Symbol, ask + offset);
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_value, strategy_sl_atr_mult);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr_value, strategy_tp_atr_mult);
      req.reason = "ma_limit_pull_sell";
     }

   return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR SL/TP. Optional +1R trailing is not enabled.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   bool has_position = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      has_position = true;
      break;
     }

   if(!has_position)
      return false;

   const int slope_shift = 1 + ((strategy_slope_lookback > 0) ? strategy_slope_lookback : 1);
   const double fast_ma = QM_EMA(_Symbol, _Period, strategy_fast_ma_period, 1);
   const double slow_ma = QM_EMA(_Symbol, _Period, strategy_slow_ma_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_fast_ma_period, slope_shift);
   if(fast_ma <= 0.0 || slow_ma <= 0.0 || fast_prev <= 0.0)
      return false;

   const bool trend_up = (fast_ma > slow_ma && fast_ma > fast_prev);
   const bool trend_down = (fast_ma < slow_ma && fast_ma < fast_prev);

   if(position_type == POSITION_TYPE_BUY && trend_down)
      return true;
   if(position_type == POSITION_TYPE_SELL && trend_up)
      return true;

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
