# QM5_41193_xtixng-fracd-rv - Strategy Spec

**EA ID:** QM5_41193

**Slug:** `xtixng-fracd-rv`

**Source ID:** `VILLAR-YAYA-XTIXNG-FRACD-RV-2026`

**Last revised:** 2026-08-29

## 1. Strategy Logic

At the first synchronized D1 bar of each genuine new broker month, within 180
minutes of the raw host-bar open, the EA exact-joins 316 completed XTI/XNG D1
close pairs from a bounded 700-bar buffer. Pairs must be strictly chronological,
positive and finite, share exact timestamps, and end no more than ten calendar
days before the decision.

For chronological log-ratio levels `s[t]=ln(XTI[t])-ln(XNG[t])`, the EA uses
fixed order `d=0.40`, exactly 64 coefficients, and recurrence
`w[0]=1; w[k]=w[k-1]*(k-1-d)/k`. It computes exactly 253 finite filtered
outputs from the 316 levels.

The first 252 outputs form an arithmetic-mean and sample-standard-deviation
baseline with variance denominator 251. The latest output is held out. A
non-finite state or standard deviation at or below `1e-12` consumes the month
flat.

- `z >= +0.50` opens SELL XTI / BUY XNG.
- `z <= -0.50` opens BUY XTI / SELL XNG.
- Interior or invalid state consumes the month flat.

Signal magnitude is diagnostic only. Each broker month permits one persisted
attempt, including a flat or rejected state.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_pair_count_d1` | 316 | synchronized completed D1 pairs |
| `strategy_frac_lags` | 64 | finite fractional-filter coefficients |
| `strategy_baseline_outputs` | 252 | prior outputs excluding held-out latest |
| `strategy_frac_order` | 0.40 | fixed, non-fitted filter order |
| `strategy_entry_abs_z` | 0.50 | inclusive absolute threshold |
| `strategy_history_bars_d1` | 700 | bounded join buffer per leg |
| `strategy_entry_window_minutes` | 180 | new-month entry grace |
| `strategy_max_endpoint_gap_days` | 10 | newest completed-pair staleness |
| `strategy_atr_period_d1` | 20 | completed D1 risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop multiple |
| `strategy_max_notional_mismatch_fraction` | 0.20 | realized notional tolerance |
| `strategy_max_hold_days` | 40 | defensive package age limit |
| `strategy_xti_max_spread_points` | 1500 | XTI entry spread ceiling |
| `strategy_xng_max_spread_points` | 3000 | XNG entry spread ceiling |

No undeclared optimization, adaptive state, fitted signal quantity, or
fallback is present.

## 3. Symbol Universe

- Host and slot 0: exact `XTIUSD.DWX`, D1, magic `411930000`.
- Companion and slot 1: exact `XNGUSD.DWX`, D1, magic `411930001`.
- Logical tester symbol: `QM5_41193_XTI_XNG_FRACD_RV_D1`.
- Both symbols are traded as one opposite-sided package; neither component
  preset is an independent strategy.
- Cross-series data is read only from exactly synchronized completed D1 bars.

The logical basket setfile is the only Q02 gate input. XTI and XNG physical
setfiles are non-gating diagnostics for basket plumbing.

## 4. Timeframe

Signal and execution decisions use broker D1 bars. Package construction runs
once at the first synchronized bar of a new broker month and references only
completed bars. Position integrity and stale-state repair run on every tick.

A valid package closes at the next broker-month transition or after forty
elapsed days. Framework and broker hard stops remain active continuously.

## 5. Expected Behaviour

The fixed inclusive threshold has a transparent standard-normal density prior
near 7.4 packages per year after the 316-pair warm-up. That is not market
evidence. Q02 owns measured frequency, profitability, costs, and drawdown and
retires fewer than five completed packages in any full post-warm-up year.

The intended exposure is relative oil versus gas rather than outright
commodity beta. No realized decorrelation claim is made at build time; Q09
remains authoritative.

Interior z-scores, missing synchronization, invalid arithmetic, excessive
spreads, invalid sizes, or failed atomic execution consume the month without
retry. A rejected or malformed second leg triggers immediate flattening of
the first leg.

## 6. Source Citation

Jose A. Villar and Frederick L. Joutz (2006), *The Relationship Between Crude
Oil and Natural Gas Prices*, U.S. Energy Information Administration; David J.
Ramberg and John E. Parsons (2012), *The Weak Tie Between Natural Gas and Oil
Prices*, *The Energy Journal* 33(2), DOI `10.5547/01956574.33.2.2`.

The deterministic filter arithmetic and basket lifecycle are governed QM
translation rules documented by source packet
`VILLAR-YAYA-XTIXNG-FRACD-RV-2026`. The oil/gas sources motivate a weak,
changing relationship; they do not establish fractional cointegration or
profitability for this exact strategy. The method precedent's gold/silver
finding does not transfer.

## 7. Risk Model

The package targets equal absolute USD notionals within a 20% realized
rounding tolerance. One aggregate `RISK_FIXED=1000` budget is split equally
across two frozen `3.5*ATR(20,D1)` broker stop risks. Backtest presets lock
`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`.

XTI is submitted first and XNG second through the basket-order helper. If the
companion leg fails or the final package is malformed, the EA immediately
flattens owned exposure and does not retry that month. Stops are never widened
or removed. The framework kill switch and account controls remain
authoritative. News axes and Friday close are disabled because the approved
card defines neither as an entry or exit rule.

This is a Q01 build and Q02 research handoff only. It creates no live, demo,
shadow, optimization, stress, deploy, or portfolio authorization. It does not
touch AutoTrading, `T_Live`, a deploy manifest, or the portfolio gate. There
is no ML, banned signal, averaging, grid, martingale, scale-in, pyramid,
break-even move, partial exit, or discretionary input.

## Revision history

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-29 | Initial OWNER-approved XTI/XNG fractional basket implementation |
