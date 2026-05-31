# QM5_10688_tv-ict-sess-v3 - Strategy Spec

**EA ID:** QM5_10688
**Slug:** `tv-ict-sess-v3`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView open-source strategy)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA locks the previous session high and low from the configured broker-time session start. A long setup starts when a closed candle opens below the prior high and closes above it; price must then reenter the prior range by the configured depth, wait the configured minimum number of bars, and retest the prior high within tolerance before buying at market. A short setup mirrors this around the prior low. Each trade uses fixed SL/TP distances on FX symbols, ATR-normalized distances on non-FX symbols, and optional day-end flat close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hour_broker` | 0 | 0-23 | Broker-hour used as the session/day boundary. |
| `strategy_session_start_minute` | 0 | 0-59 | Broker-minute used as the session/day boundary. |
| `strategy_reentry_depth_pips` | 5 | 1+ | Required reentry depth back inside the prior range for FX symbols. |
| `strategy_retest_tolerance_pips` | 5 | 1+ | Allowed retest tolerance around the prior high/low for FX symbols. |
| `strategy_min_bars_after_break` | 3 | 0+ | Minimum closed bars after the break candle before retest entry can trigger. |
| `strategy_sl_pips` | 10 | 1+ | FX fixed stop-loss distance from actual fill price. |
| `strategy_tp_pips` | 20 | 1+ | FX fixed take-profit distance from actual fill price. |
| `strategy_max_trades_per_day` | 2 | 1+ | Maximum entry signals per session. |
| `strategy_max_spread_points` | 35 | 0+ | No-trade spread ceiling in symbol points; 0 disables the ceiling. |
| `strategy_day_end_flat_enabled` | true | true/false | Enables strategy flat close after the configured day-end time. |
| `strategy_day_end_hour_broker` | 23 | 0-23 | Broker-hour for day-end flat close and entry block. |
| `strategy_day_end_minute` | 0 | 0-59 | Broker-minute for day-end flat close and entry block. |
| `strategy_session_scan_bars` | 400 | 50+ | Maximum closed bars scanned to reconstruct the prior session range. |
| `strategy_non_fx_atr_period` | 14 | 1+ | ATR period used for non-FX distance normalization. |
| `strategy_non_fx_depth_atr_mult` | 0.25 | >0 | ATR fraction for non-FX reentry depth. |
| `strategy_non_fx_tolerance_atr_mult` | 0.25 | >0 | ATR fraction for non-FX retest tolerance. |
| `strategy_non_fx_sl_atr_mult` | 1.0 | >0 | ATR multiple for non-FX stop-loss distance. |
| `strategy_non_fx_tp_atr_mult` | 2.0 | >0 | ATR multiple for non-FX take-profit distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major named in the R3 P2 basket and matches the card's EURUSD M5 default.
- `GBPUSD.DWX` - FX major named in the R3 P2 basket.
- `USDJPY.DWX` - FX major named in the R3 P2 basket.
- `XAUUSD.DWX` - Canonical DWX gold symbol for the card's `XAUUSD` basket item.
- `GDAXI.DWX` - Canonical available DAX custom symbol used for the card's `GER40.DWX` basket item.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `XAUUSD` - Unsuffixed symbol is not used in V5 research/backtest artifacts; `XAUUSD.DWX` is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday; exits by fixed TP/SL or configured day-end flat close. |
| Expected drawdown profile | Moderate false-breakout risk around prior-session levels. |
| Regime preference | Breakout-retest / volatility expansion around prior session range. |
| Win rate target (qualitative) | Medium; 2:1 TP/SL default from source starting point. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/7IFb4Zx7/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10688_tv-ict-sess-v3.md`

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
| v1 | 2026-05-31 | Initial build from card | 3083b7e3-b99f-4ac3-b0fc-50c996c023e0 |
