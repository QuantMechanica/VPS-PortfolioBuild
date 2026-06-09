# QM5_10198_tv-barcount-rev - Strategy Spec

**EA ID:** QM5_10198
**Slug:** `tv-barcount-rev`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728`
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades H1 mean-reversion after a short exhaustion run. A long setup requires four consecutive falling closed bars, increasing tick volume through the sequence, and contact with or a break below the lower Bollinger Band. A short setup mirrors this with four consecutive rising closed bars, increasing tick volume, and contact with or a break above the upper Bollinger Band. The EA enters at market on the next bar while flat, uses the farther of 1.5 ATR(14) or the setup extreme for the stop, sets a 2.0R target, and exits early if price touches the Bollinger mid-band or the position reaches 12 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_consecutive_bars` | 4 | 1-20 | Number of same-direction closed bars required for the reversal setup. |
| `strategy_volume_confirm_enabled` | true | true/false | Requires each newer setup bar to have higher tick volume than the previous setup bar. |
| `strategy_bb_period` | 20 | 2-200 | Bollinger Band lookback used for channel contact and mid-band exit. |
| `strategy_bb_deviation` | 2.0 | 0.1-5.0 | Bollinger Band deviation multiplier. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for the stop-distance candidate. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for the stop-distance candidate. |
| `strategy_target_r` | 2.0 | 0.1-10.0 | Profit target in multiples of initial stop risk. |
| `strategy_time_stop_bars` | 12 | 1-100 | Maximum H1 bars to hold when neither mid-band nor target is reached. |
| `strategy_rollover_skip_minutes` | 15 | 0-60 | Minutes skipped after broker midnight and before broker day-end. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with continuous H1 OHLC and tick-volume data for the reversal pattern.
- `GBPUSD.DWX` - major FX pair with continuous H1 OHLC and tick-volume data for the reversal pattern.
- `XAUUSD.DWX` - liquid gold CFD with H1 OHLC, volume proxy, ATR, and Bollinger Band support.
- `GDAXI.DWX` - matrix-available DAX custom symbol used in place of the card's unavailable `DAX.DWX` name.
- `NDX.DWX` - liquid Nasdaq 100 index CFD compatible with the card's cross-asset channel-reversal logic.

**Explicitly NOT for:**
- Symbols outside the registered set above - runtime trading is blocked when the chart symbol has no matching magic slot.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Expected trade frequency | frequent H1 mean-reversion setups; card does not provide a separate frontmatter value |
| Typical hold time | up to 12 H1 bars by card time stop |
| Expected drawdown profile | fixed-risk, single-position mean-reversion losses bounded by initial stop |
| Regime preference | mean-reversion / counter-trend exhaustion after consecutive bars |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script page
**Pointer:** TradingView script `The Bar Counter Trend Reversal Strategy [TradeDots]`, author `tradedots`, published 2024-10-07, https://www.tradingview.com/script/0KAtQQDD-The-Bar-Counter-Trend-Reversal-Strategy-TradeDots/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10198_tv-barcount-rev.md`

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
| v1 | 2026-06-09 | Initial build from card | edc3d2ca-e4dc-4a88-b186-d6ff01152719 |
