# QM5_9572_chande-stochrsi-vr-h4 - Strategy Spec

**EA ID:** QM5_9572
**Slug:** chande-stochrsi-vr-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades H4 StochRSI crosses only when short-term ATR is elevated versus longer-term ATR. A long entry requires ATR(7) / ATR(28) above 1.30, the last closed H4 close above EMA(100), RSI(14) above 45, and %K crossing above %D after the prior %K was below 0.15. A short entry mirrors the rule below EMA(100), with RSI(14) below 55 and %K crossing below %D after the prior %K was above 0.85. The EA exits on an opposite StochRSI cross from the opposite half of the oscillator, on two closed H4 bars with VR below 0.90, or after 20 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H4` | H4 expected | Signal timeframe from the card. |
| `strategy_rsi_period` | 14 | 2+ | RSI period used inside StochRSI and reclaim filter. |
| `strategy_stochrsi_lookback` | 14 | 2+ | RSI high-low window for StochRSI normalization. |
| `strategy_stochrsi_k_sma` | 3 | 1+ | SMA smoothing length for %K. |
| `strategy_stochrsi_d_sma` | 3 | 1+ | SMA smoothing length for %D. |
| `strategy_vr_fast_atr_period` | 7 | 1+ | Fast ATR period in the volatility ratio. |
| `strategy_vr_slow_atr_period` | 28 | 1+ | Slow ATR period in the volatility ratio. |
| `strategy_vr_entry_min` | 1.30 | >0 | Minimum VR for new entries. |
| `strategy_vr_exit_max` | 0.90 | >0 | Two-bar VR threshold for protective exit. |
| `strategy_ema_period` | 100 | 2+ | Directional EMA bias period. |
| `strategy_long_pullback_max` | 0.15 | 0.00-1.00 | Prior %K must be below this for long triggers. |
| `strategy_short_pullback_min` | 0.85 | 0.00-1.00 | Prior %K must be above this for short triggers. |
| `strategy_long_rsi_min` | 45.0 | 0-100 | RSI reclaim threshold for longs. |
| `strategy_short_rsi_max` | 55.0 | 0-100 | RSI reclaim threshold for shorts. |
| `strategy_long_exit_k_min` | 0.75 | 0.00-1.00 | Long exit cross must occur after %K reaches this zone. |
| `strategy_short_exit_k_max` | 0.25 | 0.00-1.00 | Short exit cross must occur after %K reaches this zone. |
| `strategy_atr_sl_period` | 14 | 1+ | ATR period for stop loss and spread cap. |
| `strategy_atr_sl_mult` | 1.60 | >0 | Stop loss ATR multiple. |
| `strategy_spread_atr_fraction` | 0.15 | >=0 | Entry block when live spread exceeds this ATR fraction. |
| `strategy_max_hold_bars` | 20 | 1+ | Time stop in closed H4 bars. |
| `strategy_neutral_k_low` | 0.45 | 0.00-1.00 | Lower bound of neutral zone required before same-side re-entry. |
| `strategy_neutral_k_high` | 0.55 | 0.00-1.00 | Upper bound of neutral zone required before same-side re-entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major in the card target basket.
- `GBPUSD.DWX` - FX major in the card target basket.
- `USDJPY.DWX` - FX major in the card target basket.
- `AUDUSD.DWX` - FX major in the card target basket.
- `USDCAD.DWX` - FX major in the card target basket.
- `USDCHF.DWX` - FX major in the card target basket.
- `NZDUSD.DWX` - FX major in the card target basket.
- `XAUUSD.DWX` - Metal CFD in the card target basket.
- `XTIUSD.DWX` - Oil CFD in the card target basket.
- `GDAXI.DWX` - DAX index CFD in the card target basket.
- `NDX.DWX` - Nasdaq 100 index CFD in the card target basket.
- `WS30.DWX` - Dow 30 index CFD in the card target basket.
- `UK100.DWX` - FTSE 100 index CFD in the card target basket.

**Explicitly NOT for:**
- `FRA40.DWX` - Listed by the card but not present in `dwx_symbol_matrix.csv`.
- `JP225.DWX` - Listed by the card but not present in `dwx_symbol_matrix.csv`.
- Non-DWX symbols - Research and backtest artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `28` |
| Typical hold time | Several H4 bars, capped at 20 H4 bars |
| Expected drawdown profile | Volatility-regime trend pullback system with ATR-defined single-trade risk |
| Regime preference | Volatility-expansion trend continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum plus published indicator lineage
**Pointer:** `https://www.forexfactory.com/thread/post/14002860` and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9572_chande-stochrsi-vr-h4.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9572_chande-stochrsi-vr-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 62a8165a-b25f-42e5-aa28-8df15d5b4334 |
