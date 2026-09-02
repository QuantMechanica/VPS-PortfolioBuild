# WTI Monthly ADF Persistence Trend - Source Approval

- Date: 2026-09-03
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card,
  deterministic allocation, one branch-only non-live build, strict Q01, and
  one paced Q02 enqueue while the CPU ceiling remains clear
- Proposed slug: `wti-madf-persist-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MADF-PERSIST-TREND-20260903_S01`
- Source ID: `AI-CODEX-WTI-MADF-PERSIST-TREND-20260903`

## Authority and ordering

The current explicit OWNER mission authorizes exactly one new reputable-source,
structural, low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG book, expressly permits a direct WTI trend construction,
requires `RISK_FIXED` backtests, and requests one paced Q02 enqueue. This
record durably approves the bounded source before Strategy Card extraction.

The approval is for falsification only. It does not establish activity,
economics, stationarity, a unit root, robustness, decorrelation, portfolio
admission, deployment, or live safety. The deterministic allocator owns the
numeric EA identity; this decision does not predict or hand-allocate it.

## Approved evidence and complete read

The single R1 lineage is the AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md`.
The repository's binding reputable-source policy permits an AI lineage when
the exact synthesis, source boundaries, and prompt/output trail are durable.

Two governed supporting records were read completely within their bounded
scope and are pinned in `retrieval_route_20260903.json`:

1. Ernest P. Chan (2013), *Algorithmic Trading: Winning Strategies and Their
   Rationale*, Wiley, ISBN 978-1-118-46014-6. The governed full-text extraction
   at `strategy-seeds/sources/SRC05/raw/full_text.txt`, lines 2290-2416,
   supplies the constant/no-drift ADF regression interpretation, chronological
   ordering, lag-one example, coefficient-standard-error statistic, negative
   rejection orientation, and the displayed 10% critical value `-2.594`.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper record at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` supplies monthly own-return
   continuation and explicit NYMEX WTI membership.

Chan applies ADF to USD/CAD, not WTI, and explains mean-reversion rejection.
Moskowitz-Ooi-Pedersen do not use an ADF gate. Neither source tests the
conjunction below, a 60-month continuous-CFD sample, the non-rejection-like
side of `-2.594`, fixed risk, stops, density, performance, or portfolio overlap.

## Approved mechanic

At the first executable `XTIUSD.DWX` D1 tick of each genuine new broker month:

```text
60 consecutive completed broker-month-end closes C[0..59]
x[t] = ln(C[t])
for t=2..59:
  y[t] = x[t]-x[t-1]
  z[t] = x[t-1]
  w[t] = x[t-1]-x[t-2]
OLS with intercept: y = alpha + gamma*z + phi*w + error
adf_t = gamma / se(gamma), 58 observations, 55 residual degrees of freedom
mom12 = x[59]-x[47]

BUY  iff adf_t >= -2.594 and mom12 > +1e-12
SELL iff adf_t >= -2.594 and mom12 < -1e-12
FLAT otherwise
```

The `-2.594` boundary is used as a frozen state threshold, not as a valid
finite-sample p-value for this translated sample. Failing to reject a unit-root
null never proves trend or predictability. The statistic selects a weak-error-
correction/persistence state; only the twelve-month completed return assigns
direction. Statistic magnitude never sizes risk.

Consume the month before every fallible gate. A position receives one
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget, a frozen
`3.5*ATR(20,D1)` broker hard stop, no target, a 1,500-point spread ceiling,
next-month exit, and forty-day stale repair. Both news axes, legacy news, and
Friday close are off.

## Reputable-source findings

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_BOOK_PAPER_EVIDENCE` | One durable AI source binds a complete governed Wiley extraction and complete peer-reviewed WTI paper record with hashes, precise page/line bounds, and explicit non-transfer boundaries. |
| R2 | `PASS` | Month clock, endpoints, lag-one constant/no-trend regression, centered OLS arithmetic, degrees of freedom, inclusive threshold, momentum side, attempt, risk, stop, spread, and lifecycle are locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime input. |
| R4 | `PASS` | Completed prices, logarithms, bounded OLS arithmetic, comparisons, ATR risk plumbing, and native execution only; no trained output, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Non-duplicate decision

The corrected-root receipt
`artifacts/qm5_wti_madf_persist_tr_preallocation_dedup_20260903.json` returned
`CLEAN` across 4,804 registry identities, 1,433 cards, and 45 Strategy Wiki
nodes. Manual family review separates the candidate from:

- `QM5_41317`, whose KPSS level-stationarity statistic uses demeaned-level
  partial sums and a fixed-lag Newey-West denominator, not a lagged-level
  error-correction regression;
- `QM5_41313`, `QM5_41315`, and `QM5_41316`, which use return portmanteau,
  squared-return ARCH, and delay-vector BDS states;
- raw/rank von Neumann, variance-ratio, entropy, distribution, robust-block,
  calendar, event, channel, and pure momentum families; and
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Deterministic fixtures pin upward and downward qualifying paths and a strongly
mean-reverting flat path. Verdict:
`CLEAN_WTI_MONTHLY_LAG1_CONSTANT_NO_TREND_ADF_T_GE_MINUS2P594_GATED_12M_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
formula/fixture mismatch, current-month leakage, invalid fixed risk, missing
hard stop, nondeterminism, or malformed lifecycle. A failure may not be rescued
by changing the sample, lag, regression, threshold, side, stop, hold, spread,
or retry rule. Q09 alone owns realized portfolio correlation.

Authorized after G0 and clean registries: branch-only non-live build,
deterministic reference tests, strict Q01, one fixed-risk backtest preset, and
one paced Q02 work item while a fresh CPU window is below the ceiling.
Excluded: manual backtests; live/demo/shadow/stress/optimization presets;
portfolio-gate edits; correlation waivers; portfolio admission; deploy/live
manifests; `T_Live`; AutoTrading; terminal control; and live use.

