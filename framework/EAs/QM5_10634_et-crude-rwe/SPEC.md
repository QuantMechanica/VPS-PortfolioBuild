# QM5_10634_et-crude-rwe - Strategy Spec

**EA ID:** QM5_10634
**Slug:** `et-crude-rwe`
**Source:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades an M5 intraday momentum burst. A long setup exists when price moves at least 0.35% from the lowest low to a later high inside a 20-minute window; after waiting 10 minutes, the EA buys a rebreak above that event high if it occurs within 60 minutes. Short setups mirror the same rule from high to low. The stop is placed beyond the opposite side of the event window by 0.20 ATR(14), the target is 1.2R, and open trades exit if the last closed bar closes back inside the event window or after 12 M5 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_threshold_pct` | 0.35 | 0.18-0.50 | Minimum percent move required to define the event. |
| `strategy_event_window_minutes` | 20 | 15-30 | Rolling window used to measure the momentum event. |
| `strategy_wait_minutes` | 10 | 5-15 | Required wait after the event high or low is printed. |
| `strategy_rebreak_deadline_min` | 60 | 30-90 | Maximum time after the event for a valid rebreak. |
| `strategy_atr_period` | 14 | 7-30 | ATR period for stop buffer and spike filter. |
| `strategy_sl_atr_buffer` | 0.20 | 0.10-0.50 | ATR fraction added beyond the event range for SL. |
| `strategy_spike_atr_mult` | 3.00 | 1.50-5.00 | Rejects event windows larger than this ATR multiple. |
| `strategy_tp_rr` | 1.20 | 1.00-1.50 | Take-profit multiple of initial risk. |
| `strategy_max_hold_bars` | 12 | 6-24 | Time exit in M5 bars. |
| `strategy_session_start_hour` | 1 | 0-23 | Broker-hour session start for liquid-hours filter. |
| `strategy_session_end_hour` | 21 | 0-23 | Broker-hour session end for liquid-hours filter. |
| `strategy_friday_no_entry_hour` | 19 | 0-23 | Blocks new Friday entries in the final two hours before framework Friday close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - crude oil CFD; direct target for the original crude intraday momentum concept.
- `XAUUSD.DWX` - liquid metal CFD with comparable intraday momentum bursts.
- `GDAXI.DWX` - available DWX DAX custom symbol used for the card's unavailable `GER40.DWX`.
- `NDX.DWX` - liquid index CFD with frequent intraday velocity events.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`.
- `SPX500.DWX` - not a canonical DWX symbol.

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
| Trades / year / symbol | `60` |
| Typical hold time | Up to 12 M5 bars after entry, excluding wait time. |
| Expected drawdown profile | Short intraday losses bounded by event-window ATR-buffer stops. |
| Regime preference | Intraday momentum / volatility expansion. |
| Win rate target (qualitative) | Medium to high, per source claim but not assumed by the code. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/70-success-rate-crude-oil-intraday-strategy.303063/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10634_et-crude-rwe.md`

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
| v1 | 2026-06-13 | Initial build from card | d398706c-65ef-4fbc-a256-ed15969232c0 |
