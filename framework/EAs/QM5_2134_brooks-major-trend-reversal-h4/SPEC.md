# QM5_2134_brooks-major-trend-reversal-h4 - Strategy Spec

**EA ID:** QM5_2134
**Slug:** brooks-major-trend-reversal-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades Al Brooks' H4 Major Trend Reversal pattern. For a long, it finds the strongest qualified down-leg sequence in the last 200 H4 bars, first from confirmed swing pivots and then from bounded swing extrema when the same card thresholds are present, requires a 50%-78% counter-trend rally, requires a later higher-low pullback, and buys only after a closed H4 bar breaks and closes above the rally high with a body of at least 0.8 ATR(20). Shorts use the exact mirror sequence after an up leg. The initial stop is 0.5 ATR(20) beyond leg-3, target 1 is the original leg-1 extreme, target 2 is the symmetric leg-1 extension, and positions also close on an L3/H3 failure or a 100-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_lookback_h4_bars | 200 | >=50 | Rolling H4 window used to find the strongest leg-1 swing. |
| strategy_pivot_wing_bars | 2 | >=1 | Bars on each side required to confirm local swing pivots. |
| strategy_leg_max_h4_bars | 30 | >0 | Maximum H4 bars allowed for leg-2 after leg-1 and leg-3 after leg-2. |
| strategy_atr_period | 20 | >0 | ATR period for breakout intensity, initial stop, spread filter, and trailing stop. |
| strategy_leg_atr_period | 50 | >0 | ATR period used to qualify leg-1 as a major trend. |
| strategy_d1_ema_period | 50 | >0 | D1 EMA period used for alignment confidence. |
| strategy_min_leg1_atr_mult | 2.0 | >0.0 | Minimum leg-1 move measured in ATR(50). |
| strategy_leg2_retrace_min | 0.50 | >0.0 | Minimum leg-2 retracement fraction of leg-1. |
| strategy_leg2_retrace_max | 0.78 | <1.0 | Maximum leg-2 retracement fraction of leg-1. |
| strategy_breakout_body_atr_mult | 0.80 | >0.0 | Minimum breakout-bar body measured in ATR(20). |
| strategy_initial_stop_atr_mult | 0.50 | >0.0 | ATR(20) buffer beyond leg-3 for the initial stop. |
| strategy_spread_atr_mult | 0.30 | >=0.0 | Blocks only genuinely wide spread above this ATR multiple. |
| strategy_trail_atr_mult | 2.0 | >0.0 | ATR trailing-stop multiplier after target 1 is reached. |
| strategy_time_stop_h4_bars | 100 | >0 | Maximum H4 bars to hold a trade. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Brooks examples include currency futures and this FX major is in the approved target basket.
- GBPUSD.DWX - FX major from the card's portable Brooks price-action universe.
- USDJPY.DWX - FX major from the card's portable Brooks price-action universe.
- XAUUSD.DWX - Gold is explicitly included by the card's commodity portability note.
- XTIUSD.DWX - Oil is explicitly included by the card's commodity portability note.
- NDX.DWX - Nasdaq 100 exposure from the approved index basket.
- WS30.DWX - Dow 30 exposure from the approved index basket.
- GDAXI.DWX - DAX index exposure from the approved global index basket.
- UK100.DWX - FTSE 100 exposure from the approved global index basket.
- SP500.DWX - S&P 500 exposure from Brooks examples; valid for backtest only under the SP500.DWX caveat.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the tester has no canonical DWX data for them.
- SPX500.DWX, SPY.DWX, ES.DWX - these are not the canonical S&P 500 custom-symbol name; use SP500.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(50) for alignment confidence |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 2 |
| Expected trade frequency | H4 structural reversal breakouts after qualified three-leg setup |
| Typical hold time | Up to 100 H4 bars, about 25 trading days |
| Expected drawdown profile | Medium; reversal entries use structural ATR stops and partial profit-taking. |
| Regime preference | Trend exhaustion into reversal / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum plus Brooks book/site references
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_2134_brooks-major-trend-reversal-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_2134_brooks-major-trend-reversal-h4.md`

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
| v1 | 2026-06-23 | Initial build from card | 85856952-38a1-48e4-bf30-31647a6d1ead |
| v2 | 2026-06-23 | Rework active setup scan and extrema fallback after smoke zero-trade review | 6f2363d7-3fa7-48c9-8d62-97242f50839c |
| v3 | 2026-06-23 | Correct expected-trade metadata to card approval reasoning for Q01 smoke sanity | 31abba1b-0d96-4c40-9354-54a4d55b3bc6 |
