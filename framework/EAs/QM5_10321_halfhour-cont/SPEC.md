# QM5_10321_halfhour-cont - Strategy Spec

**EA ID:** QM5_10321
**Slug:** halfhour-cont
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades M30 bars during a configured regular-session window. At the start of each eligible 30-minute slot it finds the same slot on prior trading days, goes long when the previous trading day's same-slot return is positive and the average of the prior five same-slot returns is non-negative, and goes short when both signs are negative/non-positive. It skips the first and final session slots, requires at least ten prior same-slot trading-day samples, blocks abnormally wide current spread versus same-slot historical median spread, uses a 0.50 x ATR(14) emergency stop, and exits after one 30-minute slot.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_start_hhmm` | 1630 | 0000-2359 | Broker-time start of the regular-session window used to define 30-minute slots. |
| `strategy_session_end_hhmm` | 2300 | 0000-2359 | Broker-time end of the regular-session window. |
| `strategy_slot_minutes` | 30 | 30 | Fixed slot size from the card. |
| `strategy_history_days` | 10 | 10+ | Minimum prior trading-day same-slot samples required before trading. |
| `strategy_avg_days` | 5 | 1-10 | Number of prior same-slot returns used for the persistence filter. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the emergency stop. |
| `strategy_atr_sl_mult` | 0.50 | >0 | ATR multiple for the emergency stop distance. |
| `strategy_spread_median_mult` | 1.50 | >0 | Maximum current spread as a multiple of same-slot historical median spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index CFD/custom symbol port named in R3; backtest-only caveat remains a T6 gate issue.
- `NDX.DWX` - Nasdaq 100 liquid US index CFD named in the R3 portable basket.
- `WS30.DWX` - Dow 30 liquid US index CFD named in the R3 portable basket.
- `GDAXI.DWX` - Matrix-valid DAX 40 custom symbol used as the available port for the card's GER40/DAX target.
- `UK100.DWX` - FTSE 100 index CFD named in the R3 portable basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build does not register phantom or broker-unavailable symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate before `Strategy_EntrySignal` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Expected trade frequency | Not specified in frontmatter; card cadence implies intraday same-slot opportunities during eligible regular-session slots. |
| Typical hold time | One 30-minute slot; no overnight holding. |
| Expected drawdown profile | Emergency ATR stop only; losses should be bounded per-trade by HR4 fixed-risk sizing. |
| Regime preference | Intraday return continuation / seasonality. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1107590
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10321_halfhour-cont.md`

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
| v1 | 2026-06-12 | Initial build from card | ffb279ec-f463-419f-8fea-7cccacd4c36a |
