# QM5_11129_tm-rsi25 - Strategy Spec

**EA ID:** QM5_11129
**Slug:** tm-rsi25
**Source:** 63b6d09c-d79f-561b-b577-eb5bf5878af1 (see `strategy-seeds/sources/63b6d09c-d79f-561b-b577-eb5bf5878af1/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates the last closed D1 bar. It enters long when the D1 close is above the 200-day simple moving average and RSI(4) closes below 25, then enters at market on the next bar. It exits the long when RSI(4) closes above 55, or when the position has been open for 7 D1-bar equivalents. The source add-on unit is disabled for this baseline so the EA keeps one active position per symbol and magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 4 | 2-14 | RSI period used for pullback entry and strength exit. |
| `strategy_entry_rsi` | 25.0 | 20.0-30.0 | Long oversold pullback threshold. |
| `strategy_exit_rsi` | 55.0 | 50.0-60.0 | RSI strength threshold for discretionary exit. |
| `strategy_trend_sma_period` | 200 | 100-200 | D1 trend filter SMA period. |
| `strategy_atr_period` | 14 | 1-100 | D1 ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-10.0 | ATR multiple for the protective stop. |
| `strategy_max_hold_d1_bars` | 7 | 1-30 | Maximum holding period measured in D1-bar equivalents. |
| `strategy_max_spread_points` | 250 | 0-10000 | Wide-spread entry skip; 0 disables this strategy-level cap. |

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
| Trades / year / symbol | 12 |
| Typical hold time | 3-7 days |
| Expected drawdown profile | Mean-reversion pullbacks can cluster during broad equity selloffs; ATR stop bounds single-trade loss. |
| Regime preference | mean-revert in equity-index uptrends |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 63b6d09c-d79f-561b-b577-eb5bf5878af1
**Source type:** article
**Pointer:** Larry Connors, "Connors Research Traders Journal (Volume 1): Does Mean Reversion Still Work?", TradingMarkets, 2018-04-17, https://tradingmarkets.com/recent/does-mean-reversion-still-work-1593757
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11129_tm-rsi25.md`

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
| v1 | 2026-06-07 | Initial build from card | 988092ba-814a-4a3d-89d5-68056129188f |
