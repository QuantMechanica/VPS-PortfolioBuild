---
source_id: AI-CODEX-XAUXAG-MVDW-RV-20260902
title: XAU/XAG monthly Van der Waerden normal-score reversion
publisher: QuantMechanica governed AI synthesis from peer-reviewed relationship evidence and official exchange/statistical method records
source_type: ai_originated_peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_xauxag_monthly_van_der_waerden_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
method_records:
  - NIST-TWO-SAMPLE-LINEAR-RANK-VAN-DER-WAERDEN
  - SAS-NPAR1WAY-VAN-DER-WAERDEN-SCORES-EXACT
created: 2026-09-02
created_by: Research+Development
cards_extracted:
  - QM5_41282_xauxag-mvdw-rv
---

# XAU/XAG Monthly Van der Waerden Normal-Score Reversion

## Approval And Complete Read

The durable source approval is
`decisions/2026-09-02_xauxag_monthly_van_der_waerden_reversion_source_approval.md`,
commit `396bdf003a`. The current explicit OWNER commodity/energy mission
authorizes one reputable-source, structural low-frequency sleeve and names a
market-neutral-style gold/silver basket as an eligible route. This packet is
bounded to one card, one branch build, strict Q01, and one paced non-live
logical-basket Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`,
   the governed complete-read record of Schweikert (2018), *Journal of
   Banking & Finance* 88, 44-51;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   the official CME gold/silver-ratio carrier record;
3. the complete bounded NIST/SEMATECH two-sample linear-rank sections; and
4. the complete bounded SAS/STAT NPAR1WAY normal-score and exact-test
   sections.

Exact URLs, frozen response hashes, read scopes, constants, independent
reproduction, and claim boundaries are in
`retrieval_route_vdw_scores_20260902.json`.

## Sources Of Record And Adverse Evidence

Schweikert finds a state-dependent and asymmetric gold/silver relation.
Constant-vector cointegration fails in important specifications, some daily
upper quantiles reject quantile cointegration, the relevant state is not
known ex ante, and the estimates do not directly produce a forecast. This is
adverse evidence against treating the ratio as a stable deterministic spread.

CME defines the gold/silver ratio as gold price divided by silver price per
troy ounce and describes an opposed-leg intermarket spread. It also separates
gold's monetary/safe-haven demand from silver's larger industrial-cycle
exposure. Futures liquidity, margin offsets, and execution quality do not
transfer to continuous CFDs.

NIST and SAS independently define the Van der Waerden score

```text
a(r) = Phi^-1(r/(N+1))
```

and classify it as a location score. SAS documents an exact two-sample Van
der Waerden test based on a simple linear-rank statistic. The official
records define arithmetic and method identity only. They do not define a
market carrier, sample, threshold, side, hold, or risk model.

## Source Claim Boundary

The records jointly motivate one bounded question: when the latest six
synchronized monthly gold/silver ratio changes carry an extreme signed
normal-score rank sum relative to the prior six, does fading that location
shift during the next broker month produce a viable relative-value stream?

No source tests this conjunction. Thirteen synchronized endpoints, adjacent
log-ratio changes, fixed six/six chronological blocks, strict tie rejection,
the fifteen-decimal score freeze, complete 924-label absolute-score
enumeration, inclusive 462-tail activity boundary, contrarian score-sign
side, continuous-CFD mapping, equal target notionals, fixed-dollar risk, hard
stops, spread ceilings, attempt persistence, package atomicity, and lifecycle
are pre-result QM choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
hedge ratio, neutrality, CFD equivalence, p-value, critical value,
decorrelation, or portfolio statistic transfers from any source.

## Exact Statistical Contract

At a broker-month transition reconstruct thirteen synchronized, positive,
finite, consecutive completed-month XAU/XAG close pairs. For chronological
endpoints `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11

old    = r[0..5]
recent = r[6..11]

require all twelve changes finite and pairwise distinct under
tie_tol(a,b) = 1e-12 * max(1,abs(a),abs(b))

pool and sort the twelve changes ascending
R = the six pooled ranks 1..12 carried by recent observations

for rank r=1..12:
    a(r) = Phi^-1(r/13)
    n(r) = round_half_away_from_zero(a(r) * 10^15)

S_num = sum[n(r) for r in R]

assignment_count = 0
tail_count = 0
for every one of C(12,6)=924 choices P of six recent ranks:
    S_perm_num = sum[n(r) for r in P]
    if abs(S_perm_num) >= abs(S_num):
        tail_count++
    assignment_count++

