//+------------------------------------------------------------------+
//| Compile probe for QM_PropFirm.mqh - not a tradable EA.            |
//| Exercises every exported symbol so unused-code elision cannot     |
//| hide a syntax or signature error.                                 |
//+------------------------------------------------------------------+
#property strict
#include <QM/QM_Logger.mqh>
#include <QM/QM_PropFirm.mqh>

int OnInit()
  {
   // Phase validators + derived getters (added 2026-07-27 phase selector).
   // Exercise them so a signature or type error cannot be elided.
   if(!QM_PropPhaseValidateCap(1.0))
      return INIT_FAILED;
   if(!QM_PropPhaseValidateWeekend(true))
      return INIT_FAILED;
   const double target_pct = QM_PropTargetPct();
   const bool   flatten    = QM_PropFlattenEnabled();
   const string phase_name = QM_PropPhaseName(prop_phase);
   // Proof-of-effect helper: the probe has no risk sizer, so pass a literal
   // effective cap; a real EA passes g_qm_risk_per_trade_cap_pct.
   QM_PropLogEffectiveCap(1.0, 1.0);
   Comment(StringFormat("phase=%s target_pct=%.1f flatten=%s",
                        phase_name, target_pct, flatten ? "true" : "false"));

   if(!QM_PropInit(9999))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(!QM_PropEntryAllowed(99990000))
      return;
   const double basis = QM_PropRiskBasis(AccountInfoDouble(ACCOUNT_BALANCE));
   const double scale = QM_PropRiskScale();
   if(basis > 0.0 && scale > 0.0)
      Comment(StringFormat("basis=%.2f scale=%.2f day_key=%d", basis, scale,
                           QM_PropDayKey(TimeCurrent())));
  }

void OnDeinit(const int reason)
  {
   QM_PropSaveState();
  }
