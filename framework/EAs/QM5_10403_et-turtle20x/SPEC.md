# QM5_10403_et-turtle20x - Strategy Spec

**EA ID:** QM5_10403
**Slug:** `et-turtle20x`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades a D1 Turtle-style Donchian breakout. It places stop entries at the highest high and lowest low of the prior 20 D1 bars, with one active position or pending bracket per symbol and magic. Long positions exit when price breaks below the rolling 10-day low, and short positions exit when price breaks above the rolling 10-day high. The protective stop starts at the closer of the 10-day channel exit and a 2.0 ATR(20) stop from entry, then follows the rolling 10-day channel.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_D1` | D1 baseline | Timeframe used for Donchian and ATR calculations. |
| `strategy_entry_channel` | `20` | 20, 50, 55 | Prior-bar high/low lookback used for stop entries. |
| `strategy_exit_channel` | `10` | 10, 20 | Rolling opposite channel used for exits and stop movement. |
| `strategy_atr_period` | `20` | positive integer | ATR period used for the protective stop. |
| `strategy_atr_stop_mult` | `2.0` | 1.5, 2.0, 2.5 | ATR multiple for the protective stop. |
| `strategy_atr_regime_filter` | `false` | true/false | Enables the optional ATR percentile regime filter from the card. |
| `strategy_atr_regime_window` | `100` | positive integer | Lookback window for ATR percentile calculation. |
| `strategy_atr_regime_percentile` | `50.0` | 0-100 | ATR percentile threshold when the regime filter is enabled. |
| `strategy_max_spread_points` | `0.0` | 0 or positive | Optional spread ceiling in points; 0 disables this strategy-level ceiling. |
| `strategy_pending_expiry_bars` | `1` | positive integer | Number of strategy bars before stop-entry orders expire. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved liquid FX major for daily Donchian breakout testing.
- `GBPJPY.DWX` - card-approved liquid FX cross for daily Donchian breakout testing.
- `XAUUSD.DWX` - card-approved metal symbol for daily trend breakout testing.
- `GDAXI.DWX` - matrix-backed DAX custom symbol used for the card's GER40 exposure.
- `SP500.DWX` - card-approved S&P 500 custom symbol; valid for backtest only under current DWX discipline.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable for DWX backtest registration.
- `GER40.DWX` - not present in the DWX matrix; use `GDAXI.DWX` for DAX exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `18` |
| Typical hold time | several days to weeks |
| Expected drawdown profile | Trend-following drawdowns from false breakouts and range-bound markets. |
| Regime preference | breakout / trend |
| Win rate target (qualitative) | low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/20-day-breakout.363958/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10403_et-turtle20x.md`

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
| v1 | 2026-05-25 | Initial build from card | 6c8b060c-144c-4ff3-8ea7-b4209cb4f5fb |
