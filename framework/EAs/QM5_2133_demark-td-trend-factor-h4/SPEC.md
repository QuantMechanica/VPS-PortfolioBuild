# QM5_2133_demark-td-trend-factor-h4 - Strategy Spec

**EA ID:** QM5_2133
**Slug:** demark-td-trend-factor-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades Tom DeMark's TD-Trend-Factor reversal setup on H4 bars. It confirms 5-bar swing lows and highs, projects exhaustion zones from the latest qualified pivot with the fixed DeMark factors 1.0556 and 1.1118 or their reciprocals, and enters when a closed H4 qualifier bar rejects inside that zone. Shorts require the prior 20-H4-bar move to cross from below to above the D1 EMA(50); longs require the mirror move from above to below the D1 EMA(50). The initial stop is the stricter of the entry-bar ATR stop and the Magic-2 invalidation stop, the first target is the original pivot price, and positions also close on a 60-H4-bar time stop or a fresh opposite projection conflict.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_factor_1 | 1.0556 | >1.0 | First upside DeMark projection multiplier. |
| strategy_factor_2 | 1.1118 | >strategy_factor_1 | Second upside DeMark projection multiplier. |
| strategy_down_factor_1 | 0.9474 | 0.0-1.0 | First downside reciprocal projection multiplier. |
| strategy_down_factor_2 | 0.8993 | 0.0-strategy_down_factor_1 | Second downside reciprocal projection multiplier. |
| strategy_pivot_wing_bars | 2 | fixed 2 | Bars on each side of the qualified swing pivot. |
| strategy_max_active_per_side | 4 | 1-4 | Maximum FIFO active projections per side. |
| strategy_projection_expiry_h4 | 200 | >0 | H4 bars after which an unused projection expires. |
| strategy_zone_window_h4 | 8 | >=0 | Maximum H4 bars from zone touch to qualifier bar. |
| strategy_trend_lookback_h4 | 20 | >0 | H4 lookback for the D1 EMA trend-direction qualifier. |
| strategy_atr_period | 20 | >0 | ATR period for spread, stop, and trail calculations. |
| strategy_atr_slow_period | 50 | >strategy_atr_period | Slow ATR period for volatility-spike filter. |
| strategy_d1_ema_period | 50 | >0 | D1 EMA period used by the trend-direction qualifier. |
| strategy_spread_atr_mult | 0.30 | >=0.0 | Block only genuinely wide spreads above this ATR multiple. |
| strategy_min_projection_atr | 1.50 | >=0.0 | Minimum first projection distance measured in ATR. |
| strategy_vol_ratio_max | 2.00 | >0.0 | Blocks entries when ATR(20) / ATR(50) is above this value. |
| strategy_entry_stop_atr_mult | 0.50 | >0.0 | Entry-bar high/low stop buffer in ATR. |
| strategy_hard_stop_atr_mult | 0.30 | >=0.0 | Magic-2 invalidation stop buffer in ATR. |
| strategy_trail_atr_mult | 2.00 | >0.0 | ATR trailing multiplier after the pivot target is reached. |
| strategy_time_stop_h4_bars | 60 | >0 | Maximum H4 bars to hold a trade. |
| strategy_warmup_h4_bars | 200 | >=strategy_projection_expiry_h4 | H4 history used for pivot and projection state. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - DeMark source examples include currency futures and this FX major is in the approved DWX basket.
- GBPUSD.DWX - FX major from the card's currency universe and available in the DWX matrix.
- USDJPY.DWX - FX major from the card's currency universe and available in the DWX matrix.
- XAUUSD.DWX - Gold is explicitly named by the card's commodity portability note.
- XTIUSD.DWX - Crude oil is explicitly named by the card's commodity portability note.
- NDX.DWX - Nasdaq index exposure from the approved US index basket.
- WS30.DWX - Dow index exposure from the approved US index basket.
- GDAXI.DWX - DAX exposure from the approved global index basket.
- UK100.DWX - FTSE 100 exposure from the approved global index basket.
- SP500.DWX - S&P 500 exposure from DeMark examples; valid for backtest only under the SP500.DWX caveat.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the tester has no canonical DWX data for them.
- SPX500.DWX, SPY.DWX, ES.DWX - these are not the canonical S&P 500 custom-symbol name; use SP500.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(50) for trend direction |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Expected trade frequency | H4 reversal signals after qualified projection-zone rejection |
| Typical hold time | Up to 60 H4 bars, about 15 trading days |
| Expected drawdown profile | Medium; reversal entries use ATR and projection invalidation stops. |
| Regime preference | Mean-revert after directional exhaustion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum plus book references
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_2133_demark-td-trend-factor-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_2133_demark-td-trend-factor-h4.md`

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
| v1 | 2026-06-23 | Initial build from card | 95da065b-ce2b-4d46-9a81-df45de1a63d1 |
