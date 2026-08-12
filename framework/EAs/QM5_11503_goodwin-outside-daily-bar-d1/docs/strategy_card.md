---
ea_id: QM5_11503
slug: goodwin-outside-daily-bar-d1
type: strategy
source_id: 2a126283-6905-5bb7-903a-cccd5f2b533f
sources:
  - "[[sources/goodwin-beat-the-markets-strategy-guidebook]]"
concepts:
  - "[[concepts/outside-bar-reversal]]"
  - "[[concepts/counter-trend-entry]]"
  - "[[concepts/daily-bar-pattern]]"
indicators:
  - "None (pure price action)"
period: D1
source_citation: "Jarrod Goodwin, 'Beat the Markets — Strategy Guidebook', self-published / The Transparent Trader, ~2014. R1 CONDITIONAL — named individual, self-published. References Larry Williams 1999."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present (Goodwin guidebook source record); R1 requires exactly one source, type is open — lineage traceable."
r2_mechanical: PASS
r2_reasoning: "D1 outside-bar OHLC arithmetic, close vs prior-bar extreme check, market-order entry at next open, fixed-pip SL/TP, and max-hold exit are all deterministic MT5 primitives."
r3_data_available: PASS
r3_reasoning: "D1 DWX FX symbols available; all logic uses iHigh/iLow/iClose which are MT5-native."
r4_ml_forbidden: PASS
r4_reasoning: "Pure OHLC comparisons; no ML, no adaptive refit, one position per magic."
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 30
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 PASS: single source_id and named guidebook attribution; R2 PASS: D1 outside-bar reversal entry plus fixed SL/TP/max-hold exit is mechanical with plausible ~30 trades/year/symbol; R3 PASS: DWX FX D1 testable; R4 PASS: deterministic OHLC rules, no ML or multi-position requirement."
---

# QM5_11503 Goodwin — Outside Daily Bar Reversal (D1)

## Quelle
- Source: Jarrod Goodwin, "Beat the Markets — Strategy Guidebook", self-published / The Transparent Trader (~2014). URL: local source record [[sources/goodwin-beat-the-markets-strategy-guidebook]].
- R1: CONDITIONAL — named author, self-published guidebook. Cites Larry Williams (World Cup champion) as inspiration for the Outside Bar concept.

## Mechanik

**Concept**: A daily Outside Bar (High > prior High AND Low < prior Low) that closes below the prior bar's Low signals bearish exhaustion paradoxically resolved to the upside — the full range engulf followed by a weak close suggests the aggressive sellers have been absorbed. Goodwin attributes this counter-intuitive signal to Larry Williams. Enter long on the next open.

**Logic**: The outside bar swallows the prior day's range. When it closes bearish and below the prior Low, it appears like a continuation down — but the market has absorbed all the selling pressure within a single session. The next open is a contrarian entry. Larry Williams (1999) documented this pattern; Goodwin applies it to Forex.

**Note**: This is a counter-trend/mean-reversion signal, NOT a trend-following entry. The stop is wide (200 pips) because D1 bars on Forex can have large swings.

### Entry

**LONG (Outside Bar with bearish close):**
1. **Outside Bar**: `iHigh(NULL,PERIOD_D1,1) > iHigh(NULL,PERIOD_D1,2)` AND `iLow(NULL,PERIOD_D1,1) < iLow(NULL,PERIOD_D1,2)` (today's range engulfs yesterday's)
2. **Bearish close below prior low**: `iClose(NULL,PERIOD_D1,1) < iLow(NULL,PERIOD_D1,2)` (close below prior bar's low)
3. Enter BUY at open of next bar (Market order)

**SHORT (Outside Bar with bullish close above prior high):**
1. **Outside Bar**: same range engulf
2. **Bullish close above prior high**: `iClose(NULL,PERIOD_D1,1) > iHigh(NULL,PERIOD_D1,2)` (close above prior bar's high)
3. Enter SELL at open of next bar

### Exit
- **TP**: Source unspecified. QM P2: `2 × SL distance` (2:1 R/R) = 400 pips. Alternative: close at next D1 bar open (intraday exit).
- **SL**: 200 pips fixed (source-specified for EUR/USD D1)
- **Max hold**: 5 D1 bars (QM-added fallback)
- P2 will test both fixed 2:1 TP and intraday/next-bar exit

### Stop Loss
- `SL_long = entry - 200 * pip_size`
- `SL_short = entry + 200 * pip_size`
- Source: 200 pips fixed for EUR/USD. P2 cap: 200 pips.

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX (source-specified), GBPUSD.DWX, AUDUSD.DWX (QM expansion)
- Spread cap: 30 pips
- No Friday entry

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Jarrod Goodwin, self-published guidebook. Cites Larry Williams (World Cup champion, R1 PASS) as pattern source — but Goodwin himself is the R1 author here. |
| R2 Mechanical | PASS | Pure OHLC arithmetic: iHigh/iLow/iClose comparisons on D1 bars. All MT5-native. No custom indicators. |
| R3 Data Available | PASS | D1 DWX FX. All MT5-native. |
| R4 No ML | PASS | Pure OHLC comparisons. No ML. |

G0 APPROVE eligible with CONDITIONAL R1 note. Counter-intuitive signal logic (bear close → long) makes this interesting from edge-research perspective. Wide SL (200 pips) may produce unfavorable R/R unless TP is set appropriately. P2 must test TP variants.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Jarrod Goodwin, "Beat the Markets — Strategy Guidebook", ~2014

## Implementation Notes for Codex (P1)
- `double h1 = iHigh(NULL,PERIOD_D1,1)`, `double l1 = iLow(NULL,PERIOD_D1,1)`, `double c1 = iClose(NULL,PERIOD_D1,1)`
- `double h2 = iHigh(NULL,PERIOD_D1,2)`, `double l2 = iLow(NULL,PERIOD_D1,2)`, `double c2 = iClose(NULL,PERIOD_D1,2)`
- Outside bar: `bool outside_bar = h1 > h2 && l1 < l2`
- LONG: `outside_bar && c1 < l2` — close below prior low
- SHORT: `outside_bar && c1 > h2` — close above prior high
- Market order at next open; SL: `200 * pip_size`; TP: `400 * pip_size` (2:1) or next-bar close
- P3 sweeps: TP (200/400/600 pips), require body engulf (o1 < c2 AND c1 > o2 for short), SMA200 trend filter on/off

## Verwandte Strategien
- Related: QM5_11504 (goodwin-kangaroo-tail-d1) — same source, 3-bar reversal on D1
- Related: QM5_11501 (langer-engulfing-d1-swing) — D1 candlestick pattern reversal

## Lessons Learned
- *(populated as pipeline progresses)*
