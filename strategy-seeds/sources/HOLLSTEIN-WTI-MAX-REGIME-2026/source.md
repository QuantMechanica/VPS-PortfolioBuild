---
source_id: HOLLSTEIN-WTI-MAX-REGIME-2026
parent_source_id: HOLLSTEIN-MAX-2021
title: WTI Self-Relative Low-MAX Regime
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_carrier
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20300_wti_max_regime_g0.md
parent_sha256: 66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47
created: 2026-08-13
created_by: Research+Development
cards_extracted:
  - wti-max-regime
---

# WTI Self-Relative Low-MAX Regime Source Packet

## Approved Trading Source Of Record

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017, DOI `10.1142/S2010139221500178`.

The complete 57-page accepted article and online appendix were read end to
end in the governed parent packet
`strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md`, which is content-bound
by the SHA-256 above. The durable OWNER authorization for this carrier is
`decisions/2026-08-13_qm5_20300_wti_max_regime_g0.md`.

## Trading-Source Findings Used

- The source constructs commodity characteristics from daily data over the
  preceding year, ranks a broad futures cross-section at month-end, and holds
  sorted portfolios for one month.
- Appendix B defines MAX as the arithmetic mean of the five largest daily
  commodity-futures excess returns over the preceding twelve months.
- WTI crude oil is an explicit instrument in the source universe.
- The full-sample MAX hedge return and the directly relevant two-portfolio
  split are insignificant.
- Only the December 2000-December 2015 post-financialization subsample shows
  the locked negative high-minus-low relation; the source ends before the QM
  2017+ baseline window.
- The source uses a diversified collateralized futures universe, not an
  outright continuous-CFD time-series state.

## Bounded Carrier Mechanization

At the first processed WTI D1 bar of a genuine broker-month transition, load
exactly 505 completed `XTIUSD.DWX` D1 closes, newest first. Form two
consecutive blocks of exactly 252 simple returns. Sort each complete return
vector ascending and average exactly its five largest observations:

```text
r[b,k] = close[b+k] / close[b+k+1] - 1, k = 0..251
MAX[b] = arithmetic_mean(five_largest(r[b,0..251]))

recent block:    b = 0
preceding block: b = 252
```

Buy WTI when recent MAX is lower than preceding MAX and sell WTI when it is
higher. Use one fixed-risk position, attach a frozen ATR hard stop, and close
at the next broker-month transition. A tie or invalid state consumes the
month without a trade or retry.

This preserves the source estimator, post-financialization direction, and
monthly cadence while translating a broad cross-sectional sort into a
self-relative two-block WTI state. It does not transfer a source return,
alpha, significance, cost, WTI-only result, CFD equivalence, trade density,
neutrality, or correlation claim.

## Exact Runtime Contract

- Use only completed D1 bars and exactly 505 closes. The recent block uses
  close-index pairs `0/1` through `251/252`; the preceding block uses pairs
  `252/253` through `503/504`. They share one boundary close and no return.
- Require strictly older timestamps as series index increases, a newest
  endpoint before the decision bar and no more than ten calendar days stale,
  positive finite closes, finite simple returns and MAX values, and exactly
  five selected largest observations per block.
- Buy when `MAX[0] < MAX[252] - 1e-12`; sell when
  `MAX[0] > MAX[252] + 1e-12`; consume the month flat otherwise.
- Do not use log returns, one maximum return, a percentile, winsorization,
  skewness, kurtosis, realized volatility, volatility-of-volatility, a fitted
  threshold, overlapping return support, score sizing, or a fallback signal.
- Host on WTI D1, use slot 0, risk one `RISK_FIXED=1000` position, renew
  monthly, close stale after forty days, and persist the attempted month
  before any history or execution gate.

## Non-Duplicate Boundary

The canonical checker found no exact slug, strategy-ID, or mechanic identity
across 4,365 registry rows and 476 root cards. Eleven expected fuzzy source-
family matches were manually resolved:

- `QM5_13130_xti-xng-lowmax` and `QM5_20294_xauxag-max-rk` rank two concurrent
  instruments and execute paired packages. This extraction compares two
  disjoint WTI history blocks and owns one position.
- `QM5_20295_wti-kurt-prem` uses all 252 returns in a fourth central moment
  around benchmark three, not five upside order statistics or two blocks.
- `QM5_20298_wti-vov-regime` uses dispersion across rolling realized-
  volatility estimates, not the source MAX characteristic.
- WTI skewness, semivariance, cumulative-return trend, robust-location,
  path-efficiency, calendar, event, channel, variance-ratio, and reversal
  systems use different information objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback, not a monthly symmetric WTI upside-tail state.

The two exact block offsets, disjoint return support, 252 simple returns per
block, top-five arithmetic mean, self-relative direction, single WTI carrier,
and monthly consumed attempt are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_MAX_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS with weak-evidence caveat. Peer-reviewed QJF article, DOI,
  institutional accepted manuscript, complete-read parent record, exact
  source transform, explicit WTI membership, and adverse results disclosed.
- R2: PASS. Fixed two-block estimator, order-statistic count, direction,
  cadence, risk, stop, attempt, renewal, and stale guard.
- R3: PASS for the disclosed proxy. Registered `XTIUSD.DWX` D1 history and
  native framework state suffice; futures/CFD equivalence is not assumed.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited
  signal indicator, external runtime feed, grid, martingale, or pyramid.

## Claim, Kill, And Safety Boundary

Q02 must retire the carrier below five completed positions per full post-
warm-up year or on nonpositive governed economics. Q09 alone may establish
realized book correlation. No failed result may change the formula, block
offset, direction, carrier, formation, cadence, risk, stop, hold, spread, or
retry policy.

This packet authorizes one branch-only non-live build and paced Q02 handoff.
It excludes manual testing, live/demo/shadow/stress/optimization artifacts,
AutoTrading, `T_Live`, deploy manifests, portfolio gates, portfolio admission,
and correlation waivers.
