---
source_id: MOP-WTI-THEILSEN-2026
title: WTI monthly Theil-Sen robust-trend extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-10_qm5_20271_wti_theilsen_tr_g0.md
parent_source_id: MOP-TSMOM-2012
created: 2026-08-10
created_by: Research+Development
cards_extracted:
  - wti-theilsen-tr
---

# WTI Theil-Sen Robust Trend Source Packet

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
`decisions/2026-08-10_qm5_20271_wti_theilsen_tr_g0.md`. No new online page,
blocked content, or inferred source-table value is used.

## Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that a persistent
WTI own-price path may contain directional information. They do not establish
a median pairwise-slope estimator or its performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest. Take the
natural logarithm of each close. For every forward pair `(i,j)` with
`0 <= i < j <= 12`, divide the log-price change by the positive monthly-index
distance `j-i`. Sort all 78 slopes ascending and average zero-based indexes 38
and 39. Buy when this even-sample median is positive, sell when it is negative,
and consume the month flat when it is exactly zero or invalid. Renew at the
next broker-month boundary.

The median-of-all-pairwise-slopes estimator, exact observation count, CFD
mapping, fixed-risk sizing, stop, spread cap, and lifecycle are transparent QM
mechanizations. The paper does not prescribe them. No source return, alpha,
Sharpe ratio, drawdown, trade count, cost, WTI-only result, CFD equivalence, or
portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
y[i] = ln(C[i]), i = 0..12

k = 0
for i = 0..11:
  for j = i+1..12:
    slope[k] = (y[j] - y[i]) / (j - i)
    k += 1

require k == 78
sorted = ascending copy of slope[0..77]
theilsen_slope = (sorted[38] + sorted[39]) / 2

signal = BUY  when theilsen_slope > 0
         SELL when theilsen_slope < 0
         FLAT when theilsen_slope == 0 or state is invalid
```

The month-index denominator is mandatory: multi-month pairs are slopes, not
raw returns. The current decision month contributes no endpoint. There is no
fallback to an endpoint return, adjacent-return statistic, OLS slope,
Mann-Kendall score, moving average, oscillator, calendar direction, external
series, or prior pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,328 EA-registry rows and
444 intake cards. It found no exact or fuzzy slug, strategy-ID, or declared-
mechanic collision.

Manual review separates the rule from cumulative WTI return horizons,
cumulative-return votes, adjacent-return sign counts, OLS log-price slope plus
`R^2`, all-pairs ordinal Mann-Kendall trend, the two-center median of twelve
adjacent monthly returns, and the middle-eight trimmed mean of those returns.
Generic daily regression, moving-average, channel, and Donchian builds do not
use thirteen completed broker-month endpoints and this exact robust slope
estimator.

The thirteen endpoints, 78 forward pairs, exact `j-i` denominators, log-price
orientation, ascending sort, central indexes 38 and 39, symmetric direction,
monthly attempt, and renewal clock are jointly load-bearing. Verdict:
`CLEAN_ROBUST_MONTHLY_THEILSEN_TREND`.

## Reputable-Source Criteria

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  article, DOI, author-hosted published paper, durable retrieval hash, complete
  read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, pair enumeration, denominator, sort,
  median indexes, direction, attempt, fixed risk, hard stop, spread cap,
  rollover, and stale exit are exact and mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every runtime
  input.
- R4: PASS. Deterministic logarithm, finite pairwise arithmetic, sorting, and
  native execution state only; no trained output, external runtime feed, grid,
  martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing an own-price WTI carrier, not the efficacy of the
robust slope rule. Q02 must retire the card below five completed packages per
full post-warm-up year or on nonpositive governed economics. Downstream gates
alone own robustness and correlation. No failure may be rescued by changing
the lookback, slope estimator, median definition, direction, carrier, stop,
hold, spread cap, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
