# QM5_35002_hlhb-trend-catcher-system — Strategy Spec

**EA ID:** QM5_35002
**Slug:** `hlhb-trend-catcher-system`
**Source:** `hlhb-trend-catcher-system-official-source` (see `strategy-seeds/sources/hlhb-trend-catcher-system/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_35002_hlhb-trend-catcher-system.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_35002_hlhb-trend-catcher-system.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The HLHB (Huck Loves Her Bucks) system catches sustained H1 trends using 5/10 EMA crossover triggers filtered by RSI(10) > 50 / < 50 and ADX(14) >= 25 trend strength confirmation:
- Long Entry: `EMA(5)[1] > EMA(10)[1]` AND `EMA(5)[2] <= EMA(10)[2]` AND `RSI(10)[1] > 50.0` AND `ADX(14)[1] >= 25.0` AND `+DI[1] > -DI[1]`.
- Short Entry: `EMA(5)[1] < EMA(10)[1]` AND `EMA(5)[2] >= EMA(10)[2]` AND `RSI(10)[1] < 50.0` AND `ADX(14)[1] >= 25.0` AND `-DI[1] > +DI[1]`.
- Stop Loss: 50.0 pips fixed stop loss (clamped between 0.5x and 3.5x ATR(14)).
- Take Profit: 2.0x SL distance (1:2.0 Risk:Reward ratio -> 100.0 pips).
- Trailing Stop: Once trade achieves +30.0 pips profit, trail SL at 50.0 pips behind current market price.
- No-Trade Filter: Rollover blackout 23:55-00:05 and dynamic spread filter (spread > 1.8 * ATR(14)).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema` | 5 | 3 - 8 | Fast EMA period on H1 |
| `strategy_slow_ema` | 10 | 8 - 15 | Slow EMA period on H1 |
| `strategy_rsi_period` | 10 | 7 - 14 | RSI period for momentum filter |
| `strategy_adx_period` | 14 | 10 - 20 | ADX period for trend strength |
| `strategy_adx_min` | 25.0 | 20.0 - 30.0 | Minimum ADX threshold |
| `strategy_sl_pips` | 50.0 | 30.0 - 80.0 | Initial Stop Loss distance in pips |
| `strategy_trail_trigger_pips` | 30.0 | 20.0 - 50.0 | Trailing trigger profit in pips |
| `strategy_trail_dist_pips` | 50.0 | 30.0 - 80.0 | Trailing Stop distance in pips |
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
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | see `Strategy_*` hooks in the .mq5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | Intraday / multi-day trend capture |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Sustained trend regimes on H1 |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `hlhb-trend-catcher-system-official-source`
**Pointer:** `strategy-seeds/sources/hlhb-trend-catcher-system/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_35002_hlhb-trend-catcher-system.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
