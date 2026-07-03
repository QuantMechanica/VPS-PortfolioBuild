---
ea_id: QM5_9503
slug: williams-ocr-extension-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/wide-range-body-bar]]"
  - "[[concepts/breakout-extension-confirmation]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; ForexFactory thread plus Larry Williams 'Long-Term Secrets to Short-Term Trading' (Wiley 1999, ISBN 0-471-29722-4) provide adequate lineage."
r2_mechanical: PASS
r2_reasoning: "OCR ratio, ATR range filter, SMA(50) trend gate, next-bar extension confirmation, and all entry/SL/TP/time-stop rules are closed-form on completed H4 bars with no discretion."
r3_data_available: PASS
r3_reasoning: "Price-only bar-shape primitive testable on all DWX FX pairs, XAUUSD, XTIUSD, and index CFDs at H4; SP500.DWX live-promotion caveat noted in card."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed thresholds (0.85, 1.5, 0.10, 0.3, 1.5) and periods (14, 50); 1-position-per-magic (9503×10000+slot); no ML, adaptive PnL parameters, or martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 22
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 PASS source URL plus Williams book attribution; R2 PASS deterministic H4 OCR extension entry/SL/TP/time-exit with ~22 trades/year/symbol; R3 PASS price-only rules portable to DWX FX/metals/oil/indices with SP500.DWX T6 caveat; R4 PASS fixed-parameter non-ML 1-position-per-magic no martingale."
---

# Williams Open-Close-Range (OCR) Extension-Confirmation Variant (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14002500 (ForexFactory
  Trading Systems sub-forum, Larry Williams thread cluster, OCR
  extension-confirmation sub-thread, posts circa 2017–2025).
- Author lineage: Larry Williams — *Long-Term Secrets to Short-Term
  Trading* (Wiley 1999, ISBN 0-471-29722-4) ch. 4 "Why Most Traders
  Lose Most of the Time" pp. 51–72 + ch. 9 "Big Trades" pp. 145–168 +
  ch. 14 "Confirmation Patterns" pp. 251–272 — the
  extension-confirmation rule appears in ch. 14 as Williams' framework
  for sifting "real" continuation moves from "blow-off" single-bar
  spikes: "wait for the next bar to take out the OCR-bar's high or
  low before entering — the failure of the next bar to extend is the
  signal that the OCR was an exhaustion, not a continuation".
  Williams' trading-camp lecture notes (2003–2010) reproduce the rule.
- Distinctness sibling cards (see Verwandte Strategien):
  - QM5_9452 williams-ocr-h4 — base OCR continuation, entry at the next
    H4 bar's open (no extension confirmation required).
  - QM5_9402 williams-big-trade-h4 — multi-bar key-reversal primitive.
  - QM5_9403 williams-pro-go-h4 — cumulative Pro/Go composite.
  - QM5_9454 williams-pro-go-go-trigger-h4 — Pro-Go with Go as trigger.
  - QM5_2298 williams-smash-day-h4 — multi-bar reversal primitive.
  - This card uses the same OCR primitive as 9452 but adds a
    **next-bar extension-confirmation requirement**: the bar after
    the OCR-bar must trade through the OCR-bar's extreme before
    entering. The structural difference (deferred entry conditional
    on bar-`t+1` follow-through) makes this card a distinct
    primitive — 9452's no-confirmation variant pays the trader who's
    right early but exposes them to exhaustion blow-offs; 9503's
    extension variant trades fewer/later but at the cost of skipping
    some clean follow-throughs. Comparative P2 evidence between 9452
    and 9503 quantifies the value of Williams ch. 14's extension rule.

## Mechanik

### OCR primitive (Williams 1999 ch. 4 + ch. 9)

For each closed H4 bar `t`, define:

```
body[t]      = |Close[t] − Open[t]|
range[t]     = High[t] − Low[t]
OCR_ratio[t] = body[t] / max(range[t], 1e-9)
dir[t]       = sign(Close[t] − Open[t])
```

Compute `ATR(14)` and `SMA(50)` of close on closed H4 bars.

### Entry (continuation in OCR direction, conditional on next-bar extension)

Long trigger (mirror for short):

**Stage 1 — OCR-bar identification at index `t` (same as 9452 base):**

1. `OCR_ratio[t] ≥ 0.85` (body ≥ 85 % of full range), AND
2. `range[t] ≥ 1.5·ATR(14)[t − 1]`, AND
3. `Close[t] > Open[t]` (bullish body), AND
4. **Trend alignment:** `Close[t] > SMA(50)[t]`, AND
5. **No conflicting OCR at t − 1:** NOT
   (`OCR_ratio[t − 1] ≥ 0.85` AND `dir[t − 1] = −1`).

Mark `OCR_extreme = High[t]` (for long; mirror `Low[t]` for short).
Mark the OCR-bar but do NOT enter yet.

**Stage 2 — Extension confirmation at the next closed H4 bar `t + 1`:**

The OCR-bar's signal must be confirmed by bar `t + 1` extending
through the OCR-bar's extreme:

6. **Extension trigger:** `High[t + 1] > OCR_extreme + 0.10·ATR(14)[t]`
   (bar `t + 1` prints a new high beyond OCR-bar's high plus a small
   ATR buffer that suppresses tick-spread false-extensions).
