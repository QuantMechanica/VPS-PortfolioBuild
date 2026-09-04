---
source_id: AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905
title: WTI monthly ADF and spectral-entropy agreement trend
publisher: QuantMechanica governed synthesis from approved ADF, spectral-entropy, and WTI continuation sources
source_type: ai_originated_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-05_wti_monthly_adf_spectral_entropy_agreement_trend_source_approval.md
parent_source_ids:
  - AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
  - URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902
  - MOP-TSMOM-2012
created: 2026-09-05
created_by: Research+Development
cards_extracted:
  - wti-adf-specent-agree-tr
---

# WTI Monthly ADF and Spectral-Entropy Agreement Trend

## Authority and bounded read

The current explicit OWNER mission authorizes exactly one new reputable-source,
structural, low-frequency commodity or energy sleeve outside the certified
XAU/SP500/NDX/XNG book. It permits direct WTI logic, requires a fixed-risk
backtest preset, and requests one paced Q02 enqueue.

No new public URL is imported. `retrieval_route_20260905.json` binds complete
reads of three already approved repository records: the lag-one ADF packet,
the peer-reviewed spectral-entropy method plus pinned SciPy periodogram
convention, and the peer-reviewed monthly WTI continuation packet. Their
respective SHA-256 hashes are pinned in that receipt.

The parents supply the two statistical methods and the WTI continuation
carrier separately. None tests this conjunction, the shared sixty-endpoint
sample, either frozen threshold as a WTI trading gate, continuous-CFD mapping,
fixed risk, activity, economics, or portfolio correlation.

## Structural hypothesis

WTI carries physical production, storage, transport, refining, geopolitical,
producer-hedging, and end-demand exposure absent from the certified
index/metal carriers and different from XNG weather/storage sensitivity. The
falsifiable hypothesis is that a completed twelve-month WTI move is suitable
for one further broker month only when both of these non-equivalent states
hold:

1. a lag-one ADF regression does not show strong negative error correction;
2. the newest forty-eight monthly returns have spectral power concentrated in
   relatively few frequencies rather than a broad, high-entropy spectrum.

The tests use overlapping observations and are not independent votes. Their
agreement does not prove a unit root, persistence, periodicity,
predictability, profitability, or decorrelation. Q02 owns cadence and
economics; unchanged Q09 alone owns realized portfolio overlap.

## Locked observations

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized broker
month transition, reconstruct exactly sixty consecutive completed broker-
month-end closes `C[0..59]`, oldest to newest, and set `x[t]=ln(C[t])`.
Exclude every current-month price. Fail closed on missing, duplicate,
nonconsecutive, nonchronological, nonpositive, nonfinite, or stale endpoints.

## ADF state

For `t=2..59`, create 58 observations:

```text
y[t] = x[t]-x[t-1]
z[t] = x[t-1]
w[t] = x[t-1]-x[t-2]
y[t] = alpha + gamma*z[t] + phi*w[t] + error[t]
```

Fit centered OLS. Require `Szz>1e-18`, `Sww>1e-18`,
`det=Szz*Sww-Szw^2 > 1e-12*Szz*Sww`, `SSE>1e-18`, residual variance
`SSE/55>0`, and `se_gamma>1e-18`. Set `adf_t=gamma/se_gamma`. The ADF state
qualifies iff `adf_t >= -2.594`, inclusive.

## Spectral-entropy state

Use only the newest forty-nine levels `x[11..59]` and form forty-eight returns:

```text
r[i] = x[12+i]-x[11+i], i=0..47
mean = sum(r[i])/48
d[i] = r[i]-mean
```

For one-sided non-DC bins `k=1..24`, evaluate the length-48 DFT without taper
or padding:

```text
Re[k] = sum(d[i]*cos(2*pi*k*i/48), i=0..47)
Im[k] = -sum(d[i]*sin(2*pi*k*i/48), i=0..47)
raw[k] = Re[k]^2 + Im[k]^2
power[k] = 2*raw[k], k=1..23
power[24] = raw[24]
total = sum(power[k], k=1..24)
p[k] = power[k]/total
Hspec = -sum(p[k]*ln(p[k]), p[k]>0)/ln(24)
```

