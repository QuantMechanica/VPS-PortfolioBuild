# Q02 first-intake canary now ranks by RAM-reservation GB, not a static priority list

**Date:** 2026-09-18 · **Author:** Claude (agent_tasks `7fb74ce4-f9ee-4576-a71d-321b4f2a2ba6`, routed
by `fable-orchestrator-2026-09-18`) · **Repo:** `C:\QM\repo` (`agents/board-advisor` @ `b06da29587`
base) · **Status:** code + tests, no DB writes, no compile, no factory-state mutation.

## Ticket

> farmctl intake-first-q02 (planner ~35565-35684) picked SP500.DWX for QM5_41476 (receipt
> `D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/07087e86-8a5a-4638-b3aa-3d56edc55780_96e5f16f-8d18-4ace-8318-a0c26ea6b9cf.json`).
> The 44 GB single_index_tick class only runs on an empty fleet via the exclusive drain lane, so
> first evidence is delayed by hours-days. Change: order canary candidates by
> `terminal_worker._ram_reservation_detail_for_candidate` class/GB ascending (ties: card order),
> keep everything else; add a unit test; document in CRITIC_TO_Q00_TRANSITION. Also: the
> universe-expansion Q02 path is hard-bound to `OWNER-DEC-13036-XAU`
> (`universe_expansion_owner_decision_mismatch`) — generalize the accepted decision ids to a
> config list that includes `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`.

## What changed

`tools/strategy_farm/farmctl.py`:

1. **Retired `Q02_CANARY_SYMBOL_PRIORITY`** (a hand-maintained liquidity-order tuple:
   EURUSD, USDJPY, GBPUSD, XAUUSD, SP500, NDX, GDAXI, XTIUSD, XNGUSD). It ranked SP500 ahead of
   NDX/GDAXI unconditionally and had no mechanism to track `terminal_worker`'s RAM calibration
   table — exactly the drift that produced this ticket's defect.
2. **New `_q02_canary_ram_reservation_gb(symbol, ea_id="")`** — lazily imports `terminal_worker`
   (same try/bare-import-then-package-fallback pattern already used for `review_entry_gate` in
   this file, required because `terminal_worker.py` imports `farmctl` at module level) and calls
   `_ram_reservation_detail_for_candidate({"phase": "Q02", "ea_id": ea_id, "symbol": symbol}, {},
   multisymbol=False, apply_phase_floor=False)` — the same resolver `terminal_worker` uses to
   reserve RAM at claim time.
3. **`_q02_canary_symbol_rank(symbol, ea_id="")`** now returns that GB value (previously
   `(priority_index, symbol)`).
4. **`_stage_q02_setfiles(parsed, ea_id="")`** sort key is now `(rank_gb, index)` — RAM ascending,
   ties keep the incoming list order ("card order"). `ea_id` threaded through from both call
   sites (`_first_q02_setfile_plan`, `_auto_enqueue_q02_for_build`); harmless no-op for the
   single-symbol RAM lookup today (ea_id only matters for the legacy multisymbol two-leg-FX host
   table), kept for correctness if that ever changes.
5. **`UNIVERSE_EXPANSION_ACCEPTED_OWNER_DECISIONS = (UNIVERSE_EXPANSION_OWNER_DECISION,
   "OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917")`** — `enqueue_universe_expansion_q02`'s
   gate now checks membership in this tuple instead of equality against the single literal. The
   refusal payload's `expected` field is now a list. The accepted decision id is still stored
   verbatim in the enqueued work item's payload (`universe_expansion_owner_decision`), so
   provenance per row is unaffected.

`docs/ops/CRITIC_TO_Q00_TRANSITION_2026-09-16.md`: appended §6 documenting both fixes and the
QM5_41476/QM5_41475 fact-check below.

## Fact-check against the ticket's own premise (important)

The ticket's example ("SP500.DWX = 44 GB exclusive class instead of NDX.DWX = 12 GB") predates
the 2026-09-16 recalibration recorded in `terminal_worker.py`
(`INDEX_TICK_RESERVATION_GB_BY_BASE`, ticket 6cdc6811): NDX and GDAXI were moved back to the
measured-necessity 44 GB class that day (Q05 D1 full-window runs measured 39.2-39.5 GB, falsifying
the earlier 12 GB provisional value from Q04-only evidence). Read directly:

```
$ python -c "import sys; sys.path.insert(0,'tools/strategy_farm'); import terminal_worker as tw; print(tw.INDEX_TICK_RESERVATION_GB_BY_BASE)"
{'SP500': 44.0, 'NDX': 44.0, 'GDAXI': 44.0, 'WS30': 24.0, 'UK100': 24.0}
```

