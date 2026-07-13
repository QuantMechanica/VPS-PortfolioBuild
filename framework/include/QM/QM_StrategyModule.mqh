#ifndef QM_STRATEGY_MODULE_MQH
#define QM_STRATEGY_MODULE_MQH

#include "QM_Common.mqh"

// Strategy modules are state-owning sleeves hosted by a symbol-master EA.
// Implementations must inspect/manage only positions whose POSITION_MAGIC is
// Magic().  CheckEntry implementations must use the Phase-1 explicit context:
//
//   QM_TM_OpenPosition(req, out_ticket, (int)Magic(), RiskPercent());
//
// A zero explicit risk selects the legacy host-risk fallback, so a master must
// reject every enabled module whose RiskPercent() is not strictly positive.
class CQMStrategyModule
  {
public:
   virtual bool             Init(const string symbol) { return true; }
   virtual void             Deinit() {}
   virtual bool             Enabled()      const { return false; }
   virtual long             Magic()        const = 0;
   virtual ENUM_TIMEFRAMES  TF()           const = 0;
   virtual double           RiskPercent()  const = 0;
   virtual bool             NoTrade(datetime now) { return false; }
   virtual void             ManageOpen() {}
   virtual void             CheckExit()  {}
   virtual void             CheckEntry() {}
  };

// Selection precondition: the caller has selected a position with
// PositionSelect*, PositionGetTicket, or PositionSelectByTicket.
bool QM_ModuleOwnsPosition(long magic)
  {
   return (magic > 0 && PositionGetInteger(POSITION_MAGIC) == magic);
  }

#endif // QM_STRATEGY_MODULE_MQH
