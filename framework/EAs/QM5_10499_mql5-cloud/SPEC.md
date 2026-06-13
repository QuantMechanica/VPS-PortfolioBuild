# QM5_10499_mql5-cloud - Strategy Spec

**EA ID:** QM5_10499
**Slug:** mql5-cloud
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates a reversal signal on each closed M15 bar using the source Stochastic and Fractals rules. A long signal occurs when Stochastic D is at or below 20 and K crosses above D from bar 2 to bar 1, or when a confirmed lower fractal is present. A short signal mirrors this with Stochastic D at or above 80 and K crossing below D, or a confirmed upper fractal. Entries use an ATR(14) hard stop at 1.2x ATR, a 1.5R fixed target, close on an opposite closed-bar signal, and enforce one open position plus one opened trade per broker day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_use_stochastic` | `true` | `true/false` | Enable the Stochastic threshold-cross entry leg. |
| `strategy_use_fractals` | `true` | `true/false` | Enable the confirmed Fractals entry leg. |
| `strategy_stoch_k_period` | `5` | `1+` | Stochastic K period from the source baseline. |
| `strategy_stoch_d_period` | `3` | `1+` | Stochastic D period from the source baseline. |
| `strategy_stoch_slowing` | `3` | `1+` | Stochastic slowing from the source baseline. |
| `strategy_stoch_oversold` | `20.0` | `0-100` | Stochastic D threshold for long reversals. |
| `strategy_stoch_overbought` | `80.0` | `0-100` | Stochastic D threshold for short reversals. |
| `strategy_fractal_shift` | `2` | `2+` | Confirmed fractal bar shift. |
| `strategy_one_day_one_deal` | `true` | `true/false` | Enforce the source one-day-one-deal risk control. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the P2 stop. |
| `strategy_atr_sl_mult` | `1.2` | `>0` | ATR multiplier for the hard stop. |
| `strategy_tp_rr` | `1.5` | `>0` | Fixed reward-to-risk target. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX FX major with Stochastic and Fractals portability.
- `GBPUSD.DWX` - card-listed DWX FX major with the same M15 indicator support.
- `USDJPY.DWX` - card-listed DWX FX major with the same M15 indicator support.
- `XAUUSD.DWX` - card-listed DWX metal symbol with the same M15 indicator support.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest path requires DWX symbols from `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | `Intraday to multi-day, bounded by fixed SL/TP, opposite signal, and Friday close` |
| Expected drawdown profile | `Mean-reversion losses can cluster in persistent trends; ATR stop normalizes symbol volatility.` |
| Regime preference | `mean-revert / reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/21348
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10499_mql5-cloud.md`

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
| v1 | 2026-06-13 | Initial build from card | 5b2e5a69-9c7c-4d19-9eff-02a0b145480d |
