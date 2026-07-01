---
ea_id: QM5_9450
slug: brooks-failed-spike-and-channel-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/failed-breakout]]"
  - "[[concepts/spike-and-channel]]"
indicators:
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; ForexFactory thread cluster plus Al Brooks Wiley 2012 book lineage provides clear single-source attribution."
r2_mechanical: PASS
r2_reasoning: "All three pattern stages reduce to deterministic closed-bar ATR/OHLC comparisons with explicit entry on next bar open, SL, measured-move TP, and time-stop."
r3_data_available: PASS
r3_reasoning: "Pattern is instrument-agnostic; directly testable on the DWX FX majors and index CFDs listed in target_symbols."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed coefficients and periods throughout; 1-position-per-magic enforced via magic formula; no ML, adaptive parameters, or martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 24
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 Brooks/FF source attribution present; R2 staged ATR/OHLC entry, SL, TP, time-stop mechanical with ~24 trades/year/symbol; R3 FX/CFD DWX symbols testable; R4 fixed non-ML single-position."
---

# Brooks Failed Spike-and-Channel Reversal (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14001500 (ForexFactory
  Trading Systems sub-forum, Al Brooks price-action thread cluster,
  Spike-and-Channel failure sub-thread, posts circa 2017–2025).
- Author lineage: Al Brooks — *Trading Price Action: Trends* (Wiley 2012)
  ch. 3 "Spike and Channel" pp. 81–124 (canonical S&C definition);
  *Trading Price Action: Trading Ranges* (Wiley 2012) ch. 24 "Failed
  Breakouts"; brookstradingcourse.com Encyclopedia entry
  "Spike-and-Channel Failure".
- Distinctness sibling cards (see Verwandte Strategien): QM5_9400
  (Failed-OO), QM5_9280 (Failed-Triangle), QM5_9350 (Failed-TTR),
  QM5_2354 (Failed-Final-Flag), QM5_2461 (Failed-Wedge). This card's
  Stage-1 is the spike-bar + channel sequence, structurally distinct
  from outside-bar pairs, triangle convergence, range compression,
  final-flag, and wedge.

## Mechanik

### Pattern Stages (mechanical recognition on closed H4 bars)

**Stage 1 — Spike-and-Channel formation:**

1. Compute ATR(14) on closed H4 bars.
2. A "spike bar" at index `s` requires:
   - `(High[s] − Low[s]) ≥ 2.0 × ATR(14)[s-1]` (wide range), AND
   - `|Close[s] − Open[s]| ≥ 0.70 × (High[s] − Low[s])` (strong body),
     AND
   - bar is a single H4 closed bar (no multi-bar aggregation).
   - Spike direction = sign(Close[s] − Open[s]).
3. A "channel" requires the next 4–10 closed bars after `s` to satisfy:
   - For an UP-spike: every closed bar `i ∈ [s+1, s+k]` has
     `Low[i] ≥ Open[s]` (no bar breaks back below spike start), AND
   - `max(Close) − min(Close)` over the channel window ≤
     `0.7 × (High[s] − Low[s])` (channel range smaller than spike).
   - Mirror conditions for DOWN-spike.
4. Channel locks at the close of bar `s+k` where `k ∈ [4, 10]` and the
   next bar violates either channel rule (channel-end). Define:
   - `channel_start = Open[s]` (spike origin),
   - `channel_extreme = max(High[s..s+k])` for UP-spike,
     `min(Low[s..s+k])` for DOWN-spike,
   - `S_C_anchor_bar = s+k`.

**Stage 2 — Counter-trend breakout (the failure setup):**

1. Within the next 10 closed H4 bars after `S_C_anchor_bar`:
2. For an UP-S&C, a closed H4 bar prints
   `close < channel_start − 0.3·ATR(14)` (price breaks back through
   spike origin opposite trend). Mark `breakout_bar`, mark
   `breakout_extreme = min(Low)` since `S_C_anchor_bar`.
3. Mirror for DOWN-S&C.

**Stage 3 — Failure trigger (entry signal):**

1. Within 6 closed H4 bars after `breakout_bar`:
2. For an UP-S&C-failed-breakout-down (long-reversal), a closed H4 bar
   prints:
   - `close > channel_start` (return inside the S&C zone), AND
   - `close > open` (green bar), AND
   - `high ≥ channel_start + 0.4·ATR(14)` (genuine penetration).
3. Mirror for DOWN-S&C (short-reversal).
4. On the close of that bar, the failure is confirmed.