QM5_41476's own receipt confirms its candidate set was `{SP500.DWX, GDAXI.DWX, NDX.DWX}` — under
today's table **all three are 44 GB**, so this fix does not cheapen QM5_41476's specific canary
(nor QM5_41475/H-CW's, same candidate set — see `docs/ops/CRITIC_TO_Q00_TRANSITION_2026-09-16.md`
§6). The fix is still correct and necessary: it replaces a second, hand-maintained place that
must be kept in sync with the calibration table (and silently wasn't) with a direct read of that
table, so the next recalibration (e.g. if `WS30`/`UK100` regain a sub-44GB entry, or any base
moves the other way) is honored automatically. Demonstrated with a synthetic mixed-cost cohort in
`test_staging_prefers_the_cheaper_index_base_over_the_44gb_exclusive_class` (UK100 24GB vs SP500
44GB) since no real cohort with a live cost split exists today.

## Behavior change accepted (documented, not hidden)

The retired priority list also encoded a liquidity preference among same-RAM-class FX/metal pairs
(e.g. USDJPY ranked above GBPUSD regardless of card position). The ticket's ranking rule ("class/GB
ascending, ties: card order") has no room for that secondary preference — RAM class is now the
only tiebreak dimension the ranking looks at; identical-class ties fall through to plain input
order. Two pre-existing tests encoded the old tiebreak and were updated to match:
- `tools/strategy_farm/tests/test_mnt038_canary_fanout.py::test_staging_selects_one_liquid_canary_before_fanout`
  → renamed `test_staging_selects_cheapest_ram_class_canary_before_fanout`, canary AUDUSD (not
  EURUSD) among four same-class FX/metal/index candidates.
- `tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py::test_apply_preserves_new_deferral_when_sidecar_was_already_nonempty`
  → canary AUDUSD (not EURUSD) among five same-class FX candidates.

## Tests added

- `tools/strategy_farm/tests/test_q02_canary_ram_ranking.py` — pure ranking-function contract
  (ordinary-class flat 8GB, index-base table values, cheap-vs-44GB ordering, case-insensitivity,
  ea_id no-op for single-symbol).
- `tools/strategy_farm/tests/test_mnt038_canary_fanout.py` — updated + two new cases: cheaper
  index base wins over the 44GB exclusive class; tie-break is card order, not alphabetical.
- `tools/strategy_farm/tests/test_universe_expansion_owner_decision.py` — decision-id gate:
  rejects an unlisted id with the full expected list, accepts every configured id, asserts both
  ids are present.

No DB writes in any new/changed test (the owner-decision tests short-circuit before
`init_db`/`connect`; the ranking and staging tests are pure functions over in-memory tuples).

## Verification

```
$ python -m pytest tools/strategy_farm/tests/test_q02_canary_ram_ranking.py \
    tools/strategy_farm/tests/test_mnt038_canary_fanout.py \
    tools/strategy_farm/tests/test_universe_expansion_owner_decision.py \
    tools/strategy_farm/tests/test_first_q02_intake.py -q
45 passed

$ python -m pytest tools/strategy_farm/tests/test_index_tick_reservation_table.py \
    tools/strategy_farm/tests/test_terminal_worker_phase_ram_floor.py \
    tools/strategy_farm/tests/test_universe_expansion.py -q
55 passed

$ python -m pytest tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py -q
15 passed
```

(130 tests across every file that imports or exercises `_q02_canary_symbol_rank`,
`_stage_q02_setfiles`, `enqueue_universe_expansion_q02`, or the RAM-reservation resolver this
change now calls — the focused verification scope for a Tier-2 change touching a single shared
ranking function and one gate check. The repo's full `tools/strategy_farm/tests/` suite was also
started in the background for extra coverage; not required for or blocking this REVIEW handoff.)

## Risks / blockers

- Left in `REVIEW` per standing rule (Codex review mandatory before acceptance / main
  integration is Claude+OWNER close-out only). No commit made here — diff is live in the
  `agents/board-advisor` canonical checkout working tree at `C:\QM\repo`.
- The `ea_id` threading through `_stage_q02_setfiles`/`_q02_canary_symbol_rank` is currently inert
  for every real call site (single-symbol RAM lookup ignores it); flagged here so a reviewer does
  not read it as dead-code noise — it exists for correctness if the multisymbol legacy-host path
  is ever reached through this function.
- `Q02_CANARY_SYMBOL_PRIORITY` is fully removed, not deprecated-in-place; one historical evidence
  doc (`docs/ops/evidence/2026-09-16_requeue_lifts/QM5_11731_receipt.md`) still names it as a
  historical fact about a past canary pick — left untouched (evidence docs are immutable).

## Recommended next step

Codex review of `tools/strategy_farm/farmctl.py` diff (owner-decision gate + canary ranking) and
the two updated pre-existing tests, then Claude+OWNER close-out merges to main.
