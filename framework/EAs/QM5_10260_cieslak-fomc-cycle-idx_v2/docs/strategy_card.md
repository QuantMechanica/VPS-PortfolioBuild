---
ea_id: QM5_10260
slug: cieslak-fomc-cycle-idx
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/macro-event-calendar]]"
  - "[[concepts/fomc-cycle]]"
  - "[[concepts/equity-index-calendar]]"
indicators:
  - "[[indicators/fomc-meeting-table]]"
  - "[[indicators/weeks-since-event]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 PASS SSRN/JoF source; R2 PASS deterministic FOMC-cycle entry/Friday exit; R3 PASS NDX.DWX/WS30.DWX plus SP500.DWX backtest caveat; R4 PASS static non-ML one-position rules."
expected_trades_per_year_per_symbol: 50
---

# QM5_10260 Cieslak FOMC-Cycle Even-Week Long (US Index)

## Quelle
- Primary: SSRN 2358090 — Cieslak, A., Morse, A., Vissing-Jorgensen,
  A. (2014, 2019) "Stock Returns over the FOMC Cycle." Published
  as Journal of Finance 74(5), pp. 2201-2248 (2019).
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2358090
- Reported result: from 1994-2016 (extended to 2024 in
  follow-up working papers), the equity premium on the S&P 500
  is realized **entirely in even weeks of the FOMC cycle**
  (week 0 = the week containing the FOMC meeting day; weeks
  count forward from the most-recent FOMC meeting). Specifically
  weeks 0, 2, 4, 6 of the FOMC cycle (where each FOMC cycle
  spans ~6-8 weeks between meetings) average ~50 bp/week excess
  return; odd weeks 1, 3, 5, 7 average ~0 bp/week. The pattern is
  highly statistically significant (t > 4) and robust across
  sub-samples, alternative event-week alignment definitions, and
  international markets influenced by Fed policy spillovers.
- Lineage / replication:
  - Lucca, D.O., Moench, E. (2015) "The Pre-FOMC Announcement
    Drift." Journal of Finance 70(1) — documents the
    24-hour-pre-meeting drift (subsumed into Cieslak's
    even-week pattern).
  - Brusa, F., Savor, P., Wilson, M. (2020) "One Central Bank
    to Rule Them All." Review of Finance — FOMC effect dominates
    other central banks' announcement effects globally.
  - Hu, G.X., Pan, J., Wang, J., Zhu, H. (2022) "Premium for
    Heightened Uncertainty: Explaining Pre-Announcement Market
    Returns." Journal of Financial Economics — proposes
    uncertainty-resolution as the economic mechanism.
- 700+ citations on the primary paper; one of the most cited
  macro-anomaly findings of the past decade.

## Mechanik

### Entry
- **Universe**: 3 US-equity-index CFDs — NDX, WS30 (live-routable
  on DXZ) and SP500.DWX (backtest-only — see R3 caveat).
- **FOMC-cycle clock**: maintain a static look-up table of all
  scheduled FOMC meeting dates 2018-2026+ (the Federal Reserve
  publishes the calendar 1-2 years in advance, ~8 meetings per
  year). For any trading day `t`, compute
  `cycle_week = floor((t - last_fomc_meeting_date) / 7)`.
- **Trigger**: open long position at the **Monday session open**
  of any week whose `cycle_week` is even (0, 2, 4, 6, 8).
- One open position per index-magic at a time.

### Exit
- **Trigger**: close long position at the **Friday session close**
  of the same even-cycle week.
- Hold duration: ~5 trading days (Monday open → Friday close
  within an even-cycle week).
- Flat over weekend and through the entire following odd-cycle
  week (if any).

### Stop Loss
- ATR(D1,14) × 3 hard stop below entry.
- Time-stop: force-close at Friday close of the same even-cycle
  week.
