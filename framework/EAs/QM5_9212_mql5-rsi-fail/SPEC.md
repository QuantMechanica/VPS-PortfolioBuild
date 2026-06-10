# QM5_9212_mql5-rsi-fail — Strategy Spec

**EA ID:** QM5_9212
**Slug:** `mql5-rsi-fail`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Trades RSI(14) failure-swing reversals on H1 bars. A long signal fires when the previous closed bar's RSI was below 30 and the most recently closed bar's RSI crosses back above 30; a short signal fires when the previous bar's RSI was above 70 and the latest closed bar's RSI crosses back below 70. Entries execute at the open of the bar following the signal. Positions exit when RSI reaches 50, when the opposite failure-swing signal appears, or when the hard 2R take-profit is hit. Stop loss is the wider of ATR(14) × 1.5 or the signal candle's extreme (low for longs, high for shorts). A volatility filter blocks entries when ATR(14) is below 50% of ATR(100).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 5–30 | RSI lookback period |
| `strategy_rsi_oversold` | 30.0 | 20–40 | Oversold threshold for buy signal |
| `strategy_rsi_overbought` | 70.0 | 60–80 | Overbought threshold for sell signal |
| `strategy_atr_sl_period` | 14 | 7–21 | ATR period used for stop-loss sizing |
| `strategy_atr_sl_mult` | 1.5 | 1.0–3.0 | ATR multiplier for stop-loss distance |
| `strategy_atr_filter_fast` | 14 | 7–21 | Fast ATR period for volatility filter |
| `strategy_atr_filter_slow` | 100 | 50–200 | Slow ATR period for volatility filter |
| `strategy_atr_filter_ratio` | 0.5 | 0.3–0.8 | Minimum fast/slow ATR ratio to allow trading |
| `strategy_tp_rr` | 2.0 | 1.5–4.0 | Take-profit reward-to-risk ratio |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, high liquidity, RSI reversals well-documented
- `GBPUSD.DWX` — major FX pair, correlated to EUR but independent signal dynamics
- `USDJPY.DWX` — major FX pair, often trending but RSI failure swings occur at extremes

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — card specifies FX-only basket; index tick characteristics differ

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~50 |
| Typical hold time | hours to 1–2 days |
| Expected drawdown profile | moderate; 2R reward controls losses per trade |
| Regime preference | mean-revert / reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 39): Relative Strength Index", MQL5 Articles, 2024-09-18
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9212_mql5-rsi-fail.md`

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
| v1 | 2026-06-10 | Initial build from card | 9dbc9a5b-fddb-49db-99b0-41e0652a9ded |
