# QM5_41261_wti-mab-scale-tr - Strategy Spec

**EA ID:** QM5_41261

**Slug:** `wti-mab-scale-tr`

**Strategy ID:** `AI-CODEX-WTI-MAB-SCALE-20260901_S01`

**Source:** `AI-CODEX-WTI-MAB-SCALE-20260901`

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
load thirteen consecutive completed month-end closes and form twelve adjacent
log returns. The oldest six and newest six returns are fixed samples.

Sort the twelve pairwise-distinct returns while retaining old/recent labels.
Assign symmetric end-rank scores `1,2,3,4,5,6,6,5,4,3,2,1` and sum the scores
carried by actual recent labels. Enumerate all 924 six-of-twelve label
assignments and count scores no greater than the observed score. A score of 21
or less and inclusive lower-tail count of 522 or less defines the locked state.
Continue the sign of the actual recent six-return cumulative move; consume flat
inside the `1e-12` direction band. The boundary is an activity setting, not a
statistical-significance claim.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_return_count` | 12 | adjacent monthly log returns |
| `strategy_block_size` | 6 | fixed old and recent sample size |
| `strategy_assignment_count` | 924 | complete six-of-twelve label space |
| `strategy_score_max` | 21 | inclusive observed symmetric-score cap |
| `strategy_tail_count_max` | 522 | inclusive exact lower-tail cap |
| `strategy_direction_epsilon` | 1e-12 | neutral recent-return band |
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
- Symbol slot: 0; governed magic: `412610000`.
- Runtime inputs are MT5-native prices, calendar, ATR, quote, position, deal,
  and terminal-persistent attempt state.
- There is no companion, conversion, hedge, external feed, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. The current broker month
is excluded.

```text
r[i] = log(C[i+1] / C[i]), i=0..11
old = r[0..5]; recent = r[6..11]
require strict pooled uniqueness

sort pooled returns ascending with labels retained
score(rank j) = min(j, 13-j), j=1..12
A_recent = sum(score(j) for actual recent-label ranks)

for every 12-bit mask with six set bits:
    A_perm = sum(score(j) for set-bit ranks)
    tail += (A_perm <= A_recent)

require assignments == 924
require A_recent <= 21 and tail <= 522
recent_return = sum(r[6..11])
BUY if recent_return > 1e-12
SELL if recent_return < -1e-12
FLAT otherwise
```

All arithmetic must be finite. A tie, malformed endpoint, wrong enumeration,
excessive score/tail, or neutral direction consumes the month flat.

## 5. Expected Behaviour

Exact enumeration gives 522 rank assignments at or below score 21 out of 924,
or about 6.779 qualifying states per twelve attempts before the direction,
market-data, and execution gates. Q02 must establish at least five completed
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
`strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/source.md`. Ansari and
Bradley (1960) identify the rank procedure; the pinned SciPy 1.13.1 official
implementation evidence locks pooled ranks, symmetric scores, direction, and
the small-sample no-tie exact route. Complete-read Moskowitz, Ooi, and Pedersen
(2012) evidence supports only WTI membership, monthly cadence, and own-return
continuation. The `21/522` activity boundary, CFD translation, fixed risk,
stop, and lifecycle are disclosed pre-result QM synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_mab_scale_tr_preallocation_dedup_20260901.json`.

### Non-duplicate boundary

Unlike `QM5_41250`, this build is invariant to within-rank magnitude and does
not compare block median absolute deviations. Unlike `QM5_41252`, it uses
twelve completed monthly returns rather than a 252-D1 cumulative-squared-sum
variance break. Unlike `QM5_41257`, it uses the complete symmetric score path
rather than only an upper-half label count. Unlike `QM5_41176`, it does not
use the 36 cross-block Wilcoxon wins.

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
- `trade_entry`: cached qualifying symmetric-rank state, recent-return side,
  quote/spread/ATR/stop gates, and one fixed-risk WTI order.
- `trade_management`: malformed-position repair, next-month exit, and forty-day
  stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0-approved card; governed magic `412610000` |
