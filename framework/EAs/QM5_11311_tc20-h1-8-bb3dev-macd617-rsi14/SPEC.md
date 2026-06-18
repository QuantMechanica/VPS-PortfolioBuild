# QM5_11311_tc20-h1-8-bb3dev-macd617-rsi14 — Strategy Spec

**EA ID:** QM5_11311
**Slug:** `tc20-h1-8-bb3dev-macd617-rsi14`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On the close of each H1 bar, the EA looks for a fresh crossover of the fast EMA(3)
through the middle line of a 3-sigma Bollinger Band (the 20-period SMA). That
crossover is the single trigger event: a cross above the middle line arms a long,
a cross below arms a short. Two confirmation states must already hold on the same
closed bar — MACD(6,17,1) main must be positive for a long (negative for a short),
and RSI(14) must be above 50 for a long (below 50 for a short). MACD may be
negative; only its sign is read, never a second cross. The stop is the nearer of
the recent swing structure or the Bollinger band on the trade's side, with an
ATR(14)x1.5 fallback. The take-profit is the opposite 3-sigma Bollinger band, or
a fixed 50-pip target if that band is not yet beyond entry. Exit is by static
SL/TP only.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 3 | 2-10 | Fast EMA that crosses the BB middle line |
| `strategy_bb_period` | 20 | 10-50 | Bollinger period; middle = SMA(period) |
| `strategy_bb_deviation` | 3.0 | 1.0-3.0 | BB standard-deviation multiple (3-sigma per card) |
| `strategy_macd_fast` | 6 | 3-12 | MACD fast EMA period |
| `strategy_macd_slow` | 17 | 13-26 | MACD slow EMA period |
| `strategy_macd_signal` | 1 | 1-9 | MACD signal period (main-line sign used) |
| `strategy_rsi_period` | 14 | 7-21 | RSI period for the midline state |
| `strategy_rsi_level` | 50.0 | 40.0-60.0 | RSI midline threshold for the directional state |
| `strategy_struct_lookback` | 10 | 5-30 | Swing-structure lookback for the stop |
| `strategy_atr_period` | 14 | 7-21 | ATR period for the fallback stop |
| `strategy_sl_atr_mult` | 1.5 | 1.0-3.0 | ATR fallback stop distance multiple |
| `strategy_tp_fallback_pips` | 50 | 20-100 | Fixed TP when BB band not beyond entry |
| `strategy_spread_pct_of_stop` | 20.0 | 5.0-50.0 | Skip if spread exceeds this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; tight spreads suit a 50-pip/BB-band H1 target.
- `GBPUSD.DWX` — liquid major with enough H1 range to reach the 3-sigma bands.
- `USDJPY.DWX` — liquid major; pip-scaling handled via `QM_StopRules*` helpers.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card is a forex H1 strategy with pip-based
  fallback targets calibrated to FX volatility.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~90` |
| Typical hold time | `hours` |
| Expected drawdown profile | `moderate; single position per magic, SL at structure/BB or 1.5x ATR` |
| Regime preference | `trend / momentum-confirmation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** `Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Forex Trading Strategy #8 (local PDF archive)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11311_tc20-h1-8-bb3dev-macd617-rsi14.md`

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
| v1 | 2026-06-18 | Initial build from card | central-step registration/compile pending |
