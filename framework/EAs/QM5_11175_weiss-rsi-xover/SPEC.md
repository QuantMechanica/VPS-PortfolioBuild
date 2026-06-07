# QM5_11175_weiss-rsi-xover - Strategy Spec

**EA ID:** QM5_11175
**Slug:** `weiss-rsi-xover`
**Source:** `3005c768-aa91-5daf-9dd7-500d7bfcb7a6` (see `sources/weissman-mechanical-trading-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades a short-term RSI threshold reversal on completed H1 bars. It enters long when RSI(14) was below 25 two closed bars ago and crosses back above 25 on the latest closed bar. It enters short when RSI(14) was above 75 two closed bars ago and crosses back below 75 on the latest closed bar. Each position uses a fixed 1% stop loss and a fixed 3% profit target from the entry price, with no indicator-based discretionary exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for RSI signal reads. |
| `strategy_rsi_period` | `14` | `2+` | RSI period from the card. |
| `strategy_rsi_lower` | `25.0` | `0 < lower < upper` | Lower RSI threshold for long crossover entries. |
| `strategy_rsi_upper` | `75.0` | `lower < upper < 100` | Upper RSI threshold for short crossover entries. |
| `strategy_stop_pct` | `1.0` | `> 0` | Fixed stop distance as percent of entry price. |
| `strategy_take_profit_pct` | `3.0` | `> 0` | Fixed target distance as percent of entry price. |
| `strategy_max_spread_sl_frac` | `0.10` | `>= 0` | Entry spread cap as a fraction of stop distance; `0` disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure matching the source Nasdaq 100 context.
- `SP500.DWX` - S&P 500 large-cap index exposure from the approved portable basket; backtest-only per DWX symbol discipline.
- `WS30.DWX` - Dow 30 large-cap index exposure from the approved portable basket.
- `EURUSD.DWX` - Liquid FX market included in the card's R3 basket.
- `XAUUSD.DWX` - Liquid metals market included in the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data route.

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
| Trades / year / symbol | `30` |
| Typical hold time | Hours to days until fixed 1% stop or 3% target is reached. |
| Expected drawdown profile | Mean-reversion drawdowns during persistent directional runs. |
| Regime preference | Mean-revert |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3005c768-aa91-5daf-9dd7-500d7bfcb7a6`
**Source type:** `book`
**Pointer:** Richard L. Weissman, Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis, Wiley, 2005, Chapter 5, pp. 98-101, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11175_weiss-rsi-xover.md`

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
| v1 | 2026-06-07 | Initial build from card | edfa191c-3ad8-4aaf-8a62-4e8b896563dc |
