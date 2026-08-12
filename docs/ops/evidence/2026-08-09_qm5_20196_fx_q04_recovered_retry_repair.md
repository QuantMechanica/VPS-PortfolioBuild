# QM5_20196 FX Q04 Recovered-Retry Repair

Date: 2026-08-09 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: advance one existing low-frequency structural FX basket after confirming
that the frozen 66-pair scan has no unbuilt relationship. No live, portfolio,
or manual tester action was performed.

## Outcome

`QM5_20196_eurusd-jpy-coint` (EURUSD/USDJPY D1) now has one append-only Q04
rerun pending:

- logical symbol: `QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1`;
- Q02 PASS predecessor: `a34c39c1-7ef6-43e2-b1b4-eb6a717271b2`;
- preserved Q04 INFRA_FAIL row: `e2dde9f5-0ec1-488c-af5c-e6a64dce6710`;
- new Q04 work item: `6d420834-e8d0-481e-ae3d-806bddb17ec4`;
- enqueue state at verification: `pending`, unclaimed, attempt 0; and
- event ledger row: `342365` (`cascade_backtest_enqueued`).

The prior Q04 evidence remains immutable. The supported append-only path
created exactly one row, skipped zero rows, and requeued zero rows.

## Frontier And Anchor Guard

The current frozen-frontier reconciliation in
`docs/research/FX_COINTEGRATION_FRONTIER_Q02_CPU_CEILING_STOP_2026-08-07.md`
records all 66 scan relationships as mechanized. A new Card or build would be
duplicate work.

Direct canonical-farm reads also confirmed that neither requested anchor is
blocked at Q02:

- `QM5_12532` has logical-basket Q02 PASS, Q04 PASS, then Q05 FAIL; and
- `QM5_12533` has logical-basket Q02 PASS, then terminal Q04 FAIL.

The fallback therefore advances the already-approved rank-13
EURUSD/USDJPY fixed-pair sleeve rather than duplicating a pair.

## Defect And Repair

The preserved Q04 aggregate classified all three folds as infrastructure
invalid because each `run_smoke` summary retained an initial cold-cache
`BARS_ZERO` attempt. Each summary also contained a later valid `status=OK`
native report:

| Fold | Valid recovered report | Prior incorrect fold class |
|---|---:|---|
| F1 / 2023 | 0 trades | `invalid_summary:BARS_ZERO,RUN_STATUS_INVALID` |
| F2 / 2024 | 0 trades | `invalid_summary:BARS_ZERO,RUN_STATUS_INVALID` |
| F3 / 2025 | 2 trades, PF 0.46 | `invalid_summary:BARS_ZERO,RUN_STATUS_INVALID` |

`framework/scripts/q04_walkforward.py` now treats the authoritative top-level
reason classes and completed `OK` run as the fold result after a successful
cold-cache recovery. Stale markers from earlier invalid attempts no longer
override the recovered report. Genuine top-level infrastructure classes such
as `ONINIT_FAILED`, `NO_HISTORY`, or `ACCOUNT_NOT_SPECIFIED` remain invalid.

This is a taxonomy/evidence repair only. It does not alter entries, exits,
sizing, beta, risk, thresholds, or gate floors. The observed 0/0/2-trade
profile is expected to receive an honest terminal economic/frequency verdict
on rerun; no pass is claimed.

A regression test reproduces the exact failure shape: top-level
`MIN_TRADES_NOT_MET`, one stale invalid `BARS_ZERO` attempt, and one completed
`OK` report.

## Source, Structure, And Risk Contract

The approved Card cites the OWNER-ratified Tier-A extraction of Ernest P.
Chan, *Quantitative Trading* (Wiley, 2009), plus the frozen Darwinex D1
66-pair scan. The sleeve is fixed-symbol, fixed-beta, closed-D1 residual
reversion with no learned model, online refit, grid, martingale, pyramiding,
or banned indicator.

The canonical logical setfile remains backtest-only fixed risk:

- `RISK_FIXED=1000`;
- `RISK_PERCENT=0`; and
- `PORTFOLIO_WEIGHT=1`.

The basket manifest retains `EURUSD.DWX` as host and `USDJPY.DWX` as the
second traded leg.

| Artifact | SHA256 |
|---|---|
| Approved Card | `d6f42538b40a717a02f923d380cb863cf9783c1a471e23118ff165ba14aa51fd` |
| MQ5 | `8de25f66c15be8e2fdd1791d5d22acff6dab2162ea96860dfb7c5d51d70815dd` |
| EX5 | `b8b268676f8cd3e8312e1e30ea71abf65efc2e8970eb618c75db281ae7947bb2` |
| Basket manifest | `5b36889e87a44fa2a2961d2cfda9696fd1531e487af9be3325a05d81da114a64` |
| Logical backtest setfile | `9489a6642c19f33b0834d1e92303dfafbe261f47c74e0e566d200b816a5414df` |

## Verification

```text
python -m unittest framework.scripts.tests.test_q04_walkforward
Ran 24 tests: OK

powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 \
  -EALabel QM5_20196_eurusd-jpy-coint -SkipCompile
PASS: 0 failures, 0 warnings
report: D:\QM\reports\framework\21\build_check_20260809_122154.json
```

The repaired classifier returned `None` (no infrastructure invalidation) for
each of the three preserved source summaries.

## Enqueue And Capacity

The immediate pre-enqueue path-aware sample at
`2026-08-09T12:22:23Z` found zero running factory MT5 terminals, below the
seven-terminal paced-fleet ceiling. `T_Live` and the unrelated FTMO terminal
were observed only as excluded processes and were not controlled.

The append-only command bound the exact Q02 predecessor, prior Q04 row, and
current EX5 hash:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm `
  enqueue-backtest --ea QM5_20196 --phase Q04 `
  --from-work-item-id a34c39c1-7ef6-43e2-b1b4-eb6a717271b2 `
  --append-only-rerun-of e2dde9f5-0ec1-488c-af5c-e6a64dce6710 `
  --rerun-reason "Q04 grader now ignores recovered cold-cache BARS_ZERO attempts after a valid completed report; preserve prior INFRA_FAIL evidence and rerun for terminal economic classification." `
  --expected-current-ex5-sha256 b8b268676f8cd3e8312e1e30ea71abf65efc2e8970eb618c75db281ae7947bb2
```

Normal paced workers own dispatch and execution. No pump tick or tester was
launched manually.

## Safety

- No `portfolio_admission`, portfolio KPI, or Q08-contribution path changed.
- No `T_Live` manifest, terminal, live setfile, or AutoTrading state changed.
- No Strategy Card, EA source/binary, registry, magic row, setfile, or basket
  manifest changed.
- Existing unrelated dirty-worktree files were left untouched.

Machine-readable evidence:
`artifacts/qm5_20196_fx_q04_recovered_retry_repair_20260809.json`.
