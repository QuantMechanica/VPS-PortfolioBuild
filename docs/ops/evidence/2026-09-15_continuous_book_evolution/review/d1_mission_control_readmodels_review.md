# Adversarial review — slice `d1_mission_control_readmodels`

Reviewer: Claude (adversarial). Date: 2026-09-15.
Directive: OWNER-DEC-CBE-20260915 §3, §60, §62, §72.
Patch: `…/scratchpad/patches_defg/d1_mission_control_readmodels.patch`
Repo HEAD at review: `4ad7ab7016a77f25323b95912573eafbb21c5e69` (branch `agents/board-advisor`).

## Verdict: ACCEPT_WITH_FIXES

No blocking items. The patch is clean, safe, deterministic and honest. Two MAJOR
items are follow-ups that the ORCHESTRATOR must execute on/after apply (they are
correctly out of a worktree slice's mutation scope) — without them the Factory
section and the Heartbeat health keys stay EVIDENCE_MISSING on live and the
cockpit abort persists.

## Verification performed (own commands)

- **`git apply --check` against HEAD** → exit 0. Applies clean; no conflicts.
- **Tests** (run in the implementer worktree `wf_4fa62b18-d2d-1`):
  `pytest test_factory_bottleneck_readmodel.py test_mission_control_v2_data.py
  test_render_cockpit_v2.py -q` → **58 passed, 1 failed**, matching the
  implementer summary exactly.
  - The single failure `test_full_contract_is_schema_valid` is a **pre-existing
    worktree CRLF seal drift**, not a slice defect. Verified: canonical
    `C:/QM/repo/decisions/2026-08-27_owner_count_definition_option_a.md`
    sha256 = `d47501ca…` (matches the pin in `path_to_25.py`, LF); the worktree
    copy is CRLF, sha256 = `2df61c55…` → seal mismatch raised in
    `path_to_25._counting_definition`. The failure fires **upstream** in
    `operator_surfaces.build_operator_snapshot`, before any book-evolution code
    is reached, so it is unrelated to this slice. On canonical (LF) the full
    suite passes. The slice's own new test that exercises `build_contract`
    (`test_contract_carries_book_evolution_keys_and_validates`) stubs the
    operator snapshot and passes.
- **`py_compile`** on the three code files → OK.
- **Runtime artifact `render_out/factory_bottleneck.json`** — opened and checked
  against live: `active=3, idle_in_drain=7, claimable_pending=743`, top bottleneck
  `unwinnable_reservation_head_of_line_block` (reservation 44.0 GB, ea QM5_1069).
  Matches the live claim-starvation head-of-line incident in the audit. Resources
  real (`cpu 84.9, ram_free 25.5, d_free 77.5 GB`). No invented numbers;
  `degraded_reasons: []`.
- **Idle-in-drain signal honesty** — inspected a real
  `D:/QM/strategy_farm/logs/terminal_worker_T1.log` `claim_result` record: keys
  include `stage_event="claim_result"`, `reason="no_pending_claimable"`,
  `skips.ram_class_skipped` / `skips.longrun_cap_skipped`. The detector reads
  exactly these fields → the signal is computed from real logs, not fabricated.
- **Live render `render_out/cockpit_v2_live.html`** — grep: 0× "Weg zu 25",
  0× "/25", 0× "ETA zu 25"; 11× `EVIDENCE_MISSING`; `Book Evolution` and
  `FTMO Challenge Readiness` both present. Confirms §70 and §60/§62.
- **0x800710E0 diagnosis** — verified against the live task:
  `MultipleInstances=IgnoreNew`, `LastResult=0x800710E0`,
  `Repetition.Interval=PT1M`. Diagnosis is accurate (per-minute re-fire under
  IgnoreNew refuses overlapping renders). The PT1M→PT5M fix is documented, not
  applied — correct for a worktree slice.
- **No live-state pollution** — `D:/QM/reports/state/factory_bottleneck.json` and
  `book_evolution_health.json` do NOT exist on live; the implementer wrote only to
  scratch `render_out/`. HTML rendered to scratch, not the production cockpit.

## RED / safety scan — clean

- **Farm DB**: opened `?mode=ro` + `PRAGMA query_only=ON`; the only
  `INSERT/CREATE TABLE/commit` are inside the pytest fixtures on a `tmp_path` DB.
  No write to the real DB.
- **No** T_Live / AutoTrading / FTMO purchase / live-deployment / gate-threshold /
  qualification-weakening / verdict-rewrite touches. `path_to_25` kept intact
  (now diagnostic only); no gate manifest, no qualification logic changed.
- **No secrets** (the "tokens" hits are CSS var tokens in prose).
- New module writes only under `D:/QM/reports/state/` via an atomic temp-rename.

## Schema adherence — respected

- Written `factory_bottleneck.json` conforms to `qm.factory-bottleneck/v1`:
  `generated_at_utc`, `frontier{…}`, `bottlenecks[{rank,name,evidence,cost}]`,
  `terminals{active,idle_in_drain,claimable_pending}`, `resources{cpu_pct,
  ram_free_gb,d_free_gb}`, `infra_problems[]`. Extra keys (`severity`,
  `idle_terminals`, `logs_scanned`, `drain_window`, `degraded_reasons`) are
  additive. §72 required signal "idle in drain_predrain vs claimable pending" and
  top-3 bottlenecks are present.
- Consumed read-models (`book_evolution_dxz/ftmo`, `ftmo_challenge_readiness`,
  `research_state`) are bound verbatim, EVIDENCE_MISSING-tolerant; test fixtures
  match the documented schemas including the recommendation enums (incl.
  `BUY_100K_2STEP_RECOMMENDED`) and proposal outcome enum. New MC contract keys
  are optional/permissive (not in `required`) → validation stays green pre-E1/F1/G1.
- English code comments; dated supersession markers (`OWNER-DEC-CBE-20260915`)
  throughout. German UI strings match the existing cockpit de-DE convention.

## Findings

### MAJOR (follow-up — orchestrator, on/after apply)

1. **Scheduled-task changes not applied (by design).** (a) `QM_StrategyFarm_
   Cockpit_2min` `PT1M→PT5M` to clear the 0x800710E0 overlap abort; (b) wiring
   `factory_bottleneck_readmodel.py build` into a 15-min refresh task
   (fold into `QM_StrategyFarm_PipelineState` or new
   `QM_StrategyFarm_FactoryBottleneck_15min`). Until (b) runs, live
   `factory_bottleneck.json` + `book_evolution_health.json` never materialize, so
   the cockpit Factory section renders EVIDENCE_MISSING on live. Correctly
   documented; must be executed outside the worktree.

2. **Vault Heartbeat does not consume the new health keys.** Requirement (3) asks
   for the four keys in "the health JSON the cockpit AND the vault Heartbeat
   consume." Cockpit side is satisfied (keys ride the MC contract →
   `_render_book_evolution` chips). But `heartbeat_snapshot.py` consumes
   `farmctl health`, not read-model JSON, and is NOT wired to read
   `book_evolution_health.json`; the existing `health.json` (farmctl-produced) did
   not gain the keys either. The slice persists a standalone
   `book_evolution_health.json` and only documents the Heartbeat wiring.
   `heartbeat_snapshot.py` is outside the slice's owned files — reasonable to
   defer, but the requirement is only half-met until wired.

