# QM5_12449_ea31337-mabrk - Strategy Spec

**EA ID:** QM5_12449
**Slug:** `ea31337-mabrk`
**Source:** `041e0d5c-bf76-501d-bee2-31c0f4a6e233` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades the EA31337 Moving Average Candle Breakout rule on closed H1 bars. It uses the source default Ichimoku selector as a fixed Tenkan-line baseline: the current and prior closed candle ranges are normalized by the current and prior D1 ranges and chart timeframe, the Tenkan value must sit inside either closed candle, and candle direction decides long or short. The EA enters one market position with fixed 80-pip SL and 80-pip TP, exits after 30 bars, and closes early when the opposite breakout signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_open_level` | 1.0 | >0 | Minimum normalized two-candle range required for entry. |
| `strategy_signal_open_method` | 0 | 0-7 | Optional source bitmask for Tenkan slope and four-bar extreme confirmation. |
| `strategy_tenkan_period` | 30 | >=2 | Source default Ichimoku Tenkan lookback used as the breakout line. |
| `strategy_stop_loss_pips` | 80 | >0 | Fixed protective stop distance in pips. |
| `strategy_take_profit_pips` | 80 | >0 | Fixed profit target distance in pips. |
| `strategy_close_after_bars` | 30 | >0 | Time exit after this many chart bars. |
| `strategy_max_spread_pips` | 4 | >=0 | Maximum live spread in pips; zero modeled spread is allowed. |
| `strategy_opposite_exit_enabled` | true | true/false | Close an open position when the opposite breakout signal appears. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid DWX forex major with OHLC and moving-average data.
- `GBPUSD.DWX` - card-listed liquid DWX forex major with OHLC and moving-average data.
- `USDJPY.DWX` - card-listed liquid DWX forex major with OHLC and moving-average data.
- `XAUUSD.DWX` - card-listed DWX metal CFD with OHLC and moving-average data.
- `GDAXI.DWX` - DWX matrix canonical DAX CFD equivalent for the card's `DAX.DWX` suggestion.

**Explicitly NOT for:**
- `DAX.DWX` - card suggested this label, but the DWX matrix uses `GDAXI.DWX` as the available DAX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` range normalization |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Up to 30 H1 bars, with earlier SL/TP or opposite-signal exits |
| Expected drawdown profile | Breakout strategy with fixed per-trade risk and no pyramiding |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `041e0d5c-bf76-501d-bee2-31c0f4a6e233`
**Source type:** `GitHub repository`
**Pointer:** `https://github.com/EA31337/Strategy-MA_Breakout/blob/master/Stg_MA_Breakout.mqh`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12449_ea31337-mabrk.md`

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
| v1 | 2026-06-18 | Initial build from card | b545bb02-c3e1-419f-aeef-3c894ce79f85 |
