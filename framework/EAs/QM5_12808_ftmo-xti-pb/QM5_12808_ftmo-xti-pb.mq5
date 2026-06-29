#property strict
#property version   "5.0"
#property description "QM5_12808 FTMO XTI Trend Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12808 - FTMO XTI Trend Pullback
// -----------------------------------------------------------------------------
// H4 crude-oil continuation sleeve:
//   - D1 EMA(50/200) defines bullish/bearish regime.
//   - H4 pullback touches EMA(50), then closes back through EMA(21).
//   - ATR hard stop, trend invalidation, and max-hold exits.
// Runtime uses MT5 OHLC only; no external data, no ML, no grid.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12808;
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
input int    strategy_d1_fast_ema          = 50;
input int    strategy_d1_slow_ema          = 200;
input int    strategy_h4_trigger_ema       = 21;
input int    strategy_h4_pullback_ema      = 50;
input int    strategy_slope_lookback_d1    = 5;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 2.8;
input int    strategy_max_hold_bars        = 36;
input int    strategy_max_spread_points    = 1000;

bool Strategy_IsXtiH4()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_H4);
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

int Strategy_D1Trend()
  {
   const int slope = MathMax(1, strategy_slope_lookback_d1);
   const double close_d1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double ema_fast_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_fast_ema, 1, PRICE_CLOSE);
   const double ema_slow_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_slow_ema, 1, PRICE_CLOSE);
   const double ema_fast_old = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_fast_ema, 1 + slope, PRICE_CLOSE);

   if(close_d1 <= 0.0 || ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_old <= 0.0)
      return 0;

   if(close_d1 > ema_fast_1 && ema_fast_1 > ema_slow_1 && ema_fast_1 > ema_fast_old)
      return 1;
   if(close_d1 < ema_fast_1 && ema_fast_1 < ema_slow_1 && ema_fast_1 < ema_fast_old)
      return -1;
   return 0;
  }

bool Strategy_TrendStillValid(const int position_type)
  {
   const int trend = Strategy_D1Trend();
   if(position_type == POSITION_TYPE_BUY)
      return trend > 0;
   if(position_type == POSITION_TYPE_SELL)
      return trend < 0;
   return false;
  }

void Strategy_CloseIfManagedExit()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int max_hold_seconds = MathMax(1, strategy_max_hold_bars) * PeriodSeconds(PERIOD_H4);
   const double h4_close = QM_SMA(_Symbol, PERIOD_H4, 1, 1, PRICE_CLOSE);
   const double h4_pullback_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_pullback_ema, 1, PRICE_CLOSE);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const int type = (int)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = !Strategy_TrendStillValid(type);

      if(h4_close > 0.0 && h4_pullback_ema > 0.0)
        {
         if(type == POSITION_TYPE_BUY && h4_close < h4_pullback_ema)
            should_close = true;
         if(type == POSITION_TYPE_SELL && h4_close > h4_pullback_ema)
            should_close = true;
        }

      if(opened > 0 && now - opened >= max_hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiH4())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_d1_fast_ema <= 1 || strategy_d1_slow_ema <= strategy_d1_fast_ema)
      return true;
   if(strategy_h4_trigger_ema <= 1 || strategy_h4_pullback_ema <= strategy_h4_trigger_ema)
      return true;
   if(strategy_slope_lookback_d1 <= 0 || strategy_atr_period <= 0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_max_hold_bars <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12808_XTI_TREND_PULLBACK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const int trend = Strategy_D1Trend();
   if(trend == 0)
      return false;

   const double open_h4 = QM_SMA(_Symbol, PERIOD_H4, 1, 1, PRICE_OPEN);
   const double close_h4 = QM_SMA(_Symbol, PERIOD_H4, 1, 1, PRICE_CLOSE);
   const double low_h4 = QM_SMA(_Symbol, PERIOD_H4, 1, 1, PRICE_LOW);
   const double high_h4 = QM_SMA(_Symbol, PERIOD_H4, 1, 1, PRICE_HIGH);
   const double trigger_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_trigger_ema, 1, PRICE_CLOSE);
   const double pullback_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_pullback_ema, 1, PRICE_CLOSE);
   if(open_h4 <= 0.0 || close_h4 <= 0.0 || low_h4 <= 0.0 || high_h4 <= 0.0 ||
      trigger_ema <= 0.0 || pullback_ema <= 0.0)
      return false;

   const bool long_signal = (trend > 0 && low_h4 <= pullback_ema &&
                             close_h4 > trigger_ema && close_h4 > open_h4);
   const bool short_signal = (trend < 0 && high_h4 >= pullback_ema &&
                              close_h4 < trigger_ema && close_h4 < open_h4);
   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = long_signal ? "XTI_TREND_PULLBACK_LONG" : "XTI_TREND_PULLBACK_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseIfManagedExit();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12808\",\"ea\":\"ftmo-xti-pb\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
