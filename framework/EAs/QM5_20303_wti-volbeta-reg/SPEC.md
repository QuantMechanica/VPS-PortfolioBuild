# QM5_20303_wti-volbeta-reg - Strategy Spec

**EA ID:** QM5_20303
**Slug:** `wti-volbeta-reg`
**Source:** `HOLLSTEIN-WTI-VOLBETA-REG-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-13

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, consume one
attempt and load exactly 545 synchronized completed `XTIUSD.DWX` and
`XNGUSD.DWX` D1 closes. Form two disjoint 272-simple-return blocks. Within
each block, construct an inverse-volatility common-energy return, zero its
20-return realized-volatility change on fixed two-sigma jump days, and regress
WTI return on an intercept, common-energy return, and the smooth-volatility
change. Buy WTI when the recent smooth-volatility coefficient exceeds the
preceding coefficient; sell when it is lower. XNG is read-only.

Every entry has a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly
replacement, and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_returns_per_block` | `272` | `[272]` | Returns in each factor/OLS block |
| `strategy_ols_observations` | `252` | `[252]` | Regression rows per block |
| `strategy_recent_block_offset` | `272` | `[272]` | Recent chronological return offset |
| `strategy_history_bars_d1` | `545` | `[545]` | Synchronized completed close count |
| `strategy_rv_window_d1` | `20` | `[20]` | Rolling sample-volatility window |
| `strategy_jump_exclusion_z` | `2.0` | `[2.0]` | Jump-day smooth-factor zeroing threshold |
| `strategy_min_smooth_days` | `200` | `[200]` | Minimum non-jump rows per block |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest endpoint freshness |
| `strategy_beta_tolerance` | `1e-12` | `[1e-12]` | Symmetric beta-comparison tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | WTI entry spread ceiling |

All values are locked. No optimization or alternate estimator is authorized.

## 3. Symbol Universe

Designed only for registered `XTIUSD.DWX`, D1, magic slot 0. Registered
`XNGUSD.DWX` is a read-only factor input. It has no symbol slot or magic and
must never be ordered. This is one outright WTI carrier, not an XTI/XNG
package and not a port to XNG, XAU, XAG, or XBR.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal history | Exactly 545 synchronized completed closes per input |
| Decision clock | Genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until next month transition, capped at 40 calendar days |

The current D1 bar and all incomplete returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11-12 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Drawdown profile | Sparse fixed-risk WTI factor-regime losses with gap, roll, conditioning, and persistent-state exposure |
| State | Long when recent smooth-volatility beta is higher; short when lower |

The WTI carrier and smooth common-energy volatility sensitivity are
diversification hypotheses relative to the incumbent XAU/SP500/NDX/XNG book.
Q09 alone owns realized overlap.

## 6. Source Citation

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017, DOI `10.1142/S2010139221500178`.

The source defines an option-derived aggregate smooth-volatility beta and
uses monthly high-minus-low commodity sorts. The EA's realized two-CFD factor
and two-block own-history comparison are locked QM hypotheses, not a source-
tested WTI rule. The paired energy sibling's Q08 runs-test failure is retained
as material adverse family evidence.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## 8. Exact Statistical Contract

Load 545 synchronized completed closes and form 544 chronological simple
returns. The preceding block is `0..271`; the recent block is `272..543`.
They share one boundary close and no return. For each block independently:

```text
rank span                 = return indices 20..271
sd_i                      = sample standard deviation on the rank span
w_i                       = inverse(sd_i) / sum inverse sd
m_t                       = w_XTI*r_XTI,t + w_XNG*r_XNG,t
mean_m, sd_m              = mean and sample sd on indices 20..271
RV20_t                    = sample sd(m_[t-19..t])
smooth_t                  = 0 if abs(m_t-mean_m) >= 2*sd_m
                            else RV20_t - RV20_[t-1]
r_XTI,t                   = alpha + beta_energy*m_t
                            + beta_smooth*smooth_t + error_t
```

Use exactly 252 OLS rows and require at least 200 non-jump rows per block.
Buy above the preceding beta by more than `1e-12`, sell below it by more than
`1e-12`, and consume a tie or invalid state flat.

## 9. Non-Duplicate Boundary

`QM5_13151` is a two-leg concurrent XTI/XNG beta rank. This EA compares two
disjoint WTI beta histories, owns one magic, and makes XNG read-only.
`QM5_20298` measures realized volatility-of-volatility rather than a
regression coefficient. WTI tail, moment, trend, calendar, event, breakout,
reversal, robust-location, and variance-ratio builds use other state objects.
`QM5_12567` is a short-horizon long-only XNG oscillator pullback.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong synchronized history, overlapping blocks, wrong return type,
pooled/equal weights, wrong standard-deviation denominator, wrong RV window,
wrong jump handling, too few smooth days, singular OLS acceptance, inverted
direction, any XNG order, repeated attempt, missing stop, hold beyond forty
days, risk mismatch, or nondeterminism. No rescue parameter is authorized.

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
| v2 | 2026-08-13 | Implemented locked WTI carrier and monthly lifecycle | Strict compile, deploy, and reference checks pass |

## 12. Q01 Status

PASS. The registered one-slot EA implements the exact synchronized two-block
smooth-volatility-beta estimator, block-local inverse-volatility weights,
fixed jump zeroing, restart-safe monthly attempt state, one-position lifecycle,
frozen hard stop, and fixed-risk contract. Strict compile passed with zero
errors and zero warnings; the target build check passed with zero failures and
zero warnings; six independent formula, direction, support, denominator,
jump, chronology, count, and freshness tests passed; all T1-T10 research
factory binary hashes match; and P1 artifact validation found the compiled
`.ex5`.

## 13. Q02 Handoff

NOT ENQUEUED. Q02 requires Q01 PASS plus a fresh paced-factory capacity check.
