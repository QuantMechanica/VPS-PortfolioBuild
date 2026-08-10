---
ea_id: QM5_11447
slug: burke-parabolic-short-squeeze-m5
type: strategy
source_id: 04305b6c-b4ce-522b-87b5-71708b6b8327
sources:
  - "[[sources/burke-stacey-playbook]]"
concepts:
  - "[[concepts/false-breakdown]]"
  - "[[concepts/short-squeeze]]"
  - "[[concepts/multi-day-pattern]]"
  - "[[concepts/ema-close-back]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/ema]]"
period: M5
source_citation: "Stacey Burke, The Stacey Burke Trading Playbook (online/self-published). R1 CONDITIONAL — named individual, no verifiable major-publisher credentials."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; Stacey Burke self-published Playbook is a valid attribution under updated R1 criteria.
r2_mechanical: PASS
r2_reasoning: Three consecutive lower closes, reversal-bar close direction check, and M5 EMA20 cross are pure OHLC comparisons and fully deterministic.
r3_data_available: PASS
r3_reasoning: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX on M5/D1 are DWX instruments with adequate history.
r4_ml_forbidden: PASS
r4_reasoning: Fixed EMA(20), fixed bar count (3), single position per squeeze event — no ML or adaptive parameters.
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 20
g0_approval_reasoning: "R1 PASS one source_id; R2 PASS mechanical 3-day false-break reversal plus M5 EMA entry/exit/SL with plausible ~20/yr cadence; R3 PASS DWX FX M5/D1; R4 PASS deterministic no ML."
---

# QM5_11447 Burke — Parabolic Short Squeeze → M5 EMA20 (M5+D1)

## Quelle
- Source: Stacey Burke, Tradesmint.com, 2022, URL/local PDF: `707586131-1-Stacey-Burke-Best-Trade-Setups-Playbook-Notes-Part-2.pdf` (Part 2, pages 51-106).
- R1: CONDITIONAL — named individual author, self-published.

## Mechanik

**Concept**: After three consecutive D1 lower closes (a short-term downtrend), Day 3 exhibits a false breakdown — the Low is below the prior day's Low, but the bar closes bullish (Close > Open). This "reversal bar" traps late shorts. Price then creeps back toward the prior swing high (the area from which the 3-day decline originated). When on M5 during the trade day, price closes above EMA20 after this creep back, a LONG is entered to capture the short-squeeze continuation.

**Pattern name**: "Parabolic" because the 3-day decline often has a parabolic acceleration on Day 3 before the reversal. "Short squeeze" because trapped shorts who entered on the false breakdown are forced to cover.

**News caveat**: Burke requires "no major red news." Not mechanically implementable in MT5.

### D1 Pattern Detection

**Short Squeeze Setup (Long):**
1. `Close[D1,3] < Close[D1,4]` — 3 bars ago was lower close
2. `Close[D1,2] < Close[D1,3]` — 2 bars ago was lower close
3. `Close[D1,1] < Close[D1,2]` — 1 bar ago was lower close (3 consecutive lower closes)
4. `Low[D1,1] < Low[D1,2]` — Day 3 made a new recent low (false breakdown)
5. `Close[D1,1] > Open[D1,1]` — Day 3 bar closed BULLISH (key reversal)
6. The prior swing high (approximate: `High[D1,3]` or max of prior bars) becomes the target zone

**Mirror — Short (3 higher closes → false breakout → bearish):**
- 3 consecutive higher closes + Day 3 High above prior high + Day 3 close bearish

### M5 Entry

**LONG (short squeeze):**
1. Squeeze setup confirmed at trade day open
2. Session window: London or NY
3. `Close[M5,0] > EMA20[M5,0] AND Close[M5,1] <= EMA20[M5,1]` — bar closes above EMA20 (first cross above)
4. Enter BUY at close of M5 bar

### Exit
- **TP**: entry + 50 pips (minimum); if prior swing high > entry + 50 → extend to prior swing high
- **Extended TP**: up to entry + 250 pips on strong squeeze days
- Burke range: 50-250 pips depending on session momentum

### Stop Loss
- LONG: entry - 20 pips
- P2 cap: 25 pips

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: M5 (entry), D1 (pattern)
- Session window: London + NY
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 15 pips

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Stacey Burke, named author, self-published. |
| R2 Mechanical | PASS | 3-bar consecutive close check + reversal bar close direction: pure OHLC. M5 EMA20: MT5-native. |
| R3 Data Available | PASS | M5/D1 DWX FX. |
| R4 No ML | PASS | Fixed EMA(20), fixed bar count (3). |

G0 APPROVE eligible with CONDITIONAL R1 note. **Known limitation**: news filter not implementable.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Burke Playbook (Parabolic Short Squeeze)

## Implementation Notes for Codex (P1)
- 3 lower closes: `iClose(D1,1)<iClose(D1,2) && iClose(D1,2)<iClose(D1,3) && iClose(D1,3)<iClose(D1,4)`
- False breakdown + reversal: `iLow(D1,1)<iLow(D1,2) && iClose(D1,1)>iOpen(D1,1)`
- Store bool `squeeze_active` at new D1 bar
- M5 EMA20: EMA20[0] vs EMA20[1] cross from below
- EMA cross: `iClose(M5,0)>ema20_cur && iClose(M5,1)<=ema20_prev`
- P3 sweeps: consecutive bar count (2/3/4), EMA (13/20/34), TP (50/100/200 pips), SL (15/20/25 pips)

## Verwandte Strategien
- Related: QM5_11443 (burke-day3-breakout-trap-m5) — same consecutive-bar pattern but bearish trap; Parabolic uses reversal-bar confirmation
- Related: QM5_11442 (burke-frd-fgd-daily-pump-m5) — both use false break + reversal bar; Pump uses explicit pump day, Parabolic uses 3-bar extension

## Lessons Learned
- *(populated as pipeline progresses)*
