# QM5_41171_wti-mturnpoint-tr - Strategy Spec

**EA ID:** QM5_41171

**Slug:** `wti-mturnpoint-tr`

**Strategy ID:** `MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026_S01`

**Source:** `MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-26

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
reconstruct the latest close in each of the immediately prior thirteen
consecutive completed broker months. Require positive, finite,
pairwise-distinct closes.

For each of the eleven interior endpoints, count one turning point when that
close is a strict local peak or strict local trough. The iid continuous null
mean for thirteen endpoints is `2*(13-2)/3 = 22/3`. Qualify only when
`3*TP < 22`, exactly `TP <= 7`. Follow the oldest-to-newest endpoint
direction: buy when the endpoint rises and sell when it falls. A
nonqualifying or invalid path consumes the month flat.

A valid direction owns one fixed-risk WTI position until the first later
normalized broker month, protected by a frozen ATR hard stop. A lower turning-
point count never changes risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_max_turning_points` | 7 | inclusive integer qualification ceiling |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction buffer |
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
- Magic: `411710000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe And Formula

```text
TP = 0
for i = 1..11:
  peak   = C[i-1] < C[i] and C[i] > C[i+1]
  trough = C[i-1] > C[i] and C[i] < C[i+1]
  if peak or trough: TP += 1

require 0 <= TP <= 11
qualify iff 3*TP < 22            # exactly TP <= 7

BUY  iff qualify and C[12] > C[0]
SELL iff qualify and C[12] < C[0]
FLAT otherwise
```

The formation and decision cadence are monthly. The current month contributes
no signal close. Equal closes fail closed; tie handling, p-values, phase-
duration tests, fitted values, and alternate boundaries are forbidden.

## 5. Expected Behaviour

- Pre-result density prior: five to eight completed WTI positions per full
  post-warm-up year; Q02 retires below five in any full year.
- The boundary splits at the null mean for entry density and is not a
  significance threshold or a WTI performance claim.
- Symmetric direct-WTI structural continuation; one consumed attempt per
  broker month and at most one owned position.
- The statistic is mechanically distinct from endpoint-only momentum,
  magnitude path efficiency, all-pairs Mann-Kendall, longest sign runs,
  Foster-Stuart records, Bartels adjacent-rank distance, and XNG pullback
  rules. Only downstream portfolio evidence may establish realized
  decorrelation.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Wallis and Moore (1941), "A Significance Test for Time Series Analysis,"
*Journal of the American Statistical Association* 36(215), 401-409, DOI
`10.1080/01621459.1941.10500577`. The article body is not claimed as
completely read.

Hart and Martinez, `spgs` 1.0-4, CRAN public mirror commit
`987257510f8b2a7ffe903d6b840021befbb4de58`.

Canonical bounded packet:
`strategy-seeds/sources/MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026/source.md`.
The sources supply WTI monthly-continuation lineage and the strict turning-
point definition with iid null moments. They do not test this thirteen-
endpoint, below-mean CFD trading conjunction.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes, legacy news,
and Friday close are OFF. Maximum entry spread is 1,500 points.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deployment, portfolio admission, portfolio-gate
change, tie tolerance, dynamic boundary, retry, scale-in, grid, martingale,
target, trail, break-even move, or partial exit.

## 8. Deterministic Failure Contract

The month is durably consumed before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order checks. Missing/duplicate month keys,
mixed label conventions, stale endpoints, nonpositive/nonfinite/equal closes,
wrong endpoint count, turning-point count outside 0..11, or `TP >= 8` fails
flat. An order reject never retries the month. Lifecycle repair runs every
tick before entry-only gates and closes duplicate, malformed, wrong-side,
later-month, or stale owned exposure.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoints, strict local-extrema count, `3*TP<22`, endpoint direction,
  spread/quote/ATR/stop checks, and one fixed-risk request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, later-month exit, and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-26 | approved source build | G0-approved card and governed magic `411710000` |
