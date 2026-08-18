# Point 3.1 — cost-model inventory: it feeds a gate, and the retro-trigger is exactly 2 rows

v6 §3.1 step 1 asks where the cost snapshot lives, what is in it, and — the question that sizes the
work — **who reads it**: *"geht er in Q02–Q10 ein, ist die Erweiterung ein Nachfahr-Auslöser mit
eigener Mengenabschätzung; geht er nur in den Buchbau, ist sie folgenlos."*

## Where it lives and what it says

`framework/registry/venue_cost_model.json`, generated 2026-07-19, carrying its own authority line:
*"OWNER 2026-07-19 directive: cost gate must use REAL Darwinex-Zero / FTMO worst-case costs."*

- **Convention:** `gate cost = max(dxz, ftmo)` worst-case per round-trip lot
- **Canonical engine:** `tools/strategy_farm/portfolio/commission.py (CommissionModel.cost_round_trip)`
- **Underlying registry:** `framework/registry/live_commission.json`
- **Class model:** forex 0.5 bp + $5.00/lot RT · index 0.5 bp + $5.50/lot RT
- **19 symbols**, each with `asset_class`, `dwx_symbol`, a `dxz` block, an `ftmo` block,
  `worst_case_rt_per_lot_usd`, and a note explaining which venue dominates and why

## It feeds a gate — so extension IS a retro-trigger

16 consumers. The decisive one is **`framework/scripts/q04_walkforward.py`**: the snapshot is a Q04
input, not a book-build input. `framework/scripts/venue_costs.py` exists specifically to serve it,
and its own docstring records that DL-082 §2 replaced the legacy flat `$7/lot` Q04 cost with this
model — *"an INPUT correction, not a threshold change"*.

Other consumers: `isolated_work_item_runner.py` (the worker), `q16_head_to_head.py` (optimization),
`portfolio/{build_joint_sim_manifest,challenge_campaign_capped,ftmo_p1_mc,swap_scenario}.py`,
`strategy_priority.py`, the two `prepare_ftmo_book3_*` scripts, and five test modules.

**So the answer to §3.1's branching question is the expensive branch — with one saving grace below.**

## Coverage gap against the 2.2 pool

| | |
|---|---:|
| symbols in the snapshot | 19 |
| distinct symbols in the 91-pair pool | 22 |
| covered | **11** |
| not covered | **11** |

The 11 uncovered split into two unlike classes:

- **5 real FX symbols** — AUDCAD, CHFJPY, EURGBP, EURJPY, USDCAD
- **6 logical basket host symbols** — `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` and five siblings.
  These have no venue cost of their own; their cost is a composition of their components. That is a
  **modelling question**, not a snapshot gap, and it should not be filed as one.

## The saving grace: the fallback over-costs, it never under-costs

`venue_costs.py` states its fallback discipline explicitly — *"never silently $0, never invent"*. A
symbol missing from the model falls back to the **maximum `worst_case_rt_per_lot_usd` within its
asset class** (forex ~$6.35, index ~$6.99, commodity ~$20.37), *"all real, model-sourced, non-zero,
and the harshest = never under-costs"*, and emits a WARN naming the symbol.

So the five uncovered FX symbols are currently charged ~$6.35/lot RT where their true figure is
likely ~$5.00. They are **over**-costed. The consequence is asymmetric and it makes the retro-trigger
cheap:

- a Q04 **PASS** earned under a harsher cost stays valid under the true cost — nothing to re-check
- only a Q04 **FAIL close to the floor** could be an artifact of the over-charge

## The retro-trigger, sized: 2 rows

Across the five uncovered symbols there are **597 Q04 FAILs**. Filtering to those whose weakest fold
sits below the 1.0 PF floor but within 5% of it:

| symbol | EA | weakest fold |
|---|---|---:|
| EURJPY | QM5_9940 | 0.988 |
| EURJPY | QM5_10291 | 0.951 |

**Two rows.** The remaining 595 are far enough from the floor that a ~$1.35/lot cost reduction
cannot move them.

**My own filter error, corrected here:** the first pass used `weakest >= 0.95` and returned five
hits, three of which (27.300, 1.800, 1.124) are *above* the floor — they are not PF failures at all
but failures on another criterion. The correct band is `0.95 <= weakest < 1.0`. Same shape as the
INFRA_FAIL conflation corrected twice tonight: a filter left open on the side that cannot matter.

## Recommendation

Add the five FX symbols with real DXZ/FTMO figures; re-derive Q04 for the two named rows only;
handle the six basket host symbols as a composition question inside the engine rather than as
snapshot entries. That discharges 3.1 step 1 and step 2 for the pool without a fleet-wide re-run.

## Evidence

- `framework/registry/venue_cost_model.json` (19 symbols, authority line, convention)
- `framework/scripts/venue_costs.py` (fallback discipline, DL-082 §2 note)
- consumer list: 16 files under `tools/`, `framework/scripts/`
- pool: `artifacts/pool_union_20260817.json` (91 pairs, 22 distinct symbols)
