# QM5_10672_tv-orb-ny-trail - Strategy Spec

**EA ID:** QM5_10672
**Slug:** `tv-orb-ny-trail`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA records the high and low of the first configured minutes after the New York cash open, defaulting to 15 minutes from 15:30 broker/Madrid time. Once the opening range is complete, it enters long when a closed bar finishes above the range high, or short when a closed bar finishes below the range low, provided there is no open position and today's consecutive-loss limit has not been reached. The initial stop is 0.5% of the entry price, the take profit is 2R by default, and ATR(14) with a 2.0 multiplier trails open positions while only tightening the stop. A configurable session close can flatten remaining positions late in the day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_opening_range_minutes` | 15 | 5-30 P3 sweep | Minutes after the open used to define the opening range. |
| `strategy_open_hour` | 15 | 0-23 | Opening-range start hour in broker/Madrid time. |
| `strategy_open_minute` | 30 | 0-59 | Opening-range start minute in broker/Madrid time. |
| `strategy_max_entry_hour` | 20 | 0-23 | Last hour at which new entries are allowed. |
| `strategy_max_entry_minute` | 0 | 0-59 | Last minute at which new entries are allowed. |
| `strategy_force_close_enabled` | true | true/false | Enables the card's optional forced session close. |
| `strategy_force_close_hour` | 21 | 0-23 | Forced close hour in broker/Madrid time. |
| `strategy_force_close_minute` | 55 | 0-59 | Forced close minute in broker/Madrid time. |
| `strategy_stop_pct` | 0.5 | >0 | Initial stop distance as percent of entry price. |
| `strategy_rr_target` | 2.0 | 2.0-3.0 P3 sweep | Fixed take-profit in R multiples. |
| `strategy_atr_period` | 14 | >=1 | ATR period used by the trailing stop. |
| `strategy_atr_trail_mult` | 2.0 | >0 | ATR multiplier used by the trailing stop. |
| `strategy_max_consec_losses_day` | 2 | >=1 | Daily consecutive losing trades after which entries pause. |
| `strategy_max_spread_points` | 100 | >=0 | Spread ceiling for the framework no-trade filter; 0 disables it. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq index target named in the card's primary P2 basket.
- `GDAXI.DWX` - available DWX DAX custom symbol used for the card's GER40 exposure.
- `WS30.DWX` - Dow index target named in the card's primary P2 basket.
- `XAUUSD.DWX` - gold/metals target named in the card's primary P2 basket.
- `XTIUSD.DWX` - crude oil/energy target named in the card's primary P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SP500.DWX` - discussed by the card only as a possible later SP500-only validation concern, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, flat by configured session close if still open |
| Expected drawdown profile | Fixed 0.5% price stop with $1,000 fixed backtest risk and trailing winners |
| Regime preference | Session opening-range breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Opening Range NY - OR, SL, TP editable`, author `Manu_arg`, published 2026-02-09
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10672_tv-orb-ny-trail.md`

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
| v1 | 2026-05-31 | Initial build from card | 8b69fb80-42a7-4f1f-9535-d6afffaaeb04 |
