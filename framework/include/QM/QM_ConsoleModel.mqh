#ifndef QM_CONSOLEMODEL_MQH
#define QM_CONSOLEMODEL_MQH

#include <QM/QM_DesignTokens.mqh>

enum QM_ConsoleMode { QM_CONSOLE_FULL=0, QM_CONSOLE_COMPACT=1, QM_CONSOLE_MINIMAL=2 };
enum QM_ConsoleLocale { QM_LOCALE_DE_DE=0, QM_LOCALE_EN_US=1 };
enum QM_ConsoleGateState
  { QM_GATE_PASS=0, QM_GATE_BLOCK, QM_GATE_WARN, QM_GATE_OFF, QM_GATE_NA,
    QM_GATE_WAIT, QM_GATE_ERROR, QM_GATE_STALE };
enum QM_ConsoleState
  { QM_CONSOLE_INITIALIZING=0, QM_CONSOLE_WAITING_SETUP, QM_CONSOLE_WAITING_TRIGGER,
    QM_CONSOLE_POSITION_ACTIVE, QM_CONSOLE_BLOCKED, QM_CONSOLE_ERROR };

struct QM_ConsoleGate
  {
   string key;
   string label;
   string reason;
   QM_ConsoleGateState state;
  };
struct QM_ConsoleLine
  {
   string label;
   string value;
   QM_ConsoleGateState state;
  };
struct QM_ConsoleExposure
  {
   ulong ticket;
   string symbol;
   bool pending;
   bool buy;
   datetime opened;
   datetime expires;
   double entry;
   double sl;
   double tp;
   double lots;
   double pnl;
   string entry_text;
   string sl_text;
   string tp_text;
  };
struct QM_ConsoleSnapshot
  {
   string strategy_name;
   string timeframe;
   string symbol;
   string environment;
   string version;
   QM_ConsoleState state;
   string reason;
   string next_event;
   // Admission warnings remain visible even while a position/order is active.
   // They are observations only; this snapshot never grants trade permission.
   string alert_reason;
   QM_ConsoleGateState alert_state;
   QM_ConsoleGate gates[];
   QM_ConsoleLine risk[];
   QM_ConsoleLine live[];
   QM_ConsoleLine performance[];
   QM_ConsoleExposure exposure[];
   string today;
   string week;
   int positions;
   int pending_orders;
   bool active_range;
   datetime range_start;
   datetime range_end;
   double range_high;
   double range_low;
   string range_high_text;
   string range_low_text;

   void Reset()
     {
      strategy_name=""; timeframe=""; symbol=""; environment=""; version="";
      state=QM_CONSOLE_INITIALIZING; reason="Awaiting first observation";
      next_event="Next timer update"; today="N/A"; week="N/A";
      alert_reason=""; alert_state=QM_GATE_NA;
      positions=0; pending_orders=0; active_range=false;
      range_start=0; range_end=0; range_high=0.0; range_low=0.0;
      range_high_text=""; range_low_text="";
      ArrayResize(gates,0); ArrayResize(risk,0); ArrayResize(live,0);
      ArrayResize(performance,0); ArrayResize(exposure,0);
     }
  };

void QM_ConsoleAddGate(QM_ConsoleSnapshot &snapshot,const string key,
                       const string label,const string reason,const QM_ConsoleGateState state)
  {
   const int i=ArraySize(snapshot.gates);
   ArrayResize(snapshot.gates,i+1);
   snapshot.gates[i].key=key; snapshot.gates[i].label=label;
   snapshot.gates[i].reason=reason; snapshot.gates[i].state=state;
  }
void QM_ConsoleAddLine(QM_ConsoleLine &lines[],const string label,const string value,
                       const QM_ConsoleGateState state=QM_GATE_NA)
  {
   const int i=ArraySize(lines); ArrayResize(lines,i+1);
   lines[i].label=label; lines[i].value=value; lines[i].state=state;
  }
string QM_ConsoleGateText(const QM_ConsoleGateState state)
  {
   switch(state)
     {
      case QM_GATE_PASS:return "PASS"; case QM_GATE_BLOCK:return "BLOCK";
      case QM_GATE_WARN:return "WARN"; case QM_GATE_OFF:return "OFF";
      case QM_GATE_WAIT:return "WAIT"; case QM_GATE_ERROR:return "ERROR";
      case QM_GATE_STALE:return "STALE"; default:return "N/A";
     }
  }
string QM_ConsoleStateText(const QM_ConsoleState state)
  {
   switch(state)
     {
      case QM_CONSOLE_WAITING_SETUP:return "WAITING FOR SETUP";
      case QM_CONSOLE_WAITING_TRIGGER:return "WAITING FOR TRIGGER";
      case QM_CONSOLE_POSITION_ACTIVE:return "POSITION ACTIVE";
      case QM_CONSOLE_BLOCKED:return "TRADE BLOCKED";
      case QM_CONSOLE_ERROR:return "SYSTEM ERROR";
      default:return "INITIALIZING";
     }
  }
color QM_ConsoleGateColor(const QM_ConsoleGateState state)
  {
   switch(state)
     {
      case QM_GATE_PASS:return QM_STATUS_PASS_FG;
      case QM_GATE_BLOCK:case QM_GATE_ERROR:return QM_STATUS_BLOCK_FG;
      case QM_GATE_WARN:case QM_GATE_STALE:return QM_STATUS_WARN_FG;
      case QM_GATE_WAIT:return QM_STATUS_INFO_FG;
      default:return QM_STATUS_OFF_FG;
     }
  }
color QM_ConsoleGateBackground(const QM_ConsoleGateState state)
  {
   switch(state)
     {
      case QM_GATE_PASS:return QM_STATUS_PASS_BG;
      case QM_GATE_BLOCK:case QM_GATE_ERROR:return QM_STATUS_BLOCK_BG;
      case QM_GATE_WARN:case QM_GATE_STALE:return QM_STATUS_WARN_BG;
      case QM_GATE_WAIT:return QM_STATUS_INFO_BG;
      default:return QM_STATUS_OFF_BG;
     }
  }
QM_ConsoleMode QM_ConsoleNextMode(const QM_ConsoleMode mode)
  {
   return mode==QM_CONSOLE_FULL?QM_CONSOLE_COMPACT:
          (mode==QM_CONSOLE_COMPACT?QM_CONSOLE_MINIMAL:QM_CONSOLE_FULL);
  }
bool QM_ConsoleSnapshotSelfTest()
  {
   QM_ConsoleSnapshot snapshot; snapshot.Reset();
   QM_ConsoleAddGate(snapshot,"news","News","Disabled",QM_GATE_OFF);
   QM_ConsoleAddGate(snapshot,"session","Session","No session contract",QM_GATE_NA);
   QM_ConsoleAddLine(snapshot.risk,"Next trade","0,31 % | USD 310,00");
   if(ArraySize(snapshot.gates)!=2 || ArraySize(snapshot.risk)!=1 ||
      ArraySize(snapshot.live)!=0 || snapshot.active_range ||
      QM_ConsoleGateText(snapshot.gates[0].state)==QM_ConsoleGateText(snapshot.gates[1].state))
      return false;
   if(QM_ConsoleNextMode(QM_ConsoleNextMode(QM_ConsoleNextMode(QM_CONSOLE_FULL)))!=QM_CONSOLE_FULL)
      return false;
   snapshot.Reset();
   return ArraySize(snapshot.gates)==0 && ArraySize(snapshot.risk)==0 &&
          snapshot.state==QM_CONSOLE_INITIALIZING;
  }

#endif
