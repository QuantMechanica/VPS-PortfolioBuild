"""Reusable containment release under DL-086 standing authorization.

OWNER directive 2026-08-14 (DL-086): approvals are standing and unlimited —
no per-incident windows, no signature sentences. This tool operationalizes
that: it binds the standing receipt to the draft manifest (idempotent) and
runs the fail-closed release with the registered dual audits. Reusable for
every future containment release; only the --reason changes.

Run BY OWNER via `!` (classifier blocks Claude from executing releases):

    ! python D:/QM/strategy_farm/artifacts/ops/custom_history_custom_history_variant_a_20260809/release_containment_standing.py "<reason-slug>"
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

A = Path(r"D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809")
MIGRATION = Path(r"C:\QM\repo\tools\strategy_farm\custom_history_migration.py")
MODE_JSON = Path(r"D:\QM\strategy_farm\state\custom_history_containment_mode.json")
LEASE = Path(r"D:\QM\strategy_farm\state\custom_history_global.lease")
DRAFT = A / "archive_manifest_draft.json"
RECEIPT = A / "owner_window_receipt_standing_unlimited.json"
MANIFEST = A / "archive_manifest_owner_approved_standing.json"
AUDITS = [A / "isolation_audit_3.json", A / "isolation_audit_4.json"]


def run(cmd: list[str]) -> tuple[int, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600, cwd=r"C:\QM\repo")
    out = (proc.stdout or "").strip()
    err = (proc.stderr or "").strip()
    if out:
        print(out)
    if err:
        print(err, file=sys.stderr)
    return proc.returncode, out + err


def main() -> int:
    reason = sys.argv[1].strip() if len(sys.argv) > 1 and sys.argv[1].strip() else "standing_release"
    if json.loads(MODE_JSON.read_text(encoding="utf-8")).get("enabled") is False:
        print("containment already released — nothing to do")
        return 0
    if not MANIFEST.exists():
        print("--- attach-owner-approval (standing, one-time) ---")
        rc, blob = run([sys.executable, str(MIGRATION), "attach-owner-approval",
                        "--manifest", str(DRAFT), "--owner-receipt", str(RECEIPT),
                        "--output", str(MANIFEST)])
        if rc != 0:
            print(f"attach failed rc={rc} — stopping fail-closed")
            return rc
    print("--- release-containment (standing receipt, lease-flicker tolerant) ---")
    deadline = datetime.now(timezone.utc) + timedelta(minutes=30)
    while datetime.now(timezone.utc) < deadline:
        if json.loads(MODE_JSON.read_text(encoding="utf-8")).get("enabled") is False:
            print("released")
            print(MODE_JSON.read_text(encoding="utf-8"))
            return 0
        if LEASE.exists():
            time.sleep(3)
            continue
        rc, blob = run([sys.executable, str(MIGRATION), "release-containment",
                        "--manifest", str(MANIFEST), "--owner-receipt", str(RECEIPT),
                        "--audit", str(AUDITS[0]), "--audit", str(AUDITS[1]),
                        "--reason", reason, "--execute"])
        if rc == 0:
            print(MODE_JSON.read_text(encoding="utf-8"))
            return 0
        if "lease record still exists" in blob:
            time.sleep(2)
            continue
        print(f"release failed rc={rc} (non-lease) — stopping fail-closed")
        return rc
    print("no quiet lease gap within 30min — investigate")
    return 3


if __name__ == "__main__":
    raise SystemExit(main())
