# QM5_41249_wti-mwelch-shift-tr - Strategy Spec

**EA ID:** QM5_41249

**Slug:** `wti-mwelch-shift-tr`

**Strategy ID:** `AI-CODEX-WTI-MWELCH-20260831_S01`

**Source:** `AI-CODEX-WTI-MWELCH-20260831`

**Author:** Codex

**Last revised:** 2026-08-31

## 1. Strategy logic

On the first executable `XTIUSD.DWX` D1 bar of a normalized broker month,
reconstruct thirteen consecutive completed broker-month-end closes. Convert
them into twelve chronological adjacent log returns. The first six returns
form the fixed older sample and the last six form the fixed recent sample.

Compute each arithmetic mean, each unbiased sample variance with denominator
five, and the unequal-variance standard-error term
`se2 = var_old/6 + var_recent/6`. The standardized mean-shift score is
`(mean_recent - mean_old) / sqrt(se2)`. Buy when the score is at least
`0.75` and the recent mean is above `1e-12`; sell when the score is at
most `-0.75` and the recent mean is below `-1e-12`. All other outcomes
consume the month flat.

## 2. Locked parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 12 | completed adjacent monthly log returns |
| `strategy_block_size` | 6 | fixed older and recent samples |
| `strategy_score_floor` | 0.75 | inclusive absolute score boundary |
| `strategy_zero_epsilon` | `1e-12` | recent-mean sign tolerance |
| `strategy_min_se2` | `1e-18` | degenerate denominator guard |
| `strategy_history_bars` | 900 | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | first-month-bar raw execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |

There is one Q02 baseline and no optimization surface.

## 3. Symbol and runtime

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `412490000`.
- Native MT5 price, calendar, ATR, quote, position, deal, and persistent state
  are the only runtime inputs.
- There is no companion, conversion, ratio, hedge, external, or signal symbol.

## 4. Formula

```text
r[i] = log(C[i+1] / C[i]), i=0..11

old    = r[0..5]
recent = r[6..11]

mean_old    = sum(old) / 6
mean_recent = sum(recent) / 6

var_old    = sum((old[i]    - mean_old)^2) / 5
var_recent = sum((recent[i] - mean_recent)^2) / 5

se2 = var_old/6 + var_recent/6
score = (mean_recent - mean_old) / sqrt(se2)

BUY  iff se2 > 1e-18 and score >=  0.75 and mean_recent >  1e-12
SELL iff se2 > 1e-18 and score <= -0.75 and mean_recent < -1e-12
FLAT otherwise
```

Every endpoint, ratio, logarithm, return, sum, mean, centered difference,
square, variance, `se2`, square root, and score must be finite. Missing or
duplicate months, degenerate variance, a boundary miss, sign disagreement, a
zero recent mean, or arithmetic failure consumes the month flat. There is no
p-value, degrees-of-freedom calculation, fitted split, pooled variance,
fallback estimator, or score-scaled risk.

## 5. Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualifying month can open at most one market
position, with a frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and
no target. The EA rejects malformed/crossed quotes, invalid point metadata,
and a spread above 1,500 points; a valid modeled zero spread is allowed.

Both news axes and legacy news are OFF. Friday close is disabled so a position
can retain the approved monthly holding period.

## 6. Exit and deterministic failure contract

An owned position closes on the first tick in a later normalized broker month
or after forty calendar days. Duplicate, malformed, wrong-symbol, wrong-side,
missing-stop, or otherwise invalid owned exposure is repaired before
entry-only gates. There is no target, trail, break-even, partial close,
same-month retry, scale-in, grid, martingale, pyramid, or opposite-signal exit.

The broker-month attempt is persisted before history, arithmetic, news,
spread, quote, ATR, sizing, margin, or order gates. A failed gate never causes
a late retry.

## 7. Evidence and non-duplication

The governed source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MWELCH-20260831/source.md`. It records
the complete Moskowitz, Ooi, and Pedersen (2012) WTI monthly-continuation
evidence, Welch (1938) peer-reviewed unequal-variance method lineage, the
complete official SciPy 1.18.0 method documentation, and the explicitly
untested QM trading synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_mwelch_shift_tr_preallocation_dedup_20260831.json`,
SHA-256
`418F80E037B15060AA00B11736783446818B7AAA892B49EF9C9F9A95B0777D67`.
This edge fixes two six-return samples and compares magnitude-bearing means
with separate magnitude-bearing variances. Nearby WTI builds instead use
price ranks, fixed ECDF gaps, label runs, a daily median, or an endogenous
centered CUSUM split. No realized decorrelation claim is made; Q09 alone may
establish portfolio overlap.

## 8. Expected behavior and kill criteria

The pre-result cadence prior is five to nine completed positions per full
post-warm-up year. Q02 retires on zero positions, fewer than five in any full
year, nonpositive governed economics, or any deterministic-fixture failure.
Continuous-CFD roll/basis, financing, gaps, six-observation variance
instability, and broker month-label offsets remain material risks.

## Framework alignment

- `no_trade`: exact host, period, identity, slot, risk, news, Friday, stress,
  and strategy locks.
- `trade_entry`: consumed month, consecutive completed endpoints, exact
  fixed-block Welch score, cached side, quote/spread/ATR/stop guards, and one
  fixed-risk order.
- `trade_management`: malformed/wrong-side repair, next-month exit, and
  stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magic `412490000` |
