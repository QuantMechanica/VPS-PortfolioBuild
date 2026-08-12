# QM5_20008 WTI Monthly CH3 - Q02 Enqueue Evidence

**Date:** 2026-07-19

**Branch:** agents/board-advisor

**EA:** QM5_20008_wti-month-ch3

**Status:** Q01 PASS; one XTIUSD.DWX Q02 item pending

## Edge And Source Boundary

The carrier implements the monthly channel rule tested by Szakmary, Shen and
Sharma (2010), *Trend-following trading strategies in commodity futures: A
re-examination*, Journal of Banking & Finance 34(2), 409-426, DOI
`10.1016/j.jbankfin.2009.08.004`. The peer-reviewed journal record is at
https://www.sciencedirect.com/science/article/pii/S037842660900199X. The
authors' complete accessible manuscript defines the tested channel horizons
`L={3,6,9,12}`, strict prior-month extrema, a flat inside state and a one-month
holding period:
https://www.researchgate.net/profile/Andrew-Szakmary/publication/267715955_Price_Momentum_and_Trading_Volume_In_Commodity_Futures_Markets/links/556dae9d08aeccd7773d7aca/Price-Momentum-and-Trading-Volume-In-Commodity-Futures-Markets.pdf.

The Q02 baseline uses source-tested `L=3`. On the first D1 bar of a new broker
month it reconstructs four completed WTI month-end closes. It buys when the
latest completed close is strictly above all prior three, sells when strictly
below all prior three, and otherwise remains flat. Every package closes before
the next monthly renewal. A frozen `4.0 * ATR(20)` hard stop and 35-day stale
guard are the only signal-adjacent V5 risk additions.

The local read-only cadence precheck found 65 signals across 2018-2025, or
8.21/year. That is a frequency/data gate only, not performance evidence.

## Non-Duplicate Decision

Exact and mechanic searches found no prior XTI monthly-close-versus-prior-three
month-end-extrema build. The closest WTI strategies are materially different:
QM5_13100 compares a month end with a six-month mean and neutral band;
QM5_1226 and QM5_12844 are daily price channels; QM5_12780 uses a daily
252/63-day anchor; QM5_12810 is a first-five-day monthly opening range; and
QM5_12616 uses three-/nine-month return agreement. Gold/silver ratio designs
were rejected as already heavily represented, and the tested WTI volume-climax
candidate failed the minimum-event-density gate before identity allocation.

## Identity And Q01 Evidence

- EA reservation: `QM5_20008`, strategy `SZAKMARY-WTI-MCH3-2010`.
- Magic slot 0: `XTIUSD.DWX` to `200080000`.
- Resolver retains 14,943 rows and embeds the current magic-registry SHA256
  `9958AB5A63730DA33A39D5EE88FDF43A7AB21587FEB49540EC5AEFBD1522D370`.
- Build/card commits carrying this work: `b6febe9da`, `e7bdaa1d9`,
  `8df86c4ac`, `d2bf65d80`, and `2ad4afab1`.
- Strict compile: PASS, 0 errors, 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260719_181940/QM5_20008_wti-month-ch3.compile.log`.
- Build check: PASS, 0 failures, 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260719_182057.json`.
- Card schema/G0, SPEC and build guardrails: PASS.
- MQ5 SHA256:
  `593C79996D3017B780A59C03CCD2518F6C5D8AFB21802F9F5C8EAE6FCACA0858`.
- EX5 SHA256:
  `21DF095C486911045B26A1843D668B6BA66E3CE0ADEAA5CFA4ADC1310E9244C9`.

## Risk And Q02 Queue Evidence

- Setfile:
  `framework/EAs/QM5_20008_wti-month-ch3/sets/QM5_20008_wti-month-ch3_XTIUSD.DWX_D1_backtest.set`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Setfile build hash:
  `9f49977cf479e69a8ac4de4f40ea271d5fb088c44704592fca246238d7260dae`.
- Build task `6c3d5c57-c3c3-4939-b4f8-ed5219d36c61`: done.
- Q02 work item `5659ee85-5c28-492e-965e-ca95b28e3828`: pending,
  attempt 0, unclaimed, `XTIUSD.DWX` D1.
- Enqueued at `2026-07-19T18:27:39+00:00` by `farmctl record-build`;
  one item enqueued, none skipped.

The paced-fleet scan showed eight MT5 test terminals already active. Smoke was
recorded as `deferred_p2_smoke`; no dispatch tick, worker tick, terminal launch,
tester run, optimization or backtest was started by this mission.

## Safety And Falsification Boundary

- Structural monthly price arithmetic only; no banned indicator or ML.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission or KPI was touched.
- The source uses commodity futures, while this build uses a continuous
  Darwinex WTI CFD plus an ATR risk overlay. Transfer, costs, gaps, expectancy,
  drawdown and realized correlation to the certified book remain unproven kill
  risks. Q02 and later portfolio gates—not this build—must measure them.
