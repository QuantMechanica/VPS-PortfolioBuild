# XNGUSD Missing Sleeve Research — 2026-07-02

**Task:** d4cc2b7c — R1 natgas: XNGUSD seasonality + EIA-storage-cycle mechanical edges  
**Agent:** Claude  
**Date:** 2026-07-02

## Objective

Identify solo XNGUSD mechanical edges that are style-orthogonal to the existing
book sleeve `QM5_12567_cum-rsi2-commodity` (MR-heavy) and fill gaps in the
inventory that already covers: EIA storage fade/idbrk/prestor/aftershock, broad
seasonal windows (winter/spring/summer/fall/dual-peak), Thursday DOW fade, shoulder
fade, 4-week MR, volshock fade, expiry break/fade, LNG break, 52W anchor,
weekend gap.

## Coverage Inventory (pre-task)

| ID | Slug | Style | Window/Trigger |
|---|---|---|---|
| 12575 | eia-xng-season | seasonal-calendar | broad winter/summer/shoulder |
| 12584 | eia-xng-storage | event-aftershock | EIA report reaction |
| 12595 | eia-xng-shfade | event-fade | shoulder fades |
| 12601 | eia-xng-hurr-brk | event-breakout | hurricane season |
| 12602 | eia-xng-frzfade | event-fade | freeze events |
| 12702 | winter-withdrawal-long | seasonal | Nov–Mar long, SMA confirmed |
| 12703 | spring-shoulder-short | seasonal | Apr–May short, SMA crossdown |
| 12704 | summer-power-long | seasonal | summer long |
| 12705 | fall-storage-short | seasonal | Sep–Oct short, SMA crossdown |
| 12706 | seasonal-dual-peak | seasonal | full-year rotation |
| 12725 | eia-xng-prestor | event-pre | pre-report positioning |
| 12744 | eia-xng-storfade | event-fade | post-report exhaustion fade |
| 12761 | eia-xng-stor-idbrk | event-breakout | inside-day compression breakout |
| 12769 | eia-xng-lng-brk | structural-breakout | LNG export-trend breakout |
| 12807 | xng-52w-anchor | mean-reversion | 52-week anchor |
| 12817 | xng-volshock-fade | volatility | vol-shock fade |
| 12819 | xng-thu-fade | calendar-DOW | Thursday short (day-of-week) |
| 12830 | xng-exp-brk | calendar-event | expiry breakout |
| 12838 | xng-exp-fade | calendar-event | expiry fade |

## Gaps Identified

After mapping the full inventory, three genuine gaps remain:

1. **EIA storage report DRIFT (continuation)** — the existing cards FADE (12744)
   or trade compressed inside-day breakouts (12761). The Linn & Zhu (2004) JFM
   paper documents that large post-report moves sometimes CONTINUE over subsequent
   bars. No continuation/drift card exists.

2. **Late-winter premium decay (Feb 15–Mar 31)** — 12703 covers Apr 1–May 31.
   The Feb 15–Mar 31 window, when the heating-season winter premium begins eroding
   as temperature forecasts improve, is uncovered. This is structurally prior to
   the spring shoulder and mechanically different.

3. **Injection-season SMA-slope trend filter** — 12703 (Apr–May only, SMA level)
   and 12705 (Sep–Oct only, SMA level) cover narrow windows. A slope-confirmed
   short across the full injection season (Apr–Sep) that also requires SMA to be
   falling (not just price below SMA) adds a quality filter that the existing cards
   lack and covers the mid-season months (Jun–Aug) currently absent.

## Deliverables

Three strategy cards filed in `D:/QM/strategy_farm/artifacts/cards_review/`:

### QM5_12872 — EIA XNG Storage Report Continuation Drift
- **File:** `D:/QM/strategy_farm/artifacts/cards_review/QM5_12872_eia-xng-stor-drift.md`
- **Source:** Linn, S.C. and Zhu, Z. (2004). Natural Gas Prices and the Gas Storage
  Report. Journal of Futures Markets, 24(3), 283-313.
- **Mechanic:** Detect large EIA report day (Wed/Thu/Fri, range ≥ min_range × ATR),
  observe next D1 bar confirms same direction (same-sign body ≥ min_confirm × ATR),
  enter continuation in that direction if SMA also confirms. ATR stop, SMA exit,
  max-hold exit.
- **Trades/yr:** ~6–12. **Style:** trend/continuation. **Ortho:** fades are already
  done (12744); this is the complementary drift variant.

### QM5_12873 — XNG Late-Winter Premium Decay Short
- **File:** `D:/QM/strategy_farm/artifacts/cards_review/QM5_12873_xng-latewinter-decay-short.md`
- **Source:** EIA Today in Energy, "Natural gas consumption, production respond to
  seasonal changes", Scott Bradley, 2015-09-24.
- **Mechanic:** Short-only, active Feb 15–Mar 31, entry when prior D1 close crosses
  below 20-period SMA. ATR stop, SMA recovery exit, hard Apr 1 calendar exit.
- **Trades/yr:** ~2–4. **Style:** seasonal short (decay window, not injection season).
  **Ortho:** Apr 1 start of 12703 means no overlap; Feb 15–Mar 31 is uncovered.

### QM5_12874 — XNG Injection Season SMA-Slope Filtered Short
- **File:** `D:/QM/strategy_farm/artifacts/cards_review/QM5_12874_xng-inject-slope-short.md`
- **Source:** Routledge, Seppi & Spatt (2000). Equilibrium Forward Curves for
  Commodities. Journal of Finance, 55(3), 1297-1338.
- **Mechanic:** Short-only, active Apr 1–Sep 30. Entry when prior D1 close < SMA(50)
  AND SMA(50) is falling (SMA[0] < SMA[lookback_bars]). Exits on SMA level recovery,
  SMA slope turning positive, or Oct 1 calendar.
- **Trades/yr:** ~4–10. **Style:** trend/momentum within injection season.
  **Ortho:** 12703 (Apr–May, no slope filter) and 12705 (Sep–Oct, no slope filter)
  both miss the Jul–Aug core and the slope quality gate.

## Non-Duplication Verification

Each new card's "Non-duplicate" section lists all existing cards that could be
confused with it and explains the structural distinction. Short summary:
- 12872 vs 12744/12761: opposite direction (continuation vs fade, different setup).
- 12873 vs 12703: different window (Feb 15–Mar 31 vs Apr 1–May 31), no calendar overlap.
- 12874 vs 12703/12705: different quality gate (slope filter absent in both existing
  cards), different full-season window coverage.

## Correlation Argument

All three cards are short-only or trend/continuation in style. None uses RSI or
oscillator pullback logic. The book's existing commodity MR sleeve (12567) is
RSI2-based. Correlation of calendar/trend/event-drift mechanics to RSI2 MR is
expected to be low.

## R1–R4 Summary

| Card | R1 | R2 | R3 | R4 |
|---|---|---|---|---|
| 12872 | PASS (JFM peer-reviewed) | PASS (deterministic) | PASS (XNGUSD.DWX) | PASS (no ML) |
| 12873 | PASS (EIA official) | PASS (deterministic) | PASS (XNGUSD.DWX) | PASS (no ML) |
| 12874 | PASS (JF peer-reviewed) | PASS (deterministic) | PASS (XNGUSD.DWX) | PASS (no ML) |
