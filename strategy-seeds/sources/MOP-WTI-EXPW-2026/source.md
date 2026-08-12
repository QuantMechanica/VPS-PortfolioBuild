---
source_id: MOP-WTI-EXPW-2026
title: WTI monthly exponential-recency weighted-return extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-11_qm5_20279_wti_expw_mom_g0.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-11
created_by: Research+Development
cards_extracted:
  - wti-expw-mom
---

# WTI Exponential-Recency Return Momentum Source Packet

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
`decisions/2026-08-11_qm5_20279_wti_expw_mom_g0.md`. No new online page,
blocked content, or inferred source-table value is used.

## Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that WTI's own
completed monthly returns may contain directional information. They do not
establish exponential recency weighting, a three-month half-life, or
performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest. Form
twelve non-overlapping chronological monthly log returns. Give the newest
return age zero and each successively older return one additional month of
age. Weight each return by base-two exponential decay with a fixed three-month
half-life, normalize by the sum of all twelve positive weights, and trade the
sign for one broker month. Exact zero or invalid state consumes the month flat.

The half-life, continuous-CFD carrier, broker-month endpoint reconstruction,
one-attempt ledger, `RISK_FIXED` sizing, ATR hard stop, spread ceiling, and
stale exit are transparent QM mechanizations. The paper does not prescribe
them. No source return, alpha, Sharpe ratio, drawdown, trade count, cost,
WTI-only result, CFD equivalence, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
age[i] = 11 - i
half_life = 3.0
w[i] = 2 ^ (-age[i] / half_life)
weight_total = sum(w[i]), i = 0..11
exp_weighted_mean = sum(w[i] * r[i]) / weight_total

signal = BUY  when exp_weighted_mean > 0
         SELL when exp_weighted_mean < 0
         FLAT when exp_weighted_mean == 0 or state is invalid
```

Chronology and age orientation are load-bearing. The newest weight is one;
weights half at ages three, six, and nine. The current decision month
contributes no endpoint. There is no sort, clipping, fitted decay, alternate
base, adaptive half-life, cumulative endpoint return, horizon vote, regression,
rank, moving average, oscillator, calendar direction, external series, or
prior pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,344 EA-registry rows and
455 cards. It found no exact identity and no fuzzy match above threshold.

`QM5_20278` is the nearest chronological weighted-return card, but it uses the
integer vector `1..12`; the ratio between adjacent weights is not constant and
its oldest/newest ratio is `1/12`. This candidate uses a constant base-two
decay rate with half-life three and oldest/newest ratio `2^(-11/3)`. Median,
trimmed, and Winsorized cards sort or cap returns. Quarterly vote discards
magnitude. OLS, rank, Theil-Sen, path-efficiency, and high-low cards operate on
different state objects. The thirteen endpoints, twelve adjacent intervals,
age mapping, three-month half-life, base two, normalization, symmetric trend
direction, monthly attempt, and renewal clock are jointly load-bearing.

Verdict: `CLEAN_EXPONENTIAL_RECENCY_WEIGHTED_MONTHLY_RETURN_TREND`.

## Reputable-Source Criteria

- R1: PASS. One source ID links to named authors, a peer-reviewed *Journal of
  Financial Economics* article, DOI, author-hosted published paper, durable
  retrieval hash, complete read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, return intervals, age mapping, base,
  half-life, normalization, direction, attempt, fixed risk, hard stop, spread
  cap, rollover, and stale exit are exact and mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every runtime
  input.
- R4: PASS. Deterministic logarithm, power, multiplication, addition, and
  native execution state only; no trained output, prohibited signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing an own-return WTI carrier, not the efficacy of the
exponential-recency rule. Q02 must retire the card below five completed
packages per full post-warm-up year or on nonpositive governed economics.
Downstream gates alone own robustness and correlation. No failure may be
rescued by changing the horizon, base, half-life, age direction, trade
direction, carrier, stop, hold, spread cap, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
