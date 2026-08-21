# QM5_11657 diversity build - CPU-deferred Q01 smoke

- UTC date: 2026-08-21
- Branch: `agents/board-advisor`
- EA: `QM5_11657_pp-hs-rev`
- Agent task: `0ade55b7-e775-4e01-827d-a7aed7c7bee4`
- Build task: `593a9825-a8dc-462f-bdda-c00ddb710d58`
- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11657_pp-hs-rev.md`
- Outcome: `CPU_DEFERRED_Q01_SMOKE`

## Selection and collision control

The live farm DB and deterministic diversity ranking were checked before any
repository edit. Higher-ranked eligible cards were already held by paced
agents, had failed the standard prebuild contract, or were explicit duplicates.
In particular, `QM5_11640` duplicates `QM5_11621`, and the existing
Connors-family candidate `QM5_11768` was excluded. `QM5_11657` was the
highest-ranked remaining approved, registry-preallocated, unclaimed,
non-duplicate structural card. Its coarse strategy fingerprint occurs once in
the approved-card reservoir.

The standard `farmctl build-ea` preflight created the build task, followed by
an atomic `pending -> active` claim after rechecking that no open agent task
or work item existed for the EA. The pre-claim SQLite backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11657_build_claim_20260821T023421Z.sqlite`

`PRAGMA quick_check` returned `ok`.

The CPU-deferred close was also backed up at
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11657_cpu_defer_close_20260821T024744Z.sqlite`.

The five deterministic magic rows were activated without reallocating identity:

| Card target | DWX host | Slot | Magic |
|---|---|---:|---:|
| EURUSD | `EURUSD.DWX` | 0 | 116570000 |
| GBPUSD | `GBPUSD.DWX` | 1 | 116570001 |
| XAUUSD | `XAUUSD.DWX` | 2 | 116570002 |
| GER40 | `GDAXI.DWX` | 3 | 116570003 |
| NDX | `NDX.DWX` | 4 | 116570004 |

## Mechanical implementation

The prior orphan source was not a mechanical card build. It replaced the cited
detector with a 120-bar five-pivot neckline model, added shoulder and neckline
tolerances, introduced a spread gate and a 2R take-profit, and used a different
entry trigger.

Version 5.1 translates Keith Orange's PatternPy
`detect_head_shoulder` comparisons literally:

- the labelled source row is closed shift 2;
- the source's future `shift(-1)` row is closed shift 1, so the signal is
  delayed one bar and contains no lookahead;
- the three-bar rolling high/low spans shifts 4, 3, and 2;
- `Head and Shoulder` enters short and `Inverse Head and Shoulder` enters
  long at the next bar open;
- inverse-label precedence matches the source's second dataframe assignment;
- exits are the opposite label, 12 completed holding bars, or the ATR(14)
  2.0x broker hard stop;
- no take-profit, neckline inference, swing scan, spread filter, trailing stop,
  break-even, partial close, grid, martingale, or ML remains.

Closed OHLC uses bounded `QM_ReadBar` calls. MAE sampling precedes every
per-tick guard, and both strategy and central news gates suppress entries only,
after position exits have had a chance to run.

## Q01 artifacts and verification

- Approved-card repository copy: byte-identical, SHA-256
  `b67257ab4f4d3a2f19b581b600f3658ed935ae715a260d8bfca24bcd40f63fc7`.
- `skill_build_ea_guard.py`: PASS.
- `validate_spec_doc.py`: PASS, 1/1.
- Full strict `build_check.ps1`: PASS, 0 failures, 0 warnings.
  Report: `D:\QM\reports\framework\21\build_check_20260821_024223.json`.
- Standalone strict `compile_one.ps1`: PASS, 0 errors, 0 warnings.
  Summary: `D:\QM\reports\compile\20260821_024314\summary.csv`.
- MQ5 SHA-256:
  `98dc435b2d739e9604c1135d58c20d9f8296ae1e5395daf3eea359b33ff788f5`.
- EX5 SHA-256:
  `a72cca2214f1d5407e0ddd26ac5e14a31be8ded420b26d7f7a09ab200cb88af9`.
- Canonical deferred build result:
  `D:\QM\strategy_farm\artifacts\builds\593a9825-a8dc-462f-bdda-c00ddb710d58.json`.

All five generated H4 backtest setfiles contain `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, the exact registered slot, and all
four strategy defaults.

| Symbol | Setfile SHA-256 |
|---|---|
| `EURUSD.DWX` | `3e41de13ca9215a010dfc52a13bbc184444f142a8aced0f740b4ebbe5abd242e` |
| `GBPUSD.DWX` | `17577af493106bbf1c12a94f2269266f64ae3c09e93dd68ea5fef1ae7ff2e1a7` |
| `XAUUSD.DWX` | `e01a9d45fa818ba031298901fd4f0cd30f1f565c2a5e3f9de446766b87d44e65` |
| `GDAXI.DWX` | `8ad965cef0af6358a270001538b0fa3d130413715190addcc9e49987f40880d2` |
| `NDX.DWX` | `800112f9c2bfcb589c296594061178e4544e680f6b2dd2661a4146ce6c808538` |

## Capacity stop and handoff

Immediately before the required single smoke, five consecutive total-CPU
samples were `100,100,100,100,100` percent. The farm had seven active work
items and seven running `metatester64` processes. This met the mission's
backtest CPU-ceiling stop condition.

No smoke was launched, no tester terminal was acquired, and no Q02 work item
was enqueued. The farm build claim is closed as CPU-deferred with the compiled
artifacts and canonical build result preserved. A later paced slot may resume
the same task when capacity is available, run exactly one sanctioned smoke,
and record the build for staged Q02 fanout.

## Safety boundary

No `T_Live` file, AutoTrading state, live/deploy manifest, portfolio gate, or
pipeline phase was touched. No local backtest ran.
