# QM5_12777 WTI December Fade Q02 Enqueue

Date: 2026-06-29

## Scope

- Built `QM5_12777_wti-dec-fade`, a structural low-frequency `XTIUSD.DWX` D1
  December calendar-fade sleeve.
- Source lineage: Quayyum, Khan and Ali, "Seasonality in crude oil returns",
  Soft Computing 24, 7857-7873 (2020), DOI
  https://doi.org/10.1007/s00500-019-04329-0.
- Runtime logic: short only on broker-calendar December D1 bars, ATR hard stop,
  next-D1/month-end/time exits.
- Backtest setfile risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Files

- EA: `framework/EAs/QM5_12777_wti-dec-fade/QM5_12777_wti-dec-fade.mq5`
- Binary: `framework/EAs/QM5_12777_wti-dec-fade/QM5_12777_wti-dec-fade.ex5`
- Setfile:
  `framework/EAs/QM5_12777_wti-dec-fade/sets/QM5_12777_wti-dec-fade_XTIUSD.DWX_D1_backtest.set`
- Approved card:
  `strategy-seeds/cards/approved/QM5_12777_wti-dec-fade_card.md`
- Build result: `artifacts/qm5_12777_build_result.json`

## Validation

- `python framework/scripts/update_magic_resolver.py`: PASS, resolver updated.
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12777_wti-dec-fade`:
  PASS.
- `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12777_wti-dec-fade_card.md`:
  PASS.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12777_wti-dec-fade/QM5_12777_wti-dec-fade.mq5 -Strict`:
  PASS, 0 errors, 0 warnings.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12777_wti-dec-fade -RepoRoot C:/QM/repo -SkipCompile`:
  PASS, 0 failures, 16 shared-framework DWX advisory warnings.
- `python framework/scripts/validate_registries.py --json`: FAIL from legacy
  registry issues already present in the tree. Targeted check verified
  `ea_id_registry.csv` line 3653 and `magic_numbers.csv` line 13839; no global
  issue contained `wti-dec-fade` or `127770000`.

## Hashes

- MQ5 SHA256:
  `fa88162565ad98f134a7e56685301a2c42e3abed26d5aa41aa31f13f95c53253`
- EX5 SHA256:
  `fb966b35a4ffd93ac280430918b6519f85433a256d2cb1cd8f47229482710204`
- Setfile current SHA256:
  `d7899d0fb31f07d77bb5ff1cc44764d327a868a72697e5b5370dce0c29e5d1e2`
- Setfile header `build_hash`:
  `db55d12fbfd22ed3bebe8193c2b2f6f6717f4c6fb30fa0629481b4be1f670d85`

## Q02 Queue

- Enqueue command:
  `python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_12777 --queue-ceiling 10000 --max-part2-per-run 0`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Work item: `171bf5f6-c737-4a88-bdbb-0e1d9ef14d61`
- Phase: `Q02`
- Kind: `backtest`
- Symbol: `XTIUSD.DWX`
- Status after final check: `pending`
- Created/updated: `2026-06-29T13:08:11+00:00`

## Safety

- No `T_Live` manifest touched.
- No AutoTrading toggle or live terminal action.
- No portfolio gate, portfolio admission, portfolio KPI, or Q08 contribution
  artifact touched.
- No manual MT5 backtest was launched; paced fleet Q02 owns execution.
