# QM5_41255_wti-mcvm-shift-tr - Strategy Spec

**EA ID:** QM5_41255

**Slug:** `wti-mcvm-shift-tr`

**Strategy ID:** `AI-CODEX-WTI-MCVM-20260831_S01`

**Source:** `AI-CODEX-WTI-MCVM-20260831`

**Last revised:** 2026-08-31

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
load thirteen consecutive completed month-end closes and form twelve adjacent
log returns. The oldest and newest six returns are fixed samples.

Sort the twelve returns while retaining actual sample membership. After every
pooled rank, square the old-minus-recent cumulative membership imbalance and
sum all twelve terms. Enumerate every one of the 924 possible six-rank recent
samples and count permutation scores at least as large as observed. An
inclusive tail count of 460 or fewer, equivalently an integer score of 22 or
more, activates the package. The recent-minus-old even-sample median chooses
long or short. The boundary is an activity setting, not a significance claim.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 12 | adjacent completed monthly log returns |
| `strategy_block_size` | 6 | fixed old and recent sample size |
| `strategy_assignment_count` | 924 | complete six-of-twelve label space |
| `strategy_tail_count_max` | 460 | inclusive upper-tail activity cap |
| `strategy_score_min` | 22 | equivalent integrated-path score floor |
| `strategy_direction_epsilon` | `1e-12` | recent-minus-old median side guard |
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
- Symbol slot: 0; magic: `412550000`.
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

sort pooled returns with labels
S = sum((old_seen - recent_seen)^2) over ranks 0..11

for every 12-bit mask with six set bits:
    S_perm = the same path score using set ranks as pseudo-recent
    tail += (S_perm >= S)

require assignments == 924
require tail <= 460
require S >= 22

d = median6(recent) - median6(old)
BUY if d > 1e-12; SELL if d < -1e-12; otherwise FLAT
```

All arithmetic must be finite. A tie, malformed endpoint, wrong enumeration,
sub-boundary score, or zero median difference consumes the month flat.

## 5. Expected Behaviour

Exact enumeration gives 460 qualifying strict-rank assignments out of 924,
or about 5.974 decisions per twelve months before market data and the median-
direction zero guard. Q02 must establish at least five completed positions in
every full post-warm-up year or the candidate retires.

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
`strategy-seeds/sources/AI-CODEX-WTI-MCVM-20260831/source.md`. Anderson (1962)
is bibliographic naming context only because content retrieval was policy-
deferred. Complete-read Moskowitz, Ooi, and Pedersen (2012) evidence supports
only WTI membership, monthly cadence, and own-return continuation. The exact
rank path, enumeration boundary, CFD translation, fixed risk, and lifecycle
are disclosed pre-result QM synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_mcvm_shift_tr_preallocation_dedup_20260831.json`.

### Non-duplicate boundary

Unlike `QM5_41250`, this build does not compare median absolute deviations.
Unlike `QM5_41183`, it does not keep only a maximum signed price-level ECDF
gap. Unlike `QM5_41176`, it is not a rank sum. Unlike `QM5_41249` and
`QM5_41251`, it uses no mean/variance or placement standardization. Fixed
fixtures prove that identical rank sums and identical signed maximum gaps can
produce scores on opposite sides of the locked 22 boundary.

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
membership path, score, assignment count, tail boundary, median side, fixed-
risk mode, hard stop, attempt ordering, or lifecycle.

## Framework Alignment

- `no_trade`: exact host, period, identity, slot, magic, risk, news, Friday,
  stress, strategy locks, clock, history, and arithmetic validation.
- `trade_entry`: cached qualified median direction, quote/spread/ATR/stop
  gates, and one fixed-risk WTI order.
- `trade_management`: malformed-position repair, next-month exit, and forty-
  day stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magic `412550000` |
