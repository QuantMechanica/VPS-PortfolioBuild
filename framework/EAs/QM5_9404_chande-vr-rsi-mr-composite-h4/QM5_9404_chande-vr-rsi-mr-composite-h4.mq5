#property strict
#property version   "5.0"
#property description "QM5_9404 Chande VR RSI mean-reversion H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9404;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H4;
input int             strategy_atr_short_period   = 14;
input int             strategy_atr_long_period    = 50;
input int             strategy_rsi_period         = 3;
input int             strategy_trend_sma_period   = 200;
input double          strategy_vr_max             = 0.70;
input double          strategy_long_rsi_level     = 10.0;
input double          strategy_short_rsi_level    = 90.0;
input double          strategy_exit_rsi_mid       = 50.0;
input double          strategy_rejection_atr_mult = 0.40;
input double          strategy_spread_atr_mult    = 0.20;
input int             strategy_time_stop_bars     = 8;
input bool            strategy_shorts_enabled     = true;

ENUM_TIMEFRAMES Strategy_SignalTF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

bool Strategy_SelectOpenPosition(ulong &ticket,
                                 ENUM_POSITION_TYPE &ptype,
                                 double &volume,
                                 double &open_price,
                                 datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   volume = 0.0;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_ReadTriggerBar(double &close1, double &high1, double &low1)
  {
   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();
   close1 = QM_SMA(_Symbol, tf, 1, 1, PRICE_CLOSE);
   high1 = iHigh(_Symbol, tf, 1); // perf-allowed: single closed H4 trigger-bar high read; no pooled high helper exists.
   low1 = iLow(_Symbol, tf, 1); // perf-allowed: single closed H4 trigger-bar low read; no pooled low helper exists.
   return (close1 > 0.0 && high1 > 0.0 && low1 > 0.0 && high1 >= low1);
  }

bool Strategy_CurrentSpreadOk(const double atr)
  {
   if(atr <= 0.0)
      return false;
   if(strategy_spread_atr_mult <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_atr_short_period <= 0 ||
      strategy_atr_long_period <= strategy_atr_short_period ||
      strategy_rsi_period <= 0 ||
      strategy_trend_sma_period <= 1 ||
      strategy_vr_max <= 0.0 ||
      strategy_long_rsi_level <= 0.0 ||
      strategy_short_rsi_level >= 100.0 ||
      strategy_long_rsi_level >= strategy_exit_rsi_mid ||
      strategy_short_rsi_level <= strategy_exit_rsi_mid ||
      strategy_rejection_atr_mult <= 0.0 ||
      strategy_spread_atr_mult < 0.0 ||
      strategy_time_stop_bars <= 0)
      return true;

   const ENUM_TIMEFRAMES signal_tf = Strategy_SignalTF();
   if((ENUM_TIMEFRAMES)_Period != signal_tf)
      return true;

   int warmup = strategy_trend_sma_period;
   if(strategy_atr_long_period > warmup)
      warmup = strategy_atr_long_period;
   if(strategy_time_stop_bars > warmup)
      warmup = strategy_time_stop_bars;
   warmup += 10;

   if(Bars(_Symbol, signal_tf) < warmup) // perf-allowed: O(1) warm-up availability check only.
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

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();
   const double atr_short = QM_ATR(_Symbol, tf, strategy_atr_short_period, 1);
   const double atr_long = QM_ATR(_Symbol, tf, strategy_atr_long_period, 1);
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1, PRICE_CLOSE);
   const double sma = QM_SMA(_Symbol, tf, strategy_trend_sma_period, 1, PRICE_CLOSE);
   double close1 = 0.0;
   double high1 = 0.0;
   double low1 = 0.0;
   if(atr_short <= 0.0 ||
      atr_long <= 0.0 ||
      rsi < 0.0 ||
      sma <= 0.0 ||
      !Strategy_ReadTriggerBar(close1, high1, low1))
      return false;

   const double vr = atr_short / atr_long;
   if(vr >= strategy_vr_max)
      return false;
   if(!Strategy_CurrentSpreadOk(atr_short))
      return false;

   const bool long_signal = (rsi < strategy_long_rsi_level &&
                             close1 > sma &&
                             close1 > low1 &&
                             (close1 - low1) >= strategy_rejection_atr_mult * atr_short);
   const bool short_signal = (strategy_shorts_enabled &&
                              rsi > strategy_short_rsi_level &&
                              close1 < sma &&
                              close1 < high1 &&
                              (high1 - close1) >= strategy_rejection_atr_mult * atr_short);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double raw_sl = long_signal ? (low1 - strategy_rejection_atr_mult * atr_short)
                                     : (high1 + strategy_rejection_atr_mult * atr_short);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0)
      return false;
   if(long_signal && sl >= entry)
      return false;
   if(short_signal && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = long_signal ? "CHANDE_VR_RSI_LONG" : "CHANDE_VR_RSI_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return;

   if(open_time <= 0 || strategy_time_stop_bars <= 0)
      return;

   const int stop_seconds = strategy_time_stop_bars * PeriodSeconds(Strategy_SignalTF());
   if(stop_seconds > 0 && TimeCurrent() - open_time >= stop_seconds)
      QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return false;

   const double rsi = QM_RSI(_Symbol, Strategy_SignalTF(), strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && rsi > strategy_exit_rsi_mid)
      return true;
   if(ptype == POSITION_TYPE_SELL && rsi < strategy_exit_rsi_mid)
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
      ulong ticket = 0;
      const QM_EntryResult result = QM_Entry(req, ticket);
      if(result == QM_ENTRY_OK)
         QM_LogEvent(QM_INFO, "ENTRY_OK", StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\"}", ticket, req.reason));
     }
  }
