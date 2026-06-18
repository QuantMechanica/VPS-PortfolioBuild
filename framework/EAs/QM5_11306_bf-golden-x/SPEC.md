# QM5_11306_bf-golden-x — Strategy Spec

**EA ID:** QM5_11306
**Slug:** `bf-golden-x`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A golden-cross trend strategy with a regime and momentum filter, evaluated on
closed M15 bars. The single trigger EVENT is a fresh cross of EMA(20) over
EMA(50): a bullish "golden" cross arms a long, a bearish "death" cross arms a
short. The cross is accepted if it occurred on the current or any of the prior
two closed bars (a small lookback window so the cross EVENT need not coincide on
the exact same bar as the filter STATES — this is the deliberate anti-zero-trade
design). Two STATE filters then confirm: the regime filter requires close above
EMA(100) for longs (below for shorts), and the momentum filter requires RSI(14)
above 50 for longs (below 50 for shorts). On confirmation, the EA opens one
position with a fixed-percent stop (1.5% of entry) and fixed-percent take-profit
(1.0% of entry). It exits early on the opposite cross EVENT (death cross closes
a long, golden cross closes a short). One position per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 20 | 5-50 | Fast EMA of the golden-cross pair |
| `strategy_ema_slow_period` | 50 | 20-150 | Slow EMA of the golden-cross pair |
| `strategy_ema_regime_period` | 100 | 50-300 | Regime trend filter EMA (close vs this) |
| `strategy_cross_lookback` | 3 | 1-10 | Closed bars back to accept a fresh cross EVENT |
| `strategy_rsi_period` | 14 | 5-30 | RSI lookback period |
| `strategy_rsi_level` | 50.0 | 30-70 | RSI momentum gate (>level long, <level short) |
| `strategy_sl_pct` | 1.5 | 0.3-5.0 | Stop distance as percent of entry price |
| `strategy_tp_pct` | 1.0 | 0.3-5.0 | Take-profit distance as percent of entry price |
| `strategy_spread_pct_of_stop` | 15.0 | 1-50 | Skip if spread exceeds this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major; EMA/RSI trend signals are portable to it (card R3 PASS).
- `GBPUSD.DWX` — liquid FX major; same close-derived indicator basis.
- `XAUUSD.DWX` — gold trends well, suits a golden-cross trend filter.
- `NDX.DWX` — Nasdaq 100 index CFD with persistent trend regimes.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only custom symbol; not in this card's R3 basket, no need to expand.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~60` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate; trend-following whipsaw in ranges` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `forum` (open-source GitHub trading bot repository)
**Pointer:** `https://github.com/conor19w/Binance-Futures-Trading-Bot/blob/main/TradingStrats.py` (goldenCross())
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11306_bf-golden-x.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
