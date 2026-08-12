---
source_id: MOP-WTI-BLOCKMED-2026
title: WTI chronological block median-of-means trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-12_qm5_20287_wti_blockmed_mom_g0.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-12
created_by: Research+Development
cards_extracted:
  - wti-blockmed-mom
---

# WTI Chronological Block Median-of-Means Source Packet

## Approved Trading Source Of Record

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site. The reproducible receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
the retrieval time, canonical faculty URL, 976,459 bytes, 23 pages, and PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The durable OWNER approval for this extraction is
`decisions/2026-08-12_qm5_20287_wti_blockmed_mom_g0.md`. No blocked page,
inferred source-table value, or ungoverned performance claim is used.

## Trading-Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that WTI's prior
twelve completed monthly returns may carry slow directional information. They
do not establish that chronological block median-of-means aggregation improves
the signal.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes and form twelve adjacent
chronological log returns. Partition the returns into four fixed non-
overlapping blocks of three. Compute each block's arithmetic mean, sort only
the four block means, and average sorted indexes one and two. Buy when that
even block median is positive, sell when negative, and consume the month flat
when it is exactly zero or invalid. Renew at the next broker-month boundary.

The block aggregation, even-median convention, continuous-CFD carrier,
broker-month reconstruction, one-attempt ledger, `RISK_FIXED` sizing, ATR hard
stop, spread ceiling, and stale exit are transparent QM mechanizations. No
source return, alpha, Sharpe ratio, drawdown, trade count, cost, WTI-only
result, CFD equivalence, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For positive finite completed month-end closes `C[0]..C[12]`, oldest to
newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
b[0] = (r[0] + r[1] + r[2]) / 3
b[1] = (r[3] + r[4] + r[5]) / 3
b[2] = (r[6] + r[7] + r[8]) / 3
b[3] = (r[9] + r[10] + r[11]) / 3
s = sort_ascending(b)
location = (s[1] + s[2]) / 2

signal = BUY  when location > 0
         SELL when location < 0
         FLAT when location == 0 or state is invalid
```

Block membership is chronological and immutable. Every return appears once.
Only block means are sorted. There is no sign-only vote, cumulative endpoint
return, raw-return median, trimming, clipping, weighting, iteration, magnitude
sizing, early exit, fallback center, or runtime fit.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,352 EA-registry rows and
464 root cards. It found no exact identity and no fuzzy match above threshold.
Manual review resolved the closest same-family systems:

- `QM5_20272` uses four three-month endpoint returns but requires a three-of-
  four sign consensus and stays flat on every two-versus-two sign split. This
  candidate retains within-block magnitude and resolves such splits from the
  two inner sorted block means.
- `QM5_20269` sorts twelve individual monthly returns and takes their even
  median; it does not preserve or aggregate chronological three-month blocks.
- `QM5_20270` trims two individual monthly returns from each tail and averages
  the remaining eight; it does not form or select block means.
- The cumulative, cap, Winsor, robust-iteration, regression, rank, run, path-
  efficiency, recency-weighted, and skip-month families use different
  functionals or endpoint objects.

The four fixed blocks, exact width three, equal within-block magnitude weights,
sorting of block means only, even median from indexes one and two, and nonzero
two-versus-two resolution are jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_BLOCK_NEIGHBOR_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. One canonical source ID backed by a named peer-reviewed trading
  paper, DOI, author-hosted complete paper, durable retrieval hash, complete
  read, and explicit WTI membership.
- R2: PASS. Endpoint count/order, return orientation, block membership, block
  divisor, even-median indexes, direction, attempt, fixed risk, hard stop,
  rollover, and stale exit are exact.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every input.
- R4: PASS. Deterministic logarithm, addition, division, and sorting only; no
  trained output, prohibited signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The trading source supports testing an own-return WTI carrier, not the
efficacy of the block statistic. Q02 must retire the card below five completed
packages per full post-warm-up year or on nonpositive governed economics.
Downstream gates alone own robustness and correlation. No failure may be
rescued by changing block count, block width, horizon, direction, carrier,
stop, hold, spread, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or a claim of decorrelation.
