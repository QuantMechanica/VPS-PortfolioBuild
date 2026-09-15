# Card intake prescreen — task `47a70f66-c0b1-45a7-ba2e-2883e9ceb99b`

## Outcome

A deterministic paper prescreen now checks candidate Strategy Cards before the
research/intake handoff. It is read-only by default. Mutation requires both
`--apply` and the pre-existing scheduler/operator arm
`QM_CARD_INTAKE_PRESCREEN=1`; the tool never sets that arm. Apply mode can only
annotate and move a rejected file from `cards_draft` or `cards_review` into
`cards_rejected`. It has no approval, build, pipeline, terminal, or live path.

The mailbox source-intake prompt now invokes the read-only command for each new
source-linked draft and explicitly forbids an analyst from arming apply mode.

## Checks implemented

- Slug and mechanism fingerprints against `cards_approved` and
  `cards_rejected`. Strong matches are rejection findings; a card with an
  explicit differentiation/dedup section is retained with a review warning.
- Exact `target_symbols` membership in
  `framework/registry/dwx_symbol_matrix.csv`.
- Named external-series availability below `D:/QM/data`, including VIX, COT,
  options/IV, bond yields, CVD, macro-surprise, fundamentals, and swap history.
- Structural cause, price signature, persistence, falsification, Q08/Q11 risk,
  and substantive FTMO-fit sections.
- `expected_dd_pct` in `(0, 10]`, an M5–M15 or H1–D1 horizon, and no affirmative
  ML/HFT/grid/martingale/averaging-into-losers mechanics. Negative compliance
  clauses such as “no ML” are not treated as dependencies or violations.

## Verification

Command:

```powershell
python -m pytest tools/strategy_farm/tests/test_card_intake_prescreen.py tools/strategy_farm/tests/test_mailbox_source_intake.py -q
```

Result: `35 passed in 1.30s`. The new suite contains five September 12 KEEP
fixtures, five September 12 reject-class fixtures, the dual apply-arm check,
and an apply-mode move/annotation test.

Read-only corpus command:

```powershell
python tools/strategy_farm/card_intake_prescreen.py --triage-evidence docs/ops/evidence/2026-09-12_edge_lab_triage/edge_lab_triage_2026-09-12.json --report docs/ops/evidence/47a70f66_card_intake_prescreen_2026-09-15.json
```

- Current `cards_review`: 158 inspected, 1 KEEP, 157 REJECT, 0 mutated.
- September 12 obvious-class retrospective: 107/107 evidence rows located;
  90 class-specific findings reproduced, recall **84.11%**.
- Caught by class: duplicate 60, feed 12, symbol 8, HFT/ML 10.
- The 17 misses were duplicate judgments requiring semantic knowledge beyond
  the deliberately coarse deterministic fingerprint. They remain visible in
  the bound JSON and are not silently promoted.
- JSON SHA-256:
  `252c7f9319e6f6200f06598abc3545d2281ccd2bf3b7b4a52e3bdbb7925ed458`.
- Tool SHA-256:
  `4cb7a14a63f3fda564460cde23a9984b3d5ecc34e1c765bb9d259a2178830732`.

No cards were moved, no `cards_approved` bytes were written, and no pipeline or
terminal action ran.

RESULT task=47a70f66-c0b1-45a7-ba2e-2883e9ceb99b verdict=PASS dry_run_default=true apply_dual_arm=true tests=35_passed triage_class_recall_pct=84.11 cards_approved_writes=0 lifecycle_mutations=0
