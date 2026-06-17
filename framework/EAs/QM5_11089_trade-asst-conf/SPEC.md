# QM5_11089_trade-asst-conf — Strategy Spec

**EA ID:** QM5_11089
**Slug:** `trade-asst-conf`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex "Trade Assistant", GitHub + MQL5)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Four-indicator all-agree confluence on completed H4 bars (EarnForex "Trade
Assistant"). The EA opens a position only when Stochastic, an RSI pair, the
Entry CCI and the Trend CCI all point the same direction on the last closed bar.
Long when: Stochastic main(%K) is above signal(%D); RSI(14, typical) is above
RSI(70, typical); Entry CCI > 0 and rising versus the prior closed bar; Trend
CCI > 0 and rising versus the prior closed bar. Short is the exact mirror. To
avoid the two-cross-same-bar zero-trade trap, the Entry-CCI rising/falling check
is the single directional trigger EVENT and the other three are co-confirming
STATES read on the same bar. Exit when any opposite full confluence appears, or
after a deterministic 12-bar (H4) time stop. A catastrophic ATR(14) stop at 2.0
ATR and an ATR-multiple take-profit protect each position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k_period` | 8 | 5-21 | Stochastic %K period |
| `strategy_stoch_d_period` | 3 | 2-7 | Stochastic %D (signal) period |
| `strategy_stoch_slowing` | 3 | 1-7 | Stochastic slowing |
| `strategy_rsi_fast_period` | 14 | 7-21 | Fast RSI period (typical price) |
| `strategy_rsi_slow_period` | 70 | 40-100 | Slow RSI period (typical price) |
| `strategy_cci_entry_period` | 14 | 7-30 | Entry CCI period (directional trigger) |
| `strategy_cci_trend_period` | 50 | 30-100 | Trend CCI period (regime state) |
| `strategy_atr_period` | 14 | 7-21 | ATR period for stop / target |
| `strategy_sl_atr_mult` | 2.0 | 1.5-3.0 | Catastrophic stop = mult × ATR |
| `strategy_tp_atr_mult` | 4.0 | 2.0-6.0 | Take-profit = mult × ATR |
| `strategy_time_stop_bars` | 12 | 6-48 | Close after N closed H4 bars |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major; clean oscillator behaviour on H4.
- `GBPUSD.DWX` — liquid major; trends well for confluence entries.
- `USDJPY.DWX` — liquid major; JPY scaling handled via pip-aware stops.
- `XAUUSD.DWX` — gold metal CFD; card's R3 portable basket member, strong H4 swings.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — card targets FX majors + gold only; not in R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | `hours to a few days (≤12 H4 bars unless flipped early)` |
| Expected drawdown profile | `moderate; ATR-capped per-trade catastrophic stop` |
| Regime preference | `trend / momentum confluence` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum/repository (EarnForex GitHub + MQL5)`
**Pointer:** `https://github.com/EarnForex/Trade-Assistant` (article: https://www.earnforex.com/metatrader-indicators/Trade-Assistant/)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11089_trade-asst-conf.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
