# QM5_12428_ea31337-bands - Strategy Spec

**EA ID:** QM5_12428
**Slug:** `ea31337-bands`
**Source:** `041e0d5c-bf76-501d-bee2-31c0f4a6e233` (see `artifacts/cards_approved/QM5_12428_ea31337-bands.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA trades Bollinger Band reentry on the chart timeframe using Bollinger Bands period 24, deviation 1.0, applied to open price. A long signal requires the lowest low across the last three closed bars to have pushed below the lower band, the latest closed bar to have closed back above the lower band, and the middle band to have risen versus the prior closed bar. A short signal mirrors this rule above the upper band with a falling middle band. Positions use fixed or band-qualified protective stops, fixed profit targets, a 30-bar time exit, and close earlier when the opposite reentry signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 24 | 2-200 | Bollinger Band period from the source default. |
| `strategy_bb_deviation` | 1.0 | 0.1-5.0 | Bollinger Band standard deviation multiplier. |
| `strategy_signal_open_level` | 0.0 | 0.0+ | Minimum middle-band change in price units before entry. |
| `strategy_signal_open_method` | 4 | 1-4 | Source default method; method 4 requires the excursion to cross the current middle band. |
| `strategy_sl_pips` | 80 | 1-500 | Source close-loss default used when it qualifies beyond the band excursion. |
| `strategy_tp_pips` | 80 | 1-500 | Source close-profit default used for fixed take profit. |
| `strategy_time_exit_bars` | 30 | 1-500 | Maximum holding period in chart bars. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for fallback stop placement only. |
| `strategy_atr_fallback_mult` | 2.0 | 0.1-10.0 | ATR multiple for fallback stop placement only. |
| `strategy_band_stop_buffer_pips` | 2 | 0-50 | Stop buffer beyond the three-bar excursion high or low. |
| `strategy_spread_max_pips` | 4.0 | 0.0+ | Maximum genuine spread; zero modeled spread on DWX is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major Forex pair named by the card's liquid-FX target class.
- `GBPUSD.DWX` - liquid major Forex pair named by the card's liquid-FX target class.
- `USDJPY.DWX` - liquid major Forex pair named by the card's liquid-FX target class.
- `USDCHF.DWX` - liquid major Forex pair named by the card's liquid-FX target class.
- `AUDUSD.DWX` - liquid major Forex pair named by the card's liquid-FX target class.
- `XAUUSD.DWX` - metal symbol explicitly named by the card.

**Explicitly NOT for:**
- `SP500.DWX` - the card targets Forex pairs and XAUUSD, not index CFDs for this baseline build.
- `XTIUSD.DWX` - the card does not identify energy CFDs as part of the target basket.

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
| Trades / year / symbol | `100` |
| Typical hold time | intraday to 30 H1 bars |
| Expected drawdown profile | bounded by fixed-risk stops on mean-reversion entries |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `041e0d5c-bf76-501d-bee2-31c0f4a6e233`
**Source type:** GitHub repository
**Pointer:** `https://github.com/EA31337/Strategy-Bands/blob/master/Stg_Bands.mqh`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12428_ea31337-bands.md`

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
| v1 | 2026-06-30 | Initial build from card | d946f08f-b99d-480f-85ee-0670a888026f |
