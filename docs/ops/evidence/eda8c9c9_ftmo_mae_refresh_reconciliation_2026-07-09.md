# FTMO Round25 MAE refresh reconciliation — 2026-07-09

Task: `eda8c9c9-6de0-4ca5-8a40-f6fb054a62ba`
Scope: read-only reconciliation and non-live binary refresh for the 12-sleeve
Round25 analysis book. No live terminal, live preset, AutoTrading state,
position, pipeline verdict, or gate threshold was changed.

## Verdict

**INCOMPLETE — REVIEW REQUIRED.** The acceptance condition is not met:
`4/12` streams are fresh and `8/12` remain stale. The final CE(S)T MAE
simulation is therefore not admissible and was not accepted as evidence.

The immediate root cause is confirmed. A real refresh run for
`QM5_10692 / NDX.DWX / H1` produced a canonical `report.htm` with 224 trades,
but the run loaded a binary compiled on 2026-07-05. The framework's
`entry_time`/`mae_acct` capture include was updated on 2026-07-06. The resulting
stream retained the legacy schema with neither field.

## Exact 12-sleeve stream inventory

The verifier counted only `TRADE_CLOSED` rows and required **every** row to
contain numeric `entry_time` and `mae_acct` values.

| EA | Expected symbol | TF | Closed rows | Rows with both fields | Invalid/missing rows | State |
|---|---|---:|---:|---:|---:|---|
| `QM5_10163` | `NDX.DWX` | H1 | 168 | 168 | 0 | FRESH |
| `QM5_10286` | `XTIUSD.DWX` | D1 | 50 | 0 | 50 | STALE |
| `QM5_10440` | `NDX.DWX` | H1 | 768 | 768 | 0 | FRESH |
| `QM5_10692` | `NDX.DWX` | H1 | 441 | 0 | 441 | STALE |
| `QM5_10700` | `XAUUSD.DWX` | H1 | 120 | 0 | 120 | STALE |
| `QM5_10847` | `GBPUSD.DWX` | H1 | 216 | 0 | 216 | STALE |
| `QM5_10848` | `XAUUSD.DWX` | H1 | 1,213 | 0 | 1,213 | STALE |
| `QM5_10911` | `GDAXI.DWX` | H1 | 126 | 0 | 126 | STALE |
| `QM5_11476` | `USDJPY.DWX` | H1 | 775 | 0 | 775 | STALE |
| `QM5_12475` | `NDX.DWX` | H1 | 611 | 0 | 611 | STALE |
| `QM5_12958` | `XAUUSD.DWX` | D1 | 71 | 71 | 0 | FRESH |
| `QM5_12990` | `GBPUSD.DWX` | H4 | 34 | 34 | 0 | FRESH |

The symbol/timeframe identities match the 12 Round25 presets, including the
explicit `GER40.cash -> GDAXI.DWX`, `US100.cash -> NDX.DWX`, and
`USOIL.cash -> XTIUSD.DWX` mappings.

## Report and stream reconciliation for the eight stale sleeves

| EA / sleeve | Canonical report evidence | Report trades | Current stream rows | Reconciles? |
|---|---|---:|---:|---|
| `10286 / XTIUSD.DWX / D1` | `D:/QM/reports/prop_ftmo_candidates_20260629/validation_round20/QM5_10286/20260630_044953/raw/run_01/report.htm` | 189 | 50 | NO |
| `10692 / NDX.DWX / H1` | `D:/QM/reports/ftmo_mae_refresh_20260709/QM5_10692/20260709_205406/raw/run_01/report.htm` | 224 | 441 | NO |
| `10700 / XAUUSD.DWX / H1` | `D:/QM/reports/prop_ftmo_candidates_20260629/validation_round14/QM5_10700/20260629_181939/raw/run_01/report.htm` | 151 | 120 | NO |
| `10847 / GBPUSD.DWX / H1` | `D:/QM/reports/prop_ftmo_candidates_20260629/validation_round23/QM5_10847/20260630_060004/raw/run_01/report.htm` | 272 | 216 | NO |
| `10848 / XAUUSD.DWX / H1` | `D:/QM/reports/prop_ftmo_candidates_20260629/validation_round12/QM5_10848/20260629_173555/raw/run_01/report.htm` | 502 | 1,213 | NO |
| `10911 / GDAXI.DWX / H1` | `D:/QM/reports/prop_ftmo_candidates_20260629/validation_round31/QM5_10911/20260704_175856/raw/run_01/report.htm` | 141 | 126 | NO |
| `11476 / USDJPY.DWX / H1` | `D:/QM/reports/prop_ftmo_candidates_20260629/validation_round6/QM5_11476/20260629_141313/raw/run_02/report.htm` | 775 | 775 | YES, legacy schema only |
| `12475 / NDX.DWX / H1` | `D:/QM/reports/prop_ftmo_candidates_20260629/validation_round10/QM5_12475/20260629_170803/raw/run_01/report.htm` | 691 | 611 | NO |

