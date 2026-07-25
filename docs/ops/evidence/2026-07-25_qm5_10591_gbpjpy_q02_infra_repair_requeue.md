# QM5_10591 GBPJPY Q02 infrastructure repair and requeue

- Mission unit: diversity-first Q02 infrastructure recovery
- Claimed EA/symbol: `QM5_10591_mql5-ozym` / `GBPJPY.DWX`
- Source work item: `91177dc1-d014-4ba4-8c98-490fd0f329f5`
- Source verdict: `INFRA_FAIL`
- Source reason: `ACTIVE_TIMEOUT` (`storm_kill_infra_fail_false_negative`)
- Farm claim task: `a99ddac4-8905-4ca4-bd37-a7c6ee3ab6c0`

## Diagnosis

The latest GBPJPY Q02 attempt was terminated by the fleet timeout rather than a
strategy verdict. The retained build was also stale against the current framework:
the strict build gate rejected six direct raw-series calls, and the canonical setfile
still carried `build_hash=pending`, omitted `qm_ea_id`, and omitted all strategy input
defaults.

## Repair

- Replaced direct `iHigh`, `iLow`, `iClose`, and `Bars` usage with the framework
  `QM_ReadBar` reader and fail-closed warmup reads.
- Recompiled the EA against the current V5 includes.
- Regenerated the GBPJPY H4 backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `qm_ea_id=10591`, strategy defaults, and a real build hash.
- Refreshed registered sibling setfile build hashes through the strict build check.

## Verification

- Compile: `PASS`, 0 errors, 0 warnings
- Compile log:
  `C:\QM\repo\framework\build\compile\20260725_160349\QM5_10591_mql5-ozym.compile.log`
- Compile summary:
  `D:\QM\reports\compile\20260725_160349\summary.csv`
- Strict build check: `PASS`, 0 failures, 0 warnings
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260725_160349.json`
- Runtime backtest: deliberately not launched; paced-fleet Q02 handoff only.

## Safety

No T_Live files or processes, AutoTrading state, portfolio gate, deploy manifest, or
live configuration were read or changed.
