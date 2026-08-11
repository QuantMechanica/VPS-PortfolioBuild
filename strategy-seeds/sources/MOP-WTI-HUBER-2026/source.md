---
source_id: MOP-WTI-HUBER-2026
title: WTI fixed-step Huber robust-location trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed sources
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-12_qm5_20285_wti_huber_mom_g0.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-12
created_by: Research+Development
cards_extracted:
  - wti-huber-mom
---

# WTI Fixed-Step Huber Robust-Location Source Packet

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
`decisions/2026-08-12_qm5_20285_wti_huber_mom_g0.md`. No blocked page,
inferred source-table value, or ungoverned trading claim is used.

## Statistical Lineage

Huber, Peter J. (1964), "Robust Estimation of a Location Parameter," *The
Annals of Mathematical Statistics* 35(1), 73-101, DOI
`10.1214/aoms/1177703732`, is cited only for the bounded-influence location
family. It is not a trading paper and supplies no WTI signal, tuning constant,
iteration count, return, or portfolio result. The exact scale and fixed-step
iteration below are locked QM choices.

## Trading-Source Findings Used

- Section 3.1 of Moskowitz, Ooi, and Pedersen tests each instrument's own
  return at monthly lags one through sixty and reports positive continuation
  over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that the central
direction of twelve completed WTI monthly returns may carry slow directional
information. They do not establish that a Huber location improves the signal.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes and form twelve adjacent
chronological log returns. Compute their even-sample median and even-sample
raw MAD. Freeze `delta = 1.5 * 1.4826 * MAD`, initialize location at the
median, and run exactly 32 Huber reweighted-mean updates. Buy for a positive
final location, sell for a negative final location, and consume the month
flat when it is exactly zero or invalid. Renew at the next broker-month
boundary.

The robust estimator, tuning constant, scale normalization, fixed update
count, endpoint convention, continuous-CFD carrier, broker-month
reconstruction, one-attempt ledger, `RISK_FIXED` sizing, ATR hard stop, spread
ceiling, and stale exit are transparent QM mechanizations. No source return,
alpha, Sharpe ratio, drawdown, trade count, cost, WTI-only result, CFD
equivalence, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For positive finite completed month-end closes `C[0]..C[12]`, oldest to
newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
s    = sort_ascending(r)
m    = (s[5] + s[6]) / 2
d[i] = abs(r[i] - m)
a    = sort_ascending(d)
MAD  = (a[5] + a[6]) / 2
scale = 1.4826 * MAD
delta = 1.5 * scale

mu[0] = m
for j = 0..31:
  residual = abs(r[i] - mu[j])
  w[i] = 1 if residual <= delta else delta / residual
  mu[j+1] = sum(w[i] * r[i]) / sum(w[i])

signal = BUY  when mu[32] > 0
         SELL when mu[32] < 0
         FLAT when mu[32] == 0 or state is invalid
```

The scale freezes before the first update. All 32 updates execute. There is no
early-stop tolerance, return deletion or replacement, fallback center,
alternate tuning, magnitude sizing, or runtime fit.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,350 EA-registry rows and
461 root cards. It found no exact identity and surfaced one fuzzy match,
`QM5_20277_wti-winsor-mom`. That EA replaces fixed order-statistic tails once;
it never estimates data-scaled influence weights or re-centers a location.

`QM5_20282_wti-madcap-mom` is the closest unreported neighbor: it clips each
return once around a permanently frozen median using three raw MADs, then
takes an equal-weight mean. This rule freezes only its normalized scale;
weights depend on distance from the evolving location on every one of 32
updates. Raw-median, trim, quartile-trimean, pairwise-pseudomedian, cumulative,
vote/run, regression, rank, weighting, path-efficiency, and skip-month systems
estimate other functionals or endpoint objects. Verdict:
`CLEAN_AFTER_WINSOR_AND_MADCAP_MECHANIC_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  trading paper, DOI, author-hosted complete paper, durable retrieval hash,
  complete read, and explicit WTI membership. The Huber citation is limited to
  statistical lineage.
- R2: PASS. Endpoint count/order, return orientation, median/MAD convention,
  constants, frozen scale, weight equation, update count, direction, attempt,
  fixed risk, hard stop, rollover, and stale exit are exact.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every input.
- R4: PASS. Deterministic logarithm, sorting, absolute deviation, and fixed
  arithmetic only; no trained output, prohibited signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The trading source supports testing an own-return WTI carrier, not the
efficacy of the Huber transformation. Q02 must retire the card below five
completed packages per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by changing scale, tuning, iteration count, horizon, direction,
carrier, stop, hold, spread, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or a claim of decorrelation.