- Portfolio MAX_DD 20 % trip (HR3/5 mandatory).

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` per index per weekly cycle
  for P2 baseline, `RISK_PERCENT` for live (HR4).

### Zusätzliche Filter
- Skip entry on a Monday that is a US market holiday — use
  Tuesday session open as alternative entry within the same
  even-cycle week, with exit still at Friday close.
- News-calendar filter (V5 mandatory). FOMC meeting itself
  always falls in week 0 → entry signal naturally fires on
  meeting week; the V5 default 24h-before-event skip would
  prevent this. **Exception**: this card explicitly *wants* to
  hold across FOMC announcement (the pre-announcement drift is
  part of the signal per Lucca-Moench 2015). Skill-level override
  `allow_fomc_hold = TRUE` documented in P1 build spec.
- Per-index magic-slot.

## Concepts
- [[concepts/macro-event-calendar]] -- primary
- [[concepts/fomc-cycle]] -- mechanism
- [[concepts/equity-index-calendar]] -- secondary
- [[concepts/pre-announcement-drift]] -- supporting

## R3 — SP500.DWX live-promotion caveat
SP500.DWX is a Custom Symbol on T1-T5 (OWNER-imported ticks
2018-07→2026-05, available since 2026-05-16T19:15Z). DXZ broker
does NOT route live orders on SP500. If this EA passes P0-P9 on
SP500.DWX, T6 deploy requires parallel-validation on NDX.DWX or
WS30.DWX before AutoTrading enable. Board Advisor T6-gate
enforcement. NDX.DWX and WS30.DWX are live-routable without
caveat.

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Cieslak-Morse-Vissing-Jorgensen JoF 2019, ~700 citations, top-tier peer-reviewed. All three authors tenured (Cieslak Duke, Morse Berkeley Haas, Vissing-Jorgensen Berkeley Haas + ex-IMF deputy director). Confirmed by Lucca-Moench JoF 2015 (pre-FOMC drift) and Brusa-Savor-Wilson 2020 (international Fed-spillover). One of the strongest R1 cards in the SSRN-mined batch lineage |
| R2 Mechanical | PASS | FOMC-meeting-table is a published Federal-Reserve calendar; `cycle_week = floor((today - last_meeting) / 7)` is closed-form integer arithmetic. Entry trigger on even cycle_week, exit at Friday close — pure calendar rule with a static look-up table. No indicators, no learning, no adaptive parameters |
| R3 Data Available | PASS | NDX.DWX + WS30.DWX live on DXZ; SP500.DWX backtest-only (T6 caveat above). 8 FOMC meetings × ~3 even-weeks-per-cycle × 8 years ≈ 192 even-week cycles in P2 baseline window — strong sample. FOMC dates 2018-2026+ are publicly available and embedded as static constant. The 2026-2030 meeting calendar (published Aug 2025 by Fed Board) extends look-ahead through end-2027 |
| R4 ML Forbidden | PASS | Static lookup-table calendar rule + integer arithmetic. No neural nets, no online learning, no adaptive parameters. The static FOMC-meeting table is a published, deterministic, exogenous calendar — not a learned model. ATR-based stop is deterministic volatility-scaled |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 4 (autonomous wake), PENDING

## Verwandte Strategien
- Adjacent to QM5_1158 (french-weekend-effect-idx) — both are
  weekly-cycle calendar bets. Weekend-effect avoids Monday;
  FOMC-cycle hold runs Monday-Friday only in even weeks. Both
  could be live simultaneously, with FOMC-cycle as a "regime
  filter" overlaying the Tue-Fri weekend-effect window. P5 may
  produce a composite card combining both.
- Distinct from QM5_1126 (moskowitz-tsmom-12m) — TSMOM is trend
  bet over 12 months; FOMC is event-calendar bet over weekly
  cycle. Orthogonal time-scales.
- Distinct from QM5_1049 (mcconnell-turn-of-month) — TOM is
  monthly window; FOMC is biweekly within an 8-week cycle. No
  systematic overlap.
- Subsumes (partially) the Lucca-Moench pre-FOMC drift (24h
  before announcement) — that effect lives inside this card's
  week-0 holding window.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbols: NDX.DWX, WS30.DWX, SP500.DWX (backtest-only — T6
  deploy caveat in R3 section).
- Timeframe: D1 for FOMC-cycle-week computation; M30 for
  execution on Monday open / Friday close of even cycle weeks.
- **FOMC meeting date table** — embed as MQL5 const array of
  datetimes. Source: federalreserve.gov/monetarypolicy/fomccalendars.htm.
  Populate 2018-01-01 through 2027-12-31 at build time.
  Approximate count: 8 meetings × 10 years = 80 datetime
  entries. Document the table-as-of date in the EA source so
  re-builds in 2028+ refresh the table.
- Cycle-week computation: on each D1 bar `t`, scan the table
  for max-meeting-date `m ≤ t`, then `week = floor((t - m) / 7
  days)`. Entry trigger: `week % 2 == 0 AND TimeDayOfWeek(t)
  == 1` (Monday). Exit trigger: `week % 2 == 0 AND
  TimeDayOfWeek(t) == 5 AND TimeCurrent() > <session close 30
  min before>` (Friday close).
- Magic-slot allocation: 3 magic-slots (one per US-index) per HR4.
- P3 sweep candidates: even-week-only vs week-0-only vs week-2-only
  vs week-0-and-2; entry Mon vs Tue; exit Thu vs Fri; ATR stop
  2/3/4; with/without `allow_fomc_hold` override (FOMC-week vs
  non-FOMC-even-weeks comparison); long-only vs long-on-even +
  short-on-odd long-short variant.
- Logging: persist per-cycle-week per-index PnL — needed for
  even-vs-odd-week diagnostics in P5; also needed for table
  re-validation if Fed reschedules a meeting (rare but happened
  in 2020 emergency cuts).

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
