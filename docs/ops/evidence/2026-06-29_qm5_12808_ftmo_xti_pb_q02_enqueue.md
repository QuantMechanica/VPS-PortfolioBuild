# QM5_12808 FTMO XTI Trend Pullback Build And Q02 Enqueue

Date: 2026-06-29
Branch: `agents/board-advisor`

## Edge Selected

Built `QM5_12808_ftmo-xti-pb`: a structural low-frequency WTI crude-oil
trend-pullback sleeve on `XTIUSD.DWX` H4.

Source lineage is `FTMO-MAR2026-XTI-PORTFOLIO`, the local code-first inventory
row for OWNER's FTMO March 2026 `FTMO_XTIUSD_Portfolio_v1` package. Runtime data
is limited to Darwinex MT5 OHLC and framework EMA/ATR readers.

## Duplicate Review

- XAU/XAG market-neutral ratio already exists as `QM5_12577_cme-xauxag-ratio`.
- Existing WTI/XTI sleeves include calendar, weekday, month, weekend-gap,
  EIA/WPSR, refinery, hurricane, OPEC, roll, 52-week-anchor, TSMOM, Pro-Go,
  Abraham breakout-pullback, Collins range expansion, CAD/oil, XTI/XNG,
  oil/gold, oil/silver, and RSI/reversal mechanics.
- This build is source-specific FTMO XTI trend-pullback: D1 EMA regime plus H4
  EMA pullback/reclaim. It has no metal/index exposure, no XNG logic, no event
  or inventory feed, and no RSI/cum-RSI2 dependency.

## Artifacts

- Source note: `strategy-seeds/sources/FTMO-MAR2026-XTI-PORTFOLIO/source.md`
- Card: `strategy-seeds/cards/approved/QM5_12808_ftmo-xti-pb_card.md`
- EA: `framework/EAs/QM5_12808_ftmo-xti-pb/QM5_12808_ftmo-xti-pb.mq5`
- SPEC: `framework/EAs/QM5_12808_ftmo-xti-pb/SPEC.md`
- Setfile: `framework/EAs/QM5_12808_ftmo-xti-pb/sets/QM5_12808_ftmo-xti-pb_XTIUSD.DWX_H4_backtest.set`
- Build result: `artifacts/qm5_12808_build_result.json`

## Validation

- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\approved\QM5_12808_ftmo-xti-pb_card.md`
  - PASS: status ok, no ML hits, no missing sections.
- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_12808_ftmo-xti-pb`
  - PASS: 1 PASS, 0 FAIL.
- `python tools\strategy_farm\validate_symbol_scope.py --ea-label QM5_12808_ftmo-xti-pb --verbose --fail-on-leak`
  - PASS: SINGLE_SYMBOL_OK, n_violations=0.
- `powershell -ExecutionPolicy Bypass -File framework\scripts\compile_one.ps1 -EALabel QM5_12808_ftmo-xti-pb -Strict`
  - PASS: 0 errors, 0 warnings, `.ex5` produced.
- `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_12808_ftmo-xti-pb -Strict -SkipCompile`
  - PASS: 0 failures. Warnings were existing shared-framework lazy-indicator
    advisory findings under `framework/include/QM/`.

## Q02 Enqueue

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_12808 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Work item: `16aa9bb8-af49-4a4a-9b63-7379264d6d53`
- Phase: `Q02`
- EA: `QM5_12808`
- Symbol: `XTIUSD.DWX`
- Status: `pending`
- Created: `2026-06-29T22:10:06+00:00`

No backtest was run in this build turn.

## Live Scope

No `T_Live` manifest, AutoTrading setting, deploy manifest, or portfolio gate
file was touched.
