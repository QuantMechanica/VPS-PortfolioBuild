# Offline mechanical-rule discovery — 2026-09-22

Research-only offline discovery; no runtime ML model is emitted.

## Result

Evaluated **161,420** direction-specific rules across 219 symbol/session groups and 71 closed-data features. BH FDR 10% rejected 527; **6** rules also survived the locked 2022 rule-selection validation.

States: `{"CLEAR_REJECT": 121800, "UNKNOWN": 39614, "WORTH_MT5_TEST": 6}`. Neighbouring-threshold checks: `{"FRAGILE": 4, "NOT_APPLICABLE": 2, "ROBUST": 0}` across 8 variants.

The canonical all-trial ledger has 161,420 rows and SHA-256 `5ca1f59e981c42ca4ad0dd2fc0ee4c242ccc212de2a049a77ba63fdffd677760`; the compact machine JSON materializes all FDR discoveries and all final candidates.

Discovery used 2018-07..2021-12, validation used only 2022, and 2023-2025 was not opened. Shallow CART, association rules, and boosted-stump importance were used only to rank explicit boolean conjunctions.

## Mechanical candidates

### MLDISC-2B5EA12F4567CBBB165B

```json
{
 "COST_SENSITIVITY": "base F2 round-trip prior in discovery; mandatory doubled-cost F2 falsification next",
 "DISCOVERY_METHODS": [
  "ASSOCIATION_RULE"
 ],
 "DISCOVERY_SAMPLE": {
  "metrics": {
   "hit_rate": 0.77777778,
   "mean_net_r": 0.20263267,
   "median_net_r": 0.18007484,
   "n": 45,
   "p_one_sided": 0.00012031046570643516,
   "t_stat": 3.67204114
  },
  "period": [
   "2018-07-02",
   "2021-12-31"
  ]
 },
 "DISCOVERY_SUPPORT": 0.06493506,
 "ECONOMIC_RATIONALE": "NONE unless separately supplied by independent critique; statistical condition only",
 "ENTRY_RULE": "After NY_CASH is closed, enter LONG at the next target-window bar open when ref_gbpusd_ma_regime == -1 AND target_day_of_week == 2; skip the entry during the mandatory PRE30/POST30 high-impact news blackout",
 "EXECUTION_SYMBOL": "UK100.DWX",
 "EXIT_RULE": "no profit target; fixed time exit at the end of ASIA, with framework Friday-close cap",
 "EXPECTED_BOOK_ROLE": "session-flat discovery candidate; role unproven until F2/MT5 evidence",
 "EXPECTED_OVERLAP": "concentrated in ASIA and named symbols",
 "FALSIFICATION_TEST": "pre-register unchanged rule for 2023-2025 F2 prescreen; reject on sign/effect failure, double-cost failure, or MT5 mismatch",
 "FDR_Q_VALUE": 0.04054387343284502,
 "HYPOTHESIS_ID": "MLDISC-2B5EA12F4567CBBB165B",
 "MECHANICAL_RULE": {
  "all": [
   {
    "feature": "ref_gbpusd_ma_regime",
    "negated": false,
    "op": "==",
    "value": -1
   },
   {
    "feature": "target_day_of_week",
    "negated": false,
    "op": "==",
    "value": 2
   }
  ],
  "condition_evaluator": "tools.strategy_farm.research.ml_rule_discovery:mechanical_rule_matches",
  "direction": "LONG",
  "entry": "NEXT_BAR_OPEN_AFTER_FEATURE_WINDOW",
  "execution_engine": "tools/strategy_farm/session_tools/velocity_family_f2_cash_session_0921.py:simulate",
  "feature_schema": "qm.session-features/v2",
  "feature_session": "NY_CASH",
  "flat": {
   "at": "TARGET_SESSION_END",
   "friday_server_cap": "21:00"
  },
  "missing_feature_policy": "NO_TRADE",
  "news_blackout": {
   "currencies": "strict execution-symbol currencies",
   "impact": "HIGH",
   "post_minutes": 30,
   "pre_minutes": 30
  },
  "risk": {
   "RISK_FIXED": 1000,
   "RISK_PERCENT": 0
  },
  "schema": "qm.f2-mechanical-session-rule/v1",
  "statistics_engine": "velocity_family_f1_sweep_0921.py:period_stats + velocity_family_f2_cash_session_0921.py:bootstrap_pass_prob",
  "stop": {
   "cash_atr_min": 0.3,
   "gap_through": "WORSE_OF_LEVEL_OR_BREACH_BAR_OPEN",
   "round_trip_spread_multiple_min": 5.0,
   "target_window_atr": 1.0
  },
  "target": null,
  "target_session": "ASIA"
 },
 "NEIGHBORING_THRESHOLD_ROBUSTNESS": {
  "checks": [],
  "definition": "vary one ordered atom to each immediately adjacent predeclared threshold; require >=2%/30 discovery support, >=30 validation rows, positive means, and >=50% of the selected rule's effect in both samples",
  "status": "NOT_APPLICABLE",
  "variants_evaluated": 0
 },
 "NEXT_PHASE": "independent critique, QM-RESEARCH mechanization/preregistration, then untouched 2023-2025 F2 prescreen",
 "REFERENCE_SYMBOLS": [
  "GBPUSD.DWX"
 ],
 "RISK_RULE": "RISK_FIXED=1000; RISK_PERCENT=0; one trade per symbol/target-session/day; no overnight hold; <=5% daily and <=10% total book DD guards remain external portfolio controls",
 "SEARCH_DEFLATED_T": -1.22525708,
 "SESSION": "ASIA",
 "STATUS": "RESEARCH_CANDIDATE_NOT_PREREGISTERED_OR_PIPELINE_VALIDATED",
 "STOP_RULE": "max(0.3 x prior-14 NY_CASH ATR, 1.0 x prior-14 target-window ATR, 5 x round-trip spread); conservative F2 gap-through fill",
 "SYMBOLS": [
  "GBPUSD.DWX",
  "UK100.DWX"
 ],
 "TIMEFRAME": "M1 source aggregated into completed DST-correct session windows",
 "VALIDATION_SAMPLE": {
  "metrics": {
   "hit_rate": 0.64444444,
   "mean_net_r": 0.15782833,
   "median_net_r": 0.15921316,
   "n": 45,
   "p_one_sided": 0.025323595039040164,
   "t_stat": 1.95445704
  },
  "period": [
   "2022-01-01",
   "2022-12-31"
  ]
 },
 "VALIDATION_SUPPORT": 0.20361991
}
```

