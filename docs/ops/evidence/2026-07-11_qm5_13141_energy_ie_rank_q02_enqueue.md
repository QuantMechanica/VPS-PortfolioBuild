# QM5_13141 Energy IE Rank - Q02 Enqueue Evidence

**Date:** 2026-07-11
**Branch:** agents/board-advisor
**EA:** QM5_13141_energy-ie-rank
**Strategy ID:** HAN-IE-2023_XTI_XNG_S01

## Outcome

A new structural, low-frequency energy sleeve was sourced, carded, atomically
allocated, built, and left pending in Q02. The EA ranks XTI and XNG monthly by
the difference between positive and negative half-sigma exceedance frequencies
of residuals from a quadratic commodity-factor regression. It buys lower IE
and shorts higher IE with an approximately equal-notional fixed-risk package.

This is a residual-distribution characteristic, not the existing XNG RSI
pullback, raw skew, IVOL, coefficient-of-variation, value, ALIQ, trend,
seasonality, or price-ratio logic. The driver is mechanically distinct from
the certified index/metal/XNG book, but realized portfolio decorrelation is a
later empirical gate and is not claimed by this build.

## Source And Card Evidence

- Canonical source: Han, Mo, Su, and Zhu (2023), "Is idiosyncratic asymmetry
  priced in commodity futures?", *Journal of Financial Research* 46(3),
  875-898, DOI 10.1111/jfir.12339.
- The complete open 24-page paper, appendices, tables, and references were
  reviewed end to end.
- Source packet: `strategy-seeds/sources/HAN-IE-2023/source.md`.
- Card of record: `strategy-seeds/cards/energy-ie-rank_card.md`.
- Schema and G0 lints: PASS; R1-R4: PASS under the OWNER mission directive.
- Dedup checker fuzzy hits to CV and value ranks were manually reviewed.
  Formula, input, window, direction, and lifecycle verdict:
  `CLEAN_AFTER_MANUAL_REVIEW`.

The source ranks 27 futures against the S&P GSCI. The EA substitutes a fixed
equal-weight XTI/XNG/XAU/XAG factor and ranks two continuous energy CFDs. That
proxy, benchmark endogeneity, breadth loss, and CFD basis are binding Q02 kill
risks. No source return, drawdown, cost, or correlation statistic is imported.

## Locked Mechanic

1. On the first tradable XTI D1 bar of each broker month, retain synchronized
   simple returns from exactly the six preceding complete broker months.
2. Require all six month keys and at least 100 common observations across XTI,
   XNG, XAU, and XAG.
3. Form the equal-weight four-CFD factor and regress each energy return on an
   intercept, the factor, and the squared factor.
4. Center each residual series, divide by its population standard deviation,
   and calculate `P(z >= +0.5) - P(z <= -0.5)` by inclusive empirical counts.
5. Buy the lower-IE leg and short the higher-IE leg; a numerical tie or invalid
   regression remains flat.
6. Apply one `RISK_FIXED=1000` package budget, ATR(20) times 3.5 frozen hard
   stops, and risk weights translated toward equal dollar notional. Reject
   more than 20% post-rounding notional mismatch.
7. Close at the next monthly transition or after 40 days; flatten an orphan or
   invalid package immediately and prohibit same-month re-entry via position
   and deal history.

## Identity And Registry Evidence

- EA reservation:
  `13141,energy-ie-rank,HAN-IE-2023_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131410000`.
- Magic slot 1: XNGUSD.DWX to `131410001`.
- The clean staged resolver retains 14,875 rows and both new magic values.
- Staged magic-registry SHA256:
  `CB8D5997F0C35F9C231CCB3DDA19FC1017561E6E0A58950F7ECF76B50D531FFC`.
- Resolver SHA256:
  `A16A19CCB3E0D05BF6EF2023E2B98A00BEC43EEAD5F77C1333E59E8326251D7B`.

The staged resolver preserves the pre-existing QM5_13122 binding and drops
only historical missing-directory IDs 1001, 1015, and 1016. Unrelated dirty
fleet registry rows are excluded from commit `8781aa0e3`.

## Q01 Build Evidence

- Build commit: `8781aa0e3`.
- EA source:
  `framework/EAs/QM5_13141_energy-ie-rank/QM5_13141_energy-ie-rank.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13141_energy-ie-rank/QM5_13141_energy-ie-rank.ex5`.
- Strict clean-staged-resolver compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/worktrees/codex-13141-index-20260711-1122/framework/build/compile/20260711_112202/QM5_13141_energy-ie-rank.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_111936.json`.
- Card schema lint, G0 lint, SPEC validator, build guard, and basket symbol
  scope validator: PASS.
- MQ5 SHA256:
  `3413E0A19F510DAD699A955D7B402B2705DAA26580B3099CEC359E0DD2706AA3`.
- EX5 SHA256:
  `E6A2571C618594C91C21A50039DD0A318E4CCC11FC6E0E333D9A206B3E423DF8`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13141_XTI_XNG_IE_D1`; host XTIUSD.DWX, D1.
- Setfile:
  `framework/EAs/QM5_13141_energy-ie-rank/sets/QM5_13141_energy-ie-rank_QM5_13141_XTI_XNG_IE_D1_D1_backtest.set`.
- Setfile SHA256:
  `7A4AFFB951FE9B92FF5D7B5573E047E5A80F007C57EDC7926E7B3D28152E2DE6`.
- Setfile build hash:
  `049e9773dd939f7e9024c442996d53ce3026eaafd11bbf6b26eacc6c0e6e6335`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: `b1449ed5-390e-43c9-b31c-0303a6b090bd`, done.
- Work item: `d958acd3-c76d-49a8-b550-0a40c28a686d`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13141_XTI_XNG_IE_D1`.
- Host/timeframe: XTIUSD.DWX, D1.
- Status at verification: pending.
- Attempt count: 0; claimed by: none.
- Enqueued at: `2026-07-11T11:25:50+00:00`.
- Queue path: `record_build_result.auto_q02`.

No manual smoke, tester, terminal launch, dispatch tick, worker tick, or
backtest was started. This work consumed no backtest CPU and preserved paced
Q02 dispatch.

## Safety Boundary

- No T_Live path or manifest changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest was created.
- No portfolio gate, threshold, KPI, admission file, or T_Live manifest was
  changed.
