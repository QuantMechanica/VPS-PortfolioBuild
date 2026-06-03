# QM5_10690_tv-pdh-pdl-rev_v2 - Strategy Spec

**EA ID:** QM5_10690
**Slug:** `tv-pdh-pdl-rev`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades M15 reversals around the prior daily high and prior daily low. A long setup starts after price trades below the previous-day low and a closed M15 candle closes back above that level; a short setup mirrors this above the previous-day high. The default P2 setting requires the confirmation candle to close in the favorable half of its range and permits one long and one short signal per broker day. Stops are placed beyond the current day extreme with a 0.2 ATR(14) buffer, targets are set at 2.0R, and open trades are trailed from structure after +1R or closed at the end of the configured New York session window.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop buffer, trailing buffer, and volatility filter. |
| `strategy_stop_atr_buffer_mult` | 0.20 | 0.05-1.00 | ATR multiplier added beyond the current day high or low for the initial stop. |
| `strategy_reward_r` | 2.00 | 1.00-5.00 | Take-profit multiple of initial risk. |
| `strategy_trail_activation_r` | 1.00 | 0.50-3.00 | Open-profit threshold, in R, before structure trailing activates. |
| `strategy_require_favorable_half` | true | true/false | Requires long confirmation candles to close in the upper half and shorts in the lower half. |
| `strategy_one_signal_per_dir_day` | true | true/false | Limits the EA to one long and one short signal per broker day. |
| `strategy_vol_filter_enabled` | true | true/false | Enables the low-volatility day filter. |
| `strategy_vol_median_ratio` | 0.50 | 0.10-1.00 | Blocks entries when current M15 ATR is below this ratio of the 20-day sampled median. |
| `strategy_session_start_hour` | 13 | 0-23 | Broker-time hour when the allowed entry session starts. |
| `strategy_session_end_hour` | 22 | 0-23 | Broker-time hour when the allowed entry session ends and time exits trigger. |
| `strategy_max_spread_points` | 120 | 0-1000 | Maximum spread in points for new entries; 0 disables this filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary liquid FX pair with continuous M15 OHLC and prior-day levels.
- `GBPUSD.DWX` - primary liquid FX pair with continuous M15 OHLC and prior-day levels.
- `USDJPY.DWX` - primary liquid FX pair with continuous M15 OHLC and prior-day levels.
- `XAUUSD.DWX` - canonical DWX symbol for the card's listed XAUUSD metal exposure.
- `NDX.DWX` - primary US index CFD suitable for prior-day liquidity sweeps.
- `WS30.DWX` - primary US index CFD suitable for prior-day liquidity sweeps.

**Explicitly NOT for:**
- `SP500.DWX` - listed as optional backtest-only in the card, but not part of the primary P2 basket registered for this build.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol evidence is available for pipeline testing.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` previous-day high/low and current-day high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday; exits by SL, TP, trail, or configured session end. |
| Expected drawdown profile | Moderate; vulnerable to repeated trend-day continuation stop-outs after PDH/PDL sweeps. |
| Regime preference | Mean-reversion after liquidity sweeps. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source indicator
**Pointer:** `https://www.tradingview.com/script/0uAmOgGD-PDH-PDL-Liquidity-Reversal-15M-Confirmed-Close/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10690_tv-pdh-pdl-rev_v2.md`

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
| v1 | 2026-05-31 | Initial build from card | 6bc392f9-0c71-4e23-82d8-484cbdc7572f |

