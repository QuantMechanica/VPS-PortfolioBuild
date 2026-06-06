# QM5_11022_mql5-macd-env - Strategy Spec

**EA ID:** QM5_11022
**Slug:** `mql5-macd-env`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates a completed H1 bar. It buys when that bar opens below the lower 22-period close-SMA envelope and closes back above it, while the D1 MACD main value rises across three completed D1 bars. It sells when the completed H1 bar opens above the upper envelope and closes back below it, while the D1 MACD main value falls across three completed D1 bars. Open trades exit through fixed SL/TP, optional trailing, framework Friday close, or an opposite signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast_ema` | 15 | 12-20 | Fast EMA period for the D1 MACD main value. |
| `strategy_macd_slow_ema` | 26 | 26-40 | Slow EMA period for the D1 MACD main value. |
| `strategy_macd_signal_period` | 1 | 1 | MACD signal period from the source setup. |
| `strategy_envelopes_period` | 22 | 14-30 | H1 close-SMA period used as the Envelopes center line. |
| `strategy_envelopes_deviation` | 0.3 | 0.2-0.4 | Percent distance of the upper and lower envelope from the SMA. |
| `strategy_sl_points` | 160 | 120-220 | Fixed stop-loss distance in broker points. |
| `strategy_tp_points` | 310 | 200-450 | Fixed take-profit distance in broker points. |
| `strategy_trailing_points` | 50 | 0+ | Optional step trailing distance in points; zero disables trailing. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread ceiling in points; zero disables the spread ceiling. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - original FX example ports directly to the DWX EURUSD feed.
- `GBPUSD.DWX` - liquid major FX pair using the same OHLC indicator mechanics.
- `USDJPY.DWX` - liquid major FX pair using the same OHLC indicator mechanics.
- `XAUUSD.DWX` - card-listed liquid CFD/commodity symbol with DWX OHLC availability.

**Explicitly NOT for:**
- Non-DWX symbols - research and backtest artifacts must use the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom tick data is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` MACD trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Hours to days, bounded by opposite signal, SL/TP, trailing stop, or Friday close |
| Expected drawdown profile | Trend-filtered mean-reversion entries with fixed-loss containment |
| Regime preference | Trend-filtered channel-bounce mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `article`
**Pointer:** `https://www.mql5.com/en/articles/148`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11022_mql5-macd-env.md`

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
| v1 | 2026-06-07 | Initial build from card | 31788b48-e96c-46dd-83d4-0669ed93dd79 |
