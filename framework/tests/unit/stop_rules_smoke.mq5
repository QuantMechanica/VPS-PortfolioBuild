#property strict

#include <QM/QM_StopRules.mqh>

bool AssertNear(const string label,
                const double actual,
                const double expected,
                const double eps = 1e-8)
  {
   if(MathAbs(actual - expected) <= eps)
      return true;

   PrintFormat("[STOP_RULES_TEST][FAIL] %s actual=%.8f expected=%.8f", label, actual, expected);
   return false;
  }

int OnInit()
  {
   bool ok = true;
   string sym = _Symbol;
   double entry = 1.20000;

   ok &= AssertNear("stop_from_distance_buy",
                    QM_StopRulesStopFromDistance(sym, QM_BUY, entry, 0.00100),
                    1.19900);
   ok &= AssertNear("stop_from_distance_sell",
                    QM_StopRulesStopFromDistance(sym, QM_SELL, entry, 0.00100),
                    1.20100);

   ok &= AssertNear("take_from_distance_buy",
                    QM_StopRulesTakeFromDistance(sym, QM_BUY, entry, 0.00200),
                    1.20200);
   ok &= AssertNear("take_from_distance_sell",
                    QM_StopRulesTakeFromDistance(sym, QM_SELL, entry, 0.00200),
                    1.19800);

   ok &= AssertNear("stop_atr_from_value_buy",
                    QM_StopATRFromValue(sym, QM_BUY, entry, 0.00100, 1.5),
                    1.19850);
   ok &= AssertNear("stop_atr_from_value_sell",
                    QM_StopATRFromValue(sym, QM_SELL, entry, 0.00100, 1.5),
                    1.20150);

   ok &= AssertNear("stop_structure_buy",
                    QM_StopStructureFromExtremes(sym, QM_BUY, 1.19123, 1.20789),
                    1.19123);
   ok &= AssertNear("stop_structure_sell",
                    QM_StopStructureFromExtremes(sym, QM_SELL, 1.19123, 1.20789),
                    1.20789);

   ok &= AssertNear("stop_volatility_from_adr_buy",
                    QM_StopVolatilityFromADR(sym, QM_BUY, entry, 0.01000, 0.5),
                    1.19500);
   ok &= AssertNear("stop_volatility_from_adr_sell",
                    QM_StopVolatilityFromADR(sym, QM_SELL, entry, 0.01000, 0.5),
                    1.20500);

   ok &= AssertNear("take_rr_buy",
                    QM_TakeRR(sym, QM_BUY, entry, 1.19800, 2.0),
                    1.20400);
   ok &= AssertNear("take_rr_sell",
                    QM_TakeRR(sym, QM_SELL, entry, 1.20200, 1.5),
                    1.19700);

   ok &= AssertNear("take_atr_from_value_buy",
                    QM_TakeATRFromValue(sym, QM_BUY, entry, 0.00100, 1.25),
                    1.20125);
   ok &= AssertNear("take_atr_from_value_sell",
                    QM_TakeATRFromValue(sym, QM_SELL, entry, 0.00100, 1.25),
                    1.19875);

   if(!ok)
     {
      Print("[STOP_RULES_TEST] FAIL");
      return INIT_FAILED;
     }

   Print("[STOP_RULES_TEST] PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
