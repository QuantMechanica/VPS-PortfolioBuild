---
source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
title: WTI weekly widest-range-of-four close momentum
status: approved_source_complete
source_type: governed_composite_mechanization
approval_basis: decisions/2026-08-21_wti_weekly_wr4_close_momentum_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026_S01
parent_sources:
  - source_id: MOP-TSMOM-2012
    sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  - source_id: MOP-WTI-WCLOSE-LOCATION-MOM-2026
    sha256: 60292F608787EEC685AAF7B375D66B5A819E21EF2711FA2970AE73945B70F25D
  - source_id: CRABEL-WTI-NR7-BRK-2026
    sha256: F16BDC01745C6A5A7ABB3B2F2924BE23A66A3E215C74E49B863457A1E2423D1E
  - source_id: CRABEL-WTI-WEEK-ORB-2026
    sha256: 4C97D7148BE4A5507AB440F0D980B81A32F1302B01059BC29CF3FF3D7DFA4F82
---

# WTI weekly widest-range-of-four close momentum

## Source claim

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid futures, including crude
oil: an instrument's own past return can contain directional information. Crabel documents
systematic range-based setups built around volatility contraction and expansion. The existing
governed WTI weekly source records define reproducible aggregation from D1 bars into
Monday-anchored broker weeks.

The exact rule below is not claimed by those authors. It is a QM composite hypothesis that asks
whether an unusually expansive completed WTI week whose close agrees with its own direction
continues into the next broker week.

## Deterministic translation

Evaluate once on the first tradable D1 bar of each new Monday-anchored broker week.

1. Aggregate the four immediately preceding completed broker weeks from D1 bars.
2. Require each completed week to contain three to five D1 sessions.
3. Require consecutive weekly anchors; do not skip an incomplete or missing week.
4. Exclude all bars belonging to the current decision week.
5. For every completed week calculate full range `R = high - low`.
6. For the newest completed week calculate own-week body `B = ln(close / open)` and close-location
   value `CLV = (close - low) / R`.
7. Require the newest completed week to have a range strictly greater than each of the preceding
   three ranges. Equality is no signal.
8. BUY only when `B > 0` and `CLV > 0.75`.
9. SELL only when `B < 0` and `CLV < 0.25`.
10. Zero body, invalid prices, zero range, insufficient history, incomplete weeks, anchor gaps,
    range ties, or equality at either CLV threshold means no signal.

Persist the weekly decision attempt before spread, stop-distance, sizing, margin, or order-send
gates. Permit at most one owned XTIUSD position.

## Frozen trade management

- entry grace: 180 minutes after the first tradable decision bar opens;
- stop loss: `3.5 * ATR(20, D1)`, sampled and frozen at entry;
- take profit: none;
- maximum spread: 1500 points;
- normal exit: first tick whose Monday-anchored broker-week label is later than the entry label;
- fail-safe exit: ten calendar days after entry;
- news filter: OFF;
- Friday close: OFF;
- backtest risk mode: `RISK_FIXED`;
- fixed risk: 1000 account-currency units;
- risk percent: 0.0;
- portfolio weight: 1.

## Expected cadence and falsification

A strict four-week range maximum should occur about once per four completed weeks before the
direction and close-location filters. The frozen hypothesis expects approximately five to eight
entries per full year. A canonical Q02 full-year result below five trades retires the candidate;
thresholds must not be relaxed to rescue cadence.

## Provenance and limitations

Parent records, hashes, complete-read evidence, source boundaries, dedup evidence, and rubric
results are fixed in
`decisions/2026-08-21_wti_weekly_wr4_close_momentum_source_approval.md`.

The research evidence is based primarily on exchange-traded futures and different lookbacks. The
build will trade the DarwinexZero XTIUSD CFD, whose roll treatment, financing, labels, spreads,
and session calendar can differ. The weekly WR4/CLV/body conjunction is an unvalidated engineering
translation. Nothing in this packet establishes profitability, portfolio admission, or live-use
fitness.

## Prohibited interpretations

Do not add oscillators, moving averages, ML features, discretionary pattern recognition,
cross-sectional inputs, seasonal overrides, adaptive thresholds, extra entries, pyramiding, or
parameter searches. Do not substitute current-week partial data for a completed week. Do not
modify the rule after observing Q02 except through a new governed candidate.
