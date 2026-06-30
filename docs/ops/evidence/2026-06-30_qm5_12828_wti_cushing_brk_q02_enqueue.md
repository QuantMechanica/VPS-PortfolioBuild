# QM5_12828 WTI Cushing Breakout Build And Q02 Enqueue

Date: 2026-06-30
Branch: `agents/board-advisor`

## Edge Selected

Built `QM5_12828_wti-cushing-brk`: a low-frequency structural crude-oil sleeve
on `XTIUSD.DWX` using a D1 price-only Cushing delivery-hub tightness breakout
proxy.

Source lineage is `EIA-CUSHING-STORAGE-2021`, the U.S. Energy Information
Administration Today in Energy article "Crude oil inventories at Cushing,
Oklahoma, remain low after summer draws" (2021-10-21). Runtime data is limited
to Darwinex MT5 D1 OHLC, broker calendar, spread, SMA, and ATR; the EA does not
read EIA inventory data, APIs, CSVs, futures curves, refinery data, storage
data, or external macro feeds.

## Duplicate Review

- XAU/XAG ratio reversion is already built as `QM5_12577`; XAU/XAG breakout is
  already built as `QM5_12724`.
- Existing WTI calendar/product/event families cover seasonality, driving
  season, distillate, RBOB, jet fuel, WPSR, OPEC, refinery, hurricane, SPR,
  expiry, roll, weekday/month premiums, USD/CAD confirmation, oil-metal ratios,
  and XTI/XNG baskets.
- Existing WTI momentum families include 52-week anchor, 9/12-month TSMOM,
  pullbacks, volatility contraction, and generic reversal. This build is
  long-only, weekly gated, and uses a shorter Cushing delivery-hub tightness
  breakout proxy with no event/feed/calendar/basket component.
- `QM5_12567_cum-rsi2-commodity` is RSI/pullback commodity logic; this EA uses
  no RSI or short-horizon oscillator pullback.

## Artifacts

- Source: `strategy-seeds/sources/EIA-CUSHING-STORAGE-2021/source.md`
- Card: `strategy-seeds/cards/approved/QM5_12828_wti-cushing-brk_card.md`
- EA: `framework/EAs/QM5_12828_wti-cushing-brk/QM5_12828_wti-cushing-brk.mq5`
- EX5: `framework/EAs/QM5_12828_wti-cushing-brk/QM5_12828_wti-cushing-brk.ex5`
- SPEC: `framework/EAs/QM5_12828_wti-cushing-brk/SPEC.md`
- Setfile: `framework/EAs/QM5_12828_wti-cushing-brk/sets/QM5_12828_wti-cushing-brk_XTIUSD.DWX_D1_backtest.set`
- Registry rows:
  - `framework/registry/ea_id_registry.csv`: `12828,wti-cushing-brk,...`
  - `framework/registry/magic_numbers.csv`: slot 0 `XTIUSD.DWX`, magic `128280000`

## Validation

- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\approved\QM5_12828_wti-cushing-brk_card.md`
  - PASS: status ok, no ML hits, no missing sections.
- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_12828_wti-cushing-brk`
  - PASS: 1 PASS, 0 FAIL.
- `python tools\strategy_farm\validate_symbol_scope.py --ea-label QM5_12828_wti-cushing-brk --verbose --fail-on-leak`
  - PASS: `SINGLE_SYMBOL_OK`, `n_violations=0`.
- `python framework\scripts\validate_registries.py`
  - FAIL on pre-existing global registry drift unrelated to `QM5_12828`.
  - Targeted rows verified:
    - `ea_id_registry`: `12828,wti-cushing-brk,EIA-CUSHING-STORAGE-2021,active,Development,2026-06-30`
    - `magic_numbers`: `12828,wti-cushing-brk,0,XTIUSD.DWX,128280000,2026-06-30,Development,active`
- `powershell -ExecutionPolicy Bypass -File framework\scripts\compile_one.ps1 -EALabel QM5_12828_wti-cushing-brk -Strict`
  - PASS: 0 errors, 0 warnings, `.ex5` produced.
  - Compile log: `C:\QM\repo\framework\build\compile\20260630_145622\QM5_12828_wti-cushing-brk.compile.log`
- `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_12828_wti-cushing-brk -Strict -SkipCompile`
  - PASS: 0 failures.
  - Warnings: 16 shared-framework lazy-indicator advisories under `framework/include/QM/`, matching recent builds.
  - Build check report: `D:\QM\reports\framework\21\build_check_20260630_145646.json`

## Q02 Enqueue

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_12828 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Work item: `fe9c6868-4fc0-44a0-a9a4-4a9abb9d7379`
- Farm DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Phase: `Q02`
- EA: `QM5_12828`
- Symbol: `XTIUSD.DWX`
- Status: `pending`
- Created: `2026-06-30T14:57:43+00:00`
- Setfile: `C:\QM\repo\framework\EAs\QM5_12828_wti-cushing-brk\sets\QM5_12828_wti-cushing-brk_XTIUSD.DWX_D1_backtest.set`

No backtest was run in this build turn.

## Live Scope

No `T_Live` manifest, AutoTrading setting, deploy manifest, or portfolio gate
file was touched.
