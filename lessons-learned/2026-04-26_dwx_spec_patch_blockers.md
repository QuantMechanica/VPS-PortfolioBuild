# 2026-04-26 - DWX spec patch v2 execution blockers (QUA-15)

Issue link: `QUA-15` (`a961b6a7-2645-4f8f-b7e8-725678ddc13e`)

## What was done

- Added `Fix_DWX_Spec_v2.mq5` at:
  - `D:\QM\mt5\T1\MQL5\Scripts\Fix_DWX_Spec_v2.mq5`
- Compiled with MetaEditor CLI:
  - `D:\QM\mt5\T1\MetaEditor64.exe /compile:D:\QM\mt5\T1\MQL5\Scripts\Fix_DWX_Spec_v2.mq5`
  - Compile log: `D:\QM\mt5\T1\MQL5\Scripts\Fix_DWX_Spec_v2.compile.log`
- Executed non-interactively via MT5 startup config:
  - `D:\QM\mt5\T1\run_fix_dwx_spec_v2.ini`
  - `D:\QM\mt5\T1\terminal64.exe /portable /config:D:\QM\mt5\T1\run_fix_dwx_spec_v2.ini`
- Verified launch in terminal log:
  - `D:\QM\mt5\T1\logs\20260426.log`
  - entries around `21:02:35-21:02:39` show startup config, script load, script removal, terminal shutdown/restart.

## Key findings

1. Terminal only recognized 15 `.DWX` custom symbols as present in symbol registry at run time.
2. Remaining expected symbols reported `custom_symbol_missing_or_not_custom`.
3. For the 15 present symbols, broker `tick_value/tvp/tvl` were all `0.0` during the run window, and script reported `source_tick_values_zero`.
4. Because broker source values were zero, acceptance criterion "all 36 non-zero and matching" could not be proven in this heartbeat.

## Why this matters

- `Fix_DWX_Spec_v2` is executable and idempotent, but final validation is blocked by terminal state/data state, not script launch mechanics.
- Running this check on a closed/zero-quote state will produce false readiness.

## Unblock actions

1. Ensure all 36 `.DWX` symbols are registered/visible as custom symbols in T1 runtime state before rerun.
2. Rerun verification in a session where broker source `tick_value/tvp/tvl` are non-zero.
3. Re-check `ROW|...|spec_ok=OK` for all 36 symbols and only then move `QUA-15` to `in_review`.
