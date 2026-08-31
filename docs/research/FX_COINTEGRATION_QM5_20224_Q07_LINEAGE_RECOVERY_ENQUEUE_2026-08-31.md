# QM5_20224 FX Cointegration Q07 Lineage Recovery

Date: 2026-08-31  
Branch: `agents/board-advisor`

## Status

`QM5_20224` (`EURUSD~EURJPY`) received one append-only Q07 recovery work item:
`adb5e3aa-b942-4830-9478-328522727482`. It was `pending` with no verdict immediately
after enqueue. The resident paced fleet owns dispatch; no tester was started manually.

Repair commit: `b055b1acfd86914f491f47e0e047ca55e5de330c`.

## Why this existing sleeve was selected

The controlling scan and duplicate audit remain:

- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`

The strict 66-pair frontier is fully mechanized, so creating another card would be a
duplicate. The two anchor sleeves are not Q02-blocked: `QM5_12532` has Q02/Q04 PASS and
is economically terminal at Q05; `QM5_12533` has Q02 PASS and is economically terminal
at Q04. The next attempted frontier continuation, `QM5_20246`, also received an
authenticated Q04 FAIL, so it was not refit or rescued.

`QM5_20224` is the strongest nonterminal existing FX sleeve found in the funnel. Its
bound chain is Q02 PASS, Q03 PASS, Q04 PASS_SOFT, Q05 PASS, Q06 PASS, followed by Q07
infrastructure failures. This is therefore an infrastructure recovery, not a strategy
mechanics change.

## Root cause and repair

The first Q07 row (`9ba93eb9-4973-4759-9efa-f7ff224f1494`) produced four valid seeds:

| Seed | PF | Trades | Evidence terminal |
|---:|---:|---:|---|
| 42 | 1.08 | 185 | T3 |
| 17 | 1.40 | 182 | T3 |
| 99 | 1.26 | 187 | T3 |
| 7 | 1.35 | 182 | T3 |

Seed 2026 was a false report latch, not a structural zero-trade run. Its stable HTML
shell reported `Bars=1188`, `Symbols=0`, and `Total Trades=0`, while the bound tester
journal recorded deals through `#209` before `tester forced to close`. The report shell
was accepted while the full 2018-2025 test was still running.

The second append-only row (`b38e2753-1d57-45d9-8562-3cafc0e105a0`) independently
reproduced valid seeds 42 and 17, then lost the remaining summaries. It also exposed a
separate resumability gap: Q07 searched only its current report root and legacy
`.requeued_*` names, while governed append-only retries now use new GUID roots.

The repair is deliberately harness-only:

- a zero-symbol/zero-trade report remains parseable final evidence after process exit,
  but can no longer activate the early live-process report latch;
- every new append-only row records its validated predecessor lineage;
- Q07 can reuse predecessor seeds across GUID roots and terminals only when the current
  EX5 and MQ5 hashes match, the run identity matches, the report is valid, and both the
  HARSH setfile label and effective report seed agree;
- invalid seed 2026 is rejected, so the recovery should run only that missing seed.

No entry rule, threshold, lookback, hedge ratio, sizing rule, or gate criterion changed.

## Enqueue binding

The canonical append-only command cited exact Q06 predecessor
`d13cf596-44a4-429d-92a7-2de6b1a3e7f0`, exact failed Q07 target
`b38e2753-1d57-45d9-8562-3cafc0e105a0`, and current EX5 SHA-256
`d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b`.

The new row binds both predecessor report roots plus:

- MQ5 SHA-256: `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129`
- setfile SHA-256: `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254`
- host/timeframe: `EURUSD.DWX`, D1
- full-history start: `2018.07.02`
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- existing `priority_track=true`

Fresh CPU preflight was below the hard stop: samples
`[53, 44, 30, 32, 40]%`, average `39.8%`, maximum `53%`. D: had `88.68 GB` free.

## Verification

- `python -m py_compile framework/scripts/q07_multiseed.py tools/strategy_farm/farmctl.py` — PASS
- `pwsh -NoProfile -File framework/scripts/tests/Test-RunSmokeWaitForCompleteReport.ps1` — PASS
- `pwsh -NoProfile -File framework/scripts/tests/Test-RunSmokeWaitsForChildTerminal.ps1` — PASS
- `pwsh -NoProfile -File framework/scripts/tests/Test-RunSmokeTerminalRunningGuard.ps1` — PASS
- `python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py tools/strategy_farm/tests/test_farmctl_cascade.py -q` — 88 passed, 6 subtests passed
- Q07 scratch/outlier focused tests — 2 passed
- real-root read-only recovery — seeds `[7, 17, 42, 99]`; seed 2026 rejected

Machine-readable receipt:
`artifacts/qm5_20224_q07_lineage_recovery_enqueue_20260831T135143Z.json`.

## Safety

No T_Live file/process, AutoTrading setting, portfolio admission/KPI/Q08-contribution
gate, T_Live manifest, or deploy manifest was touched. Historical work-item verdicts and
raw evidence remain unchanged.
