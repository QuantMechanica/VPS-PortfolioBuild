#property copyright "QuantMechanica"
#property version "1.00"
#property strict

#include <QM/QM_ChartPanel.mqh>

input bool InpShowPanel=true;
input bool InpApplyScheme=true;
input QM_ConsoleMode InpDashboardMode=QM_CONSOLE_FULL;
CQMChartPanel g_signature_panel;

int OnInit()
  {
   // This is an artifact-only probe; these assertions execute only if OWNER
   // subsequently attaches it. Compilation itself is not runtime evidence.
   if(!QM_PanelFormatterSelfTest() || !QM_ConsoleSnapshotSelfTest())
      return INIT_FAILED;
   Print("QM_CONSOLE_SELF_TESTS PASS");
   if(InpApplyScheme) QM_ChartScheme_Apply(ChartID());
   if(g_signature_panel.Initialize(ChartID(),99999,"compile-probe",99999001,
      "PROBE000",InpShowPanel,InpDashboardMode))
      EventSetTimer(5);
   return INIT_SUCCEEDED;
  }
void OnTimer()
  {
   QM_ConsoleSnapshot state; state.Reset();
   state.strategy_name="Header compile probe"; state.timeframe="D1";
   state.symbol=_Symbol; state.environment="DEMO"; state.version="4.0";
   state.state=QM_CONSOLE_WAITING_SETUP;
   state.reason="Synthetic presentation fixture";
   state.next_event="Next evaluation in 12:14";
   QM_ConsoleAddGate(state,"news","News","Native MT5 clear",QM_GATE_PASS);
   QM_ConsoleAddGate(state,"spread","Spread","0,6 pip",QM_GATE_PASS);
   QM_ConsoleAddGate(state,"friday","Friday","Disabled",QM_GATE_OFF);
   QM_ConsoleAddGate(state,"capacity","Capacity","One slot free",QM_GATE_PASS);
   QM_ConsoleAddLine(state.risk,"Next trade","0,31 % | USD 310,00");
   QM_ConsoleAddLine(state.risk,"Open exposure","0,00 % | USD 0,00");
   QM_ConsoleAddLine(state.risk,"Stop basis","Prior range x 1,50 | cap 80,0 pip");
   state.today="2 trades | USD +638,80"; state.week="7 trades | USD +1.200,00";
   QM_ConsoleAddLine(state.performance,"Trades today / attach / all","2 / 7 / 124");
   QM_ConsoleAddLine(state.performance,"Wins / losses | win rate","83 / 41 | 66,94 %");
   QM_ConsoleAddLine(state.performance,"Net P/L","USD +12.345,67");
   QM_ConsoleAddLine(state.performance,"Profit factor","3,18");
   QM_ConsoleAddLine(state.performance,"Max drawdown","USD 2.100,00 | 0,53 %");
   QM_ConsoleAddLine(state.performance,"Streaks now / longest","W3 L0 / W8 L4");
   g_signature_panel.Refresh(state);
  }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  { g_signature_panel.OnChartEvent(id,sparam); }
void OnDeinit(const int reason)
  {
   EventKillTimer(); g_signature_panel.Shutdown();
   if(InpApplyScheme) QM_ChartScheme_Restore(ChartID());
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  { g_signature_panel.InvalidatePerformance(); }
