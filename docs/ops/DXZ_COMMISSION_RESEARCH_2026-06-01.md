# Darwinex Zero realistic commission model — research note

**Date:** 2026-06-01 · **Author:** Claude · **Trigger:** OWNER 2026-06-01
("at Q08 a realistic Darwinex Zero commission should be used — research it")
**Bearing on:** Q04 EA-side sim commission, DL-064 Gate-0, Q11 portfolio cost rule.

## Headline

The pipeline's `COMMISSION_PER_LOT_ROUND_TRIP = 7.00` (flat $7/lot, "locked by
Vault Q04 spec") is **not** the Darwinex Zero model and is **structurally wrong**:
DXZ commission is **asset-class-specific**, mostly **percent-of-notional** or a
**fixed per-contract amount in the instrument's own currency** — never a single
flat USD-per-lot figure across all symbols. For FX it is also **lower** than $7.

## Evidence (public sources — see §Sources; authoritative table is account-gated)

Darwinex Zero mirrors the underlying signal account's real Darwinex execution
conditions ("trading commissions & swaps are taken into account in terms of how
they affect the underlying signal account and associated DARWIN performance");
the client just isn't charged on a card. So the **Darwinex execution-cost model
applies to DXZ**.

| Asset class | Commission (per side / per order) | Round-trip | Charged in |
|---|---|---|---|
| **Forex** | 2.5 units per 1.0 lot (≈ **0.0025 % of notional**) | ~0.005 % notional · €5 on EURUSD 1 lot | base currency (e.g. €) |
| **Indices** | ~2.75 units per contract | ~5.5 / contract | index currency (USD/EUR/GBP) |
| **Commodities (gold)** | **0.0025 % of order value** | ~0.005 % notional | USD |
| Reduction | D-Score > 60 / Professional: up to −40 % | — | use **standard** (no reduction) for backtest |

Worked FX example (confirmed across sources): 1 lot EURUSD = €100,000 notional →
**€5 round-trip** (= 0.005 % of notional). vs the pinned $7 → ~40 % too high for FX,
and the wrong *unit* for indices (per-contract, not per-lot) and the wrong *model*
for commodities (%-of-notional).

## Implications for QM

1. **Replace the flat $7 with an evidence-based per-symbol commission registry**
   (e.g. `framework/registry/dxz_commission.json`) encoding, per symbol: model
   (`pct_notional` vs `fixed_per_lot`), rate, currency, and the FX conversion to
   account currency. Q04 (`q04_walkforward.py` / `QM_Common.mqh` EA-side sim) AND
   the Q11 portfolio cost rule must both read this ONE registry — no hardcoded
   number anywhere.
2. **Data-plumbing gap (blocks accurate %-notional costing).** The `q08_trades`
   streams carry only `volume` + `net` — **no price, no notional, no asset-class
   tag**. Fixed-per-lot/contract (FX, indices) is computable from `volume` + a
   per-symbol rate. But **%-of-notional (gold/commodities) needs notional =
   volume × contract_size × price**, which the stream lacks. Fix options:
   (a) extend the EA stream to emit `notional` per `TRADE_CLOSED`, or
   (b) document a per-symbol average-notional approximation. **OWNER decision.**
3. **Evidence integrity / Hard Rule.** "No invented commission values." The
   figures above are third-party reviews, not the canonical table. The
   authoritative source is the **per-asset table in the DXZ account** (login-gated,
   `darwinexzero.com/assets`) and the actual `Commissions` column on a DXZ /
   MetaTrader statement. **OWNER (only one with DXZ account access) should pull the
   official per-asset rates** so the registry is sourced, not estimated.
4. **DL-064 Gate-0 nuance.** Gate-0 ("cost-correct") applied *a* cost ($7/lot),
   so it is better than gross — but it is **not yet the realistic DXZ model**.
   Gate-0 should be re-stated as "cost-aware mechanism live; magnitude pending DXZ
   calibration registry."

## Recommended next steps (pending OWNER)

1. OWNER pulls the official per-asset commission table from the DXZ account.
2. Build `framework/registry/dxz_commission.json` from it (asset-class model +
   currency); Codex wires Q04 + the Q11 cost rule to read it.
3. Decide the notional plumbing for %-of-notional assets (EA emits `notional` —
   preferred — vs approximation).
4. Unblock Q11 Task A only after the cost rule is corrected (currently on HOLD).

## Sources
- Darwinex — *What are the execution costs?* https://help.darwinex.com/execution-costs
- Darwinex Zero — *Trading commissions and swaps* https://www.darwinexzero.com/docs/trading-commissions-and-swaps
- Darwinex Zero — *Pricing / FAQ* https://www.darwinexzero.com/pricing
- forexsuggest — *Darwinex Fees, Spreads and Commissions* https://forexsuggest.com/darwinex-fees-spreads/
- TradersUnion — *Darwinex Zero Fees and Spreads (Jan 2026)* https://tradersunion.com/brokers/forex/view/darwinex-zero/fees-and-spread/
