# QM5_10671_tv-wyck-gemini - Strategy Spec

**EA ID:** QM5_10671
**Slug:** `tv-wyck-gemini`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a long-only Wyckoff-style breakout. On the close of an H4 bar, it requires price to be above EMA(200), the close to break above the highest high of the prior 20 bars, and the breakout bar tick volume to be at least 1.5 times the prior 20-bar average tick volume. Entries use a market buy with an initial stop 3.0 ATR(14) below entry; the stop is trailed upward with the same ATR rule. The position is closed by the trailing stop, framework Friday close, or a 60 H4-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 or D1 intended by card | Timeframe used for EMA, Donchian, RVOL, ATR, and hold bars. |
| `strategy_ema_period` | `200` | `1+` | Trend filter EMA period. |
| `strategy_donchian_bars` | `20` | `1+` | Prior-bar lookback for Donchian resistance. |
| `strategy_rvol_bars` | `20` | `1+` | Prior-bar lookback for average tick volume. |
| `strategy_rvol_min` | `1.5` | `>0` | Minimum breakout-bar volume multiple. |
| `strategy_atr_period` | `14` | `1+` | ATR period for initial and trailing stop. |
| `strategy_atr_stop_mult` | `3.0` | `>0` | ATR multiple below entry and trailing stop distance. |
| `strategy_max_hold_bars` | `60` | `0+` | H4 time exit bars; `0` disables the time exit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card-listed gold market with OHLC, ATR, and tick-volume support.
- `NDX.DWX` - card-listed Nasdaq index exposure with DWX custom symbol data.
- `GDAXI.DWX` - available DWX DAX symbol used for the card's GER40 exposure.
- `WS30.DWX` - card-listed Dow index exposure with DWX custom symbol data.
- `EURUSD.DWX` - card-listed major FX market with DWX tick-volume support.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; use `SP500.DWX` only when a card calls for S&P 500 exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | Up to `60` H4 bars if the ATR trail does not close first. |
| Expected drawdown profile | Trend-breakout drawdowns controlled by one 3.0 ATR trailing stop per symbol. |
| Regime preference | Breakout and trend-following, with volume expansion confirmation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView protected-source strategy
**Pointer:** `https://www.tradingview.com/script/Ig66Q5sS/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10671_tv-wyck-gemini.md`

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
| v1 | 2026-06-14 | Initial build from card | c9ba2b24-1ec6-45ae-95db-97db60052981 |