### MLDISC-52C76C0421E2FE50596F

```json
{
 "COST_SENSITIVITY": "base F2 round-trip prior in discovery; mandatory doubled-cost F2 falsification next",
 "DISCOVERY_METHODS": [
  "SPARSE_RULE_LIST"
 ],
 "DISCOVERY_SAMPLE": {
  "metrics": {
   "hit_rate": 0.45268542,
   "mean_net_r": 0.18880043,
   "median_net_r": -0.07310705,
   "n": 391,
   "p_one_sided": 1.9602297872229306e-14,
   "t_stat": 7.56360603
  },
  "period": [
   "2018-07-02",
   "2021-12-31"
  ]
 },
 "DISCOVERY_SUPPORT": 0.54005525,
 "ECONOMIC_RATIONALE": "NONE unless separately supplied by independent critique; statistical condition only",
 "ENTRY_RULE": "After NY_CASH is closed, enter LONG at the next target-window bar open when ref_eurusd_vol_ratio <= 1.0; skip the entry during the mandatory PRE30/POST30 high-impact news blackout",
 "EXECUTION_SYMBOL": "XNGUSD.DWX",
 "EXIT_RULE": "no profit target; fixed time exit at the end of ASIA, with framework Friday-close cap",
 "EXPECTED_BOOK_ROLE": "session-flat discovery candidate; role unproven until F2/MT5 evidence",
 "EXPECTED_OVERLAP": "concentrated in ASIA and named symbols",
 "FALSIFICATION_TEST": "pre-register unchanged rule for 2023-2025 F2 prescreen; reject on sign/effect failure, double-cost failure, or MT5 mismatch",
 "FDR_Q_VALUE": 4.1634248980727034e-11,
 "HYPOTHESIS_ID": "MLDISC-52C76C0421E2FE50596F",
 "MECHANICAL_RULE": {
  "all": [
   {
    "feature": "ref_eurusd_vol_ratio",
    "negated": false,
    "op": "<=",
    "value": 1.0
   }
  ],
  "condition_evaluator": "tools.strategy_farm.research.ml_rule_discovery:mechanical_rule_matches",
  "direction": "LONG",
  "entry": "NEXT_BAR_OPEN_AFTER_FEATURE_WINDOW",
  "execution_engine": "tools/strategy_farm/session_tools/velocity_family_f2_cash_session_0921.py:simulate",
  "feature_schema": "qm.session-features/v2",
  "feature_session": "NY_CASH",
  "flat": {
   "at": "TARGET_SESSION_END",
   "friday_server_cap": "21:00"
  },
  "missing_feature_policy": "NO_TRADE",
  "news_blackout": {
   "currencies": "strict execution-symbol currencies",
   "impact": "HIGH",
   "post_minutes": 30,
   "pre_minutes": 30
  },
  "risk": {
   "RISK_FIXED": 1000,
   "RISK_PERCENT": 0
  },
  "schema": "qm.f2-mechanical-session-rule/v1",
  "statistics_engine": "velocity_family_f1_sweep_0921.py:period_stats + velocity_family_f2_cash_session_0921.py:bootstrap_pass_prob",
  "stop": {
   "cash_atr_min": 0.3,
   "gap_through": "WORSE_OF_LEVEL_OR_BREACH_BAR_OPEN",
   "round_trip_spread_multiple_min": 5.0,
   "target_window_atr": 1.0
  },
  "target": null,
  "target_session": "ASIA"
 },
 "NEIGHBORING_THRESHOLD_ROBUSTNESS": {
  "checks": [
   {
    "changed_feature": "ref_eurusd_vol_ratio",
    "changed_op": "<=",
    "discovery": {
     "hit_rate": 0.51578947,
     "mean_net_r": 0.15363406,
     "median_net_r": 0.06988353,
     "n": 95,
     "p_one_sided": 7.412612004092945e-06,
     "t_stat": 4.33126928
    },
    "from": 1.0,
    "stable_positive_half_effect": false,
    "to": 0.8,
    "validation": {
     "hit_rate": 0.4,
     "mean_net_r": -0.52573237,
     "median_net_r": -0.07719575,
     "n": 5,
     "p_one_sided": 0.8719077453483222,
     "t_stat": -1.13545552
    }
   },
   {
    "changed_feature": "ref_eurusd_vol_ratio",
    "changed_op": "<=",
    "discovery": {
     "hit_rate": 0.4638448,
     "mean_net_r": 0.18122183,
     "median_net_r": -0.07310705,
     "n": 567,
     "p_one_sided": 1.0702693594687685e-17,
     "t_stat": 8.48590087
    },
    "from": 1.0,
    "stable_positive_half_effect": false,
    "to": 1.2,
    "validation": {
     "hit_rate": 0.49367089,
     "mean_net_r": -0.00099451,
     "median_net_r": -0.03258587,
     "n": 158,
     "p_one_sided": 0.5074092625840065,
     "t_stat": -0.01857333
    }
   }
  ],
  "definition": "vary one ordered atom to each immediately adjacent predeclared threshold; require >=2%/30 discovery support, >=30 validation rows, positive means, and >=50% of the selected rule's effect in both samples",
  "status": "FRAGILE",
  "variants_evaluated": 2
 },
 "NEXT_PHASE": "independent critique, QM-RESEARCH mechanization/preregistration, then untouched 2023-2025 F2 prescreen",
 "REFERENCE_SYMBOLS": [
  "EURUSD.DWX"
 ],
 "RISK_RULE": "RISK_FIXED=1000; RISK_PERCENT=0; one trade per symbol/target-session/day; no overnight hold; <=5% daily and <=10% total book DD guards remain external portfolio controls",
 "SEARCH_DEFLATED_T": 2.66630781,
 "SESSION": "ASIA",
 "STATUS": "RESEARCH_CANDIDATE_NOT_PREREGISTERED_OR_PIPELINE_VALIDATED",
 "STOP_RULE": "max(0.3 x prior-14 NY_CASH ATR, 1.0 x prior-14 target-window ATR, 5 x round-trip spread); conservative F2 gap-through fill",
 "SYMBOLS": [
  "EURUSD.DWX",
  "XNGUSD.DWX"
 ],
 "TIMEFRAME": "M1 source aggregated into completed DST-correct session windows",
 "VALIDATION_SAMPLE": {
  "metrics": {
   "hit_rate": 0.61764706,
   "mean_net_r": 0.1178643,
   "median_net_r": 0.11505835,
   "n": 68,
   "p_one_sided": 0.07199703189010052,
   "t_stat": 1.4610779
  },
  "period": [
   "2022-01-01",
   "2022-12-31"
  ]
 },
 "VALIDATION_SUPPORT": 0.28691983
}
```

