# QM5_10525_mql5-mamacd - Strategy Spec

**EA ID:** QM5_10525
**Slug:** `mql5-mamacd`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed M15 bars. It opens long when the 5-period SMA on close crosses above both the 85-period and 75-period SMAs on low, with MACD(12,26,9) above zero or rising versus the prior closed bar. It opens short on the inverse cross when MACD is below zero or falling. Positions use an ATR-normalized hard stop, a fixed broker-point take profit, and close early on the opposite fast-MA cross when enabled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ma_period` | 5 | `>0` | Fast SMA period applied to close prices. |
| `strategy_slow_ma_period_1` | 85 | `> strategy_fast_ma_period` | First slow SMA period applied to low prices. |
| `strategy_slow_ma_period_2` | 75 | `> strategy_fast_ma_period` | Second slow SMA period applied to low prices. |
| `strategy_macd_fast_period` | 12 | `>0` and `< strategy_macd_slow_period` | MACD fast EMA period. |
| `strategy_macd_slow_period` | 26 | `> strategy_macd_fast_period` | MACD slow EMA period. |
| `strategy_macd_signal_period` | 9 | `>0` | MACD signal period. |
| `strategy_atr_period` | 14 | `>0` | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 1.0 | `>0` | Stop distance as a multiple of ATR. |
| `strategy_take_profit_points` | 20 | `>0` | Take-profit distance in broker points. |
| `strategy_close_opposite_cross` | true | `true/false` | Close an open position when the opposite fast-MA cross occurs. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - R3 P2 basket forex pair with DWX M15 OHLC available.
- `EURUSD.DWX` - R3 P2 basket forex pair with DWX M15 OHLC available.
- `GBPUSD.DWX` - R3 P2 basket forex pair with DWX M15 OHLC available.
- `AUDUSD.DWX` - R3 P2 basket forex pair with DWX M15 OHLC available.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must retain the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data contract exists for them.

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
| Trades / year / symbol | `240` |
| Typical hold time | M15 fast-cross system with small fixed targets; expected minutes to hours. |
| Expected drawdown profile | Frequent small wins/losses with ATR-normalized downside per trade. |
| Regime preference | Trend-following / MACD-confirmed momentum. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/19334`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10525_mql5-mamacd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-29 | Initial build from card | a635810b-ea07-4e91-b37d-a2ca8ddf8f47 |
