#property strict

#include <QM/QM_Common.mqh>

// Compile-only overload contract.  The false branch is still type-checked by
// MetaEditor but can never submit an order if this fixture is attached.
void CompileEntryExecutionApi()
  {
   QM_EntryRequest request;
   ulong ticket = 0;
   if(false)
     {
      // Historical calls retain transient retry by default.
      QM_TM_OpenPosition(request, ticket);
      QM_TM_OpenPosition(request, ticket, 0, 0.25);
      QM_TM_OpenPosition(request, ticket, 0, QM_RISK_MODE_PERCENT, 0.25);

      // Event-contract calls explicitly select exactly one broker submission.
      QM_TM_OpenPosition(request,
                         ticket,
                         0,
                         0.0,
                         QM_TRADE_SEND_ONCE);
      QM_TM_OpenPosition(request,
                         ticket,
                         0,
                         QM_RISK_MODE_PERCENT,
                         0.25,
                         QM_TRADE_SEND_ONCE);
     }
  }

int OnInit()
  {
   CompileEntryExecutionApi();
   Print("ENTRY_EXECUTION_COMPILE_SMOKE_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
