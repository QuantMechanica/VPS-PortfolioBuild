---
source_id: KISS-WTI-RSJ-REV-2026
title: WTI absolute signed-semivariance reversal extraction
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-12_qm5_20289_wti_rsj_rev_g0.md
parent_source_id: KISS-RSJ-2025
parent_sha256: 87679A706DA34734A845C5BC932DEB75603B3B9B03D56BC88A8CFEC779ACACC8
created: 2026-08-12
created_by: Research+Development
cards_extracted:
  - wti-rsj-rev
---

# WTI Absolute Signed-Semivariance Reversal Source Packet

## Approved Trading Source Of Record

Kiss, Tamas, and Igor Ferreira Batista Martins (2025), "Good Volatility, Bad
Volatility and the Cross Section of Commodity Returns," *Finance Research
Letters* 86 Part D, article 108656, DOI
`10.1016/j.frl.2025.108656`.

The governed parent packet is
`strategy-seeds/sources/KISS-RSJ-2025/source.md`. It records a complete read
of the 12-page open-access published paper, including the structural hedging
motivation, Equations 1-4, portfolio sorts, factor controls, robustness tests,
WTI membership, and utility appendix. The parent packet's source identity and
complete-read evidence are content-bound by the SHA-256 above.

The durable OWNER approval for this extraction is
`decisions/2026-08-12_qm5_20289_wti_rsj_rev_g0.md`. The 2026-08-06 generic
retrieval attempt was policy-deferred and supplied no new source content; no
blocked page or inferred result is used here.

## Trading-Source Findings Used

- Section 3 defines monthly upside and downside realized semivariance from
  daily returns and the scale-invariant statistic
  `RSJ=(RV_plus-RV_minus)/(RV_plus+RV_minus)`.
- Section 4 sorts commodity futures at month end and holds the low-minus-high
  RSJ portfolio for one month.
- The source reports a negative cross-sectional relation between RSJ and
  next-month commodity-futures excess returns.
- Appendix A includes WTI crude oil in the 36-commodity universe.
- The paper uses collateralized futures returns and a broad cross-section; it
  does not test a single Darwinex CFD around an absolute zero threshold.

These findings support testing whether the balance of good and bad realized
WTI volatility contains a slow monthly return-premium state. They do not
establish that zero is a profitable time-series pivot.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct the
immediately preceding complete `XTIUSD.DWX` broker month and form only the
close-to-close log returns whose start and end timestamps both belong to that
month. Sum squared positive returns into `RV_plus` and squared negative returns
into `RV_minus`, normalize their difference by total realized variance, and
trade opposite the RSJ sign: buy after downside semivariance dominates and
sell after upside semivariance dominates. Renew at the next month boundary.

The absolute zero pivot and single-instrument direction map are transparent
QM hypotheses. They preserve the source's lower-RSJ/higher-next-return
orientation but replace a cross-sectional rank with a time-series state. The
log-return choice, continuous-CFD carrier, broker-month reconstruction,
one-attempt ledger, `RISK_FIXED` sizing, ATR hard stop, spread ceiling, and
stale exit are also QM mechanizations. No source return, alpha, Sharpe ratio,
drawdown, trade count, cost, WTI-only result, CFD equivalence, or portfolio-
correlation statistic transfers.

## Exact Statistical Contract

For strictly increasing positive finite D1 closes whose adjacent timestamps
both lie in the immediately preceding broker month:

```text
r[d]     = ln(close[d] / close[d-1])
RV_plus  = sum(r[d]^2 where r[d] > 0)
RV_minus = sum(r[d]^2 where r[d] < 0)
total    = RV_plus + RV_minus
RSJ      = (RV_plus - RV_minus) / total

signal = BUY  when RSJ < 0
         SELL when RSJ > 0
         FLAT when RSJ == 0 or state is invalid
```

Require 15 through 25 returns, `total > 0`, finite arithmetic, and RSJ inside
`[-1,1]` within `1e-12`. Zero returns contribute to neither semivariance but
remain valid observations. The current month, a return crossing the prior-
month boundary, an annualized scale, demeaning, threshold fitting, ranking,
trend fallback, and score-sized risk are forbidden.

## Non-Duplicate Boundary

The deterministic checker scanned 4,354 EA-registry rows and 466 root cards.
It found no exact identity and two expected source-family fuzzy matches.
Manual review fixes the boundary:

- `QM5_13129_energy-rsj` compares XTI and XNG RSJ values and trades a two-leg
  low-minus-high rank basket. This extraction has one WTI value, no second leg,
  no rank, no orphan state, and an absolute zero-pivot time-series direction.
  The parent's negative Q02 economics and Q04 failure are disclosed; this is
  neither a repair nor a performance inheritance.
- `QM5_20234_xauxag-rsj` is a paired precious-metal rank carrier with two
  magics and equal risk halves. It does not hold outright WTI or map absolute
  RSJ around zero.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback, not a normalized monthly signed-semivariance state.
- WTI return momentum, robust-location, ordinary reversal, calendar, event,
  breakout, variance-ratio, and path-quality systems use different
  information objects, direction maps, or clocks.

The one complete month, within-month log returns, normalized semivariance
difference, fixed zero pivot, low-RSJ long/high-RSJ short direction, outright
WTI carrier, and monthly lifecycle are jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_CROSS_SECTIONAL_TO_TIME_SERIES_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. One named peer-reviewed paper, DOI, institutional open manuscript,
  durable complete-read packet, and explicit WTI membership.
- R2: PASS. Month bounds, return inclusion, observation count, semivariance
  sums, normalization, pivot, direction, attempt, risk, stop, rollover, and
  stale exit are exact.
- R3: PASS. Registered `XTIUSD.DWX` D1 history and native MT5 execution state
  supply every runtime input.
- R4: PASS. Deterministic arithmetic only; no trained output, prohibited
  signal indicator, external feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The trading source supports testing commodity RSJ, not this absolute WTI
time-series translation. Q02 must retire the card below five completed
packages per full post-warm-up year or on nonpositive governed economics.
Downstream gates alone own robustness and correlation. No failure may be
rescued by changing the return window, zero pivot, direction, carrier, stop,
hold, spread, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or a claim of decorrelation.
