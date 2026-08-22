#!/usr/bin/env python3
"""generate_live_deployment_pointer.py -- SP-A1 (Schienenplan 2026-08-22).

Generates the RUNTIME authenticated deploy-stamp that morning_brief.py /
verify_live_deployment_contract.py consume from
``D:\\QM\\reports\\state\\live_deployment_pointer.json``. See the resolution
order documented in ``tools/strategy_farm/config/live_deployment.json``
(direct override -> runtime deploy-stamp -> repo default -> UNKNOWN).

SCOPE -- WHAT THIS TOOL DOES AND DOES NOT DO
---------------------------------------------
This tool COMPUTES the pointer's evidentiary fields (manifest_sha256,
expected_sleeves identity hash, binary+setfile fingerprint) fresh from disk
every run -- nothing here is copy-pasted or invented. It NEVER guesses a
deployment epoch, account, server or phase: every one of those is an
explicit CLI argument, and the run fails closed (raises) if a required one
is missing.

Signing is a separate, gated action. ``signed=true`` is written ONLY when
the caller passes BOTH ``--signed`` and ``--approval-evidence`` (a path to
the OWNER-approval record backing the manifest, e.g. a ``decisions/*.md``
file). Per the T_Live Hard Rule and the SP-A1 task's own hard_constraints
("Aktivierung/Signatur des Pointers = OWNER/ROT, kein AI-Seat mintet
Live-Bindung"), an AI seat runs this tool ONLY in unsigned (draft/GELB)
mode. Producing a ``signed=true`` pointer is an OWNER/ROT action performed
by a human operator (or by Claude acting on record of an explicit, dated,
written OWNER approval -- never as a default or convenience path).

Exit codes: 0 success, 1 usage/evidence error (fail-closed, nothing written).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Optional

SCHEMA_VERSION = "qm.live_deployment_pointer.v1"
DEFAULT_OUT = Path(r"D:\QM\reports\state\live_deployment_pointer.json")


def sha256_file(path: Path) -> Optional[str]:
    if not path.exists():
        return None
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _book_to_account(book: Optional[str]) -> Optional[str]:
    if not book:
        return None
    m = re.search(r"(\d{6,})", book)
    return m.group(1) if m else None


def load_manifest(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def compute_expected_sleeves(manifest: dict) -> dict:
    """Deterministic identity fingerprint of the sleeve roster: (ea_id, symbol,
    magic_number) triples, sorted by magic so roster order in the manifest file
    cannot change the hash. Any drift in count OR membership changes this hash."""
    sleeves = manifest.get("sleeves") or manifest.get("legs") or []
    triples = [
        {"ea_id": s.get("ea_id"), "symbol": s.get("symbol"),
         "magic_number": s.get("magic_number", s.get("magic"))}
        for s in sleeves
    ]
    triples.sort(key=lambda t: (t["magic_number"] if t["magic_number"] is not None else -1))
    canonical = json.dumps(triples, sort_keys=True, separators=(",", ":"))
    return {
        "count": len(sleeves),
        "identity_sha256": sha256_text(canonical),
        "roster": triples,
    }


def compute_binary_setfile_fingerprint(manifest: dict, manifest_dir: Path) -> dict:
    """Per-sleeve deployed-binary SHA256 (real file, resolved relative to the
    manifest's own recorded absolute paths) + the set_file_expectation dict,
    combined into one roster-order-independent fingerprint. Missing files are
    recorded explicitly as MISSING:<path>, never silently skipped."""
    sleeves = manifest.get("sleeves") or manifest.get("legs") or []
    per_sleeve = []
    for s in sleeves:
        magic = s.get("magic_number", s.get("magic"))
        ex5_path = s.get("ex5_path")
        ex5_sha = None
        ex5_status = "NO_PATH"
        if ex5_path:
            p = Path(ex5_path)
            if not p.is_absolute():
                p = manifest_dir / p
            ex5_sha = sha256_file(p)
            ex5_status = "OK" if ex5_sha else "MISSING"
        per_sleeve.append({
            "magic_number": magic,
            "ex5_path": ex5_path,
            "ex5_sha256": ex5_sha,
            "ex5_status": ex5_status,
            "deployed_preset": s.get("deployed_preset"),
            "set_file_expectation": s.get("set_file_expectation"),
        })
    per_sleeve_sorted = sorted(per_sleeve, key=lambda r: (r["magic_number"] if r["magic_number"] is not None else -1))
    canonical = json.dumps(per_sleeve_sorted, sort_keys=True, separators=(",", ":"), default=str)
    n_missing = sum(1 for r in per_sleeve_sorted if r["ex5_status"] != "OK")
    return {
        "fingerprint_sha256": sha256_text(canonical),
        "n_sleeves": len(per_sleeve_sorted),
        "n_binary_missing": n_missing,
        "per_sleeve": per_sleeve_sorted,
    }


def _atomic_write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def build_pointer(args: argparse.Namespace) -> dict:
    manifest_path = Path(args.manifest).resolve()
    if not manifest_path.exists():
        raise SystemExit(f"manifest not found: {manifest_path}")
    manifest = load_manifest(manifest_path)
    manifest_sha256 = sha256_file(manifest_path)

    expected_account = args.expected_account or _book_to_account(manifest.get("book"))
    if not expected_account:
        raise SystemExit(
            "expected_account could not be derived from manifest book=%r and "
            "no --expected-account override was given (no silent fallback)" % manifest.get("book"))

    if args.signed:
        if not args.approved_by:
            raise SystemExit("--signed requires --approved-by")
        if not args.approval_evidence:
            raise SystemExit("--signed requires --approval-evidence (path to the OWNER approval record)")
        evidence_path = Path(args.approval_evidence)
        if not evidence_path.exists():
            raise SystemExit(f"--approval-evidence path does not exist: {evidence_path}")

    expected_sleeves = compute_expected_sleeves(manifest)
    binary_setfile_fingerprint = compute_binary_setfile_fingerprint(manifest, manifest_path.parent)

    pointer = {
        "schema_version": SCHEMA_VERSION,
        "environment": args.environment,
        "expected_account": expected_account,
        "expected_server": args.expected_server,
        "expected_phase": args.expected_phase,
        "manifest_path": str(manifest_path),
        "manifest_sha256": manifest_sha256,
        "manifest_declared_status": manifest.get("status"),
        "manifest_declared_approved_by": manifest.get("approved_by"),
        "deployment_epoch_utc": args.deployment_epoch_utc,
        "signed": bool(args.signed),
        "approved_by": args.approved_by,
        "approval_evidence": (str(Path(args.approval_evidence)) if args.approval_evidence else None),
        "expected_sleeves": expected_sleeves,
        "binary_setfile_fingerprint": binary_setfile_fingerprint,
        "generator": {
            "tool": "generate_live_deployment_pointer",
            "version": "1.0",
            "task_id": "SP-A1",
        },
        "written_at_utc": args.written_at_utc,
    }
    return pointer


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", required=True, help="path to the signed portfolio manifest JSON")
    ap.add_argument("--environment", default="T_Live/DXZ", help="deployment environment label")
    ap.add_argument("--expected-account", default=None, help="override; else derived from manifest book digits")
    ap.add_argument("--expected-server", default=None, help="broker server this pointer binds to (no default)")
    ap.add_argument("--expected-phase", default=None, help="operational phase label (no default)")
    ap.add_argument("--deployment-epoch-utc", required=True,
                     help="ISO-8601 UTC timestamp of when THIS manifest went live; must be evidence-backed, never guessed")
    ap.add_argument("--written-at-utc", required=True,
                     help="ISO-8601 UTC timestamp for this pointer write (caller-supplied so the tool needs no live clock)")
    ap.add_argument("--signed", action="store_true", help="mint a signed pointer (OWNER/ROT action only)")
    ap.add_argument("--approved-by", default=None, help="required with --signed")
    ap.add_argument("--approval-evidence", default=None, help="required with --signed: path to the OWNER approval record")
    ap.add_argument("--out", default=str(DEFAULT_OUT), help="output path (default: runtime pointer path)")
    ap.add_argument("--dry-run", action="store_true", help="print the computed pointer, write nothing")
    args = ap.parse_args()

    pointer = build_pointer(args)

    if args.dry_run:
        print(json.dumps(pointer, indent=2, sort_keys=True))
        return 0

    out_path = Path(args.out)
    _atomic_write_json(out_path, pointer)
    print(f"wrote {out_path} (signed={pointer['signed']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
