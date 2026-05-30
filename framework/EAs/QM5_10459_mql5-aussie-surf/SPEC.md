# QM5_10459_mql5-aussie-surf — Strategy Spec

**EA ID:** QM5_10459
**Slug:** mql5-aussie-surf
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades M15 pullbacks in the direction of the Alligator trend. A long signal requires lips above teeth above jaw, a recent lower Bollinger Band touch, and the last closed bar crossing back above the Bollinger middle line. A short signal mirrors this with bearish Alligator order, a recent upper-band touch, and a close back below the middle line. The stop is the farther of 1.5 x ATR(14) or the recent swing beyond the Bollinger touch, with take profit fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_alligator_jaw_period` | 13 | 2-100 | Alligator jaw SMMA period. |
| `strategy_alligator_jaw_shift` | 8 | 0-50 | Alligator jaw forward shift applied as a closed-bar offset. |
| `strategy_alligator_teeth_period` | 8 | 2-100 | Alligator teeth SMMA period. |
| `strategy_alligator_teeth_shift` | 5 | 0-50 | Alligator teeth forward shift applied as a closed-bar offset. |
| `strategy_alligator_lips_period` | 5 | 2-100 | Alligator lips SMMA period. |
| `strategy_alligator_lips_shift` | 3 | 0-50 | Alligator lips forward shift applied as a closed-bar offset. |
| `strategy_bb_period` | 20 | 2-200 | Bollinger Band period. |
| `strategy_bb_deviation` | 2.0 | 0.5-5.0 | Bollinger Band standard-deviation multiplier. |
| `strategy_touch_lookback_bars` | 10 | 1-100 | Closed-bar lookback for finding a recent opposite-band touch. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the volatility stop component. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for the volatility stop component. |
| `strategy_rr_take_profit` | 2.0 | 0.1-10.0 | Reward-to-risk multiple for take profit. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPAUD.DWX` — source-market pair and primary baseline port.
- `GBPUSD.DWX` — liquid GBP major fallback named by the card.
- `AUDUSD.DWX` — liquid AUD major fallback named by the card.
- `EURUSD.DWX` — liquid FX major for the card's portable FX basket.
- `USDJPY.DWX` — liquid FX major for the card's portable FX basket.
- `USDCHF.DWX` — liquid FX major for the card's portable FX basket.
- `USDCAD.DWX` — liquid FX major for the card's portable FX basket.
- `NZDUSD.DWX` — liquid FX major for the card's portable FX basket.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX` — the card is an FX-pair Alligator/Bollinger strategy, not an index strategy.
- `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `XNGUSD.DWX` — metals and energy symbols are outside the card's FX universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | intraday to multi-session, bounded by SL/TP and Friday close |
| Expected drawdown profile | trend-pullback losses cluster in choppy or range-bound markets |
| Regime preference | trend-following with volatility-band pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase, "Aussie Surfer - expert for MetaTrader 5", Elric Arendse, published 2023-03-14, https://www.mql5.com/en/code/43278
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10459_mql5-aussie-surf.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | 3decc398-149b-4713-adea-72e5376dc760 |
