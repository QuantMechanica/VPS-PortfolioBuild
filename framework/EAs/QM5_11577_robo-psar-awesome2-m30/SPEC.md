# QM5_11577_robo-psar-awesome2-m30 - Strategy Spec

**EA ID:** QM5_11577
**Slug:** `robo-psar-awesome2-m30`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a RoboForex M30 trend-continuation setup on FX pairs. A long entry is allowed when Parabolic SAR is below current price, Awesome Oscillator is above zero and rising, and current price is above EMA5; a short entry mirrors those conditions with SAR above price, AO below zero and falling, and current price below EMA5. Entries are evaluated once per new M30 bar using closed-bar indicator values, with a broker-time London/New York session filter and a 3-pip spread cap. Open positions use fixed pip SL/TP values from the card and close early when Parabolic SAR flips against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sar_step` | 0.01 | > 0 | Parabolic SAR acceleration step from the source default. |
| `strategy_sar_max` | 0.10 | > step | Parabolic SAR maximum acceleration from the source default. |
| `strategy_ema_period` | 5 | >= 1 | EMA trend-line period used for price-side confirmation. |
| `strategy_ao_fast_period` | 5 | >= 1 | Awesome Oscillator fast SMA period on median price. |
| `strategy_ao_slow_period` | 34 | > fast | Awesome Oscillator slow SMA period on median price. |
| `strategy_eurusd_sl_pips` | 20 | >= 1 | EURUSD fixed stop loss from the card. |
| `strategy_eurusd_tp_pips` | 60 | >= 1 | EURUSD fixed take profit from the card. |
| `strategy_usdchf_sl_pips` | 18 | >= 1 | USDCHF fixed stop loss from the card. |
| `strategy_usdchf_tp_pips` | 50 | >= 1 | USDCHF fixed take profit from the card. |
| `strategy_other_sl_pips` | 20 | >= 1 | P2 baseline fixed stop loss for other FX pairs. |
| `strategy_other_tp_pips` | 55 | >= 1 | P2 baseline fixed take profit for other FX pairs. |
| `strategy_spread_cap_pips` | 3 | >= 1 | Maximum positive modeled spread before entries are blocked. |
| `strategy_london_start_hour_broker` | 8 | 0-23 | Broker-time start hour for the London session gate. |
| `strategy_london_end_hour_broker` | 17 | 0-23 | Broker-time end hour for the London session gate. |
| `strategy_newyork_start_hour_broker` | 13 | 0-23 | Broker-time start hour for the New York session gate. |
| `strategy_newyork_end_hour_broker` | 23 | 0-23 | Broker-time end hour for the New York session gate. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source instrument and DWX forex target; uses card TP 60 / SL 20 pips.
- `USDCHF.DWX` - source instrument and DWX forex target; uses card TP 50 / SL 18 pips.
- `GBPUSD.DWX` - R3 portable DWX FX expansion named in the card; uses other-FX TP 55 / SL 20 pips.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the source rules and fixed pip targets are FX-specific.
- FX symbols outside `dwx_symbol_matrix.csv` - they are not available for the DWX tester.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified in card; expected intraday-to-multi-session from M30 fixed SL/TP and PSAR-flip exit. |
| Expected drawdown profile | Not specified in card; fixed SL/TP trend-continuation losses during ranging regimes. |
| Regime preference | Trend-continuation / momentum-confirmation FX regimes. |
| Win rate target (qualitative) | Not specified in card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** local PDF strategy collection
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`, pages 48-49
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11577_robo-psar-awesome2-m30.md`

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
| v1 | 2026-06-20 | Initial build from card | 0551fb81-47fd-441a-ac37-9f6b6e323ebe |