The seven count mismatches prove that adding synthetic fields to the current
JSONL files would not be a legitimate repair. Fresh instrumented tester runs
are required. No values were inferred or fabricated from `report.htm`.

## Binary refresh and guardrails

All eight target backtest setfiles retain the required risk contract:
`RISK_FIXED=1000` and `RISK_PERCENT=0`. News staleness remained fail-closed at
the framework maximum of 336 hours.

Five EAs compiled through `compile_ea.py --force` against the current MAE
capture include with 0 errors and 0 warnings:

| EA | Compile UTC | Result |
|---|---|---|
| `QM5_10286` | 2026-07-09 21:24:01 | COMPILED |
| `QM5_10700` | 2026-07-09 21:24:12 | COMPILED |
| `QM5_10848` | 2026-07-09 21:24:23 | COMPILED |
| `QM5_11476` | 2026-07-09 21:24:34 | COMPILED |
| `QM5_12475` | 2026-07-09 21:24:44 | COMPILED |

Three EAs were correctly stopped by `validate_build_guardrails.py` and
`compile_ea.py`; the guard was not bypassed:

| EA | Blocking finding |
|---|---|
| `QM5_10692` | `time_sensitive_strategy_params_missing` in canonical backtest sets |
| `QM5_10847` | `time_sensitive_strategy_params_missing` in canonical backtest sets |
| `QM5_10911` | `time_sensitive_strategy_params_missing` in canonical backtest sets |

The routed task explicitly forbids setfile changes, so these three findings
require a separate authorized setfile repair before an instrumented compile.

## Refresh-attempt evidence

Pre-refresh streams were preserved under
`D:/QM/reports/ftmo_mae_refresh_20260709/pre_refresh_streams/`.

- `QM5_10692` produced a valid 224-trade report, proving the target
  symbol/timeframe/window can run, but the pre-instrumentation binary emitted no
  fresh fields.
- `QM5_10847` on T5 failed closed with `ACCOUNT_NOT_SPECIFIED`; no valid report
  was produced.
- `QM5_10911` attempts on T9/T10 produced invalid zero-bar reports
  (`BARS_ZERO`, empty report header).
- `QM5_11476` attempts on T9 produced `REPORT_MISSING`, with one
  `METATESTER_HUNG` classification.
- `QM5_10700` attempts on T10 did not yield a canonical report before the
  overlapping attempt stopped.

These attempts are recorded under `D:/QM/reports/ftmo_mae_refresh_20260709/`
and `D:/QM/reports/smoke_ftmo_mae/`. Active factory tests were not interrupted.

## Focused verification

- `validate_build_guardrails.py`: five target EA directories PASS; three fail
  closed as listed above.
- Risk-set inspection: 8/8 use `RISK_FIXED > 0`, 8/8 use
  `RISK_PERCENT = 0`.
- Exact stream-schema verifier: 4/12 fresh, 8/12 stale.
- `ftmo_phase1_mae.py` independently reports the same loaded/stale split. A
  short partial mechanics check was observed but is discarded as
  non-authoritative; the final CE(S)T artifact must not be generated until the
  split is 12/12.

## Required review disposition

Return this task to a controlled retry only after:

1. the three guardrail-blocking canonical setfile defects have separately
   authorized repairs;
2. all eight binaries compile with the July 6+ MAE capture;
3. idle test capacity is available through the approved terminal workflow;
4. each new `report.htm` trade count equals its emitted JSONL row count and
   every row has numeric `entry_time` and `mae_acct`;
5. only then, run the final CE(S)T `ftmo_phase1_mae` artifact.

Paid FTMO Challenge status remains **NO-GO**. No pipeline verdict is inferred
from this reconciliation.
