# QM5_10659_tv-orb-retest - Strategy Spec

**EA ID:** QM5_10659
**Slug:** tv-orb-retest
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA builds an opening range from the first configured minutes after the broker-time session start. After the range is complete, the first candle body close above the range high creates a buy-limit retest order at the range high; the first candle body close below the range low creates a sell-limit retest order at the range low. The stop is the low of the last bullish candle inside the opening range for longs, or the high of the last bearish candle inside the opening range for shorts. Take profit is a fixed R multiple of the stop distance, unfilled retest orders expire after the configured number of candles, and positions are forced flat at the configured session close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_or_minutes | 15 | 5-30 minutes | Opening-range duration after session start. |
| strategy_retest_expiry_bars | 6 | 3-12 bars | Number of chart candles before an unfilled retest order expires. |
| strategy_long_rr | 2.0 | 1.5-2.5 | Long take-profit R multiple. |
| strategy_short_rr | 2.0 | 1.5-2.5 | Short take-profit R multiple. |
| strategy_atr_period | 14 | 5-50 | ATR period for OR-size and max-SL filters. |
| strategy_min_or_atr_frac | 0.05 | 0.00-1.00 | Minimum opening-range size as ATR fraction. |
| strategy_max_or_atr_frac | 2.00 | 0.50-5.00 | Maximum opening-range size as ATR fraction. |
| strategy_max_sl_atr_mult | 1.00 | 0.50-1.50 | Maximum stop distance as ATR multiple. |
| strategy_session_start_hour | -1 | -1 or 0-23 | Broker-time session start hour; -1 uses symbol-aware default. |
| strategy_session_start_minute | -1 | -1 or 0-59 | Broker-time session start minute; -1 uses symbol-aware default. |
| strategy_entry_cutoff_hour | -1 | -1 or 0-23 | Broker-time final new-entry hour; -1 uses symbol-aware default. |
| strategy_entry_cutoff_minute | -1 | -1 or 0-59 | Broker-time final new-entry minute; -1 uses symbol-aware default. |
| strategy_session_close_hour | -1 | -1 or 0-23 | Broker-time force-flat hour; -1 uses symbol-aware default. |
| strategy_session_close_minute | -1 | -1 or 0-59 | Broker-time force-flat minute; -1 uses symbol-aware default. |
| strategy_long_monday..strategy_long_friday | true | true/false | Weekday enable flags for long setups. |
| strategy_short_monday..strategy_short_friday | true | true/false | Weekday enable flags for short setups. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index opening-range retests from the R3 basket.
- SP500.DWX - S&P 500 custom symbol, backtest-only per OWNER rollout note.
- WS30.DWX - Dow 30 index opening-range retests from the R3 basket.
- GDAXI.DWX - Canonical DWX DAX symbol for the card's GER40.DWX target.
- EURUSD.DWX - FX symbol from the card's R3 basket, run on the M15 baseline.
- XAUUSD.DWX - Metals symbol from the card's R3 basket, run on the M15 baseline.
- GBPUSD.DWX - FX symbol from the card's R3 basket, run on the M15 baseline.

**Explicitly NOT for:**
- GER40.DWX - Not present in the DWX symbol matrix; use GDAXI.DWX.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker or custom-symbol tick source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 for indices; M15 for FX and metals |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Intraday; flat by session close |
| Expected drawdown profile | Breakout-retest strategy with missed-trend and failed-retest risk |
| Regime preference | Opening-range breakout and volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView invite-only strategy
**Pointer:** https://www.tradingview.com/script/KU2b95Q8/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10659_tv-orb-retest.md`

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
| v1 | 2026-06-25 | Initial build from card | 203191d5-8bae-4f01-8f22-5fefe929ee47 |
