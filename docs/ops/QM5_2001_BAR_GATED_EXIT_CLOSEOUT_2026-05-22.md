# QM5_2001 Bar-Gated Exit Closeout - 2026-05-22

Task: `fef5e390-3c0f-4110-8b37-64814f269f77`

## Verdict

`QM5_2001_BAR_GATED_EXIT_BUILD_DEPLOY_PASS`

`QM5_2001_nnfx-classic-ssl` is rebuilt and deployed to factory terminals `T1..T10` with matching SHA256. The checked-out source already had the requested bar gate in place when this cycle inspected it, so no source rewrite was needed in this pass.

## Source Check

EA source:

`framework/EAs/QM5_2001_nnfx-classic-ssl/QM5_2001_nnfx-classic-ssl.mq5`

Relevant flow:

- `Strategy_ExitSignal()` definition starts at line 132.
- `OnTick()` calls `QM_IsNewBar()` at line 171.
- `Strategy_ManageOpenPosition()` runs after the new-bar gate at line 173.
- `Strategy_ExitSignal()` runs after the new-bar gate at line 175.
- `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` runs only inside that gated path at line 183.

This satisfies the requested fix class: position iteration and indicator checks inside `Strategy_ExitSignal()` are evaluated once per closed bar, not on every tick.

## Verification

Build check:

```text
pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_2001_nnfx-classic-ssl
build_check.result=PASS
build_check.failures=0
build_check.warnings=0
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.ex5=C:\QM\repo\framework\EAs\QM5_2001_nnfx-classic-ssl\QM5_2001_nnfx-classic-ssl.ex5
build_check.report=D:\QM\reports\framework\21\build_check_20260522_064617.json
```

Deployment:

```text
pwsh -NoProfile -File framework/scripts/deploy_ea_to_all_terminals.ps1 -EaPath C:\QM\repo\framework\EAs\QM5_2001_nnfx-classic-ssl\QM5_2001_nnfx-classic-ssl.ex5 -EvidenceJsonPath C:\QM\repo\docs\ops\QM5_2001_DEPLOY_T1_T10_2026-05-22.json
```

Deployment evidence:

- `docs/ops/QM5_2001_DEPLOY_T1_T10_2026-05-22.json`
- Terminals updated: `T1`, `T2`, `T3`, `T4`, `T5`, `T6`, `T7`, `T8`, `T9`, `T10`
- SHA256 on all terminals: `DEFA21C6A72F5FADA34F4ED10AC429F6C218722B44671143223BD0D8E185611A`

Strict deployment verification:

```text
python framework/scripts/verify_build_deployment.py --json --ea-id 2001 --ea-dir-glob QM5_2001_*
verdict=PASS
ea_dir_exists=true
ex5_present=true
size_ok=true
all_terminals_deployed=true
all_sha_match=true
setfiles_present=true
setfile_count=37
```

## Backlog Audit

Static audit command:

```text
for each framework/EAs/QM5_*/*.mq5:
  inspect OnTick()
  flag files where Strategy_ExitSignal appears before QM_IsNewBar, or no QM_IsNewBar appears in the sampled OnTick block
```

Result: `176` candidate EAs still match the broad per-tick exit-call pattern. This is a candidate list, not a verdict that every EA is slow; some exits are cheap or intentionally per-tick. These were not modified in this task.

Representative candidates to triage first because they are active or recent pipeline names:

- `framework/EAs/QM5_10260_cieslak-fomc-cycle-idx/QM5_10260_cieslak-fomc-cycle-idx.mq5`
- `framework/EAs/QM5_1044_vpmacd-us-indices/QM5_1044_vpmacd-us-indices.mq5`
- `framework/EAs/QM5_1045_zarattini-spy-intraday-momentum/QM5_1045_zarattini-spy-intraday-momentum.mq5`
- `framework/EAs/QM5_1046_maroy-intraday-vwap-exit/QM5_1046_maroy-intraday-vwap-exit.mq5`
- `framework/EAs/QM5_1056_moskowitz-tsmom-multiasset/QM5_1056_moskowitz-tsmom-multiasset.mq5`
- `framework/EAs/QM5_1081_chan-lo-1d-reversal/QM5_1081_chan-lo-1d-reversal.mq5`
- `framework/EAs/QM5_1082_chan-intraday-reversal/QM5_1082_chan-intraday-reversal.mq5`
- `framework/EAs/QM5_1084_chan-xle-basket-z2/QM5_1084_chan-xle-basket-z2.mq5`
- `framework/EAs/QM5_1086_aa-dpm-tmom-ma/QM5_1086_aa-dpm-tmom-ma.mq5`
- `framework/EAs/QM5_2010_nnfx-v2-h4-bias-h1-pullback/QM5_2010_nnfx-v2-h4-bias-h1-pullback.mq5`
- `framework/EAs/QM5_2011_nnfx-v2-h4-bias-h1-breakout/QM5_2011_nnfx-v2-h4-bias-h1-breakout.mq5`
- `framework/EAs/QM5_2013_nnfx-v2-carry-momentum-filter/QM5_2013_nnfx-v2-carry-momentum-filter.mq5`
- `framework/EAs/QM5_2014_nnfx-v2-range-filter-meanrev/QM5_2014_nnfx-v2-range-filter-meanrev.mq5`

## Limits

No Q02 backtest was manually launched from this scheduled orchestration cycle. That is deliberate: the cycle must not start `terminal64.exe` manually or interrupt active `T1..T10` worker backtests. Pipeline completion and P2 verdicts must come from the pipeline evidence after the deployed build is picked up by the queue.
