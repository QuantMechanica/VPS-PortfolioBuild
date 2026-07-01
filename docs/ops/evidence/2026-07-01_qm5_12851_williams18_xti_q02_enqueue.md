# QM5_12851 Williams 18-Bar XTI Q02 Enqueue

Date: 2026-07-01  
Branch: `agents/board-advisor`  
EA: `QM5_12851_williams18-xti`  
Strategy ID: `SRC03_S12_XTI_20260701`  
Symbol/timeframe: `XTIUSD.DWX` D1

## Edge

Low-frequency WTI continuation sleeve from SRC03 Williams S12. The EA requires
two completed non-inside D1 bars on the same side of the 18-day close SMA, then
uses a stop entry through the two-bar extreme with ATR hard stop, pending expiry,
optional fixed-R take-profit, and max-hold exit.

Non-duplicate boundary: not Williams prior-range volatility breakout, not
XTI/XNG ratio, not WTI/Brent spread, not XNG RSI, not energy seasonality/switch,
and not a metal/index sleeve.

## Build Evidence

- EA ID reserved: `12851`.
- Magic row: `12851,williams18-xti,0,XTIUSD.DWX,128510000,2026-07-01,Codex,active`.
- Compile: PASS, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260701_090901\QM5_12851_williams18-xti.compile.log`.
- EX5: `C:\QM\repo\framework\EAs\QM5_12851_williams18-xti\QM5_12851_williams18-xti.ex5`, 297106 bytes.
- Build check: PASS, 0 failures, 16 warnings.
- Build check report: `D:\QM\reports\framework\21\build_check_20260701_090912.json`.
- Warning note: warnings are existing shared-framework DWX advisory warnings from included framework files; the new EA body has no raw indicator handle calls.
- SPEC validation: PASS.
- Build result: `artifacts/qm5_12851_build_result.json`.

## Q02 Queue

- Build task: `8840bd11-0869-40db-8bed-ade71a5f9b0d`.
- Q02 work item: `89fff876-40de-4fb5-9c19-74179947a0d7`.
- Status after enqueue: `pending`.
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`.
- Setfile: `C:\QM\repo\framework\EAs\QM5_12851_williams18-xti\sets\QM5_12851_williams18-xti_XTIUSD.DWX_D1_backtest.set`.
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Safety

No T_Live files, AutoTrading state, deploy manifest, portfolio gate, or live
portfolio admission files were touched. No manual MT5 backtest was launched from
this session; Q02 is delegated to the paced farm work item.
