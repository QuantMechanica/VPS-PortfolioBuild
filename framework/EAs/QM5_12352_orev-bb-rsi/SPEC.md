# QM5_12352_orev-bb-rsi — Strategy Spec

**EA ID:** QM5_12352
**Slug:** orev-bb-rsi
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** gemini
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Buys short-term oversold pullbacks on the D1 timeframe when the longer-term trend is bullish. Specifically, enters long when the D1 close is above its 50-day SMA, the 50-day SMA is above the 150-day SMA, the 3-day RSI is below 30, and the close is below the lower Bollinger Band (21, 2.0). Exits are triggered when unrealized profit reaches 3%, unrealized loss reaches -20%, or after a 4-day time stop.

---

## 2. Parameters

Table of every input parameter, its default, range, and meaning.

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | `PERIOD_D1` | Strategy timeframe |
| `strategy_rsi_period` | 3 | 2-7 | RSI calculation period |
| `strategy_rsi_entry` | 30.0 | 20.0-35.0 | RSI oversold entry threshold |
| `strategy_bb_period` | 21 | 14-30 | Bollinger Bands period |
| `strategy_bb_deviation` | 2.0 | 1.5-2.5 | Bollinger Bands standard deviation |
| `strategy_sma_fast` | 50 | 40-75 | Fast simple moving average period |
| `strategy_sma_slow` | 150 | 100-200 | Slow simple moving average period |
| `strategy_max_hold_days` | 4 | 3-8 | Maximum holding period in days |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- `EURUSD.DWX` — liquid major forex pair
- `GBPUSD.DWX` — liquid major forex pair
- `USDJPY.DWX` — liquid major forex pair
- `XAUUSD.DWX` — gold spot against USD
- `GDAXI.DWX` — German DAX index (nearest matrix port for GER40)
- `NDX.DWX` — Nasdaq 100 index
- `WS30.DWX` — Dow Jones 30 index

**Explicitly NOT for:**
- None

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | 1-4 days |
| Expected drawdown profile | low to medium |
| Regime preference | mean-revert |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** forum
**Pointer:** `https://github.com/oreilm49/quantconnect/blob/master/MeanReversionBBLong/main.py`
**R1–R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12352_orev-bb-rsi.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-10 | Initial build from card | 5146007d-b1b8-4acf-b239-1ed29e56d16f |
