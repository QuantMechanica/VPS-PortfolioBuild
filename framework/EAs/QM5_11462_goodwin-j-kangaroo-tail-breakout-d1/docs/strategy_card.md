---
ea_id: QM5_11462
slug: goodwin-j-kangaroo-tail-breakout-d1
type: strategy
source_id: 038d2a5d-1c89-5745-afdb-2cd76b623b77
sources:
  - "[[sources/goodwin-j-beat-markets-guidebook]]"
concepts:
  - "[[concepts/3-bar-pivot]]"
  - "[[concepts/stop-order-entry]]"
  - "[[concepts/time-exit]]"
  - "[[concepts/breakout]]"
indicators: []
period: D1
source_citation: "Jarrod Goodwin, Beat the Markets Strategy Guidebook, thetransparenttrader.com (~2020). R1 CONDITIONAL — named author, backtested performance cited. Local PDF: 622374394-Beat-the-Markets-Strategy-Guidebook.pdf."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; named author Jarrod Goodwin with local PDF and backtested results — author track record not required per R1."
r2_mechanical: PASS
r2_reasoning: "3-bar Low comparison (OHLC), fixed 0.5% filter (arithmetic), BUYSTOP/SELLSTOP placement, no-Friday guard — fully mechanical."
r3_data_available: PASS
r3_reasoning: "D1 DWX FX (USDJPY, EURUSD, GBPUSD); iHigh/iLow/iClose MT5-native bar indices — data available."
r4_ml_forbidden: PASS
r4_reasoning: "Pure OHLC price structure, fixed 0.5% filter, 1 pending order at a time cancelled EOD — no ML, no adaptive parameters."
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 25
g0_approval_reasoning: "R1 single source_id/source attribution; R2 mechanical 3-bar breakout with EOD exit and plausible ~25 trades/year/symbol; R3 testable on DWX FX D1; R4 deterministic ML-free 1-pos-compatible."
---

# QM5_11462 Goodwin-J — Kangaroo Tail 3-Bar Breakout (D1)

## Quelle
- Source: Jarrod Goodwin, "Beat the Markets Strategy Guidebook" (thetransparenttrader.com, ~2020)
- R1: CONDITIONAL — named author with backtested Multicharts results (2008-2020), not Wiley-published.

## Mechanik

**Concept**: The "Kangaroo Tail" pattern is a 3-bar formation where the middle bar has a Low lower than both the preceding and following bars (for a bullish setup). This is identical to the Williams Fractal concept but identified across D1 bars and traded immediately after Bar3 closes. Entry is via BUYSTOP above Bar3's High — only enter if price resumes upward after the tail. The trade is held intraday (same session) and exited EOD.

**Pattern**: Bar1 → Bar2 (tail = lowest Low of the three) → Bar3 closes. After Bar3 closes, we know Bar2 was the local minimum.

**Goodwin backtested results** (USD/JPY, 2008-2020): 2 losing years in 12+ years.

### Entry

**LONG (Kangaroo Tail Low):**
1. `Low[2] < Low[3]` AND `Low[2] < Low[1]` — bar[2] (the middle bar) has the lowest Low of the 3 bars
2. After bar[1] closes: place BUYSTOP at `High[1] + 1 pip` (bar3's High + 1 pip)
3. SL at `Low[1] - 1 pip` (bar3's Low)
4. Filter: `NOT (Close[1] > Close[2] AND (Close[1] - Close[2]) / Close[2] > 0.005)` — do not take if bar3 close is more than 0.5% above bar2 close
5. No Friday entries

**SHORT (Kangaroo Tail High):**
1. `High[2] > High[3]` AND `High[2] > High[1]` — bar[2] has the highest High
2. SELLSTOP at `Low[1] - 1 pip`; SL at `High[1] + 1 pip`
3. Filter: do not take if bar3 close is more than 0.5% below bar2 close
4. No Friday entries

**Order management**: Place order at open of bar[0] after bar[1] closes. Cancel if not filled by EOD.

### Exit
- **Time exit**: close at EOD (same session as fill — if filled, hold until 17:00 EST)
- Note: Goodwin tests as same-day exit; the BUYSTOP can fill at any point during the day

### Stop Loss
- At bar3's extreme (Low[1] for long, High[1] for short)
- P2 cap: 80 pips (if bar3 range > 80 pips, skip the setup)

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Primary instrument: USDJPY.DWX (Goodwin's primary), also EURUSD.DWX, GBPUSD.DWX
- Spread cap: 20 pips
- No Friday entry
- Skip if bar3 range (High[1]-Low[1]) > 80 pips

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Jarrod Goodwin, named author with Multicharts backtest results. |
| R2 Mechanical | PASS | 3-bar Low comparison: pure OHLC. Percentage filter: arithmetic. BUYSTOP/SELLSTOP placement mechanical. |
| R3 Data Available | PASS | D1 DWX FX. iHigh/iLow/iClose bar indices MT5-native. |
| R4 No ML | PASS | Pure price structure, 0.5% filter is fixed. |

G0 APPROVE eligible with CONDITIONAL R1 note.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Goodwin J., Beat the Markets (Strategy 2)

## Implementation Notes for Codex (P1)
- Kangaroo Low: `iLow(D1,2) < iLow(D1,3) && iLow(D1,2) < iLow(D1,1)`
- BUYSTOP: `iHigh(D1,1) + pip_offset`; SL = `iLow(D1,1) - pip_offset`
- 0.5% filter: `(iClose(D1,1) - iClose(D1,2)) / iClose(D1,2) * 100 < 0.5`
- Friday: `TimeDayOfWeek(iTime(D1,1)) != 5`
- EOD exit: at 17:00 EST (22:00 broker GMT+2) → close all positions
- Note: the pattern is essentially a `iFractals(PERIOD_D1, MODE_LOWER, 2)` (fractal at bar 2, confirmed after bar 1 closes)
- P3 sweeps: 0.5% filter (off/0.3/0.5/1.0%), EOD exit time (15:00/16:50/17:00 EST), bar-range cap (60/80/120 pips)

## Verwandte Strategien
- Related: QM5_11461 (goodwin-j-outside-bar-daily-reversion-d1) — same source; outside bar vs. 3-bar tail
- Related: QM5_11451 (vegas-wave-ema144ema169-fractal-h1) — also Williams Fractal based entry; H1 vs. D1; with/without channel filter

## Lessons Learned
- *(populated as pipeline progresses)*
