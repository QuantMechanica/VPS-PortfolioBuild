# QM5_10560_mql5-delta-wpr - Strategy Spec

**EA ID:** QM5_10560
**Slug:** `mql5-delta-wpr`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes a Delta WPR color state from two Williams Percent Range values. The state is bullish when the slow WPR is above the signal level and the fast WPR is above the slow WPR; it is bearish when the slow WPR is below the signal level and the fast WPR is below the slow WPR. It opens long when the just-closed bar changes into the bullish blue state and opens short when the just-closed bar changes into the bearish orange state. It closes an open long on a new bearish orange transition and closes an open short on a new bullish blue transition, with ATR(14) 2.0 hard stop and 1.5R target on every entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H1-H6 | Timeframe used for Delta WPR color-state signals. |
| `strategy_wpr_fast_period` | `14` | 2-100 | Fast Williams Percent Range lookback. |
| `strategy_wpr_slow_period` | `30` | 2-200 | Slow Williams Percent Range lookback. |
| `strategy_signal_level` | `-50.0` | -100-0 | WPR level used by the source indicator to separate bullish and bearish regimes. |
| `strategy_atr_period` | `14` | 2-100 | ATR lookback for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | 0.1-10.0 | ATR multiple for stop distance. |
| `strategy_reward_r_multiple` | `1.5` | 0.1-10.0 | Take-profit distance as a multiple of initial risk. |
| `strategy_max_spread_points` | `0` | 0-10000 | Optional spread ceiling; zero disables the strategy spread filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - source test symbol and approved R3 FX target for WPR-derived OHLC logic.
- `EURUSD.DWX` - approved R3 liquid major FX target with portable WPR-derived OHLC logic.
- `GBPJPY.DWX` - approved R3 FX cross target with portable WPR-derived OHLC logic.
- `XAUUSD.DWX` - approved R3 metal target with portable WPR-derived OHLC logic.

**Explicitly NOT for:**
- `SPX500.DWX` - not a canonical DWX symbol in the matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | hours to days |
| Expected drawdown profile | ATR-stopped trend-color strategy with bounded one-position exposure. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/16512`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10560_mql5-delta-wpr.md`

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
| v1 | 2026-05-29 | Initial build from card | 7a168f72-c5d1-4aa0-96b6-30596c274872 |
