#property strict
#property version   "5.0"
#property description "QM5_10465 MQL5 RSI Dual Cloud Zone Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10465;
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
input ENUM_TIMEFRAMES strategy_timeframe  = PERIOD_H1;
input int             strategy_fast_rsi_period = 5;
input int             strategy_slow_rsi_period = 14;
input double          strategy_down_level = 30.0;
input double          strategy_up_level   = 70.0;
input int             strategy_atr_period = 14;
input double          strategy_atr_sl_mult = 1.5;
input double          strategy_tp_r_mult = 2.0;

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

int Strategy_RsiCloudLeaveSignal()
  {
   const int warmup = MathMax(strategy_fast_rsi_period, strategy_slow_rsi_period) + 3;
   if(Bars(_Symbol, strategy_timeframe) < warmup)
      return 0;

   const double fast_prev = QM_RSI(_Symbol, strategy_timeframe, strategy_fast_rsi_period, 2);
   const double slow_prev = QM_RSI(_Symbol, strategy_timeframe, strategy_slow_rsi_period, 2);
   const double fast_now  = QM_RSI(_Symbol, strategy_timeframe, strategy_fast_rsi_period, 1);
   const double slow_now  = QM_RSI(_Symbol, strategy_timeframe, strategy_slow_rsi_period, 1);

   if(fast_prev <= 0.0 || slow_prev <= 0.0 || fast_now <= 0.0 || slow_now <= 0.0)
      return 0;

   if(fast_prev <= strategy_down_level && slow_prev <= strategy_down_level &&
      fast_now > strategy_down_level && slow_now > strategy_down_level)
      return 1;

   if(fast_prev >= strategy_up_level && slow_prev >= strategy_up_level &&
      fast_now < strategy_up_level && slow_now < strategy_up_level)
      return -1;

   return 0;
  }

bool Strategy_BuildMarketRequest(QM_EntryRequest &req,
                                 const QM_OrderType side,
                                 const string reason)
  {
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, strategy_tp_r_mult);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(side == QM_BUY)
      return (req.sl < entry - point && req.tp > entry + point);
   return (req.sl > entry + point && req.tp < entry - point);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_timeframe != PERIOD_H1)
      return true;
   if(_Period != strategy_timeframe)
      return true;
   if(strategy_fast_rsi_period <= 1 || strategy_slow_rsi_period <= 1)
      return true;
   if(strategy_down_level <= 0.0 || strategy_up_level >= 100.0)
      return true;
   if(strategy_down_level >= strategy_up_level)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_tp_r_mult <= 0.0)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "RSI_CLOUD_ZONE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(Strategy_SelectOurPosition(ticket, ptype))
      return false;

   const int signal = Strategy_RsiCloudLeaveSignal();
   if(signal > 0)
      return Strategy_BuildMarketRequest(req, QM_BUY, "RSI_CLOUD_LEAVE_DOWN_LONG");
   if(signal < 0)
      return Strategy_BuildMarketRequest(req, QM_SELL, "RSI_CLOUD_LEAVE_UP_SHORT");

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, stacking, or partial-close rule.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectOurPosition(ticket, ptype))
      return false;

   const int signal = Strategy_RsiCloudLeaveSignal();
   if(ptype == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && signal > 0)
      return true;

   return false;
  }

// News Filter Hook
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
