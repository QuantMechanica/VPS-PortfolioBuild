# QM5_11499_langer-bb20-d1trend-m5-scalp - Strategy Spec

**EA ID:** QM5_11499
**Slug:** `langer-bb20-d1trend-m5-scalp`
**Source:** `8ca13fce-d951-53be-9c60-35620d56354d` (see `strategy-seeds/sources/8ca13fce-d951-53be-9c60-35620d56354d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades M5 Bollinger Band reversions only in the direction of the D1 trend. A long setup requires the previous D1 close to be above the D1 SMA(200), the just-closed M5 candle to close below the lower BB(20,2), and that same M5 candle to be bullish; it then places a buy stop above the signal candle high plus current spread. The short side mirrors this with D1 close below SMA(200), a bearish M5 signal candle closing above the upper band, and a sell stop below the signal candle low minus spread. Exits are the fixed 20-pip TP, a structure SL capped to 20 pips, break-even after 10 pips, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 2+ | M5 Bollinger Band period. |
| `strategy_bb_deviation` | 2.0 | >0 | M5 Bollinger Band deviation. |
| `strategy_d1_sma_period` | 200 | 2+ | D1 SMA trend filter period. |
| `strategy_sl_lookback_bars` | 5 | 1+ | M5 bars used for structure SL. |
| `strategy_sl_cap_pips` | 20 | 1+ | Maximum stop distance in pips for P2. |
| `strategy_tp_pips` | 20 | 1+ | Fixed take-profit distance in pips. |
| `strategy_be_trigger_pips` | 10 | 1+ | Profit threshold for break-even movement. |
| `strategy_be_buffer_pips` | 1 | 0+ | Pip buffer beyond entry after break-even. |
| `strategy_spread_cap_pips` | 15 | 1+ | Maximum real spread in pips; zero spread is accepted. |
| `strategy_block_friday_entries` | true | true/false | Blocks new entries on Friday. |
| `strategy_london_session` | true | true/false | Enables the broker-time London window. |
| `strategy_london_start_hour` | 9 | 0-23 | Broker-time London session start hour. |
| `strategy_london_end_hour` | 12 | 0-23 | Broker-time London session end hour. |
| `strategy_newyork_session` | true | true/false | Enables the broker-time New York window. |
| `strategy_newyork_start_hour` | 15 | 0-23 | Broker-time New York session start hour. |
| `strategy_newyork_end_hour` | 21 | 0-23 | Broker-time New York session end hour. |
| `strategy_order_expiration_bars` | 1 | 0+ | Pending stop order expiration in M5 bars; 0 means GTC. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed DWX major FX symbol with M5 and D1 data.
- `GBPUSD.DWX` - Card-listed DWX major FX symbol with M5 and D1 data.
- `USDJPY.DWX` - Card-listed DWX major FX symbol with M5 and D1 data.
- `AUDUSD.DWX` - Card-listed DWX major FX symbol with M5 and D1 data.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The card specifies FX majors and pip-based exits.
- FX symbols outside `dwx_symbol_matrix.csv` - Not valid for DWX backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` close and SMA(200) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Intraday scalp; minutes to hours |
| Expected drawdown profile | Short-term mean-reversion scalps with capped 20-pip stop distance |
| Regime preference | D1 trend context with M5 mean reversion |
| Win rate target (qualitative) | Medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8ca13fce-d951-53be-9c60-35620d56354d`
**Source type:** `book`
**Pointer:** Paul Langer, The Black Book of Forex Trading (Alura Publishing/CreateSpace, 2015), local PDF: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\559219887-The-Black-Book-of-Forex-Trading.pdf`
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
