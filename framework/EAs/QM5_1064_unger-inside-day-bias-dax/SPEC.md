# QM5_1064_unger-inside-day-bias-dax - Strategy Spec

**EA ID:** QM5_1064
**Slug:** `unger-inside-day-bias-dax`
**Source:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9` (see `strategy-seeds/sources/eb97a148-0af9-5b9c-878c-25fb5dfa34f9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA checks each completed D1 bar for an inside-day pattern: the last closed bar's high is below the prior bar's high and its low is above the prior bar's low. If the last closed close is above SMA(200), it places one buy-stop one point above the inside-day high; if the close is below SMA(200), it places one sell-stop one point below the inside-day low. The stop loss is the tighter of the opposite inside-day boundary and a 2 x ATR(20) cap, and there is no baseline profit target. A filled position is closed after 3 completed D1 bars if SL or framework exits have not already closed it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_D1` | D1 only | Base timeframe for inside-day, SMA, ATR, pending expiry, and time stop. |
| `strategy_sma_period` | 200 | >= 2 | Trend-bias SMA period. |
| `strategy_atr_period` | 20 | >= 2 | ATR period for narrow-range skip and 2 x ATR stop cap. |
| `strategy_atr_stop_mult` | 2.0 | > 0 | ATR multiple used for the secondary stop cap. |
| `strategy_min_range_atr` | 0.3 | > 0 | Skip inside days narrower than this multiple of ATR(20). |
| `strategy_hold_days` | 3 | >= 1 | D1 bars to hold after entry before time-stop exit. |
| `strategy_entry_offset_pts` | 1 | >= 0 | Entry and structure-stop offset in MT5 points. |
| `strategy_spread_days` | 20 | >= 1 | Lookback length for median D1 spread gate. |
| `strategy_use_spread_gate` | true | true/false | Enables skip when current spread is more than 2 x median D1 spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DWX matrix DAX proxy for the card's GER40/FDAX origin.
- `NDX.DWX` - Secondary liquid index CFD named by the card.
- `WS30.DWX` - Secondary liquid index CFD named by the card.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- Non-index forex, metals, and energy symbols - The card is an index-CFD daily inside-day breakout sleeve.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate; setfiles use D1. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | 1-3 days |
| Expected drawdown profile | Breakout whipsaws during range-bound index sessions; stop distance bounded by inside-day range and 2 x ATR(20). |
| Regime preference | Breakout with trend bias |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9`
**Source type:** book / video
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1064_unger-inside-day-bias-dax.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1064_unger-inside-day-bias-dax.md`

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
| v1 | 2026-06-14 | Initial build from card | 130c5fdf-2f53-40f5-bcb7-7fa496c1d6d9 |
