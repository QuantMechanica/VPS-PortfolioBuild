# QM5_41251_wti-mbrunner-shift-tr - Strategy Spec

**EA ID:** QM5_41251

**Slug:** `wti-mbrunner-shift-tr`

**Strategy ID:** `AI-CODEX-WTI-MBRUNNER-20260831_S01`

**Source:** `AI-CODEX-WTI-MBRUNNER-20260831`

**Author:** Codex

**Last revised:** 2026-08-31

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a normalized broker month,
reconstruct twenty-one consecutive completed broker-month-end closes. Convert
them to twenty chronological adjacent log returns. The first ten returns are
the fixed older sample and the last ten are the fixed recent sample.

Rank the old sample, recent sample, and pooled `old || recent` vector
independently, assigning exact average ranks to exact ties. Compute the
corrected Brunner-Munzel placement variances and studentized rank-shift score.
Buy when the recent distribution has a score at or above `+0.625`; sell at or
below `-0.625`; otherwise consume the month flat. The threshold is a fixed
trading score, not a statistical-significance claim, and never scales risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 20 | completed adjacent monthly log returns |
| `strategy_block_size` | 10 | fixed older and recent samples |
| `strategy_score_threshold` | `0.625` | inclusive absolute score boundary |
| `strategy_denominator_epsilon` | `1e-12` | degenerate-variance guard |
| `strategy_score_cap` | `1e6` | finite complete-separation limit |
| `strategy_history_bars` | 1200 | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | first-month-bar raw execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `412510000`.
- Native MT5 price, calendar, ATR, quote, position, deal, and persistent state
  are the only runtime inputs.
- There is no companion, conversion, ratio, hedge, external, or signal symbol.

## 4. Timeframe and Formula

The host, signal, and execution timeframe is D1. The clock fires only on the
first eligible D1 bar of a new normalized broker month and consumes only
completed prior-month endpoints.

```text
r[i] = log(C[i+1] / C[i]), i=0..19

old    = r[0..9]
recent = r[10..19]
pooled = old || recent

rank each vector independently with exact average ranks for exact ties
m_old    = mean(pooled_rank[0..9])
m_recent = mean(pooled_rank[10..19])

v_old = sum((pooled_rank[i] - rank_old[i]
             - m_old + 5.5)^2 for i=0..9) / 9
v_recent = sum((pooled_rank[10+i] - rank_recent[i]
                - m_recent + 5.5)^2 for i=0..9) / 9

numerator   = 100 * (m_recent - m_old) / 20
denominator = sqrt(10*v_old + 10*v_recent)

if denominator > 1e-12:
    score = numerator / denominator
else if m_recent - m_old > 1e-12:
    score = +1e6
else if m_recent - m_old < -1e-12:
    score = -1e6
else:
    FLAT

BUY  iff score >= +0.625
SELL iff score <= -0.625
FLAT otherwise
```

Every endpoint, ratio, logarithm, return, rank, mean, variance component,
numerator, denominator, and score must be finite. Exact ties receive average
ranks without jitter. The EA computes no p-value, degrees of freedom, or
confidence interval.

## 5. Expected Behaviour

The exact pre-data allocation count for distinct pooled ranks is
`97,078 / 184,756 = 52.5439%`, approximately 6.305 qualified monthly clocks
per twelve attempts. This is a combinatorial prior, not a WTI result. Q02 must
prove at least five completed positions in every full post-warm-up year.

### Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
A qualified month can open at most one market position, with a frozen
completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. The EA rejects
malformed or crossed quotes, invalid point metadata, and a spread above 1,500
points; a valid modeled zero spread is allowed.

Both news axes and legacy news are OFF. Friday close is disabled so an open
position can retain the approved monthly holding period.

### Exit and deterministic failure contract

An owned position closes on the first tick in a later normalized broker month
or after forty calendar days. Duplicate, malformed, wrong-symbol, wrong-side,
missing-stop, or otherwise invalid owned exposure is repaired before entry-
only gates. There is no target, trail, break-even, partial close, same-month
retry, scale-in, grid, martingale, pyramid, or opposite-signal exit.

The month attempt is persisted before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order gates. A failed gate never causes a late
retry.

## 6. Source Citation

The governed packet is
`strategy-seeds/sources/AI-CODEX-WTI-MBRUNNER-20260831/source.md`. It records
complete-read peer-reviewed WTI monthly-continuation evidence, the
peer-reviewed Brunner-Munzel method record, the official CRAN manual, and a
pinned corrected `lawstat` implementation. The exact trading conjunction and
threshold remain explicitly untested synthesis.

Preallocation receipt:
`artifacts/qm5_wti_mbrunner_shift_tr_preallocation_dedup_20260831.json`.
### Non-duplicate boundary

No exact identity was found across 4,750 registry rows, 1,388 cards, and 45
Strategy Wiki nodes. Unlike Welch `QM5_41249`, this score uses ranks and
separate rank-placement variances; unlike permutation-MAD `QM5_41250`, it
tests stochastic ordering without runtime relabeling; unlike Mann-Whitney,
KS, or Pettitt families, it studentizes the relative effect at one fixed
ten-by-ten split. Certified `QM5_12567` is an XNG long-only oscillator
pullback. No realized decorrelation claim is made; Q09 alone owns that test.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |

The Q02 preset seals the fixed-risk row above. This build authorizes no live
preset or deployment action.

Retire on zero positions, fewer than five in any full scored year,
nonpositive governed economics, or deterministic-fixture failure. WTI gaps,
continuous-CFD roll/basis, financing, small-sample ranks, ties, complete
separation, and broker month-label offsets remain material risks.

Fail on current-month leakage, wrong return order or block membership, wrong
average ranks, pooled orientation, placement variance, degeneracy handling,
inclusive boundary, fixed-risk mode, hard stop, lifecycle, or determinism.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, risk, news, Friday, stress,
  strategy locks, clock, history, and arithmetic validation.
- `trade_entry`: cached qualified direction, quote/spread/ATR/stop gates, and
  one fixed-risk WTI order.
- `trade_management`: malformed/wrong-side repair, next-month exit, and stale
  exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magic `412510000` |