require assignment_count == 924
require tail_count <= 462
require S_num != 0

BUY XAU / SELL XAG iff S_num < 0
SELL XAU / BUY XAG iff S_num > 0
```

For audit-stable verification, the twelve signed integer score numerators
over denominator `10^15` are:

```text
rank:       1                 2                 3                4
numerator: -1426076872272847 -1020076232786202 -736315917376130 -502402223373355

rank:       5                6               7              8
numerator: -293381232121193 -96558615289639 96558615289639 293381232121193

rank:       9               10               11                12
numerator:  502402223373355 736315917376130 1020076232786202 1426076872272847
```

The integers sum exactly to zero and stay far below signed 64-bit limits even
after six-score summation. The freeze is a deterministic finite-precision
representation of the official formula, not a fitted coefficient.

## Exact Activity Prior

Complete enumeration of all 924 strict six-rank assignments yields:

- twenty exact zero-score assignments, all flat;
- 462 qualifying assignments at inclusive tail count at most 462;
- 231 BUY-XAU and 231 SELL-XAU assignments; and
- six directional states per twelve combinatorial attempts.

The minimum qualifying absolute numerator is `1041895523917931`. This is a
market-free label-space prior only. It is not a p-value, serial-independence
claim, market trade count, or evidence of efficacy. Q02 must retire the card
on zero packages or fewer than five completed packages in any full scored
post-warm-up year.

## Non-Duplicate Boundary

The corrected-root receipt
`artifacts/qm5_xauxag_mvdw_rv_preallocation_dedup_20260902.json`, SHA-256
`F356B42F07A95D6F5929A75AF3C5067D18A3A9EC7B830D2A0DBF40D999790310`,
found no exact identity across 4,781 registry rows, 1,417 cards, and all 45
Strategy Wiki nodes. Expected shared-carrier fuzzy matches were resolved by
formula review.

This mechanic applies signed monotone normal-quantile scores to raw pooled
changes. It does not apply Savage harmonic scores, linear Wilcoxon ranks,
Cucconi or Anderson-Darling distribution-path quadratics, Klotz squared
normal scores after block centering, or Conover squared ranks of absolute
deviations.

Locked strict-rank fixtures prove decision disagreement:

| path | Van der Waerden | neighbor |
|---|---|---|
| `RRROOOORORRO` | numerator `-1132695640151654`, tail 422, BUY XAU | Savage tail 616 and Wilcoxon tail 544, both flat |
| `RRROROOOOORR` | tail 476, flat | Wilcoxon centered rank sum -5, tail 448, BUY XAU |
| `RRROOOOOORRR` | exact zero, flat | Savage score 1.3414502164502164, tail 400, SELL XAU |

`O` and `R` label the old/recent ownership of ascending pooled changes.
Complement paths lock score and side symmetry.

## Executable Mechanization

- Evaluate only from an `XAUUSD.DWX` D1 host chart.
- At the first synchronized executable D1 boundary of a broker month, consume
  that month before reconstructing history or testing a signal.
- Use thirteen consecutive completed synchronized month-end pairs; the latest
  completed pair must immediately precede the current broker month and must
  be no more than ten calendar days stale.
- Form twelve adjacent log-ratio changes in chronological order, split six
  old/six recent, reject any pooled relative tie, rank, score, enumerate, and
  apply the exact tail and side rules above.
- Permit no more than one package per broker month and no intramonth retry.
- Submit XAU first and XAG second. Flatten immediately if both owned legs do
  not form the expected opposed package.
- Exit both legs at the first later broker month or after forty elapsed
  calendar days. Close both if the package becomes malformed.

## Risk And Execution Boundary

- Backtest: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Split the frozen-stop budget equally across the two legs; target equal
  absolute USD notionals by volume reduction only.
- Reject rounded notional mismatch above 20 percent.
- Freeze independent `3.5*ATR(20,D1)` broker hard stops for both legs.
- Reject XAU/XAG spreads above 1,500/500 points.
- Disable both news axes, legacy news mode, Friday close, and stress rejection.
- Score or tail magnitude must never scale volume.
- No live/demo/shadow/stress preset, manual tester run, portfolio-gate change,
  deployment, live manifest, `T_Live`, AutoTrading, or terminal control is
  authorized.

Equal target notionals and opposed legs are market-neutral-style construction
only. They do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone may establish realized overlap.
