# QM5_10559_mql5-wpr-slow - Strategy Spec

**EA ID:** QM5_10559
**Slug:** `mql5-wpr-slow`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes Williams Percent Range on closed H6 bars. It opens long when WPR has been falling into the oversold zone and then turns up on the just-closed bar, and it opens short when WPR has been rising into the overbought zone and then turns down on the just-closed bar. A long is closed on the opposite bearish WPR slowdown arrow, and a short is closed on the opposite bullish arrow. Every entry carries an ATR(14) 2.0 hard stop and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H6` | H4-H12 | Timeframe used for WPR slowdown signals. |
| `strategy_wpr_period` | `14` | 2-100 | Williams Percent Range lookback. |
| `strategy_oversold_level` | `-80.0` | -100--50 | WPR zone used for bullish reversal arrows. |
| `strategy_overbought_level` | `-20.0` | -50-0 | WPR zone used for bearish reversal arrows. |
| `strategy_slowdown_bars` | `2` | 1-10 | Number of prior closed bars that must show one-way WPR movement before reversal. |
| `strategy_atr_period` | `14` | 2-100 | ATR lookback for hard stop distance. |
| `strategy_atr_sl_mult` | `2.0` | 0.5-10 | ATR multiple for stop loss. |
| `strategy_reward_r_multiple` | `1.5` | 0.5-10 | Target distance as a multiple of initial risk. |
| `strategy_ema_filter_enabled` | `false` | true/false | Optional EMA200 directional filter from the card sweep notes. |
| `strategy_ema_period` | `200` | 20-400 | EMA period used only when the optional filter is enabled. |
| `strategy_max_spread_points` | `0` | 0-1000 | Optional spread cap; zero disables the strategy-level cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURAUD.DWX` - source test symbol and card primary FX basket member.
- `EURUSD.DWX` - liquid major FX pair in the approved R3 basket.
- `GBPUSD.DWX` - liquid major FX pair in the approved R3 basket.
- `XAUUSD.DWX` - approved R3 metal symbol with OHLC-derived WPR compatibility.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid DWX backtest targets for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H6` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | hours to days |
| Expected drawdown profile | ATR-bounded reversal drawdowns with one active position per symbol/magic. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/16560`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10559_mql5-wpr-slow.md`

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
| v1 | 2026-05-29 | Initial build from card | ffa2ec1d-d978-4b42-bc89-e4134c243a77 |
