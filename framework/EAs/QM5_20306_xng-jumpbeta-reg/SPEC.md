# QM5_20306_xng-jumpbeta-reg - Strategy Spec

**EA ID:** QM5_20306  
**Slug:** `xng-jumpbeta-reg`  
**Source:** `HOLLSTEIN-XNG-JUMPBETA-REG-2026`  
**Author of this spec:** Codex  
**Last revised:** 2026-08-13

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, consume one
attempt and load exactly 505 synchronized completed `XTIUSD.DWX` and
`XNGUSD.DWX` D1 closes. Form two disjoint 252-simple-return blocks. Within
each block, construct an inverse-volatility common-energy return, isolate its
inclusive two-sigma realized-jump residual, and regress XNG return on an
intercept, common-energy return, and the jump residual. Buy XNG when the
recent jump-beta coefficient is lower than its preceding coefficient; sell
when it is higher. XTI is read-only.

Every entry has a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly
replacement, and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_returns_per_block` | `252` | `[252]` | Returns and OLS rows per factor block |
| `strategy_recent_block_offset` | `252` | `[252]` | Recent chronological return offset |
| `strategy_history_bars_d1` | `505` | `[505]` | Synchronized completed close count |
| `strategy_jump_z` | `2.0` | `[2.0]` | Inclusive realized-jump threshold |
| `strategy_min_jump_days` | `6` | `[6]` | Minimum nonzero jump rows per block |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest endpoint freshness |
| `strategy_beta_tolerance` | `1e-12` | `[1e-12]` | Symmetric beta-comparison tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `3000` | `[3000]` | XNG entry spread ceiling |

All values are locked. No optimization or alternate estimator is authorized.

## 3. Symbol Universe

Designed only for registered `XNGUSD.DWX`, D1, magic slot 0. Registered
`XTIUSD.DWX` is a read-only factor input. It has no symbol slot or magic and
must never be ordered. This is one outright XNG carrier, not an XTI/XNG
package and not a port to XTI, XAU, XAG, or XBR.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal history | Exactly 505 synchronized completed closes per input |
| Decision clock | Genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until next month transition, capped at 40 calendar days |

The current D1 bar and all incomplete returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Drawdown profile | Sparse fixed-risk XNG jump-regime losses with gap, roll, conditioning, and persistent-state exposure |
| State | Long when recent jump beta is lower; short when higher |

The slow symmetric common-jump-sensitivity state differs structurally from
the incumbent short-horizon long-only XNG pullback. Q09 alone owns realized
overlap with the XAU/SP500/NDX/XNG book.

## 6. Source Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017, DOI `10.1142/S2010139221500178`.

The source defines option-derived aggregate jump beta and uses monthly low-
minus-high commodity exposure. The EA's realized two-CFD factor and two-block
own-history comparison are locked QM hypotheses, not a source-tested XNG
rule. The paired energy sibling's Q08 runs-test failure is retained as
material adverse family evidence.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## 8. Exact Statistical Contract

Load 505 synchronized completed closes and form 504 chronological simple
returns. The preceding block is `0..251`; the recent block is `252..503`.
They share one boundary close and no return. For each block independently:

```text
sd_i                      = sample standard deviation of 252 returns
w_i                       = inverse(sd_i) / sum inverse sd
m_t                       = w_XTI*r_XTI,t + w_XNG*r_XNG,t
mean_m, sd_m              = mean and sample sd of all m_t
jump_t                    = m_t-mean_m if abs(m_t-mean_m) >= 2*sd_m, else 0
r_XNG,t                   = alpha + beta_energy*m_t
                            + beta_jump*jump_t + error_t
```

Use exactly 252 OLS rows and require at least six jump rows per block. Buy
below the preceding beta by more than `1e-12`, sell above it by more than
`1e-12`, and consume a tie or invalid state flat.

## 9. Non-Duplicate Boundary

`QM5_13147` is a two-leg concurrent XTI/XNG jump-beta rank. This EA compares
two disjoint XNG jump-beta histories, owns one magic, and makes XTI read-only.
`QM5_20304` is the locked WTI carrier and transfers no result. `QM5_20303`
estimates a smooth-volatility-change coefficient rather than an extreme-day
jump coefficient. `QM5_12567` is a short-horizon long-only XNG oscillator
pullback. Other XNG ALIQ, moment, trend, calendar, event, and variance-ratio
builds use different state objects or clocks.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong synchronized history, overlapping blocks, wrong return type,
pooled or equal weights, wrong sample-deviation denominator, wrong jump
factor, too few jump rows, singular OLS acceptance, inverted direction, any
XTI order, repeated attempt, missing stop, hold beyond forty days, risk
mismatch, or nondeterminism. No rescue parameter is authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-13 | Initial scaffold from approved card | Build pending |

## 12. Q01 Status

PENDING. Build, strict compile, deterministic reference checks, and Q01
validation have not yet run.
