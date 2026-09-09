---
source_id: MOP-WTI-TSMOM11-H2-2026
title: WTI exact eleven-completed-month trend with a fixed two-month holding clock
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_wti_eleven_month_momentum_two_month_hold_source_approval.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-09-09
created_by: Research+Development
cards_extracted:
  - wti-tsmom11-h2
---

# WTI Eleven-Month Trend / Two-Month Hold

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
and volatility scaling. It does not publish a standalone WTI `k=11, h=2`
result, an odd-month epoch, or a continuous-CFD test. The non-overlapping
clock, broker-month endpoints, fixed-dollar risk, ATR stop, spread ceiling,
and restart ledger are transparent QM mechanizations. No source efficacy or
portfolio claim transfers.

## Bounded Mechanization

At the first tradable D1 bar of each odd broker month, reconstruct the latest
twelve consecutive completed month-end closes `C[0]..C[11]`, oldest to newest.
Compute `r11 = ln(C[11] / C[0])`. Buy if `r11 > 0`, sell if `r11 < 0`, and
consume the bimonthly attempt flat for equality or invalid state. Hold to the
next odd month boundary; even-month transitions cannot close or replace the package.

The baseline uses one `RISK_FIXED=1000` position, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, a 1,500-point spread cap, and 70-day
stale repair. Runtime uses only MT5 D1 OHLC, broker time, symbol metadata,
quotes, ATR, position/deal history, and terminal-global attempt state.

## Non-Duplicate Boundary

`QM5_20280_wti-tsmom4m` and the other monthly-renewal WTI carriers do not use
the fixed two-month lifecycle. `QM5_20281_wti-tsmom-h2` observes twelve
completed months on that lifecycle. `QM5_41379` through `QM5_41388` observe
three, one, nine, six, four, two, five, seven, eight, and ten completed months. The
new identity requires the exact combination of twelve consecutive endpoints,
eleven-month orientation, fixed odd-month epoch, no even-month action, one
consumed bimonthly attempt, and two-month renewal.

## R1-R4 And Falsification

- R1: `PASS_WITH_WTI_SPECIFIC_EFFICACY_UNPROVEN`.
- R2: `PASS`; all signal, clock, attempt, stop, risk, and lifecycle rules are fixed before testing.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`.
- R4: `PASS`; deterministic native arithmetic only.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, wrong endpoints,
current-month leakage, even-month action, repeated attempt, missing stop,
wrong exit, or nondeterminism.

