# Independent (non-Claude) critique request: card-intake prescreen G0-economics contract v2

You are Antigravity (agy), acting as an **independent cross-vendor critic**. This module was
authored by Claude and, by the module's own design, **cannot be self-activated**:
`record_cross_vendor_critique(critic_agent="claude", ...)` raises `ValueError` on purpose. Your
review is the independent check the contract requires before it can be activated. You are NOT
activating anything in this session — this is a read-only critique. Do not call
`record_cross_vendor_critique`, do not edit any file, do not touch the farm state DB, do not run
`farmctl` or `agent_router.py` commands that mutate state. Treat this entire task as read-only:
you may read files and run read-only commands (e.g. `pytest`) but must not write, edit, or delete
anything in the repository.

Working directory (canonical checkout): `C:/QM/repo`.

## What to review (read-only)

1. `tools/strategy_farm/card_intake_prescreen_g0_economics.py` — the contract implementation
   (`CONTRACT_VERSION = "qm.card-intake-prescreen-g0-economics/v2"`).
2. `tools/strategy_farm/tests/test_card_intake_prescreen_g0_economics.py` — its test suite
   (claimed 21/21 passing; verify by running
   `pytest tools/strategy_farm/tests/test_card_intake_prescreen_g0_economics.py -v` yourself).
3. `docs/ops/evidence/2026-09-18_card_intake_prescreen_v2/MIGRATION_NOTE.md` — the authoring
   agent's own writeup of what was built and why.
4. `docs/ops/evidence/2026-09-18_card_intake_prescreen_v2/scan_208_cards_worktree_2026-09-18.jsonl`
   — one verdict per line, 208 cards scanned report-only.
5. `docs/ops/evidence/2026-09-18_card_intake_prescreen_v2/qm5_41477_reference_validation_2026-09-18.json`
   — the reference validation against the QM5_41477 postmortem card that motivated this contract
   (`docs/research/HFXMR_41477_Q02_POSTMORTEM_2026-09-18.md`).
6. `framework/registry/live_commission.json` and the `portfolio.commission.CommissionModel` it
   feeds, since `cost_to_target_floor` computes `commission_R` from that registry and enforces
   `COST_TO_TARGET_MAX_R = 0.03`.

## What your critique must assess

For each of the four checks — `pilot_fire_count_evidence`, `cost_to_target_floor`,
`no_op_filter_lint`, `skip_reason_logging` — assess **false-positive and false-negative risk** as
it would apply across the 208-card scan and against the reference QM5_41477 validation:

- **False positive** = the check would flag/FAIL a card that is actually fine (wastes reviewer
  time, or would incorrectly block a genuinely sound card once this becomes a blocking gate).
- **False negative** = the check would pass/silence a card that has the exact defect class the
  postmortem identified (the contract fails at the one job it exists to do).

Concretely interrogate:
- Is `MISSING_EVIDENCE`/`NOT_APPLICABLE` classification for ~200/208 cards on checks 1-2 truly
  benign (new fields, no card could have had them), or does it mask cards that *should* be
  flagged more strongly given other evidence already on the card?
- Does `no_op_filter_lint`'s `NOT_APPLICABLE` result for all 208 worktree cards (vs. its `FAIL` on
  the QM5_41477 reference card) indicate the two shipped rules
  (`trade_cap_vs_window_count`, `time_stop_vs_flat_minute`) are too narrowly matched to one card's
  specific phrasing to catch the general defect class -- i.e. a false-negative risk by
  construction on the broader population?
- Is the `0.03R` `COST_TO_TARGET_MAX_R` floor itself well-grounded (cite where it comes from), and
  is the commission figure sourced correctly from the OWNER-ratified registry with no hand-rolled
  fallback path that could silently mis-price cost?
- Does `skip_reason_logging`'s `DEFERRED_NO_BUILD_YET` classification correctly avoid
  false-positive FAILs for cards with no EA yet, while still being mandatory once an EA exists
  (verify the gate actually flips from deferred to enforced at the right point, e.g. Q02)?
- Any other correctness, scope, or activation-safety issue you find in the implementation itself
  (e.g. edge cases in `_infer_expected_trades_per_year_per_symbol`-adjacent logic, ledger
  append-only guarantees, version-pinning of old verdicts).

## Required output

Print your full critique as your final response text (markdown), structured as:
1. One-line verdict: `VERDICT: APPROVE` or `VERDICT: REVISE`.
2. A finding per check (4 total) with concrete `file:line` citations for every claim.
3. Any additional findings (implementation correctness, activation safety).
4. If `REVISE`: a concrete, minimal list of what must change before this critique could become
   ACCEPT.

Do not activate the contract. Do not change `g0_status` on any card. Do not modify the module,
its tests, or any evidence file. This is a read-only review -- no filesystem writes at all; your
entire deliverable is the response text.
