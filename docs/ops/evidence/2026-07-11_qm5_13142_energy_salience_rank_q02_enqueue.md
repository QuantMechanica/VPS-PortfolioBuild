# QM5_13142 Energy Salience Rank - Q02 Enqueue Evidence

**Date:** 2026-07-11
**Branch:** agents/board-advisor
**EA:** QM5_13142_energy-sal-rank
**Strategy ID:** HE-SALIENCE-2025_XTI_XNG_S01

## Outcome

A new structural, low-frequency energy sleeve was sourced, carded, allocated,
built, and left pending in Q02. The EA ranks XTI and XNG once per broker month
by the covariance between prior-month returns and source-defined salience
weights. It buys the higher-ST energy leg and shorts the lower-ST leg as an
approximately equal-notional, fixed-risk package.

The signal is context-relative payoff salience, not the certified XNG RSI
pullback, trend, seasonality, price-ratio reversion, raw skew, extreme-return
rank, volatility, liquidity, value, or residual-tail logic. The carrier is
mechanically different from the current index/metal/XNG book. Realized
portfolio decorrelation is a later empirical gate and is not claimed here.

## Source And Card Evidence

- Primary source: He, Jia, Shen, and Yang (2025), *Salience Theory and the
  Returns of Commodity Futures*, DOI 10.13140/RG.2.2.26815.83364.
- The complete 52-page author-uploaded preprint, including equations, tables,
  appendices, and references, was reviewed end to end.
- Peer-reviewed method supplement: Cosemans and Frehen (2021), *Journal of
  Financial Economics* 140, 460-483.
- Source packet: `strategy-seeds/sources/HE-SALIENCE-2025/source.md`.
- Card of record: `strategy-seeds/cards/energy-sal-rank_card.md`.
- Card schema and G0 lints: PASS; R1-R4: PASS under the OWNER mission.
- Dedup checker plus manual signal/input/window/direction/lifecycle review:
  `CLEAN_AFTER_MANUAL_REVIEW`.

The source uses a broad liquid futures universe. This EA fixes the reference
payoff to synchronized XTI/XNG/XAU/XAG CFDs and trades only XTI versus XNG.
Preprint status, reference endogeneity, two-name breadth, continuous-CFD basis,
rank ties, execution costs, and rounding are binding Q02 kill risks. No source
performance, drawdown, correlation, or cost statistic is imported.

## Locked Mechanic

1. On the first tradable XTI D1 bar of a broker month, retain synchronized
   close-to-close returns from exactly the immediately prior complete month.
2. Require at least 15 common observations across XTI, XNG, XAU, and XAG.
3. Form the equal-weight four-CFD daily reference return `r_bar`.
4. For each energy leg calculate
   `sigma=abs(r-r_bar)/(abs(r)+abs(r_bar)+0.1)` and rank dates descending.
5. Normalize `0.7^rank` by its sample mean and calculate the population
   covariance of normalized weights with the leg return.
6. Buy higher ST and short lower ST; a tie or invalid panel remains flat.
7. Apply one `RISK_FIXED=1000` package budget, ATR(20) times 3.5 frozen hard
   stops, and risk weights translated toward equal dollar notional. Reject
   more than 20% post-rounding notional mismatch.
8. Close at the next monthly transition or after 40 days; flatten an orphan or
   invalid package immediately and prohibit same-month re-entry.

## Identity And Registry Evidence

- EA reservation:
  `13142,energy-sal-rank,HE-SALIENCE-2025_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131420000`.
- Magic slot 1: XNGUSD.DWX to `131420001`.
- The clean staged resolver retains 14,877 rows and both new magic values.
- Clean magic-registry SHA256:
  `35517B38948937F17364324E5B084AD43BF842F5305A57F9D826A9C21087BFD8`.
- Resolver SHA256:
  `5233B5975736530E4E9DBFAB8309F6861C7775D58462E6E2A1AC586B1119322B`.

The staged resolver preserves the pre-existing QM5_13122 binding and drops
only historical missing-directory IDs 1001, 1015, and 1016. Unrelated dirty
fleet allocations were excluded from commit `bfae4b40b`.

## Q01 Build Evidence

- Build commit: `bfae4b40b`.
- EA source:
  `framework/EAs/QM5_13142_energy-sal-rank/QM5_13142_energy-sal-rank.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13142_energy-sal-rank/QM5_13142_energy-sal-rank.ex5`.
- Strict clean-staged-resolver compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `D:/QM/reports/compile/20260711_123904/QM5_13142_energy-sal-rank.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_123840.json`.
- Card schema lint, G0 lint, SPEC validator, build guard, and basket symbol
  scope validator: PASS.
- MQ5 SHA256:
  `C0D5A7CD173391246806946A37CA7364957918718D02AF8079B9A5A8116EF308`.
- EX5 SHA256:
  `A50F35F867FED1F17C01FCE167F1E58F944097C0CBEF09FF220D0B0B6F78522A`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13142_XTI_XNG_SAL_D1`; host XTIUSD.DWX, D1.
- Setfile:
  `framework/EAs/QM5_13142_energy-sal-rank/sets/QM5_13142_energy-sal-rank_QM5_13142_XTI_XNG_SAL_D1_D1_backtest.set`.
- Setfile SHA256:
  `9796679688E024F80287D18FCD2AE16DF3DF3FE25304BD4DFB79C611E9EAE4EE`.
- Setfile build hash:
  `b73de46ce71fdb7ab25fcb8a64eedf69f26c80cca549d35b7e70b5f08c4fa5c8`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: `cf2dd733-e6d3-431a-850d-ba0a231107e5`, done.
- Work item: `fd1c8e2c-5047-4e1d-be9a-a6f0aff1c1fe`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13142_XTI_XNG_SAL_D1`.
- Host/timeframe: XTIUSD.DWX, D1.
- Status at verification: pending.
- Attempt count: 0; claimed by: none.
- Enqueued at: `2026-07-11T12:44:25+00:00`.
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
