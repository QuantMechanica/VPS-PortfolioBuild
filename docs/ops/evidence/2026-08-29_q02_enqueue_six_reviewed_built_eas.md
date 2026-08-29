# Q02 enqueue for 6 reviewed/built EAs without work items — router task `d37d9ae4-56e4-4865-96bf-e242c4842a21`

Date: 2026-08-29, checked 06:33-06:45 UTC

Ticket cohort: `QM5_11561`, `QM5_11731`, `QM5_12512`, `QM5_11570`, `QM5_10050`,
`QM5_12507` — flagged by the `health` `unenqueued_eas_count` check as
reviewed + built EAs with no Q02 work items.

## Re-verification against the live canonical detector

The ticket's cohort no longer matches what
`farmctl._detect_unenqueued_eas()` (the exact function backing the health
metric) returns right now. Re-running it live returned only three EAs:
`QM5_12512`, `QM5_10050`, `QM5_12507`. The other three are excluded by the
same function's own first check, `is_q02_requeue_excluded()`:

- `QM5_11561`, `QM5_11570`, `QM5_11731` are all three listed on
  `D:/QM/strategy_farm/state/requeue_excluded_eas.txt` (the 160-entry
  Cost-Doomed-FX blocklist, `docs/ops/OPERATING_RULES_2026-07-03.md` rule 15;
  lines 114, 115, 134). `QM5_11570`'s own review evidence independently
  confirms this (`approve_summary` in review task `1cad74b2-...` states its
  own auto-Q02-enqueue already ran and skipped all 7 setfiles for exactly this
  reason). None of the three has any work item because the factory has
  deliberately never enqueued them, not because of an oversight. **Skipped —
  policy exclusion, not a code/preflight defect.** Overriding the exclusion is
  a gate-criteria decision (ROT under the standing authorization) and is out
  of scope for this ticket.

The remaining three are all three basket EAs
(`framework/EAs/<dir>/basket_manifest.json` present:
`QM5_12512_FX_PAIRS_THRESHOLD_H1`, `QM5_10050_CORR_TRIAD_H1`,
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`). Each already has dozens of
**physical-leg** Q02 work items from a legacy auto-enqueue (31 / 80 / 52 rows
respectively, mostly `INFRA_FAIL`), which is exactly the masking pattern the
detector's basket-symbol carve-out exists for — none of the three has ever
had a Q02 work item keyed to its *logical* basket symbol, so the health flag
is correct for these three.

## Preflight verification and enqueue attempts

For all three, `.ex5` exists and current, and `framework/registry/magic_numbers.csv`
carries active magic rows (12512: 6, 10050: 1, 12507: 4). I ran the canonical
seed path, `farmctl.py enqueue-backtest --review-task-id <latest APPROVE_FOR_BACKTEST
ea_review id> --phase Q02`, for each:

| EA | Review task | Result |
|---|---|---|
| `QM5_12512` | `714c3601-0372-4323-aadc-d42bdde28cd3` | Refused: `q01_smoke_not_passed` — latest build's smoke outcome is missing (neither PASS nor an eligible saturation waiver). |
| `QM5_10050` | `9212d4bd-57e6-4676-b68e-0a625a94f0d0` | Refused: `q01_smoke_waiver_missing_capacity_evidence` — smoke outcome is `deferred_p2_smoke`, but the build record carries no durable tester-fleet saturation evidence, so the OWNER-ratified saturation-only waiver (`decisions/2026-08-22_q01_smoke_saturation_waiver.md`, `farmctl._q01_smoke_admission()`) does not apply. |
| `QM5_12507` | `c85bc9b3-d5c5-46fb-ba5a-0ba8ccd01630` | Refused: `q01_smoke_waiver_missing_capacity_evidence` — same as above. |

All three refusals are the governed, fail-closed Q01 smoke admission gate
working as designed; none is a code defect in this cohort. **No Q02 work
items were created.**

## Verdict

0/6 EAs seeded. 3/6 (`11561`/`11570`/`11731`) are correctly policy-excluded
and were never in scope for this ticket despite the stale health-flag text.
3/6 (`12512`/`10050`/`12507`) are genuinely missing their logical-basket Q02
row but are blocked by the Q01 smoke admission gate — each needs either a
fresh passing smoke run or durable tester-saturation evidence attached to its
build record before a governed Q02 seed can land. Recommend a build-lane
follow-up (Codex) to produce a real Q01 smoke pass for these three basket
EAs; this ops ticket should not itself bypass the smoke gate.
