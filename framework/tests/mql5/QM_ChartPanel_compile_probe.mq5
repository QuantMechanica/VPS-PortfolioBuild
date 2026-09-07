#property copyright "QuantMechanica"
#property version   "1.00"
#property strict

#include <QM/QM_ChartPanel.mqh>

input bool InpShowPanel = true;
input bool InpApplyScheme = true;

CQMChartPanel g_signature_panel;

int OnInit()
  {
   if(!QM_PanelFormatterSelfTest())
      return INIT_FAILED;
   if(InpApplyScheme)
      QM_ChartScheme_Apply(ChartID());
   if(!g_signature_panel.Initialize(ChartID(), 99999, "compile-probe", 99999001,
                                    "PROBE000", InpShowPanel))
      return INIT_SUCCEEDED;
   EventSetTimer(5);
   return INIT_SUCCEEDED;
  }

void OnTimer()
  {
   QMChartPanelSnapshot state;
   state.trading_state = "YES";
   state.trading_reason = "ALLOW";
   state.news_state = "OPEN";
   state.news_detail = "LIVE MT5 NATIVE";
   state.friday_state = "OK";
   state.friday_countdown = "01:00";
   state.governor_state = "UNBOUND";
   state.governor_reason = "PROBE";
   state.kill_switch_state = "ARMED";
   state.spread_state = "PASS";
   state.session_state = "N/A";
   state.risk_mode = "RISK_FIXED";
   state.risk_per_trade = "1.00";
   state.effective_risk = "$1.00";
   state.daily_room = "$100.00 / 1.00%";
   state.total_room = "N/A";
   state.last_signal = "N/A";
   state.calendar_health = "LIVE MT5 NATIVE OK";
   state.heartbeat_state = "OK";
   state.build_version = "1.00";
   state.support_line = "Support: MQL5 comments/messages";
   g_signature_panel.Refresh(state);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_signature_panel.Shutdown();
   if(InpApplyScheme)
      QM_ChartScheme_Restore(ChartID());
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   g_signature_panel.InvalidatePerformance();
  }
