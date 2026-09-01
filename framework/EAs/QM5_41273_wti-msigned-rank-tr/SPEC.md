# QM5_41273_wti-msigned-rank-tr - Strategy Spec

**EA ID:** QM5_41273

**Slug:** `wti-msigned-rank-tr`

**Strategy ID:** `AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901_S01`

**Source:** `AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901`

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
load thirteen consecutive completed month-end closes and form twelve adjacent
log returns. Reject any zero return inside `1e-12` or any pair of absolute
returns tied inside that epsilon.

Rank the twelve absolute returns strictly from 1 through 12. Let `V_plus` be
the sum of ranks carried by positive returns, `T=78`, and
`S=2*V_plus-T`. Buy at `S>=18`, sell at `S<=-18`, and consume all other
states flat. The centered signed-rank score is a structural state, not a
p-value or a statistical-significance claim.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_return_count` | 12 | adjacent monthly log returns |
| `strategy_total_rank_sum` | 78 | locked sum of strict ranks 1..12 |
| `strategy_score_abs_min` | 18 | inclusive centered-score boundary |
| `strategy_zero_epsilon` | 1e-12 | zero and absolute-tie tolerance |
| `strategy_history_bars_d1` | 1200 | bounded endpoint reconstruction |
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
- Symbol slot: 0; governed magic: `412730000`.
- Runtime inputs are MT5-native prices, calendar, ATR, quote, position, deal,
  and terminal-persistent attempt state.
- There is no companion, conversion, hedge, external feed, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. The current broker month
is excluded.

```text
r[i] = log(C[i+1] / C[i]), i=0..11
require finite r[i] and abs(r[i]) > 1e-12
require abs(abs(r[i])-abs(r[j])) > 1e-12 for every i != j

rank[i] = strict ascending rank of abs(r[i]) in 1..12
require sum(rank) == 78
V_plus = sum(rank[i] where r[i] > 0)
S = 2*V_plus - 78

BUY  if S >= 18
SELL if S <= -18
FLAT otherwise
```

All arithmetic must be finite. A zero, absolute tie, malformed endpoint,
broken rank invariant, or sub-threshold score consumes the month flat.

## 5. Expected Behaviour

Exact enumeration of all 4,096 sign assignments gives 1,062 long and 1,062
short states at the inclusive absolute-18 boundary: 2,124/4,096, or
6.22265625 market-free states per twelve attempts. Q02 must establish at least
five completed positions in every full post-warm-up year or the candidate
retires.

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
`strategy-seeds/sources/AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901/source.md`.
Complete-read Moskowitz, Ooi, and Pedersen (2012) evidence supports only WTI
membership, monthly cadence, and own-return continuation through twelve lags.
The complete pinned R Core `wilcox.test` implementation and manual at commit
`bac583951b728e97b9786804d3b4081f0fe18df5` support only one-sample signed
absolute-rank arithmetic. The strict zero/tie rules, centered score, inclusive
absolute-18 activity boundary, CFD translation, fixed risk, stop, and lifecycle
are disclosed pre-result QM synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_msigned_rank_tr_preallocation_dedup_20260901.json`.

### Non-duplicate boundary

- `QM5_41191` uses 5-10 disjoint prior-year same-calendar returns and any
  nonzero score; this build uses the latest twelve contiguous returns and
  requires `|S|>=18`.
- Eleven positive returns `0.01..0.11` plus `-1.00` produce `S=54` here while
  twelve-month cumulative return is negative, separating `QM5_12603`.
- Positive ranks `{7,10,11,12}` produce `S=2`, so a zero-threshold signed-rank
  rule buys while this build consumes flat.
- Positive ranks `1..7` and negative ranks `8..12` produce seven positive
  months but `S=-22`, separating sign-count logic.
- `QM5_41176` is a two-sample Mann-Whitney rank-sum construction, not this
  one-sample signed-rank functional.
- `QM5_12567` is a two-day long-only XNG pullback rule and shares no signal
  mechanic with this direct-WTI monthly long/short sleeve.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | 1,000 account-currency units per trade |

This build authorizes no live preset or deployment action. Retire on zero
positions, fewer than five in any full scored year, failed deterministic
fixtures, nonpositive governed economics, or any downstream gate failure. WTI
gaps, continuous-CFD roll/basis, financing, strict-rank instability, ties, and
broker-month offsets remain material risks.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, magic, risk, news, Friday,
  stress, strategy locks, support invariant, clock, history, and arithmetic.
- `trade_entry`: cached signed-rank side, quote/spread/ATR/stop gates, and one
  fixed-risk WTI order.
- `trade_management`: malformed-position repair, next-month exit, and forty-
  day stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0-approved card; governed magic `412730000` |
