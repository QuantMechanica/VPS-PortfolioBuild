#property strict
#property version   "5.0"
#property description "QM5_10395 Elite Trader TTM Squeeze EMA Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10395;
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
input int    strategy_ema_fast          = 12;
input int    strategy_ema_mid1          = 20;
input int    strategy_ema_mid2          = 30;
input int    strategy_ema_slow          = 50;
input int    strategy_squeeze_period    = 20;
input double strategy_bb_deviation      = 2.0;
input double strategy_kc_atr_mult       = 1.5;
input int    strategy_atr_period        = 20;
input int    strategy_jpy_stop_pips     = 100;
input int    strategy_jpy_target_pips   = 120;
input double strategy_atr_sl_mult       = 1.0;
input double strategy_atr_tp_mult       = 1.2;
input bool   strategy_skip_friday_last_h1 = true;

bool Strategy_NoTradeFilter()
  {
   if(strategy_ema_fast <= 0 || strategy_ema_mid1 <= strategy_ema_fast ||
      strategy_ema_mid2 <= strategy_ema_mid1 || strategy_ema_slow <= strategy_ema_mid2)
      return true;
   if(strategy_squeeze_period <= 1 || strategy_bb_deviation <= 0.0 ||
      strategy_kc_atr_mult <= 0.0 || strategy_atr_period <= 0 ||
      strategy_jpy_stop_pips <= 0 || strategy_jpy_target_pips <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
   if(strategy_skip_friday_last_h1)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5 && dt.hour >= 20)
         return true;
     }
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

   if(Bars(_Symbol, PERIOD_H1) < strategy_ema_slow + strategy_atr_period + 5)
      return false;

   const double bb_upper_1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_squeeze_period, strategy_bb_deviation, 1);
   const double bb_lower_1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_squeeze_period, strategy_bb_deviation, 1);
   const double bb_upper_2 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_squeeze_period, strategy_bb_deviation, 2);
   const double bb_lower_2 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_squeeze_period, strategy_bb_deviation, 2);
   const double kc_mid_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_squeeze_period, 1);
   const double kc_mid_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_squeeze_period, 2);
   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double atr_2 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 2);
   const double close_1 = iClose(_Symbol, PERIOD_H1, 1);
   if(bb_upper_1 <= 0.0 || bb_lower_1 <= 0.0 || bb_upper_2 <= 0.0 || bb_lower_2 <= 0.0 ||
      kc_mid_1 <= 0.0 || kc_mid_2 <= 0.0 || atr_1 <= 0.0 || atr_2 <= 0.0 || close_1 <= 0.0)
      return false;

   const double kc_upper_1 = kc_mid_1 + atr_1 * strategy_kc_atr_mult;
   const double kc_lower_1 = kc_mid_1 - atr_1 * strategy_kc_atr_mult;
   const double kc_upper_2 = kc_mid_2 + atr_2 * strategy_kc_atr_mult;
   const double kc_lower_2 = kc_mid_2 - atr_2 * strategy_kc_atr_mult;
   const bool squeeze_was_on = (bb_upper_2 < kc_upper_2 && bb_lower_2 > kc_lower_2);
   const bool long_fire = (squeeze_was_on && bb_upper_1 > kc_upper_1 && close_1 > kc_mid_1);
   const bool short_fire = (squeeze_was_on && bb_lower_1 < kc_lower_1 && close_1 < kc_mid_1);
   if(long_fire == short_fire)
      return false;

   const double e_fast = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 1);
   const double e_mid1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_mid1, 1);
   const double e_mid2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_mid2, 1);
   const double e_slow = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow, 1);
   if(e_fast <= 0.0 || e_mid1 <= 0.0 || e_mid2 <= 0.0 || e_slow <= 0.0)
      return false;

   if(long_fire && e_fast > e_mid1 && e_mid1 > e_mid2 && e_mid2 > e_slow)
      req.type = QM_BUY;
   else if(short_fire && e_fast < e_mid1 && e_mid1 < e_mid2 && e_mid2 < e_slow)
      req.type = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   if(StringFind(_Symbol, "JPY") >= 0 && StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "XAG") < 0)
     {
      req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_jpy_stop_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, entry, strategy_jpy_target_pips);
     }
   else
     {
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_tp_mult);
     }

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (req.type == QM_BUY) ? "TTM_SQUEEZE_EMA_LONG" : "TTM_SQUEEZE_EMA_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP and discretionary EMA/opposite-squeeze exits only.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double e20_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_mid1, 1);
      const double e50_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow, 1);
      const double e20_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_mid1, 2);
      const double e50_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow, 2);
      if(e20_now <= 0.0 || e50_now <= 0.0 || e20_prev <= 0.0 || e50_prev <= 0.0)
         continue;

      if(position_type == POSITION_TYPE_BUY && e20_prev >= e50_prev && e20_now < e50_now)
         return true;
      if(position_type == POSITION_TYPE_SELL && e20_prev <= e50_prev && e20_now > e50_now)
         return true;

      const double bb_upper_1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_squeeze_period, strategy_bb_deviation, 1);
      const double bb_lower_1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_squeeze_period, strategy_bb_deviation, 1);
      const double bb_upper_2 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_squeeze_period, strategy_bb_deviation, 2);
      const double bb_lower_2 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_squeeze_period, strategy_bb_deviation, 2);
      const double kc_mid_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_squeeze_period, 1);
      const double kc_mid_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_squeeze_period, 2);
      const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      const double atr_2 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 2);
      const double close_1 = iClose(_Symbol, PERIOD_H1, 1);
      if(bb_upper_1 <= 0.0 || bb_lower_1 <= 0.0 || bb_upper_2 <= 0.0 || bb_lower_2 <= 0.0 ||
         kc_mid_1 <= 0.0 || kc_mid_2 <= 0.0 || atr_1 <= 0.0 || atr_2 <= 0.0 || close_1 <= 0.0)
         continue;

      const double kc_upper_1 = kc_mid_1 + atr_1 * strategy_kc_atr_mult;
      const double kc_lower_1 = kc_mid_1 - atr_1 * strategy_kc_atr_mult;
      const double kc_upper_2 = kc_mid_2 + atr_2 * strategy_kc_atr_mult;
      const double kc_lower_2 = kc_mid_2 - atr_2 * strategy_kc_atr_mult;
      const bool squeeze_was_on = (bb_upper_2 < kc_upper_2 && bb_lower_2 > kc_lower_2);
      const bool long_fire = (squeeze_was_on && bb_upper_1 > kc_upper_1 && close_1 > kc_mid_1);
      const bool short_fire = (squeeze_was_on && bb_lower_1 < kc_lower_1 && close_1 < kc_mid_1);
      if(position_type == POSITION_TYPE_BUY && short_fire)
         return true;
      if(position_type == POSITION_TYPE_SELL && long_fire)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10395_et-ttm-squeeze\"}");
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
