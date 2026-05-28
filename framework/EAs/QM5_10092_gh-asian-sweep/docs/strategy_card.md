---
ea_id: QM5_10092
slug: gh-asian-sweep
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
sources:
  - "[[sources/github-mql5-stars-20]]"
concepts:
  - "[[concepts/session-range]]"
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/asian-range]]"
  - "[[indicators/ema-200]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 80
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
card_body_incomplete: false
card_body_missing: ""
g0_approval_reasoning: "R1 source repo/file cited; R2 deterministic Asian-range sweep reversal with exits and ~80 trades/year/symbol; R3 testable on XAUUSD.DWX/CFDs; R4 no ML/grid/martingale and one-position-per-magic."
---

# GitHub Asian Range Sweep Reversal

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Repository: https://github.com/e49nana/Algorithmic-trading
- File: https://github.com/e49nana/Algorithmic-trading/blob/main/tradfi/mql5/AVGoldAsianBreakout.mqh
- Author / institution: Algosphere Quant / e49nana
- Location: `AVGoldAsianBreakout.mqh`, `CAVGoldAsianBreakout::DetectSweepReversal()`
- Source citation: 2026 GitHub URL https://github.com/e49nana/Algorithmic-trading/blob/main/tradfi/mql5/AVGoldAsianBreakout.mqh
- Target symbols: XAUUSD.DWX primary; EURUSD.DWX, DAX.DWX, and WS30.DWX port candidates after session/range normalization.

## Mechanik

### Entry
- Build the Asian session range from configured GMT hours, default 00:00-06:00 UTC, on M5 bars.
- Accept the day only if Asian range is within configured bounds, default 30-200 pips for gold.
- During the post-Asian trade window, default 06:00-16:00 UTC, detect a sweep beyond the range:
  - High sweep: bid moves at least `sweepMinPips` above Asian high and no low sweep has occurred.
  - Low sweep: bid moves at least `sweepMinPips` below Asian low and no high sweep has occurred.
- Sell after a high sweep only when the last completed bar, current bar, and bid are back below the Asian high.
- Buy after a low sweep only when the last completed bar, current bar, and bid are back above the Asian low.
- Require sweep distance not greater than `sweepMaxPips`.
- Require EMA filter if enabled: buy only when price is above EMA 200, sell only when price is below EMA 200.
- Require calculated risk/reward at least `minRRRatio`, default 1.5.
- V5 constraint: one active position per magic and one signal per range unless P3 explicitly enables a bounded second slot.

### Exit
- Buy target: Asian high.
- Sell target: Asian low.
- Buy stop: sweep low minus `slBufferPips`, default 15 pips.
- Sell stop: sweep high plus `slBufferPips`, default 15 pips.
- Expire signals after 30 seconds if not executed.

### Stop Loss
- Fixed structural stop beyond the sweep extreme plus the configured buffer.

### Position Sizing
- Source emits signal prices only; V5 build uses fixed $1,000 risk for P2 baseline and 0.25% percent risk live default.

### Zusätzliche Filter
- Broker/GMT offset normalization is required in P1.
- Range width filter, sweep min/max filter, EMA 200 directional filter, trade window filter, and max-trades-per-range filter.

## Concepts (was ist das für eine Strategie)
- [[concepts/session-range]] - primary
- [[concepts/liquidity-sweep]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full GitHub repository and file URL are cited; author/institution visible as Algosphere Quant / e49nana. |
| R2 Mechanical | PASS | Source has deterministic range construction, sweep detection, reversal confirmation, EMA filter, TP, SL, and signal expiry. |
| R3 Data Available | PASS | Uses OHLC/session time/EMA only; maps directly to XAUUSD.DWX and can port to other liquid DWX CFDs with session normalization. |
| R4 ML Forbidden | PASS | No ML, martingale, grid, or adaptive online parameters in the selected module; V5 enforces one active position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10052_gh-time-range]] - earlier range-breakout card from the same GitHub source family.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: cadence estimate assumes valid Asian ranges and sweeps on a minority of trading days; conservative annual estimate is 80 trades per symbol.*