### MLDISC-2DE6E7CD9420F417D20C

```json
{
 "COST_SENSITIVITY": "base F2 round-trip prior in discovery; mandatory doubled-cost F2 falsification next",
 "DISCOVERY_METHODS": [
  "SPARSE_RULE_LIST"
 ],
 "DISCOVERY_SAMPLE": {
  "metrics": {
   "hit_rate": 0.47368421,
   "mean_net_r": 0.15259874,
   "median_net_r": -0.07310705,
   "n": 266,
   "p_one_sided": 2.2221392343392084e-06,
   "t_stat": 4.58944417
  },
  "period": [
   "2018-07-02",
   "2021-12-31"
  ]
 },
 "DISCOVERY_SUPPORT": 0.36740331,
 "ECONOMIC_RATIONALE": "NONE unless separately supplied by independent critique; statistical condition only",
 "ENTRY_RULE": "After NY_CASH is closed, enter LONG at the next target-window bar open when ref_gdaxi_range_atr >= 1.0; skip the entry during the mandatory PRE30/POST30 high-impact news blackout",
 "EXECUTION_SYMBOL": "XNGUSD.DWX",
 "EXIT_RULE": "no profit target; fixed time exit at the end of ASIA, with framework Friday-close cap",
 "EXPECTED_BOOK_ROLE": "session-flat discovery candidate; role unproven until F2/MT5 evidence",
 "EXPECTED_OVERLAP": "concentrated in ASIA and named symbols",
 "FALSIFICATION_TEST": "pre-register unchanged rule for 2023-2025 F2 prescreen; reject on sign/effect failure, double-cost failure, or MT5 mismatch",
 "FDR_Q_VALUE": 0.001045765933548207,
 "HYPOTHESIS_ID": "MLDISC-2DE6E7CD9420F417D20C",
 "MECHANICAL_RULE": {
  "all": [
   {
    "feature": "ref_gdaxi_range_atr",
    "negated": false,
    "op": ">=",
    "value": 1.0
   }
  ],
  "condition_evaluator": "tools.strategy_farm.research.ml_rule_discovery:mechanical_rule_matches",
  "direction": "LONG",
  "entry": "NEXT_BAR_OPEN_AFTER_FEATURE_WINDOW",
  "execution_engine": "tools/strategy_farm/session_tools/velocity_family_f2_cash_session_0921.py:simulate",
  "feature_schema": "qm.session-features/v2",
  "feature_session": "NY_CASH",
  "flat": {
   "at": "TARGET_SESSION_END",
   "friday_server_cap": "21:00"
  },
  "missing_feature_policy": "NO_TRADE",
  "news_blackout": {
   "currencies": "strict execution-symbol currencies",
   "impact": "HIGH",
   "post_minutes": 30,
   "pre_minutes": 30
  },
  "risk": {
   "RISK_FIXED": 1000,
   "RISK_PERCENT": 0
  },
  "schema": "qm.f2-mechanical-session-rule/v1",
  "statistics_engine": "velocity_family_f1_sweep_0921.py:period_stats + velocity_family_f2_cash_session_0921.py:bootstrap_pass_prob",
  "stop": {
   "cash_atr_min": 0.3,
   "gap_through": "WORSE_OF_LEVEL_OR_BREACH_BAR_OPEN",
   "round_trip_spread_multiple_min": 5.0,
   "target_window_atr": 1.0
  },
  "target": null,
  "target_session": "ASIA"
 },
 "NEIGHBORING_THRESHOLD_ROBUSTNESS": {
  "checks": [
   {
    "changed_feature": "ref_gdaxi_range_atr",
    "changed_op": ">=",
    "discovery": {
     "hit_rate": 0.46354167,
     "mean_net_r": 0.15291225,
     "median_net_r": -0.07310705,
     "n": 576,
     "p_one_sided": 1.9577272529614136e-12,
     "t_stat": 6.94019992
    },
    "from": 1.0,
    "stable_positive_half_effect": false,
    "to": 0.5,
    "validation": {
     "hit_rate": 0.45771144,
     "mean_net_r": -0.03741238,
     "median_net_r": -0.07719575,
     "n": 201,
     "p_one_sided": 0.8118664483343219,
     "t_stat": -0.88479519
    }
   },
   {
    "changed_feature": "ref_gdaxi_range_atr",
    "changed_op": ">=",
    "discovery": {
     "hit_rate": 0.46875,
     "mean_net_r": 0.17624806,
     "median_net_r": -0.07310705,
     "n": 96,
     "p_one_sided": 0.001124489600438607,
     "t_stat": 3.05521676
    },
    "from": 1.0,
    "stable_positive_half_effect": false,
    "to": 1.5,
    "validation": {
     "hit_rate": 0.5,
     "mean_net_r": 0.17016355,
     "median_net_r": -0.01267518,
     "n": 28,
     "p_one_sided": 0.0982125203129026,
     "t_stat": 1.29180397
    }
   }
  ],
  "definition": "vary one ordered atom to each immediately adjacent predeclared threshold; require >=2%/30 discovery support, >=30 validation rows, positive means, and >=50% of the selected rule's effect in both samples",
  "status": "FRAGILE",
  "variants_evaluated": 2
 },
 "NEXT_PHASE": "independent critique, QM-RESEARCH mechanization/preregistration, then untouched 2023-2025 F2 prescreen",
 "REFERENCE_SYMBOLS": [
  "GDAXI.DWX"
 ],
 "RISK_RULE": "RISK_FIXED=1000; RISK_PERCENT=0; one trade per symbol/target-session/day; no overnight hold; <=5% daily and <=10% total book DD guards remain external portfolio controls",
 "SEARCH_DEFLATED_T": -0.30785405,
 "SESSION": "ASIA",
 "STATUS": "RESEARCH_CANDIDATE_NOT_PREREGISTERED_OR_PIPELINE_VALIDATED",
 "STOP_RULE": "max(0.3 x prior-14 NY_CASH ATR, 1.0 x prior-14 target-window ATR, 5 x round-trip spread); conservative F2 gap-through fill",
 "SYMBOLS": [
  "GDAXI.DWX",
  "XNGUSD.DWX"
 ],
 "TIMEFRAME": "M1 source aggregated into completed DST-correct session windows",
 "VALIDATION_SAMPLE": {
  "metrics": {
   "hit_rate": 0.53012048,
   "mean_net_r": 0.11229548,
   "median_net_r": 0.06451613,
   "n": 83,
   "p_one_sided": 0.05812212610680707,
   "t_stat": 1.57073484
  },
  "period": [
   "2022-01-01",
   "2022-12-31"
  ]
 },
 "VALIDATION_SUPPORT": 0.35021097
}
```

