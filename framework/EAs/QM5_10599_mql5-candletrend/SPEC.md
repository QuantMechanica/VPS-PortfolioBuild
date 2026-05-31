# QM5_10599_mql5-candletrend - Strategy Spec

**EA ID:** QM5_10599
**Slug:** `mql5-candletrend`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA counts the latest completed candles that closed in the same direction. It opens long when `strategy_candle_trend_total` consecutive closed candles have close greater than open, and opens short when the same number have close less than open. A long closes when the bearish sequence appears, a short closes when the bullish sequence appears, and any remaining position closes after `strategy_max_hold_bars` completed H4 bars. The protective stop is placed at `strategy_atr_sl_mult` times ATR from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_candle_trend_total` | 3 | 1-10 | Number of consecutive growing or falling closed candles required for entry and opposite-signal exit. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-10.0 | ATR multiple used to set the protective stop from entry. |
| `strategy_max_hold_bars` | 16 | 1-200 | Maximum completed H4 bars to hold when no opposite sequence appears. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - source test uses XAUUSD H4, directly matching the card baseline.
- `EURUSD.DWX` - liquid DWX FX symbol for portable OHLC candle-sequence logic.
- `GBPUSD.DWX` - liquid DWX FX symbol for portable OHLC candle-sequence logic.
- `NDX.DWX` - liquid DWX index CFD for portable momentum and price-action logic.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available in the DWX test universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | up to 16 completed H4 bars unless the opposite sequence appears first |
| Expected drawdown profile | momentum sequence strategy with ATR catastrophic stop and no take-profit target stated |
| Regime preference | price-action momentum / trend continuation |
| Win rate target (qualitative) | not stated in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/1640` and `artifacts/cards_approved/QM5_10599_mql5-candletrend.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10599_mql5-candletrend.md`

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
| v1 | 2026-05-31 | Initial build from card | 12187a67-5411-49ff-9d4f-90c65a889cbd |
