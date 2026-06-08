# QM5_11207_ft-avg-ema - Strategy Spec

**EA ID:** QM5_11207
**Slug:** `ft-avg-ema`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades a long-only H4 EMA crossover. It opens long when EMA(8) crosses above EMA(21) on the last closed bar and the closed bar has positive tick volume. It closes the open position when EMA(21) crosses above EMA(8), or through the ATR stop, the 50% ROI target, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `ema_fast` | 8 | 5, 8, 13 | Fast EMA period used for crossover entry and exit. |
| `ema_slow` | 21 | 21, 34, 55 | Slow EMA period used for crossover entry and exit. |
| `atr_stop_period` | 14 | fixed baseline | ATR period used for the stop distance. |
| `atr_stop_mult` | 3.0 | 2.0, 3.0, 4.0 | ATR multiplier used for the stop distance. |
| `strategy_roi_pct` | 50.0 | fixed baseline | Source immediate ROI target, expressed as percent above entry for long trades. |
| `strategy_max_spread_stop_pct` | 12.0 | fixed baseline | Maximum allowed spread as a percent of planned stop distance. |

Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 names this as part of the portable FX/metals EMA basket.
- `GBPUSD.DWX` - Card R3 names this as part of the portable FX/metals EMA basket.
- `USDJPY.DWX` - Card R3 names this as part of the portable FX/metals EMA basket.
- `XAUUSD.DWX` - Card R3 names this as part of the portable FX/metals EMA basket.

**Explicitly NOT for:**
- Symbols outside the card R3 basket - not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Not specified in frontmatter; expected to be hours to days until opposite EMA cross, ATR stop, ROI target, or Friday close. |
| Expected drawdown profile | High risk class from card initial risk profile. |
| Regime preference | Trend-following EMA crossover regime. |
| Win rate target (qualitative) | Not specified in card; medium is the neutral expectation for a crossover system. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/AverageStrategy.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11207_ft-avg-ema.md`

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
| v1 | 2026-06-08 | Initial build from card | 244b99c7-07f3-4797-9efb-b8a544bf5caa |