### Entry

On the next H4 bar open after Stage-3 confirmation:

- UP-S&C-failure → market BUY (reversal trade rejoining original trend).
- DOWN-S&C-failure → market SELL.

Magic = `9450 * 10000 + slot` (1-position-per-magic, HR4).

### Exit

**Profit target (mechanical, measured-move from S&C extreme):**

- For BUY: `TP = channel_extreme + 0.8·ATR(14)` (target = original
  channel extreme plus momentum extension).
- For SELL: `TP = channel_extreme − 0.8·ATR(14)`.

**Time stop:** if neither SL nor TP hit within 20 closed H4 bars after
entry, exit at market on bar 21's close.

### Stop Loss

- For BUY: `SL = min(entry, breakout_extreme) − 0.3·ATR(14)` (just
  beyond the failed counter-breakout extreme).
- For SELL: `SL = max(entry, breakout_extreme) + 0.3·ATR(14)`.

ATR snapshot at entry, fixed for the trade.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD (HR4).
- Live: `RISK_PERCENT = 0.5%` of equity at entry (HR4).

### Zusätzliche Filter

- Spread filter: skip if current spread > `0.20·ATR(14)`.
- Time filter: H4 bars only; no intra-bar entries; no entries during the
  weekly gap (Friday close → Sunday open). Spike bars straddling the
  weekly gap are rejected (gap bars do not count as legitimate spikes).
- News filter (P1 baseline): skip entry if the news_calendar shows a
  HIGH-impact event for any quote currency of the symbol within ±60
  minutes of the entry-bar open.
- One S&C → at most one entry signal. If price re-breaks
  `breakout_extreme` before Stage-3 fires, the S&C is invalidated.

## Concepts (was ist das für eine Strategie)

- [[concepts/failed-breakout]] — primary
- [[concepts/spike-and-channel]] — secondary (Stage-1 primitive)
- [[concepts/trend-continuation]] — tertiary (failure rejoins the
  original spike direction)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Al Brooks: 30+ year price-action lineage. Primary publication Wiley 2012 (Trends + Trading Ranges). brookstradingcourse.com Encyclopedia chapter on Spike-and-Channel and its failure mode. ForexFactory thread cluster ongoing. R1 PASS expected under 2026-05-15 relaxed criteria. |
| R2 Mechanical | UNKNOWN | All three stages reduce to closed-bar comparisons on ATR + close/open/high/low primitives. Channel detection is a deterministic 4–10 bar window with explicit termination. No look-ahead. Entry/SL/TP/time-stop all closed-form. R2 PASS expected. |
| R3 Data Available | UNKNOWN | Brooks describes Spike-and-Channel as instrument-agnostic and present in all liquid markets. Testable on all FX-majors, XAUUSD, XTIUSD, and Darwinex index CFDs (GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX) on H4. SP500.DWX backtest-only — T_Live promotion requires NDX.DWX or WS30.DWX parallel validation (Board Advisor T_Live-gate enforcement). R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed periods (14, 4–10 channel window, 10/6 lookforward, 20 time-stop). Fixed coefficients (2.0, 0.70, 0.7, 0.3, 0.4, 0.8). No adaptive parameters, no ML, no neural net, no online learning. 1-position-per-magic. No martingale. R4 PASS expected. |

### R3 SP500.DWX live-promotion caveat

Live promotion T_Live gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T_Live deploy requires a
parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
This is Board Advisor's T_Live-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 58.

## Verwandte Strategien

- [[strategies/QM5_9400_brooks-failed-outside-outside-h4]] — Brooks
  failed-pattern family, Stage-1 is consecutive outside-bar pair.
- [[strategies/QM5_9280_brooks-failed-triangle-h4]] — Brooks
  failed-pattern family, Stage-1 is triangle convergence.
- [[strategies/QM5_9350_brooks-failed-ttr-h4]] — Brooks failed-pattern
  family, Stage-1 is TTR (range compression).
- [[strategies/QM5_2354_brooks-failed-final-flag-h4]] — Brooks
  failed-pattern family, Stage-1 is final-flag.
- [[strategies/QM5_2461_brooks-failed-wedge-h4]] — Brooks failed-pattern
  family, Stage-1 is wedge.

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must compare Stage-1 (spike-bar +
  channel sequence) against 9400/9280/9350/2354/2461 — distinctness
  rests on the Spike-and-Channel Stage-1 primitive. Stage-2/3 logic
  mirrors the family.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
