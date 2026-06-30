# QM5_12787_vol-contraction-breakout - Strategy Spec

**EA ID:** QM5_12787
**Slug:** vol-contraction-breakout
**Source:** vol-contraction-breakout-inhouse-2026-06-29 (see `artifacts/cards_approved/QM5_12787_vol-contraction-breakout.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA looks for a closed-bar volatility contraction using the selected squeeze method. When a squeeze is present, it defines a box from the highest high and lowest low over `strategy_box_lookback` closed bars, then arms a buy stop above the box and a sell stop below the box with an ATR or percent buffer. The stop loss is either the opposite box side or an ATR distance, and the take profit is a fixed R multiple. In intraday mode the EA removes pending orders and force-closes open positions at the configured broker-time close hour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_squeeze_method` | `STRAT_SQZ_NR_BAR` | enum 0-4 | Squeeze detector: NR bar, Bollinger BandWidth low, ATR ratio, Donchian width low, or BB-inside-Keltner. |
| `strategy_squeeze_lookback` | 7 | 2-100 | Bars used by NR and Donchian squeeze tests. |
| `strategy_squeeze_rank_lookback` | 20 | 2-250 | Prior windows used to decide whether BandWidth or Donchian width is at a multi-period low. |
| `strategy_box_lookback` | 7 | 2-100 | Closed bars used to form the breakout box high and low. |
| `strategy_atr_short_period` | 5 | >0 | Short ATR period for ATR-ratio squeeze mode. |
| `strategy_atr_long_period` | 20 | >0 | Long ATR period for ATR-ratio squeeze mode. |
| `strategy_squeeze_ratio` | 0.75 | >0 | ATR short/long threshold for contracted volatility. |
| `strategy_bb_period` | 20 | >1 | Bollinger and Keltner middle period. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger band standard-deviation multiplier. |
| `strategy_kc_atr_mult` | 1.5 | >0 | Keltner ATR multiplier for BB-inside-Keltner mode. |
| `strategy_atr_period` | 14 | >0 | ATR period for buffer, box-size filter, ATR stop, and spread cap. |
| `strategy_entry_buffer_atr_mult` | 0.10 | >=0 | ATR multiplier added above/below the box for stop entries. |
| `strategy_entry_buffer_pct` | 0.0 | >=0 | Optional percent-of-price entry buffer; the EA uses the larger of ATR buffer and percent buffer. |
| `strategy_stop_mode` | `STRAT_STOP_BOX` | enum 0-1 | Stop mode: opposite box side or ATR distance. |
| `strategy_sl_atr_mult` | 1.50 | >0 | ATR stop multiplier when ATR stop mode is selected. |
| `strategy_tp_r` | 1.75 | >0 | Fixed take-profit multiple of entry risk. |
| `strategy_min_box_atr` | 0.20 | >0 | Minimum box size, scaled by ATR times square root of box lookback. |
| `strategy_max_box_atr` | 3.00 | > min | Maximum box size, scaled by ATR times square root of box lookback. |
| `strategy_max_spread_atr` | 0.20 | >=0 | Wide-spread cap in ATR units; zero DWX modeled spread is allowed. |
| `strategy_atr_expansion_confirm` | false | bool | Optional filter requiring the latest closed bar range to exceed the box range. |
| `strategy_move_to_be_enabled` | true | bool | Move stop to entry once price has moved at least 1R in favor. |
| `strategy_order_expiry_bars` | 0 | >=0 | Pending-order expiry in bars; 0 means GTC until EOD cleanup or fill. |
| `strategy_hold_mode` | `STRAT_HOLD_INTRADAY` | enum 0-1 | Intraday EOD-flat mode or daily hold mode. |
| `strategy_close_hour_broker` | 21 | 0-23 | Broker hour for intraday force-flat. |
| `strategy_close_minute_broker` | 0 | 0-59 | Broker minute for intraday force-flat. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - canonical Nasdaq 100 target from the card's NDX instrument.
- `SP500.DWX` - canonical backtest-only S&P 500 mapping for the card's US500 target.
- `GDAXI.DWX` - canonical DAX/Germany index mapping for the card's GER40 target in this matrix.
- `XAUUSD.DWX` - gold target named directly by the card.
- `XTIUSD.DWX` - WTI crude oil target named directly by the card.
- `XNGUSD.DWX` - natural gas mapping for the card's NATGAS target.

**Explicitly NOT for:**
- `US500.DWX`, `GER40.DWX`, `NATGAS.DWX` - not canonical names in `dwx_symbol_matrix.csv`; use `SP500.DWX`, `GDAXI.DWX`, and `XNGUSD.DWX`.
- Sector ETFs or unavailable futures symbols - the card targets liquid DWX indices, gold, and energy only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` build/smoke default; the card also names `M15` and `D1` as post-build grid variants |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Expected PF | 1.40 |
| Expected drawdown profile | About 10% standalone drawdown from the card frontmatter |
| Typical hold time | Intraday, flat by configured broker close hour; daily hold only if `strategy_hold_mode` is changed |
| Regime preference | Volatility-contraction into volatility-expansion breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `vol-contraction-breakout-inhouse-2026-06-29`
**Source type:** OWNER / in-house strategy build
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12787_vol-contraction-breakout.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12787_vol-contraction-breakout.md`

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
| v1 | 2026-06-30 | Initial build from card | 82c5289d-120f-4530-86bd-64e94208dbb5 |
