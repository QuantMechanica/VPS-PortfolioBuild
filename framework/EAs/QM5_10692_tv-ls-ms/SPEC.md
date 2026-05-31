# QM5_10692_tv-ls-ms - Strategy Spec

**EA ID:** QM5_10692
**Slug:** `tv-ls-ms`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA watches closed H1 bars for a confirmed pivot swing high or swing low. A long setup starts when price sweeps below the recent swing low and closes back above it; the EA then buys if price closes above the recent short-term high within 20 bars. A short setup mirrors that logic above a swing high, then sells when price closes below the recent short-term low. Exits are the ATR-based stop and 2R target, plus a time exit after 24 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pivot_lookback` | 5 | 3-10 | Bars on each side used to confirm swing highs and lows. |
| `strategy_structure_lookback` | 5 | 3-8 | Bars used to define the short-term structure break level. |
| `strategy_max_bars_after_sweep` | 20 | 10-40 | Maximum closed bars allowed between sweep and structure break. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for volatility filter and stop distance. |
| `strategy_atr_median_bars` | 100 | 20-200 | ATR sample size for the low-volatility filter. |
| `strategy_min_atr_median_ratio` | 0.50 | 0.25-1.00 | Blocks entries when current ATR is below this share of median ATR. |
| `strategy_atr_stop_mult` | 1.20 | 1.0-2.0 | ATR safety distance placed beyond the sweep extreme. |
| `strategy_atr_stop_cap_mult` | 3.00 | 1.0-3.0 | Maximum ATR multiple allowed for the safety distance. |
| `strategy_reward_r` | 2.00 | 1.5-2.5 | Take-profit distance as a multiple of stop risk. |
| `strategy_max_hold_bars` | 24 | 1-96 | Time exit in base-timeframe bars. |
| `strategy_session_filter` | true | true/false | Restricts entries to active London and New York hours. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker hour when the active session opens. |
| `strategy_session_end_hour` | 21 | 0-23 | Broker hour when the active session closes. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap; 0 leaves spread gating to framework/broker execution. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with reliable OHLC pivots and intraday sessions.
- `GBPUSD.DWX` - liquid FX major suited to London and New York sweep behaviour.
- `USDJPY.DWX` - liquid FX major with continuous intraday data.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's XAUUSD target.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's GER40 target.
- `NDX.DWX` - liquid index CFD for the card's Nasdaq target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered canonical DAX port.
- `XAUUSD` without suffix - research and backtest registry symbols must use the `.DWX` suffix.
- Symbols outside `dwx_symbol_matrix.csv` - the build registry only admits verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 24 H1 bars; M15 variants would use the card's 48-bar hold. |
| Expected drawdown profile | Whipsaw risk in sideways low-volatility ranges. |
| Regime preference | Intraday reversal-continuation after volatility expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** AIScripts, Liquidity Sweep + Market Structure Strategy, https://cn.tradingview.com/script/VRt4r5FM-Liquidity-Sweep-Market-Structure-Strategy/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10692_tv-ls-ms.md`

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
| v1 | 2026-05-31 | Initial build from card | 4f3aff2b-11ce-4635-bcc9-14e929726d26 |
