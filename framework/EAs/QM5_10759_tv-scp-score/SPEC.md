# QM5_10759_tv-scp-score - Strategy Spec

**EA ID:** QM5_10759
**Slug:** tv-scp-score
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades a fixed Smart Money Concepts confluence score on closed M15 or H1 bars. It scores bullish and bearish setups from a confirmed swing break, order-block or fair-value-gap alignment, equal-level liquidity sweeps, discount or premium/OTE location, and nearby support/resistance clustering. A long opens when the bullish score reaches the configured threshold and price is in discount or bullish FVG context; a short mirrors the rule in premium or bearish FVG context. Stops use the last confirmed swing high/low plus an ATR(14) buffer and are capped by a maximum ATR distance; targets are fixed R:R and stale setups close after the configured bar count.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_min_score` | 3 | 2-8 | Minimum confluence score required for entry. |
| `strategy_pivot_length` | 8 | 2-30 | Bars on each side used to confirm swing pivots. |
| `strategy_scan_bars` | 120 | 60-300 | Closed bars scanned for swings, equal levels, FVGs, and OB approximations. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for stop buffer and equal-level tolerances. |
| `strategy_atr_buffer_mult` | 0.20 | 0.0-1.0 | ATR buffer added beyond the swing stop. |
| `strategy_atr_max_stop_mult` | 4.00 | 1.0-10.0 | Maximum stop distance as ATR multiple. |
| `strategy_target_rr` | 2.00 | 1.0-5.0 | Fixed reward:risk target multiple. |
| `strategy_expiry_bars` | 20 | 1-80 | Bars after which a stale open trade is closed. |
| `strategy_equal_level_lookback` | 24 | 6-80 | Lookback for equal high/low liquidity levels. |
| `strategy_equal_atr_tolerance` | 0.15 | 0.01-0.50 | ATR tolerance used to classify equal highs/lows. |
| `strategy_cluster_atr_tolerance` | 0.25 | 0.01-1.00 | ATR distance for S/R clustering points. |
| `strategy_session_mode` | 3 | 0-3 | Session filter: all, London, New York, or London/New York overlap. |
| `strategy_london_start_hour` | 8 | 0-23 | Broker-hour start for London session. |
| `strategy_london_end_hour` | 17 | 0-23 | Broker-hour end for London session. |
| `strategy_newyork_start_hour` | 13 | 0-23 | Broker-hour start for New York session. |
| `strategy_newyork_end_hour` | 22 | 0-23 | Broker-hour end for New York session. |
| `strategy_allow_long` | true | true/false | Enables long entries. |
| `strategy_allow_short` | true | true/false | Enables short entries. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap; 0 disables the cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with OHLC, ATR, session, and pivot data for SMC scoring.
- `GBPUSD.DWX` - FX major with liquid intraday structure for the same confluence rules.
- `USDJPY.DWX` - FX major from the card's portable basket.
- `XAUUSD.DWX` - Metal symbol corresponding to the card's XAUUSD target.
- `GDAXI.DWX` - Available DAX custom symbol used in place of card-stated `GER40.DWX`.
- `NDX.DWX` - Liquid US index symbol from the card's portable basket.
- `WS30.DWX` - Liquid US index symbol from the card's portable basket.
- `SP500.DWX` - Optional card-listed S&P 500 backtest-only custom symbol.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX custom symbols for S&P 500.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` and `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | 10-40 bars, bounded by setup expiry |
| Expected drawdown profile | Moderate; fixed 2R target and capped swing stops reduce single-trade tail risk. |
| Regime preference | Liquidity sweep / structural reversal with volatility expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView invite-only strategy page
**Pointer:** https://www.tradingview.com/script/FudHDFuT/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10759_tv-scp-score.md`

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
| v1 | 2026-05-31 | Initial build from card | ec39084a-e5ba-48a8-b7d2-a2d6be9ea9fa |
