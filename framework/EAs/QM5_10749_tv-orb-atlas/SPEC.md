# QM5_10749_tv-orb-atlas - Strategy Spec

**EA ID:** QM5_10749
**Slug:** `tv-orb-atlas`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades an intraday opening-range breakout on M5 bars during the broker-time mapping of US regular trading hours. It records the high and low of the first configured number of session minutes, locks that range, then buys when a closed M5 bar confirms above the opening-range high plus ATR padding or sells when it confirms below the opening-range low minus ATR padding. The opening range must be neither too small nor too large relative to ATR, and the optional higher-timeframe EMA slope gate can restrict trade direction. Exits are handled by the initial stop, the target, an optional maximum holding time, and a pre-session-close flatten.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hhmm` | 1630 | 0000-2359 | Broker-time session start used for the New York RTH mapping. |
| `strategy_session_end_hhmm` | 2300 | 0000-2359 | Broker-time session end used for the New York RTH mapping. |
| `strategy_opening_range_minutes` | 15 | 5-60 | Number of first session minutes used to build the opening range. |
| `strategy_atr_period` | 14 | 1+ | ATR period on the chart timeframe. |
| `strategy_min_or_atr` | 0.50 | 0.0+ | Minimum opening-range size divided by ATR. |
| `strategy_max_or_atr` | 3.00 | 0.0+ | Maximum opening-range size divided by ATR. |
| `strategy_padding_atr_fraction` | 0.15 | 0.0+ | ATR fraction added beyond the range boundary for confirmation. |
| `strategy_use_htf_ema_slope` | false | true/false | Enables the higher-timeframe EMA slope direction gate. |
| `strategy_htf_tf` | H1 | M5-D1 | Timeframe for the EMA slope gate. |
| `strategy_htf_ema_period` | 100 | 2+ | EMA period for the slope gate. |
| `strategy_stop_mode` | STRATEGY_STOP_OPPOSITE_OR | enum | Uses either opposite opening-range boundary or ATR multiple for the stop. |
| `strategy_atr_stop_mult` | 1.50 | 0.0+ | ATR stop multiple when ATR stop mode is selected. |
| `strategy_target_mode` | STRATEGY_TARGET_RR | enum | Uses R:R, opening-range multiple, or ATR multiple target. |
| `strategy_rr_target` | 2.00 | 0.0+ | Reward-to-risk target when R:R target mode is selected. |
| `strategy_or_target_mult` | 1.00 | 0.0+ | Opening-range multiple target when OR target mode is selected. |
| `strategy_atr_target_mult` | 2.00 | 0.0+ | ATR target multiple when ATR target mode is selected. |
| `strategy_exit_before_close` | true | true/false | Enables flat-before-session-close exit. |
| `strategy_flat_hhmm` | 2255 | 0000-2359 | Broker time at or after which positions are closed and new entries blocked. |
| `strategy_max_hold_minutes` | 0 | 0+ | Optional time stop in minutes; 0 disables it. |
| `strategy_max_spread_points` | 0.0 | 0.0+ | Optional spread filter in points; 0 disables it. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure from the card's primary P2 basket.
- `WS30.DWX` - Dow 30 index exposure from the card's primary P2 basket.
- `GDAXI.DWX` - Canonical DWX DAX symbol, used for the card's GER40 basket member.
- `XAUUSD.DWX` - Gold exposure from the card's primary P2 basket.
- `EURUSD.DWX` - Major FX pair from the card's primary P2 basket.
- `GBPUSD.DWX` - Major FX pair from the card's primary P2 basket.
- `SP500.DWX` - Optional backtest-only S&P 500 symbol noted by the card and available in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - Card wording names GER40, but the DWX matrix contains `GDAXI.DWX` as the canonical DAX symbol.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not valid DWX custom-symbol names in the matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | Optional EMA slope gate on `strategy_htf_tf`, default H1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Expected trade frequency | Intraday, usually no more than one trade per active session |
| Typical hold time | Minutes to same-session close |
| Expected drawdown profile | Intraday breakout with bar-path and volatility-filter sensitivity |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView protected-source strategy
**Pointer:** `US Market ORB Atlas Strategy`, author `exlux`, https://www.tradingview.com/script/8dEIabqq-US-Market-ORB-Atlas-Strategy/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10749_tv-orb-atlas.md`

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
| v1 | 2026-05-31 | Initial build from card | 4b4f90d5-ff98-4066-907f-cbe9562126ec |
