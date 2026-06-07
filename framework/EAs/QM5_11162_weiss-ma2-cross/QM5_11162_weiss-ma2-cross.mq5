#property strict
#property version   "5.0"
#property description "QM5_11162 Weissman Two Moving Average Crossover"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11162;
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
input int    strategy_fast_sma_period    = 9;
input int    strategy_slow_sma_period    = 26;
input int    strategy_atr_period         = 20;
input double strategy_atr_stop_mult      = 3.0;

int Strategy_SmaCrossSignal()
  {
   if(strategy_fast_sma_period <= 0 ||
      strategy_slow_sma_period <= 0 ||
      strategy_fast_sma_period >= strategy_slow_sma_period)
      return 0;

   const double fast_now  = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1);
   const double slow_now  = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 1);
   const double fast_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 2);
   const double slow_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return 0;

   if(fast_prev <= slow_prev && fast_now > slow_now)
      return 1;
   if(fast_prev >= slow_prev && fast_now < slow_now)
      return -1;
   return 0;
  }

double Strategy_ProtectiveStop(const QM_OrderType side, const double entry)
  {
   if(entry <= 0.0 || strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return 0.0;

   double stop_distance = atr * strategy_atr_stop_mult;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double broker_min_distance = MathMax(0, stops_level) * point;
   if(stop_distance < broker_min_distance)
      stop_distance = broker_min_distance;

   return QM_StopATRFromValue(_Symbol, side, entry, stop_distance, 1.0);
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = candidate;
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
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

   const int cross = Strategy_SmaCrossSignal();
   if(cross == 0)
      return false;

   ENUM_POSITION_TYPE existing_type;
   ulong existing_ticket = 0;
   if(Strategy_SelectOurPosition(existing_type, existing_ticket))
      return false;

   req.type = (cross > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = Strategy_ProtectiveStop(req.type, entry);
   if(req.sl <= 0.0)
      return false;

   req.reason = (cross > 0) ? "weiss_sma_9_26_bull_cross" : "weiss_sma_9_26_bear_cross";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(position_type, ticket))
      return;
   if(!PositionSelectByTicket(ticket))
      return;

   const double current_sl = PositionGetDouble(POSITION_SL);
   if(current_sl > 0.0)
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const QM_OrderType side = (position_type == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
   const double protective_sl = Strategy_ProtectiveStop(side, open_price);
   if(protective_sl > 0.0)
      QM_TM_MoveSL(ticket, protective_sl, "weiss_catastrophic_stop_restore");
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(position_type, ticket))
      return false;

   const int cross = Strategy_SmaCrossSignal();
   if(position_type == POSITION_TYPE_BUY && cross < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && cross > 0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11162_weiss-ma2-cross\",\"source_id\":\"3005c768-aa91-5daf-9dd7-500d7bfcb7a6\"}");
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
