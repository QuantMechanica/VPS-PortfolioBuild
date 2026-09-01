# QM5_41267_wti-mmood-scale-tr - Strategy Spec

**EA ID:** QM5_41267

**Slug:** `wti-mmood-scale-tr`

**Strategy ID:** `AI-CODEX-WTI-MMOOD-SCALE-20260901_S01`

**Source:** `AI-CODEX-WTI-MMOOD-SCALE-20260901`

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker
month, load thirteen consecutive completed month-end closes and form twelve
adjacent chronological log returns. Preserve the oldest six and newest six as
fixed groups. Pool the twelve raw returns, sort them, reject every anchored
relative-tolerance tie, and assign unique integer ranks 1 through 12 back to
the original observations.

Compute the older group's locked Mood squared-rank score around rank center
6.5. Qualify the recent scale state only when that older score is at or below
its fixed null expectation of 71.5. Continue the sign of the actual recent
six-return sum for one broker month. The standardized statistic uses fixed
variance 364 and is a finite arithmetic diagnostic only; no distribution,
probability, or significance threshold enters the signal.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_return_count` | 12 | adjacent monthly log returns |
| `strategy_block_size` | 6 | fixed old and recent group size |
| `strategy_rank_center` | 6.5 | pooled-rank squared-score center |
| `strategy_score_expectation` | 71.5 | fixed old-block score expectation and inclusive gate |
| `strategy_score_variance` | 364 | fixed score variance for the diagnostic |
| `strategy_relative_epsilon` | 1e-12 | anchored tie and direction tolerance |
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
- Symbol slot: 0; governed magic: `412670000`.
- Runtime inputs are MT5-native prices, calendar, ATR, quote, position, deal,
  and terminal-persistent attempt state.
- There is no companion, conversion, hedge, external feed, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. The current broker month
is excluded.

```text
r[i] = log(C[i+1] / C[i]), i=0..11
old = r[0..5]; recent = r[6..11]

sort all twelve raw returns ascending
for each sorted run, compare candidates only with that run's first value
tie iff abs(candidate-anchor) <= 1e-12*max(1,abs(anchor),abs(candidate))
reject any tie
assign unique integer ranks R=1..12 to original observations
require 12 assignments, 12 unique ranks, and sum(R)=78

M_old = sum((R_old-6.5)^2)
E0 = 71.5
Var0 = 364
z = (M_old-E0)/sqrt(Var0)
require finite z

require M_old <= E0
recent_return = sum(r[6..11])
BUY if recent_return > 1e-12
SELL if recent_return < -1e-12
FLAT otherwise
```

All arithmetic must be finite. A malformed endpoint, duplicate rank, failed
rank invariant, tied return, score above expectation, or neutral recent return
consumes the month flat. The inclusive `M_old<=71.5` comparison is exact;
the epsilon applies only to anchored tie detection and direction neutrality.

## 5. Expected Behaviour

Across all 924 allocations of six unique ranks to the old group, 426 have
`M_old<71.5`, 72 equal 71.5, and 426 exceed it. The inclusive state therefore
qualifies 498 allocations before neutral direction, market-data, and execution
gates. This is a combinatorial activity prior, not a market or performance
result. Q02 must establish at least five completed positions in every full
post-warm-up year or the candidate retires.

### Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. One qualified month may open at most one position with
a frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. Both
news axes, legacy news, and Friday close are disabled.

The normalized month key is persisted before history, arithmetic, news,
spread, quote, ATR, sizing, margin, or order checks. Any rejection still
consumes the month and cannot be retried after restart.

### Exit and failure contract

An owned position closes on the first processed tick in a later normalized
broker month or after forty elapsed calendar days. Duplicate, malformed,
wrong-symbol, wrong-side, or stopless exposure is repaired before entry-only
gates. There is no target, trail, break-even, partial close, scale-in, grid,
martingale, pyramid, opposite-signal exit, or same-month retry.

## 6. Source Citation

The governed source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MMOOD-SCALE-20260901/source.md`.
Mood (1954) identifies the named nonparametric two-sample scale method. The
signed-tag-pinned official SciPy 1.18.0 documentation and source lock the
no-tie pooled squared-rank score, expectation, variance, and standardized
arithmetic. Complete-read Moskowitz, Ooi, and Pedersen (2012) evidence
supports only WTI membership, monthly cadence, and the broad own-return
continuation carrier. The fixed six/six sample, tie rejection, inclusive
score-center gate, cumulative-return side, CFD translation, risk, stop, and
lifecycle are disclosed pre-result QM synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_mmood_scale_tr_preallocation_dedup_20260901.json`.

### Non-duplicate boundary

Unlike `QM5_41261`, this build uses one squared-distance score over pooled
raw-return integer ranks and no symmetric end-rank weights or exact label
tail. Unlike `QM5_41266`, it does not center blocks, rank absolute
deviations, or map midranks to normal scores. Unlike `QM5_41250`, it does
not recompute block MAD under every relabeling. Unlike `QM5_41252`, it uses
fixed monthly blocks rather than a 252-D1 variance break search. Unlike
`QM5_12567`, it is symmetric WTI scale-regime continuation and contains no
short-horizon XNG oscillator.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | 1,000 account-currency units per trade |

This build authorizes no live preset or deployment action. Retire on zero
positions, fewer than five in any full scored year, failed deterministic
fixtures, nonpositive governed economics, or any downstream gate failure.
WTI gaps, continuous-CFD roll/basis, financing, small-sample rank instability,
ties, and broker-month offsets remain material risks.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, magic, risk, news, Friday,
  stress, strategy locks, clock, history, and arithmetic validation.
- `trade_entry`: cached qualifying Mood state, recent-return side,
  quote/spread/ATR/stop gates, and one fixed-risk WTI order.
- `trade_management`: malformed-position repair, next-month exit, and
  forty-day stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0-approved card; governed magic `412670000` |
