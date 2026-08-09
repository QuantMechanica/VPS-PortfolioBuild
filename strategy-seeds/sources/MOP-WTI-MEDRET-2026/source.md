---
source_id: MOP-WTI-MEDRET-2026
title: WTI monthly median-return momentum extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-09_qm5_20269_wti_medret_mom_g0.md
parent_source_id: MOP-TSMOM-2012
created: 2026-08-09
created_by: Research+Development
cards_extracted:
  - wti-medret-mom
---

# WTI Median-Return Momentum Source Packet

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
`decisions/2026-08-09_qm5_20269_wti_medret_mom_g0.md`. No new online page,
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
They do not establish the median-return statistic or its performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest. Form the
twelve non-overlapping close-to-close monthly log returns. Sort a copy of those
returns and average zero-based ascending indexes 5 and 6. Buy when that exact
even-sample median is positive, sell when it is negative, and consume the month
flat when it is exactly zero or invalid. Renew at the next broker-month
boundary.

The return order statistic is a transparent robust-direction hypothesis. The
paper does not prescribe a median estimator, center indexes, continuous CFD
carrier, broker-month endpoint reconstruction, one-attempt ledger,
`RISK_FIXED` sizing, ATR hard stop, spread ceiling, or stale exit. No source
return, alpha, Sharpe ratio, drawdown, trade count, cost, WTI-only result, CFD
equivalence, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
sorted = ascending copy of r[0..11]
median_return = (sorted[5] + sorted[6]) / 2

signal = BUY  when median_return > 0
         SELL when median_return < 0
         FLAT when median_return == 0 or state is invalid
```

The intervals are disjoint and the current decision month contributes no
endpoint. There is no fallback to a cumulative endpoint return, binary sign
count, rolling price median, pairwise rank score, regression, moving average,
oscillator, calendar direction, external series, or prior pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,326 EA-registry rows and
442 cards. It found no exact slug or strategy-ID collision. Shared
`MOP-TSMOM-2012` strategy-family identifiers produced expected fuzzy hits for
manual review.

Manual review separates this mechanic from single-horizon cumulative WTI
returns, dual-horizon agreement, nested one/three/twelve-month voting, binary
monthly-sign breadth, Mann-Kendall price ordering, OLS log-price trend, and a
D1 rolling median-of-price long/flat strategy. None sorts exactly twelve
disjoint WTI monthly returns and trades the sign of the average of order-
statistic indexes 5 and 6.

The thirteen endpoints, twelve disjoint intervals, log-return orientation,
ascending sort, exact even-sample center indexes, symmetric direction, monthly
attempt, and renewal clock are jointly load-bearing. Verdict:
`CLEAN_ROBUST_MONTHLY_RETURN_ORDER_STATISTIC`.

## Reputable-Source Criteria

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  article, DOI, author-hosted published paper, durable retrieval hash, complete
  read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, return intervals, sort, median indexes,
  direction, attempt, fixed risk, hard stop, spread cap, rollover, and stale
  exit are exact and mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every runtime
  input.
- R4: PASS. Deterministic logarithm, sorting, arithmetic, and native execution
  state only; no trained output, external runtime feed, grid, martingale,
  scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing an own-return WTI carrier, not the efficacy of the
median-return rule. Q02 must retire the card below five completed packages per
full post-warm-up year or on nonpositive governed economics. Downstream gates
alone own robustness and correlation. No failure may be rescued by changing
the horizon, median definition, direction, carrier, stop, hold, spread cap, or
retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