### MLDISC-81AB88C0139128BCFE0B

```json
{
 "COST_SENSITIVITY": "base F2 round-trip prior in discovery; mandatory doubled-cost F2 falsification next",
 "DISCOVERY_METHODS": [
  "SPARSE_RULE_LIST"
 ],
 "DISCOVERY_SAMPLE": {
  "metrics": {
   "hit_rate": 0.47058824,
   "mean_net_r": 0.13702175,
   "median_net_r": -0.07310705,
   "n": 289,
   "p_one_sided": 1.3138281555865203e-05,
   "t_stat": 4.20354608
  },
  "period": [
   "2018-07-02",
   "2021-12-31"
  ]
 },
 "DISCOVERY_SUPPORT": 0.39917127,
 "ECONOMIC_RATIONALE": "NONE unless separately supplied by independent critique; statistical condition only",
 "ENTRY_RULE": "After NY_CASH is closed, enter LONG at the next target-window bar open when ref_ndx_range_atr >= 1.0; skip the entry during the mandatory PRE30/POST30 high-impact news blackout",
 "EXECUTION_SYMBOL": "XNGUSD.DWX",
 "EXIT_RULE": "no profit target; fixed time exit at the end of ASIA, with framework Friday-close cap",
 "EXPECTED_BOOK_ROLE": "session-flat discovery candidate; role unproven until F2/MT5 evidence",
 "EXPECTED_OVERLAP": "concentrated in ASIA and named symbols",
 "FALSIFICATION_TEST": "pre-register unchanged rule for 2023-2025 F2 prescreen; reject on sign/effect failure, double-cost failure, or MT5 mismatch",
 "FDR_Q_VALUE": 0.005342018661833151,
 "HYPOTHESIS_ID": "MLDISC-81AB88C0139128BCFE0B",
 "MECHANICAL_RULE": {
  "all": [
   {
    "feature": "ref_ndx_range_atr",
    "negated": false,
    "op": ">=",
    "value": 1.0
   }
  ],
  "condition_evaluator": "tools.strategy_farm.research.ml_rule_discovery:mechanical_rule_matches",
  "direction": "LONG",
  "entry": "NEXT_BAR_OPEN_AFTER_FEATURE_WINDOW",
  "execution_engine": "tools/strategy_farm/session_tools/velocity_family_f2_cash_session_0921.py:simulate",
  "feature_schema": "qm.session-features/v2",
  "feature_session": "NY_CASH",
  "flat": {
   "at": "TARGET_SESSION_END",
   "friday_server_cap": "21:00"
  },
  "missing_feature_policy": "NO_TRADE",
  "news_blackout": {
   "currencies": "strict execution-symbol currencies",
   "impact": "HIGH",
   "post_minutes": 30,
   "pre_minutes": 30
  },
  "risk": {
   "RISK_FIXED": 1000,
   "RISK_PERCENT": 0
  },
  "schema": "qm.f2-mechanical-session-rule/v1",
  "statistics_engine": "velocity_family_f1_sweep_0921.py:period_stats + velocity_family_f2_cash_session_0921.py:bootstrap_pass_prob",
  "stop": {
   "cash_atr_min": 0.3,
   "gap_through": "WORSE_OF_LEVEL_OR_BREACH_BAR_OPEN",
   "round_trip_spread_multiple_min": 5.0,
   "target_window_atr": 1.0
  },
  "target": null,
  "target_session": "ASIA"
 },
 "NEIGHBORING_THRESHOLD_ROBUSTNESS": {
  "checks": [
   {
    "changed_feature": "ref_ndx_range_atr",
    "changed_op": ">=",
    "discovery": {
     "hit_rate": 0.45538462,
     "mean_net_r": 0.12775641,
     "median_net_r": -0.07310705,
     "n": 650,
     "p_one_sided": 3.103535176496695e-09,
     "t_stat": 5.81108104
    },
    "from": 1.0,
    "stable_positive_half_effect": false,
    "to": 0.5,
    "validation": {
     "hit_rate": 0.49779736,
     "mean_net_r": -0.0057506,
     "median_net_r": -0.02954833,
     "n": 227,
     "p_one_sided": 0.5558716619046524,
     "t_stat": -0.14051048
    }
   },
   {
    "changed_feature": "ref_ndx_range_atr",
    "changed_op": ">=",
    "discovery": {
     "hit_rate": 0.54285714,
     "mean_net_r": 0.19794816,
     "median_net_r": 0.06988353,
     "n": 105,
     "p_one_sided": 0.00013585464896532357,
     "t_stat": 3.64087854
    },
    "from": 1.0,
    "stable_positive_half_effect": false,
    "to": 1.5,
    "validation": {
     "hit_rate": 0.43333333,
     "mean_net_r": -0.02678336,
     "median_net_r": -0.09753672,
     "n": 30,
     "p_one_sided": 0.5872415640448814,
     "t_stat": -0.22045493
    }
   }
  ],
  "definition": "vary one ordered atom to each immediately adjacent predeclared threshold; require >=2%/30 discovery support, >=30 validation rows, positive means, and >=50% of the selected rule's effect in both samples",
  "status": "FRAGILE",
  "variants_evaluated": 2
 },
 "NEXT_PHASE": "independent critique, QM-RESEARCH mechanization/preregistration, then untouched 2023-2025 F2 prescreen",
 "REFERENCE_SYMBOLS": [
  "NDX.DWX"
 ],
 "RISK_RULE": "RISK_FIXED=1000; RISK_PERCENT=0; one trade per symbol/target-session/day; no overnight hold; <=5% daily and <=10% total book DD guards remain external portfolio controls",
 "SEARCH_DEFLATED_T": -0.69375214,
 "SESSION": "ASIA",
 "STATUS": "RESEARCH_CANDIDATE_NOT_PREREGISTERED_OR_PIPELINE_VALIDATED",
 "STOP_RULE": "max(0.3 x prior-14 NY_CASH ATR, 1.0 x prior-14 target-window ATR, 5 x round-trip spread); conservative F2 gap-through fill",
 "SYMBOLS": [
  "NDX.DWX",
  "XNGUSD.DWX"
 ],
 "TIMEFRAME": "M1 source aggregated into completed DST-correct session windows",
 "VALIDATION_SAMPLE": {
  "metrics": {
   "hit_rate": 0.54444444,
   "mean_net_r": 0.0941461,
   "median_net_r": 0.03659747,
   "n": 90,
   "p_one_sided": 0.08257233013597914,
   "t_stat": 1.38797499
  },
  "period": [
   "2022-01-01",
   "2022-12-31"
  ]
 },
 "VALIDATION_SUPPORT": 0.37974684
}
```

