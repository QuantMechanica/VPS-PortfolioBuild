# QM5_20291_xauxag-kurt-rk - Strategy Spec

**EA ID:** QM5_20291  
**Strategy ID:** `HOLLSTEIN-MAX-2021_XAU_XAG_S03`  
**Source:** Hollstein, Prokopczuk, and Tharann (2021), DOI
`10.1142/S2010139221500178`  
**Last revised:** 2026-08-12

## 1. Strategy Logic

On the first processed XAU D1 bar of each broker month, calculate each
metal's Pearson historical kurtosis from exactly 252 completed simple D1
returns. Buy the higher-kurtosis metal, short the lower-kurtosis metal, split
one fixed-risk package equally, and close and rerank at the next broker-month
transition. A tie or invalid input consumes the month without a trade.

This is a pure fourth-moment cross-sectional rank. It uses no price ratio,
OLS residual, spread z-score, trend, oscillator, calendar direction, trained
output, or adaptive threshold.

## 2. Parameters

```text
mu = sum(r[d]) / 252
s2 = sum((r[d] - mu)^2) / 251
m4 = sum((r[d] - mu)^4) / 252
kurtosis = m4 / (s2^2)
```

| Parameter | Locked value | Meaning |
|---|---:|---|
| `strategy_lookback_d1` | 252 | completed simple returns per metal |
| `strategy_history_bars` | 320 | bounded D1 history request |
| `strategy_max_endpoint_gap_days` | 10 | completed endpoint freshness |
| `strategy_variance_floor` | 1e-16 | positive sample-variance floor |
| `strategy_rank_tolerance` | 1e-12 | symmetric rank tie tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | hard-stop distance per leg |
| `strategy_max_hold_days` | 40 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | XAG spread ceiling |
| `strategy_deviation_points` | 20 | basket-order deviation |

All framework, risk, news, Friday-close, stress, and strategy values fail
closed against the one authorized Q02 baseline.

## 3. Symbol Universe

- Host/slot 0: `XAUUSD.DWX`, intended magic `202910000`.
- Traded slot 1: `XAGUSD.DWX`, intended magic `202910001`.
- Logical symbol: `QM5_20291_XAU_XAG_HKURT_D1`.
- No standalone-leg interpretation or single-leg fallback is authorized.

## 4. Timeframe

Both series and the host use D1. Decisions occur only on a genuine broker-
month transition. A terminal-persistent attempt marker is written before
history or order checks. The manager closes the prior package before renewal,
closes after forty days, and flattens any orphan, duplicate, same-side, or
otherwise malformed package.

## 5. Expected Behaviour

After the 253-close warm-up, the basket should attempt approximately one
opposite-side package per broker month. XAU is long only when its source-
defined kurtosis is higher than XAG's; otherwise the sides reverse. A tie or
invalid state remains flat. Q02 retires the candidate below five completed
packages per full post-warm-up year, and Q09 alone may establish realized
correlation to the certified book.

## 6. Source Citation

Hollstein, F.; Prokopczuk, M.; and Tharann, B. (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The source's two-portfolio result is
insignificant and its later-period result reverses sign; no efficacy transfers
to this two-CFD carrier.

## 7. Risk Model

Q02 is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the whole package. Each leg receives half of the
stop-normalized risk budget and a frozen `3.5 * ATR(20,D1)` broker hard stop.
News axes and Friday close are OFF. No live, demo, shadow, optimization,
stress, or deployment setfile is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-12 | initial approved XAU/XAG historical-kurtosis carrier scaffold |
| v2 | 2026-08-12 | Q01 implementation, strict compile, and registry validation PASS |
| v3 | 2026-08-12 | one logical XAU/XAG fixed-risk baseline enqueued at Q02 |
