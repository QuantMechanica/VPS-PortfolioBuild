# QM5_12433_ea31337-ichi — Strategy Spec

**EA ID:** QM5_12433
**Slug:** `ea31337-ichi`
**Source:** `041e0d5c-bf76-501d-bee2-31c0f4a6e233`
**Author of this spec:** Codex
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

On each closed H1 or H4 bar, the EA buys when Tenkan-sen (30) is above Kijun-sen (10), was below it two bars earlier, Chikou Span is below Tenkan-sen, Senkou Span A is above Senkou Span B, and Tenkan-sen has risen by at least 0.001 over three bars. The sell rule is the exact inverse, and a new entry is blocked when the positive bid/ask spread exceeds four pips. Every trade receives an 80-pip stop and an 80-pip target, and only one position may be open for the symbol and magic. The EA exits earlier after 30 chart bars, on the inverse Tenkan/Kijun cross, or through the framework Friday-close rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tenkan_period` | 30 | positive integer | Tenkan-sen lookback from the approved source default. |
| `strategy_kijun_period` | 10 | positive integer | Kijun-sen lookback from the approved source default. |
| `strategy_senkou_period` | 30 | positive integer | Senkou Span B lookback from the approved source default. |
| `strategy_signal_shift` | 1 | at least 1 | Closed-bar shift used for the signal values. |
| `strategy_prior_state_bars` | 2 | positive integer | Bars between the signal state and the required prior opposite state. |
| `strategy_slope_lookback_bars` | 3 | positive integer | Bars used for the Tenkan-sen slope threshold. |
| `strategy_open_level` | 0.001 | non-negative price distance | Minimum absolute Tenkan-sen move across the slope lookback. |
| `strategy_stop_loss_pips` | 80 | positive integer | Fixed protective-stop distance in scale-correct pips. |
| `strategy_take_profit_pips` | 80 | positive integer | Fixed target distance, expressed through the equivalent risk/reward ratio. |
| `strategy_close_time_bars` | 30 | positive integer | Maximum position age in chart bars. |
| `strategy_max_spread_pips` | 4 | positive integer | Maximum positive bid/ask spread; zero modeled spread remains valid. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURJPY.DWX` — liquid yen cross with sustained trends suitable for cloud confirmation.
- `GBPJPY.DWX` — higher-volatility yen cross suited to the same deterministic trend rule.
- `GDAXI.DWX` — canonical DWX DAX index symbol named in the approved R3 basket.
- `NDX.DWX` — liquid US technology index with directional trend regimes.
- `XAUUSD.DWX` — liquid metal CFD with trend and breakout regimes.

**Explicitly NOT for:**

- `DAX.DWX` — not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the approved canonical target.
- Symbols outside the five approved R3 targets — they were not authorized by this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 and H4, each represented by separate setfiles |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the chart symbol and timeframe |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 12, or about monthly |
| Typical hold time | Up to 30 chart bars; shorter on SL, TP, opposite cross, or Friday close |
| Expected drawdown profile | Approximately 18% card expectation, concentrated in non-trending regimes |
| Regime preference | Trend-following cloud breakout |
| Win rate target (qualitative) | Not specified by the approved card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `041e0d5c-bf76-501d-bee2-31c0f4a6e233`  
**Source type:** Public GitHub strategy repository  
**Pointer:** `https://github.com/EA31337/Strategy-Ichimoku/blob/master/Stg_Ichimoku.mqh`  
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_12433_ea31337-ichi.md`

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
| v1 | 2026-07-31 | Initial build from card | 3110a523-1c95-424f-be42-60cd17adf3d4 |
