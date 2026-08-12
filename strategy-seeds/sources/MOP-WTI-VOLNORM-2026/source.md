---
source_id: MOP-WTI-VOLNORM-2026
title: WTI within-month realized-volatility-normalized trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-12_qm5_20288_wti_volnorm_mom_g0.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-12
created_by: Research+Development
cards_extracted:
  - wti-volnorm-mom
---

# WTI Volatility-Normalized Monthly Trend Source Packet

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
`decisions/2026-08-12_qm5_20288_wti_volnorm_mom_g0.md`. No blocked page,
inferred source-table value, or ungoverned performance claim is used.

## Trading-Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns, renews them monthly, and scales exposures by ex-ante volatility.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and a 60-day-center-
  of-mass ex-ante volatility estimator; it does not test a Darwinex continuous
  CFD.

These findings support only the broad structural hypothesis that WTI's prior
twelve completed monthly returns may carry slow directional information and
that volatility scale matters to implementation. They do not establish that
normalizing each historical monthly return by its own realized daily path
improves a WTI signal.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes and the completed D1
close-to-close returns connecting them. For each of the twelve broker-month
intervals, divide its endpoint log return by the L2 norm of all daily log
returns inside that same interval. Give the twelve normalized month states
equal weight. Buy when their arithmetic mean is positive, sell when negative,
and consume exact-zero or invalid months flat. Renew at the next broker-month
boundary.

The historical within-month L2 normalization is a transparent QM signal
mechanization, not the paper's ex-ante position-sizing estimator. The
continuous-CFD carrier, broker-month reconstruction, equal-month aggregation,
one-attempt ledger, `RISK_FIXED` sizing, ATR hard stop, spread ceiling, and
stale exit are also QM choices. No source return, alpha, Sharpe ratio,
drawdown, trade count, cost, WTI-only result, CFD equivalence, or portfolio-
correlation statistic transfers.

## Exact Statistical Contract

Let `C[0]..C[12]` be positive finite completed month-end closes, oldest to
newest. For interval `m=0..11`, let `P[m,0]=C[m]`,
`P[m,n[m]]=C[m+1]`, and retain every intervening completed D1 close in strict
timestamp order:

```text
d[m,j] = ln(P[m,j+1] / P[m,j]), j = 0..n[m]-1
r[m]   = sum_j d[m,j]
e[m]   = ln(C[m+1] / C[m])
v[m]   = sqrt(sum_j d[m,j]^2)
u[m]   = r[m] / v[m]
score  = sum_m u[m] / 12

signal = BUY  when score > 0
         SELL when score < 0
         FLAT when score == 0 or state is invalid
```

Every interval requires `15 <= n[m] <= 25`, `v[m] > 0`, finite arithmetic,
and `abs(r[m]-e[m]) <= 1e-10`. Each daily return belongs to exactly one
interval. There is no demeaning, sample-standard-deviation correction,
annualization, clipping, winsorization, threshold, sign vote, unequal month
weight, magnitude-based sizing, fallback statistic, or runtime fit.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,353 EA-registry rows and
465 root cards. It found no exact identity and no fuzzy match above threshold.
Manual review resolves the nearest families:

- `QM5_20274_wti-path-eff` forms one twelve-month return divided by the L1 sum
  of twelve monthly absolute returns and applies a fixed threshold. This card
  forms twelve separate within-month daily-L2 ratios, weights months equally,
  and uses no threshold.
- `QM5_20245`, `QM5_20253`, `QM5_20256`, and `QM5_20257` use fixed-horizon
  heteroskedasticity-robust variance-ratio memory states. They do not form
  monthly endpoint returns normalized by their own realized daily paths.
- `QM5_13049_xti-1w-mom-vol` uses a five-day continuation signal behind a
  separate low-volatility gate, not a twelve-month normalized aggregate.
- The cumulative, median, trim/Winsor, M-location, regression, rank, block,
  run/vote, recency-weighted, and skip-month systems use different signal
  objects or weights.

The twelve fixed intervals, completed daily paths, separate L2 denominator per
month, endpoint-sum identity, equal month weights, and final mean sign are
jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_PATH_AND_VOLATILITY_NEIGHBOR_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. One canonical source ID backed by named authors, a peer-reviewed
  trading paper, DOI, author-hosted complete paper, durable retrieval hash,
  complete read, and explicit WTI membership.
- R2: PASS. Endpoint count/order, daily-return inclusion, interval counts, L2
  denominator, endpoint identity, equal weights, direction, attempt, fixed
  risk, hard stop, rollover, and stale exit are exact.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every input.
- R4: PASS. Deterministic logarithm, addition, multiplication, square root,
  and division only; no trained output, prohibited signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The trading source supports testing an own-return WTI carrier, not the
efficacy of this historical volatility-normalized statistic. Q02 must retire
the card below five completed packages per full post-warm-up year or on
nonpositive governed economics. Downstream gates alone own robustness and
correlation. No failure may be rescued by changing interval count, daily-path
normalization, observation bounds, horizon, direction, carrier, stop, hold,
spread, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or a claim of decorrelation.
