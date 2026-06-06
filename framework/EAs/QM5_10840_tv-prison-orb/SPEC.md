# QM5_10840_tv-prison-orb - Strategy Spec

**EA ID:** QM5_10840
**Slug:** `tv-prison-orb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a morning volatility box that starts at 08:30 America/Chicago. It labels intraday pivots with a fixed Zig Zag-style depth filter, locks the box after the configured A-D pivot count, and defines the box high and low from those pivots. The baseline waits for a first close outside the box, a return inside, and then a second close beyond the high or low of the first breakout attempt. Open positions are closed at 12:30 America/Chicago if neither the 2.0R target nor the stop has closed them earlier.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_chicago_to_broker_hours` | 8 | 0-14 | Broker-time offset used to evaluate the America/Chicago session clock. |
| `strategy_session_start_hhmm` | 830 | 0-2359 | Chicago session start for the volatility-box process. |
| `strategy_entry_end_hhmm` | 1030 | 0-2359 | Last Chicago time at which new entries may trigger. |
| `strategy_session_exit_hhmm` | 1230 | 0-2359 | Chicago hard-exit time for open positions. |
| `strategy_zigzag_depth` | 5 | 3-13 | Pivot depth filter for the intraday A-D range. |
| `strategy_end_pivots` | 4 | 3-5 | Number of pivots used to lock the volatility box; 4 represents letter D. |
| `strategy_breakout_mode` | 2 | 1-2 | 1 trades first close outside the box; 2 requires breakout, return inside, and rebreak. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for box-height and stop-distance safety checks. |
| `strategy_box_min_atr` | 0.5 | 0.1-2.0 | Minimum allowed box height as ATR multiple. |
| `strategy_box_max_atr` | 4.0 | 1.0-8.0 | Maximum allowed box height as ATR multiple. |
| `strategy_min_stop_atr` | 0.25 | 0.05-2.0 | Minimum allowed stop distance as ATR multiple. |
| `strategy_fallback_stop_atr` | 1.0 | 0.25-4.0 | ATR fallback from the breakout line when the midline stop is too tight. |
| `strategy_target_r` | 2.0 | 1.5-2.5 | Profit target in R multiple. |
| `strategy_bars_to_scan` | 240 | 40-500 | Maximum closed bars scanned for the current session pivot box. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Card-listed primary DWX index CFD for Nasdaq 100 opening-range breakouts.
- `WS30.DWX` - Card-listed US index CFD for Dow 30 opening-range breakouts.
- `GDAXI.DWX` - DWX matrix DAX equivalent used because card-listed `GER40.DWX` is unavailable.
- `XAUUSD.DWX` - Card-listed liquid metal CFD with intraday volatility suitable for the box process.
- `EURUSD.DWX` - Card-listed liquid FX CFD for portable intraday breakout testing.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SP500.DWX` - Mentioned only as a possible later test target, not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Intraday, from post-box entry until target, stop, or 12:30 America/Chicago exit. |
| Expected drawdown profile | Sparse-sample breakout drawdowns, sensitive to session mapping and pivot depth. |
| Regime preference | Volatility-expansion breakout. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Prison Escape (BreakOut!)`, author handle `gr8hayz5`, accessed 2026-05-22.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10840_tv-prison-orb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 70c2b8e3-0861-4a06-8933-6b14599c6461 |
