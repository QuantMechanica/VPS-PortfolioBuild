#property strict
#property version   "5.0"
#property description "QM5_1101 Turn-Around Tuesday"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Card: QM5_1101 turn-around-tuesday, G0 APPROVED 2026-05-17.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1101;
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
input double strategy_monday_threshold_pct  = 0.003;
input bool   strategy_enable_long           = true;
input bool   strategy_enable_short          = true;
input double strategy_max_stop_pct          = 0.015;
input int    strategy_max_hold_d1_bars      = 1;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_D1);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlRates bars[4];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, 4, bars); // perf-allowed: one D1 calendar/close read inside framework new-bar entry gate
   if(copied < 3)
      return false;

   MqlDateTime signal_dt;
   MqlDateTime previous_dt;
   TimeToStruct(bars[1].time, signal_dt);
   TimeToStruct(bars[2].time, previous_dt);

   if(signal_dt.day_of_week == 0 || signal_dt.day_of_week == 6)
      return false;

   const bool first_session_after_friday =
      (previous_dt.day_of_week == 5) ||
      ((bars[1].time - bars[2].time) > PeriodSeconds(PERIOD_D1));
   if(!first_session_after_friday)
      return false;

   const double reference_close = bars[1].close;
   const double prior_close = bars[2].close;
   if(reference_close <= 0.0 || prior_close <= 0.0)
      return false;

   const double threshold = MathMax(0.0, strategy_monday_threshold_pct);
   const double stop_pct = MathMax(0.0, strategy_max_stop_pct);
   if(stop_pct <= 0.0)
      return false;

   const double reference_return = (reference_close / prior_close) - 1.0;

   if(reference_return < -threshold && strategy_enable_long)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = ask;
      req.sl = ask * (1.0 - stop_pct);
      req.reason = "QM5_1101_TURN_AROUND_TUESDAY_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(reference_return > threshold && strategy_enable_short)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = bid;
      req.sl = bid * (1.0 + stop_pct);
      req.reason = "QM5_1101_TURN_AROUND_TUESDAY_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;

   const int hold_bars = MathMax(1, strategy_max_hold_d1_bars);
   const long hold_seconds = (long)hold_bars * (long)PeriodSeconds(PERIOD_D1);
   if(hold_seconds <= 0)
      return false;

   const datetime now = TimeCurrent();
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && (now - open_time) >= hold_seconds)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1101\",\"ea\":\"turn-around-tuesday\"}");
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
