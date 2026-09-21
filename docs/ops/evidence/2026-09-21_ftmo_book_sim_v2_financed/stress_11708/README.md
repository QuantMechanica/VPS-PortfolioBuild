# 11708 marginal under cost stress + book cost sensitivity (Fable, 2026-09-21 19:3xZ)

Same financed engine and contract as `../README.md` (Codex 3fae43b2: financed streams, 5 paired seeds x 40,000 marginal paths,
504-bd marginal horizon, base 5,000 paths / 1008 bd, 20-day blocks, seed 20260921), candidate plan reduced to 11708, run twice:

| Run | Stress | Base LCB | Base max-loss breach (phase 1) | Base progress USD/bd | Base cost drag USD/bd | 11708 Δ LCB (mean of 5 paired seeds, SE) | 11708 resolution |
|---|---|---:|---:|---:|---:|---:|---|
| `*_sp0_sl0` | none | 0.8668 | 0.0202 | 27.50 | 12.61 | **+0.0058** (SE 0.0016) | RESOLVED positive, below the +0.01 roster bar |
| `*_sp1.0_sl2.0` | +1 bps round-trip spread on every trade + 2 USD/lot slippage | **0.6072** | **0.1016** | 16.0 | 24.11 (spread stress 17,081 USD + slippage 3,440 USD over the window) | **−0.0056** (SE 0.0011) | RESOLVED negative |

Reading. (1) 11708's small positive marginal does not survive a modest cost stress: `SHADOW_BOOK` stands; not `QUEUE_FOR_NEXT_DEMO`
for Sunday. (2) The incumbent book is strongly cost-sensitive: a uniform +1 bps / +2 USD/lot stress takes the payout LCB from 0.87
to 0.61 and quintuples the phase-1 max-loss breach probability. The Q08 streams carry Darwinex `.DWX` spreads; FTMO spreads are
measured only for XAUUSD and GER40 (`D:/QM/reports/ftmo_spread_calibration/`). Venue cost fidelity is therefore the strongest open
economic uncertainty for the purchase packet -> Codex ticket `73434cab` (per-symbol FTMO-minus-Darwinex spread delta, VENUE_ADJUSTED
headline). The stress here is uniform and deliberately harsh for the FX sleeves (1 bps ≈ the full USDJPY spread); it is a
sensitivity, not a venue measurement.
