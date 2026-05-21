# Cascade Real Phase Runners (2026-05-18)

Status: historical. Current automation is governed by the Q-Series hard-gate map in `PIPELINE_PHASE_SPEC.md` and `PIPELINE_PHASE_ID_MAP.md`.

2026-05-20 hardening note: Q08 is no longer report-first for promotion; hard PASS requires real MT5 crisis-slice reruns. Q11 hard PASS requires real MT5 news-mode reruns plus deal replay.

## Problem

Cascade promotion was creating P3/P3.5/P4/P5/P5b/P5c/P6/P7/P8 `work_items`
with `kind='backtest'`, but the per-terminal worker path treated those rows as
single-year smoke backtests. That made P3+ PASS evidence indistinguishable from
`run_smoke.ps1` output and allowed false-positive phase promotion.

The immediate fix is anti-theater: cascade work_items for P3.5+ now route to
phase-specific Python runners, or receive a non-PASS pending verdict when no
runner is present.

## Architecture

- P2 and P3 remain smoke/setfile based.
- P3.5, P4, P5, P5b, P5c, P6, P7, and P8 are real phase-runner phases.
- `tools/strategy_farm/farmctl.py` chooses the runner from `PHASE_RUNNER_SCRIPTS`.
- `tools/strategy_farm/terminal_worker.py` uses the same spawn helper instead of
  hard-wiring `run_smoke.ps1`.
- If a phase runner file is absent, the work_item is marked `done` with
  `verdict='PENDING_RUNNER'`; it is never marked PASS.
- Phase runners write `summary.json` via `framework/scripts/_phase_utils.py` so
  the existing work_item poller can classify results.

## Runner Status

| Phase | Spec intent | Cascade runner | Status |
|---|---|---|---|
| P3 | Parameter sweep, 30-50 variants | `run_smoke.ps1` / existing sweep pattern | Existing path retained |
| P3.5 | Cross-symbol robustness | `p35_csr_runner.py` | Wired; emits `PENDING_IMPLEMENTATION` without baseline evidence |
| P4 | Walk-forward, 2017-2022 train, 2023-2025 OOS, 6+ anchored folds | `p4_walk_forward.py` | Wired; emits `PENDING_IMPLEMENTATION` without WF CSV evidence |
| P5 | Stress test | `p5_stress_runner.py` | Wired; emits `PENDING_IMPLEMENTATION` without clean/stress metrics |
| P5b | Calibrated noise | `p5b_noise_runner.py` | Stub; non-PASS |
| P5c | Crisis slices | `p5c_crisis_runner.py` | Stub; non-PASS |
| P6 | Multi-seed, seeds 42/17/99/7/2026 | `p6_multiseed_runner.py` | Stub; non-PASS |
| P7 | DSR/MC/FDR with PBO < 5% hard gate | `p7_stats_runner.py` | Stub; non-PASS |
| P8 | News impact, 7 modes | `p8_news_runner.py` | Stub; non-PASS |

## Spec Compliance

This patch aligns cascade dispatch with `docs/ops/PIPELINE_PHASE_SPEC.md`:

- P2/P3 stay DEV-only setup and parameter exploration.
- P4 is the first OOS gate and is no longer represented by a single 2024 smoke.
- P5+ phases are separated into their named gates.
- P5c remains report-first and does not promote as PASS by default.
- P6 uses the specified seed set.
- P7 keeps `PBO < 5%` visible as a hard-gate requirement.
- P8 uses the seven specified modes: `OFF`, `PAUSE`, `SKIP_DAY`, `FTMO_PAUSE`,
  `5ers_PAUSE`, `no_news`, and `news_only`.

## Operational Note

Existing historical P3+ PASS rows created by the old smoke path should not be
treated as phase evidence. New cascade rows either point at a real phase-runner
summary or carry a pending implementation/runner verdict.
