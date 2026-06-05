# QM5_10830_tv-ts461-sweep - Strategy Spec

**EA ID:** QM5_10830
**Slug:** `tv-ts461-sweep`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a one-candle liquidity sweep reversal on the closed bar. A long signal requires a bearish previous candle, a sweep below that candle's low without breaking above its high, and a bullish close back above the previous low. A short signal mirrors this through the previous high, and exits are only the initial stop or the configured R-multiple take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_use_ema_filter` | `false` | `true/false` | Enables the optional EMA trend filter from the card. |
| `strategy_ema_period` | `200` | `1+` | EMA period used when the trend filter is enabled. |
| `strategy_rr_target` | `1.5` | `>0` | Take-profit distance as a multiple of stop distance. |
| `strategy_stop_buffer_ticks` | `2` | `0+` | Tick buffer beyond the sweep candle wick for the stop. |
| `strategy_session_enabled` | `true` | `true/false` | Enables the optional London+New York session gate. |
| `strategy_session_start_h` | `8` | `0-23` | Broker-time session start hour. |
| `strategy_session_end_h` | `22` | `0-23` | Broker-time session end hour; wraps if before start. |
| `strategy_atr_period` | `14` | `1+` | ATR period for sweep-candle range filtering. |
| `strategy_use_atr_bounds` | `true` | `true/false` | Enables the card's ATR range bound filter. |
| `strategy_min_range_atr` | `0.25` | `>=0` | Minimum sweep candle range as ATR multiple. |
| `strategy_max_range_atr` | `2.5` | `>0` | Maximum sweep candle range as ATR multiple. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - source market and primary short-term sweep market from the card.
- `EURUSD.DWX` - card R3 states FX candles are testable and portable.
- `GBPUSD.DWX` - card R3 states FX candles are testable and portable.
- `GDAXI.DWX` - registered DWX DAX custom symbol used for the card's GER40 exposure.
- `NDX.DWX` - card R3 states index CFDs are testable and portable.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX` for DAX exposure.
- `SP500.DWX` - not in the card's primary P2 basket for this build.

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
| Trades / year / symbol | `180` |
| Typical hold time | Short-term M15 stop-or-target hold from the approved card body. |
| Expected drawdown profile | High-cadence sweep reversal with spread sensitivity and false reversals in strong directional sessions. |
| Regime preference | Liquidity-sweep reversal with optional trend filter. |
| Win rate target (qualitative) | Medium; baseline target is 1.5R and stop/TP-only exits. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `Strategy 461 - TS M15`, author handle `Fran_Pineda`, https://www.tradingview.com/script/8Evzyktw/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10830_tv-ts461-sweep.md`

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
| v1 | 2026-06-06 | Initial build from card | e9535373-5d3b-45d5-85eb-534e522351b7 |
