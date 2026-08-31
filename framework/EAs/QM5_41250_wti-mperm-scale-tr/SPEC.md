# QM5_41250_wti-mperm-scale-tr - Strategy Spec

**EA ID:** QM5_41250

**Slug:** `wti-mperm-scale-tr`

**Strategy ID:** `AI-CODEX-WTI-MPERMSCALE-20260831_S01`

**Source:** `AI-CODEX-WTI-MPERMSCALE-20260831`

**Author:** Codex

**Last revised:** 2026-08-31

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a normalized broker month,
reconstruct thirteen consecutive completed broker-month-end closes. Convert
them into twelve chronological adjacent log returns. The first six returns
form the fixed older sample and the last six form the fixed recent sample.

For each block, calculate the even-sample median as the average of sorted
values three and four, then calculate the median of the six absolute
deviations from that center. Require the recent MAD to exceed the older MAD
by more than `1e-12`. Enumerate every `C(12,6)=924` assignment of six returns
to a pseudo-recent block and its complement to pseudo-old, recomputing the MAD
difference each time. Count inclusively every permuted difference at least as
large as the observed difference, with a `1e-14` comparison tolerance.

Qualify only when that upper-tail count is at most `416`. Buy when the actual
recent-block arithmetic mean is above `1e-12`; sell when it is below
`-1e-12`. Every other outcome consumes the month flat. This is a fixed trading
score, not a statistical-significance claim.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 12 | completed adjacent monthly log returns |
| `strategy_block_size` | 6 | fixed older and recent samples |
| `strategy_scale_epsilon` | `1e-12` | strict positive MAD-expansion guard |
| `strategy_compare_tolerance` | `1e-14` | conservative inclusive tail comparison |
| `strategy_tail_count_max` | 416 | qualifying upper-tail count ceiling |
| `strategy_direction_epsilon` | `1e-12` | recent-mean direction tolerance |
| `strategy_history_bars` | 900 | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | first-month-bar raw execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |

There is one Q02 baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `412500000`.
- Native MT5 price, calendar, ATR, quote, position, deal, and persistent state
  are the only runtime inputs.
- There is no companion, conversion, ratio, hedge, external, or signal symbol.

## 4. Timeframe

The host, signal, and execution timeframe is D1. The decision clock fires only
on the first eligible D1 bar of a new normalized broker month and consumes
only completed prior-month endpoints; there are no secondary timeframes.

### Formula

```text
r[i] = log(C[i+1] / C[i]), i=0..11

old    = r[0..5]
recent = r[6..11]

median6(x) = (sort(x)[2] + sort(x)[3]) / 2
mad6(x) = median6(abs(x - median6(x)))

observed = mad6(recent) - mad6(old)
require observed > 1e-12

tail_count = 0
assignment_count = 0
for every 12-bit mask with exactly six set bits:
    pseudo_recent = selected returns
    pseudo_old = complement returns
    perm_delta = mad6(pseudo_recent) - mad6(pseudo_old)
    if perm_delta >= observed - 1e-14:
        tail_count += 1
    assignment_count += 1

require assignment_count == 924
require tail_count <= 416

mean_recent = sum(recent) / 6
BUY  iff mean_recent >  1e-12
SELL iff mean_recent < -1e-12
FLAT otherwise
```

Every endpoint, ratio, logarithm, return, sort input, median, deviation, MAD,
difference, counter, and mean must be finite and valid. Missing or duplicate
months, non-expansion, an assignment count other than 924, an excessive tail
count, zero recent mean, or arithmetic failure consumes the month flat. There
is no fitted split, sampled resampling, fallback estimator, or score-scaled
risk.

## 5. Expected Behaviour

The pre-result assignment-density prior is `416/924`, approximately 45.02%,
or roughly five to six completed positions per full post-warm-up year, with at
most one consumed attempt per broker month. A qualifying scale expansion is
held into the next broker month unless the hard stop or forty-day survivor
repair closes it first. Both long and short regimes are eligible; Q02 must
prove at least five positions in every full scored year.

### Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualifying month can open at most one market position,
with a frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and no target.
The EA rejects malformed/crossed quotes, invalid point metadata, and a spread
above 1,500 points; a valid modeled zero spread is allowed.

Both news axes and legacy news are OFF. Friday close is disabled so a position
can retain the approved monthly holding period.

### Exit and deterministic failure contract

An owned position closes on the first tick in a later normalized broker month
or after forty calendar days. Duplicate, malformed, wrong-symbol, wrong-side,
missing-stop, or otherwise invalid owned exposure is repaired before entry-
only gates. There is no target, trail, break-even, partial close, same-month
retry, scale-in, grid, martingale, pyramid, or opposite-signal exit.

The broker-month attempt is persisted before history, arithmetic, news,
spread, quote, ATR, sizing, margin, or order gates. A failed gate never causes
a late retry.

## 6. Source Citation

The governed source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MPERMSCALE-20260831/source.md`. It records
the complete Moskowitz, Ooi, and Pedersen (2012) WTI monthly-continuation
evidence and the explicitly untested exact-permutation robust-scale trading
synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_mperm_scale_tr_preallocation_dedup_20260831.json`, SHA-256
`133C36BA2F3B6CA20F658794A67CAD7A5277B8A454903A3C52F1D545D7928D4D`.
The checker found no exact identity and one expected fuzzy Welch neighbor at
score `0.53`. This edge qualifies on robust dispersion and all 924 fixed-size
label assignments. The Welch neighbor qualifies on a standardized arithmetic-
mean shift; nested VoV, monthly OHLC range, and per-month L2-normalized WTI
families retain different state objects. No realized decorrelation claim is
made; Q09 alone may establish portfolio overlap.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

Environment-to-mode validation is enforced by `QM_FrameworkInit`; the Q02
preset explicitly seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This build does not authorize any live preset.

### Kill criteria and risks

Q02 retires on zero positions, fewer than five in any full year, nonpositive
governed economics, or any deterministic-fixture failure. Continuous-CFD
roll/basis, financing, gaps, small-sample robust-scale instability,
permutation ties, and broker month-label offsets remain material risks.

Fail on current-month leakage, wrong return order or block membership, wrong
even-sample median or MAD, missing/duplicate label assignments, wrong
inclusive comparison or tolerance, wrong `416` cap, wrong recent-mean side,
missing hard stop, same-month retry, invalid risk mode, or nondeterminism.

## Framework alignment

- `no_trade`: exact host, period, identity, slot, risk, news, Friday, stress,
  and strategy locks.
- `trade_entry`: consumed month, consecutive completed endpoints, exact
  median/MAD scale state, complete 924-label enumeration, cached side,
  quote/spread/ATR/stop guards, and one fixed-risk order.
- `trade_management`: malformed/wrong-side repair, next-month exit, and stale
  exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magic `412500000` |
