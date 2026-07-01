#property strict
#property version   "5.0"
#property description "QM5_9401 DeMark TD Predicted Range Low Fade H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9401;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input ENUM_TIMEFRAMES strategy_tf              = PERIOD_H4;
input int    strategy_atr_period               = 14;
input double strategy_tail_atr_mult            = 0.50;
input double strategy_stop_atr_mult            = 0.30;
input double strategy_spread_atr_mult          = 0.20;
input int    strategy_time_stop_bars           = 12;
input int    strategy_sunday_open_hour_broker  = 22;

double Strategy_XValue(const MqlRates &prior_bar)
  {
   if(prior_bar.close > prior_bar.open)
      return (2.0 * prior_bar.high + prior_bar.low + prior_bar.close) / 4.0;
   if(prior_bar.close < prior_bar.open)
      return (prior_bar.high + 2.0 * prior_bar.low + prior_bar.close) / 4.0;
   return (prior_bar.high + prior_bar.low + 2.0 * prior_bar.close) / 4.0;
  }

bool Strategy_ReadTriggerBars(MqlRates &trigger_bar, MqlRates &prior_bar)
  {
   MqlRates bars[];
   ArrayResize(bars, 2);
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 1, 2, bars); // perf-allowed: TDPR needs only the prior two closed OHLC bars, called once per H4 entry gate.
   if(copied != 2)
      return false;

   trigger_bar = bars[0];
   prior_bar = bars[1];
   return (trigger_bar.open > 0.0 && trigger_bar.high > 0.0 &&
           trigger_bar.low > 0.0 && trigger_bar.close > 0.0 &&
           prior_bar.open > 0.0 && prior_bar.high > 0.0 &&
           prior_bar.low > 0.0 && prior_bar.close > 0.0);
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &pos_type, datetime &opened_at)
  {
   pos_type = POSITION_TYPE_BUY;
   opened_at = 0;
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

      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != strategy_tf)
      return true;
   if(strategy_atr_period < 1 || strategy_tail_atr_mult <= 0.0 ||
      strategy_stop_atr_mult <= 0.0 || strategy_spread_atr_mult <= 0.0 ||
      strategy_time_stop_bars < 1)
      return true;

   MqlDateTime broker_dt;
   TimeToStruct(TimeCurrent(), broker_dt);
   if(broker_dt.day_of_week == 6)
      return true;
   if(broker_dt.day_of_week == 0 && broker_dt.hour < strategy_sunday_open_hour_broker)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
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

   MqlRates trigger_bar;
   MqlRates prior_bar;
   if(!Strategy_ReadTriggerBars(trigger_bar, prior_bar))
      return false;

   const double x_value = Strategy_XValue(prior_bar);
   const double tdprh = 2.0 * x_value - prior_bar.low;
   const double tdprl = 2.0 * x_value - prior_bar.high;
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(x_value <= 0.0 || tdprh <= 0.0 || tdprl <= 0.0 || atr <= 0.0)
      return false;

   const bool long_signal = (trigger_bar.low <= tdprl &&
                             trigger_bar.close > tdprl &&
                             trigger_bar.close > trigger_bar.open &&
                             (trigger_bar.close - trigger_bar.low) >= strategy_tail_atr_mult * atr);
   const bool short_signal = (trigger_bar.high >= tdprh &&
                              trigger_bar.close < tdprh &&
                              trigger_bar.close < trigger_bar.open &&
                              (trigger_bar.high - trigger_bar.close) >= strategy_tail_atr_mult * atr);

   if(long_signal == short_signal)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(long_signal)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, trigger_bar.low - strategy_stop_atr_mult * atr);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, x_value);
      if(sl <= 0.0 || tp <= 0.0 || sl >= ask || tp <= ask)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TDPRL_FADE_LONG";
      return true;
     }

   const double sl = QM_StopRulesNormalizePrice(_Symbol, trigger_bar.high + strategy_stop_atr_mult * atr);
   const double tp = QM_StopRulesNormalizePrice(_Symbol, x_value);
   if(sl <= 0.0 || tp <= 0.0 || sl <= bid || tp >= bid)
      return false;

   req.type = QM_SELL;
   req.sl = sl;
   req.tp = tp;
   req.reason = "TDPRH_FADE_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP and a time stop; no trailing or partial exits.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type;
   datetime opened_at;
   if(!Strategy_SelectOurPosition(pos_type, opened_at))
      return false;
   if(opened_at <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_tf);
   if(seconds_per_bar <= 0)
      return false;

   const int hold_seconds = (strategy_time_stop_bars + 1) * seconds_per_bar;
   return (TimeCurrent() - opened_at >= hold_seconds);
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
                        60,
                        60,
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
