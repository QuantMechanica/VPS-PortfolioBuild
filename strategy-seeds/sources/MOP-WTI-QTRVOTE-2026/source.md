---
source_id: MOP-WTI-QTRVOTE-2026
title: WTI quarterly-block consensus extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-10_qm5_20272_wti_qtrvote_tr_g0.md
parent_source_id: MOP-TSMOM-2012
created: 2026-08-10
created_by: Research+Development
cards_extracted:
  - wti-qtrvote-tr
---

# WTI Quarterly-Block Consensus Source Packet

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
`decisions/2026-08-10_qm5_20272_wti_qtrvote_tr_g0.md`. No new online page,
blocked content, or inferred source-table value is used.

## Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that persistent
segments of WTI's own prior-year price path may contain directional
information. They do not establish a vote across non-overlapping quarterly
blocks or its performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest. Partition
the immediately preceding twelve months into four chronological,
non-overlapping three-month blocks. Calculate one log return per block, count
strictly positive and strictly negative blocks, buy when at least three are
positive, sell when at least three are negative, and consume every other state
flat. Renew at the next broker-month boundary.

The block partition, sign-only vote, strict three-of-four threshold, exact
endpoint count, CFD mapping, fixed-risk sizing, stop, spread cap, and lifecycle
are transparent QM mechanizations. The paper does not prescribe them. No
source return, alpha, Sharpe ratio, drawdown, trade count, cost, WTI-only
result, CFD equivalence, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
q[0] = ln(C[3]  / C[0])
q[1] = ln(C[6]  / C[3])
q[2] = ln(C[9]  / C[6])
q[3] = ln(C[12] / C[9])

positive_count = count(q[k] > 0)
negative_count = count(q[k] < 0)

signal = BUY  when positive_count >= 3
         SELL when negative_count >= 3
         FLAT otherwise
```

Exact-zero blocks are neutral and contribute to neither count. Each boundary
endpoint is shared by its neighboring blocks, but no monthly interval appears
in more than one block. The current decision month contributes no endpoint.
There is no fallback to a cumulative return, nested-horizon vote,
adjacent-month sign count, mean, median, trimmed mean, regression, rank score,
moving average, oscillator, calendar direction, external series, or prior
pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,332 EA-registry rows and
445 intake cards. It found no exact identity and two expected shared-source
fuzzy matches: the WTI and XNG one/three/twelve-month cumulative-horizon vote
cards.

Manual review separates this rule from `QM5_20258_wti-mom-vote`: that EA votes
three nested cumulative returns sharing the newest endpoint, while this rule
votes four disjoint three-month intervals that partition the prior year.
Adjacent-return sign-count systems use twelve one-month observations. OLS,
Mann-Kendall, Theil-Sen, median-return, and trimmed-return systems retain a
different information object and aggregation rule.

The thirteen endpoints, block boundaries `(0,3,6,9,12)`, chronological log
orientation, zero treatment, strict three-of-four threshold, symmetric
direction, monthly attempt, and renewal clock are jointly load-bearing.
Verdict: `CLEAN_AFTER_EXPECTED_SHARED_SOURCE_FUZZY_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  article, DOI, author-hosted published paper, durable retrieval hash, complete
  read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, block boundaries, log orientation,
  zero treatment, vote threshold, direction, attempt, fixed risk, hard stop,
  spread cap, rollover, and stale exit are exact and mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every runtime
  input.
- R4: PASS. Deterministic logarithm, sign counting, and native execution state
  only; no trained output, prohibited signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing an own-price WTI carrier, not the efficacy of the
quarter-block vote. Q02 must retire the card below five completed packages per
full post-warm-up year or on nonpositive governed economics. Downstream gates
alone own robustness and correlation. No failure may be rescued by changing
the lookback, block definition, threshold, direction, carrier, stop, hold,
spread cap, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
