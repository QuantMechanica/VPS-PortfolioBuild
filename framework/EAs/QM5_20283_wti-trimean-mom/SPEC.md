# QM5_20283_wti-trimean-mom — Strategy Spec

**EA ID:** QM5_20283
**Slug:** `wti-trimean-mom`
**Source:** `MOP-WTI-TRIMEAN-2026` (see `strategy-seeds/sources/MOP-WTI-TRIMEAN-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

On the first D1 bar of each genuine broker-month transition, reconstruct
thirteen consecutive completed WTI month-end closes and form twelve adjacent
monthly log returns. Sort the returns, estimate lower quartile, median, and
upper quartile using fixed even-half indexes, and combine them with `1:2:1`
weights. Buy on a positive quartile trimean or sell on a negative trimean. An
exact-zero or invalid state consumes the month flat. Every entry has a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal, and a forty-day
stale exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_months` | `12` | `[12]` | Exact adjacent completed-month returns |
| `strategy_history_bars_d1` | `800` | `[800]` | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | Entry spread ceiling in WTI points |

All values are locked for the baseline. No optimization or alternative
estimator is authorized.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the registered Darwinex WTI route and the only authorized
  crude-oil carrier for this card.

**Explicitly NOT for:**

- `XNGUSD.DWX` — already represented in the book and governed by separate
  natural-gas logic.
- `XBRUSD.DWX` — Brent is a distinct benchmark and is not source-equivalent to
  this WTI-only execution contract.
- `XAUUSD.DWX` and `XAGUSD.DWX` — metals do not satisfy the WTI carrier lock.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Native completed broker months reconstructed from D1; `ATR(20,D1)` |
| Bar gating | One `QM_IsNewBar()` consume, then `QM_CalendarPeriodKey(PERIOD_MN1, symbol, shift)` |

The current broker month contributes no signal endpoint.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 11–12 after thirteen completed month ends; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Expected drawdown profile | Sparse fixed-risk WTI trend losses with gap and reversal exposure |
| Regime preference | Persistent crude-oil direction not dominated by sample tails |
| Win rate target (qualitative) | Low to medium; expectancy must come from robust trend packages |

The carrier and statistic are diversification hypotheses only. Q09 owns any
realized portfolio-overlap conclusion.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-WTI-TRIMEAN-2026`
**Source type:** peer-reviewed paper with bounded QM mechanization
**Pointer:** `strategy-seeds/sources/MOP-WTI-TRIMEAN-2026/source.md`
**R1–R4 verdict (Q00):** all PASS; see
`strategy-seeds/cards/approved/QM5_20283_wti-trimean-mom_card.md`

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum,"
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The source establishes the broad own-return
trend family and includes WTI; the quartile trimean is an explicit QM
hypothesis, not an author result.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this build |

The mission creates only a backtest set with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. `QM_FrameworkInit` enforces the
ENV-to-risk-mode contract.

## 8. Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
s = sort_ascending(r)
Q1 = (s[2] + s[3]) / 2
M  = (s[5] + s[6]) / 2
Q3 = (s[8] + s[9]) / 2
T  = (Q1 + 2 * M + Q3) / 4
```

Buy for `T > 0`, sell for `T < 0`, and stay flat for `T == 0` or invalid
state. Signal magnitude never scales risk.

## 9. Non-Duplicate Boundary

`QM5_20269` uses only the center pair. `QM5_20270` equally averages every
sorted observation from indexes 2 through 9. `QM5_20277` uses fixed-tail
Winsorization. `QM5_20278` weights observations by chronology. This EA instead
uses exactly six order statistics with weights `1/8, 1/8, 1/4, 1/4, 1/8,
1/8`. The sort, selected indexes, weights, divisor, exact-zero rule, and
monthly lifecycle are jointly load-bearing.

## 10. Kill Criteria

Retire below five completed packages per full post-warm-up year, on
nonpositive governed economics, or on later portfolio-correlation rejection.
Fail on endpoint discontinuity, current-month leakage, reversed returns, wrong
sort, wrong index selection, wrong weight or divisor, fallback after exact
zero, repeated monthly attempt, missing hard stop, hold beyond forty days,
risk mismatch, or nondeterminism. No post-result rescue parameter is
authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Initial scaffold from approved card | Build commit pending |
| v2 | 2026-08-11 | Initial V5 implementation and Q01 validation | Strict compile, target build check, P1 artifact validation, and independent trimean reference vectors PASS |

## 12. Q01 Status

- Strict compile: PASS with zero errors and zero warnings; summary
  `D:/QM/reports/compile/20260811_184440/summary.csv` and log
  `C:/QM/repo/framework/build/compile/20260811_184440/QM5_20283_wti-trimean-mom.compile.log`.
- Target build check: PASS with zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260811_184440.json`.
- P1 artifact validation: PASS at
  `D:/QM/reports/pipeline/QM5_20283/P1/P1_QM5_20283_result.json`.
- Independent statistic/clock reference vectors: PASS for positive, negative,
  exact-zero, trim/Winsor sign divergence, raw-median sign divergence,
  endpoint orientation, and cross-year month continuity cases.
- Backtest set build hash:
  `81b8e1ac61600fdce049d7865c74b9a8b3adae29d6c971377ae40191d4b715d3`.
- Compiled binary SHA-256:
  `A354227A1F5C8E1DB0F5968217CDCC3C58C485861BBE0FAFE73C6B2F9BAC39ED`.

## 13. Q02 Handoff

Not enqueued. The paced CPU ceiling must be sampled after Q01 PASS; this
mission will not dispatch or run a manual backtest.
