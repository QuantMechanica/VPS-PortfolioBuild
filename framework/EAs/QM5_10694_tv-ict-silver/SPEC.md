# QM5_10694_tv-ict-silver - Strategy Spec

**EA ID:** QM5_10694
**Slug:** tv-ict-silver
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView script URL in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the Silver Bullet portion of the ICT Master Suite on a M5 baseline. During the configured Silver Bullet session, it checks the last closed higher-timeframe candle for directional bias, then enters long when a bullish three-bar fair value gap forms in a bullish bias or short when a bearish three-bar fair value gap forms in a bearish bias. The P2 default enters at market on the next bar after closed-bar confirmation, uses the nearest qualifying swing level for target, uses the nearest qualifying swing level plus a 0.2 ATR(14) buffer for stop, and forces flat after the session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_session_start_min | 600 | 0-1439 | Broker minute-of-day when the Silver Bullet window starts. |
| strategy_session_end_min | 660 | 0-1440 | Broker minute-of-day when the Silver Bullet window ends. |
| strategy_htf_bias_tf | PERIOD_H1 | PERIOD_H1/PERIOD_H4/PERIOD_D1 | Higher timeframe used for directional bias. |
| strategy_atr_period | 14 | >=1 | ATR period used for FVG minimum size and stop buffer. |
| strategy_min_fvg_atr | 0.20 | >=0.0 | Minimum FVG size as a multiple of ATR(14). |
| strategy_stop_buffer_atr | 0.20 | >=0.0 | Extra stop distance beyond the selected swing or prior-day level. |
| strategy_swing_lookback_bars | 48 | >=5 | Closed M5 bars scanned for nearest qualifying swing stop and target. |
| strategy_use_pdh_pdl_target | false | true/false | Use previous-day high/low target instead of nearest swing target. |
| strategy_use_pdh_pdl_stop | false | true/false | Use previous-day high/low stop instead of nearest swing stop. |
| strategy_force_flat_session_end | true | true/false | Close open positions once the configured session window has ended. |
| strategy_max_spread_points | 0 | >=0 | Optional spread cap; 0 disables the strategy spread filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Primary FX pair in the card's portable P2 basket.
- GBPUSD.DWX - Primary FX pair in the card's portable P2 basket.
- USDJPY.DWX - Primary FX pair in the card's portable P2 basket.
- XAUUSD.DWX - Gold symbol normalized from the card's XAUUSD reference.
- NDX.DWX - US large-cap index exposure listed in the card.
- GDAXI.DWX - Canonical DWX DAX symbol used because GER40.DWX is not in the matrix.
- SP500.DWX - Optional card-listed S&P 500 symbol; valid for backtest-only use.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical DWX symbols for S&P 500 exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 default for HTF bias; H4 and D1 are declared parameter variants |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, normally minutes to the configured session end |
| Expected drawdown profile | High-cadence intraday model with spread and slippage sensitivity |
| Regime preference | Session-specific FVG continuation aligned with higher-timeframe bias |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/ABYnIcdl-ICT-Master-Suite-Trading-IQ/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10694_tv-ict-silver.md`

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
| v1 | 2026-05-31 | Initial build from card | e242d4d8-bcd6-4041-904b-1dfd55d0b2d3 |
