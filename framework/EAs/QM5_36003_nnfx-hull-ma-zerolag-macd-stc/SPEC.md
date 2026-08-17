# QM5_36003_nnfx-hull-ma-zerolag-macd-stc — Strategy Spec

**EA ID:** QM5_36003
**Slug:** `nnfx-hull-ma-zerolag-macd-stc`
**Source:** `nnfx-hull-ma-zerolag-macd-stc-official-source` (see `strategy-seeds/sources/nnfx-hull-ma-zerolag-macd-stc/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_36003_nnfx-hull-ma-zerolag-macd-stc.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_36003_nnfx-hull-ma-zerolag-macd-stc.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The high-speed NNFX algorithmic framework on D1 combines Hull Moving Average (Baseline), ZeroLag MACD (C1 Trigger), Schaff Trend Cycle (C2 Confirmation), and Better Volume filter:
- Baseline: Hull Moving Average (HMA 20) evaluated on completed D1 bars (Shift=1).
- C1 Trigger: ZeroLag MACD (fast 12, slow 26, signal 9) comparing ZeroLag MACD line to ZeroLag Signal line.
- C2 Confirmation: Schaff Trend Cycle (STC 23, 50, 10) confirming momentum direction (STC >= 75 for Long, STC <= 25 for Short).
- Volume Gate: Better Volume filter confirming volume expansion on completed bar [1] relative to 20-bar average.
- Long Entry: Close[1] > HMA[1] AND ZL_MACD[1] > ZL_Signal[1] AND STC[1] >= 75.0 AND BetterVol == HIGH.
- Short Entry: Close[1] < HMA[1] AND ZL_MACD[1] < ZL_Signal[1] AND STC[1] <= 25.0 AND BetterVol == HIGH.
- Stop Loss: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Take Profit: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Break-Even: Move SL to Entry + 1.0 pip when open profit reaches +1.0R (1.0x ATR).
- Runner Exit: Close position when ZeroLag MACD crosses opposing signal line (ZL_MACD < ZL_Signal for Long, ZL_MACD > ZL_Signal for Short).
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14, D1)[1]) and rollover blackout 23:55–00:05 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_hma_period` | 20 | 14 - 30 | Hull Moving Average baseline period |
| `strategy_zl_macd_fast` | 12 | 8 - 15 | ZeroLag MACD fast EMA period |
| `strategy_zl_macd_slow` | 26 | 20 - 35 | ZeroLag MACD slow EMA period |
| `strategy_zl_macd_signal` | 9 | 5 - 12 | ZeroLag MACD signal period |
| `strategy_stc_fast` | 23 | 15 - 30 | Schaff Trend Cycle fast MACD period |
| `strategy_stc_slow` | 50 | 40 - 60 | Schaff Trend Cycle slow MACD period |
| `strategy_stc_length` | 10 | 7 - 14 | Schaff Trend Cycle stochastic lookback |
| `strategy_stc_long_thresh` | 75.0 | 70.0 - 80.0 | STC long confirmation threshold |
| `strategy_stc_short_thresh` | 25.0 | 20.0 - 30.0 | STC short confirmation threshold |
| `strategy_vol_avg_period` | 20 | 14 - 30 | Better Volume lookback period |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.00 | 0.8 - 1.5 | Stop loss distance as ATR multiplier |
| `strategy_tp_atr_mult` | 1.00 | 0.8 - 1.5 | Take profit distance as ATR multiplier |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 2.5 | Spread filter ATR multiplier |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA (slot 0)
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA (slot 1)
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA (slot 2)

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "80-160 high-conviction trades per year across 3 pairs" |
| Typical hold time | Daily swing (several D1 bars, up to 1-3 weeks) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Multi-indicator trend consensus with confirmed fast momentum |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-hull-ma-zerolag-macd-stc-official-source`
**Pointer:** `strategy-seeds/sources/nnfx-hull-ma-zerolag-macd-stc/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_36003_nnfx-hull-ma-zerolag-macd-stc.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
