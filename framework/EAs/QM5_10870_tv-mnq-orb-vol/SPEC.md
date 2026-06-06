# QM5_10870_tv-mnq-orb-vol - Strategy Spec

**EA ID:** QM5_10870
**Slug:** tv-mnq-orb-vol
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA defines the opening range from the first 15 minutes of the New York cash session, default 09:30 through 09:45 New York time. After the range is complete, it enters long when a closed breakout candle closes above the range high, or short when a closed breakout candle closes below the range low. The breakout candle must have tick volume at least 1.2 times the 20-bar volume average, and the opening range width must be between 0.3 and 2.0 ATR(14). Exits are the V5 bracket stop and target, or a forced flat exit at the configured session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_start_hour_ny` | 9 | 0-23 | New York hour for the opening range start. |
| `strategy_range_start_min_ny` | 30 | 0-59 | New York minute for the opening range start. |
| `strategy_opening_range_min` | 15 | 1+ | Minutes used to build the opening range. |
| `strategy_trade_end_hour_ny` | 11 | 0-23 | New York hour when open positions are flattened and new entries stop. |
| `strategy_trade_end_min_ny` | 30 | 0-59 | New York minute when open positions are flattened and new entries stop. |
| `strategy_atr_period` | 14 | 1+ | ATR period for range-width and stop calculations. |
| `strategy_atr_stop_mult` | 1.2 | 0+ | ATR stop candidate multiplier. |
| `strategy_min_stop_atr_mult` | 0.6 | 0+ | Minimum stop distance as ATR multiple. |
| `strategy_target_r` | 1.5 | 0+ | Take-profit multiple of initial stop risk. |
| `strategy_volume_sma_period` | 20 | 1+ | Tick-volume average period. |
| `strategy_volume_mult` | 1.2 | 0+ | Required breakout volume multiple. |
| `strategy_or_width_filter` | true | true/false | Enables the ATR-normalized opening range filter. |
| `strategy_or_min_atr_mult` | 0.3 | 0+ | Minimum opening range width as ATR multiple. |
| `strategy_or_max_atr_mult` | 2.0 | 0+ | Maximum opening range width as ATR multiple. |
| `strategy_max_spread_stop_pct` | 0.10 | 0+ | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq index CFD fits the source MNQ/NQ opening-range concept.
- `WS30.DWX` - Dow index CFD is part of the card's portable liquid index basket.
- `GDAXI.DWX` - Canonical DWX DAX symbol used for the card's GER40 intent.
- `XAUUSD.DWX` - Gold CFD has intraday session movement, tick volume, and ATR data.
- `EURUSD.DWX` - Major FX pair has intraday tick volume and liquid session behavior.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.

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
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, 09:45-11:30 New York window |
| Expected drawdown profile | False-breakout and news-spike sensitive intraday drawdowns |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `15 min opening range break out v1.4`, author handle `dp_bitcoin`, https://www.tradingview.com/script/9ivEXFNq-15-min-opening-range-break-out-v1-4/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10870_tv-mnq-orb-vol.md`

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
| v1 | 2026-06-06 | Initial build from card | a58cc6c3-cf41-44f4-a90b-3d50ebcefb81 |
