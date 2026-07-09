# QM5_13078_xti-holiday-gas-fade - Strategy Spec

**EA ID:** QM5_13078
**Slug:** `xti-holiday-gas-fade`
**Source:** `EIA-GAS-HOLIDAY-PULLFORWARD-2018`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

The EA trades `XTIUSD.DWX` on D1 around U.S. driving-holiday demand windows.
It computes Memorial Day, observed Independence Day, and Labor Day from the
broker calendar, then evaluates only on the first scheduled trading day after
one of those holidays. The entry is short-only and requires the pre-holiday
close to be above its SMA, at least an ATR-scaled distance above the close from
the rally lookback window, and not already meaningfully below the holiday close
at entry. The EA uses an ATR hard stop, ATR profit target, max-hold close,
mean-reclaim close, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rally_lookback_days` | 5 | 3-8 | Completed D1 bars used to confirm a pre-holiday rally. |
| `strategy_trend_period` | 20 | 15-30 | SMA period for the pre-holiday trend filter and mean-reclaim exit. |
| `strategy_atr_period` | 20 | 14-30 | ATR period for rally, stop, target, and mean-reclaim distances. |
| `strategy_min_rally_atr` | 0.70 | 0.45-1.00 | Minimum pre-holiday rally in ATR units. |
| `strategy_max_post_drop_atr` | 1.25 | 0.75-1.75 | Skip if price has already dropped this far from the holiday close. |
| `strategy_mean_reclaim_atr` | 0.20 | 0.00-0.50 | Close short after D1 close reaches SMA minus this ATR buffer. |
| `strategy_atr_sl_mult` | 2.60 | 2.00-3.40 | ATR multiple above short entry for hard stop. |
| `strategy_atr_tp_mult` | 2.20 | 1.60-3.00 | ATR multiple below short entry for profit target. |
| `strategy_max_hold_days` | 7 | 4-10 | Maximum calendar days to hold a position. |
| `strategy_max_spread_points` | 1000 | 700-1500 | Skip entries above this modeled spread. |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI crude CFD proxy for the gasoline-linked driving-demand
  pull-forward source lineage.

**Explicitly NOT for:**
- `XNGUSD.DWX` - natural gas has storage/weather drivers and already has
  separate XNG sleeves.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metals do not express the EIA gasoline
  product-supplied holiday mechanism.
- Index CFDs and FX pairs - these do not represent U.S. petroleum-demand
  holiday pull-forward exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 3 before rally and spread filters |
| Typical hold time | 1-7 calendar days |
| Expected drawdown profile | Medium, with sparse crude-holiday gap risk bounded by ATR stop and Friday close. |
| Regime preference | Post-event mean reversion after pre-holiday rally into U.S. driving demand. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-GAS-HOLIDAY-PULLFORWARD-2018`<br>
**Source type:** official EIA Today in Energy article<br>
**Pointer:** `https://www.eia.gov/todayinenergy/detail.php?id=36992`<br>
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13078_xti-holiday-gas-fade.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). The committed Q02 setfile uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from card | Mission-directed XTI post-driving-holiday gasoline pull-forward fade |
