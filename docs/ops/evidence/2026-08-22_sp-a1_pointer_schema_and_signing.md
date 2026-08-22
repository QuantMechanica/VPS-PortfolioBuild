# SP-A1 — `live_deployment_pointer.json` schema (v1) + OWNER signing procedure

Task: `agent_router` task `105cb532-20bc-49ca-b952-dc78633daf6b` (SP-A1, priority 94,
zone GELB, Schienenplan 2026-08-22). Companion to
`docs/ops/evidence/2026-08-22_sp-a1_live_deployment_pointer_generator.md` (build/run
record) and `docs/ops/evidence/2026-07-26_wse22/state_contracts_v1.md` §3 (the original
6-field deploy-stamp contract, which this doc extends — see "Delta vs. the 07-26
contract" below). This is the "Signaturschema-Doku" the task's acceptance criteria
require alongside the generated pointer.

## 1. File identity

- Path: `D:\QM\reports\state\live_deployment_pointer.json`
- `schema_version`: `"qm.live_deployment_pointer.v1"`
- Written only by `tools/strategy_farm/generate_live_deployment_pointer.py`, always via
  atomic write (`.tmp` + `os.replace`) — never hand-edited.
- Consumed by `morning_brief.py` (`_resolve_deploy_stamp` / `_authenticate_deploy`,
  `:622-723`) and `verify_live_deployment_contract.py`. Resolution order (unchanged
  from the 07-26 contract): direct override (tests) → this runtime stamp → repo default
  `tools/strategy_farm/config/live_deployment.json` (always `signed:false`) → UNKNOWN.

## 2. Field reference

| Field | Type | Meaning | Fail-closed behaviour if wrong/missing |
|---|---|---|---|
| `schema_version` | str | `qm.live_deployment_pointer.v1` | consumers should treat an unrecognized version as unauthenticated |
| `environment` | str | e.g. `T_Live/DXZ` | informational |
| `manifest_path` | str | absolute path to the deployed, signed portfolio manifest | consumer re-reads this file; absent/unreadable ⇒ UNKNOWN |
| `manifest_sha256` | hex str | SHA-256 of the manifest file bytes, **recomputed fresh every generator run** | consumer independently recomputes and compares; mismatch ⇒ **ROT** (tamper / wrong file), never silently trusted |
| `manifest_declared_status` | str | manifest's own `status` field (e.g. `LIVE`), echoed for audit | manifest status ≠ `LIVE` ⇒ GELB |
| `manifest_declared_approved_by` | str | manifest's own `approved_by` prose, echoed for audit | informational; the pointer's own `approved_by`/`signed` are the authenticating fields, not this echo |
| `deployment_epoch_utc` | ISO-8601 UTC | when this manifest went live; **required CLI arg, never defaulted** | unparseable/absent ⇒ GELB |
| `expected_account` | str | ≥6-digit account id, derived from manifest `book` digits unless overridden | manifest `book` with no bindable account (e.g. `"DXZ"`) ⇒ **UNKNOWN, never GREEN**, regardless of other fields |
| `expected_server` | str | broker server label (no default) | absent ⇒ GELB |
| `expected_phase` | str | operational phase, e.g. `DXZ_LIVE` (no default) | absent ⇒ GELB |
| `expected_sleeves.count` | int | sleeve count from the manifest | — |
| `expected_sleeves.identity_sha256` | hex str | SHA-256 over the sorted `(ea_id, symbol, magic_number)` roster — a **membership fingerprint**, independent of file row order | consumers wanting a "did the roster change" check compare this hash run-to-run; **new in this schema, not yet consumed by morning_brief.py — see §4** |
| `expected_sleeves.roster` | list | the sorted triples backing the hash above | audit trail |
| `binary_setfile_fingerprint.fingerprint_sha256` | hex str | SHA-256 over every sleeve's deployed `.ex5` SHA-256 + its `set_file_expectation`, sorted by magic | detects a stale/wrong binary deployed under a magic number without needing per-sleeve diffing |
| `binary_setfile_fingerprint.n_binary_missing` | int | count of sleeves whose `.ex5` could not be hashed | > 0 means at least one sleeve's binary is missing/unreadable on disk **right now** — this is a live infra signal, not just provenance |
| `binary_setfile_fingerprint.per_sleeve[].ex5_status` | `OK` \| `MISSING` \| `NO_PATH` | per-sleeve binary resolution outcome | `MISSING`/`NO_PATH` never silently dropped from the roster |
| `signed` | bool | **must be `true` for GREEN** | `false` (or absent) ⇒ GELB ("manifest-derived, NOT authenticated") — this is the default and correct state for anything an AI seat writes |
| `approved_by` | str \| null | non-empty approver identity/signature, required with `signed:true` | empty with `signed:true` is a generator-level usage error (raises, nothing written) |
| `approval_evidence` | str \| null | path to the OWNER approval record (e.g. a `decisions/*.md` file) backing `signed:true` | required with `signed:true`; generator verifies the path exists before writing |
| `generator.tool` / `.version` / `.task_id` | str | provenance of the tool that wrote this pointer | audit trail only |
| `written_at_utc` | ISO-8601 UTC | when this pointer file was written (caller-supplied, so the tool needs no live clock) | — |

## 3. Delta vs. the 07-26 contract (`state_contracts_v1.md` §3)

The 07-26 doc specified 6 fields (`manifest_path`, `manifest_sha256`, `signed`,
`approved_by`, `deployment_epoch_utc`, `expected_account`) plus `expected_phase`. This
schema is a **strict superset**: every field above still satisfies that contract's
GREEN/GELB/ROT/UNKNOWN rules unchanged (§3 lines 135-152 of that doc keep governing
authentication). Added on top, driven by the SP-A1 task payload:
`manifest_declared_status`, `manifest_declared_approved_by`, `expected_server`,
`expected_sleeves` (count + identity hash + roster), `binary_setfile_fingerprint`
(per-sleeve binary/setfile evidence), `approval_evidence`, `generator`, `schema_version`.
None of the new fields change existing GREEN/GELB/ROT/UNKNOWN semantics; they add
roster- and binary-drift detection that no current consumer authenticates against yet.

## 4. OWNER-authenticated signing/activation step (separately specified, per hard_constraint)

**This step is OWNER/ROT only. No AI seat performs it as a default or convenience path.**
Per the CLAUDE.md T_Live Hard Rule and the task's own hard_constraint
("Aktivierung/Signatur des Pointers = OWNER/ROT, kein AI-Seat mintet Live-Bindung"),
the generator enforces this mechanically: `--signed` requires **both**
`--approved-by` and `--approval-evidence` (a path that must exist on disk), or the
tool raises and writes nothing.

Procedure, to be carried out by OWNER (or by Claude acting on record of an explicit,
dated, written OWNER approval — never inferred or assumed):

1. OWNER reviews the **unsigned** pointer already at
   `D:\QM\reports\state\live_deployment_pointer.json` (`signed:false` today) — in
   particular `manifest_sha256`, `expected_sleeves.count`/`roster`, and
   `binary_setfile_fingerprint.n_binary_missing` (must be `0` before signing; a
   nonzero count means a sleeve's binary is not actually on disk and signing would
   authenticate a book that cannot run as claimed).
2. OWNER identifies (or writes) the approval record backing this specific manifest —
   e.g. a `decisions/*.md` file, or the manifest's own `approved_by` provenance chain
   (today: `decisions/2026-07-24_owner_approvals_audit_package.md`, countersign
   content-sha `a766b5ba…`).
3. OWNER (or Claude, holding record of the written OWNER approval) re-runs the exact
   same generator with the signing flags added:
   ```
   python tools/strategy_farm/generate_live_deployment_pointer.py \
     --manifest "D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json" \
     --deployment-epoch-utc "2026-07-24T06:42:00+00:00" \
     --written-at-utc "<ISO-8601 UTC now>" \
     --expected-server "Darwinex-Live" \
     --expected-phase "DXZ_LIVE" \
     --signed \
     --approved-by "OWNER (Fabian) <date> <channel/method>" \
     --approval-evidence "decisions/2026-07-24_owner_approvals_audit_package.md" \
     --out "D:\QM\reports\state\live_deployment_pointer.json"
   ```
4. The Deploy lamp (`morning_brief.py`) re-evaluates on next run; it only reaches GREEN
   if every §2 authentication field checks out (SHA match, bindable+matching account,
   parseable epoch, non-empty `approved_by`/`expected_phase`, manifest `status==LIVE`).
5. Record the decision under `decisions/YYYY-MM-DD_t_live_pointer_sign_<book>.md` per
   the CLAUDE.md T_Live workflow, citing the pointer's `manifest_sha256` and
   `written_at_utc` as evidence.

**Do not sign a pointer whose `manifest_path` targets a manifest other than the one
OWNER actually approved for the currently-running book.** `farmctl.py health`
(`ks_baseline_dormancy` check, 2026-08-22 run) flags several newer, unreconciled
candidate manifests (`portfolio_manifest_sunday_FINAL22/23/24b_TOTALRISK12_20260726*`,
`portfolio_manifest_sunday_24sleeve_TOTALRISK12_20260726.json`, all dated 2026-07-26,
newer than the configured 2026-07-24 manifest) — reconciling which manifest T_Live
actually runs is a prerequisite decision, not something this tool resolves.

## 5. Evidence

- Generator: `tools/strategy_farm/generate_live_deployment_pointer.py` (committed
  `bf2212920`).
- Pointer file: `D:\QM\reports\state\live_deployment_pointer.json`, `signed:false`,
  `written_at_utc: 2026-08-22T10:06:38Z`, `expected_sleeves.count: 24`,
  `binary_setfile_fingerprint.n_binary_missing: 0`.
- Build/run record: `docs/ops/evidence/2026-08-22_sp-a1_live_deployment_pointer_generator.md`.
- This schema/signing doc.
