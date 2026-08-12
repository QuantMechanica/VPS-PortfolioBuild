---
source_id: HOLLSTEIN-XAUXAG-KURT-2026
title: XAU/XAG historical-kurtosis rank carrier extraction
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_carrier
status: approved_source_complete
approval_basis: decisions/2026-08-12_qm5_20291_xauxag_kurt_rank_g0.md
parent_source_id: HOLLSTEIN-MAX-2021
parent_sha256: 66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47
created: 2026-08-12
created_by: Research+Development
cards_extracted:
  - xauxag-kurt-rk
---

# XAU/XAG Historical-Kurtosis Rank Source Packet

## Approved Trading Source Of Record

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017, DOI `10.1142/S2010139221500178`.

The complete 57-page accepted article and online appendix were read end to
end in the governed parent packet
`strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md`, which is content-bound
by the SHA-256 above. The durable OWNER authorization for this carrier is
`decisions/2026-08-12_qm5_20291_xauxag_kurt_rank_g0.md`.

## Trading-Source Findings Used

- The source constructs commodity characteristics from daily data over the
  preceding year, ranks a broad futures cross-section at month-end, and holds
  sorted portfolios for one month.
- Appendix B defines historical kurtosis from 252 daily simple returns as
  the fourth central moment divided by squared sample variance.
- The full-sample three-portfolio historical-kurtosis spread is positive, so
  the locked mechanical direction is high kurtosis long and low kurtosis
  short.
- The directly relevant two-portfolio result is positive but insignificant;
  the post-financialization result reverses sign and is insignificant; and
  the cross-sectional regression slope is insignificant.
- The source uses a diversified futures universe, not a two-metal continuous-
  CFD pair.

## Bounded Carrier Mechanization

At the first processed XAU D1 bar of a genuine broker-month transition, load
253 completed D1 closes for each of `XAUUSD.DWX` and `XAGUSD.DWX`. Form
exactly 252 chronological simple returns. For each leg compute:

```text
mu = average(r[d])
sample_variance = sum((r[d] - mu)^2) / 251
fourth_moment = sum((r[d] - mu)^4) / 252
historical_kurtosis = fourth_moment / sample_variance^2
```

Buy the higher-kurtosis metal and short the lower-kurtosis metal. Split one
fixed-risk package equally, attach independent frozen ATR hard stops, and
close at the next broker-month transition. A tie or invalid state consumes
the month without a trade or retry.

This preserves the source estimator, direction, and cadence while narrowing
the cross-section and changing the carrier. It does not transfer a source
return, alpha, significance, cost, CFD equivalence, trade density, or
correlation claim. Opposite sides and equal stop-risk halves do not prove
dollar, beta, volatility, factor, or portfolio neutrality.

## Exact Runtime Contract

- Use only completed D1 bars and exactly 253 closes/252 simple returns per
  leg; require strictly increasing timestamps and a newest endpoint before
  the decision bar and no more than ten calendar days stale.
- Require positive finite closes, finite returns and moments, positive sample
  variance, positive finite kurtosis, and absolute rank difference above
  `1e-12`.
- Do not use log returns, excess kurtosis, bias correction, winsorization,
  ratio levels, OLS residuals, adaptive thresholds, score sizing, or a
  fallback signal.
- Host on XAU D1, use XAU slot 0 and XAG slot 1, split aggregate fixed risk
  equally, renew monthly, close stale after forty days, repair orphans, and
  persist the attempted month before data or order gates.

## Non-Duplicate Boundary

`QM5_13131` is the same approved characteristic on XTI/XNG and supplies no
performance evidence for this carrier. XAU/XAG skewness, semivariance,
expected-shortfall, volatility-of-volatility, variance-ratio, robust-spread,
ratio, OLS, quantile, momentum, and calendar systems use other information
objects or directions. The legacy kurtosis EAs combine higher moments with
other fast signals rather than trading a pure monthly two-metal rank.
Verdict: `CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS with weak-evidence caveat. Peer-reviewed QJF article, DOI,
  institutional accepted manuscript, complete-read parent record, and
  disclosed insignificant/sign-reversed robustness results.
- R2: PASS. Exact observation count, denominators, Pearson formula,
  direction, cadence, risk, stops, attempt, renewal, and orphan behavior.
- R3: PASS. Registered XAU/XAG `.DWX` D1 history and native execution state.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited
  signal indicator, external runtime feed, grid, martingale, or pyramiding.

## Claim, Kill, And Safety Boundary

Q02 must retire the carrier below five completed packages per full post-
warm-up year or on nonpositive governed economics. Q09 alone may establish
realized book correlation. No failed result may change the formula,
direction, carrier, formation, cadence, risk, stop, hold, spread, or retry
policy. The packet authorizes one branch-only non-live build and paced Q02
handoff; it excludes manual testing, live artifacts, AutoTrading, `T_Live`,
deploy manifests, portfolio gates, and portfolio admission.

