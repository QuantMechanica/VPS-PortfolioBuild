# FTMO evaluator fidelity — four opening days and pinned rule contract

Date: 2026-09-05  
Router task: `bc7e3b81-b947-4e7b-ac24-a1ca81c35dd5`  
Code commit: `ed4755d8a7f82efe18f0f0ba668020d096407995` (`agents/codex`)  
Verdict: **PASS FOR REVIEW; NO PIPELINE VERDICT; NO BOOK BUILT**

## Repair

The FTMO evaluation paths now load a single schema-validated projection of
`tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json` through
`ftmo_rule_contract.py`. The shared projection supplies the Phase 1 and Phase 2
targets, daily-loss and maximum-loss amounts, Prague calendar/reset anchor,
minimum opening-day count, strict comparison operators, static initial-equity
maximum-loss model, stage reset, and the prohibition on live-equity compounding.

The timebox configuration pins both the rulepack file SHA-256 and its canonical
schema SHA-256 and refuses drift during evaluation. The raw file SHA-256 in this
run was `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992`;
the canonical SHA-256 was
`7e0b21d3768c78c69e28c390814948286736ecec4fd28490a86c647f3485dbd8`.

The one-day defect is closed: a balance above target does not pass until
positions have been opened on at least four distinct Prague calendar days.
Targets and loss floors use the pinned strict operators, Phase 2 begins on the
next Prague day with initial equity reset, and fixed-initial normalized returns
are additive rather than compounded.

First-passage, Monte Carlo, the 60-day challenge scorer, timebox evaluation, and
the mark-to-market rules engine consume the same contract. Legacy JSONL field
`trade_count` is retained for schema compatibility in the timebox evaluator but
is explicitly interpreted as positions opened on that Prague day.

## Verification

Focused suite:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_evaluator_fidelity.py tools/strategy_farm/tests/test_ftmo_timebox_eval.py tools/strategy_farm/tests/test_ftmo_rules_engine.py tools/strategy_farm/tests/test_target_rulepacks.py -q
83 passed in 4.03s
```

`py_compile` also passed for all six affected portfolio modules. Boundary tests
cover the Astra one-day reproducer, exactly four opening days, strict target
equality, Prague midnight, schema/invariant refusal, and the Phase 1-to-Phase 2
reset. The Astra fixture's recorded legacy result remains `PASS` after one day;
both repaired engines return non-pass for that input and agree on a pass after
four qualifying opening days.

## Read-only replay deltas

All new receipts were written only under
`D:/QM/scratch/codex_ftmo_fidelity_20260905/`.

- Legacy MC exact parameters: `--paths 2000 --horizon 43 --seed 20260904
  --compositions a_motor_solo_050,a_motor_solo_100`. For both compositions,
  deltas versus `2026-09-04_astra_ftmo_legacy_mc.json` were zero for pass
  probability, historical-window pass fraction, daily-loss breach probability,
  and maximum-loss breach probability. Both remain 0% pass and 0% breach on
  those four measures.
- Legacy first-passage replay: 20/20 rows identical; source fingerprint
  `e50e8f891c34f838e576f00c4b4d85e0815bd358c20028ac55dd294369b81759`;
  the old and replay artifact SHA-256 are both
  `a31e4a57eb28c4ad0ec4474af2987ab33bc3ac438c8d3d292b7ab15b8c1d0388`.
- Astra exact-cost timebox replay remains `NO_ADMISSIBLE_COMPOSITION`: 0
  evaluated, 8 refused, decision label
  `NO_EVIDENCE_CREDIT_NOT_ESTIMATED_PROBABILITY`. Result SHA-256:
  `4c445af17dbe5323725ee68a8e0cb23b2b23b280d4b383dd475ea2d898d3c5d7`.
- Astra native-cost replay remains fail-closed with exit 2:
  `ftmo_cost_snapshot: expected non-empty instrument list`.

No purchase threshold or policy was changed, no registry/gate/verdict was
written, and no FTMO book or pipeline verdict was created.
