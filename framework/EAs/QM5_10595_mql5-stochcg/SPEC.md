# QM5_10595_mql5-stochcg - Strategy Spec

**EA ID:** QM5_10595
**Slug:** `mql5-stochcg`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-30

---

## 1. Strategy Logic

The EA computes the Stochastic CG oscillator on completed H4 bars using the public MQL5 CodeBase formula. It enters long when the oscillator main line crosses above its trigger line on the just-closed bar, and enters short when the main line crosses below the trigger. It exits an open long on a bearish cross, exits an open short on a bullish cross, and also exits after 12 completed H4 bars. Each entry uses a catastrophic stop at 2.5 times ATR(14), with no take-profit target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 baseline | Timeframe used for oscillator, ATR, and hold-time bars. |
| `strategy_cg_length` | `10` | 2-100 | Stochastic CG lookback length from the source EA default. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.5` | 0.1-10.0 | ATR multiple used to place the stop loss. |
| `strategy_max_hold_bars` | `12` | 1-100 | Maximum completed H4 bars to hold a position. |
| `strategy_cross_epsilon` | `0.0` | 0.0-1.0 | Optional minimum separation between main and trigger after a cross. |
| `strategy_max_spread_points` | `0` | 0-disabled or positive points | Optional spread guard; disabled by default. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - primary source analog from the approved card.
- `EURUSD.DWX` - DWX FX major with broad H4 liquidity.
- `GBPUSD.DWX` - DWX FX major included by the card for baseline portability.
- `USDCHF.DWX` - DWX FX major included by the card for baseline portability.

**Explicitly NOT for:**
- Non-DWX symbols - build and P2 routing require symbols present in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Up to 12 H4 bars |
| Expected drawdown profile | Controlled by 2.5 x ATR(14) catastrophic stop |
| Regime preference | Cycle oscillator cross / ranging-to-cyclical FX markets |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/2312`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10595_mql5-stochcg.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-30 | Initial build from card | 0e88bf92-0999-4f85-9a1b-47839dedd377 |
