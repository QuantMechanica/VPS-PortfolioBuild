# Q-only ops evidence: T5 indicator-engine rebuild preflight

Date: 2026-07-26  
Router task: `61cfbaf3-a51d-437d-923c-a3eeff7f5116`  
Disposition: safe defer; no T1-T10 process was stopped and no terminal was
started manually.

## Confirmed state

- `D:\QM\strategy_farm\state\disabled_terminals.txt` contains exactly `T5`.
- No running process resolves below `D:\QM\mt5\T5`.
- The previous control evidence remains conclusive:
  `docs/ops/source_harvest/strategies/STR-097-ha-stoch-h4-swing/06_smoke.md`
  records both strategy handles and control EA `QM5_11144` returning
  `BarsCalculated=-1` throughout the tester run.
- T5's `terminal64.exe` and `metatester64.exe` are byte-identical to healthy
  T1:

  - terminal SHA-256:
    `3D7B65F97923E049613DDB91B1122FD7BD4E5FC7A9B58F941F541CBA7353A192`
  - tester SHA-256:
    `F0FF460321708859ECCC917FAB5EAC16D847F2ABBD4CDB6F66AEA50B5B015F41`

This rules out a stale or divergent executable as the demonstrated cause and
points to T5-local tester/configuration state.

## Why no rebuild was executed in this cycle

The payload requires rebuilding from a known-good template while preserving
the fleet de-junction topology and explicitly forbids re-importing `.DWX`
history. No registered script or evidence-backed procedure exists for that
whole-instance rebuild.

The current topology is material:

- T1 is the live factory source layout.
- T5 already has a real per-terminal `bases` directory.
- Fleet evidence
  `docs/ops/evidence/2026-07-21_bases_dejunction_spike_findings.md` requires
  per-terminal `Darwinex-Live` isolation and only a nested shared `Custom`
  junction.

A blind directory mirror from active T1 would overwrite terminal-local
configuration/tester state, could copy locked files, and could undo that
topology. Moving or deleting T5 without an enumerated preserve/restore
manifest would also be destructive and lacks a verified rollback. Those
actions were therefore not taken.

## Required repair packet

Before execution, create a checked-in or evidence-attached script that:

1. refuses unless T5 is disabled and no T5-owned process exists;
2. snapshots a path/type/hash manifest for T5;
3. preserves T5's isolated `bases` topology and does not copy `.DWX` history;
4. stages a fresh instance in a separate directory, using only known-good
   binaries and required static MQL5 assets;
5. validates junction targets and configuration before an atomic,
   rollback-capable swap;
6. runs the existing `QM5_11144` control through the supported smoke/tester
   runner (never by manually starting `terminal64.exe`);
7. requires tester-log/CSV evidence with `BarsCalculated > 0`;
8. removes T5 from `disabled_terminals.txt` only after that PASS.

Until all eight conditions are met, T5 must remain parked. The rest of the
factory remains untouched.

