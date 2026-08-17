# QM5_35001_cowabunga-multi-timeframe-trend-system — Strategy Spec

**EA ID:** QM5_35001
**Slug:** `cowabunga-multi-timeframe-trend-system`
**Source:** `cowabunga-multi-timeframe-trend-system-official-source` (see `strategy-seeds/sources/cowabunga-multi-timeframe-trend-system/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_35001_cowabunga-multi-timeframe-trend-system.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_35001_cowabunga-multi-timeframe-trend-system.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The Cowabunga System uses H4 to determine macro trend direction (EMA 5/10 cross + RSI 9 > 50 / < 50) and M15 for precise 5/10 EMA crossover triggers filtered by RSI(9), Stochastic(10,3,3), and MACD(12,26,9) histogram slope.
- Long Entry: H4 Trend UP (EMA5 > EMA10 AND RSI9 > 50), M15 EMA5 crosses above EMA10, M15 RSI9 > 50, M15 Stoch_K > Stoch_D AND Stoch_K < 80, M15 MACD Histogram > 0 AND (Hist[1] > Hist[2] OR Hist[2] <= 0).
- Short Entry: H4 Trend DOWN (EMA5 < EMA10 AND RSI9 < 50), M15 EMA5 crosses below EMA10, M15 RSI9 < 50, M15 Stoch_K < Stoch_D AND Stoch_K > 20, M15 MACD Histogram < 0 AND (Hist[1] < Hist[2] OR Hist[2] >= 0).
- Stop Loss: Placed at recent M15 swing low/high buffered by 3.0 pips (clamped between 0.5x and 3.5x ATR(14)).
- Take Profit: 2.0x SL distance (1:2.0 Risk:Reward ratio).
- Trailing / Break-Even: When profit reaches +1.0R, move SL to Break-Even + 1.0 pip.
- No-Trade Filter: Rollover blackout 23:55-00:05 and dynamic spread filter (spread > 1.8 * ATR(14)).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema` | 5 | 3 - 8 | Fast EMA period for M15 and H4 |
| `strategy_slow_ema` | 10 | 8 - 15 | Slow EMA period for M15 and H4 |
| `strategy_rsi_period` | 9 | 7 - 14 | RSI period for momentum filter |
| `strategy_stoch_k` | 10 | 5 - 15 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 2 - 5 | Stochastic %D period |
| `strategy_stoch_slowing` | 3 | 2 - 5 | Stochastic slowing period |
| `strategy_macd_fast` | 12 | 8 - 15 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 20 - 30 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5 - 12 | MACD signal SMA period |
| `strategy_swing_lookback` | 10 | 5 - 20 | Swing high/low lookback bars on M15 |
| `strategy_swing_buffer_pips` | 3.0 | 1.0 - 5.0 | Swing SL buffer distance in pips |
| `strategy_tp_rr_mult` | 2.0 | 1.5 - 3.0 | Risk:Reward multiplier for Take Profit |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for spread/fallback |
| `strategy_spread_atr_mult` | 1.8 | 1.0 - 2.5 | Spread filter ATR multiplier |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_H4` for macro trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | Intraday / swing (several hours) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Trending markets on H4 with clean pullbacks on M15 |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cowabunga-multi-timeframe-trend-system-official-source`
**Pointer:** `strategy-seeds/sources/cowabunga-multi-timeframe-trend-system/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_35001_cowabunga-multi-timeframe-trend-system.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
