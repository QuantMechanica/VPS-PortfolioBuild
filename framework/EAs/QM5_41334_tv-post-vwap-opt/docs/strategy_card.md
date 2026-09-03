---
ea_id: QM5_41334
slug: tv-post-vwap-opt
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
parent_ea_id: QM5_10815
parent_slug: tv-post-vwap
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_10815_tv-post-vwap.md
g0_status: APPROVED
g0_authority: "CEO-directed DL-089 measurement sibling build 2026-09-03 (wave 3 recipe 5e6f19a61a); parent QM5_10815 g0 APPROVED; satisfies dl089_matrix_service deferral 'expected one approved _opt sibling for QM5_10815/GDAXI.DWX, found 0'"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: H1
target_symbols: [GDAXI.DWX]
expected_trades_per_year_per_symbol: 70
last_updated: 2026-09-03
---

# QM5_41334 `tv-post-vwap-opt`

Target symbols: GDAXI.DWX

OWNER-authorized DL-089 measurement sibling of `QM5_10815`. It preserves the
parent entry, exit, sizing, news, and Friday-close mechanics and adds exactly
six closed-D1 pattern veto inputs: `opt_pp_buy1..3` and `opt_pp_sell1..3`.
Zero disables a slot, so the shipped baseline is neutral. No live or pipeline
verdict is authorized. Backtests require `RISK_FIXED > 0`, `RISK_PERCENT = 0`,
and `qm_news_stale_max_hours <= 336`.

## R1-R4 assessment

| Criterion | Status | Rationale |
|---|---|---|
| R1 Source-Link | PASS | Inherited from the approved QM5_10815 parent card and its named TradingView open-source strategy. |
| R2 Mechanical | PASS | Parent mechanics are unchanged; the six deterministic inputs only veto entries before order submission. |
| R3 Data Available | PASS | Uses closed D1 OHLC predicates on GDAXI.DWX, alongside the parent's H1 tick-volume, ATR, and VWAP inputs. |
| R4 No ML | PASS | Fixed deterministic rules; no ML, grid, martingale, or online adaptation. |

## Strategy logic (inherited from QM5_10815)

The parent trades a closed-bar reversal after a high-volume absorption bar
around session VWAP. A long setup requires the absorption bar to stretch below
VWAP by at least the configured ATR fraction, print a lower wick with high
relative tick volume, close back inside the prior bar range, and then have the
next closed bar reclaim the absorption high; the short setup mirrors that above
VWAP. The stop sits beyond the absorption swing by an ATR buffer and is capped
at a maximum ATR distance; the default target is session VWAP with an optional
fixed-R variant, plus M15/H1 time stops and the framework Friday-close guard.
The six DL-089 pattern inputs sit in front of every order via
`Pattern_AllowsRequest`; at their neutral zero defaults the corset admits every
parent entry, so the census baseline is byte-equivalent to the recompiled
QM5_10815 identity.

## Source citation

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/j6iKZmCf-Post-Absorption-VWAP-Reversal-Engine-V1-6/
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10815_tv-post-vwap.md`

## Risk model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |

This sibling exists only to run the DL-089 pattern-measurement census. No live
or pipeline verdict is authorized.
