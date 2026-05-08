#!/usr/bin/env python3
"""Post QUA-791 CTO ratification comment when Paperclip env credentials are present."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(r"C:/QM/paperclip/tools/ops")
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from lib.paperclip_api import PaperclipClient, PaperclipError  # type: ignore

ISSUE_IDENTIFIER = "QUA-791"
DRAFT_PATH = Path(r"C:/QM/repo/docs/ops/QUA-791_PAPERCLIP_COMMENT_DRAFT_2026-05-08.md")


def main() -> int:
    if not DRAFT_PATH.exists():
        print(f"ERROR: draft not found: {DRAFT_PATH}")
        return 2

    body = DRAFT_PATH.read_text(encoding="utf-8").strip()
    if not body:
        print("ERROR: draft is empty")
        return 2

    try:
        client = PaperclipClient()
        # Runtime API expects company-scoped issue listing.
        resp = client._request(  # type: ignore[attr-defined]
            "GET",
            f"/api/companies/{client.company_id}/issues",
            query={"limit": "400"},
        )
        if isinstance(resp, dict) and "issues" in resp:
            issues = resp["issues"]
        else:
            issues = resp or []
    except Exception as exc:
        print(f"BLOCKED: cannot initialize/list issues: {exc}")
        return 3

    match = None
    for issue in issues:
        if issue.get("identifier") == ISSUE_IDENTIFIER:
            match = issue
            break

    if not match:
        print(f"ERROR: {ISSUE_IDENTIFIER} not found in list_issues")
        return 4

    issue_id = match["id"]
    try:
        comment = client.add_comment(issue_id, body)
    except PaperclipError as exc:
        print(f"ERROR: comment post failed: {exc}")
        return 5

    print(f"OK: posted comment to {ISSUE_IDENTIFIER} ({issue_id}) comment_id={comment.get('id')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
