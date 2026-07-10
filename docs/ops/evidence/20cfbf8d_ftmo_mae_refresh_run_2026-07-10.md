# FTMO Round25 MAE refresh run — 2026-07-10

Task: `20cfbf8d-0ce9-4fa7-acc8-9d45ce319df4`
Supersedes: `eda8c9c9-6de0-4ca5-8a40-f6fb054a62ba`
Report root: `D:/QM/reports/ftmo_mae_refresh_20260710/`

## Verdict

**INCOMPLETE — REVIEW REQUIRED.** The acceptance gate remains `4/12` fresh
MAE streams. Two real Model-4 full-history runs proved that the refreshed
binaries still do not produce admissible report-to-stream evidence:

| EA / sleeve | Full-history report | Report trades | Fresh JSONL rows | Reconciles? | Finding |
|---|---|---:|---:|---|---|
| `QM5_10700 / XAUUSD.DWX / H1` | `D:/QM/reports/ftmo_mae_refresh_20260710/QM5_10700/20260710_071140/raw/run_02/report.htm` | 373 | 0 | NO | `run_smoke` PASS, Model 4, 2017–2025; no stream emitted |
| `QM5_11476 / USDJPY.DWX / H1` | `D:/QM/reports/ftmo_mae_refresh_20260710/QM5_11476/20260710_071141/raw/run_01/report.htm` | 1,968 | 0 | NO | tester logged `out of memory in 'QM_Common.mqh' (631,23)` while appending the Q08 trade buffer |

The required final CE(S)T `ftmo_phase1_mae.py` result was therefore **not
run or accepted**. A partial-book result is not final evidence.

## Preflight and guardrails

- `validate_build_guardrails.py` returned PASS for all eight target EA
  directories with `max_news_stale_hours=336` and no findings.
- All eight exact target backtest setfiles use `RISK_FIXED=1000` and
  `RISK_PERCENT=0`.
- The eight deployed-source binaries were compiled on 2026-07-09 or
  2026-07-10. The repository and per-terminal copies for the two real runs had
  matching SHA-256 hashes.
- `run_smoke` recorded a fresh news calendar at age 3 hours and retained the
  fail-closed 336-hour ceiling.
- No target EA was active before dispatch. No live terminal, live preset,
  AutoTrading state, position, pipeline verdict, or gate threshold was changed.
  `terminal64.exe` was never started manually; all launches were through
  `framework/scripts/run_smoke.ps1`.

## Execution evidence

The approved active-terminal path was attempted only on enabled factory
terminals T1–T4 and T6–T8. T5, T9, and T10 remained parked.

The initial seven-way dispatch collided with factory terminal acquisition on
five roots. Those attempts never produced target report/stream evidence and
were not counted. Idle target child terminals and wrapper-only processes were
closed only after verifying they had no target metatester; active factory
terminal/metatester processes were not stopped.

Two target tests acquired real metatesters:

1. `QM5_10700 / XAUUSD.DWX / H1` on T3
   - Attempt 1 executed the target EA through 2025, but MT5 exported a
     structurally invalid `M0 / 1970 / Bars=0 / Trades=0` report. `run_smoke`
     correctly classified it `BARS_ZERO`.
   - Attempt 2 completed Model 4 over `2017.01.01–2025.12.31` and `run_smoke`
     returned PASS with 373 trades, PF 1.32, and the canonical report above.
   - The expected `10700_XAUUSD_DWX.jsonl` was absent after shutdown: report
     trades 373 versus emitted rows 0.

2. `QM5_11476 / USDJPY.DWX / H1` on T6
   - The canonical report covers `2017.01.01–2025.12.31`, Model 4 / real ticks,
     with 50,708 bars and 1,968 trades.
   - The tester journal at
     `D:/QM/mt5/T6/Tester/Agent-127.0.0.1-3003/logs/20260710.log` records at
     09:19:58: `out of memory in 'QM_Common.mqh' (631,23)`.
   - Line 631 is the in-memory `g_qm_q08_trade_log += StringFormat(...)`
     append. No JSONL stream was emitted: report trades 1,968 versus rows 0.

The missing-stream results show that more terminal retries are not admissible
without first repairing and verifying the stream-emission path. Synthetic
`entry_time` or `mae_acct` values were not inferred from the reports.

## Exact stream inventory after restoration

The four unaffected streams remain fully fresh:

| EA / sleeve | Closed rows | Numeric `entry_time` + `mae_acct` | State |
|---|---:|---:|---|
| `10163 / NDX.DWX` | 168 | 168 | FRESH |
| `10440 / NDX.DWX` | 768 | 768 | FRESH |
| `12958 / XAUUSD.DWX` | 71 | 71 | FRESH |
| `12990 / GBPUSD.DWX` | 34 | 34 | FRESH |

The eight target streams remain legacy-schema only:

| EA / sleeve | Closed rows | Numeric `entry_time` + `mae_acct` | State |
|---|---:|---:|---|
| `10286 / XTIUSD.DWX` | 50 | 0 | STALE |
| `10692 / NDX.DWX` | 441 | 0 | STALE |
| `10700 / XAUUSD.DWX` | 120 | 0 | STALE |
| `10847 / GBPUSD.DWX` | 216 | 0 | STALE |
| `10848 / XAUUSD.DWX` | 1,213 | 0 | STALE |
| `10911 / GDAXI.DWX` | 126 | 0 | STALE |
| `11476 / USDJPY.DWX` | 775 | 0 | STALE |
| `12475 / NDX.DWX` | 611 | 0 | STALE |

Before dispatch, the eight legacy files were moved to
`D:/QM/reports/ftmo_mae_refresh_20260710/pre_refresh_streams/`. After the
failed refresh, they were copied back to the Common Files stream directory so
the shared analysis state was not left degraded; the preserved copies remain
under the report root.

## Required review disposition

Do not rerun the final CE(S)T simulation or claim `12/12` until:

1. the Q08 stream path is changed from an unbounded in-memory trade string to a
   bounded/incremental emission design, or an equivalent verified repair;
2. a focused tester proves a valid report count equals the JSONL row count and
   every row has numeric `entry_time` and `mae_acct`;
3. all eight targets are rerun through serialized enabled-terminal capacity to
   avoid report collisions and global-memory pressure;
4. the exact 12-sleeve verifier returns `12/12` fresh;
5. only then is `ftmo_phase1_mae.py` run for the final 30-day and 60-day
   CE(S)T pass/breach split.

Paid FTMO Challenge status remains **NO-GO**. No pipeline verdict or Q07
lineage is inferred from this task.
