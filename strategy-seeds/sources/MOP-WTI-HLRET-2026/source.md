---
source_id: MOP-WTI-HLRET-2026
title: WTI monthly Hodges-Lehmann return-location extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-11_qm5_20276_wti_hl_mom_g0.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-11
created_by: Research+Development
cards_extracted:
  - wti-hl-mom
---

# WTI Hodges-Lehmann Return Momentum Source Packet

## Approved Source Of Record

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site. The reproducible receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
the retrieval time, canonical faculty URL, 976,459 bytes, page count 23, and
PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The durable OWNER approval for this child extraction is
`decisions/2026-08-11_qm5_20276_wti_hl_mom_g0.md`. No new online page,
blocked content, or inferred source-table value is used.

## Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that the recent
distribution of WTI's own monthly returns may contain directional information.
They do not establish a pairwise-average pseudomedian or its performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest. Form the
twelve non-overlapping close-to-close monthly log returns. For every inclusive
pair `(i,j)` with `0 <= i <= j <= 11`, form the arithmetic average of the two
returns. Sort all 78 averages ascending and average zero-based indexes 38 and
39. Buy when that Hodges-Lehmann-style pseudomedian is positive, sell when it
is negative, and consume the month flat when it is exactly zero or invalid.
Renew at the next broker-month boundary.

The pairwise-average estimator, exact pair convention, continuous CFD carrier,
broker-month endpoint reconstruction, one-attempt ledger, `RISK_FIXED` sizing,
ATR hard stop, spread ceiling, and stale exit are transparent QM
mechanizations. The paper does not prescribe them. No source return, alpha,
Sharpe ratio, drawdown, trade count, cost, WTI-only result, CFD equivalence, or
portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11

k = 0
for i = 0..11:
  for j = i..11:
    w[k] = (r[i] + r[j]) / 2
    k += 1

require k == 78
sorted = ascending copy of w[0..77]
hl = (sorted[38] + sorted[39]) / 2

signal = BUY  when hl > 0
         SELL when hl < 0
         FLAT when hl == 0 or state is invalid
```

Self-pairs are mandatory: `w(i,i) == r[i]`. The intervals are disjoint and
the current decision month contributes no endpoint. There is no fallback to a
cumulative endpoint return, two-center raw-return median, trimmed mean, binary
sign count, fixed-block vote, pairwise price slope, regression, moving average,
oscillator, calendar direction, external series, or prior pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,341 EA-registry rows and
451 cards. It found no exact identity and surfaced only the expected 0.50
fuzzy matches to the same-source raw-return median and trimmed-mean cards.

Manual review separates this rule from `QM5_20269`, which averages only the
two central observed returns; `QM5_20270`, which averages the middle eight
observed returns; and `QM5_20271`, which forms forward time-normalized slopes
between thirteen log-price levels using `i < j` and a mandatory `j-i`
denominator. This rule instead forms inclusive pairwise averages of twelve
adjacent monthly returns, so its 12 self-pairs and 66 cross-pairs estimate a
different robust return-location functional.

The thirteen endpoints, twelve disjoint intervals, inclusive pair enumeration,
78 averages, sort, central indexes 38 and 39, symmetric direction, monthly
attempt, and renewal clock are jointly load-bearing. Verdict:
`CLEAN_ROBUST_PAIRWISE_RETURN_LOCATION`.

## Reputable-Source Criteria

- R1: PASS. One source ID links to named authors, a peer-reviewed *Journal of
  Financial Economics* article, DOI, author-hosted published paper, durable
  retrieval hash, complete read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, return intervals, inclusive pairs,
  average divisor, pair count, sort, median indexes, direction, attempt, fixed
  risk, hard stop, spread cap, rollover, and stale exit are exact and
  mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every runtime
  input.
- R4: PASS. Deterministic logarithm, fixed pairwise arithmetic, sorting, and
  native execution state only; no trained output, prohibited signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing an own-return WTI carrier, not the efficacy of the
pairwise-return-location rule. Q02 must retire the card below five completed
packages per full post-warm-up year or on nonpositive governed economics.
Downstream gates alone own robustness and correlation. No failure may be
rescued by changing the horizon, pair convention, estimator, direction,
carrier, stop, hold, spread cap, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.

