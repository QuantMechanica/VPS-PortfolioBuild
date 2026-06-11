# QM5_11841_ait-triple-rsi — Strategy Spec

**EA ID:** QM5_11841
**Slug:** `ait-triple-rsi`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Long-only D1 trend-following strategy using three RSI periods (20/60/120) for multi-timeframe confirmation. An entry fires when RSI(120) is above 55 (long-term trend positive), RSI(60) is below 75 (medium-term not overbought), and the last three RSI(20) values are all above 55 with the current RSI(20) having risen more than 2% versus two bars ago. A hard stop is placed 2.5 × ATR(14) below entry. The position is closed when the D1 close falls below SMA(60) and the holding period exceeds 60 calendar days.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_short` | 20 | 14–30 | RSI short period (TripleRSI tier 1) |
| `strategy_rsi_mid` | 60 | 40–80 | RSI medium period (TripleRSI tier 2) |
| `strategy_rsi_long` | 120 | 80–150 | RSI long period (TripleRSI tier 3) |
| `strategy_oversold` | 55.0 | 45–65 | RSI(long/short) lower threshold for entry |
| `strategy_overbought` | 75.0 | 65–85 | RSI(mid) upper threshold (entry blocked if exceeded) |
| `strategy_rsi_mom_pct` | 2.0 | 0.5–5.0 | Min % RSI(short) rise over 2 bars (momentum filter) |
| `strategy_sma_exit_period` | 60 | 20–100 | SMA period for trend-exit filter |
| `strategy_min_hold_days` | 60 | 20–120 | Min calendar days before SMA exit is allowed |
| `strategy_atr_period` | 14 | 7–21 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 2.5 | 1.5–4.0 | ATR multiplier for stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair; D1 RSI confirmation effective on trending moves
- `GBPUSD.DWX` — major FX pair; similar trend characteristics to EURUSD
- `USDJPY.DWX` — major FX pair; strong trending behaviour suits multi-RSI confirmation
- `XAUUSD.DWX` — gold; extended trending periods make long-only RSI confirmation viable
- `GDAXI.DWX` — DAX 40 index; ported from card's GER40.DWX (same instrument, DWX canonical name)
- `NDX.DWX` — Nasdaq 100; strong trend structure benefits from long-only RSI filter
- `WS30.DWX` — Dow 30; correlated US index provides diversification across US market

**Explicitly NOT for:**
- `SP500.DWX` — card lists as optional backtest-only; excluded from primary basket
- Short-term (M15/H1) charts — RSI(120) needs D1 history depth for meaningful signal

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (all RSI/SMA/ATR read from D1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~6 |
| Typical hold time | 60–120+ days |
| Expected drawdown profile | Up to ~18% peak-to-trough; long holding periods expose to trend reversals |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** forum / GitHub
**Pointer:** `https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/rsi.py`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11841_ait-triple-rsi.md`

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
| v1 | 2026-06-11 | Initial build from card | cf5a75b7-3bd9-48e0-bffd-42ad73e07736 |
