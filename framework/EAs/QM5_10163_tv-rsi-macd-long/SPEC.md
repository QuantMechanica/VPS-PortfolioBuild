# QM5_10163_tv-rsi-macd-long - Strategy Spec

**EA ID:** QM5_10163
**Slug:** `tv-rsi-macd-long`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long-only H1 momentum entries from the approved TradingView RSI
and MACD card. It enters when RSI(14) crosses above the 50 midline while MACD is
above its signal line, or when MACD(12,26,9) crosses above its signal line while
RSI is at or above 50. The baseline also requires price to be above EMA(200),
keeps the oversold-context filter disabled, and exits when RSI crosses back below
50 or MACD crosses below its signal with a non-positive histogram. Each entry has
a 3.0% take profit and a 1.5% stop loss, with the stop widened to at least
1.0 ATR(14) when needed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for RSI, MACD, EMA, and ATR reads. |
| `strategy_rsi_period` | `14` | `> 0` | RSI lookback period. |
| `strategy_rsi_midline` | `50.0` | `0.0-100.0` | RSI threshold for long entries and exits. |
| `strategy_macd_fast` | `12` | `> 0` | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | `> strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | `> 0` | MACD signal EMA period. |
| `strategy_require_macd_gt0` | `true` | `true/false` | Requires MACD main line above zero for entries when enabled. |
| `strategy_use_ema_filter` | `true` | `true/false` | Requires last closed price above EMA(200) when enabled. |
| `strategy_ema_period` | `200` | `> 0` | EMA trend filter period. |
| `strategy_use_oversold_ctx` | `false` | `true/false` | Enables the optional recent-oversold RSI context filter. |
| `strategy_oversold_lookback` | `20` | `>= 0` | Bars checked for the optional RSI oversold context. |
| `strategy_oversold_level` | `30.0` | `0.0-100.0` | RSI level used by the optional oversold context filter. |
| `strategy_atr_period` | `14` | `> 0` | ATR period used for minimum stop-distance sanity. |
| `strategy_sl_percent` | `1.5` | `> 0.0` | Stop loss percent below entry price. |
| `strategy_tp_percent` | `3.0` | `> 0.0` | Take profit percent above entry price. |
| `strategy_min_sl_atr_mult` | `1.0` | `>= 0.0` | Minimum stop distance as ATR multiple. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index CFD fits the long-only index momentum thesis.
- `SP500.DWX` - S&P 500 custom symbol fits the index thesis; backtest-only per DWX discipline.
- `WS30.DWX` - Dow 30 index CFD adds a second live-routable US index proxy.
- `GDAXI.DWX` - DAX index CFD fits the OHLC-derived global index extension.
- `UK100.DWX` - FTSE 100 index CFD fits the OHLC-derived global index extension.
- `XAUUSD.DWX` - gold is explicitly named by the card as a long-only variant.
- `EURUSD.DWX` - major FX pair included in the registered long-only variant basket.
- `GBPUSD.DWX` - major FX pair included in the registered long-only variant basket.
- `USDJPY.DWX` - major FX pair included in the registered long-only variant basket.
- `USDCAD.DWX` - major FX pair included in the registered long-only variant basket.
- `USDCHF.DWX` - major FX pair included in the registered long-only variant basket.

**Explicitly NOT for:**
- Any symbol not listed above - the EA is registered only for the active
  `magic_numbers.csv` rows for QM5_10163.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none by default; `strategy_signal_tf` is configurable but defaults to H1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Expected trade frequency | not specified in card frontmatter |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | fixed-risk stop/TP momentum drawdowns, bounded by V5 risk controls |
| Regime preference | momentum / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `RSI + MACD Long-Only Strategy`, author handle
`agrothe`, published 2025-08-08, https://www.tradingview.com/script/m99D8MgQ-RSI-MACD-Long-Only-Strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10163_tv-rsi-macd-long.md`

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
| v1 | 2026-06-09 | Initial build from card | 39607515-528f-4bd0-b322-dce809f93fb4 |
