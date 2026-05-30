---
ea_id: QM5_1130
slug: lou-polk-overnight-intraday
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/seasonality]]"
  - "[[concepts/calendar-anomaly]]"
indicators:
  - "[[indicators/session-clock]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 PASS: SSRN 2329485 URL and named JFE paper; R2 PASS: deterministic session-close entry/session-open exit with fixed filters; R3 PASS: testable on NDX/WS30/GDAXI/UK100 and SP500.DWX backtest-only caveat; R4 PASS: fixed clock rule, no ML/adaptive/grid/martingale, one position per symbol magic."
---

# QM5_1130 Lou-Polk-Skouras Overnight-Only Equity Index Hold

## Quelle
- Primary: SSRN 2329485 — "A Tug of War: Overnight Versus Intraday
  Expected Returns" by Dong Lou, Christopher Polk, Spyros Skouras.
  Journal of Financial Economics 134(1), Oct 2019
  (working paper Sep 2013).
  URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2329485
- Reported result: on US equities 1993-2013, **nearly the entire equity
  premium accrues overnight** (close-to-open) while the intraday
  component (open-to-close) is approximately flat or slightly negative
  on average. The persistence of the overnight-vs-intraday return
  separation across sub-samples and individual stocks is robust to
  microstructure controls.
- Lineage: Cliff/Cooper/Gulen "Return Differences Between Trading and
  Non-Trading Hours" (SSRN 1004081, 2008), Berkman/Koch/Tuttle/Zhang
  "Paying Attention: Overnight Returns and the Hidden Cost of Buying at
  the Open" (SSRN 1539502, JFQA 2012). Multiple follow-up papers
  through 2024 confirm the effect on equity indices specifically.

## Mechanik

### Entry
- **Daily** — at the close of each US trading session
  (broker-time = 22:00 broker-time outside DST / 23:00 during US DST):
  - Open **long** on the equity index CFD.
  - Single position, full RISK_FIXED budget.

### Exit
- **Daily** — at the open of the next US trading session
  (broker-time = 15:30 broker-time outside DST / 16:30 during US DST,
  approximately 17.5 hours later for NDX/WS30/SP500.DWX):
  - Close the position.
  - Flat all intraday hours.

### Stop Loss
Per-position ATR(D1,14) * 3 hard stop on overnight-bar move AND
portfolio MAX_DD 20% trip (HR3/5 mandatory). Per-trade max-loss matters
here because overnight gap-risk is real (futures-gap, earnings-after-
hours for index components).

### Position Sizing
V5 standard: `RISK_FIXED = $1,000` per symbol per overnight cycle for
P2 baseline. `RISK_PERCENT` for live (HR4).

### Zusätzliche Filter
- **Skip entry on**: Fridays (weekend gap-risk is larger than weekday;
  paper documents Friday-to-Monday returns are noisier). P3 sweep tests
  including/excluding Fri.
- **Skip entry before**: scheduled FOMC announcements, major earnings
  weeks for index heavyweights, US economic-data Tue/Wed nights. News
  filter mandatory.
- Volatility regime overlay (P3): scale or skip when VIX-equivalent
  proxy (21d realized vol on the index) > 1.5x trailing 12m mean.
- V5 mandatory: news filter, MAX_DD trip.

## Concepts
- [[concepts/seasonality]] -- the **intraday calendar** is the seasonality;
  this is a session-of-day calendar effect, sibling to the month-of-year
  / day-of-month calendar effects in QM5_1047 / QM5_1049
- [[concepts/calendar-anomaly]] -- session-clock variant

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Lou/Polk/Skouras JFE 2019, ~800 citations; Polk=LSE tenured, Lou=LSE, Skouras=Athens U. Robust replication lineage (Cliff-Cooper-Gulen 2008, Berkman et al JFQA 2012, multiple post-2019 follow-ups). Effect documented on equity indices specifically (not only individual stocks) |
| R2 Mechanical | PASS | Two clock-time events per day per symbol (close-time entry, open-time exit). Zero discretion. Friday-skip and news-skip filters are deterministic |
| R3 Data Available | PASS | DXZ index basket = NDX.DWX, WS30.DWX, SP500.DWX (backtest-only), GDAXI.DWX, UK100.DWX. P2 baseline on NDX.DWX (US-cash-session matches paper's universe most directly). P3 expands to all 5 indices. Each index uses its own home-market session-clock — GDAXI uses Xetra hours, UK100 uses LSE hours, etc. |
| R3 (continued — SP500.DWX caveat) | NOTE | If P2 also runs on SP500.DWX, card includes the mandatory T6-live-promotion caveat: SP500.DWX is not broker-routable, so passing P0-P9 on SP500.DWX alone is not sufficient for T6 enable — parallel-validation on NDX.DWX or WS30.DWX is required before AutoTrading. This is Board Advisor's T6-gate enforcement, not Codex's |
| R4 ML Forbidden | PASS | Pure clock-event rule. No parameters change online. Filter parameters (Friday-skip flag, vol threshold) are fixed, not learned |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 2 (autonomous wake), PENDING

## Verwandte Strategien
- Sibling: QM5_1045 (zarattini-spy-intraday-momentum) — also session-clock-
  aware but takes the OPPOSITE side (intraday breakout, EOD flatten).
  These two together implement the full Lou-Polk decomposition: QM5_1045
  captures the intraday breakout phase (which sometimes pays despite the
  full-day average being flat), QM5_1130 captures the always-on overnight
  carry. P3 may show they have low/negative correlation by construction
- Sibling: QM5_1049 (mcconnell-turn-of-month) — also a calendar-anomaly
  card; same family, different timescale (daily vs monthly cycle)

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbol: **NDX.DWX primary** for P2 baseline (matches paper's
  US-equity universe most directly).
- Timeframe: M30 (sufficient to bracket the session-open / session-close
  events with 30-minute precision; H1 also acceptable).
- Session times — use broker-time. **Cite the broker-time convention
  from CLAUDE.md**: GMT+2 outside US DST, GMT+3 during US DST. For NDX/WS30
  (US-cash-session 09:30-16:00 ET):
  - Outside US DST: open ≈ 15:30 broker-time, close ≈ 22:00 broker-time.
  - During US DST: open ≈ 16:30 broker-time, close ≈ 23:00 broker-time.
  - Codex must use the DXZ session calendar (NOT hardcoded clock times) to
    get the actual session boundaries per symbol per day — accounts for
    early-close days (US half-days) and exchange holidays.
- For GDAXI/UK100 (European cash session 09:00-17:30 local) — different
  session-clock times; P3 multi-symbol must per-symbol parametrise.
- "Overnight" for European indices means London-close → London-open
  (not US-close → US-open). The paper's effect has been replicated on
  European indices (Berkman et al footnote citing FTSE/DAX). Document.
- Magic per symbol per HR4.
- P3 sweep variants: include / exclude Friday entries; include / exclude
  pre-FOMC nights; vol-regime overlay on / off; "entry at session_close - 15min"
  vs "entry at exact close"; exit at "session_open + 15min" vs exact open.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
