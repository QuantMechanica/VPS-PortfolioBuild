# QM5_11014_the5ers-mprof-va - Strategy Spec

**EA ID:** QM5_11014
**Slug:** the5ers-mprof-va
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA builds the prior completed broker-day M30 market profile from the symbol's own M30 bars, using tick volume as the volume proxy. It computes VAH, VAL, and POC from a 70 percent value area around the highest-volume price bucket. A long entry is opened when the current session has traded below prior VAL and the latest closed M30 bar closes back above VAL after probing at least 0.25 ATR below it, while still below prior POC. A short entry is the mirror setup above VAH; exits are the prior-session POC capped at 2R, value-area failure, end-of-day flatten, SL/TP, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_value_area_pct | 70.0 | 68-75 | Percent of prior-session profile volume included in value area. |
| strategy_va_bucket_ticks | 5 | 1-50 | Price histogram bucket size in symbol ticks. |
| strategy_va_max_buckets | 2000 | 100-5000 | Hard cap for profile histogram size. |
| strategy_atr_period | 14 | 5-50 | M30 ATR period for depth, stop, and filters. |
| strategy_rejection_depth_atr | 0.25 | 0.15-0.40 | Minimum failed probe depth beyond VAH/VAL in ATR units. |
| strategy_sl_atr_mult | 0.5 | 0.25-2.0 | SL buffer beyond the rejection bar high/low in ATR units. |
| strategy_tp_cap_r | 2.0 | 1.5-2.0 | Maximum target distance in R when POC is farther away. |
| strategy_va_min_atr | 1.0 | 0.5-3.0 | Minimum prior value-area width in ATR units. |
| strategy_va_max_atr | 6.0 | 3.0-10.0 | Maximum prior value-area width in ATR units. |
| strategy_gap_max_atr | 2.0 | 1.0-4.0 | Maximum probe distance through VAH/VAL in ATR units. |
| strategy_session_start_hour | 9 | 0-23 | Broker-time hour when London/New York entry window starts. |
| strategy_session_end_hour | 22 | 0-23 | Broker-time hour when entry window ends. |
| strategy_ny_close_hour_broker | 23 | 0-23 | Broker-time NY close hour used for intraday flatten. |
| strategy_eod_flatten_min | 30 | 0-180 | Minutes before NY close to flatten open positions. |
| strategy_spread_pct_of_stop | 25.0 | 0-100 | Blocks only genuinely wide spread as percent of ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major with M30 OHLC and tick volume.
- GBPUSD.DWX - card-listed FX major with M30 OHLC and tick volume.
- USDJPY.DWX - card-listed FX major with M30 OHLC and tick volume.
- XAUUSD.DWX - card-listed gold CFD with M30 OHLC and tick volume.
- GDAXI.DWX - canonical DWX DAX symbol used for the card's GER40 exposure.

**Explicitly NOT for:**
- GER40.DWX - card name is not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX.
- Non-DWX symbols - registry and backtest context require the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | intraday, minutes to hours |
| Expected drawdown profile | mean-reversion losses cluster during strong directional session breaks |
| Regime preference | intraday mean-revert / value-area rejection |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** https://the5ers.com/market-profile-indicator/ and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11014_the5ers-mprof-va.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11014_the5ers-mprof-va.md`

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
| v1 | 2026-06-18 | Initial build from card | 52e92b9e-a477-4f62-8675-55f276e62aa4 |
