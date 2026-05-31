# QM5_10568_mql5-xdpo-hist - Strategy Spec

**EA ID:** QM5_10568
**Slug:** `mql5-xdpo-hist`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades closed-bar XDPO histogram direction changes on H12 by default. XDPO is implemented as the closed price minus a simple moving average shifted by `period / 2 + 1` bars. It goes long when the closed histogram has turned from falling to rising and is above zero, and goes short when it has turned from rising to falling and is below zero. Open positions close on the opposite XDPO turn, or through the framework hard stop, target, Friday close, news filter, or kill-switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H12` | H4-H12 sweep target | Timeframe used for XDPO and ATR readings |
| `strategy_dpo_period` | `14` | 2-100 | Simple moving average period used in the XDPO calculation |
| `strategy_atr_period` | `14` | 1-100 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | `2.0` | >0 | ATR multiple used for the hard stop |
| `strategy_rr_target` | `1.5` | >0 | Reward-to-risk multiple used for the target |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 primary FX symbol and source test family fit
- `GBPUSD.DWX` - card R3 portable major FX symbol
- `USDCAD.DWX` - card R3 portable major FX symbol
- `XAUUSD.DWX` - card R3 portable metals symbol

**Explicitly NOT for:**
- `SPX500.DWX` - not present in the DWX symbol matrix
- `SPY.DWX` - not present in the DWX symbol matrix

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H12` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `25` |
| Typical hold time | hours to days |
| Expected drawdown profile | ATR-defined directional oscillator losses with fixed 2.0 ATR stop |
| Regime preference | momentum direction-change |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/15294`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10568_mql5-xdpo-hist.md`

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
| v1 | 2026-05-29 | Initial build from card | 8a6940e0-c55e-4ede-9805-1076d23ec510 |
