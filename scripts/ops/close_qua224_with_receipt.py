#!/usr/bin/env python3
"""Post QUA-224 closeout comment and transition status to done."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(r"C:/QM/paperclip/tools/ops")
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from lib.paperclip_api import PaperclipClient, PaperclipError  # type: ignore

ISSUE_IDENTIFIER = "QUA-224"
RECEIPT_DOC = Path(r"C:/QM/repo/docs/ops/QUA-224_ACCEPTANCE_RECEIPT_2026-05-08.md")


def _list_issues(client: PaperclipClient) -> list[dict]:
    # Runtime uses company-scoped issue listing.
    resp = client._request(  # type: ignore[attr-defined]
        "GET",
        f"/api/companies/{client.company_id}/issues",
        query={"limit": "400"},
    )
    if isinstance(resp, dict) and "issues" in resp:
        return resp["issues"]
    return resp or []


def main() -> int:
    if not RECEIPT_DOC.exists():
        print(f"ERROR: receipt doc missing: {RECEIPT_DOC}")
        return 2

    receipt_path = RECEIPT_DOC.as_posix()
    body = (
        "QUA-224 implementation complete. Acceptance evidence is in:\n"
        f"- {receipt_path}\n\n"
        "Verified in this run:\n"
        "- fixture test passes (`python -m unittest framework.tests.unit.test_build_vps_slippage_latency_calibration_v2`)\n"
        "- idempotence hash stable on target calibration json\n"
        "- structured phase log emitted with required fields\n"
        "- one-line CLI documented in framework/scripts/README.md\n\n"
        "Requesting transition to done."
    )

    try:
        client = PaperclipClient()
        issues = _list_issues(client)
    except Exception as exc:
        print(f"BLOCKED: cannot initialize/list issues: {exc}")
        return 3

    match = next((i for i in issues if i.get("identifier") == ISSUE_IDENTIFIER), None)
    if not match:
        print(f"ERROR: issue not found by identifier: {ISSUE_IDENTIFIER}")
        return 4

    issue_id = match["id"]
    try:
        comment = client.add_comment(issue_id, body)
        updated = client.update_issue(issue_id, {"status": "done"})
    except PaperclipError as exc:
        print(f"ERROR: transition failed: {exc}")
        return 5

    out = {
        "issue_identifier": ISSUE_IDENTIFIER,
        "issue_id": issue_id,
        "comment_id": comment.get("id"),
        "status": updated.get("status"),
    }
    print(json.dumps(out, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
