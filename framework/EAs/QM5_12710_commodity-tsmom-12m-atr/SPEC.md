# QM5_12710_commodity-tsmom-12m-atr - Strategy Spec

**EA ID:** QM5_12710
**Slug:** `commodity-tsmom-12m-atr`
**Source:** `MOP-TSMOM-2012` (see `strategy-seeds/sources/MOP-TSMOM-2012/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

This EA implements a low-frequency structural WTI time-series-momentum sleeve on
`XTIUSD.DWX`. On the first new D1 bar of each broker-calendar month, it computes
the prior 12-month log return from completed D1 closes. A positive return above
the neutral band opens a monthly long package; a negative return below the band
opens a monthly short package.

Unlike `QM5_12603_wti-tsmom12m`, this build also requires current ATR as a
percent of price to sit inside a fixed volatility corridor before entry. The ATR
gate is intended to avoid dormant tape and extreme shock tape while preserving
the structural trend premise from Moskowitz, Ooi, and Pedersen. Open packages
are flattened on the next monthly rebalance or by the max-hold stale-position
guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 210-294 | Completed D1 bars used for the 12-month return-sign signal |
| `strategy_min_abs_return_pct` | 1.0 | 0.5-3.5 | Neutral band around zero trailing return |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop and ATR% gate |
| `strategy_atr_sl_mult` | 3.5 | 2.5-4.5 | ATR hard-stop distance multiplier |
| `strategy_min_atr_pct` | 0.75 | 0.5-1.0 | Minimum ATR as percent of price for participation |
| `strategy_max_atr_pct` | 7.5 | 5.0-10.0 | Maximum ATR as percent of price for participation |
| `strategy_max_hold_days` | 31 | 21-45 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI host chart and only traded symbol, magic slot 0.

**Explicitly NOT for:**
- `XNGUSD.DWX` - separate natural-gas event/seasonal sleeves.
- `XAUUSD.DWX` / `XAGUSD.DWX` - metals and metals-ratio sleeves.
- Basket symbols - this is a single-symbol WTI energy sleeve.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `5-9` |
| Typical hold time | One monthly package, capped at 31 calendar days |
| Expected drawdown profile | Medium-high; WTI trends can reverse abruptly in supply shocks |
| Regime preference | Persistent WTI directional trend with non-extreme realized volatility |
| Win rate target (qualitative) | low-medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-TSMOM-2012`
**Source type:** `peer-reviewed paper / AQR research page`
**Pointer:** `https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum`
**R1-R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_12710_commodity-tsmom-12m-atr_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Not configured by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated only by Q11/Q12 portfolio process |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
This build does not touch `T_Live`, AutoTrading, deploy manifests, or the
portfolio gate.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial build from card | pending Q02 |
