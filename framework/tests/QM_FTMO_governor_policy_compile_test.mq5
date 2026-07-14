#property strict
#property version "1.0"

#include <QM/QM_FTMOGovernorPolicy.mqh>

bool Near(const double left,const double right)
  {
   return (MathAbs(left-right) < 0.000001);
  }

int OnInit()
  {
   QM_FTMO_GovernorPolicy policy;
   QM_FTMO_DefaultPolicy(policy);
   if(!QM_FTMO_IsExactV1Policy(policy) ||
      QM_FTMO_V1_CONTRACT_REVISION != 1 ||
      QM_FTMO_V1_FINGERPRINT_NUMBER != 3543540590062.0)
      return INIT_FAILED;

   double daily=0.0,protected_floor=0.0,effective=0.0;
   if(!QM_FTMO_DailyFloors(100000.0,policy,daily,protected_floor,effective))
      return INIT_FAILED;
   if(!Near(daily,95500.0) || !Near(protected_floor,92000.0) ||
      !Near(effective,95500.0) ||
      !Near(QM_FTMO_EntryRiskScale(97500.0,effective,policy),0.5))
      return INIT_FAILED;

   const datetime spring_before = D'2026.03.29 00:30:00';
   const datetime spring_after = D'2026.03.29 01:30:00';
   if(QM_FTMO_PragueUTCOffsetSeconds(spring_before) != 3600 ||
      QM_FTMO_PragueUTCOffsetSeconds(spring_after) != 7200)
      return INIT_FAILED;

   QM_FTMO_GovernorDecision decision;
   if(!QM_FTMO_EvaluateSnapshot(D'2026.01.15 14:00:00',96000.0,95500.0,
                                100000.0,1,2,0,false,false,policy,decision))
      return INIT_FAILED;

   if(!QM_FTMO_EvaluateSnapshot(D'2026.01.15 15:00:00',90000.0,89999.0,
                                100000.0,1,1,0,true,false,policy,decision) ||
      decision.reason != QM_FTMO_GOVERNOR_TOTAL_FLOOR)
      return INIT_FAILED;

   if(!QM_FTMO_EvaluateSnapshot(D'2026.07.01 12:00:00',109500.0,110100.0,
                                109000.0,4,1,1,false,false,policy,decision) ||
      decision.reason != QM_FTMO_GOVERNOR_TARGET_CAPTURE ||
      !decision.flatten_required || decision.target_complete)
      return INIT_FAILED;

   policy.total_loss_floor=80000.0;
   if(QM_FTMO_IsExactV1Policy(policy))
      return INIT_FAILED;
   if(decision.reason != QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR ||
      !decision.persist_lock || !decision.flatten_required || decision.entry_allowed)
      return INIT_FAILED;

   Print("FTMO_GOVERNOR_POLICY_COMPILE_TEST_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
  }
