# QM5_41264_wti-myuen20-shift-tr - Strategy Spec

**EA ID:** QM5_41264

**Slug:** `wti-myuen20-shift-tr`

**Strategy ID:** `AI-CODEX-WTI-MYUEN20-20260901_S01`

**Source:** `AI-CODEX-WTI-MYUEN20-20260901`

**Author:** Codex

**Last revised:** 2026-09-01

## 1. Strategy logic

On the first executable `XTIUSD.DWX` D1 bar of a normalized broker month,
reconstruct 21 consecutive completed broker-month-end closes and form 20
chronological adjacent log returns. The first ten returns are the fixed older
block and the final ten are the fixed recent block.

Sort independent copies of each block. Delete two observations per tail for
the middle-six trimmed mean. Separately Winsorize two observations per tail,
compute the Winsorized mean over all ten values, and compute the Winsorized
variance around that mean with divisor five. Follow the signed recent-minus-old
trimmed-location shift when its unequal-variance score reaches the inclusive
absolute boundary `0.75`. Every other monthly attempt is consumed flat.

## 2. Locked parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 20 | completed adjacent monthly log returns |
| `strategy_block_size` | 10 | fixed older and recent samples |
| `strategy_trim_each_tail` | 2 | deleted/replaced observations per tail |
| `strategy_effective_size` | 6 | retained location count `h` |
| `strategy_wvar_divisor` | 5 | exact Winsorized variance divisor `h-1` |
| `strategy_score_floor` | 0.75 | inclusive absolute score boundary |
| `strategy_min_se2` | `1e-18` | degenerate denominator guard |
| `strategy_history_bars` | 900 | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |

There is one Q02 baseline and no optimization surface.

## 3. Symbol and timeframe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; governed magic: `412640000`.
- Runtime inputs are native MT5 price, calendar, ATR, quote, position, deal,
  and terminal-persistent state only.
- There is no external signal, companion, ratio, hedge, or conversion symbol.

## 4. Exact formula

```text
r[i] = log(C[i+1] / C[i]), i=0..19

old    = sort(r[0..9])
recent = sort(r[10..19])
g = 2
h = 6

tmean(x) = sum(x[2..7]) / 6
winsor(x) = [x[2],x[2],x[2],x[3],x[4],x[5],x[6],x[7],x[7],x[7]]
wmean(x) = sum(winsor(x)) / 10
wvar(x) = sum((winsor(x)[i] - wmean(x))^2, i=0..9) / 5

se2 = wvar(old)/6 + wvar(recent)/6
score = (tmean(recent) - tmean(old)) / sqrt(se2)

BUY  iff se2 > 1e-18 and score >=  0.75
SELL iff se2 > 1e-18 and score <= -0.75
FLAT otherwise
```

The divisor five is deliberate: it is `h-1`, not the ordinary sample
variance denominator for ten Winsorized observations. All endpoints, ratios,
logarithms, returns, sorted values, sums, means, differences, squares,
variances, `se2`, square root, and score must be finite. Missing or duplicate
months, degenerate scale, a boundary miss, or arithmetic failure consumes the
month flat. There is no p-value, fitted split, pooled scale, fallback
estimator, recent-mean sign gate, or score-scaled exposure.

## 5. Execution and lifecycle

- Persist the new `yyyymm` attempt before history, arithmetic, news, spread,
  quote, ATR, sizing, margin, or order gates. A failed gate cannot retry.
- Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- A qualifying attempt opens at most one market position with a frozen
  completed-bar `3.5*ATR(20,D1)` broker hard stop and no target.
- Reject malformed/crossed quotes, invalid point metadata, and spread above
  1,500 points. A valid modeled zero spread is allowed.
- Both news axes and legacy news are OFF. Friday close is disabled.
- Close on the first tick in a later normalized broker month or after 40
  calendar days. Repair duplicate, malformed, wrong-symbol, wrong-side, or
  missing-stop owned exposure before entry-only gates.
- There is no target, trail, break-even, partial close, reversal exit,
  same-month retry, scale-in, grid, martingale, pyramid, or discretionary exit.

The pre-result activity prior is approximately five to six completed positions
per full post-warm-up year. Q02 retires on zero positions, fewer than five in
any full scored year, nonpositive governed economics, or a deterministic
fixture failure. This is a design prior, not a performance claim.

## 6. Source and non-duplicate boundary

The governed packet is
`strategy-seeds/sources/AI-CODEX-WTI-MYUEN20-20260901/source.md`. It records
complete-read peer-reviewed WTI monthly-continuation evidence from Moskowitz,
Ooi, and Pedersen (2012), the named peer-reviewed Yuen (1974) method record,
and complete official SciPy 1.18.0 method/source evidence. The trading
synthesis and every execution parameter are explicitly QM-defined and
untested at intake.

Preallocation dedup receipt:
`artifacts/qm5_wti_myuen20_shift_tr_preallocation_dedup_20260901.json`,
SHA-256
`8D33C19E0A75BEFCCCDF8778DD44C89A844DAE48E0FCF64E7D37520BD3C26ED7`.

The nearest neighbor, `QM5_41249_wti-mwelch-shift-tr`, uses 12 raw returns in
six/six blocks, ordinary means and variances, plus a recent-mean sign gate.
This EA uses 20 returns, ten/ten blocks, middle-six trimmed locations,
two-per-tail Winsorized scales, effective size six, and no sign gate. Two fixed
reference fixtures prove qualification disagreement in both directions.
Q09 alone may establish realized portfolio overlap.

## 7. Framework alignment and safety

- `no_trade`: exact host, period, identity, slot, risk, news, Friday, stress,
  and strategy locks.
- `trade_entry`: consumed month, consecutive endpoints, exact Yuen20 score,
  cached side, spread/quote/ATR/stop guards, and one fixed-risk order.
- `trade_management`: invalid exposure repair, next-month exit, stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

This build authorizes no live/demo/shadow/stress preset, manual tester launch,
AutoTrading action, `T_Live` change, deploy/live manifest change, portfolio
gate change, correlation waiver, or portfolio admission.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0-approved card; governed magic `412640000` |
