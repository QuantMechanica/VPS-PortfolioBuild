# STR-004 / QM5_20103 — Build record (2026-07-24, tranche 2)

- Scaffold: ea_id 20103, magics 201030000-01, resolver verified, SPEC.md
  validator PASS. Hooks: codex (task 01724557).
- Claude integration review (reciprocal): PASS — single unshifted SMMA(5)
  handle read at shifts 1 and 1+displacement; WPR-SMMA recursion with FIXED
  400-bar seed, correct old→new direction, per-closed-bar cache (forming-time
  key), bounded O(seed_depth) with perf-allowed markers; full-condition edge
  trigger with shift-1/shift-2 truth caching; ExitSignal = closed-bar LEVEL
  recross condition; emergency 4×ATR stop normalized away from fill; WPR
  colour mapping per ledger evidence (Red=8/Blue=21; reconciliation #7).
- build_check PASS; strict compile 0/0; 2 sets.
- Smoke: not run — indicator EA, no valid host (T5 indicator engine dead;
  OWNER waiver applies). Q02 = aliveness check.