### MLDISC-4833F78D4C1169004E50

```json
{
 "COST_SENSITIVITY": "base F2 round-trip prior in discovery; mandatory doubled-cost F2 falsification next",
 "DISCOVERY_METHODS": [
  "SPARSE_RULE_LIST"
 ],
 "DISCOVERY_SAMPLE": {
  "metrics": {
   "hit_rate": 0.46035806,
   "mean_net_r": 0.13456972,
   "median_net_r": -0.07310705,
   "n": 391,
   "p_one_sided": 3.4446475544020185e-07,
   "t_stat": 4.96445868
  },
  "period": [
   "2018-07-02",
   "2021-12-31"
  ]
 },
 "DISCOVERY_SUPPORT": 0.54005525,
 "ECONOMIC_RATIONALE": "NONE unless separately supplied by independent critique; statistical condition only",
 "ENTRY_RULE": "After NY_CASH is closed, enter LONG at the next target-window bar open when ref_xagusd_return_atr >= 0.0; skip the entry during the mandatory PRE30/POST30 high-impact news blackout",
 "EXECUTION_SYMBOL": "XNGUSD.DWX",
 "EXIT_RULE": "no profit target; fixed time exit at the end of ASIA, with framework Friday-close cap",
 "EXPECTED_BOOK_ROLE": "session-flat discovery candidate; role unproven until F2/MT5 evidence",
 "EXPECTED_OVERLAP": "concentrated in ASIA and named symbols",
 "FALSIFICATION_TEST": "pre-register unchanged rule for 2023-2025 F2 prescreen; reject on sign/effect failure, double-cost failure, or MT5 mismatch",
 "FDR_Q_VALUE": 0.00018658892893676975,
 "HYPOTHESIS_ID": "MLDISC-4833F78D4C1169004E50",
 "MECHANICAL_RULE": {
  "all": [
   {
    "feature": "ref_xagusd_return_atr",
    "negated": false,
    "op": ">=",
    "value": 0.0
   }
  ],
  "condition_evaluator": "tools.strategy_farm.research.ml_rule_discovery:mechanical_rule_matches",
  "direction": "LONG",
  "entry": "NEXT_BAR_OPEN_AFTER_FEATURE_WINDOW",
  "execution_engine": "tools/strategy_farm/session_tools/velocity_family_f2_cash_session_0921.py:simulate",
  "feature_schema": "qm.session-features/v2",
  "feature_session": "NY_CASH",
  "flat": {
   "at": "TARGET_SESSION_END",
   "friday_server_cap": "21:00"
  },
  "missing_feature_policy": "NO_TRADE",
  "news_blackout": {
   "currencies": "strict execution-symbol currencies",
   "impact": "HIGH",
   "post_minutes": 30,
   "pre_minutes": 30
  },
  "risk": {
   "RISK_FIXED": 1000,
   "RISK_PERCENT": 0
  },
  "schema": "qm.f2-mechanical-session-rule/v1",
  "statistics_engine": "velocity_family_f1_sweep_0921.py:period_stats + velocity_family_f2_cash_session_0921.py:bootstrap_pass_prob",
  "stop": {
   "cash_atr_min": 0.3,
   "gap_through": "WORSE_OF_LEVEL_OR_BREACH_BAR_OPEN",
   "round_trip_spread_multiple_min": 5.0,
   "target_window_atr": 1.0
  },
  "target": null,
  "target_session": "ASIA"
 },
 "NEIGHBORING_THRESHOLD_ROBUSTNESS": {
  "checks": [
   {
    "changed_feature": "ref_xagusd_return_atr",
    "changed_op": ">=",
    "discovery": {
     "hit_rate": 0.44102564,
     "mean_net_r": 0.11366936,
     "median_net_r": -0.07310705,
     "n": 585,
     "p_one_sided": 7.088316147113066e-07,
     "t_stat": 4.82250521
    },
    "from": 0.0,
    "stable_positive_half_effect": false,
    "to": -0.5,
    "validation": {
     "hit_rate": 0.49197861,
     "mean_net_r": -0.00372041,
     "median_net_r": -0.02954833,
     "n": 187,
     "p_one_sided": 0.532290174909889,
     "t_stat": -0.08102804
    }
   },
   {
    "changed_feature": "ref_xagusd_return_atr",
    "changed_op": ">=",
    "discovery": {
     "hit_rate": 0.47445255,
     "mean_net_r": 0.15337498,
     "median_net_r": -0.07310705,
     "n": 137,
     "p_one_sided": 0.0004878521743972935,
     "t_stat": 3.29744024
    },
    "from": 0.0,
    "stable_positive_half_effect": false,
    "to": 0.5,
    "validation": {
     "hit_rate": 0.43589744,
     "mean_net_r": -0.03556242,
     "median_net_r": -0.19151847,
     "n": 39,
     "p_one_sided": 0.6441224341875906,
     "t_stat": -0.36949992
    }
   }
  ],
  "definition": "vary one ordered atom to each immediately adjacent predeclared threshold; require >=2%/30 discovery support, >=30 validation rows, positive means, and >=50% of the selected rule's effect in both samples",
  "status": "FRAGILE",
  "variants_evaluated": 2
 },
 "NEXT_PHASE": "independent critique, QM-RESEARCH mechanization/preregistration, then untouched 2023-2025 F2 prescreen",
 "REFERENCE_SYMBOLS": [
  "XAGUSD.DWX"
 ],
 "RISK_RULE": "RISK_FIXED=1000; RISK_PERCENT=0; one trade per symbol/target-session/day; no overnight hold; <=5% daily and <=10% total book DD guards remain external portfolio controls",
 "SEARCH_DEFLATED_T": 0.06716046,
 "SESSION": "ASIA",
 "STATUS": "RESEARCH_CANDIDATE_NOT_PREREGISTERED_OR_PIPELINE_VALIDATED",
 "STOP_RULE": "max(0.3 x prior-14 NY_CASH ATR, 1.0 x prior-14 target-window ATR, 5 x round-trip spread); conservative F2 gap-through fill",
 "SYMBOLS": [
  "XAGUSD.DWX",
  "XNGUSD.DWX"
 ],
 "TIMEFRAME": "M1 source aggregated into completed DST-correct session windows",
 "VALIDATION_SAMPLE": {
  "metrics": {
   "hit_rate": 0.52136752,
   "mean_net_r": 0.07285068,
   "median_net_r": 0.03058995,
   "n": 117,
   "p_one_sided": 0.09717903206677415,
   "t_stat": 1.2977942
  },
  "period": [
   "2022-01-01",
   "2022-12-31"
  ]
 },
 "VALIDATION_SUPPORT": 0.49367089
}
```

