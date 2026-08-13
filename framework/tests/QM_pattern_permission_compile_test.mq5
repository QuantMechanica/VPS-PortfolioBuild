//+------------------------------------------------------------------+
//| QM_pattern_permission_compile_test.mq5                            |
//| Compile-only harness for QM_PatternPermission.mqh.                |
//|                                                                    |
//| Not a strategy and never dispatched: it exists so the opt-in       |
//| pattern-permission include is proven to compile strict-clean       |
//| WITHOUT touching QM_Common.mqh or any fleet EA. It references      |
//| every public entry point so an unused-symbol elision cannot hide   |
//| a syntax error.                                                    |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include <QM/QM_PatternPermission.mqh>

void OnStart()
  {
   QM_PatternProfile profile;
   QM_PP_ProfileInit(profile, "COMPILE_TEST", PERIOD_D1, 1);
   QM_PP_ProfileAddBuy(profile, QM_PP_ENGULFING_BEAR);
   QM_PP_ProfileAddSell(profile, QM_PP_ENGULFING_BULL);

   const string key = QM_PP_ProfileKey(profile);
   const int need = QM_PP_ProfileRequiredBars(profile);

   QM_PermissionResult res = QM_PatternPermissionEvaluate(_Symbol, PERIOD_D1, 1, profile);

   // Touch every result field so none can be optimised away silently.
   PrintFormat("pp_compile_test key=%s need=%d valid=%s buy=%s sell=%s bar=%s reason=%s",
               key, need,
               (string)res.valid, (string)res.allow_buy, (string)res.allow_sell,
               TimeToString(res.reference_bar_time), res.reason);

   // Exercise the predicate evaluator directly on a loaded window.
   QM_PPBars bars;
   if(QM_PP_LoadBars(_Symbol, PERIOD_D1, 1, need, bars))
     {
      int fired = 0;
      const QM_PatternId probes[] =
        {
         QM_PP_DOJI, QM_PP_HAMMER, QM_PP_ENGULFING_BULL, QM_PP_NR7,
         QM_PP_GAP_UP, QM_PP_ZSCORE_HIGH, QM_PP_VOL_PERCENTILE_LOW,
         QM_PP_EFFICIENCY_RATIO_HIGH, QM_PP_VOLUME_CLIMAX,
         QM_PP_THIRD_FRIDAY, QM_PP_QUARTER_END,
         QM_PP_TREND_STRENGTH_UP_STRONG, QM_PP_RANGING
        };
      for(int i = 0; i < ArraySize(probes); ++i)
         if(QM_PP_Evaluate(probes[i], bars))
            fired++;
      PrintFormat("pp_compile_test probes=%d fired=%d", ArraySize(probes), fired);
     }
  }
//+------------------------------------------------------------------+
