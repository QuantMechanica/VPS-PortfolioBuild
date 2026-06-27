# QM5_12600 CME WTI Expiry Breakout Build + Q02 Enqueue

Date: 2026-06-27
Branch: agents/board-advisor
Owner: Development

## Scope

- Built `QM5_12600_cme-wti-exp-brk` for `XTIUSD.DWX` on D1.
- Edge: structural WTI futures expiry/roll-window breakout using deterministic calendar approximation plus D1 channel, SMA, ATR range, and ATR hard-stop rules.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- No T_Live, AutoTrading, portfolio gate, or live manifest changes.

## Source Lineage

- CME Group, Chapter 200 Light Sweet Crude Oil Futures:
  https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf
- CME Group, Understanding Futures Expiration & Contract Roll:
  https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll
- CME Group, Crude Oil Futures Contract Specs:
  https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html

## Non-Duplicate Claim

This is not a WTI weekday/month average-return card, WPSR/EIA card, hurricane/refinery/OPEC event card, ratio trade, RSI pullback, or continuous commodity trend basket. The entry gate is the recurring CME WTI expiry/roll window and the trade is only taken after XTIUSD.DWX confirms a D1 breakout inside that window.

## Build Evidence

- EA id: `QM5_12600`
- Slug: `cme-wti-exp-brk`
- Compile command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12600_cme-wti-exp-brk/QM5_12600_cme-wti-exp-brk.mq5 -Strict`
- Compile result: PASS, 0 errors, 0 warnings.
- Compile log: `framework/build/compile/20260627_065413/QM5_12600_cme-wti-exp-brk.compile.log`
- Targeted build check: PASS, 0 failures, 16 existing shared-framework advisory warnings.
- Final build-check report: `D:/QM/reports/framework/21/build_check_20260627_065739.json`
- Build task id: `12e8fbdc-85d2-44c8-802a-7810b1f59e60`
- Farm build result: `D:/QM/strategy_farm/artifacts/builds/12e8fbdc-85d2-44c8-802a-7810b1f59e60.json`

## Q02 Enqueue

- Work item id: `25314be0-0bb5-4865-b953-d0892627c6c4`
- Phase: `Q02`
- Status at enqueue verification: `pending`
- Symbol: `XTIUSD.DWX`
- Timeframe: `D1`
- Setfile: `framework/EAs/QM5_12600_cme-wti-exp-brk/sets/QM5_12600_cme-wti-exp-brk_XTIUSD.DWX_D1_backtest.set`
- Setfile build hash after final build check: `1570ade4ff7020fe8add8605a6ecc4b0d5f860000c6badaa88a0c54784c8c4ba`

## Validation Notes

- `validate_spec_doc.py framework/EAs/QM5_12600_cme-wti-exp-brk`: PASS.
- `update_magic_resolver.py`: regenerated `framework/include/QM/QM_MagicResolver.mqh`.
- Full `validate_registries.py` was not clean due to pre-existing unrelated registry debt in legacy/non-scoped entries; the scoped EA passed targeted build validation.
