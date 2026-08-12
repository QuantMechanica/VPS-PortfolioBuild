---
source_id: MOP-WTI-MADCAP-2026
title: WTI monthly median/MAD-capped return-location extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-11_qm5_20282_wti_madcap_mom_g0.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-11
created_by: Research+Development
cards_extracted:
  - wti-madcap-mom
---

# WTI Median/MAD-Capped Return Trend Source Packet

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
`decisions/2026-08-11_qm5_20282_wti_madcap_mom_g0.md`. No new online page,
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
They do not establish a median/MAD cap or its performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest. Form the
twelve adjacent close-to-close monthly log returns. Compute their even-sample
median, then the even-sample median of their twelve absolute deviations from
that median. Reject a nonpositive MAD. Cap every original return symmetrically
at three raw MADs around the median and average all twelve capped returns with
equal weight. Buy when the capped mean is positive, sell when it is negative,
and consume the month flat when it is exactly zero or invalid. Renew at the
next broker-month boundary.

The median/MAD statistic, raw rather than consistency-scaled MAD, fixed cap
multiplier, continuous-CFD carrier, broker-month endpoint reconstruction,
one-attempt ledger, `RISK_FIXED` sizing, ATR hard stop, spread ceiling, and
stale exit are transparent QM mechanizations. The paper does not prescribe
them. No source return, alpha, Sharpe ratio, drawdown, trade count, cost,
WTI-only result, CFD equivalence, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
sr = ascending copy of r
M = (sr[5] + sr[6]) / 2

d[i] = abs(r[i] - M), i = 0..11
sd = ascending copy of d
D = (sd[5] + sd[6]) / 2

L = M - 3 * D
U = M + 3 * D
c[i] = min(U, max(L, r[i]))
madcap_mean = sum(c[0..11]) / 12

signal = BUY  when madcap_mean > 0
         SELL when madcap_mean < 0
         FLAT when madcap_mean == 0, D <= 0, or state is invalid
```

The MAD is the raw median absolute deviation, not multiplied by a normal-
consistency constant. All twelve original observations remain equally
weighted after the adaptive symmetric cap. The current decision month
contributes no endpoint. There is no fallback to a cumulative endpoint
return, raw median, fixed-tail trimmed or Winsorized mean, pairwise
pseudomedian, binary sign count, price slope, rank, moving average, oscillator,
calendar direction, external series, or prior pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,347 EA-registry rows and
458 cards. It found no exact identity and surfaced five expected same-source
fuzzy matches. Manual review separates the candidate from the raw median,
fixed two-per-tail trimmed mean, fixed two-per-tail Winsorized mean, linear
recency-weighted mean, and exponential recency-weighted mean cards.

Unlike those neighbors, this rule estimates both a robust location and a
robust dispersion from the same twelve returns, defines symmetric data-
dependent bounds, retains all observations after capping, and keeps equal
weights. The thirteen endpoints, twelve adjacent intervals, two even-sample
center averages, raw-MAD convention, three-MAD cap, twelve-term divisor,
symmetric direction, monthly attempt, and renewal clock are jointly
load-bearing. Verdict: `CLEAN_AFTER_EXPECTED_ROBUST_LOCATION_FUZZY_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. One source ID links to named authors, a peer-reviewed *Journal of
  Financial Economics* article, DOI, author-hosted published paper, durable
  retrieval hash, complete read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, return intervals, sorts, median indexes,
  deviation definition, MAD indexes, raw scale, cap multiplier, divisor,
  direction, attempt, fixed risk, hard stop, rollover, and stale exit are exact
  and mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every runtime
  input.
- R4: PASS. Deterministic logarithm, sorting, absolute deviation, capping, and
  native execution state only; no trained output, prohibited signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing an own-return WTI carrier, not the efficacy of the
median/MAD-capped return-location rule. Q02 must retire the card below five
completed packages per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by changing the horizon, median/MAD definitions, cap multiplier,
estimator, direction, carrier, stop, hold, spread cap, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
