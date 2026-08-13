---
source_id: YIYI-WTI-ES-REGIME-2026
parent_source_id: YIYI-ES-2025
title: WTI Self-Relative Expected-Shortfall Regime
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_carrier
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20301_wti_es_regime_g0.md
parent_sha256: AC00A311DCA3BDB3C1BF47725EAB1887BC0335ADE84E898F4DBD8117C3A36FE9
created: 2026-08-13
created_by: Research+Development
cards_extracted:
  - wti-es-regime
---

# WTI Self-Relative Expected-Shortfall Regime Source Packet

## Approved Trading Source Of Record

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity
Futures Characteristics and Asset Pricing Models," *Journal of Futures
Markets* 45(3), 176-207, DOI `10.1002/fut.22559`.

The complete open prepublication article, appendices, tables, and references
were read end to end in the governed parent packet
`strategy-seeds/sources/YIYI-ES-2025/source.md`, which is content-bound by the
SHA-256 above. The durable OWNER authorization for this carrier is
`decisions/2026-08-13_qm5_20301_wti_es_regime_g0.md`.

## Trading-Source Findings Used

- The source measures commodity characteristics before prediction month t,
  ranks a 34-futures cross-section monthly, and holds sorted portfolios during
  month t.
- Expected shortfall is the arithmetic mean of the worst five percent of
  daily returns over months t-12 through t-1.
- The source direction is high expected shortfall minus low expected
  shortfall. Because the statistic is normally negative, high means a less
  damaging historical lower tail.
- The broad-universe one-way hedge has only a 1.36 full-sample t-statistic;
  the source's stronger result is concentrated in its early subsample.
- Expected shortfall remains associated with latent-factor loadings in the
  source, but no latent-factor or IPCA estimator is part of this extraction.
- The source studies exchange-traded futures, not an outright continuous-CFD
  time-series state.

## Bounded Carrier Mechanization

At the first processed WTI D1 bar of a genuine broker-month transition, load
exactly 505 completed `XTIUSD.DWX` D1 closes, newest first. Form two
consecutive blocks of exactly 252 simple returns. Sort each complete return
vector ascending, compute the mathematical ceiling of five percent, and
average exactly the lowest thirteen observations:

```text
r[b,k] = close[b+k] / close[b+k+1] - 1, k = 0..251
K      = ceil(252 * 0.05) = 13
ES[b]  = arithmetic_mean(13 smallest r[b,0..251])

recent block:    b = 0
preceding block: b = 252
```

Buy WTI when recent ES is higher than preceding ES and sell WTI when it is
lower. Use one fixed-risk position, attach a frozen ATR hard stop, and close
at the next broker-month transition. A tie or invalid state consumes the
month without a trade or retry.

This preserves the source estimator, high-minus-low direction, and monthly
cadence while translating a broad cross-sectional sort into a self-relative
two-block WTI state. It does not transfer a source return, alpha,
significance, cost, WTI-only result, CFD equivalence, trade density,
neutrality, or correlation claim.

## Adverse Family Evidence

`QM5_13143_energy-es-rank` uses the same expected-shortfall characteristic in
a two-leg XTI/XNG rank. It passed its Q02 rows but failed Q04 in every OOS
fold, with net PF values 0.782, 0.314, and 0.000. That failure is retained as
a material negative prior. It does not prove the distinct single-WTI
self-relative carrier will fail, and it supplies no waiver, parameter change,
or performance inheritance.

`QM5_20235_xauxag-es-rank` is a second paired carrier. Its recorded Q02 rows
are infrastructure failures and one pending retry rather than an economic
verdict. No claim is inferred from them.

## Exact Runtime Contract

- Use only completed D1 bars and exactly 505 closes. The recent block uses
  close-index pairs `0/1` through `251/252`; the preceding block uses pairs
  `252/253` through `503/504`. They share one boundary close and no return.
- Require strictly older timestamps as series index increases, a newest
  endpoint before the decision bar and no more than ten calendar days stale,
  positive finite closes, finite simple returns and ES values, and exactly
  thirteen selected lowest observations per block.
- Buy when `ES[0] > ES[252] + 1e-12`; sell when
  `ES[0] < ES[252] - 1e-12`; consume the month flat otherwise.
- Do not use log returns, a quantile cutoff without tail averaging, another
  probability, semivariance, skewness, kurtosis, MAX, winsorization, a fitted
  threshold, overlapping return support, score sizing, or a fallback signal.
- Host on WTI D1, use slot 0, risk one `RISK_FIXED=1000` position, renew
  monthly, close stale after forty days, and persist the attempted month
  before any history or execution gate.

## Non-Duplicate Boundary

The canonical checker found no exact slug, strategy-ID, or mechanic identity
across 4,366 registry rows and 477 root cards. Five expected fuzzy matches
were manually resolved:

- `QM5_13143_energy-es-rank` and `QM5_20235_xauxag-es-rank` rank two
  concurrent instruments and execute paired packages. This extraction
  compares two disjoint WTI history blocks and owns one position.
- `QM5_20300_wti-max-regime` uses exactly five largest positive returns per
  block and buys the lower-MAX state. This extraction uses thirteen smallest
  returns per block and buys the higher-ES state.
- `QM5_20289_wti-rsj-rev` compares one month of separately squared upside and
  downside returns; it neither sorts the lower five-percent tail nor compares
  two disjoint annual blocks.
- WTI skewness, kurtosis, realized VoV, cumulative-return trend, robust
  location, calendar, event, channel, variance-ratio, and reversal systems use
  different information objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback, not a monthly symmetric WTI downside-tail state.

The exact two offsets, disjoint return support, 252 simple returns per block,
ceiling-derived thirteen-return lower-tail mean, self-relative direction,
single WTI carrier, and monthly consumed attempt are jointly load-bearing.
Verdict: `CLEAN_AUTHORIZED_WTI_TIME_SERIES_ES_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS with weak-evidence caveat. Peer-reviewed Journal of Futures
  Markets article, DOI, publisher record, complete-open-paper read, exact
  source transform, and adverse source/sibling results disclosed.
- R2: PASS. Fixed two-block estimator, tail probability and count, direction,
  cadence, risk, stop, attempt, renewal, and stale guard.
- R3: PASS for the disclosed proxy. Registered `XTIUSD.DWX` D1 history and
  native framework state suffice; futures/CFD equivalence is not assumed.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited
  signal indicator, external runtime feed, grid, martingale, or pyramid.

## Claim, Kill, And Safety Boundary

Q02 must retire the carrier below five completed positions per full post-
warm-up year or on nonpositive governed economics. Q09 alone may establish
realized book correlation. No failed result may change the formula, block
offset, probability, direction, carrier, formation, cadence, risk, stop,
hold, spread, or retry policy.

This packet authorizes one branch-only non-live build and paced Q02 handoff.
It excludes manual testing, live/demo/shadow/stress/optimization artifacts,
AutoTrading, `T_Live`, deploy manifests, portfolio gates, portfolio admission,
and correlation waivers.
