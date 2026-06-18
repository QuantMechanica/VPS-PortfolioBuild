# QM5_9364_mql5-ichi-cloud-trend - Strategy Spec

**EA ID:** QM5_9364
**Slug:** `mql5-ichi-cloud-trend`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades Ichimoku cloud trend continuation on M30 bars. It buys when the latest fully closed close is higher than the previous close, both closes are above Senkou Span A, Senkou Span A is above Senkou Span B, and ADX(14) is at least 25. It sells when the same conditions are inverted: the latest closed close is lower than the previous close, both closes are below Senkou Span A, Senkou Span A is below Senkou Span B, and ADX(14) is at least 25. Positions exit on the opposite Pattern 8 signal, on a close back into or through the cloud against the trade, or after 72 M30 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tenkan_period` | 9 | 1-100 | Ichimoku Tenkan-sen period. |
| `strategy_kijun_period` | 26 | 1-200 | Ichimoku Kijun-sen period and cloud displacement reference. |
| `strategy_senkou_period` | 52 | 1-300 | Ichimoku Senkou Span B period. |
| `strategy_adx_period` | 14 | 2-100 | ADX-Wilder trend-strength period. |
| `strategy_adx_min` | 25.0 | 0.0-100.0 | Minimum ADX required for entry. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for cloud-edge stop buffer. |
| `strategy_sl_atr_mult` | 1.0 | 0.1-10.0 | ATR multiple beyond the cloud edge for stop placement. |
| `strategy_max_hold_bars` | 72 | 1-1000 | Maximum holding period in chart bars. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - card-stated DWX-native forex target.
- `EURUSD.DWX` - card-stated DWX-native forex target.
- `USDJPY.DWX` - card-stated DWX-native forex target.
- `XAUUSD.DWX` - card-stated DWX-native gold target.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest registry requires canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `75` |
| Typical hold time | Up to 72 M30 bars, about 36 hours. |
| Expected drawdown profile | Trend-following drawdown during sideways or choppy cloud regimes. |
| Regime preference | Trend-following / momentum-continuation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/18723`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9364_mql5-ichi-cloud-trend.md`

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
| v1 | 2026-06-18 | Initial build from card | 629194e9-6435-4e41-a065-7565df494b14 |
