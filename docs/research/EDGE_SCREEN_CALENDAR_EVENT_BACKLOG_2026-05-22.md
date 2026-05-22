# Edge Lab — Adversarial Screen: Calendar / Event / Microstructure Backlog

Date: 2026-05-22
Author: Claude (operation lead)
Task: research_strategy `39ff5c2a-4791-4d6a-a876-e3a72c245051`
Perspective: deep_strategy_critique_and_synthesis — kill on paper before MT5 time.
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`
Companion: `docs/research/EDGE_SCREEN_DIRECTION1_XSEC_FX_2026-05-22.md`

## Scope

The companion screen covers the Direction-1 cross-sectional FX cohort. This
screen covers the remaining non-Direction-1 card drafts in
`D:/QM/strategy_farm/artifacts/cards_review/` — Edge Lab Directions 2
(event-conditioned), 3 (calendar/seasonal), 4 (SMC/microstructure), plus the
macro-announcement index cohort:

| ea_id | slug | Edge Lab direction | g0_status | quality |
|---|---|---|---|---|
| QM5_10349 | savor-wilson-macro-announcement-idx | D2 (macro event) | REVIEW | **A** |
| QM5_10350 | savor-wilson-macro-beta-spread | D2 (macro event) | REVIEW | **A** |
| QM5_10769 | london-fix-reversion | D4-adjacent (intraday) | REVIEW | **A** |
| QM5_10766 | pre-nfp-drift | D2 (event) | DRAFT | B |
| QM5_10891 | el-d2-t10-fomc-drift | D2 (event) | DRAFT | B |
| QM5_10768 | fomc-post-mom | D2 (event) | DRAFT | B |
| QM5_10764 | idx-totm | D3 (calendar) | DRAFT | B |
| QM5_10765 | gold-monthly-seasonal | D3 (calendar) | DRAFT | B |
| QM5_10763 | fx-month-end-rebal | D3 (calendar) | DRAFT | C |
| QM5_10892 | el-d3-t11-month-end-rev | D3 (calendar) | DRAFT | C |
| QM5_10767 | idx-earnings-drift | D3 (event) | DRAFT | C |
| QM5_10890 | el-d1-t9-cbi-rs | mislabelled | DRAFT | C |
| QM5_10893 | el-d4-t12-ls-ob-micro | D4 (SMC) | DRAFT | hold |

## Finding 1 — Launch-sequence violation: Direction 4 drafted too early

The charter sequences the four directions explicitly: each launches "once the
prior one has produced its first screened thesis batch", and Direction 4
(SMC/microstructure) is **last** — "Highest failure odds, last." QM5_10893
(SMC liquidity-sweep / order-block) is already a card draft in review.
Direction 1 has not yet cleared G0 (see companion screen); Directions 2–3 have
no screened batch. **QM5_10893 should be parked, not advanced** — return it to
`cards_draft/` and re-screen it only when Directions 1–3 have produced their
first batches. Beyond sequencing, the card carries the usual SMC hazards: a
fixed "2 pips beyond the extreme" micro-stop is broker/spread-fragile, and
"Order Block", "Market Structure Shift" and "50% mean threshold" need
bit-exact mechanical definitions before `r2_mechanical` can honestly be PASS.

## Finding 2 — Duplication inside the backlog

- **Month-end FX rebalancing is drafted twice.** QM5_10763
  (fx-month-end-rebal) and QM5_10892 (el-d3-t11-month-end-rev) both trade the
  month-end portfolio-rebalancing flow on the FX basket. They differ in
  expression — 10763 is a directional equity-hedge-flow trade exiting at the
  London Fix; 10892 is a cross-sectional MTD-return reversion — but they are
  one thesis family and must be reconciled into a single card with two
  variants, not run as two independent cards.
- **The pre-event drift template is drafted twice.** QM5_10766 (pre-NFP drift)
  and QM5_10891 (pre-FOMC drift) are the *same mechanical pattern* — enter on
  the prevailing short trend 24h before a scheduled release, exit before the
  blackout. They should be one parameterised event-drift card (event ∈ {NFP,
  FOMC, CPI}), not two near-identical drafts.
- **QM5_10768 (post-FOMC momentum) overlaps an already-sanctioned variant.**
  `PROFITABILITY_TRACK_2026-05-21.md` variant queue item #3 is "Post-FOMC
  continuation window" inside the `QM5_10260` FOMC-cycle family. An independent
  10768 card competes with that program. It must be reconciled into the
  QM5_10260 variant queue, not run separately — and per the Profitability
  Track's own rule, QM5_10260 variants are only created *after* the flagship P2
  result is known. 10768 is therefore premature.

## Finding 3 — R3 data-availability failures mislabelled PASS

- **QM5_10767 (idx-earnings-drift)** triggers "the day after an Apple /
  Microsoft / Nvidia earnings report". The farm maintains a macro **news**
  calendar (`D:\QM\data\news_calendar`); it has no single-stock earnings
  calendar. `r3_data_available: YES` is wrong — this needs a new data feed.
  Also `expected_trades_per_year_per_symbol: 4` is a near-certain zero-trade
  risk under Q02 fanout. Reject or rework as a data-feasibility item.
- **QM5_10763 (fx-month-end-rebal)** computes its signal from "the monthly
  return of the S&P 500 vs the foreign index" across S&P/FTSE/DAX. That is a
  multi-index equity-data dependency for a *live* FX EA; `SP500.DWX` is
  backtest-only (`reference_dwx_sp500_unavailable`). The signal is not live-
  deployable as written. Rework to a price-derived FX-only month-end signal
  (this is what 10892 already does — another reason to merge the two).
- **QM5_10890 (CBI-RS)** is mislabelled `el-d1` (Direction 1) but is an
  event-driven intervention trade, not cross-sectional relative-value. Worse,
  its falsification rests on "10 documented intervention-like events" — the
  EUR/CHF intervention era is the SNB-floor regime (2011–2015), a one-off that
  will not repeat. A 10-event sample cannot survive Q08/Q11 as evidence; this
  is structural overfit. Reject.

## Finding 4 — News-blackout compliance conflicts

The charter makes the news blackout **mandatory** and binding for FTMO. Two
cards sit in tension with it:

- **QM5_10763** self-admits it "executes *exactly* during a news-heavy window
  (month-end data dumps)". A card whose edge window coincides with the blackout
  window has very little tradable surface left once the blackout is enforced —
  G0 must see the realistic post-blackout trade count, not the gross one.
- **QM5_10768** enters "2 hours after the FOMC statement" — this is fine *only*
  if the FOMC blackout window has fully expired by then. The card asserts it
  has; G0 must verify the entry time falls outside the configured restricted
  window, not just outside the release minute.

By contrast QM5_10766 and QM5_10891 are correctly designed: they trade the
*pre*-event drift and flatten before the blackout opens — blackout-clean.

## Finding 5 — The macro-announcement cohort (10349/10350) is the strongest here

QM5_10349 and QM5_10350 are the best-built cards in this backlog and the only
ones already at `g0_status: REVIEW` with proper `QM5_` ids:

- Real, cited academic support (Savor & Wilson 2013/2014; Wachter & Zhu 2018).
- Explicit, correct **dedupe notes** — both deliberately exclude FOMC dates so
  they do not become a hidden clone of the `QM5_10260` FOMC-cycle flagship, and
  they enumerate distinctness from `QM5_1094`, `QM5_10019`, `QM5_10320`.
- They fit the active `PROFITABILITY_TRACK_2026-05-21.md` thesis exactly — "a
  controlled family of scheduled macro/event-cycle index strategies" — and
  honestly scope their data dependency (a checked-in CPI/employment release
  calendar, which is buildable from public schedules).

One real blocker on **QM5_10350**: it is a two-leg paired EA (long NDX.DWX /
short WS30.DWX). That hits the *same* multi-symbol architecture blocker raised
in the companion Direction-1 screen — the V5 build/Q02 representation for an EA
that trades two symbols atomically is undefined. The card handles this with
discipline ("mark `OPS_FIX_REQUIRED` rather than simplifying it into an
outright long clone") — but it cannot reach Q02 until that representation
exists. QM5_10349 (outright single-symbol long) has no such blocker and is
build-ready.

## Verification

- All 13 cards read in full from `D:/QM/strategy_farm/artifacts/cards_review/`.
- Data-availability claims checked against `D:\QM\data\news_calendar` (macro
  news only, no single-stock earnings), `reference_dwx_sp500_unavailable`
  (SP500.DWX backtest-only), and the active `PROFITABILITY_TRACK_2026-05-21.md`
  variant queue.
- Charter launch-sequence and news-blackout rules checked against
  `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`.
- No card files modified; read-only screen. Companion:
  `EDGE_SCREEN_DIRECTION1_XSEC_FX_2026-05-22.md`.

## Recommended next steps (for OWNER / router)

1. **Advance to G0 now (build-ready):** QM5_10349 (macro-announcement index),
   QM5_10769 (London-fix reversion — single-symbol M15, 120 trades/yr, no
   zero-trade or fanout risk, strongest mechanical spec in the calendar set).
2. **Advance to G0, gated:** QM5_10350 — behind the same multi-symbol Q02
   work-item `ops_issue` as the Direction-1 cohort.
3. **Cheapest legitimate Direction-3 tests, low DOF, single-symbol:** QM5_10764
   (turn-of-month index) and QM5_10765 (gold monthly seasonal) — pure calendar,
   fast to test; advance after a schema clean-up (bare numeric `ea_id` →
   `QM5_` form, `g0_status` fields).
4. **Merge then re-draft as one card each:** {10763 + 10892} → one month-end FX
   card; {10766 + 10891} → one pre-event-drift card.
5. **Reconcile, do not run standalone:** QM5_10768 → into the `QM5_10260`
   post-FOMC variant queue, and only after the flagship P2 result is known.
6. **Reject:** QM5_10767 (no earnings-calendar feed; 4 trades/yr zero-trade
   risk), QM5_10890 (10-event sample, structural overfit, mislabelled).
7. **Park:** QM5_10893 (SMC) → back to `cards_draft/`; Direction 4 is last per
   the charter launch sequence.
