# QM5_20157 XAU/XAG Ratio — Build And Q02 Evidence

Date: 2026-07-25  
Branch: `agents/board-advisor`

`QM5_20157_xau-xag-ratio` is a two-leg D1 relative-value basket. It
normalizes `ln(XAUUSD.DWX) - ln(XAGUSD.DWX)` over 60 completed bars, opens at
absolute z-score 2, and exits inside 0.5. Each leg receives half of the fixed
risk budget and a frozen 2 ATR(20) hard stop.

The peer-reviewed source lineage supports a time-varying long-run gold/silver
relationship and mean reversion; it does not prove the fixed QM parameters,
profitability, or portfolio decorrelation. The new mechanic differs from the
existing stochastic gold/silver pair and standalone metal EAs.

Evidence:

- card: `strategy-seeds/cards/approved/QM5_20157_xau-xag-ratio_card.md`
- source packet: `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`
- allocation: EA 20157; XAU slot 0 magic 201570000; XAG slot 1 magic 201570001
- schema/ML lint: PASS, no missing sections or ML hits
- strict compile: PASS, 0 errors, 0 warnings
- compile log: `framework/build/compile/20260725_154828/QM5_20157_xau-xag-ratio.compile.log`
- targeted build check: PASS, 0 failures, 0 warnings
- build-check report: `D:/QM/reports/framework/21/build_check_20260725_155025.json`
- build task: `cf84cb67-4469-4946-b84e-5232f8dc0066`, done
- Q02 work item: `3ccaa92d-4376-4b6c-a536-9a982a9e497f`, pending
- logical basket: `QM5_20157_XAUUSD_XAGUSD_RATIO_D1`, D1
- setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

No manual backtest was started; the paced fleet owns Q02. No portfolio gate,
live setfile, deploy/T_Live manifest, T_Live file, terminal, or AutoTrading
state was touched.
