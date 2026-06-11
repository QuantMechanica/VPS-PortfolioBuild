# QM5_9960_ff-lwma5-openclose-cross — Strategy Spec

**EA ID:** QM5_9960
**Slug:** `ff-lwma5-openclose-cross`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA implements a triple-screen LWMA open/close cross on FX H4 charts. On the D1 timeframe a trend filter confirms direction: LWMA(5) of close must be above LWMA(5) of open for longs (below for shorts). On the H4 execution frame, a long entry fires when LWMA(5, close) crosses above LWMA(5, open) on the last closed bar, the H4 close is above both LWMA lines, and the cross-candle range does not exceed 2×ATR(14). A short entry mirrors these conditions. Positions are closed by an opposite H4 LWMA cross, a 1.5R fixed take-profit, or a 10-bar time stop (~40 hours).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lwma_period` | 5 | 3–20 | LWMA period applied to open and close price series |
| `strategy_atr_period` | 14 | 10–30 | ATR period for stop sizing and range filter |
| `strategy_atr_sl_mult` | 1.1 | 0.5–3.0 | SL = mult × ATR(14, H4) |
| `strategy_tp_ratio` | 1.5 | 1.0–4.0 | TP = ratio × SL distance (fixed R-multiple) |
| `strategy_atr_range_filter` | 2.0 | 1.0–5.0 | Skip entry if cross-candle range > mult × ATR |
| `strategy_spread_pct_max` | 0.12 | 0.05–0.30 | Maximum spread as a fraction of stop distance |
| `strategy_time_stop_bars` | 10 | 5–30 | Close position after N H4 bars (~40 h at 10 bars) |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — major FX pair; sufficient H4 volatility for LWMA cross signals
- `AUDUSD.DWX` — risk-correlated major; trending behaviour suits triple-screen approach
- `EURUSD.DWX` — highest-liquidity major; tight spreads relative to stop distance
- `USDJPY.DWX` — carry-influenced major; directional trends support D1 filter usefulness

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — LWMA open/close cross was developed on FX; index gap behaviour may distort signal

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` (trend filter only — LWMA(5) open/close alignment) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | 4–40 hours (1–10 H4 bars) |
| Expected drawdown profile | Moderate; capped by 1.1× ATR stop and 10-bar time exit |
| Regime preference | Trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** SwingMan, "Golden-Cross Trading-Idea", ForexFactory, 2023–2025, https://www.forexfactory.com/thread/1207682-golden-cross-trading-idea
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9960_ff-lwma5-openclose-cross.md`

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
| v1 | 2026-06-11 | Initial build from card | 9bf6c8ad-19ee-4299-b506-3e28910f9c10 |
