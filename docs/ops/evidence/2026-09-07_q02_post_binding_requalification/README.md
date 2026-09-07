# Governed post-binding Q02 requalification

Date: 2026-09-07

Router task: `9d8ad690-6af0-4f77-94d7-9ac2f913494e`

Mode: implementation plus production dry run only; no Q02 row was enqueued.

## Outcome

`farmctl.py requalify-q02` is a new append-only, dry-run-default path for a Q02 predecessor whose immutable EX5 and/or setfile binding is older than the current canonical build. It accepts pending or terminal Q02/P2 predecessors, preserves terminal verdicts, and creates a new pending identity only with `--apply` after every guard passes.

The path preserves EA, logical symbol, host symbol, and timeframe. It requires the operator to pin the current canonical EX5 SHA-256, authenticates the current MQ5/EX5 pair against a done `COMPILE_OK` record whose compile evidence says compile PASS and build-check PASS, and binds the successor to the current canonical setfile SHA-256. The predecessor is excluded from claims with an immutable `work_item_supersedes` sidecar; an atomic receipt records both identities and the full parameter comparison.

Old preset semantics are accepted only after exact predecessor SHA-256 recovery from Git history, allowing replay of line endings and the non-executable `; build_hash:` metadata line. Every executable key/value is compared. A non-empty diff additionally requires the authenticated compile evidence to reference an exact, canonical-repository, current-MQ5-bound source-repair/input-pin authority. No inference from the current file is used for missing old bytes.

The existing fixed-risk guard is retained: `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and `qm_news_stale_max_hours` may not exceed 336. Dry run opens the farm database read-only; apply uses one immediate transaction and rolls back the receipt if the transaction cannot commit.

## Cohort dry run

The governed command was run against all 13 predecessors in the prior stale-binding cohort. Full hashes and per-row provenance results are in `cohort_dry_run_summary.json`.

| Result | Rows | Parameter/provenance result |
|---|---:|---|
| Eligible | 3 | QM5_41359, QM5_41360, and QM5_41361: exact old bytes recovered; executable diff is empty; current compile provenance authenticated. |
| Missing predecessor set digest | 1 | QM5_21524: refused before comparison. |
| Current compile identity unauthenticated | 1 | QM5_33007: exact old bytes recovered; four safety parameters were added, but the current MQ5/EX5 pair has no done `COMPILE_OK` record, so it was refused before input-pin authority could be accepted. |
| Already superseded | 2 | QM5_20096 and QM5_10717: existing immutable disposition wins. |
| Exact old bytes unavailable | 6 | QM5_41362, QM5_41165, QM5_41172, QM5_41176, QM5_41312, and QM5_41336: refused without asserting a semantic diff. |

Summary: 3 eligible, 10 refused, 0 production successors, 0 source mutations. Eligibility is not a pipeline verdict and no production apply was performed.

QM5_33007's recovered diff is exactly:

- add `strategy_daily_drawdown_hard_stop_pct=2.5`
- add `strategy_daily_realized_loss_halt_pct=2.0`
- add `strategy_max_slippage_ticks=3.0`
- add `strategy_total_drawdown_stop_pct=5.0`

## Wave-2 correction

The wave-2 input-pin authority contains 119 registrations. `QM5_20292` is excluded by the restart plan for duplicate/registry/card identity mismatch, leaving 118 governed nonexcluded identities. A read-only database audit found at least one Q02/P2 row for every one of those 118 identities. Therefore the post-binding restart gap applies to all 118 identities listed in the plan's Q02 rows, not only the EX5-stale sample. The restart plan now routes identity-preserving stale-EX5 cases through `rebind-q02` and any authenticated setfile-identity change through `requalify-q02`; neither command is an automatic production apply.

## Verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_q02_post_binding_requalification.py \
  tools/strategy_farm/tests/test_q02_stale_binding_rebind.py \
  tools/strategy_farm/tests/test_pending_superseded_claim_filter.py \
  tools/strategy_farm/tests/test_first_q02_intake.py

31 passed in 11.44s
```

The focused tests cover pending and terminal predecessors, immutable supersession plus receipt creation, refusal of an unproven parameter change, acceptance with an exact current-MQ5-bound repair authority, and operator EX5 SHA mismatch. A final read-only query reported `production_requalification_successors=0`.
