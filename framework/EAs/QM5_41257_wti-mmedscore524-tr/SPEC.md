# QM5_41257_wti-mmedscore524-tr - Strategy Spec

**EA ID:** QM5_41257

**Slug:** `wti-mmedscore524-tr`

**Strategy ID:** `AI-CODEX-WTI-MMEDSCORE524-20260831_S01`

**Source:** `AI-CODEX-WTI-MMEDSCORE524-20260831`

**Last revised:** 2026-08-31

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
load thirteen consecutive completed month-end closes and form twelve adjacent
log returns. The oldest six and newest six returns are fixed samples.

Sort the twelve pairwise-distinct returns while retaining old/recent labels.
Let `H` be the count of recent labels in pooled ranks 7 through 12. Enumerate
all 924 possible six-rank pseudo-recent assignments and count assignments at
least as far from neutral `H=3` as the observed assignment. An inclusive tail
count of 524 or fewer is exactly the non-neutral boundary: buy at `H>=4`, sell
at `H<=2`, and consume flat at `H=3`. This is an activity setting, not a
statistical-significance claim.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 12 | adjacent completed monthly log returns |
| `strategy_block_size` | 6 | fixed old and recent sample size |
| `strategy_assignment_count` | 924 | complete six-of-twelve label space |
| `strategy_tail_count_max` | 524 | inclusive exact two-sided activity cap |
| `strategy_recent_high_long_min` | 4 | recent upper-half count for BUY |
| `strategy_recent_high_short_max` | 2 | recent upper-half count for SELL |
| `strategy_history_bars` | 900 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `412570000`.
- Runtime inputs are MT5-native prices, calendar, ATR, quote, position, deal,
  and persistent attempt state.
- There is no companion, conversion, hedge, external feed, or signal symbol.

## 4. Timeframe and Formula

The host, signal, ATR, and execution timeframe is D1. The current broker
month is excluded.

```text
r[i] = log(C[i+1] / C[i]), i=0..11
old = r[0..5]; recent = r[6..11]
require strict pooled uniqueness

sort pooled returns ascending with labels retained
H = count(actual recent labels in ranks 7..12)

for every 12-bit mask with six set bits:
    H_perm = count(set bits in ranks 7..12)
    tail += (abs(H_perm-3) >= abs(H-3))

require assignments == 924
require tail <= 524
BUY if H >= 4; SELL if H <= 2; FLAT if H == 3
```

All arithmetic must be finite. A tie, malformed endpoint, wrong enumeration,
or neutral count consumes the month flat.

## 5. Expected Behaviour

Exact enumeration gives 524 qualifying strict-rank assignments out of 924,
or about 6.805 decisions per twelve months before market-data and execution
gates. Q02 must establish at least five completed positions in every full
post-warm-up year or the candidate retires.

### Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
One qualified month may open at most one position with a frozen completed-bar
`3.5*ATR(20,D1)` broker hard stop and no target. Both news axes and Friday
close are disabled.

### Exit and failure contract

An owned position closes on the first tick in a later normalized broker month
or after forty calendar days. Duplicate, malformed, wrong-symbol, wrong-side,
or stopless exposure is repaired before entry-only gates. There is no target,
trail, break-even, partial close, scale-in, grid, martingale, pyramid,
opposite-signal exit, or same-month retry.

## 6. Source Citation

The governed exact-source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MMEDSCORE524-20260831/source.md`.
Brown and Mood (1951) are bibliographic naming context only because method
content retrieval was policy-deferred. Complete-read Moskowitz, Ooi, and
Pedersen (2012) evidence supports only WTI membership, monthly cadence, and
own-return continuation. The exact score, enumeration boundary, CFD
translation, fixed risk, and lifecycle are disclosed pre-result QM synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_mmedscore524_tr_preallocation_dedup_20260831.json`.

### Non-duplicate boundary

Unlike `QM5_41255`, this build ignores the full integrated ECDF path and uses
only the pooled upper-half count. Unlike `QM5_41250`, it does not compare
median absolute deviations. Unlike `QM5_41137`, it does not trade every
nonzero continuous median difference. Unlike `QM5_41176`, it does not use all
36 cross-block wins. Retired `QM5_41256` required the distinct 5-of-6 extreme.

## 7. Risk Model and Kill Criteria

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |

This build authorizes no live preset or deployment action. Retire on zero
positions, fewer than five in any full scored year, nonpositive governed
economics, or deterministic-fixture failure. WTI gaps, continuous-CFD roll,
basis, financing, small-sample rank instability, and broker-month offsets
remain material risks.

Fail on current-month leakage, wrong return orientation, accepted tie, wrong
upper-half count, assignment count, tail boundary, side, fixed-risk mode,
hard stop, attempt ordering, or lifecycle.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, magic, risk, news, Friday,
  stress, strategy locks, clock, history, and arithmetic validation.
- `trade_entry`: cached qualified median-score direction, quote/spread/ATR/
  stop gates, and one fixed-risk WTI order.
- `trade_management`: malformed-position repair, next-month exit, and forty-
  day stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magic `412570000` |
