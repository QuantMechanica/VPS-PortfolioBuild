"""One-shot generator for prepared_registry_patch.json (read-only; writes only the artifact)."""
import datetime
import hashlib
import json
from collections import Counter

REG = "framework/registry/dxz23_execution_contracts.json"
RCP = "D:/QM/reports/news_calendar/repin_receipts/000016_d8683b53aef9bdf8c644d6fa71465c72e3aff41bc22395fa2c09009685a6738c.json"

receipt = json.load(open(RCP))
reg = json.load(open(REG))


def resolve(root, p):
    node = root
    for k in p[2:].replace("]", "").replace("[", ".").split("."):
        node = node[int(k)] if k.isdigit() else node[k]
    return node


assert receipt["sequence"] == 16
AFTER = {s["name"]: s["after"] for s in receipt["sources"]}
BEFORE = {s["name"]: s["before"] for s in receipt["sources"]}

fields = []
other_divergent = []
already_ok = []
for s in receipt["sources"]:
    name = s["name"]
    for jp in s["registry_target_json_paths"]:
        cur = resolve(reg, jp)
        for field in ("sha256", "coverage_start", "coverage_end"):
            cv = cur.get(field)
            bv = BEFORE[name].get(field)
            av = AFTER[name].get(field)
            if cv == av:
                already_ok.append({"path": REG, "json_pointer": jp + "/" + field, "value": cv})
            elif cv == bv:
                fields.append({"path": REG, "json_pointer": jp + "/" + field,
                               "current_value": cv, "restore_to": av})
            else:
                other_divergent.append({"path": REG, "json_pointer": jp + "/" + field,
                                        "current_value": cv, "receipt_before_value": bv,
                                        "receipt_after_value": av})

patch = {
    "schema_version": "qm.prepared-registry-patch/v1",
    "prepared_at_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "prepared_by": "Kimi Code subagent (read-only diagnosis + patch preparation; NOTHING applied)",
    "status": "PREPARED_FOR_OWNER_APPROVAL_NOT_APPLIED",
    "authority": {
        "decision_id": "OWNER-DEC-CALENDAR-REPIN",
        "constraint": "kein AI-Commit - OWNER or Fable must review and apply; no AI-applied commit, no AI-minted receipt",
    },
    "governing_receipt": {
        "sequence": 16,
        "path": "D:/QM/reports/news_calendar/repin_receipts/000016_d8683b53aef9bdf8c644d6fa71465c72e3aff41bc22395fa2c09009685a6738c.json",
        "receipt_sha256": receipt["receipt_sha256"],
        "created_at_utc": receipt["created_at_utc"],
        "before_file_sha256": receipt["registry"]["before_file_sha256"],
        "after_file_sha256": receipt["registry"]["after_file_sha256"],
    },
    "registry": {
        "path": "C:/QM/repo/framework/registry/dxz23_execution_contracts.json",
        "current_raw_file_sha256": hashlib.sha256(open(REG, "rb").read()).hexdigest(),
        "current_git_state": "byte-identical to git HEAD (commit 76dca44dab, 2026-09-12T04:56:54Z); git diff empty",
    },
    "classification": {
        "reverted_to_before_count": len(fields),
        "other_divergent_count": len(other_divergent),
        "already_matches_after_count": len(already_ok),
    },
    "reverted_to_before_fields": fields,
    "other_divergent_fields": other_divergent,
    "unchanged_in_both_states_note": "coverage_start is 2015-01-01 in receipt-16 before AND after at all 19 target objects; only sha256 and coverage_end require restore (38 field writes across 19 objects).",
    "human_note": (
        "Applying this patch = setting the reverted_to_before_fields in "
        "C:/QM/repo/framework/registry/dxz23_execution_contracts.json to their restore_to values "
        "(receipt-16 attested after state: primary sha256 "
        "8744295adcb7c3aeb0a8fd25d7209f37d34159aee1913472b7c0522afa916a46, secondary sha256 "
        "3abc0cd3cea5c5385e78f5c7027de11d0932202971f886704e6668fcef75da94, coverage_end 2026-09-19). "
        "Once the registry pin again equals the receipt-chain tail (000016), the next scheduled run of "
        "QM_NewsCalendar_Refresh accepts the precondition, re-renders the registry to the LIVE calendar "
        "bytes and mints receipt 000017, binding the live bytes; the chain then self-heals. "
        "Do NOT hand-run record; do NOT commit the patched registry without OWNER direction (kein AI-Commit)."
    ),
    "expected_post_apply": [
        "registry pin == receipt-16 tail, so record() precondition is ACCEPTED on the next scheduled refresh",
        "next QM_NewsCalendar_Refresh run mints receipt 000017 binding live primary sha256 c48ad8b4bf667001ef7204d37f5420504f853ac25aa6f0a70152b3d743a1c134 (48825 data rows, mtime 2026-09-15T20:31:59Z) and live secondary sha256 e15b6fe1f80f2f6a82a612f16ef7aaf6b9cc450d3eba1c3a94690ceee2f3b935",
        "python tools/strategy_farm/news_calendar_repin.py verify returns PASS only AFTER 000017 exists; immediately post-patch verify still REFUSEs on tail-vs-live sha256, which is expected and proves no premature re-pin",
    ],
    "collateral_caveat": (
        "Receipt-16 before_file_sha256 (c6a3ee79...) does NOT equal the current file bytes (a95fd02c...) "
        "under any CRLF/LF/trailing-newline variant, and no copy of the receipt-time before/after bytes "
        "was found in git objects, worktrees, stashes, or D:/QM backups. The receipt attests its own diff "
        "was exactly the 19 calendar-identity targets (policy_or_threshold_changes: 0), so applying the 38 "
        "field restores below is necessary and sufficient for chain self-heal; any OTHER working-tree "
        "registry edits made between 2026-09-12T04:56Z and 2026-09-15T02:45Z were destroyed by the "
        "un-attested git restore and are unrecoverable. OWNER may wish to check session logs for what "
        "else was in flight."
    ),
}

out = "docs/ops/evidence/2026-09-15_news_calendar_repin_repair/prepared_registry_patch.json"
json.dump(patch, open(out, "w"), indent=2)
print("wrote", out)
print("reverted fields:", len(fields), "| other_divergent:", len(other_divergent), "| already_ok:", len(already_ok))
print("by field:", dict(Counter(f["json_pointer"].rsplit("/", 1)[1] for f in fields)))
