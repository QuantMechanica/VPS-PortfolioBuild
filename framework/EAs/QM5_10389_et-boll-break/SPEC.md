# QM5_10389_et-boll-break - Strategy Spec

**EA ID:** QM5_10389
**Slug:** `et-boll-break`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA trades H1 close breakouts beyond a 35-period Bollinger Band envelope. It enters long when the last closed H1 bar closes above the upper band and enters short when the last closed H1 bar closes below the lower band. Open long positions close when the last closed H1 bar closes below the 35-period middle line, and open short positions close when it closes above the middle line. A protective stop is placed at 2.0 x ATR(14) from entry and no profit target, trailing stop, partial close, or pyramiding rule is used.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 35 | 20-50 | Bollinger Band and SMA middle-line lookback |
| `strategy_bb_deviation` | 2.0 | 1.5-2.5 | Bollinger standard-deviation multiplier |
| `strategy_atr_period` | 14 | 1-100 | ATR lookback for the protective stop |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | ATR multiple used for initial stop loss |
| `strategy_min_band_spreads` | 8.0 | 1.0-50.0 | Minimum Bollinger width measured in current spreads |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair named by the card.
- `GBPUSD.DWX` - liquid major FX pair named by the card.
- `XAUUSD.DWX` - liquid metals CFD named by the card.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` target.
- `NDX.DWX` - liquid US index CFD named by the card.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tick-data registration.

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
| Typical hold time | Not specified in frontmatter; expected to hold from breakout until the H1 close crosses the 35-period middle line |
| Expected drawdown profile | Whipsaw risk in low-volatility ranges with ATR-defined loss per trade |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/lets-improve-basic-easylanguage-program.84690/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10389_et-boll-break.md`

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
| v1 | 2026-05-25 | Initial build from card | a59977ca-876c-4d45-9f0a-9c9ef7a529c4 |
