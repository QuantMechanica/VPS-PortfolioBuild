#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA - TradingView HalfTrend channel reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9995;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_amplitude              = 2;
input int    strategy_halftrend_atr_period   = 100;
input double strategy_channel_dev            = 2.0;
input int    strategy_sl_atr_period          = 14;
input double strategy_sl_atr_mult            = 1.5;
input double strategy_tp_atr_mult            = 0.0;
input bool   strategy_regime_filter_enabled  = false;
input int    strategy_regime_lag_bars        = 20;
input int    strategy_time_stop_bars         = 0;

int    g_halftrend_trend = -1;
double g_halftrend_max_low_price = 0.0;
double g_halftrend_min_high_price = 0.0;
bool   g_halftrend_initialized = false;

bool HalfTrendExtremes(const int lookback, double &highest_price, double &lowest_price)
  {
   highest_price = 0.0;
   lowest_price = 0.0;

   if(lookback <= 0)
      return false;

   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double high_price = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded HalfTrend channel extreme
      const double low_price = iLow(_Symbol, PERIOD_H1, shift);   // perf-allowed: bounded HalfTrend channel extreme
      if(high_price <= 0.0 || low_price <= 0.0)
         return false;

      if(shift == 1 || high_price > highest_price)
         highest_price = high_price;
      if(shift == 1 || low_price < lowest_price)
         lowest_price = low_price;
     }

   return (highest_price > 0.0 && lowest_price > 0.0);
  }

bool HalfTrendCurrentBar(double &bar_high, double &bar_low)
  {
   bar_high = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: closed H1 trigger bar high
   bar_low = iLow(_Symbol, PERIOD_H1, 1);   // perf-allowed: closed H1 trigger bar low
   return (bar_high > 0.0 && bar_low > 0.0);
  }

bool HalfTrendSpreadAllowed(const double atr_sl_distance)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr_sl_distance <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > (0.25 * atr_sl_distance))
      return false;

   return true;
  }

bool HalfTrendRegimeAllowed()
  {
   if(!strategy_regime_filter_enabled)
      return true;

   const int lag = (strategy_regime_lag_bars < 1) ? 1 : strategy_regime_lag_bars;
   const double current_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_sl_atr_period, 1);
   const double lagged_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_sl_atr_period, 1 + lag);
   if(current_atr <= 0.0 || lagged_atr <= 0.0)
      return false;

   return (current_atr > lagged_atr);
  }

bool HalfTrendHasSameSidePosition(const QM_OrderType order_type)
  {
   const int magic = QM_FrameworkMagic();
   const bool want_buy = QM_OrderTypeIsBuy(order_type);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((want_buy && position_type == POSITION_TYPE_BUY) ||
         (!want_buy && position_type == POSITION_TYPE_SELL))
         return true;
     }

   return false;
  }

void HalfTrendCloseOppositePositions(const QM_OrderType order_type)
  {
   const int magic = QM_FrameworkMagic();
   const bool want_buy = QM_OrderTypeIsBuy(order_type);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_opposite = (want_buy && position_type == POSITION_TYPE_SELL) ||
                               (!want_buy && position_type == POSITION_TYPE_BUY);
      if(is_opposite)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
     }
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int amplitude = (strategy_amplitude < 1) ? 1 : strategy_amplitude;
   double high_price = 0.0;
   double low_price = 0.0;
   if(!HalfTrendExtremes(amplitude, high_price, low_price))
      return false;

   double bar_high = 0.0;
   double bar_low = 0.0;
   if(!HalfTrendCurrentBar(bar_high, bar_low))
      return false;

   const double high_ma = QM_SMA(_Symbol, PERIOD_H1, amplitude, 1, PRICE_HIGH);
   const double low_ma = QM_SMA(_Symbol, PERIOD_H1, amplitude, 1, PRICE_LOW);
   const double ht_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_halftrend_atr_period, 1);
   const double sl_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_sl_atr_period, 1);
   if(high_ma <= 0.0 || low_ma <= 0.0 || ht_atr <= 0.0 || sl_atr <= 0.0)
      return false;

   if(!g_halftrend_initialized)
     {
      g_halftrend_trend = -1;
      g_halftrend_max_low_price = low_price;
      g_halftrend_min_high_price = high_price;
      g_halftrend_initialized = true;
      return false;
     }

   const int previous_trend = g_halftrend_trend;
   int current_trend = previous_trend;
   const double previous_max_low = g_halftrend_max_low_price;
   const double previous_min_high = g_halftrend_min_high_price;
   const double atr_threshold = strategy_channel_dev * (ht_atr / 2.0) / 100.0;

   if(previous_trend == -1 &&
      high_ma < previous_min_high &&
      bar_low > (previous_min_high + atr_threshold))
     {
      current_trend = 1;
      g_halftrend_max_low_price = low_price;
     }
   else if(previous_trend == 1 &&
           low_ma > previous_max_low &&
           bar_high < (previous_max_low - atr_threshold))
     {
      current_trend = -1;
      g_halftrend_min_high_price = high_price;
     }
   else
     {
      if(previous_trend == 1)
         g_halftrend_max_low_price = MathMax(previous_max_low, low_price);
      else
         g_halftrend_min_high_price = MathMin(previous_min_high, high_price);
     }

   g_halftrend_trend = current_trend;
   if(current_trend == previous_trend)
      return false;

   if(!HalfTrendRegimeAllowed())
      return false;

   const QM_OrderType order_type = (current_trend == 1) ? QM_BUY : QM_SELL;
   if(HalfTrendHasSameSidePosition(order_type))
      return false;

   const double entry_price = (order_type == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_distance = sl_atr * strategy_sl_atr_mult;
   if(entry_price <= 0.0 || sl_distance <= 0.0)
      return false;

   if(!HalfTrendSpreadAllowed(sl_distance))
      return false;

   const double sl_price = QM_StopATRFromValue(_Symbol, order_type, entry_price, sl_atr, strategy_sl_atr_mult);
   if(sl_price <= 0.0)
      return false;

   double tp_price = 0.0;
   if(strategy_tp_atr_mult > 0.0)
      tp_price = QM_TakeATRFromValue(_Symbol, order_type, entry_price, sl_atr, strategy_tp_atr_mult);

   HalfTrendCloseOppositePositions(order_type);

   req.type = order_type;
   req.price = 0.0;
   req.sl = sl_price;
   req.tp = tp_price;
   req.reason = (order_type == QM_BUY) ? "halftrend_flip_up" : "halftrend_flip_down";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_H1);
   if(hold_seconds <= 0)
      return false;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (now - opened) >= hold_seconds)
         return true;
     }

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
