# QM5_12602 XNG Freeze Fade Build + Q02 Enqueue

Date: 2026-06-27
Branch: agents/board-advisor
Owner: Development

## Scope

- Built `QM5_12602_eia-xng-frzfade` for `XNGUSD.DWX` on D1.
- Edge: structural January-February natural-gas winter freeze-off spike fade.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- No T_Live, AutoTrading, portfolio gate, or live manifest changes.

## Source Lineage

- EIA, "U.S. natural gas prices spiked in February 2021, then generally increased through October":
  https://www.eia.gov/todayinenergy/detail.php?id=50778
- EIA, "February 2021 weather triggers largest monthly decline in U.S. natural gas production":
  https://www.eia.gov/todayinenergy/detail.php?id=47896
- EIA, "Cold weather brings near record-high natural gas spot prices":
  https://www.eia.gov/todayinenergy/detail.php?id=47016

## Non-Duplicate Claim

This is not the existing XNG broad season map, storage aftershock, spring
calendar, winter withdrawal breakout, injection-season breakdown, summer power
squeeze, shoulder failed-rally fade, hurricane breakout, or commodity RSI
pullback. It trades only January-February and only after `XNGUSD.DWX` prints an
ATR-normalized upside spike, remains stretched above SMA, and closes as a
bearish rejection candle.

## Build Evidence

- EA id: `QM5_12602`
- Slug: `eia-xng-frzfade`
- EA registry: `12602,eia-xng-frzfade,EIA-XNG-FREEZE-2026,active,Development,2026-06-27`
- Magic registry: `12602,eia-xng-frzfade,0,XNGUSD.DWX,126020000,2026-06-27,Development,active`
- Compile command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12602_eia-xng-frzfade/QM5_12602_eia-xng-frzfade.mq5 -Strict`
- Compile result: PASS, 0 errors, 0 warnings.
- Compile log: `framework/build/compile/20260627_080524/QM5_12602_eia-xng-frzfade.compile.log`
- Targeted build check: PASS, 0 failures, 16 existing shared-framework advisory warnings.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260627_080546.json`
- SPEC validation: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12602_eia-xng-frzfade` PASS.
- Farm build task id: `24a301c0-dc8c-4ab0-80fd-4f40a03a407b`
- Build result artifact: `artifacts/qm5_12602_build_result.json`

## Q02 Enqueue

- Work item id: `c96724f7-13cb-4378-b144-3a33d02013ef`
- Phase: `Q02`
- Status at enqueue verification: `pending`
- Symbol: `XNGUSD.DWX`
- Timeframe: `D1`
- Setfile: `framework/EAs/QM5_12602_eia-xng-frzfade/sets/QM5_12602_eia-xng-frzfade_XNGUSD.DWX_D1_backtest.set`
- Setfile build hash after final build check: `29a596adbabf04ad5937774d7f109ff9e94680b6fb43273a5f7c7512d714ee8e`

## Validation Notes

- `record-build` auto-enqueued Q02 for the single backtest setfile.
- No manual MT5 backtest was launched in this build turn; paced farm workers own Q02 execution.
- Full portfolio gates and T_Live deployment artifacts were intentionally untouched.
