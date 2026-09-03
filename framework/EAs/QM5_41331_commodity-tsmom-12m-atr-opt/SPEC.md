# QM5_41331_commodity-tsmom-12m-atr-opt - Strategy Spec

**EA ID:** QM5_41331
**Slug:** `commodity-tsmom-12m-atr-opt`
**Parent EA:** `QM5_12710_commodity-tsmom-12m-atr`
**Target symbols:** `XTIUSD.DWX`
**Source:** `MOP-TSMOM-2012` (Moskowitz, Ooi & Pedersen time-series-momentum; see `strategy-seeds/sources/MOP-TSMOM-2012/`)
**Author of this spec:** Claude
**Last revised:** 2026-09-03

---

## 1. Strategy Logic

This derivative is a DL-089 measurement sibling of the recompiled parent
`QM5_12710`. It preserves the approved parent mechanics byte-for-byte and adds
only the six optional DL-089 closed-D1 pattern veto inputs. With all six inputs
at zero, the veto corset is neutral and the sibling reproduces the parent.

Parent logic (unchanged): a low-frequency structural WTI time-series-momentum
sleeve on `XTIUSD.DWX`, D1. On the first new D1 bar of each broker-calendar
month, it computes the prior 12-month log return from completed D1 closes. A
positive return above the neutral band opens a monthly long package; a negative
return below the band opens a monthly short package. Entry additionally requires
current ATR as a percent of price to sit inside a fixed volatility corridor. Open
packages are flattened on the next monthly rebalance or by the max-hold
stale-position guard. Stop is an ATR hard stop (`strategy_atr_sl_mult` x ATR).

DL-089 delta: before each entry request is sent to `QM_TM_OpenPosition`, the
request passes through `Pattern_AllowsRequest`, which consults a
closed-D1 (`shift 1`) pattern-permission profile assembled from the six
`opt_pp_*` inputs. A zero input disables its slot. With no active slot the
permission is a neutral `census_control` allow; with active slots the census
records fired/suppressed legs via `PP_CENSUS_BLOCK` / `PP_CENSUS_SUMMARY` events.

---

## 2. Parameters

Parent parameters are identical to `QM5_12710` (see the parent SPEC). The six
added measurement inputs:

| Parameter | Default | Meaning |
|---|---:|---|
| `opt_pp_buy1` | 0 | DL-089 closed-D1 buy-side pattern predicate id (0 = slot disabled) |
| `opt_pp_buy2` | 0 | DL-089 closed-D1 buy-side pattern predicate id (0 = slot disabled) |
| `opt_pp_buy3` | 0 | DL-089 closed-D1 buy-side pattern predicate id (0 = slot disabled) |
| `opt_pp_sell1` | 0 | DL-089 closed-D1 sell-side pattern predicate id (0 = slot disabled) |
| `opt_pp_sell2` | 0 | DL-089 closed-D1 sell-side pattern predicate id (0 = slot disabled) |
| `opt_pp_sell3` | 0 | DL-089 closed-D1 sell-side pattern predicate id (0 = slot disabled) |

Inherited parent parameters (unchanged defaults): `strategy_momentum_lookback_d1=252`,
`strategy_min_abs_return_pct=1.0`, `strategy_atr_period=20`, `strategy_atr_sl_mult=3.5`,
`strategy_min_atr_pct=0.75`, `strategy_max_atr_pct=7.5`, `strategy_max_hold_days=31`,
`strategy_max_spread_points=1000`.

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI host chart and only traded symbol, magic slot 0 (inherited from parent).

**Explicitly NOT for:**
- Any symbol other than `XTIUSD.DWX`; the sibling is a single-symbol measurement instrument for the parent's authorized universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (pattern-permission reference bar is closed D1, `shift 1`) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `5-9` (neutral baseline reproduces the parent) |
| Typical hold time | One monthly package, capped at 31 calendar days |
| Expected drawdown profile | Medium-high; WTI trends can reverse abruptly in supply shocks |
| Regime preference | Persistent WTI directional trend with non-extreme realized volatility |
| Purpose | DL-089 optimization census only; no live or pipeline verdict is authorized |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-TSMOM-2012`
**Source type:** peer-reviewed paper / AQR research page (inherited from parent QM5_12710)
**Pointer:** `https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum`
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12710_commodity-tsmom-12m-atr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized for this measurement sibling |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized for this measurement sibling |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
This build does not touch `T_Live`, AutoTrading, deploy manifests, or the
portfolio gate. It exists only to run the DL-089 optimization census against the
parent `QM5_12710` mechanics.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-03 | DL-089 measurement sibling of recompiled parent QM5_12710; added six opt_pp_* pattern veto inputs | router task 262f7959; sibling wave 3 (recipe = wave 2 QM5_41321-41324) |
