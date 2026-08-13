---
source_id: YIYI-XNG-ALIQ-REGIME-2026
parent_source_id: YIYI-ALIQ-2025
title: XNG Self-Relative Amihud-Proxy Illiquidity Regime
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_carrier
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20305_xng_aliq_regime_g0.md
parent_sha256: EB8D48BA2F04350634370358961686F24E7842AF09CBE30614FC001452558B85
created: 2026-08-13
created_by: Research+Development
cards_extracted:
  - xng-aliq-regime
---

# XNG Self-Relative ALIQ Regime Source Packet

## Approved Trading Source Of Record

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity
Futures Characteristics and Asset Pricing Models," *Journal of Futures
Markets* 45(3), 176-207, DOI `10.1002/fut.22559`.

The complete open prepublication paper was read end to end in the governed
parent packet `strategy-seeds/sources/YIYI-ALIQ-2025/source.md`, content-bound
by the SHA-256 above. The durable OWNER authorization for this bounded carrier
is `decisions/2026-08-13_qm5_20305_xng_aliq_regime_g0.md`.

The publisher URL was passed to the deterministic source router on
2026-08-13. The exact receipt is `retrieval_route_20260813.json`; it returned
`DEFERRED:SOURCE_POLICY`, so no new page content was read or inferred. The
existing complete-read parent remains the evidence source.

## Trading-Source Findings Used

- The paper studies 34 commodity futures from January 1981 through June 2022,
  including an energy sector, and forms characteristics with information
  available before prediction month t.
- Appendix A defines ALIQ as the prior-twelve-month average of daily absolute
  return divided by dollar volume and multiplied by 1,000,000.
- Table 3 reports a positive broad-universe high-minus-low one-way ALIQ
  portfolio result over 498 months.
- The source characteristic-correlation table reports low pairwise
  correlation between ALIQ and MOM12, IVOL, skewness, MAX, expected shortfall,
  and basis in its broad futures universe.
- The IPCA result for ALIQ is insignificant. IPCA is not used by the card.
- The paper does not test XNG alone, broker quote-tick counts, an own-history
  ALIQ comparison, or a continuous CFD.

## Bounded Carrier Mechanization

At the first processed XNG D1 bar after a genuine broker-month transition,
load exactly 505 completed `XNGUSD.DWX` rates, newest first. Compute the
source ALIQ transform over two consecutive blocks:

```text
r[b,k]       = ln(close[b+k] / close[b+k+1]), k = 0..251
aliq[b,k]    = abs(r[b,k]) / tick_volume[b+k] * 1,000,000
ALIQ[b]      = arithmetic_mean(aliq[b,0..251])

recent block:    b = 0
preceding block: b = 252
```

Buy XNG when recent ALIQ is higher than preceding ALIQ and sell XNG when it
is lower. Use one fixed-risk position, attach a frozen ATR hard stop, and
close at the next broker-month transition. A tie or invalid state consumes
the month without a trade or retry.

This preserves the source estimator, high-minus-low direction, and monthly
cadence while translating a broad cross-sectional dollar-volume sort into a
self-relative two-block XNG quote-activity state. It is not a replication.
No source return, alpha, significance, cost, XNG-only result, CFD equivalence,
trade density, neutrality, or correlation claim transfers.

## Family Evidence

The evidence boundary includes both closest governed siblings:

- `QM5_13140_energy-aliq-rank` ranks concurrent XTI and XNG ALIQ and trades a
  two-leg package. It passed Q02-Q07 and failed Q08 hard on runs-test
  `p=0.00226`; its Q08 baseline had 134 trades and PF 1.44.
- `QM5_20302_wti-aliq-regime` uses the same locked two-block estimator on WTI.
  Its Q02 governed window passed with 39 trades, PF 1.01, net profit 182.72,
  and drawdown 6,667.30.

Neither result transfers to XNG or authorizes a rescue, waiver, parameter
change, efficacy claim, or correlation claim.

## Exact Runtime Contract

- Use exactly 505 completed D1 rates, with positive finite closes and strictly
  positive tick volume on all 504 ending bars used by the transform.
- The recent block uses close-index pairs `0/1` through `251/252` and tick
  volumes `0..251`; the preceding block uses pairs `252/253` through
  `503/504` and volumes `252..503`. The blocks share one boundary close and
  no return or tick-volume observation.
- Require strictly older timestamps as series index increases, a newest
  endpoint before the decision bar and no more than ten calendar days stale,
  and finite log returns, terms, and means.
- Buy when `ALIQ[0] > ALIQ[252] + 1e-12`; sell when
  `ALIQ[0] < ALIQ[252] - 1e-12`; consume the month flat otherwise.
- Do not use simple returns, price volume, volume changes, a percentile,
  winsorization, trend, seasonality, an oscillator, fitted scale, score
  sizing, or a fallback signal.
- Host and trade only XNG D1 on slot 0, risk one `RISK_FIXED=1000` position,
  renew monthly, close stale after forty days, and persist the attempted month
  before any history or execution gate.

## Non-Duplicate Boundary

The canonical checker found no exact slug or strategy-ID identity across
4,370 registry rows and 481 cards. Three expected fuzzy matches were manually
resolved:

- `QM5_13140` ranks concurrent XTI and XNG values and trades opposite legs;
  this extraction compares disjoint XNG histories and owns one position.
- `QM5_20302` is the same locked statistic on a WTI carrier. This XNG carrier
  extension changes the traded return stream without changing parameters and
  inherits no sibling result.
- `QM5_12567` is short-horizon long-only XNG cumulative-RSI pullback logic,
  whereas this extraction is indicator-free, monthly, symmetric long/short,
  and activity-scaled.
- Other XNG tail, moment, trend, calendar, storage-event, variance-ratio, and
  relative-value EAs use different information objects or clocks.

The exact block offsets, disjoint return/activity support, log-return/tick-
volume transform, fixed scale, XNG carrier, source high-ALIQ direction, and
consumed monthly attempt are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_XNG_ALIQ_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS with translation and family-evidence caveats. The primary source is
  peer reviewed, has a DOI, and has a complete-read governed parent packet.
- R2: PASS. Fixed history counts, offsets, transform, scale, direction,
  cadence, risk, stop, attempt, renewal, and stale guard are deterministic.
- R3: PASS for the disclosed proxy. Registered XNG D1 closes and native tick
  volume suffice; quote-tick counts are not dollar volume.
- R4: PASS. Native arithmetic only; no trained output, prohibited signal
  indicator, external runtime feed, grid, martingale, or pyramid.

## Claim, Kill, And Safety Boundary

Q02 must retire the carrier below five completed positions per full post-
warm-up year or on nonpositive governed economics. Q09 alone may establish
realized book correlation. No failed result may change the return type,
volume alignment, scale, block support, direction, carrier, formation,
cadence, risk, stop, hold, spread, or retry policy.

This packet authorizes one branch-only non-live build and paced Q02 handoff.
It excludes manual testing, live/demo/shadow/stress/optimization artifacts,
AutoTrading, `T_Live`, deploy manifests, portfolio gates, portfolio
admission, and correlation waivers.
