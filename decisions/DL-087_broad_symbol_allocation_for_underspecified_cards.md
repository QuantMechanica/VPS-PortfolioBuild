# DL-087 — Broad Symbol Allocation for Cards in the Legacy Format

**Date:** 2026-08-17
**Status:** ADOPTED (OWNER-authorized)
**Authority:** OWNER, 2026-08-17: *"Die 105 ohne Zielsymbol auf index, Gold und Major
Forex Paaren zuteilen!"*, reaffirmed after being shown that 100 of the 105 do declare
instruments and that the broad rule costs 1,111 additional magic rows.
**Scope:** the 105 registry-blocked EAs whose approved cards carry no structured
`target_symbols:` field — and only those.

## What this authorizes

Each of the 105 EAs is allocated magic rows for a fixed 13-symbol set, **regardless of
which instruments its own card names**:

| Class | Symbols |
|---|---|
| Indices (5) | `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX` |
| Gold (1) | `XAUUSD.DWX` |
| Major FX (7) | `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX` |

All thirteen are confirmed tradable in `framework/registry/dwx_symbol_matrix.csv`
(indices 5/5, commodities include `XAUUSD.DWX`, the seven USD majors within the 28 FX
rows). **105 × 13 = 1,365 magic rows.**

## Why a decision record was needed

The allocator would otherwise derive each EA's symbol set from its card. These 105 cards
are an older format: they record the instrument in `r3_reasoning`, the title and the slug
rather than in a `target_symbols:` list. Measured on 2026-08-17, **100 of the 105 do name
their instruments** in the card text — 69 name exactly one, the rest two to seven. Only
five (`QM5_12929`, `QM5_12930`, `QM5_1401`, `QM5_1402`, `QM5_1485`) name none anywhere.

Allocating the broad set therefore goes **beyond what those cards authorize**. A
single-instrument NDX momentum strategy (`QM5_12612`, whose card states *"NDX.DWX is a
core live-tradable DWX index instrument"*) will be allocated on EURUSD and gold as well.
That is a deliberate breadth-discovery choice, not an inference from the card, and it is
recorded here so no later reader mistakes it for one.

The alternative was put to OWNER with numbers — card-declared symbols plus the broad set
only for the five silent cards would have been **254 rows** — and the broad rule was
chosen knowingly.

## Consequences, stated plainly

- **1,111 additional (EA, symbol) pairs** relative to card-faithful allocation. Each pair
  is eventually a Q02 backtest. At the observed fleet throughput this is on the order of
  weeks of terminal time.
- Q02 results on symbols the card never contemplated are **exploratory**, not
  card-validated. A PASS there is a discovery, and the card must be amended before that
  pair is treated as authorized for anything downstream.
- A strategy will be run on instruments its source research never examined. Poor results
  on those pairs are not evidence against the strategy on its intended instrument.

## Binding constraints (unchanged by this decision)

- Allocation follows the governed sequence: EA directory → magic rows → resolver
  regeneration → verify nothing dropped. `update_magic_resolver.py` keeps only rows whose
  EA directory exists.
- Allocation is **serial**; concurrent allocation corrupts regeneration.
- `magic = ea_id * 10000 + symbol_slot`, unchanged. Slot numbering follows the fixed
  order of the table above so it is reproducible across regenerations.
- Allocation creates **rows, not queue pressure**. Enqueueing Q02 for all 1,365 pairs at
  once would swamp a queue already holding over a thousand pending items; the pairs are
  staged into the queue, not dumped into it. Every pair remains runnable — this governs
  *when*, never *whether*.
- No gate is lowered. These EAs clear Q02 onward on their own economics like every other
  candidate.
- Excluded regardless: `QM5_31003` (withheld, 28 undeclared foreign symbols), any EA whose
  `ea_id_registry` status is not active, and anything under `framework/EAs/_obsolete_*`.

## Evidence

- Worklists: `artifacts/fleet_magic_allocation_worklist_20260817.json`,
  `artifacts/century_prebuild_worklist_20260817.json`
- Tradability: `framework/registry/dwx_symbol_matrix.csv`
- Stranded inventory: `docs/ops/evidence/stranded_ea_inventory_2026-08-17.json`
- Allocator programme: router task `184bed28`
