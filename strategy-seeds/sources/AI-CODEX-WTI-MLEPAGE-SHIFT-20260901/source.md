---
source_id: AI-CODEX-WTI-MLEPAGE-SHIFT-20260901
title: WTI monthly Lepage joint location-scale shift continuation
publisher: QuantMechanica governed AI synthesis from peer-reviewed WTI and location-scale-method research plus complete official CRAN implementation evidence
source_type: ai_originated_peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_lepage_shift_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
method_records:
  - LEPAGE-1971
  - HUSSAIN-TSAGRIS-2025-V3
  - CRAN-LEPAGE-1.0
created: 2026-09-01
created_by: Research+Development
cards_extracted:
  - QM5_41270_wti-mlepage-shift-tr
---

# WTI Monthly Lepage Joint Location-Scale Shift Continuation

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_wti_monthly_lepage_shift_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one reputable-
source, structural low-frequency sleeve and identifies direct WTI trend or
seasonality as eligible. This packet is bounded to one card, one branch build,
strict Q01, and one paced non-live Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   which preserves a complete 23-page read of Moskowitz, Ooi, and Pedersen
   (2012), *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, including own-return continuation and
   explicit NYMEX WTI membership;
2. Hussain and Tsagris (2025), arXiv `2509.19126v3`, all twenty pages, PDF
   SHA-256
   `1761E9D22E26B79D6A21496CDD4C237CBAB27B35A232C29830A0B957C7531359`,
   including its derivations of the classical Wilcoxon and Ansari-Bradley
   component moments, the classical Lepage `L0` quadratic sum, the
   chi-square-two asymptotic reference, limitations, simulations, and adverse
   preference for robustified variants under its target weak-null setting;
3. the complete CRAN `LePage` 1.0 source archive, SHA-256
   `613165E7F2809DCFDED603A85B322B6781132A27F16B0CC7F8FF430BC89042CE`,
   including every source, manual, metadata, namespace, and manifest file.

Lepage (1971), "A combination of Wilcoxon's and Ansari-Bradley's statistics,"
*Biometrika* 58(1), 213-217, DOI `10.1093/biomet/58.1.213`, supplies the named
original peer-reviewed method record. Publisher metadata and abstract plus
Crossref metadata were read. The original body was access-blocked, so no
complete original-paper read, hidden derivation, table value, or PDF hash is
claimed. Exact arithmetic comes from the complete author preprint and complete
official package record. Retrieval hashes and access boundaries are stored
beside this packet.

No external runtime source, inferred result, trained output, or unpublished
performance number enters the hypothesis.

## Sources Of Record And Adverse Evidence

Moskowitz, Ooi, and Pedersen define a broad own-return momentum family on
liquid futures and explicitly include NYMEX WTI. Their pooled commodity
result does not establish a WTI-only effect, a twenty-five-session direction
horizon, a Lepage regime gate, a continuous-CFD translation, fixed risk, or
the QM lifecycle. Their excess returns, rolling contracts, volatility sizing,
costs, and portfolio results do not transfer.

Hussain and Tsagris state the classical Lepage statistic as the sum of squared
standardized Wilcoxon-Mann-Whitney location and Ansari-Bradley scale
components. They show the even-sample component moments and the asymptotic
chi-square-two reference. Their paper concerns independent biomedical samples,
not overlapping WTI returns. It also finds that newer robustified variants can
outperform classical `L0` for right-skewed weak-null inference. This card does
not suppress that adverse finding: it uses `L0` only as an interpretable,
fully locked ordinal regime score and claims neither hypothesis-test validity
nor significance.

The complete CRAN implementation independently fixes pooled ordering, the
recent-sample rank sum, mirrored tail ranks, component normalization, the
classical quadratic sum, and chi-square-two reference. Ties are implementation-
sensitive; the EA fails closed on any exact pooled return tie rather than
importing an unapproved midrank correction.

## Source Claim Boundary

The sources jointly motivate one bounded question: when the latest twenty-
five completed WTI daily returns show sufficiently large joint ordinal
location and tail/center-scale displacement from the preceding twenty-five,
does the latest twenty-five-session WTI return direction continue for one
broker month?

No source tests this conjunction. Fifty-one completed D1 closes, adjacent log
returns, fixed twenty-five/twenty-five membership, strict ties, chi-square-two
median gate, cumulative-return side, monthly attempt, continuous-CFD mapping,
fixed-dollar risk, stop, spread, and lifecycle are pre-result QM choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
significance, CFD equivalence, independence, decorrelation, or portfolio
statistic transfers from a source.

## Exact Statistical Contract

At a broker-month transition, reconstruct fifty-one positive, finite,
strictly chronological completed `XTIUSD.DWX` D1 closes `C[0..50]`, oldest to
newest. The current D1 bar is excluded and the newest completed label may be
no more than four calendar days stale.

Form fifty chronological adjacent log returns:

```text
r[i] = log(C[i+1]/C[i]), i=0..49
old = r[0..24]
recent = r[25..49]
```

Require every return finite and all fifty values pairwise distinct. Sort the
pooled observations ascending while retaining old/recent membership. Assign
ordinary ranks `j=1..50` and symmetric end ranks
`a(j)=min(j,51-j)`, whose path is `1,2,...,25,25,...,2,1`.

