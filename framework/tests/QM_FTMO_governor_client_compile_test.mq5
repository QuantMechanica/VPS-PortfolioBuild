#property strict
#property version "1.0"

#include <QM/QM_FTMOGovernorClient.mqh>

int OnInit()
  {
   double scale=1.0;
   string reason="";
   if(QM_FTMO_ReadGovernorScale("WRONG_POLICY","challenge_20260713",2,scale,reason))
      return INIT_FAILED;
   if(scale != 0.0 || reason != "GOVERNOR_CLIENT_CONFIG_INVALID")
      return INIT_FAILED;
   if(!QM_FTMO_IdentifierValid("challenge_20260713") ||
      QM_FTMO_IdentifierValid("challenge id with spaces"))
      return INIT_FAILED;
   if(StringLen(QM_FTMO_StateKey(12345678,"challenge_20260713","heartbeat_utc")) > 63)
      return INIT_FAILED;
   Print("FTMO_GOVERNOR_CLIENT_COMPILE_TEST_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
  }
