#ifndef QM_MOD_TEMPLATE_MQH
#define QM_MOD_TEMPLATE_MQH

#include "../QM_StrategyModule.mqh"

// Phase-3 copy template.  It is deliberately disabled and contains no
// strategy logic.  A real module replaces the three placeholder values and
// implements only the lifecycle/filter/manage/exit/entry hooks it needs.
class CQMModTemplate : public CQMStrategyModule
  {
public:
   virtual bool            Enabled()     const { return false; }
   virtual long            Magic()       const { return 0; }
   virtual ENUM_TIMEFRAMES TF()          const { return PERIOD_D1; }
   virtual double          RiskPercent() const { return 0.0; }
  };

#endif // QM_MOD_TEMPLATE_MQH
