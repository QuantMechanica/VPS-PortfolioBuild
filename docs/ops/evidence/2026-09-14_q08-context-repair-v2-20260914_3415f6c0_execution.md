# Execution record — OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914 (receipt 3415f6c0, task 3ec11996)

OWNER 2026-09-14 ~14:5xZ (chat): "ABC & D freigegeben zur Umsetzung". Orchestrator lane, 15:0x–16:1xZ.
Evidence directory: `docs/ops/evidence/2026-09-14_q08_context_repair/`.

## Class A — 24 rows / 22 EAs with an approved card and no sealed search

| Step | Result |
|---|---|
| Declaration block | 20 cards amended (append-only `## Approved Amendment (2026-09-14) — DSR Single Configuration`, one `qm-dsr-single-configuration` block each, validated offline with `dsr_single_configuration.declaration` / `effective_parameters` before writing; D: card is the assembler source, C: mirrored where a copy exists). Journal `card_amend_journal.jsonl`. Canonical card names created for 41380 (`…_card.md` copy) and 41394 (C: → D:). |
| Excluded from the declaration | QM5_10163 (rows ba9aaa36/bae7cf06 lock `…_ablation_04.set`) and QM5_10932 (ce8f0416 locks `…_ablation_02.set`): an ablation series is a research search, so "no optimisation search" would be false. They stay INVALID / held and go to the class-B follow-up card. |
| Baseline set files | 5 EAs whose baseline set carried no `strategy_*` line (Q08 8.5 `baseline_setfile_defect:empty_strategy_params`): QM5_9724 H1, 12548 D1, 10412 H1 (versioned `s20260914-001`), 10290 D1, 11121 H4 (canonical regenerated in place; parameter dict identical to the versioned copy). Generator `framework/scripts/gen_setfile.ps1` from the approved card defaults. 10928/11179 already had regenerated `s20260907-001` sets. |
| Q08 rows | 10 append-only reruns of done INVALID rows (pinned to the current build via `--expected-current-ex5-sha256`, `--replacement-setfile` for the regenerated sets): 5df4eae7 20072, fd7dd094 41380, 2ec6d04e 9724, d64e26f7 12548, e77c1d8c 10412, 90a450b1 12925, 44c01339 11563 (claimed at 15:40Z on T9 with a SEALED context — the end-to-end proof), f5d489b9 13138, d5e42867 10928, 3c58c921 11179. 10 stale pending rows (recorded build identity from before the 2026-09-13 source repairs, or no timeframe) superseded by append-only dispositions and replaced by fresh rows pinned to the current build: a17469d0 12712, 0e3f3359 1328, d02a1128 13137, 84202fc0 11263, 6a060ccb 1910, 5fa7c144 10290, b6988aaf 12350, a6f023c9 11121, f74cea03 41394, 1c700065 9579. Every live row passes `dsr_single_configuration.validate` offline against the current mq5/ex5/set file. |
| Dispositions | 12 (plan) + 12 (extra: July 2026 pending chains of 1328/12712 and the first fresh rows that inherited stale hashes), receipts `dispositions_receipt*.json`, SQLite backups under `state/backups/`. |

Caveat recorded: for EAs whose `.mq5` was pin-repaired on 2026-09-13 without a rebuild, the declared `locked_parameters`
come from the current source text while the `.ex5` (identity per the OWNER rule) is unchanged; the set file overrides the
strategy parameters, and the mq5/ex5/set hashes are bound together in the context.

## Class C — 3 rows with a sealed DL-089 ledger

- Root cause 1 (fixed, commit series `dsr_cohort`): DL-090 retention had compressed the Q03/report evidence to `.gz`; the
  cohort looked for plain paths and hashed compressed bytes. `_evidence_file` / `_content_sha256` / aged-report
  materialisation added; 71 DSR tests + 3 new pass. QM5_21501/USDJPY assembles (DL089_V3, 156 trials); rerun 510bac30
  enqueued (append-only, pinned).
- Root cause 2 (contract question, on the follow-up card): prescreen-skipped census cells (`PRESCREEN_SKIPPED`) count as
  `INCOMPLETE_TRIAL` — 21507 (sell_032/2025) and 20266 (buy_010) wait for the rule.

## Class D — 2 rows, QM5_11167 old identity

19c9df13 superseded by 89ea5894 (same identity, FAIL_SOFT); 737a2134 superseded (identity rebuilt per
OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT), hold released. Dispositions `SUPERSEDED_IDENTITY` in the receipt.

## Class B — 11 rows without a card

Not declared (would be false). Follow-up card `OWNER-DEC-Q08-SWEEP-ARM-CONTEXT-20260914` minted (way 1 recommended:
window-sweep ledger as DSR search history + prescreen-skip rule; way 2: retire the standalone Q08 rows). 41472/41473/41474
keep their `Q08_DSR_CONTEXT_UNAVAILABLE` hold until the identity-equivalence binding lands (41473 EQUIVALENT_EXACT,
41474 NOT_EQUIVALENT → own chain, 41472 awaiting its Q02 replay).

## Infrastructure fixes made on the way (all committed)

- `farmctl` fresh/requeued rows pin the CURRENT build when the operator binds the ex5 (same helper as append-only
  reruns); the existing-row dedupe ignores superseded rows and non-backtest kinds. Incident: the old path requeued 8
  disposition rows to pending at 15:49Z; reverted under the mutation lock with a backup, root cause fixed.
- `dsr_cohort` timeframe fallback covers M1..MN1 set-file tokens.
- Reload chunk 84 (all ten workers) chained after chunk 83 so the claim-time preflight carries the evidence fixes.

## Acceptance (card)

- 24 cards carry a valid declaration block → **20 of 22 EAs** (2 excluded as false statements, documented above).
- Reruns claimed with a sealed DSR context → **first proof 44c01339 (11563) SEALED at 15:40Z**; the remaining rows are
  pending with offline-validated identities; claim-time proof follows as they run.
- No verdict overwritten; old rows stay as evidence → append-only throughout (dispositions + supersedes edges).
- No gate threshold, DSR formula or candidate-universe change → none.
