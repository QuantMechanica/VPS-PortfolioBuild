# QM5_10330_illiq-rev - Strategy Spec

**EA ID:** QM5_10330
**Slug:** `illiq-rev`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see `artifacts/cards_approved/QM5_10330_illiq-rev.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades H1 short-run reversal after a liquidity-pressure event. A long signal occurs when the just-closed H1 close-to-close return is less than `-0.75 * ATR(14)`, the closed-bar spread is at or above the 70th percentile of its 60-day history, and closed-bar tick volume is at or above the 70th percentile of its 60-day history. A short signal is the mirror image after a positive `0.75 * ATR(14)` return shock. Each position uses a `1.00 * ATR(14)` stop, no take-profit, and exits after two H1 bars or when the configured cash-session window closes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period for return-shock threshold and stop distance. |
| `strategy_return_atr_mult` | 0.75 | 0.10-5.00 | H1 return shock multiplier versus ATR. |
| `strategy_stop_atr_mult` | 1.00 | 0.10-10.00 | Stop-loss distance multiplier versus ATR. |
| `strategy_percentile_days` | 60 | 5-252 | Lookback in trading days for spread and tick-volume percentile ranks. |
| `strategy_bars_per_day` | 24 | 1-24 | H1 bars per day used to convert day lookbacks into bars. |
| `strategy_spread_percentile_min` | 70.0 | 0-100 | Minimum spread percentile rank for liquidity-pressure entry. |
| `strategy_volume_percentile_min` | 70.0 | 0-100 | Minimum tick-volume percentile rank for liquidity-pressure entry. |
| `strategy_session_start_hour` | 8 | 0-23 | Broker-hour start of the main cash-session window. |
| `strategy_session_end_hour` | 22 | 0-24 | Broker-hour end of the main cash-session window. |
| `strategy_max_hold_bars` | 2 | 1-24 | Maximum H1 bars to hold a position. |
| `strategy_min_stop_spreads` | 4 | 1-20 | Minimum stop distance expressed as current spreads. |
| `strategy_spread_session_count` | 20 | 5-60 | Prior sessions used for the median-spread regime filter. |
| `strategy_spread_year_sessions` | 252 | 60-366 | Session medians used for the one-year spread 80th percentile. |
| `strategy_skip_monday_first_session` | true | true/false | Skip the first configured session bar after weekend reopen. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index proxy named in the card, valid for backtest.
- `NDX.DWX` - Nasdaq 100 index proxy named in the card.
- `WS30.DWX` - Dow 30 index proxy named in the card.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` target.
- `XAUUSD.DWX` - liquid metals proxy named in the card.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available in the DWX backtest universe.
- `GER40.DWX` - card-stated alias is not present in the DWX matrix; `GDAXI.DWX` is the available DAX symbol.

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
| Trades / year / symbol | `60` |
| Typical hold time | Two H1 bars or less, per card exit rule. |
| Expected drawdown profile | Short-horizon mean-reversion losses cluster when liquidity pressure continues instead of reversing. |
| Regime preference | Mean-revert / liquidity-pressure reversal. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** paper
**Pointer:** `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=555968`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10330_illiq-rev.md`

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
| v1 | 2026-06-12 | Initial build from card | 2091fa3f-c358-4035-ad49-382da49e5540 |
