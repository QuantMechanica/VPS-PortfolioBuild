# QM5_11094_bbs-adv-zero - Strategy Spec

**EA ID:** QM5_11094
**Slug:** `bbs-adv-zero`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. It computes the EarnForex Bollinger Squeeze Advanced trending state as `BB_Deviation * StdDev(close, 20) / (ATR(20) * KeltnerFactor)` and allows signals only when that ratio is at least 1. It computes the trigger histogram as `DeMarker(13) - 0.5`; long entries occur when the histogram crosses from non-positive to positive, and short entries occur when it crosses from non-negative to negative. Open positions close on the opposite zero cross, when the trending state ends, or after 24 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 primary; H4 P3 candidate | Timeframe used for completed-bar signal reads. |
| `strategy_bb_period` | 20 | 5-100 | Standard deviation lookback for the Bollinger side of the squeeze ratio. |
| `strategy_bb_deviation` | 2.0 | 0.5-4.0 | Bollinger deviation multiplier in the squeeze ratio. |
| `strategy_keltner_period` | 20 | 5-100 | ATR lookback for the Keltner side of the squeeze ratio. |
| `strategy_keltner_factor` | 1.5 | 0.5-4.0 | Keltner ATR multiplier in the squeeze ratio denominator. |
| `strategy_demarker_period` | 13 | 5-50 | DeMarker lookback for the zero-cross histogram. |
| `strategy_atr_period` | 14 | 5-100 | ATR lookback for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-6.0 | ATR multiple used for the catastrophic stop. |
| `strategy_max_hold_bars` | 24 | 1-240 | Maximum holding time in signal timeframe bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid major FX pair suitable for OHLC-derived volatility and oscillator logic.
- `GBPUSD.DWX` - card-listed liquid major FX pair suitable for the same completed-bar squeeze logic.
- `USDJPY.DWX` - card-listed liquid major FX pair suitable for the same completed-bar squeeze logic.
- `XAUUSD.DWX` - card-listed liquid metal CFD with enough volatility for squeeze/trend-state testing.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use broker-verified `.DWX` symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | Intraday to 24 H1 bars maximum |
| Expected drawdown profile | Moderate oscillator whipsaw risk during failed volatility expansion |
| Regime preference | Volatility-expansion / trending |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** GitHub / MQL5 indicator source
**Pointer:** `https://github.com/EarnForex/Bollinger-Squeeze-Advanced`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11094_bbs-adv-zero.md`

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
| v1 | 2026-06-07 | Initial build from card | 57117b96-1345-441a-9d48-7e3320fee8e3 |
