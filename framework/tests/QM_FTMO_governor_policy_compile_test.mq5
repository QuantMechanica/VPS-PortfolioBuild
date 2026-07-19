#property strict
#property version "2.0"

#include <QM/QM_FTMOGovernorPolicy.mqh>

bool Near(const double left,const double right)
  {
   return (MathAbs(left-right) < 0.000001);
  }

bool CheckPolicyIdentity(const string policy_id,const double fingerprint)
  {
   QM_FTMO_GovernorPolicy policy;
   return (QM_FTMO_SelectPolicy(policy_id,policy) &&
           QM_FTMO_IsExactPolicy(policy) &&
           QM_FTMO_PolicyFingerprintNumber(policy) == fingerprint);
  }

int OnInit()
  {
   if(QM_FTMO_CONTRACT_REVISION != 2 ||
      !Near(QM_FTMO_POLICY_VERSION,2.0) ||
      !CheckPolicyIdentity("FTMO_2S_P1_100K_V2",1215771617389199.0) ||
      !CheckPolicyIdentity("FTMO_2S_P2_100K_V2",2586499533483248.0) ||
      !CheckPolicyIdentity("FTMO_2S_FUNDED_100K_V2",1248702263814813.0))
      return INIT_FAILED;

   QM_FTMO_GovernorPolicy p1;
   if(!QM_FTMO_SelectPolicy("FTMO_2S_P1_100K_V2",p1))
      return INIT_FAILED;
   double official=0.0,protected_floor=0.0,liquidation=0.0,entry=0.0;
   if(!QM_FTMO_Floors(100000.0,p1,official,protected_floor,liquidation,entry) ||
      !Near(official,95000.0) || !Near(protected_floor,95200.0) ||
      !Near(liquidation,98750.0) || !Near(entry,99100.0) ||
      !Near(QM_FTMO_EntryRiskScale(99550.0,entry,p1),0.5) ||
      !Near(QM_FTMO_EntryRiskScale(108000.0,entry,p1),0.75) ||
      !Near(QM_FTMO_EntryRiskScale(109500.0,entry,p1),0.50))
      return INIT_FAILED;

   const datetime spring_before = D'2026.03.29 00:30:00';
   const datetime spring_after = D'2026.03.29 01:30:00';
   if(QM_FTMO_PragueUTCOffsetSeconds(spring_before) != 3600 ||
      QM_FTMO_PragueUTCOffsetSeconds(spring_after) != 7200)
      return INIT_FAILED;

   QM_FTMO_GovernorDecision decision;
   if(!QM_FTMO_EvaluateSnapshot(D'2026.01.15 14:00:00',99000.0,98749.0,
                                 100000.0,1,2,0,false,false,p1,decision) ||
      decision.reason != QM_FTMO_GOVERNOR_EFFECTIVE_DAILY_FLOOR ||
      !decision.persist_lock || !decision.flatten_required || decision.entry_allowed)
      return INIT_FAILED;

   if(!QM_FTMO_EvaluateSnapshot(D'2026.01.15 15:00:00',94000.0,93999.0,
                                 100000.0,1,1,0,true,false,p1,decision) ||
      decision.reason != QM_FTMO_GOVERNOR_TOTAL_FLOOR)
      return INIT_FAILED;

   if(!QM_FTMO_EvaluateSnapshot(D'2026.07.01 12:00:00',109500.0,110100.0,
                                 109000.0,4,1,1,false,false,p1,decision) ||
      decision.reason != QM_FTMO_GOVERNOR_TARGET_CAPTURE ||
      !decision.flatten_required || decision.target_complete)
      return INIT_FAILED;

   QM_FTMO_GovernorPolicy p2;
   if(!QM_FTMO_SelectPolicy("FTMO_2S_P2_100K_V2",p2) ||
      !QM_FTMO_EvaluateSnapshot(D'2026.07.01 12:00:00',105000.0,105000.0,
                                 104000.0,4,0,0,false,false,p2,decision) ||
      decision.reason != QM_FTMO_GOVERNOR_TARGET_COMPLETE ||
      !decision.target_complete || decision.entry_allowed)
      return INIT_FAILED;

   QM_FTMO_GovernorPolicy funded;
   if(!QM_FTMO_SelectPolicy("FTMO_2S_FUNDED_100K_V2",funded) ||
      !QM_FTMO_Floors(100000.0,funded,official,protected_floor,liquidation,entry) ||
      !Near(liquidation,99500.0) || !Near(entry,99650.0) ||
      !Near(QM_FTMO_EntryRiskScale(99825.0,entry,funded),0.5) ||
      !QM_FTMO_EvaluateSnapshot(D'2026.07.01 12:00:00',110000.0,110000.0,
                                 100000.0,0,0,0,false,false,funded,decision) ||
      decision.reason != QM_FTMO_GOVERNOR_ALLOW || decision.target_reached ||
      decision.target_complete || !decision.entry_allowed)
      return INIT_FAILED;

   p1.internal_total_floor=80000.0;
   if(QM_FTMO_IsExactPolicy(p1) || QM_FTMO_PolicyFingerprintNumber(p1) != 0.0)
      return INIT_FAILED;

   Print("FTMO_GOVERNOR_POLICY_COMPILE_TEST_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
  }
