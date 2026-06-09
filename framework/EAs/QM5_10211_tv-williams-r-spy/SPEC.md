# QM5_10211_tv-williams-r-spy - Strategy Spec

**EA ID:** QM5_10211
**Slug:** tv-williams-r-spy
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see strategy card frontmatter)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades a long-only daily mean-reversion signal on major index symbols. On each closed D1 bar, it computes Williams %R from a configurable 2-25 bar lookback and opens a long position when Williams %R is below -90. It exits an open long when Williams %R rises above -30, or when the latest closed D1 close is higher than the prior D1 high. The protective stop is the tighter of 2.5 * ATR(14) below entry and a 5% price stop below entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wpr_length` | 2 | 2-25 | Williams %R lookback length for D1 signal calculation. |
| `strategy_entry_wpr` | -90.0 | -100 to 0 | Long entry threshold; enter when Williams %R is below this value. |
| `strategy_exit_wpr` | -30.0 | -100 to 0 | Oscillator exit threshold; exit when Williams %R is above this value. |
| `strategy_atr_period` | 14 | >=1 | ATR lookback used for the protective stop. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiplier for the protective stop below entry. |
| `strategy_price_sl_pct` | 5.0 | >0 | Percent-price protective stop below entry. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol used as the SPY analog for backtesting.
- `NDX.DWX` - Nasdaq 100 index CFD cross-check for US large-cap technology exposure.
- `WS30.DWX` - Dow 30 index CFD cross-check for US large-cap industrial exposure.

**Explicitly NOT for:**
- Non-index forex, metals, and energy symbols - the source logic is a SPY-style index reversal baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | days |
| Expected drawdown profile | Mean-reversion pullbacks can cluster during index selloffs; protective stop bounds single-trade loss. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView popular Pine script
**Pointer:** TradingView script `Williams %R Strategy`, author handle `EdgeTools`, published 2024-10-15, https://www.tradingview.com/script/WgrZZgCZ/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10211_tv-williams-r-spy.md`

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
| v1 | 2026-06-09 | Initial build from card | 1607bf10-4df8-4d48-bf9e-2ef96401797c |
