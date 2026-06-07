# QM5_11128_tm-rsi25-75 - Strategy Spec

**EA ID:** QM5_11128
**Slug:** tm-rsi25-75
**Source:** 63b6d09c-d79f-561b-b577-eb5bf5878af1 (see `strategy-seeds/sources/63b6d09c-d79f-561b-b577-eb5bf5878af1/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates the last closed D1 bar. It enters long when the close is above the 200-day simple moving average and RSI(2) closes below 25, then enters at market on the next bar. It exits a long when RSI(2) closes above 75 or when the position has been held for 7 D1 bars. The short side is implemented as a disabled parameter variant: when enabled, it mirrors the rule below the 200-day average with RSI above 75 and exits below 25.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 2 | 2-4 | RSI period used for pullback entry and strength exit. |
| `strategy_long_entry_rsi` | 25.0 | 20.0-30.0 | Long pullback threshold. |
| `strategy_exit_rsi` | 75.0 | 65.0-85.0 | Long strength exit threshold and optional short entry threshold. |
| `strategy_trend_sma_period` | 200 | 100-200 | D1 trend filter SMA period. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-10.0 | ATR multiple for the protective stop. |
| `strategy_max_hold_d1_bars` | 7 | 1-30 | Maximum holding period measured in D1-bar equivalents. |
| `strategy_enable_shorts` | false | true/false | Enables the optional short-side ablation from the card. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure matching the source ETF universe; backtest-only per DWX custom-symbol caveat.
- `NDX.DWX` - Nasdaq 100 index exposure for liquid US large-cap technology beta.
- `WS30.DWX` - Dow 30 index exposure for liquid US large-cap equity beta.
- `GDAXI.DWX` - canonical matrix DAX symbol used as the available DAX equivalent for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - named by the card but not present in `framework/registry/dwx_symbol_matrix.csv`.
- Non-index `.DWX` symbols - the source edge is an ETF/index pullback pattern, not a forex, metal, or energy rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Up to 7 D1 bars |
| Expected drawdown profile | Mean-reversion pullbacks can cluster during broad equity selloffs; ATR stop bounds single-trade loss. |
| Regime preference | mean-revert in equity-index uptrends |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 63b6d09c-d79f-561b-b577-eb5bf5878af1
**Source type:** article
**Pointer:** David Penn, "ETF Software and RSI 25/75: High Probability Entries, High Probability Exits", TradingMarkets, 2009-10-21, https://tradingmarkets.com/recent/etf_software_and_rsi_2575_high_probability_entries_high_probability_exits-640384
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11128_tm-rsi25-75.md`

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
| v1 | 2026-06-07 | Initial build from card | e204ac1a-1f4e-4412-aa37-fba361916b83 |
