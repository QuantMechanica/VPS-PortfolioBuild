#ifndef QM_STRATEGY_MODULE_MQH
#define QM_STRATEGY_MODULE_MQH

#include "QM_Common.mqh"

// Strategy modules are state-owning sleeves hosted by a symbol-master EA.
// Implementations must inspect/manage only positions whose POSITION_MAGIC is
// Magic().  CheckEntry implementations must use the Phase-2.5 explicit
// dual-mode context:
//
//   QM_TM_OpenPosition(req, out_ticket, (int)Magic(), RiskMode(), RiskValue());
//
// A master must reject every enabled module whose RiskMode() is not PERCENT
// or FIXED, or whose RiskValue() is not strictly positive.
class CQMStrategyModule
  {
public:
   virtual bool             Init(const string symbol) { return true; }
   virtual void             Deinit() {}
   virtual bool             Enabled()      const { return false; }
   virtual long             Magic()        const = 0;
   virtual ENUM_TIMEFRAMES  TF()           const = 0;
   // Legacy Phase-1/2 percent-only knob. A module that only ever sizes
   // PERCENT may implement just this one; RiskMode()/RiskValue() below
   // default to reading it, so pre-Phase-3 placeholder slots need no change.
   virtual double           RiskPercent()  const { return 0.0; }
   // Phase-3 dual-mode knob (Phase 2.5 explicit FIXED/PERCENT sizing). A
   // module that needs FIXED (backtest regression) or genuine dual-mode
   // sizing overrides these two directly instead of RiskPercent().
   virtual QM_RiskMode      RiskMode()     const { return QM_RISK_MODE_PERCENT; }
   virtual double           RiskValue()    const { return RiskPercent(); }
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
