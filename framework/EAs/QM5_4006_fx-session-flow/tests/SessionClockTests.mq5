#property strict
#property version "1.00"
#property description "QM5_4006 EA-local London/New-York clock contract tests"

#include "..\Strategy_SessionClock.mqh"

int OnInit()
  {
   if(!Strategy_SessionClockSelfTest())
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
