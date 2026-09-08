---
ea_id: QM5_41333
slug: tv-liq-break-opt
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
parent_ea_id: QM5_10700
parent_slug: tv-liq-break
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_10700_tv-liq-break.md
g0_status: APPROVED
g0_authority: "CEO-directed DL-089 measurement sibling build 2026-09-03 (recipe b91f5ffa); parent QM5_10700 g0 APPROVED; satisfies dl089_matrix_service deferral 'expected one approved _opt sibling for QM5_10700/XAUUSD.DWX, found 0'"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: H1
target_symbols: [XAUUSD.DWX]
expected_trades_per_year_per_symbol: 80
last_updated: 2026-09-03
---

# QM5_41333 `tv-liq-break-opt`

Target symbols: XAUUSD.DWX

OWNER-authorized DL-089 measurement sibling of `QM5_10700`. It preserves the
parent entry, exit, sizing, news, and Friday-close mechanics and adds exactly
six closed-D1 pattern veto inputs: `opt_pp_buy1..3` and `opt_pp_sell1..3`.
Zero disables a slot, so the shipped baseline is neutral. No live or pipeline
verdict is authorized. Backtests require `RISK_FIXED > 0`, `RISK_PERCENT = 0`,
and `qm_news_stale_max_hours <= 336`.

## R1-R4 assessment

| Criterion | Status | Rationale |
|---|---|---|
| R1 Source-Link | PASS | Inherited from the approved QM5_10700 parent card and its named TradingView open-source strategy. |
| R2 Mechanical | PASS | Parent mechanics are unchanged; the six deterministic inputs only veto entries before order submission. |
| R3 Data Available | PASS | Uses closed D1 OHLC predicates on XAUUSD.DWX, alongside the parent's H1 contraction/liquidity-breakout inputs. |
| R4 No ML | PASS | Fixed deterministic rules; no ML, grid, martingale, or online adaptation. |

## Strategy logic (inherited from QM5_10700)

Two-pivot contraction detection (newest pivot high below the prior pivot high,
newest pivot low above the prior pivot low). On the close of an H1 bar the EA
buys when price closes through the prior liquidity high and sells when price
closes through the prior liquidity low. Baseline exit is an ATR stop plus a
fixed 2R take-profit, with the framework Friday-close guard. The six DL-089
pattern inputs sit in front of every order via `Pattern_AllowsRequest`; at
their neutral zero defaults the corset admits every parent entry, so the
census baseline is byte-equivalent to the recompiled QM5_10700 identity.

## Source citation

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/UUHabgvo-Liquidity-Breakout-Strategy-presentTrading/
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10700_tv-liq-break.md`

## Risk model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |

This sibling exists only to run the DL-089 pattern-measurement census. No live
or pipeline verdict is authorized.
