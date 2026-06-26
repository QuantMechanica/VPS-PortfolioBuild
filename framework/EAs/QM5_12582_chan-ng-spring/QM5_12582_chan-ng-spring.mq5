#property strict
#property version   "5.0"
#property description "QM5_12582 Chan Natural Gas Spring Calendar"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12582 - Chan Natural Gas Spring Calendar
// -----------------------------------------------------------------------------
// D1 structural XNG sleeve:
//   - long only during Feb 25 through Apr 15
//   - D1 SMA confirmation and ATR stop
//   - Friday close remains enabled, so the original seasonal hold is segmented
// Runtime uses MT5 OHLC only; no futures-expiry, weather, or storage feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12582;
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
input int    strategy_trend_period        = 63;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 10;
input int    strategy_max_spread_points   = 800;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_InSpringWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.mon == 2)
      return (dt.day >= 25);
   if(dt.mon == 3)
      return true;
   if(dt.mon == 4)
      return (dt.day <= 15);
   return false;
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

bool Strategy_ClosedState(double &close_last, double &sma_last, datetime &closed_time)
  {
   closed_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 calendar window gate.
   close_last = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   return (closed_time > 0 && close_last > 0.0 && sma_last > 0.0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double sma_last = 0.0;
   datetime closed_time = 0;
   if(!Strategy_ClosedState(close_last, sma_last, closed_time))
      return;

   const bool in_window = Strategy_InSpringWindow(closed_time);
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = (!in_window || close_last < sma_last);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12582_CHAN_NG_SPRING";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double sma_last = 0.0;
   datetime closed_time = 0;
   if(!Strategy_ClosedState(close_last, sma_last, closed_time))
      return false;
   if(!Strategy_InSpringWindow(closed_time))
      return false;
   if(close_last <= sma_last)
      return false;

   req.type = QM_BUY;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "CHAN_NG_SPRING_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12582\",\"ea\":\"chan-ng-spring\"}");
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
