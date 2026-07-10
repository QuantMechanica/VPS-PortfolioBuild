# QM5_13118_energy-skew-rank - Strategy Spec

**EA ID:** QM5_13118  
**Slug:** `energy-skew-rank`  
**Strategy ID:** `FERNANDEZ-SKEW-2018_XTI_XNG_S01`  
**Source:** `FERNANDEZ-SKEW-2018`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

This EA implements a low-frequency structural commodity-skewness premium as a
paired energy basket on `XTIUSD.DWX` and `XNGUSD.DWX`. On the first D1 bar of
each broker month it uses completed D1 log returns from the prior 12 complete
broker months to calculate each leg's Pearson moment coefficient of skewness.
It buys the lower-skew energy leg and shorts the higher-skew leg, allocating
half of the fixed risk budget to each, then closes and reranks at the next month.

The strategy is not a duplicate of `QM5_12567_cum-rsi2-commodity`: it contains
no RSI, pullback, long-only state, or five-day exit. It is also distinct from
existing XTI/XNG momentum, return-spread reversion, volatility-breakout, carry,
momentum-IVol, and same-calendar-month baskets because the signal is the third
standardized moment of each leg's completed daily return distribution.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | locked | completed broker months in the source formation window |
| `strategy_history_bars` | 500 | 400-650 | bounded D1 history buffer |
| `strategy_min_return_observations` | 180 | 180-200 | minimum valid daily returns per leg |
| `strategy_atr_period_d1` | 20 | 14-30 | per-leg hard-stop ATR period |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen per-leg stop multiplier |
| `strategy_max_hold_days` | 35 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | market-order deviation |

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - host chart, crude-oil leg, and magic slot 0.
- `XNGUSD.DWX` - natural-gas leg and magic slot 1.
- `QM5_13118_ENERGY_SKEW_RANK_D1` - logical basket symbol for Q02 dispatch.

**Explicitly NOT for:**

- Standalone XTI or XNG evaluation - the edge is the monthly relative rank.
- XAU/XAG - their ratio-reversion and breakout baskets already exist.
- Other commodities, FX, or indices - adding instruments changes the approved
  two-leg carrier and requires a new card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal cadence | first tradable D1 bar of each broker month |
| Formation window | prior 12 complete broker months of completed D1 returns |
| Multi-timeframe refs | `MN1` calendar key only; no MN1 price indicator |
| Bar gating | `QM_IsNewBar()` plus monthly transition detection |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12 completed packages after warm-up |
| Typical hold time | one broker month |
| Expected drawdown profile | high; XNG gaps, legging, and narrow-universe rank reversals |
| Regime preference | persistent cross-sectional commodity-skewness premium |
| Win rate target | no source-derived single-carrier target |

---

## 6. Source Citation

Fernandez-Perez, Adrian; Frijns, Bart; Fuertes, Ana-Maria; and Miffre,
Joelle (2018), "The Skewness of Commodity Futures Returns", *Journal of
Banking & Finance* 86, 143-158, DOI
https://doi.org/10.1016/j.jbankfin.2017.06.015.

The full accepted manuscript is held by Auckland University of Technology:
https://openrepository.aut.ac.nz/server/api/core/bitstreams/05e08e2e-f763-4f46-ac67-4c13ac10a451/content.

The source uses 27 exchange-traded commodity futures and extreme quintiles.
This EA is a two-leg continuous-CFD carrier whose economics must be established
by Q02 and later gates; no source performance number is imported.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest Q02+ | `RISK_FIXED` | 1000 per package, split equally by leg |
| Live | not authorized | no live setfile or manifest created |

Each leg has a frozen `ATR(20) * 3.5` broker-side hard stop. The manager closes
orphans, unexpected sides, month-old packages, and positions exceeding 35 days.
Friday close is disabled only for the source-aligned monthly holding period.
Framework kill-switch and news-entry guards remain authoritative.

Equal risk and opposite direction reduce common energy exposure but do not
guarantee dollar or beta neutrality. The loss of the source's broad
cross-section and futures-to-CFD roll/basis translation are explicit Q02 kill
risks, not waiver grounds.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial build from approved card | pending commit |

