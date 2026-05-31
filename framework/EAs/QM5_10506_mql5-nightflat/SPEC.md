# QM5_10506_mql5-nightflat - Strategy Spec

**EA ID:** QM5_10506
**Slug:** mql5-nightflat
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates once per configured broker-time night hour on H1. It measures the highest high minus lowest low over the last three completed H1 bars and trades only when that range is between the configured minimum and maximum. If the last completed H1 close is above the midpoint of that three-bar range it opens long; if it is below the midpoint it opens short. Each trade uses an ATR(14) hard stop, a 1.0R take profit, and a time exit at the next liquid-session broker hour if neither SL nor TP has closed it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_open_hour_broker` | 22 | 0-23 | Broker-time hour when the three-bar night-flat entry check is evaluated. |
| `strategy_exit_hour_broker` | 7 | 0-23 | Broker-time hour for the next-session time exit. |
| `strategy_range_bars` | 3 | fixed 3 | Number of completed H1 bars used for the source range gate. |
| `strategy_min_range_points` | 20 | >=0 | Minimum allowed three-bar range in symbol points. |
| `strategy_max_range_points` | 250 | > min | Maximum allowed three-bar range in symbol points. |
| `strategy_atr_period` | 14 | >0 | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 1.0 | >0 | ATR multiplier for stop distance. |
| `strategy_take_profit_r` | 1.0 | >0 | Take-profit distance as a multiple of initial risk. |
| `strategy_min_stop_points` | 20 | >0 | Minimum stop distance in points. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread block; 0 disables the spread block. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Source example symbol and directly compatible H1 FX major.
- `GBPUSD.DWX` - Liquid DWX FX major suitable for night-session range logic.
- `USDJPY.DWX` - Liquid DWX FX major suitable for quiet-session range logic.
- `XAUUSD.DWX` - DWX metal included by the approved card's portable P2 basket.

**Explicitly NOT for:**
- Equity index symbols - not listed in the approved card's R3 basket.
- Energy CFDs - not listed in the approved card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Overnight to next liquid-session open, usually under one trading day |
| Expected drawdown profile | Bounded single-position night-session losses through ATR hard stops |
| Regime preference | Quiet-session range compression with directional midpoint bias |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** Leonid Basis idea, Vladimir Karputov code, "Night Flat Trade", https://www.mql5.com/en/code/20815
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10506_mql5-nightflat.md`

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
| v1 | 2026-05-28 | Initial build from card | bea2ad0e-4a0c-455e-af07-1be6edf40a93 |
