#property strict
#property version "1.00"
#property description "QM5_4007 pure MAC5 signal and target-delta contract tests"

#include "..\Strategy_MAC5Core.mqh"

int OnInit()
  {
   if(!Strategy_MAC5CoreSelfTest())
     {
      Print("MAC5_CORE_TEST_FAIL");
      return INIT_FAILED;
     }
   Print("MAC5_CORE_TEST_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
