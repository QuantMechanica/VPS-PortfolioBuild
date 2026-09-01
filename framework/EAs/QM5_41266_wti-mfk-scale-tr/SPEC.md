# QM5_41266_wti-mfk-scale-tr - Strategy Spec

**EA ID:** QM5_41266

**Slug:** `wti-mfk-scale-tr`

**Strategy ID:** `AI-CODEX-WTI-MFK-SCALE-20260901_S01`

**Source:** `AI-CODEX-WTI-MFK-SCALE-20260901`

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
load thirteen consecutive completed month-end closes and form twelve adjacent
log returns. Keep the oldest six and newest six as fixed groups. Center each
group on its own even median, pool the twelve absolute deviations, assign
anchored relative-tolerance midranks, and map the ranks to the 23 locked
positive normal scores used by the median form of the Fligner-Killeen scale
statistic.

Qualify only when the recent group's mean normal score strictly exceeds the
older group's mean beyond the locked relative tolerance. Continue the sign of
the actual recent six-return sum for one broker month. The statistic is a
finite arithmetic invariant and diagnostic; there is no probability lookup or
significance threshold.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_return_count` | 12 | adjacent monthly log returns |
| `strategy_block_size` | 6 | fixed old and recent group size |
| `strategy_score_table_size` | 23 | integer/half-rank normal-score map |
| `strategy_relative_epsilon` | 1e-12 | anchored ties, scale comparison, and side band |
| `strategy_min_score_variance` | 1e-18 | statistic denominator floor |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |
| `strategy_deviation_points` | 20 | framework execution deviation lock |

There is one Q02 baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; governed magic: `412660000`.
- Runtime inputs are MT5-native prices, calendar, ATR, quote, position, deal,
  and terminal-persistent attempt state.
- There is no companion, conversion, hedge, external feed, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. The current broker month
is excluded.

```text
r[i] = log(C[i+1] / C[i]), i=0..11
old = r[0..5]; recent = r[6..11]

m_old = (sort(old)[2] + sort(old)[3]) / 2
m_recent = (sort(recent)[2] + sort(recent)[3]) / 2
z_old[i] = abs(old[i] - m_old)
z_recent[i] = abs(recent[i] - m_recent)

sort pooled z ascending
form each tie run against that run's first value with
    abs(candidate-anchor) <= 1e-12*max(1,abs(anchor),abs(candidate))
assign occupied midrank R; require 12 assignments and sum(R)=78
a(R) = Phi^-1(0.5 + R/26), by locked table only

A_old = mean(a_old); A_recent = mean(a_recent); A_all = mean(all a)
s2 = sum((a-A_all)^2)/11; require s2 > 1e-18
X2 = 6*((A_old-A_all)^2 + (A_recent-A_all)^2)/s2
require finite X2

scale_tol = 1e-12*max(1,abs(A_old),abs(A_recent))
require A_recent > A_old + scale_tol
recent_return = sum(r[6..11])
BUY if recent_return > 1e-12
SELL if recent_return < -1e-12
FLAT otherwise
```

All arithmetic must be finite. A malformed endpoint, broken rank invariant,
degenerate score variance, tied/non-expanding score means, or neutral recent
return consumes the month flat. Ties are valid and receive anchored midranks.

## 5. Expected Behaviour

Equal-block label symmetry puts 462 of 924 distinct-rank allocations in the
recent-mean-above-old state before deviation ties, neutral direction,
market-data, and execution gates. This is a pre-result activity prior, not a
performance or significance claim. Q02 must establish at least five completed
positions in every full post-warm-up year or the candidate retires.

### Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
One qualified month may open at most one position with a frozen completed-bar
`3.5*ATR(20,D1)` broker hard stop and no target. Both news axes, legacy news,
and Friday close are disabled.

### Exit and failure contract

An owned position closes on the first tick in a later normalized broker month
or after forty calendar days. Duplicate, malformed, wrong-symbol, wrong-side,
or stopless exposure is repaired before entry-only gates. There is no target,
trail, break-even, partial close, scale-in, grid, martingale, pyramid,
opposite-signal exit, or same-month retry.

## 6. Source Citation

The governed source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MFK-SCALE-20260901/source.md`.
Fligner and Killeen (1976) identify the scale-test family; the pinned official
SciPy 1.18.0 documentation/source locks median centering, pooled midranks,
positive normal scores, and statistic arithmetic. Complete-read Moskowitz,
Ooi, and Pedersen (2012) evidence supports only WTI membership, monthly
cadence, and the broad own-return continuation carrier. The fixed six/six
sample, recent-only scale direction, cumulative-return side, CFD translation,
risk, stop, and lifecycle are disclosed pre-result QM synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_mfk_scale_tr_preallocation_dedup_20260901.json`.

### Non-duplicate boundary

Unlike `QM5_41261`, this build ranks group-median absolute deviations with
midrank normal scores and never ranks raw returns or enumerates a symmetric
score tail. Unlike `QM5_41250`, it preserves the observed group centers and
uses one pooled score path instead of recomputing MAD under every relabeling.
Unlike `QM5_41252`, it uses fixed monthly blocks rather than a 252-D1 variance
break search. Unlike `QM5_12567`, it is symmetric WTI scale-regime continuation
and contains no short-horizon XNG oscillator.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | 1,000 account-currency units per trade |

This build authorizes no live preset or deployment action. Retire on zero
positions, fewer than five in any full scored year, failed deterministic
fixtures, nonpositive governed economics, or any downstream gate failure. WTI
gaps, continuous-CFD roll/basis, financing, small-sample rank instability,
ties, and broker-month offsets remain material risks.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, magic, risk, news, Friday,
  stress, strategy locks, clock, history, and arithmetic validation.
- `trade_entry`: cached qualifying scale state, recent-return side,
  quote/spread/ATR/stop gates, and one fixed-risk WTI order.
- `trade_management`: malformed-position repair, next-month exit, and forty-day
  stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0-approved card; governed magic `412660000` |
