---
source_id: AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905
title: WTI monthly ADF persistence and Mann-Kendall ordinal-trend agreement
publisher: QuantMechanica governed synthesis from complete reputable parent records
source_type: ai_originated_reputable_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-05_wti_monthly_adf_mann_kendall_agreement_trend_source_approval.md
parent_source_ids:
  - AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
  - MOP-WTI-RANKTREND-2026
created: 2026-09-05
created_by: Research+Development
cards_extracted:
  - wti-adf-mkendall-agree-tr
---

# WTI Monthly ADF and Mann-Kendall Agreement Trend

## Approval and bounded complete evidence

The explicit OWNER commodity/energy-sleeve mission authorizes one new
structural low-frequency card, build, and paced Q02 handoff. The durable source
approval is
`decisions/2026-09-05_wti_monthly_adf_mann_kendall_agreement_trend_source_approval.md`.
The composition receipt is `retrieval_route_20260905.json`; no new public URL
or unread source is represented.

The complete governed parents preserve two different information functions:

- Chan's lag-one, intercept-only ADF regression, extracted from his Wiley book,
  supplies the weak-error-correction state and the transparently translated
  inclusive `-2.594` boundary.
- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), DOI `10.1016/j.jfineco.2011.11.003`, supplies monthly own-price
  continuation and explicit NYMEX WTI membership. The governed WTI rank packet
  fixes the thirteen-endpoint Mann-Kendall all-pairs score and `28` boundary.

Chan studies USD/CAD and does not use ordinal direction. Moskowitz, Ooi, and
Pedersen do not use ADF or Mann-Kendall. Neither parent tests this conjunction,
the rounded boundaries on a continuous WTI CFD, fixed risk, costs, density,
profitability, or book correlation.

## Locked hypothesis and formula

WTI has supply, storage, transport, refining, producer-hedging, geopolitical,
and end-demand drivers absent from the certified index/metal carriers and
different from natural-gas weather/storage exposure. The falsifiable hypothesis
is that a strong ordinal monthly WTI trend is more suitable for continuation
when a separate ADF regression does not identify strong negative error
correction.

On the first executable D1 tick after a genuine broker-month transition,
reconstruct exactly sixty consecutive completed broker-month-end closes
`C[0..59]`, oldest to newest. Exclude the current month and set `x[t]=ln(C[t])`.

For `t=2..59`, fit 58 observations:

```text
y[t] = x[t]-x[t-1]
z[t] = x[t-1]
w[t] = x[t-1]-x[t-2]
y[t] = alpha + gamma*z[t] + phi*w[t] + error[t]
adf_t = gamma / se(gamma), residual dof = 55
```

Use centered cross-products, require positive finite regression energies,
`det > 1e-12*Szz*Sww`, and require `adf_t >= -2.594` inclusively. The threshold
is a frozen state line, not a valid 60-observation CFD p-value; non-rejection
does not prove a unit root, trend, or predictability.

Separately use only the newest thirteen completed endpoints `C[47..59]`:

```text
S = sum(sign(C[j]-C[i])) for all 47 <= i < j <= 59
require all 78 pairs to be non-tied
BUY  iff adf_t >= -2.594 and S >= +28
SELL iff adf_t >= -2.594 and S <= -28
FLAT otherwise
```

The score sign alone chooses side. Neither ADF nor rank-score magnitude changes
risk. ADF and Mann-Kendall must both qualify; there is no endpoint-return,
moving-average, oscillator, calendar, PnL, or pipeline-result fallback.

## Attempt, execution, risk, and lifecycle

Persist the normalized broker month as attempted before every fallible history,
signal, spread, quote, ATR, sizing, margin, or order gate. Never retry a month.
Permit no foreign WTI position and at most one owned position.

Use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, a frozen completed-D1 `3.5*ATR(20)` broker hard stop,
no target, and an inclusive 1,500-point spread ceiling. News, Friday close, and
stress are off. Close on the first processed tick of the next broker month or
after forty calendar days. No intramonth flip, target, trail, break-even,
partial close, scaling, grid, martingale, or pyramid is allowed.

## Reputable-source criteria

- R1 `PASS_WITH_GOVERNED_COMPLETE_REPUTABLE_EVIDENCE`: complete hash-bound
  Wiley and peer-reviewed WTI parent records define the two separate functions;
  adverse and non-transfer boundaries are explicit.
- R2 `PASS`: month clock, sixty endpoints, ADF regression, newest-thirteen
  all-pairs score, inclusive thresholds, side, attempt, fixed risk, hard stop,
  spread, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 supplies every runtime input; roll, basis, financing, gaps,
  and broker-month labels remain risks.
- R4 `PASS`: bounded prices, timestamps, OLS, comparisons, ATR, and native V5
  execution only; no ML, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, pyramid, or random path.

## Non-duplicate and kill boundary

The corrected-root receipt
`artifacts/qm5_wti_adf_mkendall_agree_tr_preallocation_dedup_20260905.json`
found no exact identity across 4,834 registry rows, 1,447 cards, and 45 Wiki
nodes. The fuzzy ADF-agreement siblings use KPSS, entropy, von Neumann, LZ76,
sample entropy, Ljung-Box, BDS, variance ratio, or Phillips-Perron as a state
gate and still use endpoint return for side. `QM5_41319` has no ordinal gate;
`QM5_20264` has no ADF gate. This rule requires both functions and lets the
all-pairs ordinal score choose direction, so fixed paths can make either parent
trade while the conjunction stays flat.

Q02 retires on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
leakage, invalid risk, missing stop, malformed lifecycle, or nondeterminism.
No parameter may change after results. Q09 alone may establish decorrelation.

Authorized: one Strategy Card, deterministic allocation, branch-only non-live
V5 build, reference tests, strict Q01, one fixed-risk D1 set, and one paced Q02
enqueue while CPU admission is clear. Forbidden: manual backtests,
optimization, live/demo/shadow/stress presets, portfolio-gate edits,
correlation waivers, portfolio admission, deployment/live manifests,
`T_Live`, AutoTrading, terminal control, or live use.
