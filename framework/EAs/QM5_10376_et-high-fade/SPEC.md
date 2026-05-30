# QM5_10376_et-high-fade - Strategy Spec

**EA ID:** QM5_10376
**Slug:** `et-high-fade`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. It buys when the last closed bar made the highest high of the configured lookback window and closed below the previous bar's close, then enters on the next bar through a market order. When the symmetric short input is enabled, it sells when the last closed bar made the lowest low of the lookback window and closed above the previous bar's close. Each trade uses an ATR(14)-based stop, ATR-based target, and a max-hold time stop if neither protective order fires first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bars_back` | 4 | 4, 8, 12, 20 | Lookback window for the new-high or new-low test. |
| `strategy_atr_period` | 14 | fixed baseline | ATR period for stop, target, and volatility floor. |
| `strategy_stop_atr` | 0.75 | 0.5-1.5 | Stop-loss distance in ATR multiples. |
| `strategy_target_atr` | 1.0 | 0.5-2.0 | Profit-target distance in ATR multiples. |
| `strategy_max_hold_bars` | 12 | 6-48 | Number of H1 bars after which an open trade is closed. |
| `strategy_symmetric_short` | true | true/false | Enables the V5 symmetric short variant from the card. |
| `strategy_min_atr_points` | 1.0 | >= 0 | Minimum ATR(14) in symbol points; 0 disables the floor. |
| `strategy_index_session_start_hour` | 9 | 0-23 | First index session hour excluded for intraday CFDs. |
| `strategy_index_session_end_hour` | 22 | 1-24 | Session end marker; the prior hour is excluded for intraday CFDs. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card names EURUSD and DWX matrix confirms the forex symbol.
- `GBPUSD.DWX` - card names GBPUSD and DWX matrix confirms the forex symbol.
- `XAUUSD.DWX` - card names XAUUSD.DWX and DWX matrix confirms the metals symbol.
- `GDAXI.DWX` - DAX exposure port for the card's GER40.DWX target; DWX matrix canonical DAX symbol.
- `SP500.DWX` - card names SP500.DWX and DWX matrix confirms the backtest-only S&P 500 custom symbol.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX` for DAX exposure.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; canonical custom symbol is `SP500.DWX`.

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
| Trades / year / symbol | `45` |
| Typical hold time | `6-48 H1 bars, baseline 12 bars` |
| Expected drawdown profile | `Counter-trend failed-extreme setup; main risk is entering into genuine breakouts.` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/tradestation-easylanguage.123919/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10376_et-high-fade.md`

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
| v1 | 2026-05-25 | Initial build from card | 68107987-21cd-4a6f-9af6-8feafa3f0fcc |
