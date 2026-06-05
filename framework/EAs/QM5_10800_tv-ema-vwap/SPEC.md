# QM5_10800_tv-ema-vwap - Strategy Spec

**EA ID:** QM5_10800
**Slug:** `tv-ema-vwap`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades the closed-bar EMA(9) crossover of session VWAP on the active chart timeframe. A long entry requires EMA(9) to cross above VWAP, EMA(9) to be above EMA(21), VWAP slope to be non-flat, and the weekday filter to allow the bar. A short entry mirrors the rule below VWAP and EMA(21). The baseline exit is an ATR(14) stop at 1.5x ATR and a fixed 2R profit target, with framework Friday close still active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 9 | 1-100 | Fast EMA used for VWAP crossover. |
| `strategy_ema_slow_period` | 21 | 2-200 | Slow EMA trend filter. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the baseline stop. |
| `strategy_atr_stop_mult` | 1.5 | 0.1-10.0 | Stop distance multiplier on ATR. |
| `strategy_target_rr` | 2.0 | 0.1-10.0 | Profit target as a fixed risk multiple. |
| `strategy_vwap_flat_pct` | 0.01 | 0.0-1.0 | Minimum absolute VWAP slope percent; lower values permit flatter VWAP. |
| `strategy_vwap_max_bars` | 300 | 50-512 | Maximum bars scanned for the session VWAP proxy. |
| `strategy_monday_enabled` | true | true/false | Allow Monday entries. |
| `strategy_tuesday_enabled` | true | true/false | Allow Tuesday entries. |
| `strategy_wednesday_enabled` | true | true/false | Allow Wednesday entries. |
| `strategy_thursday_enabled` | true | true/false | Allow Thursday entries. |
| `strategy_friday_enabled` | true | true/false | Allow Friday entries. |
| `strategy_session_enabled` | false | true/false | Enable optional London/NY liquid-hours gate. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour session start when session gate is enabled. |
| `strategy_session_end_hour` | 21 | 0-23 | Broker-hour session end when session gate is enabled. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional spread cap in points; zero disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 major FX basket member with liquid intraday data.
- `GBPUSD.DWX` - Card R3 major FX basket member with liquid intraday data.
- `USDJPY.DWX` - Card R3 major FX basket member with liquid intraday data.
- `XAUUSD.DWX` - Canonical DWX gold symbol for the card's `XAUUSD` target.
- `GDAXI.DWX` - Canonical DWX DAX symbol for the card's `GER40.DWX` target.
- `NDX.DWX` - Card R3 US index basket member for Nasdaq 100 exposure.
- `WS30.DWX` - Card R3 US index basket member for Dow 30 exposure.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - Missing `.DWX` suffix for backtest registry context; use `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` baseline; card also lists `M15` and `M30` for parameter testing |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday, minutes to hours |
| Expected drawdown profile | High-cadence intraday crossover with spread and slippage sensitivity |
| Regime preference | Intraday trend-following / directional push |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/2dvhxn9p-EMA-VWAP-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10800_tv-ema-vwap.md`

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
| v1 | 2026-06-05 | Initial build from card | 8edb1a9a-9a7b-42cd-907d-e51ce572be8b |
