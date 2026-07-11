# QM5_13143 Energy Expected-Shortfall Rank - Q02 Enqueue Evidence

**Date:** 2026-07-11
**Branch:** agents/board-advisor
**EA:** QM5_13143_energy-es-rank
**Strategy ID:** YIYI-ES-2025_XTI_XNG_S02

## Outcome

A new structural, low-frequency energy sleeve was sourced, carded, allocated,
built, and left pending in Q02. Once per broker month, the EA estimates each
energy leg's expected shortfall as the mean of its worst 5% of simple daily
returns over the prior twelve complete broker-calendar months. It buys the
higher-ES XTI/XNG leg and shorts the lower-ES leg with equal fixed-risk halves.

Expected shortfall is a negative return statistic, so “higher” means the less
damaging lower tail. The signal is downside-tail risk exposure, not the
certified XNG RSI pullback, trend, seasonality, price-ratio reversion, signed
variance, maximum-return, skew, kurtosis, residual-volatility, residual-tail,
liquidity, salience, or value logic already in the repository. The opposite
sides reduce common energy direction, but dollar, beta, volatility, factor,
and realized market neutrality are explicitly unclaimed.

## Source And Card Evidence

- Primary source: Qin, Cai, Zhu, and Webb (2025), *Commodity Futures
  Characteristics and Asset Pricing Models*, *Journal of Futures Markets*
  45(3), 176-207, DOI 10.1002/fut.22559.
- The complete open paper was reviewed, including the characteristic
  construction, one-way sorts, latent-factor tests, conclusion, and appendix.
- The paper defines ES as the average worst 5% of daily returns from months
  t-12 through t-1 and holds the ranked portfolio in month t.
- Its full-sample one-way high-minus-low ES result is positive but weak
  (annualized 0.037, t=1.36); that weakness is preserved as a Q02 kill risk.
- Source packet: `strategy-seeds/sources/YIYI-ES-2025/source.md`.
- Card of record: `strategy-seeds/cards/energy-es-rank_card.md`.
- Card schema and G0 lints: PASS; R1-R4: PASS under the OWNER mission.
- Dedup checker plus manual signal/input/window/direction/lifecycle review:
  `CLEAN_AFTER_MANUAL_REVIEW`.

The source ranks a broad futures universe. This build fixes the carrier to two
continuous energy CFDs. Narrow breadth, CFD/futures basis and rolls, sparse
tail estimation, gaps, legging, costs, and the weak one-way source statistic
are binding Q02 falsification risks. No source Sharpe ratio, drawdown,
correlation, or cost statistic is imported.

## Locked Mechanic

1. On the first tradable XTI D1 bar of a broker month, use only daily returns
   ending in the immediately prior twelve complete broker-calendar months.
2. Require all twelve months and at least 220 valid close-to-close returns per
   leg; use simple returns and `K=ceil(N*0.05)`.
3. Calculate `ES=mean(K lowest returns)` separately for XTI and XNG.
4. Buy the higher-ES leg and short the lower-ES leg; ties and invalid samples
   remain flat.
5. Allocate one `RISK_FIXED=1000` package as equal fixed-risk halves with
   independent frozen ATR(20) times 3.5 broker hard stops.
6. Close at the next monthly transition or after 40 days; immediately flatten
   invalid composition or an orphan leg and prohibit same-month re-entry.

## Identity And Registry Evidence

- EA reservation:
  `13143,energy-es-rank,YIYI-ES-2025_XTI_XNG_S02,active`.
- Magic slot 0: XTIUSD.DWX to `131430000`.
- Magic slot 1: XNGUSD.DWX to `131430001`.
- The clean staged resolver retains 14,879 rows and both new magic values.
- Clean magic-registry SHA256:
  `88022F076C4E0B0E71648C1DA8BAE3E1EBC3AF0BB8908505520B8E8E4A984F92`.
- Resolver SHA256:
  `92DCB2F9542CD66DCBF368128AF0D5BF3AB12B48F7625A0D39D67BD376680C9B`.

The staged resolver preserves the pre-existing QM5_13122 binding and drops
only historical missing-directory IDs 1001, 1015, and 1016. Unrelated dirty
fleet allocations were excluded from build commit `cbc364a89`.

## Q01 Build Evidence

- Build commit: `cbc364a89fa55837d47d40354843cdb9587bd1b6`.
- Strict clean-staged-resolver compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `D:/QM/reports/compile/20260711_135013/QM5_13143_energy-es-rank.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_135013.json`.
- Card schema lint, G0 lint, SPEC validator, build guard, basket symbol-scope
  validator, and setfile/source hash check: PASS.
- MQ5 SHA256:
  `1888A3CE606E4C6492C23E988A9678513CDC26CCD85FF855334AE3C688A113C1`.
- EX5 SHA256:
  `E1F9F309148169AE6964E9A938A5BEB62EAD1EA95891DD90966A31FB4574B409`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13143_XTI_XNG_ES_D1`; host XTIUSD.DWX, D1.
- Setfile:
  `framework/EAs/QM5_13143_energy-es-rank/sets/QM5_13143_energy-es-rank_QM5_13143_XTI_XNG_ES_D1_D1_backtest.set`.
- Setfile SHA256:
  `B0344DD9730C86505E5D5E2988351D40D11268D632FC002A1922183BD9EABB1B`.
- Setfile build hash:
  `1888a3ce606e4c6492c23e988a9678513cdc26ccd85ff855334ae3c688a113c1`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: `d3db63e0-0184-45cc-ac90-8ad3c12406ef`, done.
- Work item: `29285285-beb9-499b-9709-bdabc3a3af65`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13143_XTI_XNG_ES_D1`.
- Host/timeframe: XTIUSD.DWX, D1.
- Status at verification: pending.
- Attempt count: 0; claimed by: none.
- Enqueued at: `2026-07-11T13:55:45+00:00`.
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
