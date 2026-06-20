# QM5_11500_langer-engulfing-w1-position - Strategy Spec

**EA ID:** QM5_11500
**Slug:** langer-engulfing-w1-position
**Source:** 8ca13fce-d951-53be-9c60-35620d56354d (see `strategy-seeds/sources/8ca13fce-d951-53be-9c60-35620d56354d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA checks the last completed W1 candle against the prior W1 candle. A long setup occurs when the last completed weekly candle has a higher high, lower low, bullish body, and bullish body engulf versus the prior candle. A short setup is the mirrored bearish condition. The EA places a stop order 5 pips beyond the engulfing candle extreme, sets the stop loss at the opposite extreme capped at 200 pips, sets take profit to 1.5 times the engulfing candle range, and moves the stop to break-even after price moves 0.5 times that candle range in favor.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_offset_pips` | 5.0 | 4.0-6.0 | Stop-entry offset beyond the W1 engulfing candle high or low. |
| `strategy_tp_candle_mult` | 1.5 | 1.0-2.0 | Take-profit distance as a multiple of the engulfing candle range. |
| `strategy_sl_cap_pips` | 200.0 | 1.0-500.0 | Maximum stop distance for P2 when weekly candles are large. |
| `strategy_be_trigger_frac` | 0.5 | 0.1-1.0 | Fraction of the engulfing candle range required before moving SL to entry. |
| `strategy_spread_cap_pips` | 30.0 | 1.0-100.0 | Maximum positive spread allowed before new entries are blocked. |
| `strategy_signal_expiry_weeks` | 1 | 1-4 | Pending stop order lifetime in weeks. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed W1 DWX FX major with available native OHLC.
- `GBPUSD.DWX` - Card-listed W1 DWX FX major with available native OHLC.
- `USDJPY.DWX` - Card-listed W1 DWX FX major with available native OHLC.
- `AUDUSD.DWX` - Card-listed W1 DWX FX major with available native OHLC.
- `USDCAD.DWX` - Card-listed W1 DWX FX major with available native OHLC.
- `EURJPY.DWX` - Card-listed W1 DWX FX cross with available native OHLC.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the approved card names only FX pairs for this weekly engulfing strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `W1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate; setfiles use W1 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | Days to weeks, because this is a W1 position trade with SL/TP and break-even management. |
| Expected drawdown profile | Infrequent but wider weekly stops; P2 uses the 200-pip SL cap and fixed $1,000 risk. |
| Regime preference | Volatility expansion / breakout after a weekly engulfing candle. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8ca13fce-d951-53be-9c60-35620d56354d
**Source type:** book
**Pointer:** Paul Langer, The Black Book of Forex Trading (Alura Publishing/CreateSpace, 2015), Position Trading Strategy "Big Bulls and Bears"; local PDF path in the approved card.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11500_langer-engulfing-w1-position.md`

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
| v1 | 2026-06-20 | Initial build from card | bc11ee36-693b-4a2d-b0d3-6b40f22b519b |
