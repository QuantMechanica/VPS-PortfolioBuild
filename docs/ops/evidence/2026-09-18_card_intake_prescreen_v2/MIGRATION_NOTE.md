# Card intake prescreen -- G0 economics contract v2: migration note

Status: **report-only, non-blocking.** No card frontmatter, no `g0_status`, and
no approval state was changed by this work. This note lists which currently
approved cards would fail the new checks *if* they were mandatory; it does not
retroactively reject or requeue anything.

Task: `7a5c6c40-9516-4e6d-a93e-47a99d2a0bf8` ("Prescreen v2 (versioned,
sec68A)"). Source: `docs/research/HFXMR_41477_Q02_POSTMORTEM_2026-09-18.md`
section 5 (QM5_41477 H-FXMR Q02 postmortem).

## What was built

`tools/strategy_farm/card_intake_prescreen_g0_economics.py` -- a new,
independently versioned contract (`CONTRACT_VERSION =
"qm.card-intake-prescreen-g0-economics/v2"`), implementing the postmortem's
four durable-lesson checks:

1. `pilot_fire_count_evidence` -- a card with a trading-frequency claim
   (`expected_trades_per_year_per_symbol` or an `expected_trade_frequency`
   prose claim) must also carry a `measured_fire_count_per_window` field
   bound to a hash-pinned evidence file
   (`measured_fire_count_evidence_path` + `measured_fire_count_evidence_sha256`).
   A claim without measured evidence is `MISSING_EVIDENCE`.
2. `cost_to_target_floor` -- a card must declare `cost_floor_min_stop_units`
   and `cost_floor_unit_value_per_lot`; `commission_R` is computed via the
   OWNER-ratified worst-case commission registry
   (`framework/registry/live_commission.json` through
   `portfolio.commission.CommissionModel` -- never a hand-rolled figure) and
   must stay at or below `COST_TO_TARGET_MAX_R = 0.03`.
3. `no_op_filter_lint` -- cross-checks declared controls against each other
   for structural reachability. Two mechanical rules ship now
   (`trade_cap_vs_window_count`, `time_stop_vs_flat_minute`); the rule set is
   explicitly extensible, not exhaustive.
4. `skip_reason_logging` -- a built EA's `.mqh`/`.mq5` source must emit a
   `STRATEGY_ENTRY_REJECTED` event (new event name, distinct from the
   framework's existing `QM_ENTRY_REJECTED_*` order-submission rejects in
   `QM_Entry.mqh`, which never fire for an application-level "no signal"
   evaluation). This check is `DEFERRED_NO_BUILD_YET` at G0 (no EA exists
   yet) and becomes mandatory before Q02.

Tests: `tools/strategy_farm/tests/test_card_intake_prescreen_g0_economics.py`,
21/21 passing (`pytest tools/strategy_farm/tests/test_card_intake_prescreen_g0_economics.py -v`).

## Relationship to the existing `card_intake_prescreen.py` (v1)

A module of the same family already exists upstream (`agents/board-advisor`,
schema `qm.card-intake-prescreen/v1`, last touched 2026-09-15), but it screens
a *different* problem: dedup/overlap, DWX symbol and external-feed
availability, Edge Lab charter-section completeness, and the runtime-ML /
tail-risk-contract boundary, at the `cards_review`/`cards_draft` stage. It has
no frequency-measurement, cost-floor, control-reachability, or build-time
logging check. This new module is an additive sibling, not a replacement or a
rename -- it does not import, patch, or alter v1's behavior in any way. When
the branches that carry each module eventually merge, folding both under one
schema namespace is a reasonable follow-up; it is out of scope here to avoid
touching a live, heavily-modified upstream checkout (`C:/QM/repo` on
`agents/board-advisor` currently carries ~530 dirty paths of unrelated,
in-flight factory state -- not a safe target for this change).

## Old verdicts stay bound to their version

This contract never rewrites a card's `g0_status`/`g0_approval_reasoning`
frontmatter and never touches the state DB. Every card approved to date was
evaluated only against `farmctl.approve_card`'s existing checks (R1-R4
consistency, `_approval_card_contract_issues`,
`_infer_expected_trades_per_year_per_symbol`) plus, for some cards, the
separate v1 draft-stage screen -- neither of which is versioned by name today.
`LEGACY_CONTRACT_VERSION = "qm.card-intake-prescreen-g0-economics/v1-legacy-unversioned"`
exists purely as an explicit label for that historical baseline. A verdict
produced by this module is only ever appended (via `append_verdict_to_ledger`,
JSONL, open in `"a"` mode) to a caller-owned ledger; it never mutates or
supersedes an existing row.

## Activation gate: independent cross-vendor critique required

`contract_is_active()` returns `False` until a critique distinct from the
implementing author (`claude`) is recorded via `record_cross_vendor_critique`
with `verdict="ACCEPT"`, appended to
`docs/ops/evidence/2026-09-18_card_intake_prescreen_v2/activation_ledger.jsonl`.
Calling it with `critic_agent="claude"` raises `ValueError` -- self-activation
is not possible by construction. **This module ships INACTIVE.** No file in
this evidence directory records an ACCEPT critique; `contract_is_active()`
currently returns `False`. Activating it (Codex or OWNER review, then an
ACCEPT record) and wiring it into `farmctl.approve_card` /
`ready_strategy_card_inventory` as a blocking gate are both follow-up work,
not done here -- the postmortem's own card (`QM5_41477`) is direct evidence of
what happens when a same-vendor-only approval substitutes for that step
(`Pipeline history`: "APPROVED ... independent non-Kimi critique gated").

