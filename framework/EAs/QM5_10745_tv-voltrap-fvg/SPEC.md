# QM5_10745_tv-voltrap-fvg - Strategy Spec

**EA ID:** QM5_10745
**Slug:** `tv-voltrap-fvg`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

Long when a closed M5 bar sequence shows a sharp bearish trap candle followed by a bullish fair value gap. The trap candle is either a bearish engulfing candle or a close below the prior low by at least 0.5 ATR(14), and its DWX tick volume must be within 5 percent of the prior 20-bar tick-volume average. The EA places a buy limit at the lower boundary of the bullish FVG, sets the stop 0.1 ATR below that boundary, and targets the most recent confirmed swing high within 3R; if no such swing high exists it uses a fixed 2R target. Unfilled pending orders expire after 10 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1-100 | ATR period for breakdown threshold and stop offset. |
| `strategy_breakdown_atr_mult` | 0.5 | 0.1-5.0 | Minimum close-below-prior-low distance in ATR units. |
| `strategy_volume_sma_period` | 20 | 1-200 | Prior-bar tick-volume SMA period. |
| `strategy_volume_band_pct` | 5.0 | 0.0-50.0 | Allowed tick-volume distance from SMA, in percent. |
| `strategy_sl_atr_mult` | 0.1 | 0.01-5.0 | Stop offset below the FVG lower boundary, in ATR units. |
| `strategy_pending_expiry_bars` | 10 | 1-100 | Number of bars before an unfilled buy limit expires. |
| `strategy_swing_lookback_bars` | 40 | 3-300 | Search window for the most recent confirmed swing high. |
| `strategy_max_swing_rr` | 3.0 | 0.5-10.0 | Maximum swing-high target distance in R. |
| `strategy_fallback_rr` | 2.0 | 0.5-10.0 | Fixed target in R if no valid swing high is found. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card R3 basket includes gold, and the rule uses OHLC/FVG plus DWX tick-volume proxy.
- `EURUSD.DWX` - Card R3 basket includes the liquid EUR/USD forex pair.
- `GBPUSD.DWX` - Card R3 basket includes the liquid GBP/USD forex pair.
- `NDX.DWX` - Card R3 basket includes Nasdaq 100 index exposure.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtest registration.

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
| Trades / year / symbol | `70` |
| Typical hold time | Not specified in card frontmatter; intraday pending-limit entries exit via SL/TP or framework Friday close. |
| Expected drawdown profile | Not specified in card frontmatter; fixed per-trade V5 risk with one position per symbol/magic. |
| Regime preference | Intraday bearish-volume-trap plus FVG confirmation. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView script`
**Pointer:** `https://www.tradingview.com/script/Jvnd1LTj-Liquidity-Grab-Strategy-Volume-Trap/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10745_tv-voltrap-fvg.md`

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
| v1 | 2026-06-14 | Initial build from card | 82fc8b65-4572-489a-b78f-8f9a946a80d0 |
