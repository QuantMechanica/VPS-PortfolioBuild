# QM5_10701_tv-or-ny-rr - Strategy Spec

**EA ID:** QM5_10701
**Slug:** `tv-or-ny-rr`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `artifacts/cards_approved/QM5_10701_tv-or-ny-rr.md`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA builds an opening range from the configured broker-time cash-open minute and waits until that range is complete. On each closed bar after the range, it buys when the bar closes above the opening-range high and sells when the bar closes below the opening-range low. The initial stop is a fixed percent of entry price and the take profit is a fixed risk-reward multiple of that stop distance. It can stop opening new trades after a configured number of consecutive losing exits during the broker day, can stop accepting late entries after the opening-range window, and can force-close at the configured session close time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_or_start_hhmm` | 1530 | 0000-2359 | Broker-time start of the opening range; card source example is 15:30 Europe/Madrid for New York cash open. |
| `strategy_or_duration_minutes` | 15 | 5, 15, 30 | Number of minutes included in the opening range. |
| `strategy_stop_percent` | 0.50 | 0.25-1.00 | Fixed percent stop distance from entry price. |
| `strategy_rr_target` | 2.0 | 2.0-3.0 | Take-profit distance as a multiple of initial risk. |
| `strategy_max_losses_per_day` | 2 | 1-3 | Stop opening new trades after this many consecutive losing exits in the broker day. |
| `strategy_max_entry_enabled` | true | true/false | Enables the latest-entry cutoff after the opening range. |
| `strategy_max_entry_minutes` | 90 | 90-240 | Minutes after opening-range end during which new entries are allowed. |
| `strategy_session_close_enabled` | true | true/false | Enables force-close at the configured session close time. |
| `strategy_session_close_hhmm` | 2200 | 0000-2359 | Broker-time session close used for force-close. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used only when ATR trailing is enabled. |
| `strategy_atr_trailing_mult` | 0.0 | 0.0, 1.5, 2.0 | ATR trailing multiplier; 0 disables trailing. |
| `strategy_atr_trailing_start_r` | 1.0 | 0.0-5.0 | Favorable movement in initial-risk units before ATR trailing may tighten the stop. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional spread ceiling in points; 0 disables the spread ceiling. |
| `strategy_or_scan_bars` | 128 | 1-512 | Closed bars scanned to find the current day's opening range. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index CFD matches the card's liquid index CFD basket.
- `WS30.DWX` - Dow 30 index CFD matches the card's liquid index CFD basket.
- `GDAXI.DWX` - DAX CFD proxy for the card's `GER40.DWX`, which is not present in `dwx_symbol_matrix.csv`.
- `XAUUSD.DWX` - Gold is explicitly included by the card's R3 basket.
- `EURUSD.DWX` - Liquid FX major explicitly included by the card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not registered because it is absent from `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX symbol.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable phantom S&P variants under the DWX symbol discipline.

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
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, minutes to same-session hours |
| Expected drawdown profile | Trendless days can trigger false breakouts and consecutive daily losses. |
| Regime preference | Breakout / volatility expansion after the cash open |
| Win rate target (qualitative) | Medium to low, offset by 2R-3R winners |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView protected-source strategy`
**Pointer:** `https://www.tradingview.com/script/VSS73dTp/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10701_tv-or-ny-rr.md`

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
| v1 | 2026-05-31 | Initial build from card | d0527348-3935-4186-8fad-7bec52a81b06 |
