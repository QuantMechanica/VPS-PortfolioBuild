# QM5_11907 Diverse-FX Magic Repair — CPU-Ceiling Stop

## Outcome

`QM5_11907_davey-momentum-big-range-h1` was claimed as a distinct Q02
infrastructure repair, given ten missing FX magic registrations, rebuilt against
the current V5 framework, and brought to strict build/compile PASS. Q02 was not
re-enqueued because the single bounded smoke invocation exceeded the 10-minute
runtime ceiling after colliding with a worker-owned terminal slot.

## Why This EA

- The pending diverse build cards were not faithfully runnable: their required
  lumber, Treasury-yield, or bond series are not approved DWX inputs.
- This EA diversifies the current index/metal/energy survivor concentration with
  ten FX pairs.
- The source is Kevin J. Davey's *My 5 Favorite Entries*, Entry #1 “Momentum and
  Big Range”; the approved card records all R1–R4 gates as PASS.
- The farm had no active/pending/claimed row, downstream Q04+ evidence, or other
  agent repair claim for the EA when work item
  `e0911bc9-6e0b-48bb-8e95-212de2de4204` was claimed.

## Diagnosis And Repair

The farm retained 120 Q02 rows for the ten FX symbols. None had a strategy
verdict; retained failure classes included `ONINIT_FAILED`, `NO_HISTORY`, and
`summary_missing_retries_exhausted`.

The hard initialization defect was deterministic: `ea_id_registry.csv` contained
EA 11907, but `magic_numbers.csv` contained no EA 11907 row. All ten old setfiles
also selected slot 0. The repair added collision-free magic values 119070000–
119070009, regenerated `QM_MagicResolver.mqh`, and regenerated all ten H1
backtest setfiles with slots 0–9, `RISK_FIXED=1000`, and `RISK_PERCENT=0`.

The EA was also brought through current build-corset checks: bounded raw-range
reads are explicitly annotated, the entry request is zero-initialized, the
one-position gate is magic-scoped, and the news blackout gates entries below
position management and hard exits. The previously missing `SPEC.md` now passes
the Q01 validator.

| Check | Result |
|---|---|
| SPEC validation | PASS |
| Strict build check | PASS, 0 failures, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260710_112324.json` |
| Strict compile | PASS, 0 errors, 0 warnings |
| Compile log | `C:/QM/repo/framework/build/compile/20260710_112344/QM5_11907_davey-momentum-big-range-h1.compile.log` |
| Repair commits | `93c29e87c146016d1da5460bdd2657cca2dc388c`, `ad071501d8b286466d75be1ebff8aefcea205046` |
| MQ5 SHA256 | `665060DB8FEE0407266D43E2965C4845F7047FFD25616D328CF05ADA022338CD` |
| EX5 SHA256 | `D89A56893C884140D87703C8B2FD624FC45D37A15250C5CE64BF334A2EFBF3DA` |

## Runtime Ceiling

The one permitted smoke invocation used `-Terminal any`, EURUSD.DWX, H1, 2024,
Model 4, `-MinTrades 1`, and `-SmokeMode`. It did not yield a valid EA summary.
The selected T3 slot was concurrently taken by a farm worker: retained `run_01`
evidence begins with `QM5_9403_williams-pro-go-h4`, contains no `QM5_11907`
marker, and two terminal logs grew to roughly 230 MB. Three incomplete run
directories were created before the command stopped at 654 seconds.

No orphaned terminal process remained afterward. Per the requested CPU-ceiling
stop and the one-pass smoke rule, no retry and no Q02 enqueue were performed.

## Safety Boundary

No `T_Live` file, AutoTrading state, portfolio gate, or live manifest was
touched.

Machine-readable evidence:
`artifacts/qm5_11907_fx_magic_repair_cpu_ceiling_stop_20260710.json`.
