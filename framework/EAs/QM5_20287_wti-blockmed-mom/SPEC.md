# QM5_20287_wti-blockmed-mom — Strategy Spec

**EA ID:** QM5_20287
**Slug:** `wti-blockmed-mom`
**Source:** `MOP-WTI-BLOCKMED-2026` (see
`strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct
thirteen consecutive completed WTI month-end closes and form twelve adjacent
chronological log returns. Partition them into four fixed non-overlapping
blocks of three returns, compute each block's arithmetic mean, sort the four
block means, and average sorted zero-based indexes 1 and 2. Buy for a positive
even block median and sell for a negative one. Exact zero or invalid state
consumes the month flat. Every entry has a frozen `3.5 * ATR(20,D1)` hard
stop, no take-profit, monthly renewal, and a forty-day stale exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_months` | `12` | `[12]` | Adjacent completed monthly log returns |
| `strategy_block_months` | `3` | `[3]` | Returns per chronological block |
| `strategy_block_count` | `4` | `[4]` | Fixed non-overlapping block count |
| `strategy_history_bars_d1` | `800` | `[800]` | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | Entry spread ceiling in WTI points |

All values are locked for baseline. No optimization or alternate estimator is
authorized.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI route and only authorized carrier.

**Explicitly NOT for:**

- `XNGUSD.DWX` — already represented in the book and governed separately.
- `XBRUSD.DWX` — distinct benchmark and not source-equivalent to this route.
- `XAUUSD.DWX` and `XAGUSD.DWX` — metals do not satisfy the WTI carrier lock.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Completed broker months reconstructed from D1; `ATR(20,D1)` |
| Bar gating | One `QM_IsNewBar()` consume, then broker-month transition check |

The current broker month contributes no signal endpoint.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11–12 after thirteen completed month ends; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk WTI trend losses with gap and delayed-reversal exposure |
| Regime preference | Persistent broad crude-oil direction after block-level shock isolation |
| Win rate target | Low to medium; expectancy must come from slow trend packages |

The WTI carrier and block statistic are diversification hypotheses only. Q09
owns any realized portfolio-overlap conclusion.

## 6. Source Citation

**Source ID:** `MOP-WTI-BLOCKMED-2026`
**Source type:** peer-reviewed trading paper with bounded QM statistical
mechanization
**Pointer:** `strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md`
**R1–R4 verdict (G0):** all PASS; see
`strategy-seeds/cards/approved/QM5_20287_wti-blockmed-mom_card.md`

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, establishes the broad monthly own-price trend
family and includes WTI. The block median-of-means estimator is a locked QM
hypothesis; the paper does not test it.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this build |

The mission creates one backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Framework initialization enforces
the environment-to-risk-mode contract.

## 8. Exact Statistical Contract

For thirteen positive finite completed month-end closes, oldest to newest:

```text
r[i] = ln(C[i+1] / C[i]), i=0..11
b[j] = (r[3j] + r[3j+1] + r[3j+2]) / 3, j=0..3
s = sort_ascending(b)
location = (s[1] + s[2]) / 2
```

Only the four block means are sorted. Buy for `location > 0`, sell for
`location < 0`, and consume exact zero or invalid state flat.

## 9. Non-Duplicate Boundary

`QM5_20272` forms the same four chronological three-month intervals but uses
a three-of-four sign consensus and always stays flat on two-versus-two splits.
This EA retains block magnitude and resolves those splits from the inner two
sorted means. `QM5_20269` sorts twelve individual returns; `QM5_20270` trims
individual-return tails. Cumulative, cap, Winsor, iterative robust-location,
regression, rank, path, vote/run, recency, and skip-month systems use other
functionals. Block membership, equal within-block weights, sorting block means
only, the even-median indexes, and nonzero split resolution are load-bearing.

## 10. Kill Criteria

Retire below five completed packages per full post-warm-up year, on
nonpositive governed economics, or on later portfolio-correlation rejection.
Fail on endpoint discontinuity, current-month leakage, wrong return
orientation, overlapping/reordered blocks, block count other than four, block
width/divisor other than three, sorting individual returns, wrong median
indexes, sign-only voting, wrong-side entry, repeated attempt, missing hard
stop, hold beyond forty days, risk mismatch, or nondeterminism. No post-result
rescue parameter is authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-12 | Initial scaffold from approved card | Build pending |

## 12. Q01 Status

PENDING. Strict compile, target build validation, P1 artifact validation, and
independent statistic/clock reference vectors must pass before Q02 handoff.

## 13. Q02 Handoff

PENDING. Enqueue exactly one current-binary `XTIUSD.DWX` D1 item only after
Q01 passes and a binding path-anchored CPU-ceiling sample permits the handoff.
Do not dispatch or run a manual backtest from this build mission.
