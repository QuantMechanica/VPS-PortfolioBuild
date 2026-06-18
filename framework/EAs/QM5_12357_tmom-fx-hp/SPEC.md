# QM5_12357_tmom-fx-hp - Strategy Spec

**EA ID:** QM5_12357
**Slug:** `tmom-fx-hp`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On each completed D1 bar, the EA reads the latest closed-price window and applies a Hodrick-Prescott trend filter with fixed lambda 1600. It goes long when the filtered trend is rising over the configured lag and the latest close is above the current trend value. It goes short when the filtered trend is falling over the configured lag and the latest close is below the current trend value. Open positions are closed or reversed when the computed source signal no longer matches the held direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_hp_lambda` | 1600.0 | 800.0-3200.0 tested | Hodrick-Prescott smoothing lambda from the card baseline. |
| `strategy_hp_lookback` | 100 | 75-150 tested | Number of completed D1 closes used in the HP filter. |
| `strategy_slope_lag` | 4 | 1 to lookback-1 | Computes `trend[-1] - trend[-5]` at the default value. |
| `strategy_warmup_bars` | 130 | >= lookback | Minimum completed D1 bars required before signal evaluation. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the hard protective stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 tested | ATR multiple for the hard protective stop. |
| `strategy_min_deviation_pct` | 0.0 | 0.0-1.0 | Optional P3 gate; default disabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with D1 close data.
- `GBPUSD.DWX` - card-listed FX major with D1 close data.
- `USDJPY.DWX` - card-listed FX major with D1 close data.
- `XAUUSD.DWX` - card-listed metal with D1 close data.
- `GDAXI.DWX` - verified DWX DAX equivalent for card-listed `GER40.DWX`.
- `NDX.DWX` - card-listed liquid index CFD with D1 close data.
- `WS30.DWX` - card-listed liquid index CFD with D1 close data.

**Explicitly NOT for:**
- `GER40.DWX` - named in the card but not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SP500.DWX` - optional in the card, not part of the primary P2 basket.

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
| Trades / year / symbol | 16 |
| Typical hold time | Days to weeks; the card does not specify a fixed hold time. |
| Expected drawdown profile | Trend-filter lag and whipsaw around the HP trend are the main risks. |
| Regime preference | Trend-following D1 price-filter regime. |
| Win rate target (qualitative) | Medium. |

Expected trade frequency from card: D1 HP trend-state strategy; conservative estimate 8-24 completed trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** GitHub repository source file
**Pointer:** `https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/fx/fx_moving_averages.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12357_tmom-fx-hp.md`

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
| v1 | 2026-06-18 | Initial build from card | 53267b02-36ae-4fdf-ab17-9db938376c71 |
