# QM5_10656_tv-ob-vol-fvg - Strategy Spec

**EA ID:** QM5_10656
**Slug:** `tv-ob-vol-fvg`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades M15 fair-value-gap mitigation. On each closed bar it scans a bounded recent history for standard bullish or bearish three-candle imbalances, then selects the newest active box whose age, mitigation depth, tick-volume proxy, and optional candle confirmation pass. It opens one market position in the mitigation direction, uses a fixed percentage stop capped by ATR(14), leaves take-profit empty, and starts an ATR trailing stop only after the configured profit trigger is reached. Pyramiding is disabled by the framework one-position check plus duplicate-entry guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fvg_lookback_bars` | 240 | 30-500 | Maximum recent M15 bars scanned for active FVG boxes. |
| `strategy_min_fvg_age_bars` | 20 | 10-30 | Minimum age of an FVG box before mitigation entries are allowed. |
| `strategy_long_mitigation_pct` | 60.0 | 50.0-80.0 | Minimum bullish FVG mitigation depth for long entries. |
| `strategy_short_mitigation_pct` | 60.0 | 50.0-80.0 | Minimum bearish FVG mitigation depth for short entries. |
| `strategy_candle_confirmation` | false | false/true | Require bullish close for long and bearish close for short. |
| `strategy_volume_filter_mode` | 2 | 0-2 | Tick-volume proxy mode: off, minimum total only, or total plus directional share. |
| `strategy_min_tick_volume` | 0.0 | 0+ | Minimum M15 tick volume when volume filtering is enabled. |
| `strategy_min_directional_share` | 0.55 | 0.50-0.80 | Required close-location directional share when mode 2 is enabled. |
| `strategy_stop_percent` | 1.0 | 0.1-3.0 | Fixed stop-loss percentage from entry before ATR cap. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for stop cap and trailing stop. |
| `strategy_atr_stop_cap_mult` | 1.5 | 1.0-2.0 | Maximum stop distance as ATR multiple. |
| `strategy_trailing_trigger_mode` | 1 | 0-1 | Use percent trigger when 0, R-multiple trigger when 1. |
| `strategy_trailing_trigger_pct` | 1.0 | 0.25-3.0 | Percent profit trigger for trailing mode 0. |
| `strategy_trailing_trigger_r` | 1.0 | 0.5-1.5 | R-multiple profit trigger for trailing mode 1. |
| `strategy_trailing_atr_mult` | 1.0 | 0.5-3.0 | ATR trailing stop distance after activation. |
| `strategy_cooldown_bars` | 5 | 0-50 | Entry-to-entry cooldown in chart bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX pair with DWX tick-volume proxy.
- `GBPUSD.DWX` - card-listed liquid FX pair with DWX tick-volume proxy.
- `USDJPY.DWX` - card-listed liquid FX pair with DWX tick-volume proxy.
- `XAUUSD.DWX` - card-listed metal exposure, normalized to canonical DWX suffix.
- `GDAXI.DWX` - canonical DWX DAX symbol for the card's GER40 intent.
- `NDX.DWX` - card-listed US index CFD with DWX OHLC and tick-volume proxy.

**Explicitly NOT for:**
- `GER40.DWX` - not present in the DWX matrix; `GDAXI.DWX` is the registered canonical DAX equivalent.
- `XAUUSD` - unsuffixed research symbol; backtests use `XAUUSD.DWX`.

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
| Trades / year / symbol | `100` |
| Typical hold time | intraday to multi-session, until fixed stop or delayed trailing stop |
| Expected drawdown profile | medium; noisy tick-volume proxy and stale boxes are the main risks |
| Regime preference | volatility retracement / FVG mitigation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/PjH7wg3n/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10656_tv-ob-vol-fvg.md`

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
| v1 | 2026-06-26 | Initial build from card | 29f456e4-5841-4ae4-96dd-967910231c55 |
