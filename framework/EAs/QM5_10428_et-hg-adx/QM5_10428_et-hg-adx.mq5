#property strict
#property version   "5.0"
#property description "QM5_10428 Elite Trader Holy Grail ADX Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10428;
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
input int    strategy_adx_period        = 14;
input double strategy_adx_cutoff        = 30.0;
input int    strategy_xma_period        = 20;
input int    strategy_sma_slope_period  = 5;
input int    strategy_stop_lookback     = 3;
input int    strategy_target_lookback   = 10;
input int    strategy_atr_period        = 20;
input double strategy_atr_floor_mult    = 1.0;
input int    strategy_max_hold_bars     = 20;
input int    strategy_pending_bars      = 1;

bool Strategy_NoTradeFilter()
  {
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
   req.expiration_seconds = MathMax(1, strategy_pending_bars) * PeriodSeconds(_Period);

   if(strategy_adx_period < 1 || strategy_xma_period < 1 ||
      strategy_sma_slope_period < 1 || strategy_stop_lookback < 1 ||
      strategy_target_lookback < 1 || strategy_atr_period < 1)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return false;
     }

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double xma = QM_EMA(_Symbol, _Period, strategy_xma_period, 1);
   const double sma_now = QM_SMA(_Symbol, _Period, strategy_sma_slope_period, 1);
   const double sma_prev = QM_SMA(_Symbol, _Period, strategy_sma_slope_period, 2);
   const double close_1 = iClose(_Symbol, _Period, 1);
   const double high_1 = iHigh(_Symbol, _Period, 1);
   const double low_1 = iLow(_Symbol, _Period, 1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(adx <= 0.0 || xma <= 0.0 || sma_now <= 0.0 || sma_prev <= 0.0 ||
      close_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || atr <= 0.0)
      return false;

   double swing_low = DBL_MAX;
   double swing_high = -DBL_MAX;
   for(int bar = 1; bar <= strategy_stop_lookback; ++bar)
     {
      const double low = iLow(_Symbol, _Period, bar);
      const double high = iHigh(_Symbol, _Period, bar);
      if(low <= 0.0 || high <= 0.0)
         return false;
      swing_low = MathMin(swing_low, low);
      swing_high = MathMax(swing_high, high);
     }

   double target_high = -DBL_MAX;
   double target_low = DBL_MAX;
   for(int bar = 1; bar <= strategy_target_lookback; ++bar)
     {
      const double low = iLow(_Symbol, _Period, bar);
      const double high = iHigh(_Symbol, _Period, bar);
      if(low <= 0.0 || high <= 0.0)
         return false;
      target_low = MathMin(target_low, low);
      target_high = MathMax(target_high, high);
     }

   const double slope = sma_now - sma_prev;
   const double atr_floor = strategy_atr_floor_mult * atr;

   if(adx > strategy_adx_cutoff && close_1 < xma && slope > 0.0)
     {
      const double entry = high_1;
      const double sl = MathMin(swing_low, entry - atr_floor);
      const double tp = target_high;
      if(sl <= 0.0 || tp <= entry || entry <= SymbolInfoDouble(_Symbol, SYMBOL_ASK))
         return false;
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "ET_HG_ADX_LONG_STOP";
      return true;
     }

   if(adx > strategy_adx_cutoff && close_1 > xma && slope < 0.0)
     {
      const double entry = low_1;
      const double sl = MathMax(swing_high, entry + atr_floor);
      const double tp = target_low;
      if(sl <= entry || tp <= 0.0 || tp >= entry || entry >= SymbolInfoDouble(_Symbol, SYMBOL_BID))
         return false;
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "ET_HG_ADX_SHORT_STOP";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars < 1)
      return false;

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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, _Period, open_time, false);
      if(open_shift >= strategy_max_hold_bars)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10428_et_hg_adx\"}");
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
