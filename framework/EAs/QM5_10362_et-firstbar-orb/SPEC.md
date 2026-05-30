# QM5_10362_et-firstbar-orb - Strategy Spec

**EA ID:** QM5_10362
**Slug:** `et-firstbar-orb`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

At the start of each broker trading day, the EA records the high and low of the first `strategy_bars_to_set_range` closed M5 bars. Once that opening range is complete, it takes at most one trade for the day when a closed bar crosses above the range high plus one tick or below the range low minus one tick. Long trades use the opposite range low minus a buffer as the protective stop, short trades use the opposite range high plus a buffer, and open trades are closed after `strategy_time_exit_bars` bars if the stop has not closed them first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bars_to_set_range` | 5 | 1-10 | Number of first-session bars used to define the opening range. |
| `strategy_limit_offset_ticks` | 0 | 0-10 | Tick offset retained from the card's stop-limit formulation; P2 baseline uses deterministic market fill after the closed-bar trigger. |
| `strategy_time_exit_bars` | 5 | 3-12 | Maximum bars to hold a trade before strategy exit. |
| `strategy_stop_buffer_ticks` | 1 | 0-10 | Extra ticks beyond the opposite side of the opening range for the stop. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used to reject oversized opening ranges. |
| `strategy_max_range_atr_mult` | 1.2 | 0.5-3.0 | Maximum opening range width as a multiple of ATR. |
| `strategy_optional_target_rr` | 0.0 | 0.0-3.0 | Optional profit target in R; zero disables the optional P3 target. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol listed in the card and available for backtest.
- `NDX.DWX` - Nasdaq 100 index CFD from the card's portable basket.
- `WS30.DWX` - Dow 30 index CFD from the card's portable basket.
- `GDAXI.DWX` - DAX equivalent available in the DWX matrix; used in place of unavailable `GER40.DWX`.
- `XAUUSD.DWX` - Gold CFD listed in the card's portable basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | `5 M5 bars, about 25 minutes` |
| Expected drawdown profile | `Opening-session noise with fixed protective stop at the opposite side of the range.` |
| Regime preference | `breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/stop-limit-order-in-easylanguage-tradestation.305303/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10362_et-firstbar-orb.md`

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
| v1 | 2026-05-25 | Initial build from card | 49f989ad-bab9-434a-a951-90702594b983 |
