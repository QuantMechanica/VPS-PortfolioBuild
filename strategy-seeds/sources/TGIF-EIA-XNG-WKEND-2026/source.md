---
source_id: TGIF-EIA-XNG-WKEND-2026
title: Natural-gas pre-weekend to Monday structural return window
publisher: Journal of Finance Issues / U.S. Energy Information Administration
source_type: peer_reviewed_plus_official_agency_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-14_xng_wkend_hold_g0.md
parent_source_ids:
  - TGIF-WTI-WEEKEND-2017
  - EIA-XNG-WEEKEND-GAP-2026
created: 2026-08-14
created_by: Research+Development
cards_extracted:
  - xng-wkend-hold
---

# XNG Pre-Weekend To Monday Source Packet

## Approved sources of record

This bounded extraction uses two already governed repository packets, both
read completely before the card was drafted.

1. `strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md` records the
   complete official 22-page review of Hoelscher, Seth A., Cedric Mbanga, and
   Walt A. Nelson (2017), "TGIF? The Weekend Effect in Energy Commodities,"
   *Journal of Finance Issues* 16(1), 47-68, DOI
   `10.58886/jfi.v16i1.2264`. Despite the parent packet's historical WTI name,
   its reviewed paper explicitly covers natural gas and records the relevant
   natural-gas tables, estimators, subperiods, and EIA spot-data provenance.
2. `strategy-seeds/sources/EIA-XNG-WEEKEND-GAP-2026/source.md` records the
   U.S. Energy Information Administration's official description of weather-
   sensitive heating and electric-power demand as recurring natural-gas price
   drivers.

The OWNER commodity/energy mission delivered on 2026-08-14 is the durable
authority for this bounded source/card packet, deterministic allocation,
non-live build, strict Q01 validation, and one paced Q02 handoff.

A fresh deterministic source-router call for the journal landing page on
2026-08-14 returned `PERMISSION_REQUIRED` with lead status
`DEFERRED:SOURCE_POLICY` because the generic reader is router-only. No proxy,
mirror, cookie, CAPTCHA, or other workaround was attempted. No new web text is
imported; the earlier complete governed review remains the source of record.

## Findings used

- The paper computes weekday-labelled close-to-close EIA spot returns and
  reports positive natural-gas Monday coefficients across its five full-
  sample estimators. Its repository review records persistence in the two
  tested subperiods, with all five estimators positive/significant in the
  later subperiod.
- A Monday-labelled close-to-close observation contains the non-tradable
  weekend interval. Entering only after Monday opens, as prior QM extractions
  do, cannot capture that interval.
- EIA identifies weather-sensitive heating and electric-power demand as
  recurring natural-gas price drivers, providing a structural reason why
  information accumulated while the market is closed can matter at the
  reopen.

The paper does not prescribe a trading implementation and the EIA page does
not claim a return premium. The findings support one falsifiable translation:
does an executable XNG long held from the standard V5 Friday risk cutoff to
the matching Monday cutoff retain a positive net return after CFD costs and
gap risk?

## Bounded mechanization

- Trade only `XNGUSD.DWX` on H1, magic slot 0.
- On the genuine Friday 21:00 broker H1 boundary, within a five-minute attach
  grace, persist the framework week key before all fallible gates and allow at
  most one attempt for that week.
- Buy one fixed-risk XNG position; never sell, hedge, pyramid, or scale.
- Protect it with a frozen `3.5 * ATR(20,D1)` server-side hard stop and no
  take-profit.
- Deliberately disable framework Friday flatten, then close at the first tick
  at or after Monday 21:00 broker time. Close on the first later-week tick if
  that cutoff is missed and after 96 hours at the latest.
- Use only native MT5 broker time, H1/D1 bars, spread, quote, ATR, position,
  deal, and terminal-global state.

The 21:00 broker cutoff is the existing V5 Friday risk boundary, not the
paper's EIA spot fixing. H1 execution, continuous-CFD mapping, fixed-dollar
risk, ATR stop, spread ceiling, attempt persistence, and stale repair are
transparent QM hypotheses. No paper return, coefficient, significance,
cost, trade count, drawdown, or correlation statistic transfers.

## Non-duplicate boundary

The deterministic identity check returned no exact collision and one
source-family fuzzy match. Manual review separates it:

- `QM5_20016_xti-xng-mon-rv` enters a jointly sized short-WTI/long-XNG package
  on Monday after the weekend and exits at the next D1 boundary. It cannot
  hold XNG alone and does not capture the closed-market interval.
- `QM5_12806_xng-rev-weekend` buys only after Monday starts and independently
  sells Friday. It explicitly records the timing mismatch this card tests.
- `QM5_12738_xng-weekend-gap` requires a completed Monday gap and confirming
  body, then follows the gap. This card enters before the gap exists and has
  no gap-size, body, or direction filter.
- XNG seasonality, storage, weather-shock, trend, reversal, carry, expiry, and
  relative-value systems use different state objects or packages.

Verdict:
`CLEAN_AUTHORIZED_XNG_PREWEEKEND_TO_MONDAY_HOLD_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1: PASS. One bounded composite lineage backed by a fully reviewed named-
  author peer-reviewed paper with DOI/full-text receipt and an official EIA
  structural source.
- R2: PASS. Entry boundary, long-only direction, consumed attempt, sizing,
  stop, spread, exit boundary, stale repair, and invalid-state behavior are
  deterministic.
- R3: PASS. Registered native `XNGUSD.DWX` H1/D1 data and MT5 execution state
  supply every runtime field; no external series is read.
- R4: PASS. Fixed calendar and native arithmetic only, with no trained signal,
  PnL adaptation, grid, martingale, scale-in, pyramid, or randomness.

## Claim, kill, and safety boundary

The source evidence is historical EIA spot data, while Q02 tests a continuous
Darwinex custom CFD with broker-specific hours, spread, gap, and roll effects.
Holding deliberately crosses the framework's usual Friday flat boundary, so
weekend jumps, stop slippage, Monday holidays, continuous-CFD basis, and
source-to-carrier timing mismatch are first-order kill risks.

Retire below five completed trades per full year, on nonpositive governed
economics, or at later portfolio-correlation rejection. Failure may not be
rescued by moving entry to Monday, selecting months, adding a gap/trend
filter, changing direction, widening the stop, extending the Monday exit, or
retrying a consumed week.

This packet authorizes one non-live V5 build, strict Q01, one `RISK_FIXED`
backtest setfile, and one paced Q02 handoff while capacity permits. It does
not authorize a manual tester run, live/demo/shadow/stress artifact,
AutoTrading, `T_Live`, a deploy manifest, portfolio admission, a portfolio-
gate change, or a correlation waiver.
