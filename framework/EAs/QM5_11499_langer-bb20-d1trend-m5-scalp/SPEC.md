# QM5_11499_langer-bb20-d1trend-m5-scalp - Strategy Spec

**EA ID:** QM5_11499
**Slug:** langer-bb20-d1trend-m5-scalp
**Source:** 8ca13fce-d951-53be-9c60-35620d56354d (see `strategy-seeds/sources/8ca13fce-d951-53be-9c60-35620d56354d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades M5 Bollinger Band reversions only in the direction of the D1 trend. Long setup requires yesterday's D1 close above the D1 SMA(200), an M5 close below the lower Bollinger Band, and a bullish reversal candle; short setup mirrors this below the D1 SMA(200), above the upper Bollinger Band, and with a bearish reversal candle. Entry is a pending stop beyond the reversal candle extreme with a spread offset, a prior-five-bar structural stop capped at 20 pips, a fixed 20-pip take profit, and a break-even shift after 10 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 14-26 P3 sweep noted by card | M5 Bollinger Band lookback. |
| `strategy_bb_deviation` | 2.0 | >0 | M5 Bollinger Band standard-deviation multiplier. |
| `strategy_d1_sma_period` | 200 | 100-300 P3 sweep noted by card | D1 SMA trend-filter period. |
| `strategy_sl_lookback_bars` | 5 | 3-7 P3 sweep noted by card | Closed M5 bars used for structural stop. |
| `strategy_sl_cap_pips` | 20 | >0 | Maximum allowed stop distance in pips. |
| `strategy_tp_pips` | 20 | 10-20 P3 sweep noted by card | Fixed take-profit distance in pips. |
| `strategy_be_trigger_pips` | 10 | >0 | Move SL to break-even once price moves this many pips in favor. |
| `strategy_be_buffer_pips` | 1 | >=0 | Break-even lock-in buffer in pips. |
| `strategy_pending_expiry_bars` | 3 | >0 | Pending stop lifetime in M5 bars. |
| `strategy_spread_cap_pips` | 15.0 | >0 | Blocks only genuinely wide positive spread. |
| `strategy_london_start_hour_broker` | 9 | 0-23 | Broker-time London-open session start. |
| `strategy_london_end_hour_broker` | 12 | 1-24 | Broker-time London-open session end. |
| `strategy_ny_start_hour_broker` | 15 | 0-23 | Broker-time NY-session start. |
| `strategy_ny_end_hour_broker` | 22 | 1-24 | Broker-time NY-session end. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with M5 and D1 DWX data.
- `GBPUSD.DWX` - card-listed major FX pair with M5 and D1 DWX data.
- `USDJPY.DWX` - card-listed major FX pair with M5 and D1 DWX data.
- `AUDUSD.DWX` - card-listed major FX pair with M5 and D1 DWX data.

**Explicitly NOT for:**
- Non-card `.DWX` symbols - the approved card names only the four FX pairs above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 close and D1 SMA(200) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Not specified in card frontmatter; intraday scalp expected from M5 TP/BE mechanics. |
| Expected drawdown profile | Not specified in card frontmatter. |
| Regime preference | Bollinger Band mean reversion with D1 trend filter. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8ca13fce-d951-53be-9c60-35620d56354d
**Source type:** book
**Pointer:** Paul Langer, The Black Book of Forex Trading (Alura Publishing/CreateSpace, 2015), local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\559219887-The-Black-Book-of-Forex-Trading.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11499_langer-bb20-d1trend-m5-scalp.md`

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
| v1 | 2026-06-25 | Initial build from card | 8d594943-d757-4e80-aca6-1c1a7e16e2e4 |
