# QM5_12833 WTI JPY Confirm Build And Q02 Enqueue

Date: 2026-06-30
Branch: `agents/board-advisor`

## Edge Selected

Built `QM5_12833_wti-jpy-confirm`: a low-frequency structural WTI sleeve on
`XTIUSD.DWX` confirmed by closed-bar `USDJPY.DWX` direction as a Japan
oil-importer FX proxy. The EA trades only `XTIUSD.DWX`; `USDJPY.DWX` is
read-only confirmation.

Source lineage is `EIA-BOJ-WTI-JPY-2026`, using official EIA Japan energy
source material, the Bank of Japan 2026-06-03 policy speech on oil/import-cost
pressure, and the EIA oil/exchange-rate working paper as supplement. Runtime
data is limited to Darwinex MT5 D1 OHLC and broker calendar state; the EA does
not read EIA data, BOJ data, DXY, APIs, CSV files, futures curves, oil-import
data, or external macro feeds.

## Duplicate Review

- XAU/XAG ratio reversion is already built as `QM5_12577`; XAU/XAG breakout is
  already built as `QM5_12724`, so the metals candidate was rejected.
- `QM5_12814` uses `EURUSD.DWX` as a broad USD proxy; this build uses
  `USDJPY.DWX` as an oil-importer yen proxy.
- Existing WTI/CAD builds are `QM5_12607`, `QM5_12609`, and `QM5_12722`; this
  build is not CAD petro-currency logic.
- `QM5_12831` is a two-leg WTI/AUDUSD basket; this build trades only WTI.
- Existing WTI families cover weekday/month seasonality, WPSR, OPEC, refinery,
  hurricane, Cushing, SPR, expiry/roll, driving season, distillate, RBOB, jet
  fuel, TSMOM, reversal, volatility-contraction, and XTI/XNG or oil/metal
  ratios. This build is not an event/calendar or basket sleeve.
- `QM5_12567_cum-rsi2-commodity` is RSI/pullback commodity logic; this EA uses
  no RSI or oscillator pullback.

## Artifacts

- Source: `strategy-seeds/sources/EIA-BOJ-WTI-JPY-2026/source.md`
- Card: `strategy-seeds/cards/approved/QM5_12833_wti-jpy-confirm_card.md`
- EA: `framework/EAs/QM5_12833_wti-jpy-confirm/QM5_12833_wti-jpy-confirm.mq5`
- EX5: `framework/EAs/QM5_12833_wti-jpy-confirm/QM5_12833_wti-jpy-confirm.ex5`
- SPEC: `framework/EAs/QM5_12833_wti-jpy-confirm/SPEC.md`
- Setfile: `framework/EAs/QM5_12833_wti-jpy-confirm/sets/QM5_12833_wti-jpy-confirm_XTIUSD.DWX_D1_backtest.set`
- Build result: `artifacts/qm5_12833_build_result.json`
- Registry rows:
  - `framework/registry/ea_id_registry.csv`: `12833,wti-jpy-confirm,EIA-BOJ-WTI-JPY-2026,active,Development,2026-06-30`
  - `framework/registry/magic_numbers.csv`: slot 0 `XTIUSD.DWX`, magic `128330000`

## Validation

- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\approved\QM5_12833_wti-jpy-confirm_card.md`
  - PASS: status ok, no ML hits, no missing sections.
- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_12833_wti-jpy-confirm`
  - PASS: 1 PASS, 0 FAIL.
- `python tools\strategy_farm\validate_symbol_scope.py --ea-label QM5_12833_wti-jpy-confirm --verbose --fail-on-leak`
  - PASS: `SINGLE_SYMBOL_OK`, `n_violations=0`.
  - Note: `strategy_jpy_proxy_symbol` is read-only and appears as an unresolved variable arg, not as a traded-symbol leak.
- `python framework\scripts\validate_registries.py`
  - FAIL on pre-existing global registry drift unrelated to `QM5_12833`.
  - Targeted rows verified for `ea_id_registry` and `magic_numbers`.
- `powershell -ExecutionPolicy Bypass -File framework\scripts\compile_one.ps1 -EAPath framework\EAs\QM5_12833_wti-jpy-confirm\QM5_12833_wti-jpy-confirm.mq5 -Strict`
  - PASS: 0 errors, 0 warnings, `.ex5` produced.
  - Compile log: `C:\QM\repo\framework\build\compile\20260630_183747\QM5_12833_wti-jpy-confirm.compile.log`
- `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_12833_wti-jpy-confirm -Strict -SkipCompile`
  - PASS: 0 failures.
  - Warnings: 16 shared-framework lazy-indicator advisories under `framework/include/QM/`, matching recent builds.
  - Build check report: `D:\QM\reports\framework\21\build_check_20260630_183816.json`

## Q02 Enqueue

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_12833 --queue-ceiling 10000 --max-part2-per-run 0
```

First attempt hit `sqlite3.OperationalError: database is locked` before commit;
a readback confirmed 0 existing `QM5_12833` rows. Retry succeeded.

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Work item: `3eddba18-d485-48eb-8a12-ddb9e486d663`
- Farm DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Phase: `Q02`
- EA: `QM5_12833`
- Symbol: `XTIUSD.DWX`
- Status: `pending`
- Created: `2026-06-30T18:39:29+00:00`
- Setfile: `C:\QM\repo\framework\EAs\QM5_12833_wti-jpy-confirm\sets\QM5_12833_wti-jpy-confirm_XTIUSD.DWX_D1_backtest.set`

No backtest was run in this build turn.

## Live Scope

No `T_Live` manifest, AutoTrading setting, deploy manifest, portfolio gate,
portfolio KPI, or live-terminal file was touched.
