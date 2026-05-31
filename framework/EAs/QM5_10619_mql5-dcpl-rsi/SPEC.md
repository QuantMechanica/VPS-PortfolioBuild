# QM5_10619_mql5-dcpl-rsi — Strategy Spec

**EA ID:** QM5_10619
**Slug:** mql5-dcpl-rsi
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA evaluates completed H1 bars only. It opens long when the last two completed bars form a Piercing Line reversal pattern and RSI on the last completed bar is below 40. It opens short when the last two completed bars form a Dark Cloud Cover reversal pattern and RSI on the last completed bar is above 60. Long positions close when RSI crosses downward through 70 or 30; short positions close when RSI crosses upward through 30 or 70. The initial stop is based on the two-candle pattern extreme, capped at 1.75 times ATR(14), and the target is 1.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 20 | 1+ | RSI lookback used for entry confirmation and exit crosses. |
| `strategy_rsi_long_max` | 40.0 | 0-100 | Long entries require closed-bar RSI below this threshold. |
| `strategy_rsi_short_min` | 60.0 | 0-100 | Short entries require closed-bar RSI above this threshold. |
| `strategy_exit_low` | 30.0 | 0-100 | Lower RSI level used for strategy exits. |
| `strategy_exit_high` | 70.0 | 0-100 | Upper RSI level used for strategy exits. |
| `strategy_ma_period` | 14 | 1+ | Close/body averaging period used inside the two-candle pattern context. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the stop-distance cap. |
| `strategy_atr_sl_cap_mult` | 1.75 | 0+ | Maximum initial stop distance as a multiple of ATR. |
| `strategy_take_profit_rr` | 1.5 | 0+ | Fixed reward-to-risk target from the initial stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed baseline FX symbol with DWX matrix coverage.
- `GBPUSD.DWX` — card-listed baseline FX symbol with DWX matrix coverage.
- `USDJPY.DWX` — card-listed baseline FX symbol with DWX matrix coverage.
- `XAUUSD.DWX` — card-listed baseline metals symbol with DWX matrix coverage.

**Explicitly NOT for:**
- Non-`.DWX` symbols — research and backtest artifacts must use the canonical DWX symbol names.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — no broker/custom-symbol data guarantee exists for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Not specified in card; exits occur through RSI crosses, 1.5R target, SL, or Friday close. |
| Expected drawdown profile | Sparse to moderate reversal system with fixed $1,000 backtest risk per trade. |
| Regime preference | Candlestick reversal with RSI reversal confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/300 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10619_mql5-dcpl-rsi.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10619_mql5-dcpl-rsi.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | 05da0ca8-b4b0-41ad-8773-b08b75ea5382 |
