# QM5_9698_ff-symphonie-4lights-m15 — Strategy Spec

**EA ID:** QM5_9698
**Slug:** `ff-symphonie-4lights-m15`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Four Symphonie indicator proxies — Trendline (EMA slope), Extreme (RSI > 50), Emotion (MACD main vs signal), and Sentiment (Stochastic K vs D) — must all align bullish or bearish on the same completed M15 bar. A freshness gate requires at least one of the four lights to have flipped from its prior state within the last 3 closed bars, preventing stale signal entries. Entry is long when all four lights are bullish and a fresh flip is detected with price above EMA(20); short when all four lights are bearish. Stop loss is placed below the signal bar low (long) or above the signal bar high (short), offset by 0.35× ATR(14). Take profit is set at 1.8R. The position exits when the Trendline indicator reverses against the trade, when two or more lights close opposite the trade direction, or after 16 M15 bars (time stop).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 20 | 5–100 | EMA period for Trendline light proxy (close vs EMA) |
| `strategy_rsi_period` | 14 | 5–50 | RSI period for Extreme light proxy (>50 = bull) |
| `strategy_macd_fast` | 12 | 3–50 | MACD fast period for Emotion light proxy |
| `strategy_macd_slow` | 26 | 10–100 | MACD slow period for Emotion light proxy |
| `strategy_macd_signal` | 9 | 3–30 | MACD signal period for Emotion light proxy |
| `strategy_stoch_k` | 5 | 3–21 | Stochastic K period for Sentiment light proxy |
| `strategy_stoch_d` | 3 | 1–10 | Stochastic D period for Sentiment light proxy |
| `strategy_stoch_slow` | 3 | 1–10 | Stochastic slow period for Sentiment light proxy |
| `strategy_atr_period` | 14 | 5–50 | ATR period for SL calculation |
| `strategy_sl_atr_mult` | 0.35 | 0.10–1.0 | SL offset multiplier on ATR from signal bar L/H |
| `strategy_tp_rr` | 1.8 | 1.0–5.0 | Take-profit as multiple of SL distance (R:R) |
| `strategy_time_stop_bars` | 16 | 4–100 | Hard time stop: exit after N M15 bars |
| `strategy_session_start_h` | 7 | 0–23 | Entry allowed from this broker hour (European open) |
| `strategy_session_end_h` | 22 | 0–23 | Entry blocked from this broker hour (NY close) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid FX major; tight spreads suit M15 multi-filter strategy
- `GBPUSD.DWX` — high volatility during European session; good signal frequency
- `USDJPY.DWX` — overlaps both Asian and US sessions; complements EUR/GBP basket
- `EURJPY.DWX` — cross pair with strong trend character; risk-on/off sensitivity adds diversification

**Explicitly NOT for:**
- Index CFDs (NDX.DWX, WS30.DWX) — card targets FX majors; indicator calibration differs
- Commodity pairs (XAUUSD.DWX) — different volatility regime; not validated

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
| Trades / year / symbol | ~70 |
| Typical hold time | 0.5–4 hours (up to 16 M15 bars = 4h hard stop) |
| Expected drawdown profile | Moderate intraday; Friday close and session filter limit overnight exposure |
| Regime preference | Trending with momentum; four-light consensus filters ranging markets |
| Win rate target (qualitative) | Medium (consensus filter raises precision) |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** https://www.forexfactory.com/thread/315572-symphonie-trader-system (handle: `Evaluator`, 2011-09-16)
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9698_ff-symphonie-4lights-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 4a78473e-d625-46cc-bd3c-aaa8a32158ae |
