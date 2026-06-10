#property strict
#property version   "5.0"
#property description "QM5_10170 Carver Continuous Starter Trend System"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10170;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input bool   strategy_use_ma_signals      = true;
input bool   strategy_use_breakout_signals = true;
input bool   strategy_shorts_enabled      = true;
input int    strategy_atr_period          = 14;
input double strategy_emergency_atr_mult  = 5.0;

int Strategy_MASignal(const int fast_period, const int slow_period)
  {
   const double fast = QM_SMA(_Symbol, PERIOD_D1, fast_period, 1);
   const double slow = QM_SMA(_Symbol, PERIOD_D1, slow_period, 1);
   if(fast <= 0.0 || slow <= 0.0)
      return 0;
   if(fast > slow)
      return 1;
   if(fast < slow)
      return -1;
   return 0;
  }

int Strategy_BreakoutSignal(const int lookback)
  {
   if(lookback <= 0)
      return 0;
   return QM_Sig_Range_Breakout(_Symbol, PERIOD_D1, lookback, 1);
  }

int Strategy_AggregateSignal()
  {
   int sum = 0;
   if(strategy_use_ma_signals)
     {
      sum += Strategy_MASignal(8, 32);
      sum += Strategy_MASignal(16, 64);
      sum += Strategy_MASignal(32, 128);
      sum += Strategy_MASignal(64, 256);
     }

   if(strategy_use_breakout_signals)
     {
      sum += Strategy_BreakoutSignal(20);
      sum += Strategy_BreakoutSignal(40);
      sum += Strategy_BreakoutSignal(80);
      sum += Strategy_BreakoutSignal(160);
      sum += Strategy_BreakoutSignal(320);
     }

   if(sum > 0)
      return 1;
   if(sum < 0)
      return -1;
   return 0;
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype)
  {
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
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

   const int signal = Strategy_AggregateSignal();
   if(signal == 0)
      return false;
   if(signal < 0 && !strategy_shorts_enabled)
      return false;

   ENUM_POSITION_TYPE ptype;
   if(Strategy_GetOurPosition(ptype))
     {
      if(signal > 0 && ptype == POSITION_TYPE_BUY)
         return false;
      if(signal < 0 && ptype == POSITION_TYPE_SELL)
         return false;
     }

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_emergency_atr_mult);
   req.tp = 0.0;
   req.reason = (signal > 0) ? "CARVER_AGG_TREND_LONG" : "CARVER_AGG_TREND_SHORT";

   return (entry > 0.0 && req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_GetOurPosition(ptype))
      return false;

   const int signal = Strategy_AggregateSignal();
   if(signal == 0)
      return true;
   if(ptype == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && signal > 0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10170_carver-cont\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
