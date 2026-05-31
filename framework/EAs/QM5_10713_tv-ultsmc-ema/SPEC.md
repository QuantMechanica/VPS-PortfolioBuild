# QM5_10713_tv-ultsmc-ema - Strategy Spec

**EA ID:** QM5_10713
**Slug:** `tv-ultsmc-ema`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source cited in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades M5/M15 execution bars only when the closed bar is on the same side of SMA(200) as the EMA(9)/EMA(21) stack. It builds H4 swing highs and lows from confirmed width-2 fractal pivots, then treats prices below the 0.618 swing level or inside a demand order-block zone as long value, and prices above that level or inside a supply order-block zone as short value. A long entry fires on a bullish three-candle fair-value gap inside discount or a close back above EMA(9); a short entry mirrors this with bearish fair-value gaps or a close back below EMA(9). The target is the nearest H4 pivot in the trade direction, the stop is the opposite H4 pivot with an ATR(14) minimum floor, and trades are skipped unless target distance is at least 1.2 times stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 200 | 50-400 | Execution-timeframe trend baseline. |
| `strategy_ema_fast_period` | 9 | 2-50 | Fast execution-timeframe EMA for trend and trigger checks. |
| `strategy_ema_slow_period` | 21 | 5-100 | Slow execution-timeframe EMA for trend and exit checks. |
| `strategy_h4_fractal_width` | 2 | 1-5 | Left/right width for confirmed H4 fractal swing pivots. |
| `strategy_h4_scan_bars` | 240 | 50-1000 | Closed H4 bars scanned for pivots and order-block zones. |
| `strategy_atr_period` | 14 | 5-50 | H4 ATR period used for the minimum stop-distance floor. |
| `strategy_atr_floor_mult` | 1.0 | 0.1-5.0 | Minimum stop distance as a multiple of H4 ATR. |
| `strategy_min_target_stop_ratio` | 1.2 | 0.5-5.0 | Minimum target distance divided by stop distance. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with native DWX coverage.
- `GBPUSD.DWX` - card-listed FX major with native DWX coverage.
- `XAUUSD.DWX` - card-listed metal with native DWX coverage.
- `GDAXI.DWX` - DAX-equivalent DWX symbol used because the card-listed `GER40.DWX` is not in the symbol matrix.
- `NDX.DWX` - card-listed index with native DWX coverage.

**Explicitly NOT for:**
- `GER40.DWX` - card-listed name is not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX port.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable to the DarwinexZero test terminals.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` and `M15` execution bars |
| Multi-timeframe refs | H4 confirmed fractal pivots, H4 order-block zones, H4 ATR stop floor |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` from card frontmatter |
| Typical hold time | Not specified in frontmatter; day-trading strategy with H4 SL/TP levels |
| Expected drawdown profile | Not specified in frontmatter; trend-following pullback model with fixed $1,000 risk in backtests |
| Regime preference | Trend with retracement into discount/premium and structural expansion triggers |
| Win rate target (qualitative) | Not specified in frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** `https://www.tradingview.com/script/Ak5HYG42-Ultimate-SMC-EMAs-Day-Trading-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10713_tv-ultsmc-ema.md`

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
| v1 | 2026-05-31 | Initial build from card | 4467f81c-bb1d-49ca-8bfb-73c72913da8b |
