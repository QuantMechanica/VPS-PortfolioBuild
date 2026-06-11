# QM5_12368_tmom-channel - Strategy Spec

**EA ID:** QM5_12368
**Slug:** `tmom-channel`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates once per completed D1 bar. It builds a 20-bar close channel: the upper band is the highest close in the lookback and the lower band is the lowest close in the lookback. It enters long when the latest completed close is at or below the lower band, and enters short when the latest completed close is at or above the upper band. It closes a long when a completed close reaches the channel middle or the opposite upper band, closes a short when a completed close reaches the channel middle or opposite lower band, and uses a 1.5 x ATR(14) hard stop from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | D1 baseline | Timeframe used for channel, ATR, and closed-bar logic. |
| `strategy_channel_type` | `STRATEGY_CHANNEL_DONCHIAN` | Donchian or Bollinger | Channel construction mode for P3 variants; P2 baseline is Donchian. |
| `strategy_lookback` | `20` | 10-40 card test range | Number of completed bars in the channel. |
| `strategy_warmup_bars` | `60` | 60 or higher | Minimum completed bars required before trading. |
| `strategy_atr_period` | `14` | 14 baseline | ATR period for the protective hard stop and optional width gate. |
| `strategy_atr_sl_mult` | `1.5` | 1.0-2.0 card test range | ATR multiplier for the hard stop. |
| `strategy_bollinger_deviation` | `2.0` | 1.5-2.5 card test range | Standard-deviation setting when channel type is Bollinger. |
| `strategy_require_width_atr` | `false` | true or false | Enables the optional P3 channel-width filter. |
| `strategy_min_width_atr_mult` | `1.0` | 1.0 baseline | Minimum channel width expressed as ATR multiple when the width filter is enabled. |
| `strategy_max_spread_points` | `0` | 0 or positive | Optional spread cap; 0 disables the cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with D1 close data.
- `GBPUSD.DWX` - card-listed liquid FX major with D1 close data.
- `USDJPY.DWX` - card-listed liquid FX major with D1 close data.
- `XAUUSD.DWX` - card-listed liquid metal with D1 close data.
- `GDAXI.DWX` - DAX custom symbol available in the DWX matrix; used as the port for card-listed `GER40.DWX`.
- `NDX.DWX` - card-listed liquid US index CFD with D1 close data.
- `WS30.DWX` - card-listed liquid US index CFD with D1 close data.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SP500.DWX` - card marks it optional backtest-only, not part of the primary P2 basket for this build.

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
| Trades / year / symbol | `24` |
| Typical hold time | `several days, until middle-band exit or ATR stop` |
| Expected drawdown profile | `Moderate; main risk is fading persistent breakouts and breakdowns.` |
| Regime preference | `mean-reversion, channel, threshold-entry, middle-band-exit, atr-hard-stop, long-short` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `GitHub repository`
**Pointer:** `ThewindMom/151-trading-strategies, src/strategies/stocks/channel.py, https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/stocks/channel.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12368_tmom-channel.md`

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
| v1 | 2026-06-11 | Initial build from card | 7f01e322-8ce3-4eb7-899d-133d90eee964 |
