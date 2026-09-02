# QM5_41284_wti-mfp-shift-tr - Strategy Spec

**EA ID:** QM5_41284

**Slug:** `wti-mfp-shift-tr`

**Strategy ID:** `AI-CODEX-WTI-MFP-SHIFT-20260902_S01`

**Source:** `AI-CODEX-WTI-MFP-SHIFT-20260902`

**Author:** Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a normalized broker month,
reconstruct twenty-one consecutive completed broker-month-end closes and
convert them to twenty chronological adjacent log returns. The first ten
returns are the fixed older sample and the final ten are the fixed recent
sample.

For each old value, count recent values below it plus half of exact ties. For
each recent value, count old values below it plus half of exact ties. Apply the
locked Fligner-Policello pair-placement dispersion formula. Buy when the recent
sample shift score is at or above `+0.600`; sell when it is at or below
`-0.600`; otherwise consume the month flat. This threshold is an activity
boundary, not a statistical-significance claim, and the score never scales
risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 20 | completed adjacent monthly log returns |
| `strategy_block_size` | 10 | fixed old and recent sample sizes |
| `strategy_score_threshold` | `0.600` | inclusive absolute score boundary |
| `strategy_denominator_epsilon` | `1e-12` | degenerate-denominator guard |
| `strategy_score_cap` | `1e6` | finite complete-separation limit |
| `strategy_history_bars` | 1200 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | first-month-bar raw execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `412840000`.
- Native MT5 price, calendar, ATR, quote, position, deal, and persistent state
  are the only runtime inputs.
- There is no companion, ratio, hedge, conversion, external, or signal symbol.

## 4. Timeframe and Formula

The host, signal, and execution timeframe is D1. The clock fires only on the
first eligible D1 bar of a new normalized broker month and uses only completed
prior-month endpoints.

```text
r[i] = log(C[i+1] / C[i]), i=0..19

old    = r[0..9]
recent = r[10..19]

p[i] = count(recent[j] < old[i]) + 0.5*count(recent[j] == old[i])
q[j] = count(old[i] < recent[j]) + 0.5*count(old[i] == recent[j])

p_bar = sum(p)/10
q_bar = sum(q)/10
v_p = sum((p[i]-p_bar)^2)
v_q = sum((q[j]-q_bar)^2)

numerator   = sum(q)-sum(p)
denominator = 2*sqrt(v_p+v_q+p_bar*q_bar)

if denominator > 1e-12:
    score = numerator/denominator
else if numerator > 0:
    score = +1e6
else if numerator < 0:
    score = -1e6
else:
    FLAT

BUY  iff score >= +0.600
SELL iff score <= -0.600
FLAT otherwise
```

Every endpoint, ratio, logarithm, return, placement, mean, dispersion,
product, numerator, denominator, and score must be finite. Exact cross-block
ties receive half credit without jitter. The EA computes no p-value,
resampling distribution, confidence interval, or raw-mean fallback.

## 5. Expected Behaviour

Exact pre-data enumeration of distinct pooled ranks qualifies
`97,616 / 184,756 = 52.8351%`, approximately 6.340 qualified monthly clocks
per twelve attempts. This is a combinatorial activity prior, not a WTI result.
Q02 must prove at least five completed positions in every full scored
post-warm-up year.

### Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
A qualified month can open at most one market position with a frozen completed-
bar `3.5*ATR(20,D1)` broker hard stop and no target. Malformed or crossed
quotes, invalid point metadata, and spreads above 1,500 points fail closed; a
valid modeled zero spread is allowed.

Both news axes and legacy news are OFF. Friday close is disabled so an open
position can retain the approved monthly holding period.

### Exit and deterministic failure contract

An owned position closes on the first processed tick in a later normalized
broker month or after forty calendar days. Duplicate, malformed, wrong-symbol,
wrong-side, missing-stop, or otherwise invalid owned exposure is repaired
before entry-only gates. There is no target, trail, break-even, partial close,
same-month retry, scale-in, grid, martingale, pyramid, or intramonth signal
exit.

The month attempt is persisted before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order gates. A failed gate never causes a late
retry.

## 6. Source Citation and Non-Duplicate Boundary

The governed packet is
`strategy-seeds/sources/AI-CODEX-WTI-MFP-SHIFT-20260902/source.md`. It records
complete-read peer-reviewed WTI monthly-continuation evidence, the peer-
reviewed Fligner-Policello method record with an explicit body-access boundary,
and the complete pinned CRAN NSM3 implementation. The exact ten-by-ten CFD
conjunction and threshold remain disclosed, untested QM synthesis.

The canonical preallocation receipt is
`artifacts/qm5_wti_mfp_shift_tr_preallocation_dedup_20260902.json`. It found no
exact identity. Unlike `QM5_41251`, this score uses direct p/q cross-block
placements and the `p_bar*q_bar` denominator term, not corrected Brunner-
Munzel pooled/within-rank variances. Fixed equal-Mann-Whitney-total fixtures
also cross the `0.600` boundary because placement dispersion differs.
Certified `QM5_12567` is an XNG long-only oscillator pullback. No realized
decorrelation claim is made; Q09 alone owns that test.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |

The Q02 preset seals the fixed-risk row above. This build authorizes no live,
demo, shadow, stress, or deployment preset.

Retire on zero positions, fewer than five completed positions in any full
scored post-warm-up year, nonpositive governed economics, or deterministic-
fixture failure. WTI gaps, continuous-CFD roll/basis, financing, small-sample
ranks, ties, complete separation, and broker month-label offsets remain
material risks.

Fail on current-month leakage, wrong return order or block membership,
incorrect tie credit, placements, means, dispersions, product term,
degeneracy, inclusive boundary, fixed-risk mode, hard stop, spread, lifecycle,
or determinism.

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
| v1 | 2026-09-02 | approved source build | G0-approved card; governed magic `412840000` |
