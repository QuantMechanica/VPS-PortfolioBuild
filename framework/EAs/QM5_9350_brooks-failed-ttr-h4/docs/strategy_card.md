---
ea_id: QM5_9350
slug: brooks-failed-ttr-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/failed-breakout]]"
  - "[[concepts/tight-trading-range]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/donchian]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id 6e967762 present, attributing to the ForexFactory Brooks thread cluster with Al Brooks primary publications as named author lineage."
r2_mechanical: PASS
r2_reasoning: "All three stages (TTR formation, breakout bar, failure trigger) reduce to closed-bar Donchian/ATR/OHLC comparisons; entry, SL, TP, and time-stop are all closed-form."
r3_data_available: PASS
r3_reasoning: "Donchian channel and ATR computed from OHLC data, portable to all DWX FX majors, XAUUSD, and index CFDs."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed periods (20, 14, 8, 30) and fixed thresholds throughout; no ML, adaptive equity-dependent parameters, or unbounded multi-position logic; one-position-per-magic enforced."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS source URL/Brooks attribution; R2 PASS deterministic H4 TTR failed-breakout entry/SL/TP/time exit with ~30 trades/year/symbol; R3 PASS portable to DWX FX/indices; R4 PASS fixed params no ML/martingale 1-position-per-magic."
---

# Brooks Failed Tight-Trading-Range Reversal (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14000000 (ForexFactory
  Trading Systems sub-forum, Al Brooks price-action thread cluster, ongoing
  2014-2026).
- Author lineage: Al Brooks — *Reading Price Charts Bar by Bar* (Wiley 2009),
  *Trading Price Action: Trends / Trading Ranges / Reversals* (Wiley 2012),
  brookstradingcourse.com Encyclopedia chapter "Failed Breakouts from Tight
  Trading Ranges".
- Reference card: this is a recursive variant of QM5_9280
  `brooks-failed-triangle-h4` and QM5_9284
  `brooks-tight-trading-range-h4` (Stage-1 TTR formation reused).

## Mechanik

### Pattern Stages (mechanical recognition on closed H4 bars)

**Stage 1 — TTR formation** (identical to 9284):

1. Compute rolling Donchian channel `DC(N=20)` on closed H4 bars.
2. Compute ATR(14) on closed H4 bars.
3. TTR triggers when, over the last 20 closed H4 bars:
   - `DC_high(20) − DC_low(20) ≤ 1.5 × ATR(14)` (range compression), AND
   - At least 14 of the last 20 bar bodies are ≤ 0.4 × ATR(14) (small
     bodies = balance), AND
   - The bar-by-bar high/low envelope stays within
     `[DC_low(20) − 0.1·ATR, DC_high(20) + 0.1·ATR]` (no clean break attempt).
4. The TTR is locked: record `TTR_high = DC_high(20)`, `TTR_low = DC_low(20)`,
   `TTR_anchor_bar = current bar index`.

**Stage 2 — Initial breakout (the failure setup):**

1. Within the next 20 H4 bars after TTR lock:
2. A closed H4 bar prints `close > TTR_high + 0.2·ATR(14)` (UP-breakout) OR
   `close < TTR_low − 0.2·ATR(14)` (DOWN-breakout). Mark side, mark
   `breakout_bar`, mark `breakout_extreme` (highest high since
   `TTR_anchor_bar` for UP, lowest low for DOWN).

**Stage 3 — Failure trigger (entry signal):**

