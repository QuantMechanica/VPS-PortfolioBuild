#property strict
#property version   "5.0"
#property description "QM5_11274 iaf-rsi-ema - RSI oversold state with EMA crossover confirmation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11274;
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
input int    strategy_ema_fast_period   = 12;
input int    strategy_ema_slow_period   = 26;
input int    strategy_ema_lookback      = 10;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;
input double strategy_stop_loss_pct     = 5.0;
input double strategy_trailing_tp_pct   = 10.0;
input int    strategy_atr_fallback_period = 14;
input double strategy_atr_fallback_mult = 2.0;

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0 || rsi_now >= strategy_rsi_oversold)
      return false;

   bool bullish_cross_recent = false;
   for(int shift = 1; shift <= strategy_ema_lookback; ++shift)
     {
      const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
      const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift);
      const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift + 1);
      const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift + 1);
      if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
         continue;
      if(fast_prev <= slow_prev && fast_now > slow_now)
        {
         bullish_cross_recent = true;
         break;
        }
     }
   if(!bullish_cross_recent)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   double stop_distance = entry * (strategy_stop_loss_pct / 100.0);
   double sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, entry, stop_distance);
   if(sl <= 0.0 || sl >= entry)
     {
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_fallback_period, 1);
      if(atr_value <= 0.0)
         return false;
      sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_fallback_mult);
     }
   if(sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "iaf_rsi_ema_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_trailing_tp_pct <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(magic <= 0 || bid <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double trail_distance = open_price * (strategy_trailing_tp_pct / 100.0);
      if(open_price <= 0.0 || trail_distance <= 0.0)
         continue;
      if((bid - open_price) < trail_distance)
         continue;

      const double new_sl = QM_StopRulesNormalizePrice(_Symbol, bid - trail_distance);
      if(new_sl <= open_price)
         continue;
      if(current_sl > 0.0 && new_sl <= current_sl)
         continue;

      QM_TM_MoveSL(ticket, new_sl, "iaf_10pct_trailing_take_profit");
     }
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now < strategy_rsi_overbought)
      return false;

   for(int shift = 1; shift <= strategy_ema_lookback; ++shift)
     {
      const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
      const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift);
      const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift + 1);
      const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift + 1);
      if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
         continue;
      if(fast_prev >= slow_prev && fast_now < slow_now)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
