---
source_id: AI-CODEX-WTI-ADF-LZ-AGREE-TREND-20260905
title: WTI monthly ADF and LZ76 agreement trend
publisher: QuantMechanica governed synthesis from approved ADF, LZ76, and WTI continuation sources
source_type: ai_originated_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-05_wti_monthly_adf_lz76_agreement_trend_source_approval.md
parent_source_ids: [AI-CODEX-WTI-MADF-PERSIST-TREND-20260903, AI-CODEX-WTI-MLZ76-TREND-20260902, MOP-TSMOM-2012]
created: 2026-09-05
created_by: Research+Development
cards_extracted: [wti-adf-lz-agree-tr]
---

# WTI Monthly ADF and LZ76 Agreement Trend

## Authority and bounded read

The current OWNER mission authorizes one new reputable-source, structural,
low-frequency commodity/energy card and build outside the certified
XAU/SP500/NDX/XNG book. `retrieval_route_20260905.json` binds complete approved
repository records for lag-one ADF arithmetic, exact LZ76 finite-word
complexity, and peer-reviewed monthly WTI continuation. No new network source
is used. The parent records were read completely before this synthesis.

## Structural hypothesis and exact rule

WTI carries production, storage, transport, refining, hedging, geopolitics,
and end-demand exposure absent from the directional index/metal book and
different from XNG weather sensitivity. At the first executable D1 tick of a
new broker month, reconstruct sixty consecutive completed month-end closes
`C[0..59]`, oldest to newest, and set `x[t]=ln(C[t])`.

Fit the lag-one constant/no-time-trend ADF regression over `t=2..59`:

```text
y[t]=x[t]-x[t-1]
z[t]=x[t-1]
w[t]=x[t-1]-x[t-2]
y=alpha+gamma*z+phi*w+error
adf_t=gamma/se_gamma, with SSE/55
```

Require the existing governed finite-energy and determinant checks and
`adf_t >= -2.594`, inclusively.

From newest levels `x[39..59]`, form twenty returns. Map a return strictly
above `+1e-12` to `1` and strictly below `-1e-12` to `0`; a tie invalidates the
month. Parse the twenty-bit word into the unique LZ76 exhaustive history: at
each component start choose the shortest phrase absent from the prefix ending
immediately before that phrase's terminal bit; only the final suffix may be
non-exhaustive. Require exact reconstruction and `2 <= C(S) <= 9`; qualify
inclusively when `C(S) <= 6`.

```text
mom12=x[59]-x[47]
BUY  iff adf_t >= -2.594 and C(S) <= 6 and mom12 > +1e-12
SELL iff adf_t >= -2.594 and C(S) <= 6 and mom12 < -1e-12
FLAT otherwise
```

The two gates overlap and are not independent votes. ADF non-rejection does
not prove persistence, and low LZ76 complexity does not prove predictability.
Only momentum sign chooses side; no magnitude affects risk.

Consume the normalized broker month before every fallible gate and never
retry. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, a 1,500-point spread ceiling, later-
month exit, and forty-day stale repair. News, Friday close, and stress are off.

## Reputable-source criteria

- R1 `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE`: complete approved Wiley
  ADF extraction, complete accessible peer-reviewed LZ76 method manuscript
  with original IEEE provenance, and complete peer-reviewed WTI trading-paper
  record are hash-bound with explicit non-transfer boundaries.
- R2 `PASS`: month clock, endpoints, ADF regression, sign map, exact phrase
  parser, inclusive boundaries, conjunction, side, attempt, risk, stop, spread,
  and lifecycle are deterministic and frozen.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1
  and MT5 state supply every runtime input; roll, financing, gaps, and broker-
  month labels remain material risks.
- R4 `PASS`: bounded timestamps, prices, logarithms, OLS, strings, substring
  equality, integer counts, comparisons, ATR risk, and native execution only;
  no ML, external runtime feed, grid, martingale, or adaptive parameter.

## Non-duplicate boundary

The corrected-root receipt
`artifacts/qm5_wti_adf_lz_agree_tr_preallocation_dedup_20260905.json` found no
exact identity across 4,819 registry rows and 1,438 cards; the configured Wiki
root was missing and is not claimed clean. Expected fuzzy neighbors are
manually distinct: `QM5_41319` has ADF only; `QM5_41309` has LZ76 only;
`QM5_41338` replaces variable-length phrase novelty with raw successive-return
dispersion; `QM5_41337` uses frequency-power entropy; and `QM5_41336` uses
KPSS partial-sum geometry. Fixed fixtures must prove ADF-only, LZ-only, and
up/down agreement paths. Q09 alone owns realized portfolio overlap.

## Kill and safety boundary

Retire unchanged on zero positions, fewer than five positions in any full
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
leakage, invalid fixed risk, missing stop, lifecycle defect, nondeterminism, or
downstream hard failure. No failed result may tune the sample, transform,
thresholds, side, stop, hold, spread, or retry rule.

Authorized after G0 and clean allocation: branch-only non-live build,
reference tests, strict Q01, one fixed-risk set, and one paced Q02 enqueue only
below the CPU ceiling. Forbidden: manual backtests, optimization, live/demo/
shadow/stress presets, terminal control, portfolio-gate edits, correlation
waivers, portfolio admission, deploy/live manifests, `T_Live`, AutoTrading,
or live use.
