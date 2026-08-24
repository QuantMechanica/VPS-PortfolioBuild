# Review — Risk-Freeze fail-closed prevention wiring (task 6e512650)

Date: 2026-08-24
Reviewer: Claude (review lane)
Router task: `6e512650-a3e6-4563-8b62-7a9e31f04df7` (ops_issue, codex)
Worker artifact: `docs/ops/evidence/2026-08-23_live_risk_freeze_prevention.md`
Worker verdict: `PASS_REVIEW: fail-closed live-book guards wired; MC visible; tests pass`
Authority: `decisions/2026-08-22_owner_dec_risk_freeze_executed.md`

## Verdict: APPROVED

Prevention is genuinely wired at every live-book control point off the single
canonical `risk_freeze.assert_live_book_mutation_allowed()`; no second freeze
semantic. All six acceptance criteria met and independently verified read-only.

## What I verified (evidence)

Canonical guard, fail-closed by construction:
- `tools/strategy_farm/risk_freeze.py:387` `assert_live_book_mutation_allowed`
  refuses on ACTIVE, missing (`:221` NO_FREEZE_STATE), unreadable (`:236`
  STATE_UNREADABLE), wrong schema (`:252`), incomplete baseline (`:285`,`:305`),
  unknown status; an INACTIVE/LIFTED record passes only with both
  `lift_authority`/`lifted_by` and `lifted_at_utc` (`:405`). Absence never = permission.

Guard call sites (grep, all present, all before mutation):
- `portfolio/stage_tlive_presets_risk.py:71` — under `--apply`, before manifest read.
- `portfolio/build_11422_preset_FINAL24b.py:53`
- `portfolio/portfolio_manifest.py:408`
- `portfolio/build_book_dxz.py:279`
- legacy generators `gen_dxz_23sleeve_manifest.py:7`, `gen_dxz24_weekend_manifest.py:24`,
  `gen_dxz_final_manifest.py:32`, `gen_dxz23_20260726.py:96`, `gen_dxz24b_20260726.py:119`
- `generate_live_deployment_pointer.py:216` — `--signed` path.
- `reseal_chart09_ks_delta.py:66`
- `deploy_tlive_book.py:121` — guard param, called `execute():130` deliberately before
  plan read, directory creation, backup, or temp write.
- `prepare_dxz_v2_liveops_profile.ps1:72-78` — shells `risk_freeze.py guard`, exit!=0 aborts;
  `-VerifyOnly` intentionally read-only.

Non-frozen boundary confirmed: no `risk_freeze` import in `farmctl.py`,
`terminal_worker.py`, `compile_ea.py`, `agent_router.py` (grep -l → none).

Mission Control: `mission_control_v2_data.py:1052` `build_risk_freeze()` consumes
`diff_against_baseline()` read-only, emitted at `:1122`; cockpit v2 renders the panel.

Tests (rerun by me, read-only):
- focused suite (5 files): **65 passed, 2 skipped** — refusal + allow paths per guard,
  missing/unreadable/invalid state, three condition IDs in ACTIVE error, OWNER-lift
  positive fixture, dry-run read-only, static coverage of legacy generators + PS profile.
- Live guard: `risk_freeze.py guard` exits **3** (refuses, prints lift rule + 3 conditions).
- `risk_freeze.py verify`: status=ACTIVE, baseline 9.7499 = current 9.7499, 24→24 sleeves.

Live state untouched: `D:/QM/reports/state/live_risk_freeze.json` intact, ACTIVE.
No T_Live/AutoTrading action; review was read-only.

## Observation (not a defect of this task) — surface to OWNER

Live `verify` now reports **held=false** with `preset_sha256` drift on ~10 of 24
sleeves (e.g. `04_XTIUSD_H4_...`, `14_NDX_H1_...`, `23_XNGUSD_D1_...`), while total
RISK_PERCENT (9.7499) and sleeve count (24) are unchanged. This is the DETECTION
layer working as designed — the guard refuses fail-closed on ACTIVE regardless of
held, so prevention is unaffected. But the deployed presets have diverged from the
armed baseline: either a legitimate content change post-arming or an unauthorized
edit. Recommend a separate diagnosis ticket (out of scope for this review) to
reconcile the drifted preset SHAs against provenance before any lift is considered.

## Line-number note
A few artifact line refs drifted slightly vs current source (e.g. build_book_dxz
276→279, MC emitter 912→1052) — cosmetic; guards are present and functional.
