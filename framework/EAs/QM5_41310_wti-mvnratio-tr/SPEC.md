# QM5_41310_wti-mvnratio-tr - Strategy Spec

**EA ID:** QM5_41310

**Slug:** `wti-mvnratio-tr`

**Strategy ID:** `AI-CODEX-WTI-MVNRATIO-TREND-20260902_S01`

**Source:** `AI-CODEX-WTI-MVNRATIO-TREND-20260902`

**Author of this spec:** OpenAI Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker
month, reconstruct the immediately prior twenty-one consecutive completed
broker-month-end closes. Convert them into twenty chronological adjacent log
returns. Qualify the raw path when the sum of nineteen squared successive
return differences divided by the centered return sum of squares is strictly
below two. Follow the sign of the newest twelve-return sum outside a symmetric
`1e-12` tie band.

A valid direction owns one fixed-risk WTI position until the next normalized
broker month. It is protected by a frozen ATR hard stop and a forty-day stale
repair. Statistic magnitude never changes risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 20 | consecutive completed monthly log returns |
| `strategy_eta_boundary` | 2.0 | strict raw von Neumann ratio ceiling |
| `strategy_variance_floor` | 1e-18 | centered denominator floor |
| `strategy_momentum_months` | 12 | newest continuation slice |
| `strategy_direction_epsilon` | 1e-12 | inclusive neutral direction band |
| `strategy_history_bars_d1` | 1000 | bounded endpoint reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | raw current-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for one Q02 baseline. There is no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `413100000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe And Formula

For chronological completed-month closes `C[0..20]`:

```text
r[i]  = ln(C[i+1] / C[i]), i=0..19
mean  = sum(r[i], i=0..19) / 20
V     = sum((r[i] - mean)^2, i=0..19)
D     = sum((r[i+1] - r[i])^2, i=0..18)
eta   = D / V
mom12 = sum(r[i], i=8..19)

BUY  iff V > 1e-18 and eta < 2.0 and mom12 > 1e-12
SELL iff V > 1e-18 and eta < 2.0 and mom12 < -1e-12
FLAT otherwise
```

Every close and intermediate must be finite; closes must be positive, `D`
and `eta` nonnegative, and `V` must exceed its floor. The current month
contributes no signal close. `eta=2` and inclusive momentum ties stay flat.

## 5. Expected Behaviour

- Pre-result cadence prior: about six completed WTI positions per full
  post-warm-up year; Q02 retires below five in any full year.
- Symmetric direct-WTI structural continuation, with one consumed attempt per
  broker month and at most one owned position.
- The raw return-magnitude state differs mechanically from the thirteen-level
  ordinal Bartels rule in `QM5_41170`, path efficiency, multi-horizon variance
  ratios, entropy, LZ76, and the certified XNG oscillator pullback.
- Only downstream Q09 evidence may establish realized portfolio decorrelation.

## 6. Source Citation

NIST/SEMATECH Dataplot, "Mean Successive Differences Test,"
`https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/msdt.htm`.

von Neumann (1941), "Distribution of the Ratio of the Mean Square Successive
Difference to the Variance," *Annals of Mathematical Statistics* 12(4),
367-395, DOI `10.1214/aoms/1177731677`.

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded packet:
`strategy-seeds/sources/AI-CODEX-WTI-MVNRATIO-TREND-20260902/source.md`.
The references supply the raw statistic, low-ratio interpretation, WTI
carrier, and monthly own-return continuation lineage. They do not test this
exact CFD conjunction.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes, legacy news,
and Friday close are OFF. Maximum entry spread is 1,500 points.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deployment, portfolio admission, portfolio-gate
change, retry, scale-in, grid, martingale, target, trail, break-even move, or
partial exit.

## 8. Deterministic Failure Contract

The month is durably consumed before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order checks. Missing or duplicate month keys,
mixed label conventions, stale endpoints, invalid closes or returns, wrong
counts, `V<=1e-18`, nonfinite state, `eta>=2`, or neutral momentum fails flat.
An order reject never retries the month. Lifecycle repair runs every tick
before entry-only gates and closes duplicate, malformed, wrong-side,
later-month, or stale owned exposure.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, consecutive completed
  endpoints, exact raw ratio, newest-twelve direction, spread/quote/ATR/stop
  checks, and one fixed-risk request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, later-month exit, and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-02 | approved source build | G0-approved card and governed magic `413100000` |