1. Within 8 closed H4 bars after `breakout_bar` (Brooks: "two to ten bars
   typical"):
2. A closed H4 bar prints, for an UP-breakout-failure:
   - `close < TTR_high` (return inside the range), AND
   - `close < open` (red bar), AND
   - `low ≤ TTR_high − 0.5·ATR(14)` (genuine penetration back inside).
3. Mirror for a DOWN-breakout-failure
   (`close > TTR_low`, `close > open`, `high ≥ TTR_low + 0.5·ATR(14)`).
4. On the close of that bar, the failure is confirmed.

### Entry

On the next H4 bar open after Stage-3 confirmation:

- UP-failure → market SELL.
- DOWN-failure → market BUY.

Magic = `9350 * 10000 + slot` (1-position-per-magic, HR4).

### Exit

**Profit target (mechanical):**

- For SELL: `TP = TTR_low − 1.0·ATR(14)` (target = opposite end of the TTR plus
  one ATR of momentum-extension, the "measured move" Brooks describes).
- For BUY:  `TP = TTR_high + 1.0·ATR(14)`.

**Time stop:** if neither SL nor TP hit within 30 closed H4 bars after entry,
exit at market on bar 31's close.

### Stop Loss

- For SELL: `SL = max(entry, breakout_extreme) + 0.3·ATR(14)` (just beyond the
  failed-breakout extreme).
- For BUY:  `SL = min(entry, breakout_extreme) − 0.3·ATR(14)`.

ATR snapshot at entry, fixed for the trade.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD (HR4).
- Live: `RISK_PERCENT = 0.5%` of equity at entry (HR4).

### Zusätzliche Filter

- Spread filter: skip if current spread > `0.20·ATR(14)`.
- Time filter: H4 bars only; no intra-bar entries; no entries during the
  weekly gap (Friday close → Sunday open).
- News filter (P1 baseline): skip entry if the news_calendar shows a
  HIGH-impact event for any quote currency of the symbol within ±60 minutes
  of the entry-bar open.
- One TTR → at most one entry signal. If Stage-3 fails (price re-breaks
  through `breakout_extreme` before Stage-3 trigger fires), the TTR is
  invalidated; no entry, restart the TTR search.

## Concepts (was ist das für eine Strategie)

- [[concepts/failed-breakout]] — primary
- [[concepts/tight-trading-range]] — secondary
- [[concepts/mean-reversion]] — tertiary (failure reverses back through the
  range, with measured-move extension)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Al Brooks: 30+ year price-action lineage. Primary publications Wiley 2009/2012. Active brookstradingcourse.com Encyclopedia chapter. ForexFactory thread cluster ongoing 2014-2026. Multi-source attributed. R1 PASS expected under 2026-05-15 relaxed criteria. |
| R2 Mechanical | UNKNOWN | All three stages reduce to closed-bar comparisons on Donchian + ATR + close/open/high/low primitives. Stage gating prevents look-ahead. Entry/SL/TP/time-stop all closed-form. R2 PASS expected. |
| R3 Data Available | UNKNOWN | Brooks describes the pattern as instrument-agnostic. Testable on all FX-majors (EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF, NZDUSD), XAUUSD, XTIUSD, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX H4. SP500.DWX backtest-only — T6 live promotion requires NDX.DWX or WS30.DWX parallel validation (Board Advisor T6-gate enforcement). R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed periods (20, 14, 8, 30), fixed thresholds (1.5, 0.4, 0.1, 0.2, 0.5, 1.0, 0.3, 0.20). No adaptive parameters, no ML, no neural net, no online learning. 1-position-per-magic. No martingale. R4 PASS expected. |

### R3 SP500.DWX live-promotion caveat

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation
on NDX.DWX or WS30.DWX before AutoTrading enable. This is Board Advisor's
T6-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 56.

## Verwandte Strategien

- [[strategies/QM5_9280_brooks-failed-triangle-h4]] — Stage-1 pattern
  family; this card targets the TTR variant where Stage-1 is
  range-compression rather than triangle convergence.
- [[strategies/QM5_9284_brooks-tight-trading-range-h4]] — uses the same
  Stage-1 TTR formation; that card trades the *successful* breakout
  continuation; this card trades the *failed* breakout reversal.
- [[strategies/QM5_2354_brooks-failed-final-flag-h4]] — sibling
  Brooks-failed-pattern card with different Stage-1 (final flag, not TTR).
- [[strategies/QM5_2461_brooks-failed-wedge-h4]] — sibling
  Brooks-failed-pattern card with wedge Stage-1.
- [[strategies/QM5_1396_brooks-tight-micro-channel-trend-h1]] — same Brooks
  lineage, lower timeframe, different mechanic (channel-trend not
  failed-breakout).

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must compare Stage-3 trigger rule against
  9280 (Failed-Triangle) and 9284 (TTR continuation) on H4 DWX data — both
  share Stage-1 with this card, distinctness rests on Stage-2 and Stage-3.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
