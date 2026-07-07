---
ea_id: QM5_9504
slug: brooks-failed-channel-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/failed-breakout]]"
  - "[[concepts/tight-channel-reversal]]"
indicators:
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; ForexFactory thread plus Al Brooks 'Trading Price Action: Trends/Trading Ranges' (Wiley 2012) and brookstradingcourse.com provide adequate lineage."
r2_mechanical: PASS
r2_reasoning: "All three stages (pure-channel formation, reversal break, failure trigger) reduce to closed-form ATR, OHLC, and bar-count comparisons on completed H4 bars with no discretion."
r3_data_available: PASS
r3_reasoning: "Price-only primitive testable on all DWX FX majors, XAUUSD, XTIUSD, and index CFDs at H4; SP500.DWX live-promotion caveat noted in card."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed window ranges (6,14,12,8,24) and thresholds throughout; 1-position-per-magic (9504×10000+slot); no ML, adaptive PnL parameters, or martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 24
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 PASS cited ForexFactory URL plus Brooks books/course; R2 PASS deterministic H4 OHLC/ATR entry, SL, TP, time exit with ~24 trades/year/symbol; R3 PASS price-only portable to DWX FX/CFD symbols with SP500 caveat; R4 PASS fixed rules, no ML/adaptive/grid/martingale, 1-position-per-magic."
---

# Brooks Failed Pure-Channel Reversal (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14002600 (ForexFactory
  Trading Systems sub-forum, Al Brooks price-action thread cluster,
  Pure-Channel failure sub-thread, posts circa 2018–2025).
- Author lineage: Al Brooks — *Trading Price Action: Trends* (Wiley 2012)
  ch. 4 "Channels" pp. 125–168 (channel without preceding spike —
  pure-trend-channel definition, distinct from Spike-and-Channel ch. 3);
  *Trading Price Action: Trading Ranges* (Wiley 2012) ch. 24 "Failed
  Breakouts" + ch. 25 "Channel Failure";
  brookstradingcourse.com Encyclopedia entry "Channel Failure".
- Distinctness sibling cards (see Verwandte Strategien):
  - QM5_9450 brooks-failed-spike-and-channel-h4 — Failed S&C, Stage-1
    requires a wide spike-bar precursor + channel.
  - QM5_9400 brooks-failed-outside-outside-h4 — Stage-1 = OO bar pair.
  - QM5_9280 brooks-failed-triangle-h4 — Stage-1 = triangle.
  - QM5_9350 brooks-failed-ttr-h4 — Stage-1 = tight-trading-range.
  - QM5_2354 brooks-failed-final-flag-h4 — Stage-1 = final-flag.
  - QM5_2461 brooks-failed-wedge-h4 — Stage-1 = wedge.
  - This card uses **pure-channel Stage-1** (sustained directional
    drift in a narrow band, NO preceding wide spike-bar) — structurally
    distinct from all the Stage-1 patterns above. Brooks 2012 ch. 4
    explicitly contrasts "pure trend channels" (no spike, sustained
    micro-channel drift) from "spike-and-channel" sequences. A
    pure-channel that fails reverses with different mechanics than an
    S&C-failure: pure-channel-failure typically retraces 50–70% of the
    channel before printing a Stage-3 reversal-bar, vs. S&C failure
    which targets the spike-origin.

## Mechanik

### Pattern Stages (mechanical recognition on closed H4 bars)

**Stage 1 — Pure-channel formation (no spike precursor):**