### MINOR (notes)

3. `_render_path_to_25` is retained but no longer called anywhere (intentional per
   §3 for historical availability). Dead in the render flow; acceptable, worth a
   later cleanup or an explicit `# retained: history only` at the call-less def.

4. The FTMO venue sub-block (`_render_be_venue`) does not surface the
   ftmo-specific `demo_cycle` mirror named in the `book_evolution_ftmo` schema;
   demo-cycle detail is shown in the separate FTMO Challenge Readiness block
   instead. Cosmetic completeness only.

5. Pre-existing worktree CRLF drift on
   `decisions/2026-08-27_owner_count_definition_option_a.md` should be
   renormalized (`git checkout --` / EOL renormalize) before relying on
   `test_full_contract_is_schema_valid` in any worktree. Not this slice's defect;
   canonical is correct.

## Bottom line

The patch does what §3/§60/§62/§72 require: abolishes the "Way to 25" primary
view, installs the Book Evolution (DXZ/FTMO/Research/Factory) + FTMO Challenge
Readiness views bound verbatim from read-models with EVIDENCE_MISSING fallback,
adds a deterministic read-only `factory_bottleneck.json` producer, exposes the
health keys to the cockpit, and correctly diagnoses (without applying) the cockpit
task abort. Safe to apply on canonical (LF), where the full test suite passes. The
two MAJOR items are orchestrator follow-ups needed for end-to-end live function.