## Scan results (report-only, no cards were touched)

### This worktree's `artifacts/cards_approved/` (208 cards; stale relative to
canonical `C:/QM/repo`, which has 258 -- the 50-card gap includes the
postmortem's own card and its sibling H-series, added after this branch's
base commit)

```
scanned: 208
by_overall_status:
  FAIL:             206
  MISSING_EVIDENCE:   2
```

Evidence: `scan_208_cards_worktree_2026-09-18.jsonl` (one verdict per line).

Per-check breakdown across the 208 cards:

| check_id | status | count |
|---|---|---|
| pilot_fire_count_evidence | MISSING_EVIDENCE | 200 |
| pilot_fire_count_evidence | NOT_APPLICABLE | 8 |
| cost_to_target_floor | MISSING_EVIDENCE | 201 |
| cost_to_target_floor | NOT_APPLICABLE | 7 |
| no_op_filter_lint | NOT_APPLICABLE | 208 |
| skip_reason_logging | FAIL | 206 |
| skip_reason_logging | DEFERRED_NO_BUILD_YET | 2 |

Reading this honestly: `MISSING_EVIDENCE` on checks 1-2 for ~200/208 cards is
expected and not a defect finding -- `measured_fire_count_per_window` and
`cost_floor_min_stop_units`/`cost_floor_unit_value_per_lot` are net-new
fields; no card written before this module existed could carry them.
`skip_reason_logging` FAILs for 206/208 for the same reason:
`STRATEGY_ENTRY_REJECTED` is a new event name introduced by this contract: no
EA built before it existed emits it. `no_op_filter_lint` returned
`NOT_APPLICABLE` for all 208 cards in this worktree's (stale) set -- neither
of its two rules matched any card's declared-control phrasing in this sample.
That is a sample-composition fact, not a validation of the rule: see below.

### Direct validation against the actual postmortem card (canonical
`C:/QM/repo/artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md`
+ its built EA at `framework/EAs/QM5_41477_fx-session-mean-reversion-m15/`,
read-only, no writes to that checkout)

Evidence: `qm5_41477_reference_validation_2026-09-18.json`.

- `no_op_filter_lint` -> **FAIL**: *"max_trades_per_day min=2 >= structural
  window ceiling 2 (london, ny x one entry/window): the cap is a no-op across
  its whole preregistered range"* -- this reproduces the postmortem's own
  finding verbatim ("`max_trades_per_day` (card range 2..6, default 4) is a
  silent no-op across its whole preregistered range", postmortem sec 1).
- `skip_reason_logging` -> **FAIL**: no `STRATEGY_ENTRY_REJECTED` event in the
  built EA source -- reproduces the postmortem's finding ("The logger emits
  no rejection events at all ... A reason-code census ... is therefore
  impossible from this run's evidence", postmortem sec 1).
- `pilot_fire_count_evidence` -> `MISSING_EVIDENCE` (card claims "roughly
  18-28 trades per month" derived from its own caps, exactly the anti-pattern
  postmortem sec 5.1 names; no measured field exists to check against).
  Postmortem sec 0/1: the *measured* rate was 5.69/mo, an 80% shortfall.
  Postmortem sec 5.1 is the origin of this check.
- `cost_to_target_floor` -> `MISSING_EVIDENCE` (no `cost_floor_*` fields on
  the card; postmortem sec 2 measured `commission_R` = 0.583/11.1 = 0.0525,
  above the 0.03 floor this check would enforce once the fields exist).

This is the check set working exactly as designed against the one card that
motivated it -- both mechanically-checkable findings (`no_op_filter_lint`,
`skip_reason_logging`) reproduce the postmortem's own conclusions from the
card text and EA source alone, without needing the postmortem's own trade-log
analysis.

## No retroactive action taken

No card frontmatter was edited. No card was moved, rejected, or requeued. No
gate threshold changed. This is exclusively a new, inactive, additive tool
plus this report. Follow-up (not done here, and each requires its own
sign-off per the standing authorization's GELB/ROT split):

- Full 258-card scan against canonical `C:/QM/repo/artifacts/cards_approved`
  (this worktree only has 208; the missing 50 include several other
  session/window cards from the same 2026-09 research batch worth checking
  against `no_op_filter_lint`).
- Recording an independent (non-`claude`) critique to activate the contract.
- Wiring the four checks into `farmctl.approve_card` /
  `ready_strategy_card_inventory` as blocking, once active -- ROT-zone
  (touches gate/contract criteria), needs explicit OWNER sign-off, not
  autonomous.
- Adding `STRATEGY_ENTRY_REJECTED` emission to the shared entry-signal
  scaffolding so new EAs get it by construction rather than per-EA
  retrofitting.