1. Compute ATR(14) on closed H4 bars.
2. A "pure-channel" requires `k` consecutive closed H4 bars
   `i ∈ [s, s + k − 1]` with `k ∈ [6, 14]` (6–14-bar window — wider
   than S&C's 4–10 because pure channels are slower-developing) where:
   a. **No spike-bar in or preceding the channel:** for every bar `i`
      in `[s − 2, s + k − 1]`, `(High[i] − Low[i]) < 1.5·ATR(14)[i − 1]`
      (no bar in the channel window or the 2 bars preceding it
      satisfies the spike-bar wide-range criterion of `2.0×ATR`).
   b. **Directional drift:** count `up_bars` = number of `i` with
      `Close[i] > Close[i − 1]`, and `dn_bars` = number with
      `Close[i] < Close[i − 1]`, over `i ∈ [s, s + k − 1]`.
      - **Up-channel:** `up_bars − dn_bars ≥ 4` AND
        `Close[s + k − 1] > Close[s − 1] + 1.0·ATR(14)[s − 1]`
        (net upward progress of at least 1 ATR).
      - **Down-channel:** mirror.
   c. **Bounded range:** `max(High) − min(Low)` over the channel
      window ≤ `2.5·ATR(14)[s − 1]` (the channel is narrow relative
      to its baseline volatility — not a runaway breakout).
3. The channel locks at the close of bar `s + k − 1` where the next
   bar violates the directional-drift continuation (a bar in the
   opposite direction breaks `Close[s − 1]` for an up-channel, or
   the directional-progress condition fails).
4. Define:
   - `channel_origin = Close[s − 1]`,
   - `channel_extreme = max(High[s..s + k − 1])` for up-channel,
     `min(Low[s..s + k − 1])` for down-channel,
   - `channel_anchor_bar = s + k − 1`.

**Stage 2 — Reversal break (the failure setup):**

1. Within the next 12 closed H4 bars after `channel_anchor_bar`:
2. For an up-channel, a closed H4 bar prints
   `close < channel_origin − 0.3·ATR(14)` (price breaks back through
   the channel origin opposite the channel direction). Mark
   `break_bar`, mark
   `break_extreme = min(Low)` since `channel_anchor_bar`.
3. Mirror for down-channel.
4. If no break occurs within 12 bars, the pattern is abandoned —
   pure-channel typically resolves as a sustainable trend.

**Stage 3 — Failure trigger (entry signal):**

For an up-channel that broke down (entry direction = SHORT):

1. After `break_bar`, look for a "reversal-bar" within the next
   8 closed H4 bars that confirms the channel is dead:
   - `(High[r] − Low[r]) ≥ 0.8·ATR(14)[r − 1]` (meaningful range), AND
   - `Close[r] < Open[r]` (red bar), AND
   - `(High[r] − max(Close[r], Open[r])) ≤ 0.3·(High[r] − Low[r])`
     (no large upper rejection-tail — closes near the low, not a
     pinbar in the wrong direction), AND
   - `Close[r] < break_extreme + 0.5·ATR(14)[r − 1]` (the
     reversal-bar's close is at or below the prior breakdown
     extreme — confirms the breakdown is sustaining, not bouncing).
2. Entry on bar `r + 1` open at market (SHORT).

For a down-channel that broke up: mirror (entry direction = LONG).

Magic = `9504 × 10000 + slot` (1-position-per-magic, HR4).

### Exit

**Profit target (channel-retrace target):**

Brooks 2012 ch. 25 p. 482: "a failed channel typically retraces 50–70%
of the channel before stalling — the target is the channel midpoint."

- Short (failed up-channel): `TP = channel_origin +
  0.5·(channel_extreme − channel_origin)` — the 50% retrace of the
  channel's net move.
- Long (failed down-channel): mirror.

**Time stop:** if neither SL nor TP hit within 24 closed H4 bars after
entry, exit at market on bar 25's close.

### Stop Loss

- Short (failed up-channel): `SL = max(High[break_bar .. r]) +
  0.3·ATR(14, entry-bar)`. The post-break recovery high before the
  reversal-bar `r` acts as the structural stop — if price prints
  above that, the failure pattern is invalidated.
- Long: mirror.

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
- One entry per detected channel: once Stage-3 fires (or the channel
  is abandoned via 12-bar Stage-2 timeout), the channel is consumed.
- After a SL exit, no fresh entries on the same symbol for 24 H4 bars
  (whipsaw guard — failed channels often re-test before fully
  reversing).

## Concepts (was ist das für eine Strategie)

- [[concepts/failed-breakout]] — primary (Stage-2 break + Stage-3
  failure-reversal is the canonical Brooks "failed-pattern" geometry)
- [[concepts/tight-channel-reversal]] — secondary (Stage-1 is a
  pure-channel — sustained drift without a wide spike-bar precursor)
- [[concepts/mean-reversion]] — tertiary (TP at 50% channel retrace)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Al Brooks — *Trading Price Action: Trends* (Wiley 2012) ch. 4 (pure channels) + *Trading Ranges* (Wiley 2012) ch. 25 (channel failure). Brooks: 30+ year published price-action trader, brookstradingcourse.com Encyclopedia of Trading Patterns. ForexFactory thread cluster ongoing. R1 PASS expected. |
| R2 Mechanical | UNKNOWN | All three stages reduce to closed-form ATR, OHLC, and bar-count comparisons on closed H4 bars. Stage 1 uses a deterministic 6–14-bar window with bounded directional-drift + range checks. Stage 2 is a single closed-bar break-condition. Stage 3 is a deterministic 8-bar look-ahead for a reversal-bar with bounded properties. No look-ahead beyond closed bars; no fitting. R2 PASS expected. |
| R3 Data Available | UNKNOWN | Price-action primitive — price-only, no volume. Testable on all FX-majors, XAUUSD, XTIUSD, and Darwinex index CFDs on H4. SP500.DWX backtest-only — T_Live promotion requires NDX.DWX or WS30.DWX parallel validation (Board Advisor T_Live-gate enforcement). R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed window ranges (6, 14, 12, 8, 24), fixed thresholds (1.5, 4, 1.0, 2.5, 0.3, 0.8, 0.5, 0.20). No adaptive parameters, no ML, no neural net, no online learning. 1-position-per-magic. No martingale. R4 PASS expected. |

### R3 SP500.DWX live-promotion caveat

Live promotion T_Live gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T_Live deploy requires a
parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
This is Board Advisor's T_Live-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 59.

## Verwandte Strategien

- [[strategies/QM5_9450_brooks-failed-spike-and-channel-h4]] — Failed
  S&C with spike precursor. Distinct: 9504's Stage-1 explicitly forbids
  a spike-bar in or preceding the channel; 9450 mandates one.
- [[strategies/QM5_9400_brooks-failed-outside-outside-h4]] — Failed-OO,
  Stage-1 = outside-outside bar pair.
- [[strategies/QM5_9280_brooks-failed-triangle-h4]] — Failed-Triangle,
  Stage-1 = triangle convergence.
- [[strategies/QM5_9350_brooks-failed-ttr-h4]] — Failed-TTR, Stage-1 =
  tight-trading-range.
- [[strategies/QM5_2354_brooks-failed-final-flag-h4]] — Failed-Final-Flag,
  Stage-1 = final flag.
- [[strategies/QM5_2461_brooks-failed-wedge-h4]] — Failed-Wedge,
  Stage-1 = wedge convergence.
- [[strategies/QM5_1366_brooks-micro-channel-h1]] — micro-channel
  primitive on H1 (different timeframe, no failure trigger).
- [[strategies/QM5_1396_brooks-tight-micro-channel-trend-h1]] — micro
  channel continuation on H1.

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must verify pure-channel Stage-1
  produces a meaningfully different pattern set than S&C Stage-1 (9450).
  Brooks 2012 ch. 4 vs. ch. 3 distinction: pure-channel = sustained
  drift with no spike-bar precursor in the 2 bars preceding the
  channel start; S&C = wide spike-bar + channel. The two should fire
  on largely disjoint H4 bar windows. If P2 shows substantial overlap
  between 9450 and 9504 trade lists (e.g. >40% of trades fire on the
  same bar), the spike-exclusion criterion in Stage-1 needs review.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
