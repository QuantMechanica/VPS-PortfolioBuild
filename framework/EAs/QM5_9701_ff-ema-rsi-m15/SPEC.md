# QM5_9701_ff-ema-rsi-m15 — Strategy Spec

**EA ID:** QM5_9701
**Slug:** `ff-ema-rsi-m15`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA enters long on a completed M15 bar where EMA(5) crosses above EMA(12) and RSI(7) is above 50, subject to a spread filter (spread < 20% of ATR(14)) and a session gate (London through early New York, broker hours 08:00–18:00). Short entry mirrors these conditions. Stop loss is placed below/above the previous candle low/high adjusted for spread, capped at 20 pips and widened to 0.45×ATR(14) if the raw stop is too tight. Take profit targets 1.4× the SL distance (risk:reward 1:1.4). Exits trigger on an opposite EMA(5/12) cross or after 24 M15 bars have elapsed (6-hour time stop).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 5 | 3–20 | Fast EMA period (card: 5) |
| `strategy_ema_slow` | 12 | 5–50 | Slow EMA period (card: 12) |
| `strategy_rsi_period` | 7 | 5–21 | RSI period for momentum filter (card: 7) |
| `strategy_atr_period` | 14 | 7–21 | ATR period for SL floor and spread gate |
| `strategy_spread_atr_ratio` | 0.20 | 0.05–0.50 | Max allowed spread / ATR(14) |
| `strategy_sl_max_pips` | 20 | 5–50 | SL cap in pips (card: 20 pips) |
| `strategy_sl_atr_min_mult` | 0.45 | 0.20–1.00 | SL minimum as ATR(14) multiple |
| `strategy_tp_rr_mult` | 1.4 | 0.5–5.0 | TP = SL distance × this factor (card: 1.4×) |
| `strategy_time_stop_bars` | 24 | 4–96 | Close position after N M15 bars (card: 24) |
| `strategy_session_start_hour` | 8 | 0–23 | Session open, broker time |
| `strategy_session_end_hour` | 18 | 1–23 | Session close, broker time |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major; tight spreads during London/NY; EMA cross signals clear on M15
- `GBPUSD.DWX` — liquid major; London-session volatility suits M15 cross system
- `USDJPY.DWX` — liquid major; well-defined M15 trends during Asia-London overlap and NY
- `XAUUSD.DWX` — liquid commodity; strong intraday trends and ample ATR on M15; SL floor keeps stops practical

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — card targets FX/metals only; session hours differ

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
| Trades / year / symbol | ~85 |
| Typical hold time | 1–6 hours (1–24 M15 bars) |
| Expected drawdown profile | Intraday; frequent small losses, occasional larger wins; DD typically < 15% with 1:1.4 R:R |
| Regime preference | Trend / momentum (EMA cross filter selects directional moves) |
| Win rate target (qualitative) | medium (40–55%); profitability from R:R > 1) |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** sashadeol, "EMA & RSI Intraday M15 system", ForexFactory, 2011-09-20,
https://www.forexfactory.com/thread/316055-ema-rsi-intraday-m15-system
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9701_ff-ema-rsi-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 38d93408-8333-4486-bacf-54869f3296b6 |
