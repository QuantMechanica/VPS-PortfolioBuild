#property strict
#property version   "5.0"
#property description "SRC04_S08 lien-channels scaffold (P0)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1014;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 1.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy (SRC04_S08 defaults)"
input int    channel_lookback             = 16;
input int    channel_max_pips             = 30;
input int    channel_min_pips             = 10;
input int    entry_offset_pips            = 10;
input int    management_mode              = 0;   // 0=conservative,1=lien_2r_full_exit
input double tp1_rr                       = 1.0;
input double tp_full_rr                   = 2.0;
input int    trail_method                 = 0;   // 0=two_bar_extreme
input int    channel_definition           = 0;   // 0=n-bar-horizontal-range
input int    arm_only_during              = 0;   // 0=always

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"strategy\":\"SRC04_S08\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // P0 scaffold: trading logic to be implemented from card Section 4/5.
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
