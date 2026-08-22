# SP-A1 — Authenticated runtime deploy-pointer generator

Task: `agent_router` task `105cb532-20bc-49ca-b952-dc78633daf6b` (SP-A1, priority 94,
zone GELB, Schienenplan 2026-08-22).

## What was built

`tools/strategy_farm/generate_live_deployment_pointer.py` — a generator that computes,
fresh from disk every run, the fields `morning_brief.py`'s `_authenticate_deploy_stamp`
and `verify_live_deployment_contract.py` consume from the RUNTIME pointer at
`D:\QM\reports\state\live_deployment_pointer.json` (see the resolution order documented
in `tools/strategy_farm/config/live_deployment.json`: direct override → runtime
deploy-stamp → repo default → UNKNOWN).

Computed fields (never invented, never carried over from a prior run):
- `manifest_sha256` — SHA-256 of the manifest file bytes, recomputed every run.
- `expected_sleeves` — `{count, identity_sha256, roster}`: a deterministic fingerprint
  of `(ea_id, symbol, magic_number)` triples, sorted by magic so roster reordering in
  the manifest file cannot change the hash. Any membership/count drift changes it.
- `binary_setfile_fingerprint` — per-sleeve deployed `.ex5` SHA-256 (resolved from the
  manifest's own recorded absolute path, read from disk) + `set_file_expectation`,
  combined into one order-independent fingerprint. A missing binary is recorded as
  `ex5_status: MISSING`, never silently skipped.

Required, non-defaulted CLI args (fail-closed — the tool raises rather than guesses):
`--manifest`, `--deployment-epoch-utc`, `--written-at-utc`. `--expected-account`
derives from the manifest's `book` field digits unless overridden; the tool exits
non-zero if neither source yields a value.

## Signing is explicitly out of scope for an AI seat

Per the task's own hard_constraints ("Aktivierung/Signatur des Pointers = OWNER/ROT,
kein AI-Seat mintet Live-Bindung") and the CLAUDE.md T_Live Hard Rule, this run wrote
the pointer with **`signed: false`**. `--signed` requires both `--approved-by` and
`--approval-evidence` (a path to the OWNER approval record); the tool refuses to set
`signed: true` without both. No AI-seat invocation in this cycle passed those flags.

Promoting the pointer to `signed: true` is a separate, human-gated action: OWNER (or
Claude acting on record of an explicit, dated, written OWNER approval — never as a
default) re-runs the same tool with `--signed --approved-by "..." --approval-evidence
<path>`, pointing `--approval-evidence` at the decision record backing the manifest
(the 24-sleeve book's approval is already recorded in the manifest's own
`approved_by` field and in `decisions/2026-07-24_owner_approvals_audit_package.md`).

## Run performed this cycle

```
python tools/strategy_farm/generate_live_deployment_pointer.py \
  --manifest "D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json" \
  --deployment-epoch-utc "2026-07-24T06:42:00+00:00" \
  --written-at-utc "2026-08-22T10:06:38Z" \
  --expected-server "Darwinex-Live" \
  --expected-phase "DXZ_LIVE" \
  --out "D:\QM\reports\state\live_deployment_pointer.json"
```

- `deployment_epoch_utc` = the live manifest's own `generated_at` (2026-07-24T06:42:00Z)
  — the only evidence-backed timestamp available for when this book's manifest was
  finalized; no separate "went live" timestamp exists in the manifest or elsewhere, so
  this is documented as the epoch source rather than inventing a different one.
- `expected_server` = `Darwinex-Live`, read directly (read-only) from
  `C:\QM\mt5\T_Live\MT5_Base\config\common.ini`, whose `Login=4000090541` matches the
  manifest's `book` field digits (`DXZ_4000090541`) exactly — cross-checked, not
  assumed.
- `expected_phase` = `DXZ_LIVE`, matching the convention already encoded in
  `tools/strategy_farm/tests/test_morning_brief_live_status.py`.
- Result: `D:\QM\reports\state\live_deployment_pointer.json` written atomically,
  `signed: false`, `expected_sleeves.count: 24`, `binary_setfile_fingerprint`:
  24/24 sleeves resolved `ex5_status: OK` (0 missing binaries).

## Verification

- `python -m pytest tools/strategy_farm/tests/test_morning_brief_live_status.py -q`
  → 64 passed. The new pointer's extra fields do not break `morning_brief.py`'s
  `stamp.get(...)`-only reads.
- Effect on the Deploy lamp: unchanged class (GELB) — before this run there was no
  runtime pointer at all and `morning_brief` fell back to the unauthenticated repo
  default (`config/live_deployment.json`, itself `signed: false`, GELB-by-design).
  The runtime pointer now exists with real, freshly-computed manifest/binary evidence
  instead of an absent file, but stays `signed: false`/GELB until OWNER performs the
  signing step above — no false GREEN was introduced.

## Depends on this (SP-A2)

SP-A2 ("Deploy-Consumer binden + Live-Burn-in reparieren") depends on this pointer
existing and is handled next in this cycle.
