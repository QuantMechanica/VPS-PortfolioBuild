# QM5_11298_cs-bb-close — Strategy Spec

**EA ID:** QM5_11298
**Slug:** `cs-bb-close`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see the approved Strategy Card)
**Author of this spec:** Codex
**Last revised:** 2026-08-08

---

## 1. Strategy Logic

On each completed H1 bar, the EA opens long when the close crosses from at or below the upper Bollinger Band to above it, and opens short when the close crosses from at or above the lower band to below it. The bands use 21 closes and two standard deviations. A long closes when the completed-bar close crosses below the middle band, while a short closes when it crosses above the middle band; every entry also carries a catastrophic stop 2.5 times ATR(14), and a reversal waits for the next completed bar after the position is flat.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 21 | fixed baseline | Number of H1 closes used by the source Bollinger Bands. |
| `strategy_bb_deviation` | 2.0 | fixed baseline | Standard-deviation multiplier for the upper and lower bands. |
| `strategy_atr_period` | 14 | fixed baseline | Closed-bar ATR period used only for the catastrophic stop. |
| `strategy_sl_atr_mult` | 2.5 | fixed baseline | Catastrophic stop distance as a multiple of ATR(14). |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major-FX close series suitable for the card's close-derived bands.
- `GBPUSD.DWX` — liquid major-FX close series suitable for the same mechanical signal.
- `USDJPY.DWX` — liquid major-FX close series that broadens the portable FX basket.
- `XAUUSD.DWX` — liquid gold series available in the DWX matrix for volatility breakouts.
- `GDAXI.DWX` — canonical DWX DAX proxy used in place of the card's unavailable `GER40.DWX` name.

**Explicitly NOT for:**

- `GER40.DWX` — this exact name is absent from `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered canonical equivalent.
- Symbols outside `dwx_symbol_matrix.csv` — the tester has no supported DWX tick-data contract for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 45 |
| Expected trade frequency | approximately weekly, derived from 45 trades/year |
| Typical hold time | not stated in the card; mechanically, until the H1 mid-band cross, catastrophic stop, or framework Friday close |
| Expected drawdown profile | false breakouts can cluster during range-bound conditions |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | not specified by the card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** public GitHub repository and Python source
**Pointer:** `https://github.com/CryptoSignal/Crypto-Signal/blob/master/app/analyzers/informants/bollinger_bands.py` with crossover semantics from `https://github.com/CryptoSignal/Crypto-Signal/blob/master/app/analyzers/crossover.py`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11298_cs-bb-close.md`.

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
| v1 | 2026-08-08 | Initial build from card | cb217c87-514c-4603-aff4-ef4cbf1b01b0 |
