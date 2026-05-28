---
ea_id: QM5_1145
slug: cliff-cooper-intraday-only-idx
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/session-clock]]"
  - "[[concepts/overnight-intraday-decomposition]]"
indicators:
  - "[[indicators/session-open]]"
  - "[[indicators/session-close]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS SSRN source/link; R2 PASS session-clock short open-to-close with exit/SL; R3 PASS DWX indices incl SP500.DWX backtest-only T6 caveat; R4 PASS no ML/adaptive/grid/martingale, one position per magic."
---

# QM5_1145 Cliff-Cooper-Gulen Intraday-Only Index Hold (QM5_1130 sibling)

## Quelle
- Primary: SSRN 1004081 — Cliff, M.T., Cooper, M.J., Gulen, H. (2008)
  "Return Differences Between Trading and Non-Trading Hours: Like Night
  and Day". Working paper documenting that for major US equity indices
  and ETFs, nearly all the cumulative return historically occurred
  **overnight** (close-to-open), while intraday (open-to-close) returns
  were flat or slightly negative depending on era.
  SSRN abstract 1004081
- Companion / lineage:
  - SSRN 2329485 — Lou, D., Polk, C., Skouras, S. (2019) "A Tug of War:
    Overnight Versus Intraday Expected Returns" JFE — extends the
    decomposition with cross-sectional evidence.
  - SSRN 1539502 — Berkman, H., Koch, P.D., Tuttle, L., Zhang, Y.J.
    (2012) "Paying Attention: Overnight Returns and the Hidden Cost
    of Buying at the Open" JFQA — attribution to retail attention
    at the open.
- Reported result: open-to-close intraday return on S&P 500 1993-2007
  was ~0 bps/day mean (~−10 bps/day in some sub-windows); close-to-open
  overnight return was ~+5 to +7 bps/day. The decomposition is robust
  across major US equity indices and during multiple decades.
- **Intended counter-test**: QM5_1130 (lou-polk-overnight-intraday)
  trades the **positive** overnight side (long close → flat open).
  QM5_1145 trades the **negative-or-flat** intraday side (short open →
  flat close) — the empirical counterpart. If the decomposition holds
  on DXZ data 2018-2025, this card's expected baseline is flat to mildly
  positive (short side of a near-zero-mean return is symmetric); if the
  intraday-side is actually positive on DXZ 2018-2025 era (e.g., the
  decomposition has weakened post-2020), this card will negative-test
  and DIE at P2 with negative PF — that's still useful information
  about the decomposition's stability.

## Mechanik

### Entry
- **Daily** rule on major equity-index instruments.
- Universe: 4 DXZ indices (GDAXI, NDX, UK100, WS30) + SP500.DWX
  (backtest-only).
- At the **first M30 bar after session open** for each index:
  - **Short** 1 unit of the index (one position per symbol).
- (Symmetric long-side variant in P3 sweep: instead long-the-intraday
  on indices where intraday is empirically positive.)

### Exit
- At the **last M30 bar before session close** for the same trading
  day → close the position. Flat overnight.
- New short opens at next day's session open.

### Stop Loss
ATR(M30,14) × 4 intraday hard stop (intraday short of an index can
have a strong continuation rally; need wider stop than QM5_1130's
overnight side). Portfolio MAX_DD 20 % trip (HR3/5).

### Position Sizing
V5 standard: `RISK_FIXED = $1,000` per index per session for P2
baseline, `RISK_PERCENT` for live (HR4).

### Zusätzliche Filter
- News-calendar filter — skip days with FOMC rate decision (intraday
  vol dominated by announcement, masks the decomposition signal).
- Skip days where overnight gap > 1 % (large-gap days behave
  differently and are documented in Lou-Polk-Skouras as a separate
  regime).
- P3 sweep: long-side vs short-side; per-index regime filter (test
  whether some indices have positive intraday — GDAXI's session
  structure differs from US indices); with/without gap filter.

## Concepts
- [[concepts/session-clock]] -- primary
- [[concepts/overnight-intraday-decomposition]] -- mechanism

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Cliff-Cooper-Gulen 2008 working paper at Virginia Tech / Purdue; extended by Lou-Polk-Skouras JFE 2019 and Berkman et al JFQA 2012 — both top-tier peer-reviewed venues. The intraday-vs-overnight decomposition is documented across 30+ years of US equity data |
| R2 Mechanical | PASS | Pure session-clock rule — "short at first M30 after open, exit at last M30 before close, flat overnight". No parameters, no discretion, fully deterministic |
| R3 Data Available | PASS-WITH-CAVEAT | DXZ index basket on M30 has continuous data from 2018-07. SP500.DWX inclusion requires standard T6-live-promotion caveat (see ## R3 below). NDX and WS30 are live-tradable analogs to S&P 500 / Dow components; GDAXI and UK100 trade on European sessions and the decomposition may differ (P2 will verify per-index) |
| R4 ML Forbidden | PASS | Session-clock rule, no parameters, no ML, no adaptive logic. Magic per index per HR4 |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 3 (autonomous wake), PENDING

## Verwandte Strategien
- **Negative-counterpart pair** to QM5_1130 (lou-polk-overnight-intraday).
  Both cards derive from the same intraday-vs-overnight decomposition.
  QM5_1130 trades the empirically-positive overnight leg (close → open
  long). QM5_1145 trades the empirically-flat-or-negative intraday leg
  (open → close short).
  **Joint P2 result is the primary scientific output of this pair**:
  - Both pass → decomposition holds on DXZ 2018-2025; portfolio combo
    of long-overnight + short-intraday is the right deploy.
  - QM5_1130 passes, QM5_1145 fails → standard "all the return is
    overnight" regime, only deploy the overnight side.
  - Both fail → decomposition has weakened post-2020; archive both.
- Distinct from: QM5_1045 (zarattini-spy-intraday-momentum) — same
  intraday window but signal-driven (noise-boundary breakout) not
  session-clock unconditional.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbols: GDAXI.DWX, NDX.DWX, UK100.DWX, WS30.DWX,
  SP500.DWX (backtest-only).
- Timeframe: M30.
- "Session open" — first M30 bar of the index's primary trading
  session in broker-time:
  - GDAXI: 09:00 server (XETRA open ≈ 08:00 UTC = ~10:00/11:00 server
    depending on DST).
  - UK100: 09:00 server (LSE open ≈ 08:00 UTC).
  - NDX, WS30: 15:30 server (NYSE open ≈ 13:30 UTC).
  - SP500.DWX: 15:30 server.
  - Codex must read DXZ trading-session metadata at runtime — do NOT
    hard-code times that could break under DST switches. Use
    `SymbolInfoSessionTrade` or equivalent MQL5 API.
- "Session close" — last M30 bar before primary-session close (same
  symbol-info source).
- Magic per index per HR4.
- P3 sweep: long-side vs short-side per index; with/without FOMC and
  gap filters; sub-window (e.g., first hour only / last hour only) vs
  full session.

## R3
T6 live-promotion gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-
validation on NDX.DWX or WS30.DWX before AutoTrading enable. (Board
Advisor T6-gate enforcement.)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*

