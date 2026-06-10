# QM5_10142_rsi2-sma — Strategy Spec

**EA ID:** QM5_10142
**Slug:** `rsi2-sma`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each completed D1 bar, check if price is above the 200-period SMA (uptrend filter) and RSI(2) is below 10 (short-term oversold). If both conditions hold, enter long at the next bar open. Exit the long position when RSI(2) closes above the 5-period SMA. Optionally, enter short when price is below the 200-period SMA and RSI(2) exceeds 90, exiting when price closes below the 5-period SMA. An emergency stop at 3× ATR(14) from entry protects against large adverse moves.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 2 | 2–5 | RSI lookback period (Connors-style short-term) |
| `strategy_long_level` | 10.0 | 5–20 | RSI threshold below which long entry fires |
| `strategy_short_level` | 90.0 | 80–95 | RSI threshold above which short entry fires |
| `strategy_trend_sma_period` | 200 | 100–200 | SMA period for trend direction filter |
| `strategy_exit_sma_period` | 5 | 3–8 | SMA period for exit signal |
| `strategy_shorts_enabled` | false | true/false | Enable short-side entries |
| `strategy_atr_period` | 14 | 10–20 | ATR period for emergency stop calculation |
| `strategy_atr_stop_mult` | 3.0 | 2.5–4.0 | ATR multiplier for emergency stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — large-cap US equity index; mean-reversion within D1 trend works well on index CFDs (backtest-only: not broker-routable for live)
- `NDX.DWX` — Nasdaq 100; high-vol US tech index, RSI(2) pullbacks pronounced
- `WS30.DWX` — Dow Jones 30; diversifies the US large-cap index basket

**Explicitly NOT for:**
- Forex pairs — mean-reversion horizon and trend dynamics differ from equity indices
- Commodities — overnight gaps and fundamental regime shifts invalidate the SMA-200 trend filter

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
| Trades / year / symbol | ~16 |
| Typical hold time | 1–5 days |
| Expected drawdown profile | Short-term pullback drawdowns; emergency ATR stop limits extreme loss |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Source type:** blog / website
**Pointer:** https://raposa.trade/blog/4-simple-rsi-trading-strategies-you-can-use-today/ (Raposa.Trade, Jun 2021)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10142_rsi2-sma.md`

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
| v1 | 2026-05-24 | Initial build from card | fa6d6d4a-9f2a-406b-a6d7-4f8e96d2a70c |
| v2 | 2026-06-10 | Fix forbidden iClose calls — replace with QM_Sig_Price_Above_MA | fa6d6d4a-9f2a-406b-a6d7-4f8e96d2a70c |
