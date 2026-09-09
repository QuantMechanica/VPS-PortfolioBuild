# FTMO admission compatibility and bounded dry-run planner

Task 83ffadd6-24bc-4dd3-afa0-2843269b1ad9. REVIEW; no candidate promoted or enqueued.

The reader's existing active/historical phase repair is correct for this intake:
latest completed evidence across Q09_NEWS and active Q10_NEWS wins, including a
newer refusal. The new change makes seed coverage explicitly version-bound.
V2 still requires five native seeds. V3 requires only native seed 17 and the exact
authenticated `seed_provenance` declaring inert fanout to the five selector seeds.
This matches q09_news_contract.py; duplicating its one native observation for
selection cannot create five native executions. Unsupported adjudication schemas
and contradictory V3 seed provenance now fail authentication. Economic thresholds
and target coverage requirements are unchanged. A DXZ 7x1 lock remains ineligible.

36 tests passed: version equivalence, V3 expanded coverage and missing cell,
V2 single-seed refusal, unknown version, tampered aggregate, phase coexistence,
latest-result precedence, existing qualification, roster cap and exact-identity
request deduplication. The real intake is identical before/after: **12 scope-not-FTMO,
3 evidence-missing, 1 not-config-locked, 0 admitted**. See `verification.json`.
The occurrence view is used for current per-work-item evidence; reading the base
cell table alone would lose rerun occurrences. No seed rows or verdicts were written.

`tools/strategy_farm/portfolio/ftmo_acceleration_plan.py` opens the database read-only
in one read transaction. `plan.json` contains every pair's current source, binary,
baseline setfile and existing closure hashes, historical news identities, seed
counts, admission reason and target test cost. It hashes and checks the current
scoped calendar activation's manifest, declarations and both source CSVs. This
proves those bytes, not full target/calendar admissibility or row release.

Every one of the 16 existing include closures fails validation against the current
tree. 10700's closure has an EX5 mismatch; the others report source inventory/hash
mismatch. The 13 pairs with news identity have matching historical/current EX5
hashes, but that does not prove current source/include compatibility. The planner
keeps these dimensions separate from news admission, costs and deployment.

The calendar activation remains scoped and OWNER_ROW_BY_ROW. An USD-only scope
cannot silently qualify EURUSD, GBPUSD or USDCAD, and even an USD-only instrument
needs its exact window and release proof. Neither an old calendar bundle nor a
new source CSV is silently substituted into historical evidence. No calendar
repair, seed inflation or obsolete matrix rerun was started.

The current cost roster selects zero pairs; therefore the planner emits zero
requests and zero native runs. It validates at most five distinct intake keys and
refuses requested keys outside that roster. Exact repeated prospective bindings
deduplicate; a changed binary, calendar, window or target creates a different
request identity. This request-level deduplication does not claim reusable native
evidence from similar historical rows. Full native evidence reuse is blocked here
by current-closure and prospective-plan gaps.

For a future selected pair, the current narrow FTMO V3 target costs eight native
configurations (one CONTROL_OFF plus seven FTMO policy configurations), each with
two windows: **16 native runs before reuse**, at most 80 for five pairs. Runtime
seconds remain unknown. Expansion to 29 configurations is not assumed or queued.
The planner records prerequisites and binds prospective windows as unsealed/null;
it cannot emit an executable native plan until those prerequisites are closed.
It exposes no apply option and has no database writer.

Reproduce:

```powershell
python C:/QM/repo/tools/strategy_farm/portfolio/ftmo_acceleration_plan.py --output C:/QM/repo/docs/ops/evidence/2026-09-09_ftmo_admission/plan.json
python -m pytest -q tools/strategy_farm/tests/test_ftmo_q09_admission.py tools/strategy_farm/tests/test_ftmo_admission_v3.py tools/strategy_farm/tests/test_ftmo_qualification.py tools/strategy_farm/tests/test_ftmo_acceleration_plan.py
```

Next executable preparation after an accepted nonempty roster: issue current
compile/include closure and execution identity; seal the prospective selection/
holdout windows and calendar scope; feed those exact paths to canonical
q09_news_runner.py `plan --deployment-target FTMO --contract-version q09-news-evidence/v3`.
The existing planner requires Q08 evidence, set, EX5, closure, calendar manifest,
time windows, tester model and cost profile explicitly. Run it only after those
prerequisites and holdout authorization are satisfied, then use normal factory
claims. No old result is inherited across changed trading code, no holdout metrics
were queried here, and the regular 25-pair builder prerequisite remains intact.
