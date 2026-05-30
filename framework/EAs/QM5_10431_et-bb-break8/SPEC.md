# QM5_10431_et-bb-break8 - Strategy Spec

**EA ID:** QM5_10431
**Slug:** `et-bb-break8`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA trades a completed-bar D1 long-only Bollinger breakout rule. It enters long on the next daily bar after the last completed close is above the Bollinger upper band using SMA(20) plus 2.0 standard deviations. It exits when eight completed daily bars have elapsed since entry or when the last completed close falls below the Bollinger midline. Each entry carries a catastrophic protective stop at 3.0 times ATR(20), with no profit target, trailing stop, break-even, or partial close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 15-30 | Bollinger SMA and standard deviation lookback. |
| `strategy_bb_deviation` | 2.0 | 1.5-2.5 | Standard-deviation multiplier for the Bollinger bands. |
| `strategy_hold_bars` | 8 | 5-13 | Number of completed D1 bars to hold before time-stop exit. |
| `strategy_atr_period` | 20 | 20 | ATR period used for the emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 2.5-3.0, or 0 in parameter tests | ATR multiple used for the emergency stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - canonical S&P 500 custom-symbol port for US large-cap breakout exposure; backtest-only per symbol discipline.
- `NDX.DWX` - live-tradable Nasdaq 100 index CFD for portable US large-cap breakout exposure.
- `WS30.DWX` - live-tradable Dow 30 index CFD for portable US large-cap breakout exposure.
- `GDAXI.DWX` - matrix-valid DAX CFD used for the card's `GER40.DWX` basket item.
- `XAUUSD.DWX` - matrix-valid gold CFD included by the approved card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in the DWX symbol matrix; this build registers `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; `SP500.DWX` is the canonical custom symbol.

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
| Typical hold time | about 8 completed daily bars unless midline exit or ATR stop fires earlier |
| Expected drawdown profile | daily breakout continuation can underperform in mean-reverting markets |
| Regime preference | breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/bollinger-bands-breakout.22475/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10431_et-bb-break8.md`

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
| v1 | 2026-05-27 | Initial build from card | e472aaf9-78e9-41f1-938d-85557dbb6909 |
