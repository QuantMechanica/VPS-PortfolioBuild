# QM5_20152 EURUSD Q02 collateral LOG_BOMB recovery

Date: 2026-08-05

Router task: `bcad1975-7303-4de6-8bc2-f7586da9735d`

Branch: `agents/board-advisor`

## Scope

This task was limited to diagnosing the Q02 infrastructure failure for
`QM5_20152_sma-cross-pullback-h1` on `EURUSD.DWX` and ensuring that a governed
Q02 retry existed. It did not authorize strategy changes, a pipeline verdict,
portfolio work, deployment, `T_Live`, or AutoTrading.

The backtest set remains within the fixed-risk guardrail:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- symbol/timeframe `EURUSD.DWX` / `H1`
- setfile SHA-256
  `cf82084ca76ce0182a455f395f326d93f01db67a691068e1c674218fc60dd89c`

## Diagnosis

The source work item was infrastructure-only, not an economic result:

- Work item: `9f479af0-e9c4-434e-bc0e-4fb8f9c0e6fc`
- Evidence:
  `D:\QM\reports\work_items\9f479af0-e9c4-434e-bc0e-4fb8f9c0e6fc\QM5_20152\20260801_021555\summary.json`
- Terminal: `T4`
- Result/reasons: `FAIL` / `LOG_BOMB;INCOMPLETE_RUNS`
- Detected journal: `D:\QM\mt5\T4\Tester\logs\20260801.log`
- Detected size: 72.64 GB
- Attempted runs: 1; report size: 0; no Q02 strategy verdict was available
- News calendar: `OK`, age 94 hours, maximum 336 hours

The failure was collateral from an earlier T4 journal bomb:

1. Root-cause work item `4fc6101a-0a73-4a06-ac07-bd619a141d66`
   (`QM5_13022`, `XAUUSD.DWX`) produced a genuine 98.6 GB tester journal on
   T4. Its durable detector record is
   `D:\QM\reports\work_items\4fc6101a-0a73-4a06-ac07-bd619a141d66\log_bomb_evidence.json`.
2. The next T4 work item, `3cb3c72f-5ce4-4b54-9b5c-774ff3df8ab4`
   (`QM5_1424`), started about two minutes later and immediately detected the
   same 98.6 GB Agent journal as its own `LOG_BOMB`.
3. `QM5_20152` then started on T4 roughly one minute later and was killed by
   the surviving mirrored dispatcher journal. Its EA-specific logger emitted
   no sample and its report remained empty, which is consistent with a stale
   sibling journal rather than an EA-generated 72.64 GB stream.

The infrastructure mechanism is already fixed by commit
`9f53ce7fcaa7da2a522c1c60c90e8051ad1dc0bd`. After a detected log bomb stops
the terminal/metatester processes, `run_smoke.ps1` now removes every over-cap
dispatcher and Agent journal under that terminal root. The absolute 4 GB disk
safety cap remains unchanged.

## Governed retry result

A later governed, append-only Q02 work item already exercised the same failed
execution identity on a different terminal, so another retry was not enqueued:

- Work item: `b37949eb-18a7-4181-be2c-822442d968e1`
- Evidence:
  `D:\QM\reports\work_items\b37949eb-18a7-4181-be2c-822442d968e1\QM5_20152\20260801_151216\summary.json`
- Terminal: `T10`
- Result/reason: `FAIL` / `MIN_TRADES_NOT_MET`
- Farm verdict: `ZERO_TRADES`
- Run status/exit: `OK` / `0`
- Real-ticks marker: present
- Deterministic: true
- Trades: 0
- Log-bomb detected: false
- News calendar: `OK`, age 107 hours, maximum 336 hours

The failed and retry runs bind the same EX5 SHA-256
`1518feeb984455518340b578a75b93f374b966dde85accd71cd095ddcf2df3e0`
and the same setfile SHA-256
`cf82084ca76ce0182a455f395f326d93f01db67a691068e1c674218fc60dd89c`.
Both use `EURUSD.DWX`, H1, Model 4, and `2022-07-01` through `2022-12-31`.
The retry therefore closes the collateral infrastructure question and exposes
a separate zero-trade result. It does not produce a Q02 PASS or an economic
pipeline verdict.

No additional Q02 work item was created because the farm already contains the
terminal retry above and no open `QM5_20152` Q02 row. Any investigation of the
zero-trade outcome must be separately routed through the deterministic
zero-trades recovery workflow; this task does not authorize it.

## Focused verification

Run from `C:\QM\repo` on 2026-08-05:

- `Test-RunSmokeLogBombSiblingCleanup.ps1`: PASS
- Fix commit is an ancestor of canonical checkout HEAD
  `a632ceac56bc9480d9cd877ba27f8a403831cb12`: PASS
- Backtest set risk contract (`RISK_FIXED=1000`, `RISK_PERCENT=0`): PASS
- `qm_news_stale_max_hours <= 336` guard: PASS
- `farmctl.py work-items --ea QM5_20152`: two terminal rows only
  (`INFRA_FAIL`, `ZERO_TRADES`); no open row

No EA source, EX5, setfile, registry, terminal setting, or live artifact was
changed by this recovery.

## Disposition

`REVIEW` — collateral `LOG_BOMB` diagnosis confirmed; mirrored-journal cleanup
fix present and regression-tested; governed retry completed cleanly as
`ZERO_TRADES`; no duplicate Q02 enqueue performed.
