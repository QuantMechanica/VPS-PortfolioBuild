#property strict

#include <QM/QM_RiskSizer.mqh>

bool AssertNear(const string label, const double actual, const double expected, const double eps = 1e-8)
  {
   if(MathAbs(actual - expected) <= eps)
      return true;

   Print(StringFormat("ASSERT_FAIL %s actual=%.8f expected=%.8f", label, actual, expected));
   return false;
  }

bool AssertExact(const string label, const double actual, const double expected)
  {
   if(actual == expected)
      return true;

   Print(StringFormat("ASSERT_FAIL_EXACT %s actual=%.16f expected=%.16f", label, actual, expected));
   return false;
  }

bool AssertCondition(const string label, const bool condition)
  {
   if(condition)
      return true;

   Print(StringFormat("ASSERT_FAIL_CONDITION %s", label));
   return false;
  }

bool AssertMarginCapForSide(const string label,
                            const ENUM_ORDER_TYPE order_type,
                            const double entry_price,
                            const QM_SymbolRiskSnapshot &snapshot)
  {
   const double requested_lots = snapshot.volume_max;
   const double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   const double margin_budget = free_margin * QM_RISK_SIZER_MARGIN_HEADROOM;
   if(!AssertCondition(label + "_inputs",
                       requested_lots > 0.0 && entry_price > 0.0 &&
                       free_margin > 0.0 && margin_budget > 0.0))
      return false;

   double requested_margin = 0.0;
   if(!AssertCondition(label + "_requested_order_calc_margin",
                       OrderCalcMargin(order_type,
                                       _Symbol,
                                       requested_lots,
                                       entry_price,
                                       requested_margin) &&
                       requested_margin > 0.0))
      return false;

   const double actual_lots = QM_RiskSizerCapLotsByOrderMargin(_Symbol,
                                                                order_type,
                                                                entry_price,
                                                                requested_lots,
                                                                snapshot);
   if(!AssertCondition(label + "_positive_not_oversized",
                       actual_lots > 0.0 && actual_lots <= requested_lots))
      return false;

   const double volume_steps = actual_lots / snapshot.volume_step;
   if(!AssertNear(label + "_volume_grid", volume_steps, MathRound(volume_steps), 1e-8))
      return false;

   double actual_margin = 0.0;
   if(!AssertCondition(label + "_actual_order_calc_margin",
                       OrderCalcMargin(order_type,
                                       _Symbol,
                                       actual_lots,
                                       entry_price,
                                       actual_margin) &&
                       actual_margin > 0.0 &&
                       actual_margin <= margin_budget + MathMax(1e-8, margin_budget * 1e-10)))
      return false;

   if(requested_margin <= margin_budget + MathMax(1e-8, margin_budget * 1e-10))
     {
      if(!AssertExact(label + "_affordable_request_unchanged", actual_lots, requested_lots))
         return false;
      Print(StringFormat("MARGIN_CAP_NOT_REQUIRED side=%s requested=%.8f margin=%.8f budget=%.8f",
                         label,
                         requested_lots,
                         requested_margin,
                         margin_budget));
      return true;
     }

   if(!AssertCondition(label + "_active_cap_reduces_lots", actual_lots < requested_lots))
      return false;

   const double next_lots = QM_RiskSizerQuantizeLots(actual_lots + snapshot.volume_step,
                                                      snapshot.volume_min,
                                                      snapshot.volume_max,
                                                      snapshot.volume_step);
   if(next_lots > actual_lots && next_lots <= requested_lots)
     {
      double next_margin = 0.0;
      if(!AssertCondition(label + "_next_step_order_calc_margin",
                          OrderCalcMargin(order_type,
                                          _Symbol,
                                          next_lots,
                                          entry_price,
                                          next_margin) &&
                          next_margin > margin_budget))
         return false;
     }

   Print(StringFormat("MARGIN_CAP_ACTIVE side=%s requested=%.8f capped=%.8f requested_margin=%.8f actual_margin=%.8f budget=%.8f",
                      label,
                      requested_lots,
                      actual_lots,
                      requested_margin,
                      actual_margin,
                      margin_budget));
   return true;
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

   double explicit_pct_risk = QM_RiskSizerRiskMoney(100000.0, 0.25);
   if(!AssertNear("explicit_percent_risk_money", explicit_pct_risk, 250.0))
      return INIT_FAILED;

   // A per-call override must not mutate the configured legacy percentage.
   double pct_risk_after_override = QM_RiskSizerRiskMoney(100000.0);
   if(!AssertNear("percent_risk_after_override", pct_risk_after_override, 1000.0))
      return INIT_FAILED;

   if(!QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, 0.0, 1000.0, 0.5, 300.0))
      return INIT_FAILED;

   double capped_weighted_risk = QM_RiskSizerRiskMoney(100000.0);
   if(!AssertNear("weighted_capped_risk_money", capped_weighted_risk, 300.0))
      return INIT_FAILED;

   double lots_capped = QM_LotsForRiskFromSnapshot(snap, capped_weighted_risk, 500.0);
   if(!AssertNear("lots_weighted_capped", lots_capped, 0.60))
      return INIT_FAILED;

   double explicit_capped_risk = QM_RiskSizerRiskMoney(100000.0, 2.0);
   if(!AssertNear("explicit_percent_weighted_capped", explicit_capped_risk, 300.0))
      return INIT_FAILED;

   // Phase 2.5 exact-equivalence proof. Both paths receive the same equity,
   // fixed value, portfolio weight, cap, stop distance, and symbol snapshot.
   const double exact_equity = 123456.0;
   const double exact_fixed = 1234.5;
   const double exact_weight = 0.4;
   const double exact_cap = 600.0;
   const double exact_sl_points = 375.0;

   if(!QM_RiskSizerConfigure(QM_RISK_MODE_FIXED,
                             0.0,
                             exact_fixed,
                             exact_weight,
                             exact_cap))
      return INIT_FAILED;

   double global_fixed_risk = QM_RiskSizerRiskMoney(exact_equity);
   double explicit_fixed_risk = QM_RiskSizerRiskMoney(exact_equity,
                                                       QM_RISK_MODE_FIXED,
                                                       exact_fixed);
   if(!AssertExact("explicit_fixed_equals_global_fixed_risk_money",
                   explicit_fixed_risk,
                   global_fixed_risk))
      return INIT_FAILED;

   double global_fixed_lots = QM_LotsForRiskFromSnapshot(snap,
                                                          global_fixed_risk,
                                                          exact_sl_points);
   double explicit_fixed_lots = QM_LotsForRiskFromSnapshot(snap,
                                                            explicit_fixed_risk,
                                                            exact_sl_points);
   if(global_fixed_lots <= 0.0 ||
      !AssertExact("explicit_fixed_equals_global_fixed_lots",
                   explicit_fixed_lots,
                   global_fixed_lots))
      return INIT_FAILED;

   // Exercise the public symbol-level overload as well as the pure snapshot
   // primitive above. Both calls read the same tester symbol/account state.
   double global_fixed_symbol_lots = QM_LotsForRisk(_Symbol,
                                                     exact_sl_points);
   double explicit_fixed_symbol_lots = QM_LotsForRisk(_Symbol,
                                                       exact_sl_points,
                                                       QM_RISK_MODE_FIXED,
                                                       exact_fixed);
   if(global_fixed_symbol_lots <= 0.0 ||
      !AssertExact("explicit_fixed_equals_global_fixed_symbol_lots",
                   explicit_fixed_symbol_lots,
                   global_fixed_symbol_lots))
      return INIT_FAILED;

   // The explicit fixed value is per-call only: a different override must not
   // alter the configured global fixed value used by the following call.
   double explicit_fixed_override = QM_RiskSizerRiskMoney(exact_equity,
                                                           QM_RISK_MODE_FIXED,
                                                           2000.0);
   double global_fixed_after_override = QM_RiskSizerRiskMoney(exact_equity);
   if(!AssertExact("explicit_fixed_override_hits_cap",
                   explicit_fixed_override,
                   exact_cap) ||
      !AssertExact("global_fixed_after_explicit_override",
                   global_fixed_after_override,
                   global_fixed_risk))
      return INIT_FAILED;

   // Exercise the active cap on the explicit FIXED branch as a second exact
   // comparison (1234.5 * 0.4 exceeds 450.0).
   if(!QM_RiskSizerConfigure(QM_RISK_MODE_FIXED,
                             0.0,
                             exact_fixed,
                             exact_weight,
                             450.0))
      return INIT_FAILED;

   double global_fixed_capped = QM_RiskSizerRiskMoney(exact_equity);
   double explicit_fixed_capped = QM_RiskSizerRiskMoney(exact_equity,
                                                         QM_RISK_MODE_FIXED,
                                                         exact_fixed);
   if(!AssertExact("explicit_fixed_equals_global_fixed_capped",
                   explicit_fixed_capped,
                   global_fixed_capped))
      return INIT_FAILED;

   double global_fixed_capped_lots = QM_LotsForRiskFromSnapshot(snap,
                                                                 global_fixed_capped,
                                                                 exact_sl_points);
   double explicit_fixed_capped_lots = QM_LotsForRiskFromSnapshot(snap,
                                                                   explicit_fixed_capped,
                                                                   exact_sl_points);
   if(global_fixed_capped_lots <= 0.0 ||
      !AssertExact("explicit_fixed_equals_global_fixed_capped_lots",
                   explicit_fixed_capped_lots,
                   global_fixed_capped_lots))
      return INIT_FAILED;

   double global_fixed_capped_symbol_lots = QM_LotsForRisk(_Symbol,
                                                            exact_sl_points);
   double explicit_fixed_capped_symbol_lots = QM_LotsForRisk(_Symbol,
                                                              exact_sl_points,
                                                              QM_RISK_MODE_FIXED,
                                                              exact_fixed);
   if(global_fixed_capped_symbol_lots <= 0.0 ||
      !AssertExact("explicit_fixed_equals_global_fixed_capped_symbol_lots",
                   explicit_fixed_capped_symbol_lots,
                   global_fixed_capped_symbol_lots))
      return INIT_FAILED;

   // Phase-1 percent regression: the legacy explicit-percent overload and the
   // new mode-aware PERCENT wrapper must both equal the global PERCENT path.
   const double exact_percent = 0.75;
   if(!QM_RiskSizerConfigure(QM_RISK_MODE_PERCENT,
                             exact_percent,
                             0.0,
                             exact_weight,
                             exact_cap))
      return INIT_FAILED;

   double global_percent_exact = QM_RiskSizerRiskMoney(exact_equity);
   double explicit_percent_legacy = QM_RiskSizerRiskMoney(exact_equity,
                                                           exact_percent);
   double explicit_percent_mode = QM_RiskSizerRiskMoney(exact_equity,
                                                         QM_RISK_MODE_PERCENT,
                                                         exact_percent);
   if(!AssertExact("explicit_percent_legacy_equals_global_percent",
                   explicit_percent_legacy,
                   global_percent_exact) ||
      !AssertExact("explicit_percent_mode_equals_global_percent",
                   explicit_percent_mode,
                   global_percent_exact))
      return INIT_FAILED;

   double global_percent_lots = QM_LotsForRiskFromSnapshot(snap,
                                                            global_percent_exact,
                                                            exact_sl_points);
   double explicit_percent_lots = QM_LotsForRiskFromSnapshot(snap,
                                                              explicit_percent_mode,
                                                              exact_sl_points);
   if(global_percent_lots <= 0.0 ||
      !AssertExact("explicit_percent_equals_global_percent_lots",
                   explicit_percent_lots,
                   global_percent_lots))
      return INIT_FAILED;

   double global_percent_symbol_lots = QM_LotsForRisk(_Symbol,
                                                       exact_sl_points);
   double explicit_percent_legacy_symbol_lots = QM_LotsForRisk(_Symbol,
                                                                exact_sl_points,
                                                                exact_percent);
   double explicit_percent_mode_symbol_lots = QM_LotsForRisk(_Symbol,
                                                              exact_sl_points,
                                                              QM_RISK_MODE_PERCENT,
                                                              exact_percent);
   if(global_percent_symbol_lots <= 0.0 ||
      !AssertExact("explicit_percent_legacy_equals_global_percent_symbol_lots",
                   explicit_percent_legacy_symbol_lots,
                   global_percent_symbol_lots) ||
      !AssertExact("explicit_percent_mode_equals_global_percent_symbol_lots",
                   explicit_percent_mode_symbol_lots,
                   global_percent_symbol_lots))
      return INIT_FAILED;

   // Entry-only margin proof.  The caller runs this fixture on NDX.DWX to
   // exercise the active CFD/index cap; it remains valid on an affordable
   // symbol and reports MARGIN_CAP_NOT_REQUIRED instead.
   QM_SymbolRiskSnapshot margin_snapshot;
   MqlTick margin_quote;
   if(!AssertCondition("margin_snapshot",
                       QM_RiskSizerReadSymbolSnapshot(_Symbol, margin_snapshot)) ||
      !AssertCondition("margin_atomic_quote",
                       SymbolInfoTick(_Symbol, margin_quote) &&
                       margin_quote.ask > 0.0 && margin_quote.bid > 0.0) ||
      !AssertMarginCapForSide("buy",
                              ORDER_TYPE_BUY,
                              margin_quote.ask,
                              margin_snapshot) ||
      !AssertMarginCapForSide("sell",
                              ORDER_TYPE_SELL,
                              margin_quote.bid,
                              margin_snapshot))
      return INIT_FAILED;

   Print("RISK_SIZER_SMOKE_PASS");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ExpertRemove();
  }
