#property strict
#property version "1.00"
#property description "QuantMechanica no-trade ConsoleData self-test script"

#include "QM_ConsoleData_selftests.mqh"

void OnStart()
  {
   string failure="";
   const bool passed=QM_ConsoleDataSelfTest(failure);
   Print(passed?"QM_CONSOLE_DATA_SELF_TESTS PASS":"QM_CONSOLE_DATA_SELF_TESTS FAIL: "+failure);
  }
