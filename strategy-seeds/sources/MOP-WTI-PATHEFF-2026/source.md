---
source_id: MOP-WTI-PATHEFF-2026
title: WTI monthly path-efficiency extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-10_qm5_20274_wti_path_eff_g0.md
parent_source_id: MOP-TSMOM-2012
created: 2026-08-10
created_by: Research+Development
cards_extracted:
  - wti-path-eff
---

# WTI Monthly Path-Efficiency Source Packet

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
`decisions/2026-08-10_qm5_20274_wti_path_eff_g0.md`. No new online page,
blocked content, or inferred source-table value is used.

## Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that persistence
inside WTI's prior-year own-price path may contain directional information.
They do not establish a net-to-path efficiency statistic, its threshold, or
the candidate's performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest. Form the
twelve chronological adjacent log returns. Divide the absolute sum of those
returns by the sum of their absolute values. Follow the net direction only when
this path-efficiency ratio is at least `0.25`. A zero net move, zero path,
below-threshold path, invalid state, or unavailable history consumes the month
flat. Renew at the next broker-month boundary.

The path-efficiency estimator, fixed threshold, exact endpoint count, CFD
mapping, fixed-risk sizing, stop, spread cap, and lifecycle are transparent QM
mechanizations. The paper does not prescribe them. No source return, alpha,
Sharpe ratio, drawdown, trade count, cost, WTI-only result, CFD equivalence, or
portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
N    = sum(r[i])
P    = sum(abs(r[i]))
E    = abs(N) / P

signal = BUY  when N > 0 and E >= 0.25
         SELL when N < 0 and E >= 0.25
         FLAT otherwise
```

Every adjacent return contributes once to both `N` and `P`. Require finite
arithmetic, `P > 0`, and `E` in `[0,1]` up to `1e-10` numerical tolerance.
The current decision month contributes no endpoint. Efficiency and return
magnitude never scale risk. There is no fallback to a cumulative-return-only
signal, sign count, sign run, fixed block vote, mean, median, trimmed mean,
regression, rank, moving average, oscillator, calendar direction, external
series, or prior pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,337 EA-registry rows and
447 intake cards. It found no exact identity and no fuzzy match above its
threshold.

Manual review separates this rule from pure WTI TSMOM, which follows one
cumulative endpoint return without measuring path length; sign-count and sign-
run cards, which discard magnitudes; fixed quarterly and nested-horizon votes;
OLS, ordinal, and Theil-Sen estimators over price levels; and median or trimmed-
mean aggregators. Generic efficiency-ratio EAs exist elsewhere in the
repository, but no approved WTI/commodity card uses this exact twelve-month
completed-endpoint carrier, monthly lifecycle, and `0.25` net-to-absolute-path
contract.

The thirteen endpoints, twelve adjacent log returns, orientation, all-term
absolute-path denominator, threshold, symmetric direction, monthly attempt,
and renewal clock are jointly load-bearing. Verdict: `CLEAN`.

## Reputable-Source Criteria

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  article, DOI, author-hosted published paper, durable retrieval hash, complete
  read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, log-return orientation, numerator,
  denominator, zero handling, threshold, direction, attempt, fixed risk, hard
  stop, spread cap, rollover, and stale exit are exact and mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every runtime
  input.
- R4: PASS. Deterministic logarithm, absolute value, sums, division, and native
  execution state only; no trained output, prohibited signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramiding.

## Frequency Reference And Kill Boundary

A seeded zero-drift Gaussian twelve-return design reference places about half
of monthly states at `E >= 0.25`, or about six decisions/year before missing
history and execution gates. This is a transparent density reference, not
market evidence. Q02 must retire the card below five completed packages per
full post-warm-up year or on nonpositive governed economics.

Downstream gates alone own robustness and correlation. No failure may be
rescued by changing the lookback, threshold, direction, carrier, stop, hold,
spread cap, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
