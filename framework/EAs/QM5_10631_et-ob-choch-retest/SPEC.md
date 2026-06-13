# QM5_10631_et-ob-choch-retest - Strategy Spec

**EA ID:** QM5_10631
**Slug:** `et-ob-choch-retest`
**Source:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64` (see `strategy-seeds/sources/cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates completed M30 bars for a reversal change of character. A long setup requires a prior bearish swing sequence, a close above the previous confirmed swing high by an ATR buffer, a bullish imbalance in the impulse candle, and a retest limit at the configured fraction of the last bearish order-block candle. A short setup mirrors this logic after a prior bullish swing sequence and a close below the previous confirmed swing low. Exits are the broker SL/TP, a close back through the original ChoCh level, or a time stop after the configured number of M30 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period used for ChoCh buffer, impulse filter, OB height filter, and SL offset. |
| `strategy_swing_width` | 3 | 2-5 | Confirmed swing width on each side of the pivot. |
| `strategy_choch_break_atr` | 0.10 | 0.05-0.20 | Minimum close break beyond the prior swing as an ATR multiple. |
| `strategy_ob_entry_fraction` | 0.50 | 0.25-0.75 | Order-block zone fraction used for the limit entry. |
| `strategy_ob_sl_atr` | 0.20 | 0.10-0.50 | ATR offset beyond the order-block extreme for stop placement. |
| `strategy_rr` | 2.00 | 1.0-3.0 | Maximum reward/risk target before capping at the opposing swing. |
| `strategy_ob_max_height_atr` | 1.40 | 0.5-2.5 | Maximum order-block height as an ATR multiple. |
| `strategy_impulse_min_range_atr` | 0.80 | 0.25-2.0 | Minimum ChoCh candle range as an ATR multiple. |
| `strategy_same_dir_lookback_bars` | 20 | 5-50 | Blocks repeat same-direction ChoCh signals in the recent lookback. |
| `strategy_pending_expiry_bars` | 10 | 1-20 | Limit order expiration in M30 bars. |
| `strategy_time_exit_bars` | 40 | 24-56 | Maximum hold time in M30 bars. |
| `strategy_ob_search_bars` | 12 | 3-30 | Search depth for the last opposite candle before the impulse. |
| `strategy_history_bars` | 140 | 60-300 | Closed-bar history used to identify swings and recent ChoCh events. |
| `strategy_timeframe` | M30 | M30 | Base timeframe used by all strategy logic. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with DWX OHLC coverage.
- `GBPUSD.DWX` - card-listed FX major with DWX OHLC coverage.
- `USDJPY.DWX` - card-listed FX major with DWX OHLC coverage.
- `XAUUSD.DWX` - card-listed metals symbol with DWX OHLC coverage.
- `NDX.DWX` - card-listed index symbol with DWX OHLC coverage.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must retain the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the card requires only matrix-verified symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | Up to 40 M30 bars by card time exit. |
| Expected drawdown profile | Reversal entries with fixed initial risk and no averaging. |
| Regime preference | ChoCh reversal after imbalance and order-block retest. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/a-way-to-track-the-moves-of-big-players.380018/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10631_et-ob-choch-retest.md`

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
| v1 | 2026-06-13 | Initial build from card | 2adb74fe-ad57-452e-8df9-5c71c9844cb5 |
