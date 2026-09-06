// Native Strategy Tester acceptance for the FTMO M13 account-control contract.
// The fixture is tester-only and never writes production halt files.
#property strict
#property version "1.00"

#include <QM/QM_FTMOAccountControl.mqh>

input string InpAcceptanceRunId="UNSET";
input string InpSourceSha="UNSET";

bool g_acceptance_pass=false;
string g_cases="";

void RecordCase(const string name,const bool pass,
                const QM_FTMO_AccountControlDecision &decision,
                const int expected_reason)
  {
   if(g_cases != "")
      g_cases+=",";
   g_cases+=StringFormat(
      "{\"case\":\"%s\",\"pass\":%s,\"expected_reason\":%d,"
      "\"observed_reason\":%d,\"entry_allowed\":%s,"
      "\"flatten_required\":%s,\"persist_halt\":%s}",
      name,pass?"true":"false",expected_reason,(int)decision.reason,
      decision.entry_allowed?"true":"false",
      decision.flatten_required?"true":"false",
      decision.persist_halt?"true":"false");
  }

bool EvaluateCase(const string name,const datetime timestamp_utc,
                  const datetime broker_time,const double equity,
                  const bool persisted_halt,const bool news_allowed,
                  const int expected_reason,const bool expected_flatten,
                  const bool expected_persist,
                  const QM_FTMO_GovernorPolicy &policy)
  {
   QM_FTMO_AccountControlDecision decision;
   const bool evaluated=QM_FTMO_EvaluateAccountControl(
      timestamp_utc,broker_time,100000.0,equity,100000.0,0,1,0,
      false,false,persisted_halt,news_allowed,21,5,policy,decision);
   const bool pass=(evaluated && (int)decision.reason == expected_reason &&
                    !decision.entry_allowed &&
                    decision.flatten_required == expected_flatten &&
                    decision.persist_halt == expected_persist);
   RecordCase(name,pass,decision,expected_reason);
   return pass;
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || InpAcceptanceRunId == "UNSET" ||
      StringLen(InpSourceSha) != 64 ||
      StringFind(InpAcceptanceRunId,"..") >= 0 ||
      StringFind(InpAcceptanceRunId,":") >= 0)
      return INIT_PARAMETERS_INCORRECT;

   QM_FTMO_GovernorPolicy policy;
   if(!QM_FTMO_SelectPolicy("FTMO_2S_P1_100K_V2",policy))
      return INIT_FAILED;

   // Prague midnight floor is 95,000; the immutable internal liquidation
   // floor is tighter, so 94,999 must be classified as a daily hard stop.
   g_acceptance_pass=EvaluateCase(
      "daily_breach_prague_midnight",D'2026.09.02 10:00:00',
      D'2026.09.02 12:00:00',94999.0,false,true,
      QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR,true,true,policy);
   g_acceptance_pass=EvaluateCase(
      "static_total_breach",D'2026.09.02 10:01:00',
      D'2026.09.02 12:01:00',89999.0,false,true,
      QM_FTMO_GOVERNOR_TOTAL_FLOOR,true,true,policy) && g_acceptance_pass;
   g_acceptance_pass=EvaluateCase(
      "friday_cutoff",D'2026.09.04 18:55:00',
      D'2026.09.04 20:55:00',100000.0,false,true,
      QM_FTMO_GOVERNOR_WEEKEND_FLAT,true,false,policy) && g_acceptance_pass;
   g_acceptance_pass=EvaluateCase(
      "mandatory_news_blackout",D'2026.09.02 10:02:00',
      D'2026.09.02 12:02:00',100000.0,false,false,
      QM_FTMO_GOVERNOR_NEWS_BLACKOUT,false,false,policy) && g_acceptance_pass;
   g_acceptance_pass=EvaluateCase(
      "restart_halt_persistence",D'2026.09.07 10:00:00',
      D'2026.09.07 12:00:00',100000.0,true,true,
      QM_FTMO_GOVERNOR_HALT_LATCHED,true,true,policy) && g_acceptance_pass;

   const string filename="QM\\ftmo_governor_acceptance\\"+
                         InpAcceptanceRunId+"\\acceptance.json";
   int handle=FileOpen(filename,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return INIT_FAILED;
   const string report=StringFormat(
      "{\"schema\":\"qm.ftmo-governor-native-acceptance/v1\","
      "\"status\":\"%s\",\"source_sha256\":\"%s\","
      "\"basis\":\"NATIVE_TESTER_PURE_ACCOUNT_CONTROL\",\"cases\":[%s]}",
      g_acceptance_pass?"PASS":"FAIL",InpSourceSha,g_cases);
   FileWriteString(handle,report+"\r\n");
   FileFlush(handle);
   FileClose(handle);
   return g_acceptance_pass ? INIT_SUCCEEDED : INIT_FAILED;
  }

void OnTick() {}
double OnTester() { return g_acceptance_pass ? 1.0 : 0.0; }

