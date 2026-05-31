# QM5_10679_tv-fvg-rr1 - Strategy Spec

**EA ID:** QM5_10679
**Slug:** `tv-fvg-rr1`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades classic three-candle fair value gaps on the chart timeframe. A bullish gap forms when the last closed candle's low is above the high from two candles earlier; a bearish gap forms when the last closed candle's high is below the low from two candles earlier. Trades are allowed only during the configured session window, enter in normal mode on gap formation or the first later midpoint touch, use the middle candle wick plus an ATR buffer as stop, and set take profit at 1R. Open positions close at session end or when an opposite fair value gap appears after at least three bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period used for minimum FVG size and stop buffer. |
| `strategy_min_fvg_atr` | 0.15 | 0.0+ | Minimum gap size as ATR multiple. |
| `strategy_stop_buffer_atr` | 0.10 | 0.0+ | ATR buffer beyond the middle-candle wick. |
| `strategy_reward_r` | 1.00 | 0.1+ | Take-profit multiple of initial risk. |
| `strategy_setup_expiry_bars` | 24 | 1+ | Bars after which an untraded FVG midpoint setup expires. |
| `strategy_min_exit_bars` | 3 | 1+ | Minimum bars open before opposite-FVG exit is allowed. |
| `strategy_enter_on_formation` | true | true/false | Allow market entry on closed-bar FVG formation. |
| `strategy_enter_on_midpoint_retest` | true | true/false | Allow first midpoint-retrace entry after FVG formation. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap; 0 disables this cap. |
| `strategy_fx_session_start_min` | 780 | 0-1439 | FX/metals session start minute of broker day. |
| `strategy_fx_session_end_min` | 1020 | 0-1440 | FX/metals session end minute of broker day. |
| `strategy_index_session_start_min` | 930 | 0-1439 | Index session start minute of broker day. |
| `strategy_index_session_end_min` | 1320 | 0-1440 | Index session end minute of broker day. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair with DWX OHLC and session data.
- `GBPUSD.DWX` - Major FX pair from the card's portable P2 basket.
- `XAUUSD.DWX` - Metal CFD equivalent for the card's XAUUSD target.
- `NDX.DWX` - Liquid US index CFD from the card's P2 basket.
- `GDAXI.DWX` - DWX matrix DAX proxy for the card's GER40.DWX target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `XAUUSD` - Missing `.DWX` suffix; backtest registry uses `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` and `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `140` |
| Typical hold time | intraday, minutes to session-end |
| Expected drawdown profile | fixed 1R losses with no scaling or martingale |
| Regime preference | session-filtered mean reversion around fair value gaps |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView protected-source strategy
**Pointer:** `https://www.tradingview.com/script/Yoc6NU8j-FVG-1-1-RR-Strategy-Invert-7-Custom-Sessions/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10679_tv-fvg-rr1.md`

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
| v1 | 2026-05-31 | Initial build from card | e01209dc-3fc6-4bb1-8d0a-9d7616e44a5a |
