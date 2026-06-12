# QM5_10333_dax-loser-rev - Strategy Spec

**EA ID:** QM5_10333
**Slug:** `dax-loser-rev`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates a four-index basket once per hour during the main European cash session on M5 data. It calculates each symbol's return over the prior 60 minutes and buys only the current chart symbol when that symbol is the worst performer and its return is below `-0.50 * ATR(14,M5) / close`. The stop is placed `0.75 * ATR(14,M5)` below entry, the take-profit is the prior 60-minute range midpoint when that midpoint is above entry, and any still-open position is closed after 60 minutes or at the session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | M5 expected | Signal timeframe from the card. |
| `strategy_session_start_hhmm` | `900` | 0000-2359 | Main European cash session start in broker time. |
| `strategy_session_end_hhmm` | `1730` | 0000-2359 | Main European cash session end in broker time. |
| `strategy_session_skip_minutes` | `15` | 0-120 | Minutes skipped after session open and before session close. |
| `strategy_ranking_minutes` | `60` | 15-240 | Return-ranking lookback window. |
| `strategy_holding_minutes` | `60` | 15-240 | Maximum holding time. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for entry threshold and stop. |
| `strategy_entry_atr_fraction` | `0.50` | 0.10-2.00 | Loser-return threshold as ATR fraction divided by close. |
| `strategy_stop_atr_mult` | `0.75` | 0.10-5.00 | ATR multiple used for the stop loss. |
| `strategy_min_valid_symbols` | `3` | 1-4 | Minimum basket symbols with valid bars before ranking is allowed. |
| `strategy_spread_lookback_bars` | `240` | 0-2000 | M5 bars used for rolling spread percentile. |
| `strategy_spread_percentile` | `80.0` | 1.0-100.0 | Current spread must be at or below this rolling percentile. |
| `strategy_min_stop_spread_mult` | `4.0` | 1.0-20.0 | Stop distance must be at least this many current spreads. |
| `strategy_basket_warmup_bars` | `1200` | 100-5000 | Bars requested to warm basket symbol history in tester. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX proxy registered because `GER40.DWX` is not present in `dwx_symbol_matrix.csv`.
- `SP500.DWX` - US large-cap index proxy named in the card's portable basket; backtest-only caveat applies at T6.
- `NDX.DWX` - Nasdaq 100 liquid index proxy named in the card's portable basket.
- `WS30.DWX` - Dow 30 liquid index proxy named in the card's portable basket.

**Explicitly NOT for:**
- `GER40.DWX` - named by card frontmatter but absent from the DWX matrix, so it is not registered.
- `DE30.DWX` - DAX naming variant absent from the current DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | `60 minutes` |
| Expected drawdown profile | Intraday single-leg losses bounded by a 0.75 ATR stop and no overnight holding. |
| Regime preference | Intraday loser-reversal mean reversion across liquid index sessions. |
| Win rate target (qualitative) | medium |

Expected trade frequency from the card: "Intraday loser-reversal evaluated on liquid sessions; conservative estimate 120 trades/year/symbol after spread and signal filters."

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** paper
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10333_dax-loser-rev.md`
**R1-R4 verdict (Q00):** frontmatter R1-R4 PASS per `artifacts/cards_approved/QM5_10333_dax-loser-rev.md`; the body's R3 table also documents that the DWX port uses proxy index CFDs rather than source-identical DAX constituents.

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
| v1 | 2026-06-13 | Initial build from card | 437cc137-f94e-4021-b2ef-ae8d4f4f17bd |
