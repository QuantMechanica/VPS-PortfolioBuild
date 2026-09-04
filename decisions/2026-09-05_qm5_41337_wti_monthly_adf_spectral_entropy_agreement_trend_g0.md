# QM5_41337 WTI ADF and Spectral-Entropy Agreement Trend - G0 Decision

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- Gate: G0, approval for falsification
- EA ID: `QM5_41337` (provisional until deterministic registry reservation)
- Slug: `wti-adf-specent-agree-tr`
- Strategy ID: `AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905_S01`
- Source ID: `AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905`

## Authority

The current OWNER mission directs one new structural, low-frequency
commodity/energy card and build outside the certified XAU/SP500/NDX/XNG book,
permits direct WTI logic, requires a `RISK_FIXED` preset, and requests one
paced Q02 enqueue. The source was approved and committed first in
`faea4503f7`.

This approval authorizes branch-only non-live implementation, deterministic
registry allocation, reference tests, strict Q01, and one paced Q02 enqueue
only after compile PASS and a clear CPU window. It is not a performance,
robustness, decorrelation, portfolio, deployment, or live verdict.

## Card reviewed

`strategy-seeds/cards/approved/QM5_41337_wti-adf-specent-agree-tr_card.md`

The card locks one sixty-endpoint monthly WTI sample, a lag-one ADF
regression, a frequency-domain state over the newest forty-eight returns, both
inclusive boundaries, a strict conjunction, twelve-month continuation side,
one consumed monthly attempt, fixed risk, frozen hard stop, and next-month
lifecycle.

## R1-R4 findings

| gate | verdict | evidence |
|---|---|---|
| R1 | `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE` | Approved complete ADF, peer-reviewed spectral-entropy/transparent implementation, and peer-reviewed WTI continuation records with exact hashes and claim boundaries. |
| R2 | `PASS` | Month clock, endpoints, both arithmetic paths, inclusive boundaries, conjunction, side, attempt, fixed risk, stop, spread, and lifecycle are deterministic and locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 data and MT5 state supply every runtime input. |
| R4 | `PASS` | Bounded deterministic prices, OLS, DFT/entropy arithmetic, comparisons, ATR risk, and native execution only. |

## Source and claim boundary

The parent sources supply ADF, spectral entropy, and monthly WTI continuation
separately. None supplies the conjunction, fixed sample/thresholds,
continuous-CFD translation, activity, economics, fixed risk, or portfolio
correlation. The two state paths overlap and may not be described as
independent votes.

## Non-duplicate finding

The corrected-root scan found no exact identity across 4,817 registry rows
and 1,436 cards. The external Wiki root was unavailable and is explicitly not
counted as clean. The four fuzzy neighbors are expected and manually cleared:
the single ADF and spectral builds each lack the other gate; the ADF-KPSS
build uses different partial-sum/long-run-variance geometry; Phillips-Perron
uses a different regression and correction.

Fixture SHA-256
`B591901078B38B63168EEAC2D87AF3DF584944616464F297E83DAA68B1CD0FBC`
pins both one-gate disagreement paths. Its high-entropy random walk passes ADF
and KPSS but is flat here, separating this card from `QM5_41336`. Manual
identity verdict:
`DISTINCT_PRICE_LEVEL_ERROR_CORRECTION_AND_FREQUENCY_POWER_CONJUNCTION`.

Shared WTI continuation may still correlate. Q09 remains authoritative.

## Locked implementation contract

- Exact host/traded `XTIUSD.DWX`, D1, slot zero.
- Sixty prior consecutive completed broker-month endpoints; no current-month
  price.
- ADF: 58-row intercept/no-time-trend regression with one lagged difference,
  55 residual degrees of freedom, inclusive `adf_t >= -2.594`.
- Spectral: newest 48 adjacent log returns, mean removed, length-48 one-sided
  DFT bins 1..24, paired bins doubled, Nyquist undoubled, inclusive normalized
  entropy `<=0.88`.
- Both states must qualify; strict twelve-month return sign chooses side.
- One attempt consumed before every fallible entry gate.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling.
- News, Friday close, and stress off; later-month or forty-day stale exit.

## Kill and safety boundary

Retire unchanged on zero positions, fewer than five positions in any full
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
leakage, invalid risk, missing stop, lifecycle defect, nondeterminism, or
downstream hard failure. No result-dependent change is authorized.

Forbidden: manual tester/backtest launch; optimization; live/demo/shadow/
stress presets; terminal control; AutoTrading; `T_Live`; deploy/live manifest;
portfolio-gate edit; correlation waiver; portfolio admission; or live use.
