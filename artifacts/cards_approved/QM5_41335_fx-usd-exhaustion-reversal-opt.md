---
ea_id: QM5_41335
slug: fx-usd-exhaustion-reversal-opt
type: strategy
source_id: OWNER-CODEX-FX-USD-EXHAUSTION-20260626
parent_ea_id: QM5_12580
parent_slug: fx-usd-exhaustion-reversal
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_12580_fx-usd-exhaustion-reversal.md
g0_status: APPROVED
g0_authority: "Inherited from approved parent QM5_12580 (OWNER 2026-06-26); DL-089 measurement sibling authorized under OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903 (path-to-25 sibling wave)."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
target_symbols: [AUDUSD.DWX]
expected_trades_per_year_per_symbol: 5
last_updated: 2026-09-03
---

# QM5_41335 `fx-usd-exhaustion-reversal-opt`

Target symbols: AUDUSD.DWX

OWNER-authorized DL-089 measurement sibling of `QM5_12580`. It preserves the
repaired parent entry, exit, sizing, news, and Friday-close mechanics
byte-for-byte and adds exactly six closed-D1 pattern veto inputs:
`opt_pp_buy1..3` and `opt_pp_sell1..3`. Zero disables a slot, so the shipped
baseline is neutral (`census_control`) and reproduces the parent exactly. No
live or pipeline verdict is authorized. Backtests require `RISK_FIXED > 0`,
`RISK_PERCENT = 0`, and `qm_news_stale_max_hours <= 336`.

The parent evaluates a USD-major basket three-day return z-score once per closed
D1 bar and fades an overextended USD move on the carrier symbol when it is also
stretched at least `strategy_extension_atr_mult * ATR(14)` from its `SMA(10)`.
The seven-symbol basket array (`EURUSD, GBPUSD, AUDUSD, NZDUSD, USDJPY, USDCHF,
USDCAD` - all `.DWX`) is the factor-construction universe; the EA only trades
the chart symbol whose basket slot matches `qm_magic_slot_offset`. For this
census cell that carrier is `AUDUSD.DWX` (basket slot 2), so the shipped set
pins `qm_magic_slot_offset=2` and the sibling measures the single
`AUDUSD.DWX` (EA, symbol) cell only.

## R1-R4 assessment

| Criterion | Status | Rationale |
|---|---|---|
| R1 Source-Link | PASS | Inherited from the approved QM5_12580 parent card and its named source (OWNER-CODEX-FX-USD-EXHAUSTION-20260626). |
| R2 Mechanical | PASS | Parent mechanics are unchanged; the six deterministic inputs only veto entries. |
| R3 Data Available | PASS | Uses closed D1 OHLC predicates on AUDUSD.DWX alongside the parent's D1 USD-basket z-score, SMA, and ATR inputs. |
| R4 No ML | PASS | Fixed deterministic rules; no ML, grid, martingale, or online adaptation. |