For the twenty-five recent observations:

```text
W = sum(j)
A = sum(a(j))

mu_W  = 25*(50+1)/2             = 637.5
var_W = 25*25*(50+1)/12         = 2656.25
mu_A  = 25*(50+2)/4             = 325
var_A = 25*25*(50^2-4)/(48*49)  = 32500/49

zW2 = (W-mu_W)^2/var_W
zA2 = (A-mu_A)^2/var_A
L = zW2 + zA2
```

Require finite nonnegative component squares and statistic. Qualify iff
`L>=1.3862943611198906`, exactly `2*ln(2)`, the median of the asymptotic
chi-square distribution with two degrees of freedom. There is no p-value,
permutation, CDF lookup, adaptive critical value, optimizer, or statistic-
magnitude sizing. Compute `recent_return=sum(r[25..49])`; buy above `1e-12`,
sell below `-1e-12`, and consume flat otherwise.

## Pre-Result Activity And Duplicate Boundary

Under the source asymptotic chi-square-two reference, the median threshold
qualifies half of null-state observations, giving a rough six-attempt-per-year
prior before overlap, dependence, strict ties, neutral direction, data, and
execution gates. This is not a WTI frequency or performance result. Q02 must
retire the candidate below five completed positions in any full post-warm-up
year.

The corrected-root receipt
`artifacts/qm5_wti_mlepage_shift_tr_preallocation_dedup_20260901.json`,
SHA-256
`FFF74031E1A7636A78816E6EB0AB67B6CA2731467577CA4D656D96A4B52C2A97`,
checked 4,769 registry rows, 1,406 cards, and 45 Wiki nodes and returned one
fuzzy match, `QM5_41268`, for mandatory manual review.

The new mechanic is distinct:

- `QM5_41268` uses four trigonometric empirical-characteristic-function
  features, feature covariance, and a guarded matrix inverse. This source
  uses only pooled ranks, a monotone location score, a mirrored tail/center
  scale score, and their fixed standardized quadratic sum.
- `QM5_41176` is a location-only six-by-six rank threshold on completed
  monthly endpoint prices.
- `QM5_41261` is a scale-only six-by-six exact lower-tail rule on twelve
  completed monthly returns.
- `QM5_41266` and `QM5_41267` are scale-only monthly-return gates.

For recent pooled ranks
`{1,2,4,5,7,8,9,10,12,13,16,23,25,28,29,30,34,37,38,39,40,41,43,45,48}`,
`W=587`, `A=295`, `zW2=0.9600941176470589`,
`zA2=1.356923076923077`, and `L=2.317017194570136`. Neither component alone
reaches the gate; the joint state qualifies. For ranks
`{1,2,6,7,8,9,10,19,20,22,23,25,26,27,28,29,33,36,37,39,43,45,46,49,50}`,
`W=640`, `A=327`, and `L=0.008383710407239817`, so it stays flat. These fixed
fixtures are part of the implementation parity contract.

Manual verdict:
`DISTINCT_WTI_MONTHLY_FIXED_25_BY_25_DAILY_RETURN_LEPAGE_JOINT_WILCOXON_ANSARI_BRADLEY_LOCATION_SCALE_CHI_SQUARE_TWO_MEDIAN_GATE_RECENT_RETURN_CONTINUATION`.

## Mechanical Execution Contract

- Exact host/traded symbol `XTIUSD.DWX`, exact `PERIOD_D1`, slot 0, registered
  magic, and one consumed attempt per normalized broker month.
- Persist the month marker before history, signal, spread, quote, ATR, sizing,
  margin, or order checks. No outcome retry is permitted in that month.
- Backtest risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Use one completed-bar `ATR(20,D1)` frozen at entry and a broker hard stop at
  `3.5*ATR`; no target.
- Reject spread above 1,500 points; use deviation 20 points.
- Exit on the first processed tick in a later normalized broker month or
  after forty calendar days as stale repair.
- Repair duplicate, wrong-symbol, wrong-magic, wrong-side, or stopless owned
  exposure before entry-only gates.
- Both news axes, legacy news mode, and Friday close are OFF.
- No target, trail, break-even, partial close, intramonth flip, scale-in,
  pyramid, grid, martingale, external feed, file read, randomization, trained
  output, optimization, or portfolio-state input is authorized.

## Falsification And Safety Boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, failed CRAN/formula fixture parity, nonpositive governed
economics, or any downstream gate failure. A change to symbol, cadence,
close/return count, block membership, tie rule, score formula, component
moments, statistic threshold, direction, attempt timing, risk, stop, spread,
or lifecycle requires a new EA identity and full pipeline requalification.

This source authorizes only one Strategy Card. After G0 it may authorize one
branch build, deterministic reference tests, strict Q01, one D1 `RISK_FIXED`
backtest setfile, and one paced non-live Q02 handoff if the CPU ceiling
permits. It does not authorize a manual tester run, optimization,
live/demo/shadow/stress setfile, AutoTrading, `T_Live`, deploy/live manifest,
portfolio-gate mutation, portfolio admission, or correlation waiver.
