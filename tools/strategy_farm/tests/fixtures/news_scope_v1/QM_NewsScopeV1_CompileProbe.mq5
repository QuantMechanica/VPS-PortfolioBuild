#property strict
#property version "1.00"
// Non-trading compile probe. Not an inventory EA and not queued as a strategy.
#include "../../../../../framework/include/QM/QM_NewsScopeV1.mqh"
QM_NewsScopeV1 scope;
int OnInit()
  {
   string ids="";
   if(scope.Entry("EURUSD",D'2026.01.01',ids)!=QM_SCOPE_DEFER_TO_LEGACY)
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }
void OnTick() {}
