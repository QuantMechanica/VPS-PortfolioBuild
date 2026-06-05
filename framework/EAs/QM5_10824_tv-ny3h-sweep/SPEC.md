# QM5_10824_tv-ny3h-sweep - Strategy Spec

**EA ID:** QM5_10824
**Slug:** `tv-ny3h-sweep`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades the New York open on M5 bars. It reads the previous completed 3-hour range, waits during the configured New York opening window for price to sweep below the prior range low or above the prior range high, then enters after the closed bar confirms by breaking a recent swing high for longs or swing low for shorts. Long trades target the prior 3-hour high and place the stop below the sweep low plus an ATR buffer; short trades target the prior 3-hour low and place the stop above the sweep high plus an ATR buffer. The EA limits baseline trading to one trade per New York day and force-closes open positions at the configured New York flat time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_tf` | `PERIOD_H3` | `PERIOD_H2`-`PERIOD_H4` test axis | Timeframe used for the previous completed range. |
| `strategy_swing_lookback_bars` | `5` | `3`-`8` test axis | M5 bars used to define the recent swing high or low. |
| `strategy_atr_period` | `14` | `14` baseline | ATR period for the stop buffer. |
| `strategy_stop_buffer_atr_fraction` | `0.10` | `0.00`-`0.20` test axis | ATR fraction added beyond the sweep extreme for the stop. |
| `strategy_max_stop_range_mult` | `1.50` | `0.10`+ | Skip trades when stop distance exceeds this multiple of the 3-hour range. |
| `strategy_ny_open_start_hhmm` | `930` | `900`-`930` test axis | New York local start time for sweep detection. |
| `strategy_ny_open_end_hhmm` | `1030` | `1030`-`1100` test axis | New York local end time for new entries. |
| `strategy_ny_flat_hhmm` | `1100` | `1030`-`1600` | New York local time to force flat. |
| `strategy_one_trade_per_day` | `true` | `true`/`false` | Enforce the card baseline one-trade-per-symbol-per-day rule. |
| `strategy_breakeven_enabled` | `true` | `true`/`false` test axis | Move stop to entry after price reaches +1R. |
| `strategy_max_spread_points` | `0.0` | `0.0`+ | Optional spread cap; `0.0` disables the spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure named in the card's primary P2 basket.
- `WS30.DWX` - Dow 30 index exposure named in the card's primary P2 basket.
- `GDAXI.DWX` - Available DWX DAX custom symbol used as the nearest matrix-valid port for card-stated `GER40.DWX`.
- `XAUUSD.DWX` - Gold CFD exposure named in the card's primary P2 basket.
- `EURUSD.DWX` - FX major exposure named in the card's primary P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated DAX label is not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX S&P 500 custom symbol names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | Previous completed `PERIOD_H3` range by default |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday; card does not specify a frontmatter hold-time value |
| Expected drawdown profile | Main risks are NY-open spread/slippage and false reclaim breaks in choppy index sessions |
| Regime preference | Intraday liquidity-sweep continuation / range-continuation |
| Win rate target (qualitative) | Card does not specify a frontmatter win-rate target |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/0vL9Hcs2/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10824_tv-ny3h-sweep.md`

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
| v1 | 2026-06-06 | Initial build from card | 9754cf16-43fe-4e4b-86e0-1b2d131a9dfa |
