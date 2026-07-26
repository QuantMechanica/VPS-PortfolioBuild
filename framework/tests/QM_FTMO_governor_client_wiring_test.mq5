#property strict
#property version "2.0"
#property description "Canonical book-EA wiring recipe for the FTMO governor client (compile/fault test)"

// WS-G' client wiring reference. Demonstrates the EXACT pattern every FTMO book
// sleeve adopts to consume the account-governor's published risk scale and fail
// CLOSED on anything short of a clean ALLOW snapshot. This is a compile/fault
// test only; it never trades. Live sleeves copy QM_ApplyGovernorScale verbatim
// and multiply their planned per-trade risk fraction by its return value.

#include <QM/QM_FTMOGovernorClient.mqh>

// Signed per-deployment identity (bound by the OWNER manifest / set file in a
// real sleeve). Defaults are non-deployable: an unset sleeve runs UNGUARDED
// only if it is explicitly not a governed FTMO sleeve.
input string qm_ftmo_governor_policy_id = "";
input string qm_ftmo_challenge_id       = "";
input bool   qm_ftmo_governor_required  = false; // true for FTMO book sleeves
input int    qm_ftmo_heartbeat_max_age  = 5;     // client clamps to 1..5 s

// Multiply a planned risk fraction by the governor's published scale. Fail
// CLOSED: if the governor is required but does not publish a fresh, generation-
// stable, policy-matched, unlocked, positive-scale snapshot for THIS account and
// challenge, planned risk collapses to zero (no entry). A sleeve that is not a
// governed FTMO sleeve passes its planned risk through unchanged.
double QM_ApplyGovernorScale(const double planned_risk)
  {
   if(planned_risk <= 0.0)
      return 0.0;
   if(!qm_ftmo_governor_required)
      return planned_risk;                       // e.g. DXZ book: unguarded
   double scale=0.0;
   string reason="";
   if(!QM_FTMO_ReadGovernorScale(qm_ftmo_governor_policy_id,qm_ftmo_challenge_id,
                                 qm_ftmo_heartbeat_max_age,scale,reason))
     {
      PrintFormat("QM_FTMO_GOVERNOR_BLOCK reason=%s",reason);
      return 0.0;                                // fail closed
     }
   if(scale <= 0.0 || scale > 1.0)               // defence in depth
      return 0.0;
   return planned_risk*scale;
  }

int OnInit()
  {
   // Unguarded sleeve: planned risk passes through unchanged.
   if(!qm_ftmo_governor_required && QM_ApplyGovernorScale(0.01) != 0.01)
      return INIT_FAILED;

   // Zero / negative planned risk is always zero.
   if(QM_ApplyGovernorScale(0.0) != 0.0 || QM_ApplyGovernorScale(-1.0) != 0.0)
      return INIT_FAILED;

   // Guarded path with no published governor state must fail closed to zero.
   double scale=1.0;
   string reason="";
   const bool ok=QM_FTMO_ReadGovernorScale("FTMO_2S_P1_100K_V2","challenge_20260713",
                                           qm_ftmo_heartbeat_max_age,scale,reason);
   if(ok)                                        // no governor running in a compile test
      return INIT_FAILED;
   if(scale != 0.0)
      return INIT_FAILED;
   // A required-but-unavailable governor yields zero risk (no entry).
   Print("FTMO_GOVERNOR_CLIENT_WIRING_TEST_PASS reason=",reason);
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   // Illustrative live use: never open with a zero governed risk fraction.
   const double planned=0.01;
   const double governed=QM_ApplyGovernorScale(planned);
   if(governed <= 0.0)
      return; // blocked by the governor (or unavailable) -> no entry this tick
   // ... a real sleeve would size its order by `governed` here ...
  }
