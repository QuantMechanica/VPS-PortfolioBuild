---
source_id: MOP-WTI-TSMOM10-H1-2026
title: WTI exact ten-completed-month trend with a one-month holding clock
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_wti_ten_month_momentum_one_month_hold_source_approval.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-09-09
created_by: Research+Development
cards_extracted:
  - wti-tsmom10-h1
---

# WTI Ten-Month Trend / One-Month Hold

## Complete-Read Record

The approved parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, Journal of
Financial Economics 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. Its author-hosted retrieval receipt records
23 pages and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

## Source Findings And Translation Boundary

Section 3.1 tests monthly own-return predictability at lags one through sixty
and reports positive continuation over the first twelve lags. Section 3.2
defines time-series-momentum positions by the sign of an instrument's own past
`k`-month return and expresses the family with formation horizon `k` and
holding horizon `h`. Appendix A includes NYMEX WTI crude.

The source uses liquid rolling futures, excess returns, overlapping portfolios,
and volatility scaling. It does not publish a standalone WTI `k=10, h=1`
result or a continuous-CFD test. Broker-month endpoints, fixed-dollar risk,
ATR stop, spread ceiling, and restart ledger are transparent QM
mechanizations. No source efficacy or portfolio claim transfers.

## Bounded Mechanization

At the first tradable D1 bar of every new broker month, reconstruct the latest
eleven consecutive completed month-end closes `C[0]..C[10]`, oldest to newest.
Compute `r10 = ln(C[10] / C[0])`. Buy if `r10 > 0`, sell if `r10 < 0`, and
consume the monthly attempt flat for equality or invalid state. Hold to the
next month boundary.

The baseline uses one `RISK_FIXED=1000` position, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, a 1,500-point spread cap, and 40-day
stale repair. Runtime uses only MT5 D1 OHLC, broker time, symbol metadata,
quotes, ATR, position/deal history, and terminal-global attempt state.

## Non-Duplicate Boundary

`QM5_41388_wti-tsmom10-h2` observes the same exact ten-month return but only
at odd-month boundaries and preserves each position through the intervening
even month. Existing monthly-renewal WTI carriers use other formation horizons,
composite votes, volatility gates, regressions, robust statistics, calendar
states, or event clocks. Exact ten-month endpoints plus every-month renewal
are jointly load-bearing.

## Falsification

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, wrong endpoints,
current-month leakage, skipped or repeated month attempts, missing stop,
wrong exit, or nondeterminism. Changing formation, hold, direction, carrier,
stop, risk, spread, or retry policy requires a new identity and Q00/Q01.
