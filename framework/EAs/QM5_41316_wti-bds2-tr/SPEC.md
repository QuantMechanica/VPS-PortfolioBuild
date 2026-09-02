# QM5_41316 — WTI Monthly BDS2 Trend

**EA ID:** QM5_41316

**Slug:** `wti-bds2-tr`

**Strategy ID:** `BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902_S01`

**Source:** `BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902`

**Author:** Development

**Last revised:** 2026-09-02

## 1. Strategy Logic

This EA implements the approved card
`strategy-seeds/cards/approved/QM5_41316_wti-bds2-tr_card.md` without a
research or optimization surface. It is a direct `XTIUSD.DWX` D1 commodity
sleeve: an embedding-dimension-two BDS dependence state gates the sign of
newest twelve-month WTI momentum. The card's source, method limitations, and
synthetic conjunction boundary remain authoritative. Q09 alone can establish
portfolio diversification; this build does not authorize live use.

## 2. Parameters

| input | value | purpose |
|---|---:|---|
| `strategy_month_returns` | 48 | completed chronological log returns |
| `strategy_embedding_dim` | 2 | fixed BDS delay-vector dimension |
| `strategy_distance_multiplier` | 1.5 | epsilon in sample-standard-deviation units |
| `strategy_sample_variance_floor` | `1e-18` | reject degenerate return samples |
| `strategy_epsilon_floor` | `1e-12` | reject degenerate distance radii |
| `strategy_bds_variance_floor` | `1e-18` | reject unstable BDS denominators |
| `strategy_abs_bds_boundary` | `0.6744897501960817` | inclusive symmetric state divider |
| `strategy_momentum_months` | 12 | direction window |
| `strategy_direction_epsilon` | `1e-12` | symmetric neutral band |
| `strategy_history_bars` | 1500 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | inclusive entry-cost ceiling |

Q02 uses exactly one fixed-risk backtest set: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## 3. Symbol Universe

The exact host and traded carrier are `XTIUSD.DWX`, D1, slot zero, governed
magic `413160000`. On the first executable tick after a genuine broker-month
change, reconstruct 49 consecutive completed broker-month-end closes,
oldest to newest. The current month never enters the sample.

For `C[0..48]`, calculate chronological `r[i]=ln(C[i+1]/C[i])`, `i=0..47`.
With `n=48`, use sample standard deviation (`ddof=1`) and
`epsilon=1.5*sample_sd`. Define a complete symmetric indicator matrix,
including its unit diagonal, with the strict comparison
`I[a,b] = 1 iff abs(r[a]-r[b]) < epsilon`.

```text
C1  = mean(I[a,b], 0 <= a < b < 48)
row[a] = sum(I[a,b], b=0..47)
S   = sum(I[a,b], a,b=0..47)
k   = (sum(row[a]^2)-3*S+2*48)/(48*47*46)
C1T = mean(I[a,b], 1 <= a < b < 48)
C2  = mean(I[a,b]*I[a+1,b+1], 0 <= a < b < 47)
variance2 = 4*(k-C1^2)^2
BDS2 = sqrt(47)*(C2-C1T^2)/sqrt(variance2)
mom12 = sum(r[36..47])

BUY  iff abs(BDS2) >= 0.6744897501960817 and mom12 > +1e-12
SELL iff abs(BDS2) >= 0.6744897501960817 and mom12 < -1e-12
FLAT otherwise
```

All closes and arithmetic must be finite; closes must be positive. The
sample variance, epsilon, and BDS variance must exceed their locked floors.
The BDS sign never supplies direction and its magnitude never changes risk.

## 4. Timeframe

Signal and execution timeframe are both D1. The low-frequency decision clock
is monthly, and a qualifying position is intended to survive only within its
entry broker month.

Persist the normalized broker month before history reconstruction, signal,
news, spread, quote, ATR, sizing, margin, or order gates. A consumed month is
never retried. Reject late decisions, previous entry deals, owned exposure,
or foreign `XTIUSD.DWX` exposure. Entry spread must be finite and within
`[0,1500]` points.

A qualified decision opens at most one market position. Size it through the
V5 fixed-dollar risk path and attach a frozen completed-bar `3.5*ATR(20,D1)`
broker hard stop. There is no target. Both news axes, legacy news, Friday
close, and stress rejection are locked off.

## 5. Expected Behaviour

Lifecycle repair runs before entry-only gates on every tick. Close owned
exposure on the first processed tick in a later normalized broker month or
after forty elapsed calendar days. Duplicate, wrong-symbol, invalid-type,
wrong-side, missing-stop, malformed entry time, or inconsistent entry-month
state causes a defensive strategy close. Restart recovery may reconstruct the
entry month only from matching owned deal history.

There is no target, intramonth statistic exit or flip, Friday flatten, trail,
break-even move, partial close, resize, scale-in, grid, martingale, pyramid,
or retry. Framework kill switch and broker hard stop remain authoritative.

## 6. Source Citation

The pinned statsmodels implementation fixes strict distance indicators,
`ddof=1`, full-sample `k`, first-observation conditioning, adjacent-pair delay
orientation, variance, and BDS normalization. Broock et al. provide original
method attribution; Moskowitz, Ooi, and Pedersen provide monthly own-return
continuation and explicit WTI membership. No source proves this conjunction,
its boundary, CFD transport, economics, or portfolio correlation.

The EA runs a deterministic reference self-test at initialization. The
independent Python suite reproduces the scalar formula using a separately
constructed delay-vector correlation sum, checks a pinned upstream sequence
fixture, affine invariance, strict epsilon behavior, full versus conditioned
sums, boundary symmetry, endpoints, set/card/registry binding, and source
guards.

Q02 must retire the variant on zero positions, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
nondeterminism, or any formula, fixed-risk, stop, attempt, or lifecycle defect.
No result-based repair is authorized.

## 7. Risk Model

The canonical baseline uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Stop distance is the frozen `3.5*ATR(20,D1)` value at
entry; no target or dynamic resizing exists. Gaps may exceed modeled stop
risk. Principal model risks are continuous-CFD roll, basis and financing,
single-carrier concentration, broker-month labeling, small-sample BDS
distortion, and dependence caused by outliers or volatility rather than a
tradable continuation state. No live risk is authorized.

## Framework Alignment

- `Strategy_NoTradeFilter`: identity, magic, fixed-risk and framework locks.
- bounded helpers: month clock, attempt state, endpoints, BDS2, momentum side,
  and restart recovery.
- `Strategy_EntrySignal`: exposure, spread, quote, ATR, frozen stop, and order.
- `Strategy_ManageOpenPosition`: malformed-state repair, side validation,
  next-month exit, and forty-day repair.
- `Strategy_ExitSignal`: no discretionary exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | approved-source build | G0-approved card; magic `413160000`; Q01 pending |
