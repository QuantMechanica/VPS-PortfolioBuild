# QM5_20019 XAU/XAG Weekend Basket — Q02 Enqueue Evidence

Date: 2026-07-20. Branch: `agents/board-advisor`.

QM5_20019 implements one weekly logical package: BUY `XAUUSD.DWX` and SELL
`XAGUSD.DWX` at broker Friday 21:00, equal USD notionals, then close both on
the first Monday H1 bar. The combined ATR stops share `RISK_FIXED=1000`;
`RISK_PERCENT=0`. The source is Borowski and Lukasik (2017), official paper:
https://econjournals.sgh.waw.pl/JMFS/article/download/740/643/ . Table 5 finds
the weekend effect significant for gold (`p=0.001138788`) but not silver
(`p=0.323175`); Table 7 reports gross weekend means `0.0294%` and `0.0223%`.

The repository contained XAU/XAG ratio, threshold-cointegration and stochastic
baskets, and outright gold Friday logic, but no Friday-close/Monday-open
XAU-long/XAG-short package. The equal-notional silver hedge is explicitly a QM
translation to isolate the gold anomaly; it is not described as source-tested
or proven decorrelated. Costs, financing, broker/session basis, hedge error,
small gross differential and post-publication decay are Q02 kill risks.

Q01 evidence:

- EA/magic reservation: 20019; XAU slot 0 `200190000`, XAG slot 1 `200190001`.
- Resolver regenerated after directory and registry creation; both magics are
  retained. The three dropped IDs (1001/1015/1016) are pre-existing missing
  directories, not this build.
- Strict compile PASS, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260720_160415/QM5_20019_xauxag-wkend.compile.log`.
- Strict build check PASS, 0 failures, 0 warnings. Report:
  `D:/QM/reports/framework/21/build_check_20260720_160628.json`.
- Canonical logical setfile hash:
  `91d78b1ae26fa5f487e5eaeba03c97a909407ab5d9b507cbf645c2c6353fd181`.
- Q02 work item `1790413c-1c71-46a4-ac75-3f7e9464249f` is pending for logical
  symbol `QM5_20019_XAU_XAG_WKEND_H1`, H1, attempt 0, unclaimed.

The basket unit suite ran 15 tests; 11 passed and four errored in pre-existing
process-identity/test-double paths unrelated to QM5_20019. No test changed the
new EA. The live process scan showed ten `terminal64` and six `metatester64`
processes, including active factory slots and T_Live, so the backtest CPU
ceiling was reached. No smoke, dispatch tick, terminal launch, tester run or
optimization was started.

No live set, T_Live file/process, AutoTrading state, deploy manifest,
T_Live manifest, portfolio gate or portfolio admission was touched.
