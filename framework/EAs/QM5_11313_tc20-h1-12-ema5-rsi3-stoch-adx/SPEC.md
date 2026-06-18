# QM5_11313_tc20-h1-12-ema5-rsi3-stoch-adx — Strategy Spec

**EA ID:** QM5_11313
**Slug:** `tc20-h1-12-ema5-rsi3-stoch-adx`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Thomas Carter TC20 Strategy #12: a five-condition trend-confluence trigger on H1.
The macro trend gate is EMA(34,close) vs EMA(89,close). On the signal (closed) bar
four states must align and one fresh event must fire. Long: EMA34 above EMA89,
Stochastic(5,3,3) %K above %D, ADX(14) +DI above -DI, and RSI(3) has burst into the
overbought zone (>= 80) on the signal bar or within the prior few bars — and the
trigger EVENT is EMA(3,close) crossing above EMA(5,open). Short mirrors with EMA34
below EMA89, %K below %D, -DI above +DI, RSI(3) <= 20 burst, and EMA(3,close) crossing
below EMA(5,open). To avoid the two-crossover-same-bar zero-trade trap, only the
EMA3/5 micro cross is a fresh event; RSI3 burst and the others are states. Stop is the
structural anchor (lower of EMA34 / 5-bar lowest low for longs, plus a pip buffer,
floored to a minimum and capped at 1.5x ATR(14)); take-profit is 2x the stop distance.
Defensive exit on a reverse EMA3/5 cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_macro_fast` | 34 | 10-100 | Macro trend fast EMA (close) |
| `strategy_ema_macro_slow` | 89 | 20-300 | Macro trend slow EMA (close) |
| `strategy_ema_trig_fast` | 3 | 2-10 | Micro trigger fast EMA (close) |
| `strategy_ema_trig_slow` | 5 | 3-15 | Micro trigger slow EMA (open) |
| `strategy_rsi_period` | 3 | 2-14 | RSI burst period |
| `strategy_rsi_burst_hi` | 80.0 | 60-95 | Long burst level (RSI >= this) |
| `strategy_rsi_burst_lo` | 20.0 | 5-40 | Short burst level (RSI <= this) |
| `strategy_rsi_burst_lookback` | 3 | 0-10 | Bars back the burst state may have occurred |
| `strategy_stoch_k` | 5 | 3-21 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 2-10 | Stochastic %D period |
| `strategy_stoch_slow` | 3 | 1-10 | Stochastic slowing |
| `strategy_adx_period` | 14 | 7-28 | ADX / DI period |
| `strategy_struct_lookback` | 5 | 3-20 | Bars for LowestLow/HighestHigh stop |
| `strategy_sl_buffer_pips` | 2.0 | 0-20 | Buffer beyond structure (pips) |
| `strategy_sl_min_pips` | 20.0 | 5-100 | Minimum SL distance (pips) |
| `strategy_atr_period` | 14 | 7-28 | ATR period for SL cap |
| `strategy_atr_cap_mult` | 1.5 | 0.5-5 | SL capped at mult x ATR |
| `strategy_tp_rr` | 2.0 | 1-5 | TP = rr x SL distance |
| `strategy_spread_pct_of_stop` | 25.0 | 5-100 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary H1 major, deep liquidity, card primary instrument
- `GBPUSD.DWX` — second card major, comparable H1 trend behaviour
- `USDJPY.DWX` — card P2 expansion major; pip-scaling handled via QM_StopRules pip factor

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — strategy is FX-major-tuned (RSI3 burst + EMA34/89 calibrated to H1 FX swings)

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
| Trades / year / symbol | `~70` |
| Typical hold time | `hours (intraday-to-multiday H1 swings)` |
| Expected drawdown profile | `moderate; structural stops with 2R targets` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy #12 (2014)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11313_tc20-h1-12-ema5-rsi3-stoch-adx.md`

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
| v1 | 2026-06-18 | Initial build from card | EMA3/5 micro-cross sole trigger; RSI3 burst + Stoch + ADX DI as states |
