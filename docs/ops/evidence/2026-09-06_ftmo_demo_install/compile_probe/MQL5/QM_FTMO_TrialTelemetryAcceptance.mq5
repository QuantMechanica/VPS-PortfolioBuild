// Native Strategy Tester acceptance fixture; refuses attachment outside tester.
// Account observations are scripted; writer and collector serialization are real.
#property strict
#property version "1.00"
input string InpAcceptanceRunId="UNSET";
input string InpCollectorSourceSha="UNSET";
datetime g_fixture_now=0;
double g_fixture_equity=100000;
int g_fixture_positions=0,g_fixture_orders=0;
datetime FixtureUTC(){return g_fixture_now;}
long FixtureAccountInteger(ENUM_ACCOUNT_INFO_INTEGER key){return 123;}
string FixtureAccountString(ENUM_ACCOUNT_INFO_STRING key){return key==ACCOUNT_CURRENCY?"USD":"Synthetic-Tester";}
double FixtureAccountDouble(ENUM_ACCOUNT_INFO_DOUBLE key){return key==ACCOUNT_EQUITY?g_fixture_equity:100000;}
int FixturePositionsTotal(){return g_fixture_positions;}
int FixtureOrdersTotal(){return g_fixture_orders;}
ulong FixturePositionTicket(int i){return 1234;}
bool FixturePositionSelect(ulong t){return t==1234;}
long FixturePositionInteger(ENUM_POSITION_PROPERTY_INTEGER k){return k==POSITION_MAGIC?42:1234;}
string FixturePositionString(ENUM_POSITION_PROPERTY_STRING k){return "EURUSD";}
double FixturePositionDouble(ENUM_POSITION_PROPERTY_DOUBLE k){return k==POSITION_VOLUME?1:(k==POSITION_SWAP?-10:-5990);}
ulong FixtureOrderTicket(int i){return 2345;}
bool FixtureOrderSelect(ulong t){return t==2345;}
long FixtureOrderInteger(ENUM_ORDER_PROPERTY_INTEGER k){return k==ORDER_MAGIC?43:ORDER_TYPE_BUY_LIMIT;}
string FixtureOrderString(ENUM_ORDER_PROPERTY_STRING k){return "EURUSD";}
double FixtureOrderDouble(ENUM_ORDER_PROPERTY_DOUBLE k){return 1;}
#define QM_TRIAL_DEFAULT_ID "NATIVE_ACCEPTANCE_FIXTURE"
#define TimeGMT FixtureUTC
#define AccountInfoInteger FixtureAccountInteger
#define AccountInfoString FixtureAccountString
#define AccountInfoDouble FixtureAccountDouble
#define PositionsTotal FixturePositionsTotal
#define OrdersTotal FixtureOrdersTotal
#define PositionGetTicket FixturePositionTicket
#define PositionSelectByTicket FixturePositionSelect
#define PositionGetInteger FixturePositionInteger
#define PositionGetString FixturePositionString
#define PositionGetDouble FixturePositionDouble
#define OrderGetTicket FixtureOrderTicket
#define OrderSelect FixtureOrderSelect
#define OrderGetInteger FixtureOrderInteger
#define OrderGetString FixtureOrderString
#define OrderGetDouble FixtureOrderDouble
#define OnInit CollectorInit
#define OnDeinit CollectorDeinit
#define OnTick CollectorTick
#define OnTimer CollectorTimer
#include "QM_FTMO_TrialTelemetry.mq5"
#undef OnInit
#undef OnDeinit
#undef OnTick
#undef OnTimer

bool g_acceptance_pass=false;
string g_cases="";
bool RunCase(const string name,const datetime start,const int initial_day,const int final_day,const bool dst)
  {
   const string directory="QM\\ftmo_acceptance\\"+InpAcceptanceRunId+"\\"+name;
   if(!OpenWriter(directory)) return false;
   // A separate write handle simulates a competing collector's OS-level claim.
   int competitor=FileOpen(directory+"\\trial_telemetry_raw.jsonl",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   bool exclusive=(competitor==INVALID_HANDLE);
   if(competitor!=INVALID_HANDLE) FileClose(competitor);
   g_sequence=0;g_session_id=name+"-before";g_armed=true;
   int first_key=0,last_key=0;bool persisted=true;
   for(int i=0;i<=900;i++)
     {
      g_fixture_now=start+i;
      if(i==0) first_key=QM_FTMO_PragueDayKey(g_fixture_now);
      if(i==450)
        {
         CloseWriter();
         if(!OpenWriter(directory)) { g_armed=false;return false; }
         g_sequence=0;g_session_id=name+"-after";
        }
      g_fixture_equity=(i==460?94000:100000);
      g_fixture_positions=(i>=455 && i<=599?1:0);
      g_fixture_orders=(i>=455 && i<=599?1:0);
      ulong before=g_sequence;Capture("TIMER");
      if(g_sequence!=before+1) persisted=false;
      last_key=QM_FTMO_PragueDayKey(g_fixture_now);
     }
   g_armed=false;CloseWriter();
   int offset_before=QM_FTMO_PragueUTCOffsetSeconds(start);
   int offset_after=QM_FTMO_PragueUTCOffsetSeconds(start+900);
   bool offsets_ok=dst ? (name=="spring_dst" ? offset_before==3600 && offset_after==7200 : offset_before==7200 && offset_after==3600) : offset_before==offset_after;
   bool pass=exclusive && persisted && first_key==initial_day && last_key==final_day && offsets_ok;
   if(g_cases!="")g_cases+=",";
   g_cases+=StringFormat("{\"case\":\"%s\",\"pass\":%s,\"samples\":901,\"exclusive_writer\":%s,\"first_day\":%d,\"last_day\":%d,\"dst_crossing\":%s}",name,pass?"true":"false",exclusive?"true":"false",first_key,last_key,dst?"true":"false");
   return pass;
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || InpAcceptanceRunId=="UNSET" || StringLen(InpCollectorSourceSha)!=64 || StringFind(InpAcceptanceRunId,"..")>=0 || StringFind(InpAcceptanceRunId,":")>=0) return INIT_PARAMETERS_INCORRECT;
   g_acceptance_pass=RunCase("winter_midnight",D'2026.01.01 22:55:00',20260101,20260102,false);
   g_acceptance_pass=RunCase("summer_midnight",D'2026.06.01 21:55:00',20260601,20260602,false) && g_acceptance_pass;
   g_acceptance_pass=RunCase("spring_dst",D'2026.03.29 00:55:00',20260329,20260329,true) && g_acceptance_pass;
   g_acceptance_pass=RunCase("autumn_dst",D'2026.10.25 00:55:00',20261025,20261025,true) && g_acceptance_pass;
   string filename="QM\\ftmo_acceptance\\"+InpAcceptanceRunId+"\\acceptance.json";
   int h=FileOpen(filename,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE)return INIT_FAILED;
   string report=StringFormat("{\"schema\":\"qm.ftmo-native-collector-acceptance/v1\",\"status\":\"%s\",\"collector_source_sha256\":\"%s\",\"basis\":\"NATIVE_TESTER_SCRIPTED_OBSERVATIONS\",\"cases\":[%s]}",g_acceptance_pass?"PASS":"FAIL",InpCollectorSourceSha,g_cases);
   FileWriteString(h,report+"\r\n");FileFlush(h);FileClose(h);
   return g_acceptance_pass?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
double OnTester(){return g_acceptance_pass?1:0;}
void OnDeinit(const int reason){CloseWriter();}
