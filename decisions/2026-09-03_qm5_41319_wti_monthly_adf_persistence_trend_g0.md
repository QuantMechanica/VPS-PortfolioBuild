# QM5_41319 WTI Monthly ADF Persistence Trend - G0 Decision

- Date: 2026-09-03
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- Gate: G0, approval for falsification
- EA ID: `QM5_41319` (provisional until deterministic registry reservation)
- Slug: `wti-madf-persist-tr`
- Strategy ID: `AI-CODEX-WTI-MADF-PERSIST-TREND-20260903_S01`
- Source ID: `AI-CODEX-WTI-MADF-PERSIST-TREND-20260903`

## Authority

The current OWNER mission directs one new structural, low-frequency
commodity/energy card and build outside the certified XAU/SP500/NDX/XNG book,
expressly permits direct WTI trend logic, requires a `RISK_FIXED` backtest
preset, and requests a paced Q02 enqueue. The source was approved and committed
first in `d486b131e7`.

This G0 approval authorizes a branch-only non-live implementation, deterministic
registry allocation, reference tests, strict Q01, and one paced Q02 enqueue if
the whole-host CPU ceiling remains clear. It is not a performance, robustness,
decorrelation, portfolio, deployment, or live verdict.

## Card reviewed

`strategy-seeds/cards/approved/QM5_41319_wti-madf-persist-tr_card.md`

The card locks sixty consecutive completed broker-month-end WTI closes, a
58-observation intercept OLS with one lagged difference and no deterministic
time trend, an inclusive ADF lagged-level t-statistic floor of `-2.594`, a
twelve-month completed-return continuation side, one consumed monthly attempt,
fixed risk, a frozen hard stop, and next-month lifecycle.

## R1-R4 findings

| gate | verdict | evidence |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_BOOK_PAPER_EVIDENCE` | The single durable AI lineage binds Chan's complete governed Wiley extraction and the complete peer-reviewed Moskowitz-Ooi-Pedersen WTI record, with exact local paths, hashes, page/line scope, and explicit non-transfer boundaries. |
| R2 | `PASS` | Month clock, completed endpoints, chronological logarithms, lag-one constant/no-trend regression, centered OLS and standard error, degrees of freedom, inclusive threshold, momentum side, attempt, risk, stop, spread, and lifecycle are deterministic and locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 data, quotes, metadata, positions, deals, and broker calendar supply every runtime input. Continuous-CFD roll, basis, financing, gaps, and month labels remain falsification risks. |
| R4 | `PASS` | Bounded deterministic prices, logarithms, OLS arithmetic, comparisons, ATR risk plumbing, and native execution only; no trained output, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, pyramid, or random path. |

## Source and claim boundary

The source packet SHA-256 is
`576505363DE9DCA4F8E0CB4047D30DE630FB76CBC754F3F9FE3805CDA33507EC`.
Chan supplies ADF mechanics and a displayed example threshold; the momentum
paper supplies monthly continuation and WTI membership. Neither supplies this
combined rule, the 60-month CFD sample, non-rejection-like interpretation,
activity, profit factor, drawdown, fixed risk, or correlation.

The card must describe `adf_t >= -2.594` only as a frozen persistence-state
gate. It may not claim a valid translated p-value, unit root, stationarity
diagnosis, causal regime, or predicted profit.

## Non-duplicate finding

The canonical corrected-root scan, SHA-256
`30321D2047DC7B44683A913BAC2B10AD7B258059D49FDDDAEA341324B7643468`,
returned `CLEAN` across 4,804 registry identities, 1,433 cards, and 45 Strategy
Wiki nodes.

Manual review confirms that `QM5_41317` uses KPSS partial sums and a Newey-West
long-run-variance denominator, whereas this candidate uses a lagged-level
error-correction coefficient t-statistic inside a lag-one first-difference
regression. Portmanteau, ARCH, BDS, entropy, von Neumann, variance-ratio,
robust-block, calendar, event, channel, pure momentum, and the certified XNG
RSI family observe different states or carriers. The fixture SHA-256
`EA4E1DDF8D6AF0468C2A15EB7210BD984428D2927137290AB84235FC8E94601A`
pins both qualifying directions and a rejected mean-reverting path.

Verdict:
`CLEAN_WTI_MONTHLY_LAG1_CONSTANT_NO_TREND_ADF_T_GE_MINUS2P594_GATED_12M_CONTINUATION`.

## Locked implementation contract

- Exact host/traded symbol `XTIUSD.DWX`, D1, slot zero.
- Sixty immediately prior consecutive broker-month endpoints; no current-month
  price and no fallback sample.
- Fifty-eight rows of `delta x[t]` on an intercept, `x[t-1]`, and
  `delta x[t-1]`; 55 residual degrees of freedom.
- Centered cross-product OLS exactly as written on the card; positive finite
  determinant, residual energy, and lagged-level standard error.
- Inclusive `adf_t >= -2.594` state and strict twelve-month return sign.
- One attempt consumed before every fallible entry gate.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling.
- Both news axes, legacy news mode, Friday close, and stress rejection off.
- Close at a later broker month or forty-day stale repair; malformed-position
  defensive close before new entry.

## Kill and safety boundary

Retire the unchanged identity on zero positions, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
current-month leakage, formula/fixture mismatch, invalid risk, missing stop,
malformed lifecycle, nondeterminism, or any downstream hard failure. No
result-dependent threshold, sample, lag, side, risk, stop, spread, hold, or
retry change is authorized.

Forbidden: manual tester/backtest launch; optimization; live/demo/shadow/stress
presets; terminal control; AutoTrading; `T_Live`; deploy/live manifest;
portfolio-gate edit; correlation waiver; portfolio admission; or live use.