7. **Extension closes positive:** `Close[t + 1] > Close[t]` (the
   extension bar does not collapse back below the OCR-bar's close —
   eliminates the "bullish-OCR followed by a bearish reversal that
   spiked the OCR-high only to close back below" exhaustion pattern).
8. **Extension is timely:** stage 2 must fire on bar `t + 1`
   exactly — not bar `t + 2` or later. If bar `t + 1` fails to
   extend, the OCR-bar's signal is discarded permanently. (This is
   Williams' "decisive follow-through" rule, ch. 14 p. 258.)

Entry on the **bar `t + 2` open** at market.

Short trigger: mirror with `Close[t] < Open[t]`, `Close[t] < SMA(50)[t]`,
`Low[t + 1] < OCR_extreme − 0.10·ATR(14)[t]`, `Close[t + 1] < Close[t]`.

Magic = `9503 × 10000 + slot` (1-position-per-magic, HR4).

### Exit

**Profit target (mechanical, range-extension):**

- Long: `TP = Close[t + 1] + 1.5·(range[t])` (target = 1.5× the
  OCR-bar's range projected from the extension-bar's close).
- Short: `TP = Close[t + 1] − 1.5·(range[t])`.

The 1.5× projection follows Williams' "1.5× the breakout-bar range" rule
(ch. 14 p. 263).

**Time stop:** if neither SL nor TP hit within 12 closed H4 bars after
entry, exit at market on bar 13's close.

### Stop Loss

- Long:  `SL = Low[t] − 0.3·ATR(14, entry-bar)`. The OCR-bar's low is
  the structural stop — if price violates the OCR-bar low, the
  continuation pattern is invalidated.
- Short: `SL = High[t] + 0.3·ATR(14, entry-bar)`.

ATR snapshot at entry; stop fixed for the trade.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD (HR4).
- Live: `RISK_PERCENT = 0.5%` of equity at entry (HR4).

### Zusätzliche Filter

- Spread filter: skip if current spread > `0.20·ATR(14)`.
- Time filter: H4 bars only; no intra-bar entries; no entries during
  the weekly gap.
- News filter (P1 baseline): skip entry if news_calendar shows a
  HIGH-impact event for any quote currency of the symbol within ±60
  minutes of the entry-bar open.
- One entry per OCR-bar `t`: once stage 2 fails or fires, the OCR-bar
  is consumed and cannot trigger again.

## Concepts (was ist das für eine Strategie)

- [[concepts/wide-range-body-bar]] — primary (OCR ratio ≥ 0.85 + range
  ≥ 1.5×ATR identifies wide-body conviction bar)
- [[concepts/breakout-extension-confirmation]] — secondary (deferred
  entry conditional on next-bar follow-through through OCR extreme)
- [[concepts/trend-following]] — tertiary (SMA(50) bias)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Larry Williams — *Long-Term Secrets to Short-Term Trading* (Wiley 1999) ch. 4 / 9 / 14. World Cup Trading Championships winner 1987. Williams' trading-camp lecture notes 2003–2010 corroborate the extension-confirmation rule. ForexFactory thread cluster ongoing. R1 PASS expected. |
| R2 Mechanical | UNKNOWN | All values closed-form on closed H4 bars. OCR identification + extension confirmation + entry / SL / TP / time-stop fully deterministic. No look-ahead. R2 PASS expected. |
| R3 Data Available | UNKNOWN | Bar-shape primitive — price-only. Testable on all FX-majors, XAUUSD, XTIUSD, and Darwinex index CFDs on H4. SP500.DWX backtest-only — T_Live promotion requires NDX.DWX or WS30.DWX parallel validation (Board Advisor T_Live-gate enforcement). R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed thresholds (0.85, 1.5, 0.10, 0.3, 1.5, 12, 0.20), fixed periods (14, 50). No adaptive parameters, no ML, no neural net, no online learning. 1-position-per-magic. No martingale. R4 PASS expected. |

### R3 SP500.DWX live-promotion caveat

Live promotion T_Live gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T_Live deploy requires a
parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
This is Board Advisor's T_Live-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 59.

## Verwandte Strategien

- [[strategies/QM5_9452_williams-ocr-h4]] — base OCR continuation, no
  extension confirmation. Distinct: 9503 adds a mandatory next-bar
  follow-through filter and delays entry by one bar.
- [[strategies/QM5_9402_williams-big-trade-h4]] — multi-bar key-reversal
  primitive (different geometry).
- [[strategies/QM5_9403_williams-pro-go-h4]] — cumulative Pro/Go
  composite (different primitive class).
- [[strategies/QM5_9454_williams-pro-go-go-trigger-h4]] — Pro-Go with
  Go as trigger.
- [[strategies/QM5_2298_williams-smash-day-h4]] — Smash-Day multi-bar
  reversal.
- [[strategies/QM5_2352_williams-3day-failure-h4]] — 3-Day-Failure
  multi-bar reversal.

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must verify that the
  extension-confirmation requirement changes the trade list
  meaningfully vs. 9452. Williams 1999 ch. 14 p. 258 argues "30–40% of
  OCR-bars fail to extend on bar `t+1` — those failures are exactly
  the exhaustion blow-offs you want to avoid". If P2 shows 9503's
  trade list is ~60% of 9452's with materially higher win-rate, the
  extension rule is validated; if it's ~95% of 9452's with similar
  win-rate, the extension filter is too lax.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
