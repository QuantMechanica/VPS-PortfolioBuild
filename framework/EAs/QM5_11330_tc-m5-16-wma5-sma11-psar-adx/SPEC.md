# QM5_11330_tc-m5-16-wma5-sma11-psar-adx — Strategy Spec

**EA ID:** QM5_11330
**Slug:** `tc-m5-16-wma5-sma11-psar-adx`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, 20 Forex Trading Strategies — 5 Min System #16)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A trend-following M5 system. Direction is set by three confirming STATES that
must all agree on the just-closed bar: WMA(5) above/below SMA(11), Parabolic SAR
below/above price, and ADX DI+ vs DI- direction. A trade fires only when ONE
fresh trigger EVENT occurs on that bar — either a WMA(5)/SMA(11) crossover or a
Parabolic SAR flip to the trade side — so the EA never waits for two crossovers
on the same bar (the zero-trade trap). Go LONG when all three states are bullish
(WMA>SMA, SAR below price, DI+>DI-) and a fresh MA cross or SAR flip occurs; go
SHORT on the mirror. The stop is the previous swing low (long) / swing high
(short) over a 20-bar structure lookback, with an ATR(14)×1.5 fallback; an
optional RR take-profit (2R) is set. The position is closed on a Parabolic SAR
reversal (SAR crosses to the opposite side of price).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wma_period` | 5 | 3-20 | Fast WMA (LWMA) period |
| `strategy_sma_period` | 11 | 5-50 | Slow SMA period |
| `strategy_psar_step` | 0.01 | 0.005-0.05 | Parabolic SAR acceleration step (corrected from card typo) |
| `strategy_psar_max` | 0.1 | 0.05-0.4 | Parabolic SAR maximum acceleration |
| `strategy_adx_period` | 14 | 7-28 | ADX / DI period |
| `strategy_adx_min` | 0.0 | 0-40 | Optional ADX strength floor (0 = off; card uses DI direction only) |
| `strategy_sl_lookback` | 20 | 5-50 | Swing-structure lookback bars for the stop |
| `strategy_atr_period` | 14 | 7-28 | ATR period (stop fallback + spread reference) |
| `strategy_atr_sl_mult` | 1.5 | 0.5-4.0 | ATR stop multiple (fallback when structure stop invalid) |
| `strategy_tp_rr` | 2.0 | 0-5 | Take-profit as RR multiple of stop distance (0 = PSAR exit only) |
| `strategy_spread_pct_of_stop` | 25.0 | 5-100 | Skip if spread exceeds this % of stop distance (fail-open on zero spread) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, tight liquidity, clean M5 trend behaviour.
- `GBPUSD.DWX` — major FX pair with sufficient M5 directional moves.
- `AUDUSD.DWX` — commodity-linked major, trends on M5 sessions.
- `USDCHF.DWX` — major FX pair, complements the basket for diversification.

All four appear in `framework/registry/dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card targets FX majors on M5; index micro-structure differs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~100` |
| Typical hold time | `minutes to a few hours (M5 trend ride)` |
| Expected drawdown profile | `frequent small stops between captured trends` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #16 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11330_tc-m5-16-wma5-sma11-psar-adx.md`

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
