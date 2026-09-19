# Q02 ONINIT_FAILED root-cause dig — 4216dd75 (Claude, 2026-09-19)

Scope: the four EA groups named in router task `4216dd75-6430-4ccb-b545-6c6cf6f3fd4b` —
QM5_12582/XNGUSD, QM5_10369/GDAXI+NDX+SP500, QM5_10327/GDAXI, QM5_10505/XAUUSD. Per-pair detail
is in the sibling `oninit_QM5_<id>.md` files. This document is the cross-pair synthesis,
the infra-constraint explanation, and the packet the acceptance criteria ask for.

**Never requeued anything blind. Never touched a verdict.** This is a read-only diagnostic
pass plus new evidence files; the existing `q02_stranded_20260919.json` (committed
`27a2ffeeaf`, part of today's separate 7-point factory-unblock sweep) is untouched.

## Per-pair result

| EA | Symbol | Latest verdict evidence | Tester-log signature | Classification |
|---|---|---|---|---|
| QM5_12582 | XNGUSD.DWX | `ae468d0f-...` 2026-09-07 | `OnInit returns non-zero code 1` | `UNRESOLVED_REQUIRES_INSTRUMENTED_REBUILD` |
| QM5_10369 | GDAXI.DWX | `89875e78-...` 2026-09-15 | `OnInit reports incorrect input parameters` | `UNRESOLVED_REQUIRES_INSTRUMENTED_REBUILD` |
| QM5_10369 | NDX.DWX | `446e60ca-...` 2026-09-15 | `OnInit reports incorrect input parameters` | `UNRESOLVED_REQUIRES_INSTRUMENTED_REBUILD` |
| QM5_10369 | SP500.DWX | `f262acc0-...` 2026-08-30 | — | **out of scope: already `RETIRE`** |
| QM5_10327 | GDAXI.DWX | `838e5951-...` 2026-09-15 | none — `TIMEOUT` this run | `INFRA_TRANSIENT_UNCONFIRMED_ONINIT` |
| QM5_10505 | XAUUSD.DWX | `cc347183-...` 2026-09-11 | `OnInit returns non-zero code 1` | `UNRESOLVED_REQUIRES_INSTRUMENTED_REBUILD` + stale-`.set` hygiene defect |

Two distinct tester-log signatures showed up, and they mean different things:

- **`OnInit returns non-zero code 1`** (QM5_12582, QM5_10505): `OnInit()` executed and the EA's
  only failure path — `if(!QM_FrameworkInit(...)) return INIT_FAILED;` — actually ran. The
  rejection is somewhere inside the five internal `return false` branches of
  `QM_FrameworkInitCoreAfterRuntimeStateArmed` (`framework/include/QM/QM_Common.mqh`):
  `runtime_state_not_armed`, `ea_id_non_positive`, `portfolio_weight_out_of_range`,
  `risk_inputs_invalid`, `magic_resolution_failed`.
- **`OnInit reports incorrect input parameters`** (QM5_10369 GDAXI+NDX): the EA source can only
  ever return `INIT_SUCCEEDED`/`INIT_FAILED`, never `INIT_PARAMETERS_INCORRECT` explicitly, so
  this wording for a code path that cannot produce it points at the tester's own `.set`-to-
  `.ex5` parameter binder refusing **before** `OnInit()` is even called — corroborated by the
  GDAXI worker log recording zero logger files (the EA's `QM_LoggerInit` call is the first
  statement inside the framework init core, so zero files means that function body never ran).

Neither signature matches the known `project_qm_inputsvalid_framework_pin_defect_2026-08-20`
class (a hard-coded EA-side `input == constant` check on a framework-owned input): grepped all
four EA sources for `QM_InputRequire` and hand-equality checks against `qm_rng_seed`,
`qm_stress_reject_probability`, `qm_news_temporal` — zero hits in all four. That known class is
ruled out for this batch.

## What was checked and ruled out, across all four EAs

- Magic registry rows present, active, and slot/symbol-consistent with each set file
  (`framework/registry/magic_numbers.csv`) — not a missing-registration cause.
- `RISK_FIXED`/`RISK_PERCENT`/`PORTFOLIO_WEIGHT` valid in every set file — not an out-of-range
  risk input.
- `ex5_sha256` stable across weeks/months per pair — not a build-drift flip between the many
  attempts (rules out "different code compiled between runs" as an explanation for the
  consistent failure).
- One genuine, independently actionable defect found: QM5_10505's XAUUSD `.set` file carries
  nine `qm_filter_*` keys that do not exist as inputs anywhere in the current
  `QM5_10505_mql5-macd-sar.mq5` — orphaned residue from a source refactor, evidence the set was
  never regenerated via `gen_setfile.ps1` against current card defaults. See
  `oninit_QM5_10505.md` for detail and the recommended fix.

## Why no fresh out-of-claim `run_smoke` reproduction was spawned this cycle

The acceptance criterion asks for a governed `run_smoke` reproduction "no factory claim." Three
options were evaluated and all three were rejected for concrete, checked reasons — this was not
skipped for convenience:

1. **`DEV1`/`DEV2` (the framework's own bounded isolated-dev lanes)** — `run_smoke.ps1` hard-
   requires the Windows identity `%COMPUTERNAME%\QMDev1` / `QMDev2` for these terminals
   (`framework/scripts/run_smoke.ps1:102-125`). This session runs as `SYSTEM` (headless
   scheduled task), which is neither identity, so `run_smoke.ps1 -Terminal DEV1/DEV2` would
   throw immediately.
2. **`T11`/`T12`** — these sit outside the automated T1–T10 claim/worker fleet
   (`farmctl.py mt5-slots` lists `terminal_workers` for T1–T10 only), so they don't risk
   racing a live backtest. But `D:\QM\mt5\T11\Bases` (checked directly) carries no privatized
   `Bases\Custom` data for GDAXI/NDX/SP500/XAUUSD/XNGUSD — these are all Custom-history symbols
   under the Variant-A per-terminal containment (`docs/ops/evidence/2026-08-10_ramp10_serialization_gate_statonly_fix.md`).
   A run there would not reproduce the real failure; it would most likely hit `NO_HISTORY`
   instead, contaminating rather than confirming the evidence. `farmctl reserve-terminal T11`
   was actually issued and then released once this was confirmed — see the reservation
   audit trail (`reserved_by=claude_task_4216dd75`, released same session).
3. **A live T1–T10 slot** — these do carry the needed Custom-history data, but `reserve-terminal`
   is not actually enforced: `terminal_reservation()` in `farmctl.py` is defined and written to
   `state/terminal_reservations.json`, but grepping the whole file shows it is **never read** by
   the automated claim/dispatch loop. Reserving a T-slot would not stop that terminal's
   `terminal_worker.py` daemon from claiming and starting its own `terminal64.exe` concurrently
   — a direct violation of "do not interrupt active T1-T10 backtests." Manually spawning
   `run_smoke.ps1` there was therefore not attempted.

**Net effect**: a genuinely safe, out-of-claim reproduction of these five Custom-history-symbol
OnInit failures is not currently possible from a `SYSTEM`-identity headless session. This is
itself a real infra gap, not just a task blocker — flagged below as a follow-up.

## Recommended next step (not executed — outside this task's authority/capability)

File a Codex `build_ea`/`ops_issue` ticket to:

1. Add `QM_LogEvent`/`QM_InputRequire*`-style self-describing predicates to every remaining
   bare `return false` in `QM_FrameworkInitCoreAfterRuntimeStateArmed` and to
   `QM_RuntimeExecutionBeginLegacyInitialization`, following the exact pattern already
   established by the 2026-08-17 fix
   (`docs/ops/evidence/2026-08-17_bars_zero_is_oninit_rejection_misclassified_as_infra.md`).
2. Regenerate `QM5_10505_mql5-macd-sar_XAUUSD.DWX_H1_backtest.set` via `gen_setfile.ps1` to
   drop the orphaned `qm_filter_*` keys (independent of point 1).
3. Recompile the affected EAs and dispatch exactly one exact-successor Q02 attempt per pair on
   a real T1–T10 slot (through the normal factory claim path this time, since the instrumented
   build needs the real Custom-history data and the current architecture has no other safe
   lane) to capture which branch fires, before any bulk requeue is considered.
4. Separately: consider whether `farmctl reserve-terminal`/`release-terminal` should actually
   gate the automated claim loop, since right now it is pure bookkeeping — a structural gap
   for any future bounded manual diagnostic on a live factory terminal.

## Packet

`q02_stranded_20260919_oninit_rootcause.json` (this directory) — machine-readable form of the
table above, distinct from and additive to the already-committed
`q02_stranded_20260919.json` census.
