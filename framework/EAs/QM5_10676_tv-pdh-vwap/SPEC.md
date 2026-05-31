# QM5_10676_tv-pdh-vwap - Strategy Spec

**EA ID:** QM5_10676
**Slug:** `tv-pdh-vwap`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView open-source strategy)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA trades prior-day high and prior-day low liquidity sweeps on intraday bars. A long setup requires the last closed candle to trade below the prior day low, close back above that level, and also close above both session VWAP and the EMA trend filter. A short setup mirrors this at the prior day high: the candle trades above the prior day high, closes back below it, and closes below both VWAP and the EMA. Positions use ATR-based stop loss and take profit, allow only one position per symbol/magic, optionally allow only one trade per session day, and flatten after the configured session ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_index_period` | 200 | 1-500 | EMA trend-filter period for index and metal symbols. |
| `strategy_ema_fx_period` | 100 | 1-500 | EMA trend-filter period for FX symbols. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used for stop and target distance. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiple for the baseline stop loss. |
| `strategy_atr_tp_mult` | 2.0 | 0.1-20.0 | ATR multiple for the baseline take profit. |
| `strategy_structure_extra_atr_max` | 0.5 | 0.0-5.0 | Maximum extra ATR distance allowed when moving the stop beyond the swept candle extreme. |
| `strategy_session_filter_enabled` | true | true/false | Enables entry filtering and session-end flattening. |
| `strategy_one_trade_per_day` | true | true/false | Allows only one entry per session day. |
| `strategy_session_start_hour` | -1 | -1-23 | Optional broker-hour override for session start; -1 uses symbol preset. |
| `strategy_session_start_minute` | -1 | -1-59 | Optional broker-minute override for session start; -1 uses symbol preset. |
| `strategy_session_end_hour` | -1 | -1-23 | Optional broker-hour override for session end; -1 uses symbol preset. |
| `strategy_session_end_minute` | -1 | -1-59 | Optional broker-minute override for session end; -1 uses symbol preset. |
| `strategy_spread_stop_fraction` | 0.10 | 0.0-1.0 | Maximum spread as a fraction of ATR stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index sweep target from the card's primary basket.
- `WS30.DWX` - Dow 30 index sweep target from the card's primary basket.
- `GDAXI.DWX` - DAX proxy registered because `GER40.DWX` is named in the card but only `GDAXI.DWX` is present in the DWX matrix.
- `EURUSD.DWX` - Major FX pair from the card's primary basket, with the card's 100-EMA FX preset.
- `XAUUSD.DWX` - Gold/metal target from the card's primary basket.

**Explicitly NOT for:**
- `GER40.DWX` - Not registered because it is absent from `dwx_symbol_matrix.csv`.
- Symbols outside `dwx_symbol_matrix.csv` - Build discipline forbids phantom registrations.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | Prior day high/low from `D1`; EMA, VWAP, and ATR on current chart timeframe |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` from card frontmatter |
| Typical hold time | Intraday; exits by ATR target/stop or session end |
| Expected drawdown profile | Moderate intraday false-breakout drawdown; fixed $1,000 risk per backtest trade |
| Regime preference | Liquidity sweep reversal with VWAP and trend-filter confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/0mlIctOY/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10676_tv-pdh-vwap.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | 1cd0a143-6f6c-498d-a8d5-9091d73800e8 |
