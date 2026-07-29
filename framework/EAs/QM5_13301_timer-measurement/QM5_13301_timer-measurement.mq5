// BACKTEST-ONLY measurement variant for QM5_13301.
// Live deployment remains the untouched gated EA on its own GDAXI chart.
//
// Keep the strategy implementation single-sourced: rename only the gated event
// handlers while including it, then expose wrappers which move open-position
// management and discretionary exits from OnTick to a one-second tester timer.
#define OnInit              QM13301_GatedOnInit
#define OnDeinit            QM13301_GatedOnDeinit
#define OnTick              QM13301_GatedOnTick
#define OnTimer             QM13301_GatedOnTimer
#define OnTradeTransaction  QM13301_GatedOnTradeTransaction
#define OnTester            QM13301_GatedOnTester
#include "../QM5_13301_balke-minute-range-breakout/QM5_13301_balke-minute-range-breakout.mq5"
#undef OnInit
#undef OnDeinit
#undef OnTick
#undef OnTimer
#undef OnTradeTransaction
#undef OnTester

int OnInit()
  {
   const int result = QM13301_GatedOnInit();
   if(result != INIT_SUCCEEDED)
      return result;
   if(!EventSetTimer(1))
     {
      QM_LogEvent(QM_ERROR, "TIMER_INIT_FAILED", "{\"interval_seconds\":1}");
      QM13301_GatedOnDeinit(REASON_INITFAILED);
      return INIT_FAILED;
     }
   QM_LogEvent(QM_INFO, "TIMER_MEASUREMENT_INIT",
               "{\"backtest_only\":true,\"interval_seconds\":1}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   QM13301_GatedOnDeinit(reason);
  }

datetime g_qm13301_last_management_run = 0;

bool QM13301_TimerGuardsAllow()
  {
   if(!QM_KillSwitchCheck())
      return false;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return false;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return false;
   if(QM_FrameworkHandleFridayClose())
      return false;
   return !Strategy_NoTradeFilter();
  }

void QM13301_CloseOnStrategyExit()
  {
   if(!Strategy_ExitSignal())
      return;
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

bool QM13301_ManagementDue(const datetime broker_now)
  {
   return (g_qm13301_last_management_run == 0 ||
           broker_now - g_qm13301_last_management_run >= 1);
  }

void QM13301_RunManagement(const datetime broker_now)
  {
   Strategy_ManageOpenPosition();
   QM13301_CloseOnStrategyExit();
   g_qm13301_last_management_run = broker_now;
  }

void OnTick()
  {
   const datetime broker_now = TimeCurrent();
   const bool guards_allow = QM13301_TimerGuardsAllow();

   // Tester timers advance with simulated time.  The final tick before a
   // session gap may therefore have no following timer event.  Catch up on
   // that tick when the shared one-second management stamp is stale.
   if(guards_allow && QM13301_ManagementDue(broker_now))
      QM13301_RunManagement(broker_now);

   if(!guards_allow)
      return;

   // Entry logic is unchanged and remains gated to each newly closed bar.
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
   const datetime broker_now = TimeCurrent();
   if(!QM13301_ManagementDue(broker_now))
      return;
   if(!QM13301_TimerGuardsAllow())
      return;
   QM13301_RunManagement(broker_now);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM13301_GatedOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   return QM13301_GatedOnTester();
  }
