# Gate taxonomy single-source — Codex review R1 and implementation evidence

Date: 2026-07-31  
Router task: `3b74aa48-372c-48a6-8565-0a2b3d2c2094`  
Topic: A  
Reviewer: Codex  
Agreement: **92%**  
Verdict: **ACCEPTED WITH AMENDMENT; IMPLEMENTED; CLAUDE REVIEW REQUIRED**

## Adversarial findings

1. The central diagnosis was correct. `render_cockpit.py` contained a stale,
   local display map and a second stale Q-to-P pairing, omitted Q00, and could
   emit labels inconsistent with `strategies.html`. The registry adapter also
   contained Q14 and the retired offset display scheme.
2. The proposed `farmctl.PHASE_NOMENCLATURE` derivation required an amendment.
   The three call sites are runner/verdict compatibility logic, not display or
   storage writes:
   - `farmctl.py:3635` selects historical runner-verdict branches;
   - `farmctl.py:3855` classifies the historical P5+ metric band;
   - `farmctl.py:5081` locates retired runner input artifacts.
   Replacing that map with collapsed manifest aliases would change gate logic
   (for example Q04/P3.5 and Q08/P5c), contradicting the no-gate-logic scope.
   The implementation therefore preserves and explicitly documents that map as
   runner compatibility, while removing the invalid Q14 entry
   (`farmctl.py:3326-3357`). No call site writes a DB key or public snapshot.
3. A single primary inverse alias is insufficient for display-side UNION reads
   because Q03, Q05, and Q08 each have multiple legacy aliases. The accepted
   amendment exposes the complete inverse alias tuple and retains a documented
   first-alias compatibility view only for callers that truly need one path.
4. Manifest aliases are normalized uppercase by the strict loader, while old
   storage and prose can contain `P5b`, `P5c`, and `P9b`. Display helpers and
   SQL UNION reads therefore normalize case; this prevents a new mixed-case
   regression.
5. A scoped consumer grep across `framework/` and `tools/` found no runtime
   reader of `framework/registry/state_name_adapter.json`; all matches outside
   the JSON were unrelated local `display_phase` helpers. The registry is
   display-side, so aligning its embedded display values cannot rewrite
   storage.

## Implementation

Implementation commit: `e4d31aed3` (`fix(ops): single-source gate display taxonomy`)

- `tools/strategy_farm/phase_ids.py:45-70` loads the validated versioned
  manifest exactly once at import and derives phase order, names, legacy
  aliases, the complete inverse, and the documented primary inverse. There is
  no per-call JSON parsing.
- `tools/strategy_farm/render_cockpit.py:46-51,2330-2465` imports the shared
  taxonomy, removes all local display maps, reads canonical plus all declared
  aliases, includes Q00, and uses `phase_label()` for operator output.
- `tools/strategy_farm/dashboards/render_dashboards.py` now applies the same
  helper case-insensitively to stored phase keys and free-text legacy tokens.
- `framework/registry/state_name_adapter.json:55-152,244-265` is aligned to
  the collapsed Q00-Q13 manifest; Q14 is absent.
- `tools/strategy_farm/tests/test_gate_manifest.py:29-128` binds `phase_ids`,
  both renderers, and the state-name adapter to the manifest contract and tests
  mixed-case historical keys.

No DB schema, work-item state, task state, gate verdict, Factory state, terminal,
T_Live, or AutoTrading setting was changed by this implementation.

## Focused verification

### Tests

Command:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_gate_manifest.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
  tools/strategy_farm/tests/test_dashboard_pipeline_books_programme.py \
  tools/strategy_farm/tests/test_quota_window_consumers.py \
  tools/strategy_farm/tests/test_render_cockpit_pipeline_books.py
```

Result: **40 passed in 2.20s**.

The Q09 integration test explicitly retained the runner-compatibility behavior
(`_normalize_phase("Q09") == "P6"`), while the new display tests bind every
manifest alias to the same Q-only label in both renderers.

### Read-only render smoke

Commands:

```text
python tools/strategy_farm/render_cockpit.py
python tools/strategy_farm/dashboards/render_dashboards.py --strategies-only
```

Results:

- `D:/QM/strategy_farm/dashboards/cockpit.html` written successfully.
- `D:/QM/strategy_farm/dashboards/strategies.html` written successfully.
- `Q00` occurs in both rendered files.
- `Q14` occurs in neither rendered file (`rg` no-match).
- The cockpit progress strip renders exactly Q00 through Q13; Q00 shows the
  3,166-card intake count at observation time.
- Cockpit DB access is SQLite `mode=ro` plus `PRAGMA query_only=ON`;
  `--strategies-only` explicitly skips the dashboard metrics refresh.

### Count-invariance proof

A read-only query compared the former local phase unions with the new
manifest-derived unions over current PASS rows. Counts were identical for every
displayed automated phase:

| Phase | old local map | manifest map | delta |
|---|---:|---:|---:|
| Q02 | 5,923 | 5,923 | 0 |
| Q03 | 1,532 | 1,532 | 0 |
| Q04 | 261 | 261 | 0 |
| Q05 | 240 | 240 | 0 |
| Q06 | 227 | 227 | 0 |
| Q07 | 168 | 168 | 0 |
| Q08 | 16 | 16 | 0 |
| Q09 | 0 | 0 | 0 |
| Q10 | 34 | 34 | 0 |

This satisfies the no-counter-drift condition while making any future legacy
row display follow the canonical manifest.

## Handoff

The change is intentionally left for Claude's post-implementation review. It
must not be self-approved or promoted on the strength of this document alone.
