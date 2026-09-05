"""Default-off, read-only recognition of an OWNER-attested unchanged live book."""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

try:
    from . import live_identity_attest as attest
    from . import owner_decision_store as decisions
except ImportError:
    import live_identity_attest as attest
    import owner_decision_store as decisions

DECISION_PREFIX = "OWNER-DEC-LIVE-IDENTITY-CURRENT-"


def attestation_effect(proposal_sha256: str) -> str:
    """Exact OWNER-visible YES effect; notes cannot supply this authority."""
    return f"ATTEST_CURRENT_PROPOSAL_SHA256={proposal_sha256};FREEZE=ACTIVE;NO_ACTIVATION"


def strict_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    def constant(_):
        raise ValueError("non-finite JSON constant")

    return json.loads(raw, object_pairs_hook=pairs, parse_constant=constant)


def load_context(proposal_path: Path, receipt_id: str) -> dict:
    """Read metadata only; current pointer/freeze/tool paths are canonical.

    Receipt authority comes exclusively from the Mission-Control ledger, never
    from a sidecar supplied with the proposal. Paths inside the current manifest
    and measurement are inert strings; no deployed preset or binary is opened.
    """
    proposal_raw = attest.safe_path(proposal_path).read_bytes()
    proposal = strict_json(proposal_raw)
    bindings = proposal["bindings"]
    fixed = {"pointer": attest.POINTER, "freeze": attest.STATE, "source_tool": attest.SOURCE_TOOL}
    files = {}
    for role, path in fixed.items():
        if attest.safe_path(bindings[role]["path"]) != attest.safe_path(path):
            raise ValueError("proposal does not bind the canonical " + role)
        files[role] = attest.safe_path(path).read_bytes()
    pointer = strict_json(files["pointer"])
    manifest_path = attest.safe_path(pointer["manifest_path"])
    if attest.safe_path(bindings["manifest"]["path"]) != manifest_path:
        raise ValueError("proposal manifest is not the current pointer manifest")
    files["manifest"] = manifest_path.read_bytes()
    files["observation"] = attest.safe_path(bindings["observation"]["path"]).read_bytes()
    receipts_raw = attest.safe_path(decisions.DEFAULT_RECEIPTS).read_bytes()
    receipts = [strict_json(line) for line in receipts_raw.splitlines() if line.strip()]
    # Refuse drift during this metadata read as well as drift since proposal time.
    for role, binding in bindings.items():
        if role not in files or attest.safe_path(binding["path"]).read_bytes() != files[role]:
            raise ValueError("input changed during identity consumption: " + role)
    return {"proposal_raw": proposal_raw, "files": files,
            "receipt_id": receipt_id, "receipts": receipts}


def evaluate(context: dict | None, *, enabled: bool = False, at=None) -> dict:
    result = {"accepted": False, "condition_1_satisfied": False,
              "freeze_status": None, "mutation_allowed": False,
              "runtime_pointer_write": False, "activation_authorized": False}
    if enabled is not True:
        return {**result, "reason": "IDENTITY_EXCEPTION_DISABLED"}
    try:
        if not context:
            raise ValueError("IDENTITY_CONTEXT_MISSING")
        if context.get("load_error"):
            raise ValueError("IDENTITY_METADATA_REFUSED:" + context["load_error"])
        proposal_raw = context["proposal_raw"]
        proposal_sha = attest.raw_sha(proposal_raw)
        proposal = strict_json(proposal_raw)
        if proposal.get("schema") != attest.SCHEMA:
            raise ValueError("PROPOSAL_VERSION_UNSUPPORTED")
        files = context["files"]
        bindings = proposal["bindings"]
        if set(files) != {"manifest", "pointer", "freeze", "source_tool", "observation"} or set(bindings) != set(files):
            raise ValueError("INPUT_BINDINGS_INCOMPLETE")
        for role, raw in files.items():
            if attest.raw_sha(raw) != bindings[role]["sha256"]:
                raise ValueError("CURRENT_" + role.upper() + "_BYTE_DRIFT")
        manifest, pointer, freeze, observation = [strict_json(files[k]) for k in
                                                 ("manifest", "pointer", "freeze", "observation")]
        result["freeze_status"] = freeze.get("status")
        created = attest.utc(proposal["created_at_utc"])
        now = at or dt.datetime.now(dt.timezone.utc)
        if created > now:
            raise ValueError("PROPOSAL_FROM_FUTURE")
        recomputed = attest.evaluate(manifest, pointer, freeze, observation, bindings, created)
        if recomputed["status"] != "ELIGIBLE_FOR_OWNER_REVIEW":
            raise ValueError("PROPOSAL_REVALIDATION_REFUSED:" + ";".join(recomputed["failures"]))
        if recomputed != proposal:
            raise ValueError("PROPOSAL_CONTENT_DRIFT")
        receipt_id = context["receipt_id"]
        matches = [r for r in context["receipts"] if r.get("receipt_id") == receipt_id]
        if not receipt_id or len(matches) != 1:
            raise ValueError("MISSION_CONTROL_RECEIPT_MISSING_OR_DUPLICATED")
        receipt = matches[0]
        unsigned = {k: v for k, v in receipt.items() if k != "receipt_sha256"}
        if receipt.get("receipt_sha256") != decisions.sha256_bytes(decisions.canonical_bytes(unsigned)):
            raise ValueError("MISSION_CONTROL_RECEIPT_HASH_INVALID")
        if (receipt.get("schema") != decisions.RECEIPT_SCHEMA
                or receipt.get("decided_by") != "OWNER" or receipt.get("decision") != "YES"
                or receipt.get("decision_id") != DECISION_PREFIX + proposal_sha
                or receipt.get("selected_effect") != attestation_effect(proposal_sha)):
            raise ValueError("RECEIPT_NOT_OWNER_ATTESTATION_OF_THIS_PROPOSAL")
        if not created <= attest.utc(receipt["decided_at_utc"]) <= now:
            raise ValueError("ATTESTATION_RECEIPT_TIME_INVALID")
        return {**result, "accepted": True, "condition_1_satisfied": True,
                "reason": "OWNER_ATTESTED_CURRENT_IDENTITY", "proposal_sha256": proposal_sha,
                "receipt_id": receipt_id, "observation_age_seconds": recomputed["observation_age_seconds"]}
    except (ValueError, TypeError, KeyError, AttributeError, OverflowError) as exc:
        return {**result, "reason": "IDENTITY_ATTESTATION_REFUSED", "detail": str(exc)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-attested-current-identity", action="store_true")
    parser.add_argument("--identity-proposal", type=Path)
    parser.add_argument("--identity-attestation-receipt-id")
    args = parser.parse_args(argv)
    context = None
    if args.allow_attested_current_identity:
        if not args.identity_proposal or not args.identity_attestation_receipt_id:
            parser.error("enabled identity recognition requires proposal and exact attestation receipt ID")
        try:
            context = load_context(args.identity_proposal, args.identity_attestation_receipt_id)
        except (OSError, ValueError, TypeError, KeyError) as exc:
            print(json.dumps({"accepted": False, "reason": "IDENTITY_METADATA_REFUSED", "detail": str(exc)}))
            return 2
    result = evaluate(context, enabled=args.allow_attested_current_identity)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["accepted"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
