# WTI Monthly Phillips-Perron Persistence Trend - Source Approval

- Date: 2026-09-03
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card,
  deterministic allocation, one branch-only non-live build, strict Q01, and
  one paced Q02 enqueue while the CPU ceiling remains clear
- Proposed slug: `wti-mpp-persist-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MPP-PERSIST-TREND-20260903_S01`
- Source ID: `AI-CODEX-WTI-MPP-PERSIST-TREND-20260903`

## Authority and ordering

The current explicit OWNER mission authorizes exactly one new reputable-
source, structural, low-frequency commodity/energy sleeve outside the
certified XAU/SP500/NDX/XNG book, permits direct WTI logic, requires
`RISK_FIXED` backtests, and requests one paced Q02 enqueue. This durable
record approves the bounded source before Strategy Card extraction.

Approval is for falsification only. It establishes no activity, economics,
unit root, stationarity, robustness, decorrelation, portfolio admission,
deployment, or live safety. The deterministic allocator owns the numeric EA
identity; this decision does not hand-allocate one.

## Approved evidence and complete read

The single R1 lineage is
`strategy-seeds/sources/AI-CODEX-WTI-MPP-PERSIST-TREND-20260903/source.md`.
Its pre-approval SHA-256 is
`C8ED6052ADDA9F6978ACADA8F34F54C2F6502316762AF30AC16DF0F6325329A2`.
Its `retrieval_route_20260903.json` binds:

1. Phillips and Perron (1988), "Testing for a Unit Root in Time Series
   Regression," *Biometrika* 75(2), 335-346, DOI
   `10.1093/biomet/75.2.335`: all 12 journal pages read, PDF SHA-256
   `62FE139F59B2630AFC6634EA27BA93FB48CA4B711F48F7BCA70D7EC147EFD336`.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`: complete governed paper record, supplying
   monthly own-return continuation and explicit NYMEX WTI membership.
3. Pinned `arch` commit `704bb70e48372e3ccccdde7da379811657ad0224`, used
   only as an arithmetic transcription oracle for PP Z-tau and Bartlett
   covariance—not as economic evidence.

The primary PP article explicitly warns of appreciable finite-sample size
distortion under negative moving-average errors. That adverse evidence is
binding. The paper proposes no trading rule; the WTI paper uses no PP gate.

## Approved mechanic

At the first executable `XTIUSD.DWX` D1 tick of each genuine broker month:

```text
60 consecutive completed broker-month-end closes C[0..59]
x[t] = ln(C[t])
fit x[t] = alpha + rho*x[t-1] + u[t], t=1..59
n=59, k=2, residual_dof=57
estimate lambda2 with 11 Bartlett-weighted residual autocovariances, divisor 59
transform raw (rho-1)/se(rho) into Phillips-Perron Z-tau
mom12 = x[59]-x[47]

BUY  iff pp_z_tau >= -2.594 and mom12 > +1e-12
SELL iff pp_z_tau >= -2.594 and mom12 < -1e-12
FLAT otherwise
```

The full formula and arithmetic floors are locked in the source packet. The
threshold is a frozen state line, not a claimed finite-sample p-value. Only
the twelve-month return selects side. Consume the month before every fallible
gate. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling, next-month
exit, and forty-day stale repair. News, Friday close, and stress are off.

## Reputable-source findings

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_PEER_REVIEWED_EVIDENCE` | Complete peer-reviewed PP article plus complete governed peer-reviewed WTI paper record, immutable retrieval hashes, exact read scopes, and adverse/non-transfer boundaries. |
| R2 | `PASS` | Endpoints, orientation, regression, degrees of freedom, Bartlett lags/weights/divisor, PP correction, state line, side, attempt, fixed risk, stop, spread, and lifecycle are locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime input. |
| R4 | `PASS` | Completed prices, bounded OLS/HAC arithmetic, comparisons, ATR risk plumbing, and native execution only; no trained output, banned indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Non-duplicate decision

The corrected-root receipt found no exact duplicate across 4,805 registry
identities, 1,434 cards, and 45 Strategy Wiki nodes. It returned the expected
fuzzy neighbor `QM5_41319_wti-madf-persist-tr` at score `0.75`; this requires
and received manual resolution rather than a false CLEAN label.

`QM5_41319` is a three-coefficient first-difference ADF regression with one
lagged difference and 55 residual degrees of freedom. The approved mechanic
is a two-coefficient level AR(1) with 57 residual degrees of freedom and an
eleven-lag Bartlett residual-covariance transformation. The formulas and
functional state decisions are not interchangeable. Manual verdict:
`DISTINCT_PP_ZTAU_HAC_STATE_FROM_ADF_LAGGED_DIFFERENCE_STATE`.

Both remain WTI continuation hypotheses. This decision establishes a new
mechanical identity, not portfolio orthogonality. Q09 alone owns realized
correlation and may reject either challenger.

## Kill and safety boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, formula/oracle mismatch,
current-month leakage, invalid fixed risk, missing stop, malformed lifecycle,
nondeterminism, or any downstream hard failure. Preserve negative evidence;
do not repair a failure by changing the sample, lags, threshold, side, stop,
hold, spread, or retry rule.

Authorized after G0 and clean registries: branch-only non-live build,
independent reference tests, strict Q01, one fixed-risk backtest preset, and
one paced Q02 item while a fresh CPU window is below the ceiling. Excluded:
manual backtests; live/demo/shadow/stress/optimization presets; portfolio-
gate edits; correlation waivers; portfolio admission; deploy/live manifests;
`T_Live`; AutoTrading; terminal control; and live use.
