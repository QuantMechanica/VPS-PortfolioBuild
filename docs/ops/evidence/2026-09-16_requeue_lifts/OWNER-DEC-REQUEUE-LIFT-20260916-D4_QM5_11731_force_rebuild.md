# OWNER-DEC-REQUEUE-LIFT-20260916-D4 — QM5_11731 force-rebuild authority (scoped)

- Owner decision id: `OWNER-DEC-REQUEUE-LIFT-20260916-D4`
- Ratifies under interim delegation: `OWNER-DEC-REQUEUE-LIFT-20260916` (D2B,
  APPROVED WITH CONDITIONS: EURUSD.DWX M5 pilot first, fan out only on a clean pilot)
- Date (UTC): 2026-09-16
- EA: `QM5_11731` (slug `QM5_11731_tc-m5-s20-ema3-bb-macd`; 4-symbol card
  universe EURUSD/GBPUSD/USDCHF/USDJPY .DWX, all M5)

## Scope and conditions (mandatory)

- **EA scope: QM5_11731 ONLY.** This authority grants NO generic force-rebuild
  capability. No other EA id is named or implied.
- Preserve existing EX5/build evidence: never delete the old wave-64 `.ex5`
  bytes (they remain git-committed history), never reopen or mutate the done
  build task `1a17f439-b48e-46db-986b-2a3c62f8816c`.
- Create NEW append-only repair lineage: one fresh COMPILE_EA work item, one
  deterministic canonical local MetaEditor compile (codex NOT required —
  provider determination already made, see
  `QM5_11731_D2B_continuation_RECEIPT.md` section 1), 0 errors / 0 warnings,
  normal hardening checks pass.
- Lift the requeue exclusion ONLY after a valid fresh build identity exists
  (done/`COMPILE_OK` COMPILE_EA row with matching ex5 hash).
- EURUSD.DWX M5 canary first via `farmctl intake-first-q02`; the remaining
  symbols (GBPUSD/USDCHF/USDJPY) fan out only after the canary pilot checks
  (a–e: data integrity, normal claim, Model-4 Every Real Tick, valid evidence,
  no setup/data failure) come back CLEAN.
- Economic FAIL is a legitimate result and is reported as such.

## Technical effect

`tools/strategy_farm/compile_work_items.py` reads this document through
`requeue_lift_d4_force_rebuild_allowlist`: the hardcoded
`REQUEUE_LIFT_D4_FORCE_REBUILD_EA_IDS` name AND this document (exact owner
reference AND the `QM5_11731` name) must both agree, else the bypass stays off.
This waives only the candidate-guard refusals `EX5_ALREADY_PRESENT` and
`BUILD_TASK_EXISTS` for QM5_11731 so the governed enqueue-compile → COMPILE_EA
→ intake-first-q02 path can run.

## Why this EA needs it

`QM5_11731` holds a git-tracked wave-64 `.ex5` (2026-08-04) and a `done`
build_ea task, and has zero work items of any kind, so the fail-closed enqueue
guards refuse `EX5_ALREADY_PRESENT` + `BUILD_TASK_EXISTS` with no other
legitimate waiver (documented in `QM5_11731_receipt.md` and
`QM5_11731_D2B_continuation_RECEIPT.md`). Rebuilding the `.ex5` under a new
COMPILE_EA identity is the entire point of this scoped repair; the old binary
and build task remain untouched as append-only evidence.

## Revocation

Removing or rewriting this document (or the owner reference in it) turns the
bypass back off for QM5_11731 without a code change.
