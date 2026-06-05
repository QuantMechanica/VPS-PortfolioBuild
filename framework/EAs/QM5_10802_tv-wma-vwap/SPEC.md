# QM5_10802_tv-wma-vwap - Strategy Spec

**EA ID:** QM5_10802
**Slug:** `tv-wma-vwap`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Claude
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades the closed-bar crossover of WMA(50) and WMA(100) filtered by the
session VWAP side and an ATR volatility floor. A long entry requires WMA(50) to
cross above WMA(100) on the last two closed bars, the last closed price to be
above the current-session VWAP, and ATR to clear an optional minimum threshold.
A short entry mirrors the rule (WMA(50) crosses below WMA(100), price below
VWAP). The baseline exit is an ATR(14) stop at 3.0x ATR and a 3R profit target
(9.0x ATR), with framework Friday close active. An optional opposite-crossover
signal exit is available but off by default.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wma_fast_period` | 50 | 1-200 | Fast WMA in the crossover trigger. |
| `strategy_wma_slow_period` | 100 | 2-400 | Slow WMA in the crossover trigger (must exceed fast). |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the stop and volatility floor. |
| `strategy_atr_stop_mult` | 3.0 | 0.1-10.0 | Stop distance multiplier on ATR. |
| `strategy_target_rr` | 3.0 | 0.1-10.0 | Profit target as a fixed risk multiple (3R = 9x ATR). |
| `strategy_atr_min_points` | 0.0 | 0.0-100000 | ATR volatility floor in points; zero disables the filter (card option "off"). |
| `strategy_vwap_max_bars` | 300 | 50-512 | Maximum bars scanned for the session VWAP. |
| `strategy_exit_on_opposite_cross` | false | true/false | Optional V5 signal exit on the opposite WMA crossover. |
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
| Base timeframe | `M5`/`M15` baseline; card also lists `M30` for parameter testing |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday, minutes to hours |
| Expected drawdown profile | High-cadence crossover with a wide 3R bracket; slippage and low-volatility filter sensitivity on short timeframes |
| Regime preference | Intraday trend / directional momentum |
| Win rate target (qualitative) | low-to-medium (wide 3R target) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/wp0V0TVO-Algomist-app-v1-0/` (author `Algomist_`)
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10802_tv-wma-vwap.md`

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
| v1 | 2026-06-05 | Initial build from card | d5c426de-9587-4b61-b771-93d17f6ac52b |
