# QM5_10265_tv-or-psvr - Strategy Spec

**EA ID:** QM5_10265
**Slug:** tv-or-psvr
**Source:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5 (see `strategy-seeds/sources/c84ae47e-8ea0-56f1-8b25-4436b6dda5b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA records a 15-minute opening range for the symbol's assigned session: London for GBP/EUR/USD FX pairs and New York for US index CFDs. After the range is complete, it opens long after the configured number of consecutive closed candles close above the range high, or short after the same number close below the range low. At least one confirmation candle must have tick volume at or above 150% of its 20-bar average volume. The baseline stop is the opposite side of the opening range, TP1 closes 50% at +1R and moves the remainder to breakeven, TP2 closes the remainder at +2R, and all positions are closed at the configured 22:30 broker-time EOD cutoff.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `or_duration_minutes` | 15 | 5-60 | Opening range duration in minutes after the session open. |
| `consecutive_closes` | 2 | 1-3 | Closed candles required beyond the opening range to confirm breakout. |
| `psvr_volume_sma` | 20 | 10-30 | Number of prior bars used for the tick-volume baseline. |
| `psvr_min_volume_ratio` | 1.5 | 1.0-2.0 | Minimum confirmation-candle volume as a multiple of its volume SMA. |
| `stop_mode` | `Opposite_Range` | `Opposite_Range`, `ATR`, `Fixed_Percent` | Card default is implemented; alternate modes need P3 parameter values before activation. |
| `tp1_close_fraction` | 0.50 | 0.0-1.0 | Fraction of open volume to close at +1R where broker minimum lot permits. |
| `tp2_r_multiple` | 2.0 | >0 | Final take-profit distance in R multiples. |
| `atr_filter_period` | 14 | >0 | ATR period for the opening-range width guard. |
| `min_or_atr_multiple` | 0.25 | >0 | Minimum opening-range width as ATR multiple. |
| `max_or_atr_multiple` | 2.50 | >0 | Maximum opening-range width as ATR multiple. |
| `london_open_hour_broker` | 10 | 0-23 | Broker-time hour used for the London opening range. |
| `london_open_minute_broker` | 0 | 0-59 | Broker-time minute used for the London opening range. |
| `ny_open_hour_broker` | 16 | 0-23 | Broker-time hour used for the New York opening range. |
| `ny_open_minute_broker` | 30 | 0-59 | Broker-time minute used for the New York opening range. |
| `eod_close_hhmm_broker` | 2230 | 0000-2359 | Broker-time end-of-day strategy close. |
| `trade_monday` | true | true/false | Enables Monday entries. |
| `trade_tuesday` | true | true/false | Enables Tuesday entries. |
| `trade_wednesday` | true | true/false | Enables Wednesday entries. |
| `trade_thursday` | true | true/false | Enables Thursday entries. |
| `trade_friday` | false | true/false | Keeps Friday disabled as the baseline. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - GBP/USD maps to the card's London-session GBP target.
- `EURUSD.DWX` - EUR/USD maps to the card's London-session EUR target.
- `WS30.DWX` - DWX Dow 30 proxy for the card's US30 target.
- `NDX.DWX` - DWX Nasdaq 100 proxy for the card's NAS100 target.
- `SP500.DWX` - DWX backtest-only S&P 500 proxy for the card's SPX500 target.

**Explicitly NOT for:**
- `SPX500.DWX` - not present in the DWX matrix; `SP500.DWX` is the canonical custom symbol.
- `SPY.DWX` - not present in the DWX matrix; `SP500.DWX` is the canonical S&P 500 custom symbol.

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
| Trades / year / symbol | 120 |
| Typical hold time | Intraday; same-session to 22:30 broker-time maximum |
| Expected drawdown profile | Medium risk; card cites 16% expected drawdown |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
**Source type:** article
**Pointer:** TradingView protected-script description, `https://www.tradingview.com/script/sprZfKwH/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10265_tv-or-psvr.md`

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
| v1 | 2026-06-12 | Initial build from card | 82874264-195e-4fb9-8127-94c2231d553a |
