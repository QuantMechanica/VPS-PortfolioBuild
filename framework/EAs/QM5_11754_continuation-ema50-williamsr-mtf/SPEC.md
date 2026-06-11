# QM5_11754_continuation-ema50-williamsr-mtf - Strategy Spec

**EA ID:** QM5_11754
**Slug:** `continuation-ema50-williamsr-mtf`
**Source:** `8fc38d7b-ef60-57f3-97f3-24eab132b1d9` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H4 pullbacks in the direction of the D1 trend. A long setup requires the D1 close to be above a rising EMA(50), the H4 signal bar to close below its EMA(50), and Williams %R(14) on H4 to cross back above -80 after being oversold. A short setup mirrors the rule: D1 close below a falling EMA(50), H4 close above its EMA(50), and Williams %R crossing back below -20. The stop is placed beyond the H4 signal bar high or low, the hard target is ATR(14) times the configured multiplier, and the stop trails from SMA(5) logic only after the trade has reached the configured reward-to-risk trigger.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 50 | 2-200 | EMA period used for the D1 trend filter and H4 pullback filter. |
| `strategy_wpr_period` | 14 | 2-100 | Williams %R period on H4. |
| `strategy_wpr_oversold` | -80.0 | -100 to 0 | Long trigger threshold; WPR must cross back above this level. |
| `strategy_wpr_overbought` | -20.0 | -100 to 0 | Short trigger threshold; WPR must cross back below this level. |
| `strategy_trail_sma_period` | 5 | 2-50 | SMA period used for post-2R trailing stop checks. |
| `strategy_trail_rr_trigger` | 2.0 | 0.5-10.0 | Reward-to-risk multiple that activates SMA trailing. |
| `strategy_atr_period` | 14 | 1-100 | ATR period on H4 for the hard take-profit distance. |
| `strategy_atr_tp_mult` | 5.0 | 4.0-7.0 | ATR multiple for the hard take-profit; default is the midpoint of the card's 4-7 ATR range. |
| `strategy_sl_buffer_points` | 10 | 0-200 | Point buffer beyond the H4 signal bar high or low for the initial stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with D1 and H4 DWX history.
- `GBPUSD.DWX` - card-listed major FX pair with D1 and H4 DWX history.
- `USDJPY.DWX` - card-listed major FX pair with D1 and H4 DWX history.
- `USDCHF.DWX` - card-listed major FX pair with D1 and H4 DWX history.
- `AUDUSD.DWX` - card-listed major FX pair with D1 and H4 DWX history.
- `USDCAD.DWX` - card-listed major FX pair with D1 and H4 DWX history.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the card specifies FX majors and does not authorize indices, metals, energy, or synthetic substitutes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` EMA(50) trend and close; `H4` EMA(50), Williams %R(14), SMA(5), ATR(14), signal-bar high/low/close |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Not explicitly stated; expected to be multi-H4-bar trend-continuation holds because trailing activates only after 2R. |
| Expected drawdown profile | Trend-following pullback profile with losses controlled by signal-bar structure stops and fixed-risk sizing. |
| Regime preference | Trend-following continuation; performs best when D1 trend persists after H4 pullbacks. |
| Win rate target (qualitative) | Medium; reward-to-risk and ATR target are designed to carry winners beyond the initial stop distance. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8fc38d7b-ef60-57f3-97f3-24eab132b1d9`
**Source type:** book / trading PDF
**Pointer:** Cecil Robles, "The Continuation Method", in `459341651-6-Simple-Strategies-for-Trading-Forex-pdf.pdf`, pages 35-54.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11754_continuation-ema50-williamsr-mtf.md`

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
| v1 | 2026-06-11 | Initial build from card | 5751e7a0-f1c0-43cd-bb8c-f00e07e30436 |
