# QM5_41274_wti-m3block-rank-tr - Strategy Spec

**EA ID:** QM5_41274

**Slug:** `wti-m3block-rank-tr`

**Strategy ID:** `AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901_S01`

**Source:** `AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901`

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
reconstruct the immediately completed month. Require 17 through 23 completed
sessions and select its final fifteen closes in chronological order. Divide
those closes into three fixed five-session blocks.

Reject any pair of closes separated by no more than `0.5 * SYMBOL_POINT`.
For every earlier-block/later-block pair, count a win when the later close is
higher. The three block pairs contribute 25 comparisons each, so `N=75`.
Buy when `2*W>75` and sell when `2*W<75`. The odd center and even doubled win
count make a valid strict-order state directional. This is a structural
classifier, not a significance test.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_sessions_min` | 17 | completed-month session floor |
| `strategy_month_sessions_max` | 23 | completed-month session ceiling |
| `strategy_close_count` | 15 | final chronological closes |
| `strategy_block_size` | 5 | fixed close count per block |
| `strategy_comparison_count` | 75 | locked cross-block pair count |
| `strategy_center_doubled` | 75 | strict direction midpoint |
| `strategy_tie_points` | 0.5 | all-pair tie tolerance in symbol points |
| `strategy_history_bars_d1` | 120 | bounded month reconstruction |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_atr_period_d1` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |
| `strategy_deviation_points` | 20 | framework execution deviation lock |

There is one Q02 baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; governed magic: `412740000`.
- Runtime inputs are MT5-native prices, calendar, ATR, quote, position, deal,
  and terminal-persistent attempt state.
- There is no companion, conversion, hedge, external feed, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. Every current-month
close is excluded.

```text
C = final fifteen chronological closes of the immediately completed month
G0 = C[0..4]
G1 = C[5..9]
G2 = C[10..14]

require abs(C[i]-C[j]) > 0.5*SYMBOL_POINT for every i != j

W = 0
N = 0
for a in 0..1:
  for b in a+1..2:
    for x in Ga:
      for y in Gb:
        N += 1
        if y > x: W += 1

require N == 75
BUY  if 2*W > 75
SELL if 2*W < 75
```

Wrong history, month membership, chronology, session count, close, tie,
comparison count, win count, or side consumes the month flat.

## 5. Expected Behaviour

The strategy consumes one attempt per broker month. Every valid strict-order
state has a side, giving a market-free upper bound of twelve positions per
full year before execution gates. Q02 must establish at least five completed
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
`strategy-seeds/sources/AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901/source.md`.
Complete-read Moskowitz, Ooi, and Pedersen (2012) evidence supports only WTI
membership, monthly cadence, and own-return continuation. The within-month
three-block close-order score, half-point tie rule, continuous-CFD
translation, fixed risk, stop, and lifecycle are disclosed pre-result QM
synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_m3block_rank_tr_preallocation_dedup_20260901.json`.

### Non-duplicate boundary

- `QM5_41115` votes three cumulative return signs using a parent close; this
  build uses no parent and counts all 75 cross-block close comparisons.
- With parent 5 and closes `[1,2,3,4,10,11,12,13,14,9,15,16,17,18,8]`, this
  build buys at `W=68` while the three-return vote sells on `+,-,-`.
- Closes `[100..113,99]` buy here at `W=65` while their endpoint return is
  negative, separating endpoint momentum.
- `QM5_20264` compares thirteen monthly endpoints; this build compares fifteen
  daily closes inside one completed month.
- `QM5_41273` ranks twelve absolute monthly-return sizes; this build ranks no
  return magnitude.
- `QM5_12567` is a two-day long-only XNG oscillator pullback and shares no
  signal mechanic with this direct-WTI monthly long/short sleeve.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | 1,000 account-currency units per trade |

This build authorizes no live preset or deployment action. Retire on zero
positions, fewer than five in any full scored year, failed deterministic
fixtures, nonpositive governed economics, or any downstream gate failure.
WTI gaps, continuous-CFD roll/basis, financing, strict-order instability,
ties, and broker-month offsets remain material risks.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, magic, risk, news, Friday,
  stress, strategy locks, clock, history, and arithmetic.
- `trade_entry`: cached ordinal side, quote/spread/ATR/stop gates, and one
  fixed-risk WTI order.
- `trade_management`: malformed-position repair, next-month exit, and forty-
  day stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0-approved card; governed magic `412740000` |
