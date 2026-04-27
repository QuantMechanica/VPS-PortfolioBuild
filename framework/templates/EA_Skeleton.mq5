#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    ea_id             = 9999;
input int    magic_slot_offset = 0;

input group "Risk"
input double RISK_PERCENT      = 0.0;
input double RISK_FIXED        = 1000.0;
input double PORTFOLIO_WEIGHT  = 1.0;

input group "News"
input QM_NewsMode news_mode    = QM_NEWS_OFF;

input group "Friday Close"
input bool   friday_close_enabled    = true;
input int    friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_placeholder     = 0;

int OnInit()
  {
   if(!QM_FrameworkInit(ea_id,
                        magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        news_mode,
                        friday_close_enabled,
                        friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // TODO: V5 strategy logic goes here.
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