### MLDISC-59725479D7B74111B658

```json
{
 "COST_SENSITIVITY": "base F2 round-trip prior in discovery; mandatory doubled-cost F2 falsification next",
 "DISCOVERY_METHODS": [
  "SPARSE_RULE_LIST"
 ],
 "DISCOVERY_SAMPLE": {
  "metrics": {
   "hit_rate": 0.60233918,
   "mean_net_r": 0.1662153,
   "median_net_r": 0.15176152,
   "n": 171,
   "p_one_sided": 3.695620044539411e-05,
   "t_stat": 3.9633271
  },
  "period": [
   "2018-07-02",
   "2021-12-31"
  ]
 },
 "DISCOVERY_SUPPORT": 0.20141343,
 "ECONOMIC_RATIONALE": "NONE unless separately supplied by independent critique; statistical condition only",
 "ENTRY_RULE": "After NY_PREOPEN is closed, enter SHORT at the next target-window bar open when target_day_of_week == 3; skip the entry during the mandatory PRE30/POST30 high-impact news blackout",
 "EXECUTION_SYMBOL": "XNGUSD.DWX",
 "EXIT_RULE": "no profit target; fixed time exit at the end of CASH_OPEN, with framework Friday-close cap",
 "EXPECTED_BOOK_ROLE": "session-flat discovery candidate; role unproven until F2/MT5 evidence",
 "EXPECTED_OVERLAP": "concentrated in CASH_OPEN and named symbols",
 "FALSIFICATION_TEST": "pre-register unchanged rule for 2023-2025 F2 prescreen; reject on sign/effect failure, double-cost failure, or MT5 mismatch",
 "FDR_Q_VALUE": 0.013745322294690132,
 "HYPOTHESIS_ID": "MLDISC-59725479D7B74111B658",
 "MECHANICAL_RULE": {
  "all": [
   {
    "feature": "target_day_of_week",
    "negated": false,
    "op": "==",
    "value": 3
   }
  ],
  "condition_evaluator": "tools.strategy_farm.research.ml_rule_discovery:mechanical_rule_matches",
  "direction": "SHORT",
  "entry": "NEXT_BAR_OPEN_AFTER_FEATURE_WINDOW",
  "execution_engine": "tools/strategy_farm/session_tools/velocity_family_f2_cash_session_0921.py:simulate",
  "feature_schema": "qm.session-features/v2",
  "feature_session": "NY_PREOPEN",
  "flat": {
   "at": "TARGET_SESSION_END",
   "friday_server_cap": "21:00"
  },
  "missing_feature_policy": "NO_TRADE",
  "news_blackout": {
   "currencies": "strict execution-symbol currencies",
   "impact": "HIGH",
   "post_minutes": 30,
   "pre_minutes": 30
  },
  "risk": {
   "RISK_FIXED": 1000,
   "RISK_PERCENT": 0
  },
  "schema": "qm.f2-mechanical-session-rule/v1",
  "statistics_engine": "velocity_family_f1_sweep_0921.py:period_stats + velocity_family_f2_cash_session_0921.py:bootstrap_pass_prob",
  "stop": {
   "cash_atr_min": 0.3,
   "gap_through": "WORSE_OF_LEVEL_OR_BREACH_BAR_OPEN",
   "round_trip_spread_multiple_min": 5.0,
   "target_window_atr": 1.0
  },
  "target": null,
  "target_session": "CASH_OPEN"
 },
 "NEIGHBORING_THRESHOLD_ROBUSTNESS": {
  "checks": [],
  "definition": "vary one ordered atom to each immediately adjacent predeclared threshold; require >=2%/30 discovery support, >=30 validation rows, positive means, and >=50% of the selected rule's effect in both samples",
  "status": "NOT_APPLICABLE",
  "variants_evaluated": 0
 },
 "NEXT_PHASE": "independent critique, QM-RESEARCH mechanization/preregistration, then untouched 2023-2025 F2 prescreen",
 "REFERENCE_SYMBOLS": [],
 "RISK_RULE": "RISK_FIXED=1000; RISK_PERCENT=0; one trade per symbol/target-session/day; no overnight hold; <=5% daily and <=10% total book DD guards remain external portfolio controls",
 "SEARCH_DEFLATED_T": -0.93397112,
 "SESSION": "CASH_OPEN",
 "STATUS": "RESEARCH_CANDIDATE_NOT_PREREGISTERED_OR_PIPELINE_VALIDATED",
 "STOP_RULE": "max(0.3 x prior-14 NY_CASH ATR, 1.0 x prior-14 target-window ATR, 5 x round-trip spread); conservative F2 gap-through fill",
 "SYMBOLS": [
  "XNGUSD.DWX"
 ],
 "TIMEFRAME": "M1 source aggregated into completed DST-correct session windows",
 "VALIDATION_SAMPLE": {
  "metrics": {
   "hit_rate": 0.72916667,
   "mean_net_r": 0.15022922,
   "median_net_r": 0.22756171,
   "n": 48,
   "p_one_sided": 0.016589545731683978,
   "t_stat": 2.12990943
  },
  "period": [
   "2022-01-01",
   "2022-12-31"
  ]
 },
 "VALIDATION_SUPPORT": 0.20083682
}
```
