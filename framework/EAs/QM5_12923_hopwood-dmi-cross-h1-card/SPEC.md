# QM5_12923_hopwood-dmi-cross-h1-card — Strategy Spec

**EA ID:** QM5_12923
**Slug:** hopwood-dmi-cross-h1-card
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

Trades Wilder's Directional Movement Index (+DI, -DI) crossovers on the H1 timeframe filtered by ADX trend strength. Opens a LONG position when +DI crosses above -DI on closed H1 bar and ADX(14) > 22. Opens a SHORT position when -DI crosses above +DI on closed H1 bar and ADX(14) > 22. Exits on an opposite DMI crossover or when ADX falls below the exhaustion threshold (18). Protected by an initial ATR(14) * 2.0 stop loss and an optional 2.0R take-profit target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_dmi_period` | 14 | 7-30 | Lookback period for Wilder's +DI, -DI, and ADX calculations |
| `strategy_adx_threshold` | 22.0 | 15.0-35.0 | Minimum ADX required on closed bar for entry confirmation |
| `strategy_atr_period` | 14 | 5-30 | ATR period on H1 for initial stop loss calculation |
| `strategy_atr_sl_mult` | 2.0 | 1.0-4.0 | ATR multiplier for stop loss distance |
| `strategy_take_profit_rr` | 2.0 | 0.0-5.0 | Risk-reward multiple for fixed take-profit (0.0 to disable) |
| `strategy_adx_exit_threshold` | 18.0 | 0.0-25.0 | ADX floor below which open trend positions are closed |
| `strategy_require_h1` | true | true/false | Requires H1 chart timeframe for execution |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- `EURUSD.DWX` — Liquid major FX pair with reliable trending regimes.
- `GBPUSD.DWX` — Liquid major FX pair with high directional momentum.
- `USDJPY.DWX` — Liquid major FX pair responsive to DMI/ADX directional moves.
- `AUDUSD.DWX` — Commodity FX pair with clean H1 trends.
- `GDAXI.DWX` — European equity index with strong intraday directional runs.
- `NDX.DWX` — US tech equity index with established trend characteristics.
- `WS30.DWX` — US industrial equity index.
- `UK100.DWX` — UK equity index.

**Explicitly NOT for:**
- `XAUUSD.DWX` — Highly erratic precious metals whip without session trend confirmation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80-120 |
| Typical hold time | 8-36 hours |
| Expected drawdown profile | Moderate trend-following drawdown during ranging regimes |
| Regime preference | Trending / directional expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** ForexFactory Steve Hopwood thread/282290
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12923_hopwood-dmi-cross-h1-card.md`

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
| v1 | 2026-08-21 | Initial build from card | f9e1abeb-a14c-4f02-9869-b9d99fcbf303 |
