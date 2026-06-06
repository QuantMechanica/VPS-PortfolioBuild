# QM5_10981_ftmo-scalp-brk — Strategy Spec

**EA ID:** QM5_10981
**Slug:** `ftmo-scalp-brk`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades M5 index breakouts during the card's high-liquidity windows. It builds a 12-bar closed-bar range, requires the range height to sit between 0.6 and 1.8 times ATR(14), then buys a close above the range high or sells a close below the range low when tick volume is above 1.25 times the prior 20-bar median and price is on the correct side of EMA(20). The stop is placed one computed R beyond the broken range boundary, TP is 2R, stop moves to breakeven after 1R, and the EA exits when the last closed bar returns inside the pre-breakout range or after 12 M5 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_lookback` | 12 | 2-60 | Closed M5 bars used to define the pre-breakout high/low range. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for range-width qualification and stop distance. |
| `strategy_range_min_atr` | 0.6 | 0.1-5.0 | Minimum range height as a multiple of ATR. |
| `strategy_range_max_atr` | 1.8 | 0.1-5.0 | Maximum range height as a multiple of ATR. |
| `strategy_volume_lookback` | 20 | 2-100 | Closed bars used for median tick-volume confirmation. |
| `strategy_volume_mult` | 1.25 | 0.1-5.0 | Breakout candle volume must exceed this multiple of median volume. |
| `strategy_ema_period` | 20 | 2-200 | EMA filter period on M5 closes. |
| `strategy_stop_atr_mult` | 0.8 | 0.1-5.0 | ATR component of R for stop placement. |
| `strategy_stop_range_frac` | 0.5 | 0.1-2.0 | Range-height component of R for stop placement. |
| `strategy_tp_r_mult` | 2.0 | 0.5-10.0 | Take-profit multiple of actual entry-to-stop risk. |
| `strategy_max_hold_bars` | 12 | 1-100 | Time exit in M5 bars. |
| `strategy_spread_lookback` | 20 | 2-100 | Closed bars used for median spread filter. |
| `strategy_spread_mult` | 1.5 | 0.5-10.0 | Current spread must not exceed this multiple of median spread. |
| `strategy_false_break_minutes` | 30 | 5-240 | Lookback window for prior false breakout rejection. |
| `strategy_cash_open_skip_min` | 5 | 0-30 | Minutes skipped after the relevant cash-open window starts. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — canonical DWX DAX index available in the matrix; used as the build-time port for the card's `GER40.DWX`.
- `NDX.DWX` — Nasdaq 100 index CFD matching the card's US high-liquidity index target.
- `WS30.DWX` — Dow 30 index CFD matching the card's US high-liquidity index target.

**Explicitly NOT for:**
- `GER40.DWX` — named by the card but absent from `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX` — unavailable DWX variant; not part of the approved card basket.

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
| Trades / year / symbol | `80` |
| Typical hold time | Intraday, capped at 12 M5 bars after entry. |
| Expected drawdown profile | Small fixed-R losses during failed breakouts, with 2R winners when range expansion follows through. |
| Regime preference | Breakout / volatility-expansion during liquid index windows. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** `https://ftmo.com/en/blog/how-to-develop-a-scalping-strategy/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10981_ftmo-scalp-brk.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 0c7a6a52-1732-4a00-9263-2c85b853bb9e |
