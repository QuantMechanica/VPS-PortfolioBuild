#property strict
#property version "2.00"
#property description "No-trade Version 2 chart presentation self-tests"

#include "QM_ChartPresentationV2_selftests.mqh"

// Opt-in, disposable QA chart only. Default execution is entirely pure.
input bool qm_verify_chart_roundtrip=false;
input bool qm_verify_zoom_roundtrip=false;

void OnStart()
  {
   string failure="";
   bool passed=QM_ChartPresentationV2SelfTest(failure);
   if(passed && qm_verify_chart_roundtrip)
      passed=QM_ChartPresentationV2ChartSelfTest(ChartID(),failure);
   if(passed && qm_verify_zoom_roundtrip)
      passed=QM_ChartPresentationV2ZoomSelfTest(ChartID(),failure,true);
   Print(passed?"QM_CHART_PRESENTATION_V2_SELF_TESTS PASS":"QM_CHART_PRESENTATION_V2_SELF_TESTS FAIL: "+failure);
  }
