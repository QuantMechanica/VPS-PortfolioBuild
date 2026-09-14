# NEWS_CALENDAR_CONTRACT_V2 section 6 — `known_at_utc` implementation

Claude task `01870d4c-8fec-43f2-a315-f678523253c7` (BOOK SPRINT, cutover Sun 2026-09-20),
closing LIFT_CONDITIONS[1] item (1) named in
`decisions/2026-09-14_owner_risk_freeze_lift.md` and
`docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md` §6.

## What changed

- `tools/strategy_farm/config/news_impact_mapping.v1.json`: new `known_at_utc_policy`
  block (`policy_id qm.news_impact_mapping.known_at_utc.conservative_backfill.v1`),
  `default_lead_hours: 24`, per-label `lead_hours` (currently uniform 24h across
  high/medium/low/holiday — documented reasoning inline: no differentiated
  upstream-publication-timestamp evidence exists for the historical seed calendars, so a
  per-label split would be invented, not derived).
- `tools/strategy_farm/news_impact_mapping.py`:
  - `known_at_utc_lead_hours()` / `known_at_utc_for()` — the formula
    `known_at_utc = timestamp_utc - lead_hours[impact_label]`.
  - `load_rules()` now requires `known_at_utc_policy` and fails closed if
    `default_lead_hours` or any `lead_hours` entry is not a positive number (a 0 would
    silently collapse `known_at_utc` to `timestamp_utc`, exactly what section 6 forbids).
  - `MappedEvent` gained `known_at_utc` and `known_at_utc_lead_hours` fields, populated in
    `map_rows()` for every row (including collapsed/conflict-resolved rows — the winner's
    own label's lead time applies).
  - `schedule_view()` (the section 5 gate-facing projection) now carries `known_at_utc`
    on every row.
  - `run_self_report()` (section 7) gained `known_at_utc_policy_id`,
    `known_at_utc_present_count`, `known_at_utc_coverage_pct` — coverage is *measured*
    (counted from actual rows), not assumed, so a future code path that skips the field
    is caught here.
- `docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md` §6: append-only implementation-status
  note (the original normative text is unchanged).
- `tools/strategy_farm/tests/test_news_impact_mapping.py`: new `KnownAtUtcTests` class (7
  tests) + updated `DeterminismTests.test_schedule_view_never_exposes_lookahead_fields`
  (asserts `known_at_utc` is present, `actual`/`forecast`/`previous` still absent) +
  updated `SelfReportTests` (`REQUIRED` fields, new coverage test).

## Flag-gating

No new gate was added inside `news_impact_mapping.py`. The module was already
fully opt-in (`OptInRequired` unless `opt_in=True` + a named `consumer`), and every real
caller (`q09_news_runner._news_contract_v2_declaration()`, `news_calendar_gate.py`) only
reaches this module after checking `nim.v2_enabled()` /
`news_contract_v2_enabled()` (`QM_NEWS_IMPACT_MAPPING_V2=1`) itself. Adding fields inside
the already-gated module therefore inherits "flag off = byte-identical" for free — no
caller reaches the new code unless it was already reaching the V2 path.

## Test evidence

```
QM_NEWS_IMPACT_MAPPING_V2= python -m pytest tools/strategy_farm/tests/test_news_impact_mapping.py -q
47 passed, 2 subtests passed

QM_NEWS_IMPACT_MAPPING_V2= python -m pytest tools/strategy_farm/tests/test_news_contract_v2_cutover.py -q
23 passed

QM_NEWS_IMPACT_MAPPING_V2= python -m pytest tools/strategy_farm/tests/ -k news -q
565 passed, 9408 deselected, 2 subtests passed, 4 failed
```

The 4 failures (`test_q09_live_news_diagnostic.py`,
`test_qm5_12954_pring_coppock_static.py`, `test_qm5_20160_review_rework_static.py`,
`test_qm5_9353_rework_static.py`) are pre-existing, unrelated EA-setfile build-hash /
`qm_news_temporal` binding-drift failures — static assertions against specific `.set`
files and compiled `.ex5` hashes for unrelated EAs, consistent with `farmctl health`'s
independently-reported `pending_artifact_binding_drift` FAIL (81 mismatched bindings
across 42 pending rows, ambient factory state at the time of this run, not touched by
this change). None of the four import or exercise `news_impact_mapping.py`.

**Note on the local shell environment**: this VPS shell currently carries
`QM_NEWS_IMPACT_MAPPING_V2=1` machine-wide (set by the `reload_chunk76..84` idle-worker
reload wave, 2026-09-13). Without explicitly clearing it, 3 unrelated pre-existing
cutover tests fail (`test_real_environment_is_off_in_this_repo`,
`test_flag_off_payload_is_byte_identical`, `test_flag_off_keeps_the_pre_v2_marker`) —
this is environment leakage in the test *runner's* shell, not a code defect; those tests
assert against `os.environ` directly and would fail identically with this change fully
reverted. All commands above were run with the flag explicitly cleared to get a clean
signal.

## Acceptance checklist

- [x] `known_at_utc` present on every row of the scoped consumer output
      (`MappedEvent` + `schedule_view()`), documented provenance rule (this file +
      contract §6 addendum + `known_at_utc_policy` in the rules artifact).
- [x] Run self-report includes `known_at_utc` coverage.
- [x] Tests green (new + existing news tests, flag cleared).
- [x] Flag off = byte-identical behaviour (structural: unreachable without opt-in +
      `v2_enabled()`; confirmed by the passing cutover-test suite).
- [x] No live EA / T_Live change (DL-080 unaffected; this module is explicitly
      `live_path_forbidden` and was already never wired into the live path).
