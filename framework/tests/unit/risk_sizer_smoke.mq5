#property strict

#include <QM/QM_RiskSizer.mqh>

bool AssertNear(const string label, const double actual, const double expected, const double eps = 1e-8)
  {
   if(MathAbs(actual - expected) <= eps)
      return true;

   Print(StringFormat("ASSERT_FAIL %s actual=%.8f expected=%.8f", label, actual, expected));
   return false;
  }

int OnInit()
  {
   QM_SymbolRiskSnapshot snap;
   snap.tick_value     = 1.0;
   snap.tick_size      = 0.00001;
   snap.point          = 0.00001;
   snap.volume_min     = 0.01;
   snap.volume_max     = 50.0;
   snap.volume_step    = 0.01;
   snap.contract_size  = 100000.0;
   snap.margin_initial = 0.0;

   if(!QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, 0.0, 1000.0, 1.0))
      return INIT_FAILED;

   double fixed_risk = QM_RiskSizerRiskMoney(100000.0);
   if(!AssertNear("fixed_risk_money", fixed_risk, 1000.0))
      return INIT_FAILED;

   double lots_fixed = QM_LotsForRiskFromSnapshot(snap, fixed_risk, 500.0);
   if(!AssertNear("lots_fixed", lots_fixed, 2.0))
      return INIT_FAILED;

   if(!QM_RiskSizerConfigure(QM_RISK_MODE_PERCENT, 1.0, 0.0, 1.0))
      return INIT_FAILED;

   double pct_risk = QM_RiskSizerRiskMoney(100000.0);
   if(!AssertNear("percent_risk_money", pct_risk, 1000.0))
      return INIT_FAILED;

   double lots_pct = QM_LotsForRiskFromSnapshot(snap, pct_risk, 500.0);
   if(!AssertNear("lots_percent", lots_pct, 2.0))
      return INIT_FAILED;

   if(!QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, 0.0, 1000.0, 0.5, 300.0))
      return INIT_FAILED;

   double capped_weighted_risk = QM_RiskSizerRiskMoney(100000.0);
   if(!AssertNear("weighted_capped_risk_money", capped_weighted_risk, 300.0))
      return INIT_FAILED;

   double lots_capped = QM_LotsForRiskFromSnapshot(snap, capped_weighted_risk, 500.0);
   if(!AssertNear("lots_weighted_capped", lots_capped, 0.60))
      return INIT_FAILED;

   Print("RISK_SIZER_SMOKE_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
