# QM5_10702_tv-range-pivot - Strategy Spec

**EA ID:** QM5_10702
**Slug:** `tv-range-pivot`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA waits for an active range created when a higher-timeframe candle closes inside the previous higher-timeframe candle range, or when a completed session closes inside the prior session range. After that range is active, a touch of the range low creates a bullish pending signal and a touch of the range high creates a bearish pending signal. A long enters when the closed bar breaks above the active pivot high; a short enters when the closed bar breaks below the active pivot low. Stops are placed at the opposite active pivot, targets use the configured R:R multiple, and an opposite confirmed signal closes an existing position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_mode` | 0 | 0-1 | Selects HTF inside-candle mode or session-range mode. |
| `strategy_htf_timeframe` | `PERIOD_H4` | MT5 timeframe enum | Higher timeframe used by HTF mode. |
| `strategy_range_scan_units` | 40 | 2+ | Number of HTF bars to scan for the most recent inside-candle range. |
| `strategy_pivot_fresh_bars` | 40 | 3+ | Current-timeframe bars used to reconstruct fresh pivot and pending state. |
| `strategy_rr_target` | 2.0 | >0 | Take-profit multiple of entry-to-stop risk. |
| `strategy_session_start_h` | 0 | 0-23 | Broker-hour start for session range mode. |
| `strategy_session_end_h` | 8 | 0-24 | Broker-hour end for session range mode. |
| `strategy_session_scan_bars` | 240 | 10+ | Current-timeframe bars scanned for completed session ranges. |
| `strategy_trade_start_h` | 0 | 0-23 | Optional broker-hour no-trade start filter; all-day by default with end 24. |
| `strategy_trade_end_h` | 24 | 0-24 | Optional broker-hour no-trade end filter; all-day by default. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap in points; 0 disables the cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 forex basket member with OHLC data for range and pivot logic.
- `GBPUSD.DWX` - card R3 forex basket member with OHLC data for range and pivot logic.
- `USDJPY.DWX` - card R3 forex basket member with OHLC data for range and pivot logic.
- `XAUUSD.DWX` - canonical DWX metals symbol for the card's XAUUSD target.
- `GDAXI.DWX` - available DWX DAX symbol used for the card's GER40.DWX target.
- `NDX.DWX` - card R3 index basket member with OHLC data for range and pivot logic.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `XAUUSD` - missing `.DWX` suffix; mapped to `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_H4` by default for HTF range mode |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday to multi-session; exits by 2R target, pivot stop, opposite confirmation, or framework Friday close. |
| Expected drawdown profile | Moderate, with clustered losses possible in choppy range reversals. |
| Regime preference | Range mitigation followed by structure-break confirmation. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/0oFRzxDy-Range-Trading-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10702_tv-range-pivot.md`

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
| v1 | 2026-05-31 | Initial build from card | 16649f23-20ac-438b-af89-106b3c1afec6 |
