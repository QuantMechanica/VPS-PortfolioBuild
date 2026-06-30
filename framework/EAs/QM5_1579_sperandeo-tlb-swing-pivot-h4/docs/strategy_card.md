---
ea_id: QM5_1579
slug: sperandeo-tlb-swing-pivot-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/three-line-break-refined]]"
  - "[[concepts/2b-pivot-confirmation]]"
indicators:
  - "[[indicators/sperandeo-tlb-swing-pivot]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Sperandeo Trader Vic II (Wiley 1994, ISBN cited) and Nison Beyond Candlesticks (Wiley 1994, ISBN cited) accessed via FF TLB cluster."
r2_mechanical: PASS
r2_reasoning: "TLB line-construction, flip-detection, and 2B-fail qualifier are all deterministic bar-level OHLC comparators with fixed parameters."
r3_data_available: PASS
r3_reasoning: "OHLC H4 primitives are symbol-agnostic; portable to DWX FX majors, NDX.DWX, WS30.DWX, XAUUSD, XTIUSD."
r4_ml_forbidden: PASS
r4_reasoning: "N=3 TLB lines, 3-bar 2B window, and ATR multiplier are all fixed; no ML or equity-adaptive logic; bounded P3 sweep; one position per magic."
expected_trades_per_year_per_symbol: 6
pipeline_phase: G0
last_updated: 2026-05-19
card_body_incomplete: true
card_body_missing: "target_symbols,expected_trade_frequency"
g0_approval_reasoning: "R1 PASS Sperandeo/Nison books with ISBN plus FF attribution; R2 PASS deterministic TLB flip plus 2B confirmation entry and opposite/trailing exit, expected 6 trades/year/symbol; R3 PASS portable to DWX FX/index/XAU/oil; R4 PASS fixed params, no ML, 1 pos/magic."
---

# Sperandeo Three-Line-Break + Swing-Pivot Filter (H4)

## Quelle
- Source: [[sources/forexfactory-trading-systems]] — ForexFactory thread/142751 "Three-Line-Break + Sperandeo's 2B reversal" and the broader Sperandeo / TraderVic-following Renko-family cluster on FF Trading-Systems (TLB-variants thread/202518 and Sperandeo-2B thread cross-references).
- Page / Timestamp: Victor Sperandeo with Brown — *Trader Vic II — Principles of Professional Speculation* (Wiley 1994, ISBN 0-471-12275-1) ch. 10 "Method of Trading on the Trend" (specifically the 2B reversal pivot-rule on pp. 213-227) combined with Steve Nison — *Beyond Candlesticks* (Wiley 1994, ISBN 0-471-00720-9) ch. 6 pp. 207-215 (Three-Line-Break primitive). Cross-author: the FF-clustered card combines Sperandeo's 2B-pivot qualifier on top of the base TLB-flip mechanic. Primary-author prior-art: Steve Nison's TLB construction (Beyond Candlesticks) is the upstream base — see 1118 (base Renko card uses Renko-brick variant of the same swing-aggregation primitive). Distinct from 1118 (Renko-Street-V2 — base Renko-brick flip) by: TLB uses **bar-based** new-high / new-low aggregation (price-action over N closed bars) instead of fixed-brick-distance aggregation. The Sperandeo 2B-pivot overlay adds a **failed-breakout-confirmation** requirement on top of the TLB-flip — distinct primitive from Sperandeo 2B-Reversal sibling (1484) which fires on raw bar-level swing without the TLB-aggregation precondition.

## Mechanik

TLB construction (Nison 1994 ch. 6):
- Build TLB-line series from closed H4 bars: start with seed close-price line.
- On each new H4 close: if `Close > max(last_3_TLB_lines)` → append new up-line; if `Close < min(last_3_TLB_lines)` → append new down-line; otherwise no change (TLB is event-aggregated, not time-aggregated).
- **TLB-flip-down (bearish)**: a down-line appears after a streak of up-lines (the streak-break is the flip event).
- **TLB-flip-up (bullish)**: an up-line appears after a streak of down-lines.

Sperandeo 2B-pivot overlay (Sperandeo 1994 ch. 10):
- After a TLB-flip-down, a valid sell signal requires the **next H4 bar** to:
  - Make a new High that exceeds the last up-line's high, AND
  - Close back below the same up-line's high (the 2B failed-breakout).
- Mirror logic for TLB-flip-up + 2B failed-breakdown for buy signal.

