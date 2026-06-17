# QM5_11192_ft-bandtastic — Strategy Spec

**EA ID:** QM5_11192
**Slug:** `ft-bandtastic`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Long-only Bollinger mean reversion ported from Robert Roman's freqtrade
`Bandtastic.py`. On the close of an M15 bar, enter long when the closed-bar
close prints below the lower Bollinger Band(20) at `bb_entry_std` deviations
(source default 1 std) — a stretched-below-the-band reversion buy. The source
"volume > 0" guard is a no-op on `.DWX` (tick volume is always positive on a
closed bar) and is omitted; the RSI/MFI/EMA buy guards are disabled by source
default (an optional RSI buy guard is provided, off by default, for the P3
sweep). Exit when BOTH source signal-exit conditions hold: MFI(14) on tick
volume is above `mfi_exit` (source 46) AND the close is above the upper
Bollinger Band(20) at `bb_exit_std` deviations (source 2). A protective ATR
stop, `QM_StopATR(14, atr_stop_mult)` (MT5 baseline replacing the source's
crypto-tuned -34.5% stoploss / ROI ladder / percentage trailing stop), plus the
framework Friday-close, close the position otherwise. No fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10-50 | Bollinger Band period |
| `strategy_bb_entry_std` | 1.0 | 1-3 | Lower-band deviation for the entry trigger |
| `strategy_bb_exit_std` | 2.0 | 1-3 | Upper-band deviation for the signal exit |
| `strategy_mfi_period` | 14 | 7-28 | Money Flow Index period (tick volume) |
| `strategy_mfi_exit` | 46.0 | 40-55 | MFI threshold for the signal exit |
| `strategy_enable_rsi_guard` | false | false/true | Enable optional RSI buy guard |
| `strategy_rsi_period` | 14 | 7-28 | RSI period for the optional buy guard |
| `strategy_rsi_guard_max` | 50.0 | 30-70 | If guard on: require RSI(1) below this |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the protective stop |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | Stop distance = mult × ATR |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip if spread > this % of stop distance |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; mean reversion to the band well-behaved.
- `GBPUSD.DWX` — liquid major with intraday range suiting M15 reversion.
- `USDJPY.DWX` — liquid major; tick-volume MFI portable.
- `XAUUSD.DWX` — metal with strong intraday mean-reversion episodes.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, `SP500.DWX`) — card baskets FX/metals only;
  trend persistence on indices works against a band-fade long.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` (capped conservative estimate after spread/news filters) |
| Typical hold time | `hours` (intraday M15 reversion) |
| Expected drawdown profile | `high risk class; reversion clusters in trends until the ATR stop trims` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `forum` (open-source freqtrade strategy repo)
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Bandtastic.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11192_ft-bandtastic.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | board-advisor worktree |
