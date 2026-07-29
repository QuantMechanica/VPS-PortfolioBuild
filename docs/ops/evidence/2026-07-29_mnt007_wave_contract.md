# MNT-007 recovery contract — 5, then 25

**OWNER lock:** 2026-07-29
**Implementation:** `tools/strategy_farm/requeue_stranded_infra.py`
**Runtime execution in this change:** none (read-only census only)

## Immutable release boundary

- Wave 1 contains exactly **5** eligible work-item rows.
- Wave 2 contains exactly **25** rows and cannot be planned or applied without a
  `qm.mnt007.wave1_receipt.v1` PASS receipt.
- Caller-selected `--limit` and unlimited apply are retired.
- A Wave-1 PASS requires all five bound rows to finish with real terminal
  verdicts: 100% disposition yield, 0 recurrent `INFRA_FAIL`, 0 INVALID outcome.
- The receipt binds its source journal by SHA-256 and freezes the exact next 25
  work-item IDs plus their pre-state. Planning and apply both re-evaluate the
  live read-only decision basis. Drift, reuse, tampering, a nonterminal row, or
  fewer than 25 eligible rows blocks Wave 2.
- Q08 `phase_runner_invalid_report`, explicit `INVALID_REPORT`, and preserved
  `*_invalid` evidence-lineage reasons are non-retryable. They receive
  `BLOCKED/q08_invalid_report_non_retryable` and can never enter either wave.
- A pair already represented in a deeper phase is a historical exclusion and
  is never resurrected from a lower-phase INFRA row.

## Read-only health invariant

`--health-census` scans Q03 through Q08 without opening the database writable.
For each phase it publishes infra groups and pair counts, current infra-only
cases, historical/superseded exclusions, cause, evidence presence, registry
state, and the deterministic disposition `RETRY`, `BLOCKED`, `RETIRED`, or
`REAL_VERDICT`. The invariant fails if a current case has no disposition or a
Q08 invalid-report case is exposed as retryable.

## Operator sequence

Planning, census, and receipt assessment are read-only. Each `--apply` is run
only in an authorized Factory-OFF, DB-quiescent window; workers may process the
released rows only after the coordinated restart/recovery authorization.

```powershell
python tools/strategy_farm/requeue_stranded_infra.py --health-census
python tools/strategy_farm/requeue_stranded_infra.py --wave 1 --snapshot-out <wave1-plan.json>
python tools/strategy_farm/requeue_stranded_infra.py --wave 1 --apply --snapshot-out <wave1-journal.json>

# Only after all five rows settle; this command reads the DB and writes a receipt, but does not mutate DB rows.
python tools/strategy_farm/requeue_stranded_infra.py --assess-wave1 <wave1-journal.json> --receipt-out <wave1-receipt.json>

python tools/strategy_farm/requeue_stranded_infra.py --wave 2 --wave1-receipt <wave1-receipt.json> --snapshot-out <wave2-plan.json>
python tools/strategy_farm/requeue_stranded_infra.py --wave 2 --wave1-receipt <wave1-receipt.json> --apply --snapshot-out <wave2-journal.json>
```

The pre-existing durable journal, archive-before-commit compensation, exact
row-state drift checks, and byte-faithful revert protocol remain unchanged.