This 2-stage gate (TLB-flip event + 2B confirmation bar) is the swing-pivot-filtered TLB primitive — the prior-art base TLB (Nison) fires on the flip alone; Sperandeo's overlay adds the 2B qualifier to suppress whipsaw flips that the H4-TLB stream alone produces.

### Entry
- Compute rolling TLB-line series over `Inp_TLB_Lines = 3` (Nison default) on H4 closes.
- Detect TLB-flip events: track current streak direction and length; flip event = direction-change.
- On flip-down event, wait for next H4 bar to satisfy 2B-fail: `High > last_up_line_high AND Close < last_up_line_high` → **enter short** at next bar open.
- On flip-up event, wait for next H4 bar to satisfy 2B-fail: `Low < last_down_line_low AND Close > last_down_line_low` → **enter long** at next bar open.
- If the 2B-fail does not occur within `Inp_2B_Window = 3` H4 bars of the flip, the signal is voided.
- One position per direction per magic; opposite-direction flip + 2B-fail closes existing before opening new.

### Exit
- Opposite TLB-flip-and-confirmation sequence → close at next bar open.
- Or trailing-stop: maintain SL at the most recent same-direction TLB-line + ATR-buffer; tighten as new TLB-lines accumulate.

### Stop Loss
- ATR-based initial: `SL = Entry - ATR(14, H4) * Inp_SL_ATR_Mult` (long), `+` for short.
- Default `Inp_SL_ATR_Mult = 2.2` (Sperandeo 1994 ch. 10 indicates the 2B-pivot stop should be just beyond the failed-breakout extreme; 2.0-2.5 ATR captures that on H4).
- Alternative hard stop at the 2B-bar's High (short) / Low (long) — whichever is closer to entry → use that.

### Position Sizing
- **P2 baseline**: `RISK_FIXED = $1000`.
- **T6-live**: `RISK_PERCENT = 0.5%`.

### Zusätzliche Filter
- Spread filter: skip if spread > 25 pts (FX) / 50 pts (CFD).
- News filter: ±15 min high-impact event suppression.
- Session: 24/5 FX, native session for indices, native for XAUUSD.
- Optional ADX gate: ADX(14, H4) > 16 — TLB is inherently a trend-reversal/continuation hybrid and underperforms in flat regimes; default-on the ADX filter to reduce flat-regime exposure.

### Target Symbols / Trade Frequency
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX.
- expected_trades_per_year_per_symbol: 6 — H4 TLB flips filtered by a three-bar 2B confirmation are sparse but plausibly above two annual entries per liquid symbol.

## Concepts (was ist das für eine Strategie)
- [[concepts/three-line-break-refined]] — primary (TLB-flip aggregation primitive)
- [[concepts/2b-pivot-confirmation]] — secondary (Sperandeo 2B-fail qualifier overlay)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Sperandeo *Trader Vic II* (Wiley 1994, ISBN cited) is canonical published reference. Nison *Beyond Candlesticks* (Wiley 1994, ISBN cited) is canonical for TLB. ForexFactory threads link to both. R1 PASS. |
| R2 Mechanical | UNKNOWN | TLB-line construction is closed-form aggregation; flip-detection is direction-change comparator; 2B-fail is bar-level High/Low/Close comparator. All deterministic. R2 PASS. |
| R3 Data Available | UNKNOWN | H4 swing-reversal/continuation applicable to FX majors, index CFDs, gold, oil. All in DWX. R3 PASS. |
| R4 ML Forbidden | UNKNOWN | TLB-lines parameter fixed; 2B-window fixed; ATR-multiplier fixed; no equity-adaptive logic; 1 pos per magic. R4 PASS. |

## Pipeline-Verlauf
- G0: PENDING.

## Verwandte Strategien
- [[strategies/QM5_1118_renko-street-v2-trend]] — sister Renko-family card; base Renko-brick flip primitive (vs TLB bar-based aggregation here)
- [[strategies/QM5_1484_sperandeo-2b-reversal-h4]] — sister 2B-pivot card; raw bar-level 2B without the TLB-aggregation precondition
- [[strategies/QM5_1313_heiken-ashi-smoothed-flip-h1]] — sister bar-aggregation family (HA-smoothed candle aggregation)
- [[strategies/QM5_1119_fps-toms-ma-rsi-h1]] — sister FF-Tom's-MA-RSI primitive (related FF-trading-systems cluster)

## Lessons Learned (während Pipeline-Lauf)
- (empty — added during P1-P9 pipeline runs)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
