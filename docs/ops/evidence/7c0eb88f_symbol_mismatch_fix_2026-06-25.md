# Basket EA Symbol-Ticker Mismatch Fix

Task: `7c0eb88f-0a65-4f00-b8c6-0edffac4c6b7`

Date: 2026-06-25

## Scope

Patched the requested basket/index EA symbol mismatch in `C:/QM/repo`.

- Replaced unavailable DAX alias `GER40.DWX` with imported custom symbol `GDAXI.DWX`.
- Removed unavailable basket members `FRA40.DWX`, `AUS200.DWX`, and `XCUUSD.DWX` from affected symbol arrays.
- Removed matching unavailable-symbol `.set` files so Q02 fanout cannot select them.
- Updated `framework/registry/magic_numbers.csv`:
  - active DAX rows now use `GDAXI.DWX`;
  - removed symbols are marked `retired`.
- Regenerated `framework/include/QM/QM_MagicResolver.mqh`.

Patched EAs:

`QM5_10209`, `QM5_1075`, `QM5_1112`, `QM5_1113`, `QM5_1179`, `QM5_1181`, `QM5_1182`, `QM5_1186`, `QM5_1187`, `QM5_1207`, `QM5_1209`, `QM5_1210`, `QM5_1211`, `QM5_1212`, `QM5_1214`, `QM5_1215`, `QM5_1217`, `QM5_1218`, `QM5_1220`, `QM5_1221`, `QM5_1231`, `QM5_1232`, `QM5_1253`.

## Verification

Available custom-symbol check:

- `D:/QM/mt5/T1` contains `GDAXI.DWX`.
- `D:/QM/mt5/T1` does not contain `GER40.DWX`, `FRA40.DWX`, `AUS200.DWX`, or `XCUUSD.DWX`.

Scoped bad-symbol grep:

- `rg "GER40\.DWX|FRA40\.DWX|XCUUSD\.DWX|AUS200\.DWX"` across patched EA directories: no matches.

Build guardrails:

- `python tools/strategy_farm/validate_build_guardrails.py <23 patched EA dirs>`: `PASS`.
- Findings: none.
- `qm_news_stale_max_hours` remained at or below `336`.
- Backtest sets remain `RISK_FIXED > 0` and `RISK_PERCENT = 0`.

Magic resolver:

- `python framework/scripts/update_magic_resolver.py`: PASS.
- Rows: `13273`.
- CSV SHA prefix: `D7369D4690199127`.

Compile:

- `python tools/strategy_farm/compile_ea.py --ea-label <label> --force --json --fail-on-error`
- Result: 23/23 `COMPILED`, 0 errors, 0 warnings.

## Queue State

Active farm DB checked:

- `D:/QM/strategy_farm/state/farm_state.sqlite`
- For all patched EA IDs, `tasks` rows for `ea_review` / `backtest_p2` / `backtest_q02`: `0`.
- For all patched EA IDs, `work_items`: `0`.

Direct Q02 enqueue by EA label was attempted for `QM5_1209`:

```text
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_1209 --phase Q02
=> enqueued=false, reason="Phase Q02 is not a cascade phase..."
```

Therefore there were no existing Q02 rows to reset to pending and no review predecessor row for `enqueue-backtest --review-task-id`. I did not manufacture untracked DB rows.

## Recommendation

Add a dispatch/card symbol-alias map for index aliases (`GER40 -> GDAXI`) and a pre-enqueue availability guard for card-declared symbols. That prevents future cards or generated setfiles from reintroducing unavailable custom-symbol names.
