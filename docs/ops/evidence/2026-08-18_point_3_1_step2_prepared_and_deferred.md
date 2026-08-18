# Point 3.1 step 2 — the five entries are derivable without inventing anything, and the edit is deliberately deferred

Step 1 established that `venue_cost_model.json` feeds Q04, that 11 of the pool's 22 symbols are
uncovered, and that the uncovered ones split into 5 real FX symbols and 6 logical basket hosts.
This prepares the five FX entries and states why they are **not** being written yet.

## Four of five are derivable from the snapshot's own convention

DXZ charges `2.5 per side` in the instrument's **base currency** (`tester_group: Forex\* … Mode=1
(base ccy)`); FTMO charges a flat `$5.00` round-trip for forex. `worst_case_rt_per_lot_usd` is the
max of the two. The existing AUDUSD entry demonstrates the pattern end to end: 5.00 AUD → $3.30 at
AUDUSD 0.66 → worst case $5.00 *"because FTMO flat $5 DOMINATES"*.

Applying the same rule with the snapshot's own `reference_prices_indicative_2026_07`:

| symbol | base | DXZ RT (base ccy) | DXZ RT USD | FTMO RT | **worst_case** | source of the USD leg |
|---|---|---|---|---|---|---|
| USDCAD | USD | 5.00 USD | $5.00 | $5.00 | **$5.00** | none needed — base is USD |
| EURJPY | EUR | 5.00 EUR | $5.85 | $5.00 | **$5.85** | EURUSD 1.17, in the snapshot |
| EURGBP | EUR | 5.00 EUR | $5.85 | $5.00 | **$5.85** | EURUSD 1.17, in the snapshot |
| AUDCAD | AUD | 5.00 AUD | $3.30 | $5.00 | **$5.00** | AUDUSD 0.66, in the snapshot |
| **CHFJPY** | CHF | 5.00 CHF | **unknown** | $5.00 | **unresolved** | needs CHFUSD — **absent** |

No number above is invented; each is the documented convention applied to a price the snapshot
already carries. CHFJPY is the exception and must be written with `null` for its DXZ USD leg and its
worst case, which routes it to the declared conservative class-max fallback — the same treatment it
receives today, but **explicitly declared instead of silently absent**.

That matters: the snapshot's own discipline is *"never silently $0, never invent"*, and its
`open_axes_not_covered` block already names spread and swap as openly unresolved. A null CHF leg
belongs in that tradition, not in a guess.

## Why the edit is deferred, and it is not a preference

**Q08 consumes the cost model directly.** A live Q08 aggregate from the running batch records:

```
commission_basis  : "worst_case_dxz_ftmo"
commission_model  : {registry_path: framework/registry/live_commission.json, default_class: forex …}
commission_total  : 454.901689
cost_cushion      : 1.9551
cost_cushion_tier : "EDGE_SOFT"
```

Editing the model mid-batch would put some (b) runs on the old cost basis and some on the new. C1's
8-of-8 determinism result was measured under the current model; later C2/C3 readings taken under a
changed model would not be comparable to it. **That would contaminate the pre-registered experiment
to save a few hours.**

Concretely affected: **5 of the 78 batch rows are still pending on these symbols** — EURJPY 1,
AUDCAD 2, USDCAD 1, CHFJPY 1. Those are exactly the rows that would straddle the change.

## The change, when it is made

1. Add the four derivable entries plus a null-legged CHFJPY to `venue_cost_model.json`.
2. **Update the pinned digest in the same commit** —
   `framework/EAs/QM5_10253_tv-ifvg-sweep/tools/candidate_analysis/audit_tv_ifvg_sweep_two_arm_dev.py:107`
   pins the file's SHA256 and currently matches byte-for-byte.
3. Re-derive Q04 for the two rows the over-charge could plausibly have flipped — EURJPY/QM5_9940
   (weakest fold 0.988) and EURJPY/QM5_10291 (0.951). No fleet-wide re-run.
4. Handle the six basket host symbols as a composition question inside the engine, not as registry
   entries.

Trigger: the (b) batch reaching completion.

## Evidence

- `framework/registry/venue_cost_model.json` — convention, `reference_prices_indicative_2026_07`,
  AUDUSD as the worked example, `open_axes_not_covered`
- live Q08 `aggregate.json` from the running batch — `commission_basis`, `commission_model`
- `docs/ops/evidence/2026-08-18_point_3_1_cost_model_inventory.md` (step 1 and its correction)
