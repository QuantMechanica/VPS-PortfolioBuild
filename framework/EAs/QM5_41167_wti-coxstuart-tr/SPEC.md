# QM5_41167_wti-coxstuart-tr - Strategy Spec

**EA ID:** QM5_41167

**Slug:** `wti-coxstuart-tr`

**Strategy ID:** `MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026_S01`

**Source:** `MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-26

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker
month, reconstruct the latest close in each of the immediately prior
fourteen consecutive completed broker months. Require positive finite closes,
strictly increasing endpoint timestamps, an immediately prior newest
endpoint, and a newest endpoint no more than ten calendar days old. Apply one
label convention, raw or raw-plus-one-day, to the current bar and the entire
history package.

Take natural logs of the fourteen chronological closes. For `i=0..6`, compare
the disjoint pair `i` with `i+7`. Any zero or nonfinite difference consumes
the month flat. Buy when at least five differences are positive, sell when at
least five are negative, and consume a 4/3 split flat. A valid direction owns
one fixed-risk WTI position until the first later normalized broker month,
protected by a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 14 | consecutive completed month-end closes |
| `strategy_pair_count` | 7 | fixed disjoint half-sample pairs |
| `strategy_signs_required` | 5 | strict concordant signs required |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | raw current-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for one Q02 baseline. There is no optimization surface,
and sign magnitude or winning count beyond five cannot alter size.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411670000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe And Formula

```text
y[i] = ln(C[i]), i = 0..13
d[i] = y[i+7] - y[i], i = 0..6
BUY  iff all d are finite/nonzero and count(d > 0) >= 5
SELL iff all d are finite/nonzero and count(d < 0) >= 5
FLAT otherwise
```

The formation and decision cadence are monthly. The seven pairs use every
endpoint exactly once and each pair spans seven month indexes. The position
holds through Fridays and exits on the next broker-month boundary, with a
forty-day stale repair.

## 5. Expected Behaviour

- Pre-result density prior: five to eight completed WTI positions per full
  post-warm-up year; Q02 retires below five in any full year.
- Under a fair independent-sign thought experiment only, 58 of 128 sign
  vectors qualify, or 45.3125%, implying 5.4375 monthly decisions/year. This
  is not a WTI independence, significance, frequency, or profitability claim.
- Symmetric direct-WTI structural continuation; one consumed attempt per
  broker month and at most one owned position.
- Direct crude-oil exposure is mechanically distinct from the certified XAU,
  SP500, NDX, and XNG carriers; only Q09 may establish realized decorrelation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Cox, D. R., and Stuart, A. (1955), "Some Quick Sign Tests for Trend in
Location and Dispersion," *Biometrika* 42(1/2), 80-95, DOI
`10.1093/biomet/42.1-2.80`.

Official NIST Dataplot reference, "Cox Stuart Test."

Canonical bounded packet:
`strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md`.

The sources supply WTI monthly continuation and ordered half-sample sign-test
lineage. None tests this locked 14-endpoint, 5-of-7 CFD trading rule. Exact
sample, threshold, CFD mapping, risk, stop, spread cap, attempt, and lifecycle
are disclosed QM mechanizations.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes, legacy news,
and Friday close are OFF. Maximum entry spread is 1,500 points.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deployment, portfolio admission, portfolio-gate
change, current-month signal price, alternate pair, tie deletion, dynamic
threshold, fitted scale, retry, scale-in, grid, martingale, pyramid, target,
trail, break-even move, or partial exit.

## 8. Deterministic Failure Contract

The month is durably consumed before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order checks. Missing/duplicate month keys,
mixed label conventions, stale endpoints, nonpositive prices, nonfinite
logarithms, any tie, wrong pair/count, or 4/3 split fails flat. An order reject
never retries the month. Lifecycle repair runs every tick before entry-only
gates and closes duplicate, malformed, wrong-side, later-month, or stale
owned exposure.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoints, seven disjoint signs, strict 5-of-7 count, spread/quote/ATR/stop
  checks, and one fixed-risk request.
- trade_management: malformed or wrong-side repair, later-month exit, and
  stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-26 | approved source build | G0-approved card and governed magic `411670000` |
