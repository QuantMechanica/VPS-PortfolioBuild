# Slice c3_research_guard_author — implementation report

**Date:** 2026-09-15 · **Authority:** OWNER master directive 2026-09-15 (continuous book
evolution), OWNER-DEC-CBE-20260915 · directive §34, §36, §37, §70.
**Audits consumed:** `audit/research_disk_guard.md`, `audit/rule_inventory_code.md` (F8),
contract `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`.

## What changed

### (1) Evidence-based research resource guard (directive §34; audit research_disk_guard.md)
`tools/strategy_farm/research/research_env.py`: replaced the flat `D: < 80 GB` block (which
permanently disabled research, since the tester-cache purge parks D: at its 60 GB low-water) with a
measured guard:
- watches the **research scratch volume** (default the C: dataset-output location
  `C:\QM\repo\artifacts\research_datasets`; `QM_RESEARCH_SCRATCH` override) with floor
  `RESEARCH_DISK_MIN_FREE_GB = 20.0` (`QM_RESEARCH_MIN_FREE_GB` override) — derived from the
  measured research need (~0.3 GB venv + few-MB CSV output → `max(need×2, 20 GB)`);
- adds a **factory-protection floor**: D: free must stay above the tester-cache-purge low-water
  (60 GB) **only when the scratch root is on D:** (`QM_FACTORY_MIN_FREE_GB` override);
- the 60 GB value is read from a new **shared config** `config/factory_disk_policy.v1.json` (not
  hardcoded twice); `tester_cache_purge.ps1` default aligned 150→60 to match the live task + config
  (audit R3);
- **fail-closed**: an unmeasurable/unknown volume refuses (`DISK_UNMEASURED` /
  `FACTORY_DISK_UNMEASURED`); disk measurement is a local fail-closed helper (returns None on
  error), distinct from `terminal_worker._disk_free_gb` which fails open for workers;
- CPU / RAM / mutation-lock latches unchanged; venv NOT moved (orchestrator decides relocation).
- Live guard now returns `allowed: true` (scratch on C:, 74.5 GB free) — previously
  `allowed:false … DISK_LOW:61.2GB<80.0GB` on every call.

### (2) Internal-source author generalization (directive §36, §37; audit F8)
- `tools/strategy_farm/config/research_source.v1.json` (new): authorized author set
  `[Kimi, Fable, Claude, Codex, Antigravity]` + `multi_agent_prefix: "multi-agent:"`; OWNER-tunable,
  env override `QM_RESEARCH_AUTHORIZED_AUTHORS`.
- `tools/strategy_farm/research_source.py`: added `load_authorized_authors()`,
  `is_authorized_author()`, reason `UNAUTHORIZED_AUTHOR`, and a fail-closed author check in
  `verify()` (present-but-unauthorized `research.json.author` → refuse). Everything else identical:
  durable artifact, `sha256(source.md)`, manifest, mint/resolve/verify/seal, non-Kimi critic
  invariant, `INTERNAL_SOURCE_UNRESOLVED`. `verify(source_config_path=...)` seam + CLI
  `--source-config`. The prescreen (`card_intake_prescreen._internal_source_reason`) and farmctl
  (`_internal_research_source_error`) both delegate to `verify`, so the check flows through both
  intake surfaces with no other edit; no hardcoded `source_author == 'Kimi'` existed to remove.
- Docs: `INTERNAL_RESEARCH_SOURCE_CONTRACT.md` header + `source_author` row updated, Annex
  2026-09-15b appended (author generalization + guard recalibration; SUPERSEDED markers on the
  old Kimi-only / 80 GB wording). `processes/qb_reputable_source_criteria.md` R1 annex:
  "Kimi-authored" → "internally authored by an authorized research agent".

## Contracts changed (directive §70 regression list)
- **"Fable/internal author provenance works"** — `verify()` accepts any authorized author +
  multi-agent collaborations; regression-tested.
- **"Kimi internal source remains fail-closed"** — unchanged fail-closed paths preserved; new
  `UNAUTHORIZED_AUTHOR` tightens (unauthorized authors now refuse); regression-tested.
- Research resource guard threshold constants (class A/D per rule_inventory_code F8; not a gate
  criterion / verdict — no ROT boundary touched).

## Tests added + result
New: `tools/strategy_farm/tests/test_research_env_guard.py` (12 tests: C:/D: floor matrix, env
overrides, unknown-volume fail-closed, shared-config wiring, layering invariant).
Extended: `test_research_source.py` (+8: Fable/multi-agent pass, unauthorized fail, author-without-
artifact fail, config override, helper unit tests), `test_card_r1_internal_source.py` (+2: Fable
card KEEP, unauthorized card REJECT through prescreen + farmctl guard), and updated the stale
`test_research_observe_projector.py` 80→20 floor assertion.

```
56 passed, 1 warning in 4.49s
```
(command: `python -X utf8 -m pytest tools/strategy_farm/tests/test_research_env_guard.py
tools/strategy_farm/tests/test_research_observe_projector.py
tools/strategy_farm/tests/test_research_source.py
tools/strategy_farm/tests/test_card_r1_internal_source.py -q`; the 1 warning is a pre-existing
`\T` escape in farmctl.py, unrelated.)

## Rollback
- Guard: revert `research_env.py` + delete `config/factory_disk_policy.v1.json`; or set env
  `QM_RESEARCH_SCRATCH=D:/…` and `QM_RESEARCH_MIN_FREE_GB=80` to restore the old D: posture without
  a code change. `tester_cache_purge.ps1` default: revert the one-line `[int]$LowWaterGB` change
  (the live scheduled task passes `-LowWaterGB 60` explicitly, so factory behavior is unchanged
  either way).
- Author: revert `research_source.py` + delete `config/research_source.v1.json`; or widen
  `QM_RESEARCH_AUTHORIZED_AUTHORS`. Doc annexes are append-only and can be struck without code impact.

## Not done / could not do
- Did NOT relocate the venv or any data (out of scope; orchestrator decides — see notes).
- The 60 GB low-water is now single-sourced for the Python guard via the shared config; the
  PowerShell purge default was aligned to 60 but still declares its own default literal (PowerShell
  does not parse the JSON) — the live scheduled task remains the runtime authority.
