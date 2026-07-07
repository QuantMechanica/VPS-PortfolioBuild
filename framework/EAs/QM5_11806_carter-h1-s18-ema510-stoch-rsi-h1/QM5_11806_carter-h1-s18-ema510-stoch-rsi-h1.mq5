#property strict
#property version   "5.0"
#property description "QM5_11806 Carter H1 S18 EMA5/10 Stoch RSI"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Carter S18 H1 EMA(5/10) cross with Stochastic and RSI confirmation.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11806;
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
input int    strategy_ema_fast_period   = 5;
input int    strategy_ema_slow_period   = 10;
input int    strategy_stoch_k_period    = 14;
input int    strategy_stoch_d_period    = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_overbought  = 80.0;
input double strategy_stoch_oversold    = 20.0;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_midline       = 50.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_atr_tp_mult       = 4.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return true;
   if(qm_magic_slot_offset < 0)
      return true;
   if(strategy_ema_fast_period <= 0 || strategy_ema_slow_period <= 0)
      return true;
   if(strategy_ema_fast_period >= strategy_ema_slow_period)
      return true;
   if(strategy_stoch_k_period <= 0 || strategy_stoch_d_period <= 0 || strategy_stoch_slowing <= 0)
      return true;
   if(strategy_stoch_oversold < 0.0 || strategy_stoch_overbought > 100.0)
      return true;
   if(strategy_stoch_oversold >= strategy_stoch_overbought)
      return true;
   if(strategy_rsi_period <= 0 || strategy_rsi_midline <= 0.0 || strategy_rsi_midline >= 100.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
   return false;
  }

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
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_H1;
   const double ema_fast_1 = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double ema_slow_1 = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 1, PRICE_CLOSE);
   const double ema_fast_2 = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 2, PRICE_CLOSE);
   const double ema_slow_2 = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 2, PRICE_CLOSE);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool bullish_cross = (ema_fast_1 > ema_slow_1 && ema_fast_2 <= ema_slow_2);
   const bool bearish_cross = (ema_fast_1 < ema_slow_1 && ema_fast_2 >= ema_slow_2);
   if(!bullish_cross && !bearish_cross)
      return false;

   const double stoch_k = QM_Stoch_K(_Symbol, tf, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, tf, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi <= 0.0 || rsi >= 100.0)
      return false;

   if(bullish_cross)
     {
      if(!(stoch_k > stoch_d && stoch_k < strategy_stoch_overbought && rsi > strategy_rsi_midline))
         return false;
      req.type = QM_BUY;
      req.reason = "CARTER_S18_LONG_EMA_STOCH_RSI";
     }
   else
     {
      if(!(stoch_k < stoch_d && stoch_k > strategy_stoch_oversold && rsi < strategy_rsi_midline))
         return false;
      req.type = QM_SELL;
      req.reason = "CARTER_S18_SHORT_EMA_STOCH_RSI";
     }

   const double entry_price = QM_EntryMarketPrice(req.type);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr, strategy_atr_sl_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry_price, atr, strategy_atr_tp_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY && (req.sl >= entry_price || req.tp <= entry_price))
      return false;
   if(req.type == QM_SELL && (req.sl <= entry_price || req.tp >= entry_price))
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_H1;
   const double ema_fast_1 = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double ema_slow_1 = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 1, PRICE_CLOSE);
   const double ema_fast_2 = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 2, PRICE_CLOSE);
   const double ema_slow_2 = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 2, PRICE_CLOSE);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool bullish_cross = (ema_fast_1 > ema_slow_1 && ema_fast_2 <= ema_slow_2);
   const bool bearish_cross = (ema_fast_1 < ema_slow_1 && ema_fast_2 >= ema_slow_2);
   if(!bullish_cross && !bearish_cross)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && bearish_cross)
         return true;
      if(pos_type == POSITION_TYPE_SELL && bullish_cross)
         return true;
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11806\",\"ea\":\"carter-h1-s18-ema510-stoch-rsi-h1\"}");
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
