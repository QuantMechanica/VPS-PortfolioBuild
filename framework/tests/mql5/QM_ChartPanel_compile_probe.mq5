#property copyright "QuantMechanica"
#property version   "1.00"
#property strict

#include <QM/QM_ChartPanel.mqh>

input bool InpShowPanel = true;

CQMChartPanel g_signature_panel;

int OnInit()
  {
   if(!g_signature_panel.Initialize(ChartID(), 99999, "compile-probe", 99999001,
                                    "PROBE000", InpShowPanel))
      return INIT_SUCCEEDED;
   EventSetTimer(5);
   return INIT_SUCCEEDED;
  }

void OnTimer()
  {
   QMChartPanelSnapshot state;
   state.news_state = "OPEN";
   state.friday_state = "OK";
   state.governor_state = "ARMED";
   state.environment = "ENV PROBE";
   state.risk_mode = "RISK_FIXED";
   state.risk_per_trade = "1.00";
   state.heartbeat_state = "OK";
   g_signature_panel.Refresh(state);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_signature_panel.Shutdown();
  }
