# QM5_41271_wti-msiegel-tukey-scale-tr - Strategy Spec

**EA ID:** QM5_41271

**Slug:** `wti-msiegel-tukey-scale-tr`

**Strategy ID:** `AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901_S01`

**Source:** `AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901`

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
load seventeen consecutive completed month-end closes and form sixteen
adjacent log returns. The oldest eight and newest eight returns are fixed
samples.

Sort the sixteen pairwise-distinct returns while retaining old/recent labels.
Following the NIST Siegel-Tukey prescription, assign consecutive ranks by
alternating between pooled extremes. In ascending-value order the locked path
is `1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2`. Sum scores carried by actual
recent labels, enumerate all 12,870 eight-of-sixteen label assignments, and
count scores no greater than observed. Score 68 or less and inclusive lower-
tail count 6,698 or less define the locked state.

Continue the sign of the actual recent eight-return cumulative move; consume
flat inside the `1e-12` direction band. The exact half-support boundary is an
activity setting, not a statistical-significance claim.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 17 | consecutive completed month-end closes |
| `strategy_return_count` | 16 | adjacent monthly log returns |
| `strategy_block_size` | 8 | fixed old and recent sample size |
| `strategy_assignment_count` | 12870 | complete eight-of-sixteen label space |
| `strategy_score_max` | 68 | inclusive observed Siegel-Tukey score cap |
| `strategy_tail_count_max` | 6698 | inclusive exact lower-tail cap |
| `strategy_direction_epsilon` | 1e-12 | neutral recent-return band |
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
- Symbol slot: 0; governed magic: `412710000`.
- Runtime inputs are MT5-native prices, calendar, ATR, quote, position, deal,
  and terminal-persistent attempt state.
- There is no companion, conversion, hedge, external feed, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. The current broker month
is excluded.

```text
r[i] = log(C[i+1] / C[i]), i=0..15
old = r[0..7]; recent = r[8..15]
require strict pooled uniqueness

sort pooled returns ascending with labels retained
scores = 1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2
S_recent = sum(scores occupied by actual recent labels)

for every 16-bit mask with eight set bits:
    S_perm = sum(scores occupied by set-bit ranks)
    tail += (S_perm <= S_recent)

require assignments == 12870
require S_recent <= 68 and tail <= 6698
recent_return = sum(r[8..15])
BUY if recent_return > 1e-12
SELL if recent_return < -1e-12
FLAT otherwise
```

All arithmetic must be finite. A tie, malformed endpoint, wrong score path or
enumeration, excessive score/tail, or neutral direction consumes the month
flat.

## 5. Expected Behaviour

Exact enumeration gives 6,698 rank assignments at or below score 68 out of
12,870, or about 6.245 qualifying states per twelve attempts before direction,
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
`strategy-seeds/sources/AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901/source.md`.
Siegel and Tukey (1960) identify the peer-reviewed relative-spread method; the
complete official NIST Dataplot page locks the pooled ordering, alternating-
extremes ranks, and rank-sum reduction. Complete-read Moskowitz, Ooi, and
Pedersen (2012) evidence supports only WTI membership, monthly cadence, and
broad own-return continuation. The `68/6698` activity boundary, CFD
translation, fixed risk, stop, and lifecycle are disclosed pre-result QM
synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_msiegel_tukey_scale_tr_preallocation_dedup_20260901.json`.

### Non-duplicate boundary

The sole fuzzy neighbor, `QM5_41261`, uses twelve returns, six-by-six blocks,
mirrored Ansari-Bradley scores, 924 assignments, and `21/522`. This build uses
sixteen returns, eight-by-eight blocks, non-mirrored alternating-extremes
scores, 12,870 assignments, and `68/6698`. Reference fixtures prove both
decision-disagreement directions with positive recent returns.

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
- `trade_entry`: cached qualifying Siegel-Tukey state, recent-return side,
  quote/spread/ATR/stop gates, and one fixed-risk WTI order.
- `trade_management`: malformed-position repair, next-month exit, and forty-
  day stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0-approved card; governed magic `412710000` |
