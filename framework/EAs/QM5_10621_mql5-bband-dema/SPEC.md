# QM5_10621_mql5-bband-dema - Strategy Spec

**EA ID:** QM5_10621
**Slug:** `mql5-bband-dema`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see MQL5 CodeBase citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA evaluates completed M30 candles against Bollinger Bands. It opens long when the completed candle is bullish and crosses the lower band from below to above while the D1 DEMA is rising over three completed DEMA samples. It opens short when the completed candle is bearish and crosses the upper band from above to below while the D1 DEMA is falling. Long positions close when a bearish candle crosses the upper band from above to below; short positions close when a bullish candle crosses the lower band from below to above, with V5 SL/TP protection active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bands_period` | 20 | >= 2 | Bollinger Bands period. |
| `strategy_bands_deviation` | 2.0 | > 0 | Bollinger standard deviation multiplier. |
| `strategy_bands_shift` | 0 | >= 0 | Bollinger Bands shift applied to the closed-bar band lookup. |
| `strategy_dema_period` | 20 | >= 2 | DEMA period for trend direction. |
| `strategy_dema_timeframe` | PERIOD_D1 | MT5 timeframe enum | DEMA timeframe; source code uses D1 while the chart signal runs on M30. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for the protective stop. |
| `strategy_atr_sl_mult` | 1.5 | > 0 | ATR multiple for the default stop distance. |
| `strategy_tp_rr` | 2.0 | > 0 | Emergency take-profit in R-multiple terms. |
| `strategy_max_spread_atr_fraction` | 0.20 | >= 0 | Entry is skipped when current spread exceeds this fraction of ATR(14). |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source example references EURUSD M30 and DWX matrix has the custom symbol.
- `GBPUSD.DWX` - liquid FX major using the same OHLC Bollinger and DEMA mechanics.
- `USDJPY.DWX` - liquid FX major using the same OHLC Bollinger and DEMA mechanics.
- `XAUUSD.DWX` - liquid metal symbol listed in the approved card and DWX matrix.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available to the DWX backtest terminals.
- Non-OHLC synthetic baskets - the card specifies single-symbol Bollinger and DEMA signals.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `PERIOD_D1` DEMA direction filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | Not stated in card frontmatter; held until the opposite Bollinger band-cross exit or emergency 2R TP/SL. |
| Expected drawdown profile | Fixed $1,000 risk per backtest trade with ATR-bounded stop distance. |
| Regime preference | Trend-following filter with Bollinger band reversal entries. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/166` and `artifacts/cards_approved/QM5_10621_mql5-bband-dema.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10621_mql5-bband-dema.md`

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
| v1 | 2026-05-31 | Initial build from card | 258752c6-d97a-4414-931c-67e8be378a38 |
