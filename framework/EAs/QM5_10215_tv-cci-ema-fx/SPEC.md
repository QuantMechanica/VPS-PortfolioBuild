# QM5_10215_tv-cci-ema-fx - Strategy Spec

**EA ID:** QM5_10215
**Slug:** `tv-cci-ema-fx`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades H1 CCI reversals in the direction of an EMA trend filter. A long signal appears when CCI(20) on HLC3 crosses above its SMA(14) smoothing line while the closed-bar CCI value is between -100 and 0, with EMA50 above EMA200 when the trend filter is enabled. A short signal mirrors this rule: CCI crosses below the smoothing line while CCI is between 0 and +100, with EMA50 below EMA200 when enabled. Positions exit by fixed stop-loss, fixed take-profit, or by closing an open position when the opposite valid signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | `PERIOD_M1`-`PERIOD_MN1` | Timeframe used for the CCI and EMA signal reads. |
| `strategy_cci_period` | `20` | `1+` | CCI lookback period on HLC3. |
| `strategy_cci_sma_period` | `14` | `1+` | SMA length used to smooth CCI values. |
| `strategy_ema_fast_period` | `50` | `1+` | Fast EMA period for the trend filter. |
| `strategy_ema_slow_period` | `200` | `1+` | Slow EMA period for the trend filter. |
| `strategy_trend_filter` | `true` | `true` / `false` | Enables the EMA50 versus EMA200 direction gate from the card. |
| `strategy_stop_loss_pct` | `0.50` | `>0` | Fixed stop distance as a percent of entry price. |
| `strategy_take_profit_pct` | `0.50` | `>0` | Fixed take-profit distance as a percent of entry price. |
| `strategy_max_spread_points` | `80` | `0+` | Blocks new trading when current spread exceeds this many points; `0` disables. |
| `strategy_time_filter_enabled` | `false` | `true` / `false` | Optional broker-hour trading window gate. |
| `strategy_start_hour_broker` | `0` | `0`-`23` | Start hour for the optional broker-time gate. |
| `strategy_end_hour_broker` | `24` | `0`-`24` | End hour for the optional broker-time gate. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Explicitly named major FX pair and one of the source's top-performing examples.
- `USDCAD.DWX` - Explicitly named major FX pair and one of the source's top-performing examples.
- `GBPJPY.DWX` - Explicitly named major FX cross and one of the source's top-performing examples.
- `GBPUSD.DWX` - Card-listed liquid FX cross-check symbol.
- `XAUUSD.DWX` - Card-listed liquidity and volatility cross-check symbol.

**Explicitly NOT for:**
- Any `.DWX` symbol outside the five registered rows above - the card defines a bounded FX/gold test universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | not specified in card; fixed SL/TP and opposite-signal exit imply hours to days |
| Expected drawdown profile | fixed-risk mean-reversion drawdown bounded by V5 risk and stop-loss controls |
| Regime preference | mean-reversion entries aligned to EMA trend filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `Commodity Channel Index CCI + EMA strategy`, author handle `Burdiga84`, published 2025-12-28, https://www.tradingview.com/script/R1oQ3nrw/
**R1-R4 verdict (Q00):** all PASS - see `artifacts/cards_approved/QM5_10215_tv-cci-ema-fx.md`

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
| v1 | 2026-06-09 | Initial build from card | 55abec41-cbfe-4c40-b86f-cf9830cca73f |
