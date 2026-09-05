//+------------------------------------------------------------------+
//| QM_FTMO_TrialTelemetry.mq5                                      |
//| Read-only telemetry for an OWNER-created FTMO demo/trial only.  |
//| No trade API is included or called.                             |
//+------------------------------------------------------------------+
#property copyright "QuantMechanica V5"
#property version   "1.00"
#property strict
#property description "Read-only FTMO trial telemetry. Never install on T_Live."

#include <QM/QM_FTMOGovernorPolicy.mqh>

input int    InpTimerSeconds  = 1;
input string InpOutputDir     = "QM\\ftmo_trial";
input long   InpExpectedLogin = 0;
input string InpExpectedServer = "";
input string InpTrialId       = "UNSET";

#define QM_TRIAL_SCHEMA "qm.ftmo-trial-telemetry.raw/v1"

bool     g_busy = false;
bool     g_armed = false;
ulong    g_sequence = 0;
datetime g_session_started_utc = 0;
string   g_session_id = "";

string JsonEscape(const string value)
  {
   string result="";
   for(int index=0; index<StringLen(value); ++index)
     {
      ushort c=StringGetCharacter(value,index);
      if(c==34) { result+="\\\""; continue; }
      if(c==92) { result+="\\\\"; continue; }
      if(c<32 || c>126) c=32;
      result+=ShortToString(c);
     }
   return result;
  }

string IsoUtc(const datetime value)
  {
   MqlDateTime p;
   ZeroMemory(p);
   TimeToStruct(value,p);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
                       p.year,p.mon,p.day,p.hour,p.min,p.sec);
  }

bool AppendLine(const string line)
  {
   const string path=InpOutputDir+"\\trial_telemetry_raw.jsonl";
   int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|
                       FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle==INVALID_HANDLE)
      return false;
   FileSeek(handle,0,SEEK_END);
   FileWriteString(handle,line+"\r\n");
   FileFlush(handle);
   FileClose(handle);
   return true;
  }

string PositionInventory(int &selected)
  {
   selected=0;
   string result="[";
   const int expected=PositionsTotal();
   for(int index=0; index<expected; ++index)
     {
      const ulong ticket=PositionGetTicket(index);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(selected>0) result+=",";
      result+=StringFormat(
         "{\"ticket\":%I64u,\"position_id\":%I64u,\"magic\":%I64d,"
         "\"symbol\":\"%s\",\"volume\":%.8f,\"profit\":%.2f,\"swap\":%.2f}",
         ticket,(ulong)PositionGetInteger(POSITION_IDENTIFIER),
         PositionGetInteger(POSITION_MAGIC),
         JsonEscape(PositionGetString(POSITION_SYMBOL)),
         PositionGetDouble(POSITION_VOLUME),
         PositionGetDouble(POSITION_PROFIT),PositionGetDouble(POSITION_SWAP));
      ++selected;
     }
   return result+"]";
  }

string PendingInventory(int &selected)
  {
   selected=0;
   string result="[";
   const int expected=OrdersTotal();
   for(int index=0; index<expected; ++index)
     {
      const ulong ticket=OrderGetTicket(index);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(selected>0) result+=",";
      result+=StringFormat(
         "{\"ticket\":%I64u,\"magic\":%I64d,\"symbol\":\"%s\",\"type\":%d,\"volume\":%.8f}",
         ticket,OrderGetInteger(ORDER_MAGIC),
         JsonEscape(OrderGetString(ORDER_SYMBOL)),
         (int)OrderGetInteger(ORDER_TYPE),OrderGetDouble(ORDER_VOLUME_CURRENT));
      ++selected;
     }
   return result+"]";
  }

void Capture(const string source)
  {
   if(!g_armed || g_busy)
      return;
   g_busy=true;
   const datetime now=TimeGMT();
   int position_count=0;
   int pending_count=0;
   const string positions=PositionInventory(position_count);
   const string pending=PendingInventory(pending_count);
   const bool reconciled=(position_count==PositionsTotal() &&
                          pending_count==OrdersTotal());
   const string row=StringFormat(
      "{\"schema\":\"%s\",\"event\":\"SAMPLE\",\"trial_id\":\"%s\","
      "\"session_id\":\"%s\",\"sequence\":%I64u,\"ts_utc\":\"%s\","
      "\"ts_epoch\":%I64d,\"prague_day_key\":%d,\"source\":\"%s\","
      "\"account_login\":%I64d,\"account_server\":\"%s\",\"currency\":\"%s\","
      "\"balance\":%.2f,\"equity\":%.2f,\"open_positions\":%d,"
      "\"pending_orders\":%d,\"reconciliation_complete\":%s,"
      "\"positions\":%s,\"orders\":%s}",
      QM_TRIAL_SCHEMA,JsonEscape(InpTrialId),JsonEscape(g_session_id),g_sequence,
      IsoUtc(now),(long)now,QM_FTMO_PragueDayKey(now),JsonEscape(source),
      AccountInfoInteger(ACCOUNT_LOGIN),
      JsonEscape(AccountInfoString(ACCOUNT_SERVER)),
      JsonEscape(AccountInfoString(ACCOUNT_CURRENCY)),
      AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY),
      position_count,pending_count,(reconciled ? "true" : "false"),
      positions,pending);
   if(AppendLine(row))
      ++g_sequence;
   else
      Print("QM_FTMO_TrialTelemetry append failed: ",GetLastError());
   g_busy=false;
  }

int OnInit()
  {
   const long login=AccountInfoInteger(ACCOUNT_LOGIN);
   const string server=AccountInfoString(ACCOUNT_SERVER);
   if(InpTrialId=="" || InpTrialId=="UNSET")
     {
      Print("QM_FTMO_TrialTelemetry requires an explicit InpTrialId");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpExpectedLogin>0 && login!=InpExpectedLogin)
      return INIT_FAILED;
   if(InpExpectedServer!="" && server!=InpExpectedServer)
      return INIT_FAILED;
   g_session_started_utc=TimeGMT();
   g_session_id=StringFormat("%I64d-%I64d",login,(long)g_session_started_utc);
   int seconds=MathMax(1,MathMin(5,InpTimerSeconds));
   if(!EventSetTimer(seconds))
      return INIT_FAILED;
   g_armed=true;
   Capture("INIT");
   return INIT_SUCCEEDED;
  }

void OnTick()  { Capture("TICK"); }
void OnTimer() { Capture("TIMER"); }

void OnDeinit(const int reason)
  {
   if(g_armed)
      Capture("DEINIT");
   EventKillTimer();
   g_armed=false;
  }

