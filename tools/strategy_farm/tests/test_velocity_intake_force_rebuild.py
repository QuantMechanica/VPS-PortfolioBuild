"""FABLE-DEC-VELOCITY-INTAKE-20260920 force-rebuild allowlist is document-bound and fail-closed."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import compile_work_items as cwi  # noqa: E402

REPO = Path(__file__).resolve().parents[3]


def test_live_document_authorizes_exactly_the_listed_eas():
    got = cwi.velocity_intake_force_rebuild_allowlist(REPO)
    assert got == frozenset({"11299", "11496", "11516", "11518", "11291", "11292"})
    assert got <= cwi.force_rebuild_allowlist(REPO / "nonexistent-root", REPO)
    assert cwi.force_rebuild_owner_reference("11299") == cwi.VELOCITY_INTAKE_FORCE_REBUILD_OWNER_REFERENCE
    assert cwi.force_rebuild_evidence_note("11299") == cwi.VELOCITY_INTAKE_FORCE_REBUILD_DECISION_DOC


def test_missing_or_revoked_document_turns_the_bypass_off(tmp_path):
    assert cwi.velocity_intake_force_rebuild_allowlist(tmp_path) == frozenset()
    doc = tmp_path / cwi.VELOCITY_INTAKE_FORCE_REBUILD_DECISION_DOC
    doc.parent.mkdir(parents=True)
    doc.write_text(cwi.VELOCITY_INTAKE_FORCE_REBUILD_OWNER_REFERENCE + " QM5_11299 only", encoding="utf-8")
    assert cwi.velocity_intake_force_rebuild_allowlist(tmp_path) == frozenset({"11299"})
    doc.write_text("no reference QM5_11299", encoding="utf-8")
    assert cwi.velocity_intake_force_rebuild_allowlist(tmp_path) == frozenset()
