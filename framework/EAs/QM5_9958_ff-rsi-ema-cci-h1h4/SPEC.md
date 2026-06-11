<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9958_ff-rsi-ema-cci-h1h4 — Strategy Spec

**EA ID:** QM5_9958
**Slug:** `ff-rsi-ema-cci-h1h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades EMA(5/12) crossovers on the H1 timeframe with dual-oscillator midline confirmation. A long entry fires when EMA(5) crosses above EMA(12) on the just-closed bar AND RSI(21) is above 50 AND CCI(80) is above 50 AND the close is above both EMAs. A short entry mirrors these conditions. An additional filter rejects entries where the EMA(5)–EMA(12) separation is less than 5% of ATR(14). The stop-loss defaults to 45 pips, falling back to 1.2×ATR(14) if the pip distance falls outside the [0.8, 1.8]×ATR band. Take-profit is set at 1.5× the stop distance. Positions are closed on the reverse EMA cross, when both oscillators cross back through 50 in the opposing direction, or after 20 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | 2–50 | Fast EMA period |
| `strategy_ema_slow_period` | 12 | 5–200 | Slow EMA period |
| `strategy_rsi_period` | 21 | 5–50 | RSI period |
| `strategy_cci_period` | 80 | 14–200 | CCI period |
| `strategy_rsi_threshold` | 50.0 | 40–60 | RSI midline filter level |
| `strategy_cci_threshold` | 50.0 | 20–80 | CCI midline filter level |
| `strategy_atr_period` | 14 | 5–30 | ATR period for SL calibration |
| `strategy_stop_pips` | 45 | 20–120 | Baseline stop loss in pips |
| `strategy_stop_atr_min_mult` | 0.8 | 0.3–1.2 | Lower ATR bound for pip-stop validity |
| `strategy_stop_atr_max_mult` | 1.8 | 1.0–3.0 | Upper ATR bound for pip-stop validity |
| `strategy_stop_atr_fallback` | 1.2 | 0.5–3.0 | ATR multiplier when pip stop is out of bounds |
| `strategy_tp_ratio` | 1.5 | 0.5–5.0 | Take-profit as multiple of SL distance |
| `strategy_max_bars_hold` | 20 | 5–100 | Maximum hold time in H1 bars |
| `strategy_min_sep_atr_mult` | 0.05 | 0.01–0.20 | Minimum EMA separation as fraction of ATR |
| `strategy_spread_filter_pct` | 0.12 | 0.05–0.30 | Maximum spread as fraction of SL distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Major FX pair with tight spreads and H1 trend structure; slot 0
- `GBPUSD.DWX` — Major FX pair with sufficient volatility for EMA crossover signals; slot 1
- `USDJPY.DWX` — Major FX pair; DWX-available with good H1 data history; slot 2
- `AUDUSD.DWX` — Major FX pair; commodity-correlated trends suit momentum filters; slot 3

**Explicitly NOT for:**
- Index CFDs — The strategy uses pip-based stop sizing calibrated for FX majors; indices require different stop calibration

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` (H4 is a P3 alternate, not used in baseline) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~55 |
| Typical hold time | 2–20 H1 bars (2h–20h) |
| Expected drawdown profile | Moderate; constrained by 45-pip SL and 1.5R TP |
| Regime preference | Trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** ahmedabbas, "Simple RSI & EMA high Profitable ratio Strategy", ForexFactory, 2016, https://www.forexfactory.com/thread/599061-simple-rsi-ema-high-profitable-ratio-strategy
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9958_ff-rsi-ema-cci-h1h4.md`

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
| v1 | 2026-06-11 | Initial build from card | f82c731a-f99f-4ea1-a294-e4e90888ca09 |
