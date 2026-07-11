# QM5_9930 FX daily-open breakout — Q01 recovery and Q02 enqueue

Date: 2026-07-11
Branch: `agents/board-advisor`
Farm build task: `1366fa6a-1a20-4f28-9999-f6d83ecc7793`

## Outcome

Recovered the already-approved, already-registered `QM5_9930_ff-hline-do-breakout-m30`
build from its terminal Q01 compile failure and placed a staged Q02 wave into the farm.
This is a structural daily-open breakout on a diverse FX basket, not a new indicator or
ML strategy.

The previous build result failed on MQL5's illegal C/C++ `(void)broker_time` cast. The
repair removes that construct, keeps news gating on the entry path only so management
and exits remain live during blackout windows, and zero-initializes `QM_EntryRequest`.
No strategy parameter, entry threshold, stop, target, or symbol allocation changed.

## Registry preflight

The required allocations were already active in the committed registries:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `GBPUSD.DWX` | 99300000 |
| 1 | `EURUSD.DWX` | 99300001 |
| 2 | `USDJPY.DWX` | 99300002 |
| 3 | `XAUUSD.DWX` | 99300003 |

No registry or framework include was changed in this unit.

## Build evidence

- SPEC validation: `PASS`
- Build check: `PASS`, 0 failures, 0 warnings
- Build-check report: `D:\QM\reports\framework\21\build_check_20260711_025320.json`
- Compile summary: `D:\QM\reports\compile\20260711_025320\summary.csv`
- `.ex5` SHA256: `C924A17BB834A7EE94207B6306DBAE72225909B38F51F2AE3D163DC82B2211CE`
- Backtest setfiles: four M30 `environment=backtest`, `risk_mode=FIXED`,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, with registry-matched magic slots.

## Smoke evidence

The factory had no active T1-T10 run and reported 0% host load before dispatch. The
single `run_smoke.ps1` invocation used `-Terminal any -SmokeMode`; the dispatcher chose
factory terminal T6. T_Live was not accessed.

- Result: `PASS`
- Model: 4 (Every Real Tick)
- Symbol / period / year: `GBPUSD.DWX` / M30 / 2024
- Deterministic: yes; both harness runs produced 370 trades, PF 0.96, net -9582.34,
  drawdown 24.48%
- OnInit failure: false
- Log bomb: false
- Summary: `D:\QM\reports\smoke\QM5_9930\20260711_025402\summary.json`
- Report evidence: `D:\QM\reports\framework\22\20260711_025402_QM5_9930_T6_GBPUSD_DWX_run_smoke.md`

The smoke is a build/runtime gate, not a profitability verdict. Its 370 trades exceed
the card estimate of 130; Q02 must judge full-history frequency and cost economics with
the approved parameters unchanged.

## Farm state after `record-build`

The build task is `done`, SPEC validation is clean, and these Q02 work items are pending
with attempt count 0 and no claimant:

| Work item | Symbol | State |
|---|---|---|
| `2b5d7932-15b3-4893-9a04-0dd69b8dd39e` | `GBPUSD.DWX` | pending |
| `f3e5567a-4cad-4e9b-a290-08d9a8dd53e7` | `EURUSD.DWX` | pending |
| `131413cf-2bd2-45da-bf23-c378a0b7c5dd` | `XAUUSD.DWX` | pending |

`USDJPY.DWX` remains preserved in
`D:\QM\strategy_farm\state\q02_deferred_symbols.json` for the normal staged-promotion
sweep; it was not dropped.

No Q02 run was manually dispatched, and no T_Live manifest or portfolio gate was
touched.
