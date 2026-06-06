# QM5_10941_grimes-keltner-pb - Strategy Spec

**EA ID:** QM5_10941
**Slug:** `grimes-keltner-pb`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades a D1 Keltner trend pullback. It waits for price to close beyond the EMA(20) plus or minus 2.25 ATR(20), confirms the EMA(20) slope over five bars, and then enters on the next open after the first pullback bar touches the prior completed bar's EMA(20). Long trades require no close below EMA(20) after the upper-band thrust; short trades mirror the rule after a lower-band thrust. Exits are handled by the initial stop/target bracket, a D1 close against EMA(20), the 12 D1 bar time stop, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 20 | `> 0` | EMA period for Keltner midline and pullback state. |
| `strategy_atr_period` | 20 | `> 0` | ATR period for Keltner width and stop distance. |
| `strategy_atr_filter_period` | 100 | `> strategy_atr_period` | Slow ATR period for dead-market filter. |
| `strategy_keltner_atr_mult` | 2.25 | `> 0` | ATR multiplier for upper and lower Keltner bands. |
| `strategy_setup_max_bars` | 10 | `>= 1` | Maximum D1 bars from band thrust to pullback touch. |
| `strategy_ema_slope_bars` | 5 | `>= 1` | EMA slope lookback in D1 bars. |
| `strategy_atr_filter_mult` | 0.70 | `> 0` | Requires ATR(20) >= this value times ATR(100). |
| `strategy_stop_atr_mult` | 2.0 | `> 0` | ATR fallback distance used in the initial stop. |
| `strategy_max_stop_atr_mult` | 3.0 | `> strategy_stop_atr_mult` | Rejects setups whose stop distance exceeds this ATR multiple. |
| `strategy_rr_target` | 2.0 | `> 0` | R-multiple target cap; target is this or Keltner retest, whichever is closer. |
| `strategy_time_exit_bars` | 12 | `> 0` | Maximum holding period in D1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with D1 OHLC, EMA, and ATR data.
- `GBPUSD.DWX` - major FX pair with D1 OHLC, EMA, and ATR data.
- `USDJPY.DWX` - major FX pair with D1 OHLC, EMA, and ATR data.
- `XAUUSD.DWX` - liquid metals CFD with D1 trend and volatility behaviour.
- `XTIUSD.DWX` - liquid oil CFD with D1 trend and volatility behaviour.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 build and backtest registry requires canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `18` |
| Typical hold time | Up to `12` D1 bars by card time exit. |
| Expected drawdown profile | Trend-continuation pullback strategy with losses limited by ATR and structure stop. |
| Regime preference | Trend continuation after Keltner-band thrust and orderly EMA pullback. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog/library page
**Pointer:** Adam H. Grimes, "Keltner Statistics", https://adamhgrimes.com/library/indicators/keltner-statistics/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10941_grimes-keltner-pb.md`

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
| v1 | 2026-06-06 | Initial build from card | cac8e88f-011c-4057-9727-698996692912 |
