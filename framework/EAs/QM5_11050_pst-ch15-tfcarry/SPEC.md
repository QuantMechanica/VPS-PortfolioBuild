# QM5_11050_pst-ch15-tfcarry - Strategy Spec

**EA ID:** QM5_11050
**Slug:** `pst-ch15-tfcarry`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (see `strategy-seeds/sources/352af9de-f372-5cf2-9a86-681a26224597/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates one completed D1 bar at a time. It calculates three capped EWMAC trend forecasts, using EMA(close,16)-EMA(close,64), EMA(close,32)-EMA(close,128), and EMA(close,64)-EMA(close,256), each divided by 60-day daily close-to-close volatility and multiplied by the card's fixed scalars. Because no deterministic historical DWX carry proxy is available, the forecast uses the card's trend-only renormalised weights: 42%, 16%, and 42%, then applies the 1.31 forecast multiplier. It enters long at combined forecast >= +5, enters short at <= -5, exits long at <= +1, and exits short at >= -1; initial emergency stop is 3.0 * ATR(20,D1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_warmup_bars` | 300 | 300+ | Minimum D1 bars before signal evaluation. |
| `strategy_vol_period` | 60 | 2+ | D1 close-to-close volatility lookback. |
| `strategy_ewmac_fast_1` | 16 | 1+ | Fast EMA for first EWMAC component. |
| `strategy_ewmac_slow_1` | 64 | > fast | Slow EMA for first EWMAC component. |
| `strategy_ewmac_fast_2` | 32 | 1+ | Fast EMA for second EWMAC component. |
| `strategy_ewmac_slow_2` | 128 | > fast | Slow EMA for second EWMAC component. |
| `strategy_ewmac_fast_3` | 64 | 1+ | Fast EMA for third EWMAC component. |
| `strategy_ewmac_slow_3` | 256 | > fast | Slow EMA for third EWMAC component. |
| `strategy_entry_forecast` | 5.0 | 3.0-8.0 | Absolute combined forecast threshold for entries. |
| `strategy_exit_forecast` | 1.0 | 0.0-5.0 | Reversal threshold for discretionary exits. |
| `strategy_atr_period` | 20 | 1+ | ATR lookback for emergency stop. |
| `strategy_atr_sl_mult` | 3.0 | 2.5-3.5 | ATR stop multiplier. |
| `strategy_use_carry_proxy` | false | true/false | Reserved switch for future deterministic carry proxy; default trend-only. |
| `strategy_spread_filter_days` | 60 | 0-60 | Observed D1 spread median window; 0 disables spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair with D1 OHLC history for trend following.
- `GBPUSD.DWX` - liquid major FX pair with D1 OHLC history for trend following.
- `USDJPY.DWX` - liquid major FX pair with D1 OHLC history for trend following.
- `AUDUSD.DWX` - liquid major FX pair with D1 OHLC history for trend following.
- `NDX.DWX` - liquid US index CFD compatible with D1 trend following.
- `WS30.DWX` - liquid US index CFD compatible with D1 trend following.
- `XAUUSD.DWX` - liquid metal CFD compatible with D1 trend following.

**Explicitly NOT for:**
- `SP500.DWX` - mentioned as optional backtest-only coverage in the card, but not listed in `target_symbols`.
- Non-DWX symbols - build, research, and backtest artifacts must keep the `.DWX` suffix.

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
| Trades / year / symbol | 35 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Diversified slow trend/carry profile with ATR-capped emergency risk. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** book / public GitHub config
**Pointer:** `https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/futures_chapter15/futuresconfig.yaml`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11050_pst-ch15-tfcarry.md`

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
| v1 | 2026-06-07 | Initial build from card | 95effc17-9698-4a71-a34e-65150ce16805 |
