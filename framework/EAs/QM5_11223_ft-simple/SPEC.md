# QM5_11223_ft-simple - Strategy Spec

**EA ID:** QM5_11223
**Slug:** ft-simple
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long on M5 closed bars when MACD default momentum is positive, MACD is above its signal line, the upper Bollinger Band 12/2 is rising, and RSI7 is above 70. The entry is sent at the next bar as a market buy. The initial stop uses ATR(14) times 1.5, with the source -25% stop retained only as a disaster cap. The trade exits through the 1% ROI target, the RSI7 > 80 source exit, the stop, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | fixed | MACD fast EMA period from the source default. |
| `strategy_macd_slow` | 26 | fixed | MACD slow EMA period from the source default. |
| `strategy_macd_signal` | 9 | fixed | MACD signal period from the source default. |
| `strategy_rsi_period` | 7 | 7-14 | RSI period used by entry and exit. |
| `strategy_rsi_entry` | 70.0 | 60-80 | Minimum RSI for long entry. |
| `strategy_rsi_exit` | 80.0 | 75-85 | RSI threshold for source signal exit. |
| `strategy_bollinger_window` | 12 | 12-20 | Bollinger Band lookback window. |
| `strategy_bollinger_devs` | 2.0 | fixed | Bollinger Band standard-deviation multiplier. |
| `strategy_atr_period` | 14 | fixed | ATR period for the MT5 baseline stop. |
| `strategy_atr_stop_mult` | 1.5 | 1.0-2.0 | ATR stop multiplier. |
| `strategy_roi_pct` | 1.0 | fixed | Immediate ROI target from the source strategy. |
| `strategy_disaster_stop_pct` | 25.0 | fixed | Source stoploss retained as disaster cap. |
| `strategy_max_spread_stop_fraction` | 0.06 | fixed | Maximum spread as a fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid forex major with DWX OHLC data.
- `GBPUSD.DWX` - card-listed liquid forex major with DWX OHLC data.
- `USDJPY.DWX` - card-listed liquid forex major with DWX OHLC data.
- `XAUUSD.DWX` - card-listed gold symbol with DWX OHLC data.

**Explicitly NOT for:**
- Symbols outside the card's R3 basket - not registered for this EA and not part of the P2 baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | medium risk; card leaves PF and drawdown TBD |
| Regime preference | MACD/Bollinger momentum and volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/Simple.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11223_ft-simple.md`

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
| v1 | 2026-06-08 | Initial build from card | 354dc104-8df7-4359-8920-adaa9d406cfb |
