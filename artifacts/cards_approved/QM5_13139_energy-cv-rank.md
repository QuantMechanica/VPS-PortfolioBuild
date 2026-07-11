---
strategy_id: SZYMANOWSKA-CV-2014_XTI_XNG_S01
source_id: SZYMANOWSKA-CV-2014
ea_id: QM5_13139
slug: energy-cv-rank
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
source_citation: "Szymanowska, de Roon, Nijman, and van den Goorbergh (2014), An Anatomy of Commodity Futures Risk Premia, The Journal of Finance 69(1), 453-482, DOI 10.1111/jofi.12096."
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13139_XTI_XNG_CV_D1
expected_trade_frequency: "One bimonthly XTI/XNG coefficient-of-variation package after 37 completed month-end closes; approximately 6 packages/year."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.03
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# QM5_13139 - XTI/XNG Bimonthly Coefficient-of-Variation Rank

## Source And Approval

The complete 45-page peer-reviewed primary source was read end to end. It
ranks a broad commodity-futures cross-section every two months and defines the
coefficient-of-variation characteristic from variance scaled by mean return
over months `t-36` through `t-1`. The source links higher CV with higher
expected futures returns.

OWNER mission-directed G0 approval on 2026-07-11 covers one new structural,
low-frequency commodity/energy card, build, and Q02 enqueue. Atomic allocator
assigned `QM5_13139`. Manual dedup review was clean: existing energy sleeves
use value, beta, residual volatility, skew, kurtosis, signed semivariance,
autocorrelation, carry, trend, or short-horizon pullback inputs, not normalized
monthly variance.

## Locked Mechanic

On the first tradable `XTIUSD.DWX` D1 bar of January, March, May, July,
September, and November:

1. Reconstruct 37 completed, consecutive broker month-end closes for XTI and
   XNG from native D1 history.
2. Calculate exactly 36 monthly log returns per leg.
3. Compute arithmetic mean `mu`, sample variance with denominator 35, and
   `CV = variance / abs(mu)`.
4. Buy the higher-CV leg and short the lower-CV leg.
5. Split fixed package risk equally and attach an `ATR(20) * 3.5` hard stop to
   each leg.
6. Close at the next odd-month rebalance or after 70 days; flatten an orphan or
   invalid package immediately.

The absolute denominator is the deterministic sign-safe translation of a
nonnegative risk measure. A numerical tie, `abs(mu) <= 1e-12`, nonpositive
variance, missing calendar month, invalid arithmetic, insufficient history,
spread/ATR/lot failure, existing package, or already-entered period stays flat.
Current positions and entry-deal history prevent same-period re-entry after a
restart or stop.

## Runtime And Risk

- Host and slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, divided equally between legs.
- Friday close disabled for the source-aligned bimonthly hold.
- Structural Q02 set disables news axes; lifecycle management precedes the
  entry-only news hook.
- Native MT5 D1 OHLC, ATR, spread, time, position state, and deal history only.
- No TP, trailing, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, banned indicator, adaptive PnL fit, or ML.

## Evidence Boundary And Kill Risks

This is a carrier translation, not a source replication. The paper uses 21
collateralized commodity futures, four portfolios, multiple maturities, and a
sample ending in 2010. QM ranks only two continuous broker CFDs and cannot
reproduce the source's spot/term/maturity decomposition. No source return,
alpha, correlation, drawdown, or cost statistic transfers to Q02.

Expected density is six packages/year after warm-up, only one above the Q02
floor. Missing data or filters can therefore kill density. Near-zero means can
destabilize CV ranks, while XNG gaps and sequential two-leg execution create
tail and legging risk. Q02 must independently falsify the signal; Q09 alone may
measure portfolio orthogonality.

No `T_Live`, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI path is authorized.