Require `total>1e-24`, probability sum within `1e-10` of one, finite
components, and entropy within `[-1e-12,1+1e-10]`; clamp only admitted
roundoff to `[0,1]`. The state qualifies iff `Hspec <= 0.88`, inclusive.

## Agreement, direction, and lifecycle

```text
mom12 = x[59]-x[47]

BUY  iff adf_t >= -2.594 and Hspec <= 0.88 and mom12 > +1e-12
SELL iff adf_t >= -2.594 and Hspec <= 0.88 and mom12 < -1e-12
FLAT otherwise
```

Only the twelve-month sign chooses side. Statistic or return magnitude never
changes risk. Persist the normalized broker month before history, arithmetic,
news, spread, quote, ATR, sizing, margin, or submission; never retry.

Use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Attach a frozen `3.5*ATR(20,D1)` broker hard stop, no
target, and admit spread only in `[0,1500]` points. Both news axes, legacy
news, Friday close, and stress are off. Close on the first processed tick in a
later broker month or after forty elapsed calendar days. Repair malformed
owned exposure defensively. No intramonth signal exit or flip, target, trail,
break-even, partial close, scale-in, grid, martingale, or pyramid is allowed.

## Reputable-source criteria

- **R1 — PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE.** Complete approved ADF,
  peer-reviewed spectral-entropy/transparent implementation, and peer-reviewed
  WTI continuation records are hash-bound with explicit non-transfer limits.
- **R2 — PASS.** Month clock, endpoints, ADF regression, DFT, power weighting,
  entropy, inclusive boundaries, conjunction, side, attempt, risk, stop,
  spread, and lifecycle are deterministic and locked.
- **R3 — PASS_WITH_CONTINUOUS_CFD_BASIS_RISK.** Registered native
  `XTIUSD.DWX` D1 and MT5 state supply every runtime input; roll, basis,
  financing, gaps, and broker-month labels remain material risks.
- **R4 — PASS.** Only timestamps, completed prices, logarithms, bounded OLS,
  deterministic trigonometry/DFT, sums, comparisons, ATR risk, and native
  execution are used. There is no trained output, banned signal indicator,
  external runtime feed, optimizer output, randomness, grid, or martingale.

## Non-duplicate boundary

The corrected-root receipt
`artifacts/qm5_wti_adf_specent_agree_tr_preallocation_dedup_20260905.json`
found no exact identity across 4,817 registry rows and 1,436 cards. The
configured Strategy Wiki root was absent, so its zero-node result is not
represented as a clean external-vault scan. Four expected fuzzy neighbors
require manual resolution:

- `QM5_41319` has only the ADF state and admits high-entropy paths.
- `QM5_41312` has only the spectral-entropy state and admits ADF-reverting
  paths.
- `QM5_41336` replaces spectral entropy with constant-only KPSS partial-sum
  geometry; a low-entropy path can fail KPSS and a KPSS-qualified path can
  remain high entropy.
- `QM5_41320` uses a lag-zero AR(1) and eleven-lag Phillips-Perron correction,
  not the lag-one ADF plus frequency-domain conjunction.

The independent fixture must pin at least one ADF-only qualifier, one
spectral-only qualifier, one ADF+KPSS qualifier rejected for high entropy, and
executable up/down agreement paths. Manual identity verdict:
`DISTINCT_PRICE_LEVEL_ERROR_CORRECTION_AND_FREQUENCY_POWER_CONJUNCTION`.
Shared WTI continuation may still correlate; no identity decision waives Q09.

## Claim, kill, and safety boundary

Q02 retires the unchanged identity on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, formula/fixture mismatch, current-month leakage, invalid fixed
risk, missing stop, lifecycle defect, nondeterminism, or downstream hard
failure. No failed result may tune the sample, transform, lags, bins,
thresholds, direction, stop, spread, hold, or retry rule.

Authorized after G0 and clean registries: one branch-only non-live build,
independent reference tests, strict Q01, one fixed-risk preset, and one paced
Q02 enqueue below the binding CPU ceiling. Forbidden: manual backtests,
optimization, live/demo/shadow/stress presets, terminal control, portfolio-
gate edits, correlation waivers, portfolio admission, deploy/live manifests,
`T_Live`, AutoTrading, or live use.
