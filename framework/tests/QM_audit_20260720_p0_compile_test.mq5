// QM framework audit 2026-07-20 P0-bundle compile test (pattern: FTMO governor
// compile tests). Proves the full include graph still compiles after the audit
// bundle and pins the new API signatures: live-following risk cap, clamp
// evidence hooks, pending-order duplicate guard, held-period primitives, and
// failed-modify suppression. OnInit doubles as a logic smoke when attached.
#property strict
#property version "1.0"

#include <QM/QM_Common.mqh>

int OnInit()
  {
   // P0.2 — live-following percent cap with FIXED-rail fallback.
   QM_RiskSizerSetCapPct(1.0);
   if(QM_RiskSizerPercentCap(100000.0) != 1000.0)
      return INIT_FAILED;
   QM_RiskSizerSetCapPct(0.0);
   if(QM_RiskSizerPercentCap(100000.0) != g_qm_risk_per_trade_cap_money)
      return INIT_FAILED;

   // P1.4 — clamp evidence hooks.
   g_qm_risk_clamp_flag = false;
   QM_RiskSizerNoteClamp("compile_test", 2.0, 1.0);
   if(!g_qm_risk_clamp_flag || g_qm_risk_clamp_kind != "compile_test" ||
      g_qm_risk_clamp_from != 2.0 || g_qm_risk_clamp_to != 1.0)
      return INIT_FAILED;
   g_qm_risk_clamp_flag = false;

   // P0.5 — pending duplicate guard (no orders exist in this context).
   if(QM_EntryHasPendingOrder(123456789, _Symbol, ORDER_TYPE_BUY_STOP))
      return INIT_FAILED;

   // P0.4 — held-period primitives: unknown states must report -1, never "due".
   if(QM_TM_HeldPeriods(_Symbol, PERIOD_D1, 0) != -1)
      return INIT_FAILED;
   if(QM_TM_HeldPeriodsForMagic(123456789, _Symbol, PERIOD_D1) != -1)
      return INIT_FAILED;

   // Failed-modify suppression state machine.
   QM_TM_RememberFailedModify(42, 1.2345, 2.3456);
   if(!QM_TM_ModifySuppressed(42, 1.2345, 2.3456))
      return INIT_FAILED;
   if(QM_TM_ModifySuppressed(42, 1.5000, 2.3456))   // changed target retries
      return INIT_FAILED;
   QM_TM_ClearFailedModify(42);
   if(QM_TM_ModifySuppressed(42, 1.2345, 2.3456))
      return INIT_FAILED;

   Print("QM_AUDIT_20260720_P0_COMPILE_TEST_OK");
   return INIT_SUCCEEDED;
  }

void OnTick() {}
