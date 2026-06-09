# QM5_10187_tv-vwap-rsi-scalp - Strategy Spec

**EA ID:** QM5_10187
**Slug:** tv-vwap-rsi-scalp
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long and short VWAP/RSI scalps on intraday bars. A long entry requires RSI(3) at or below 20, the last closed close above the session VWAP, and the last closed close above EMA(50). A short entry requires RSI(3) at or above 80, the last closed close below the session VWAP, and the last closed close below EMA(50). Entries attach a fixed ATR(14) bracket immediately: stop loss at 1.0 x ATR and take profit at 2.0 x ATR. The EA closes open positions when the configured trading session ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | M5 or M15 intended | Signal timeframe used for VWAP, RSI, EMA, and ATR reads. |
| `strategy_rsi_period` | `3` | `1+` | RSI period for exhaustion signal. |
| `strategy_rsi_oversold` | `20.0` | `0-100` | Long threshold. |
| `strategy_rsi_overbought` | `80.0` | `0-100` | Short threshold. |
| `strategy_ema_period` | `50` | `1+` | EMA trend filter period. |
| `strategy_atr_period` | `14` | `1+` | ATR period for stop and target distance. |
| `strategy_atr_sl_mult` | `1.0` | `>0` | Stop distance in ATR multiples. |
| `strategy_atr_tp_mult` | `2.0` | `>0` | Take-profit distance in ATR multiples. |
| `strategy_session_start_hhmm` | `1400` | `0000-2359` | Broker-time session start for allowed entries and VWAP accumulation. |
| `strategy_session_end_hhmm` | `2100` | `0000-2359` | Broker-time session end; open positions close after this time. |
| `strategy_max_trades_per_day` | `3` | `1+` | Daily cap per symbol and magic number. |
| `strategy_max_spread_atr_frac` | `0.15` | `>0` | Maximum spread as a fraction of ATR stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Liquid US index CFD matching the source's large-cap index use case.
- `WS30.DWX` - Liquid US index CFD matching the source's cash-session liquidity premise.
- `XAUUSD.DWX` - Liquid metal CFD included in the card's DWX port targets.
- `XTIUSD.DWX` - Liquid energy CFD included in the card's DWX port targets.
- `EURUSD.DWX` - Liquid FX major for the London/New York overlap interpretation in the card.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - broker or custom-symbol data is not available for P2.

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
| Trades / year / symbol | `180` |
| Typical hold time | Intraday minutes to hours, bounded by fixed ATR bracket and session-end close. |
| Expected drawdown profile | Frequent small fixed-risk trades with ATR-bounded loss per entry. |
| Regime preference | Mean-reversion exhaustion inside VWAP/EMA directional bias during liquid sessions. |
| Win rate target (qualitative) | Medium-high due to 2:1 ATR bracket requiring selective entries. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script
**Pointer:** TradingView script `VWAP-RSI Scalper FINAL v1`, author handle `michaelriggs`, published 2025-08-07, https://www.tradingview.com/script/S9hY3huK-VWAP-RSI-Scalper-FINAL-v1/
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10187_tv-vwap-rsi-scalp.md`

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
| v1 | 2026-06-09 | Initial build from card | 07c8bcec-ada1-4924-8e75-19976474638a |
