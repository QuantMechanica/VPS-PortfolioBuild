# Poison-pill quarantine and EA-readable calendar gate (2026-07-26)

## Outcome

Both requested controls are implemented without stopping or isolating the factory, touching
T_Live, changing AutoTrading, or adding a concurrency cap.

## Poison-pill quarantine

The scheduler now maintains a separate `poison_pill_quarantine` table keyed by
`(ea_id, symbol, phase)`. Before either production claim path selects work, it evaluates
pending triples from immutable `work_items` history. A triple is excluded from scheduling
only when:

- the latest five completed attempts are all `INFRA_FAIL`;
- all five carry the identical non-empty `verdict_reason`; and
- no `PASS` or `FAIL` merit verdict has ever been recorded for the triple.

Five was selected because the smallest measured poison population is 12 identical failures.
It stops waste seven runs earlier than that population while still requiring five independent
observations. A changed reason ends the streak. Merit `PASS` and `FAIL` rows count as successful
terminal execution and can never themselves cause quarantine.

The state is visible in `poison_pill_quarantine`: reason, consecutive count, successes-ever
count, newest evidence/log/report path, quarantine time, and release history. Existing
`work_items` are never rewritten.

Release one fixed triple with:

```powershell
python tools/strategy_farm/poison_pill_quarantine.py release --ea-id QM5_11896 --symbol EURUSD.DWX --phase Q02 --note "fixed: <ticket/evidence>"
```

Release is reversible operationally: it marks the quarantine inactive and grants a fresh
observation window. The item is immediately claimable; only five new identical infrastructure
failures after the release can quarantine it again. The command is compare-and-update guarded
and refuses when no matching active quarantine exists.

### Current-backlog projection

The read-only scan at 2026-07-26 found **371 of 2,162 pending triples (17.2%)** eligible:

| phase | reason | triples |
|---|---|---:|
| Q02 | `summary_missing_retries_exhausted` | 366 |
| Q02 | `run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS` | 5 |

Streak distribution: 5=16, 6=161, 7=128, 8=7, 9=5, 10=9, 11=16, 12=28, 23=1.
Every worklist entry includes its reason and the newest available summary, work-item log, or
report-root path. Full machine-readable diagnosis worklist:
`docs/ops/evidence/2026-07-26_poison_pill_worklist.json`.

This was deliberately a projection only. It did not mass-update `work_items` and did not
activate the 371 quarantine rows. The live scheduler will add quarantine records
idempotently at its normal claim boundary; at report time active quarantine count remained
zero.

## EA-readable news-calendar gate

`run_smoke.ps1` now validates the two files under the actual MQL5 `FILE_COMMON` route:

`%APPDATA%\MetaQuotes\Terminal\Common\Files`

It checks both Common files exist, uses the older file's mtime for the 14-day freshness gate,
and SHA256-compares each Common file with its corresponding `D:\QM\data\news_calendar`
source. Missing Common files, stale Common files, or any hash mismatch throw before
`Start-TesterRun`, and the exception names the Common path.

The refresh task now treats any Common-copy exception as a terminating failure after reporting
the exact source, destination, and error. It no longer emits a warning and then exits
successfully when MT5 holds a destination open.

At verification time both production Common files existed, matched their source SHA256
exactly, and had Common mtimes of `2026-07-26T15:54:41.6416106Z`:

| file | SHA256 |
|---|---|
| `news_calendar_2015_2025.csv` | `65B27D349B798713D11285E103FBEC26851FC67D7F8AF0D100AC7923F219A967` |
| `forex_factory_calendar_clean.csv` | `4E416AB17EB2C9960F621C71929D3878E1B61C437E4E289806ED4A9F4897D57E` |

## Verification

- `python -m pytest tools/strategy_farm/tests/test_poison_pill_quarantine.py tools/strategy_farm/tests/test_refresh_news_calendar.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q`
  — **59 passed**.
- `powershell.exe -NoProfile -NonInteractive -File framework/scripts/tests/Test-RunSmokeNewsCalendarGate.ps1`
  — **PASS**.
- `python -m py_compile tools/strategy_farm/poison_pill_quarantine.py tools/strategy_farm/farmctl.py tools/strategy_farm/terminal_worker.py`
  — **PASS**.
- `git diff --check` — no whitespace errors.

## Limits and residual cause

No real MT5 smoke was launched because the factory is live; therefore the pre-spawn failure
was verified structurally and with isolated tests, not by consuming a production terminal
slot. The refresh copy-failure path was verified with a deterministic filesystem collision,
not by deliberately locking a production Common file.

The current Common copies are present, fresh, and byte-identical to source. This change does
not identify the residual post-refresh `ONINIT_FAILED` cause, and there is no evidence here
that calendar state is its sole cause. Residual OnInit failures still require diagnosis from
new pre-gate-clean runs.
