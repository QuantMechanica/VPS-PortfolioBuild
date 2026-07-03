# QM5_9278 mql5-lw-outside Build And Q02 Enqueue

Date: 2026-07-03
Branch: `agents/board-advisor`
Task: `0c2d5b21-6df9-4859-9931-597f09b82c2a`

## Scope

Built `QM5_9278_mql5-lw-outside` from the approved D1 Larry Williams bearish outside-bar reversal card.

Registered portable symbols:

- `EURUSD.DWX` slot 0 magic `92780000`
- `GBPUSD.DWX` slot 1 magic `92780001`
- `XAUUSD.DWX` slot 2 magic `92780002`
- `GDAXI.DWX` slot 3 magic `92780003`

Card symbol `GER40.DWX` is absent from `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX DWX port used for the build.

## Verification

- `python framework/scripts/update_magic_resolver.py` -> PASS
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_9278_mql5-lw-outside` -> PASS
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_9278_mql5-lw-outside --fail-on-leak` -> PASS
- `pwsh -NoProfile -File framework/scripts/compile_one.ps1 -EALabel QM5_9278_mql5-lw-outside -Strict` -> PASS, 0 errors, 0 warnings
- `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_9278_mql5-lw-outside` -> PASS, failures 0

Smoke was deferred to Q02 to avoid consuming backtest CPU in the build turn.

## Farm Result

Build result:

- `artifacts/qm5_9278_build_result.json`
- `D:\QM\strategy_farm\artifacts\builds\0c2d5b21-6df9-4859-9931-597f09b82c2a.json`

`farmctl record-build` returned `recorded=true`, `new_status=done`, `smoke_result=deferred_p2_smoke`.

Q02 staged work items:

- `5a31a2c3` `EURUSD.DWX` D1
- `878dc145` `GDAXI.DWX` D1
- `1ef81ecd` `XAUUSD.DWX` D1

Deferred by farm stage-1 diversity rule:

- `GBPUSD.DWX` D1
