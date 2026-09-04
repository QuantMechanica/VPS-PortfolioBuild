"""Reproduce the Q08 bundle review findings using temporary synthetic evidence.

Run from any directory; no farm DB, queue, or production stream is modified.
Exit zero means the controls passed and the documented ordering defect reproduced.
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))

from tools.strategy_farm import assemble_stream_bundle as bundle
from tools.strategy_farm.tests import test_assemble_stream_bundle as fixtures


def selection_case(root, older_verdict, newer_verdict, reverse, mixed_offsets):
    root.mkdir()
    db = root / "farm.sqlite"
    con = fixtures._make_db(db)
    identity = "a" * 64
    fixtures._q14(con, "q14", "QM5_9001", "EURUSD.DWX", identity, "2026-09-04T12:00:00Z")
    stamps = ("2026-09-04T11:30:00+02:00", "2026-09-04T10:00:00Z") if mixed_offsets else (
        "2026-09-04T09:30:00Z", "2026-09-04T10:00:00Z"
    )
    rows = [("older", older_verdict, stamps[0]), ("newer", newer_verdict, stamps[1])]
    if reverse:
        rows.reverse()
    for wid, verdict, timestamp in rows:
        stream = root / wid / "9001_EURUSD_DWX.jsonl"
        sha = fixtures._write_stream(stream, "EURUSD.DWX", days=4 if wid == "older" else 5)
        aggregate = root / wid / "aggregate.json"
        fixtures._aggregate(aggregate, source_ex5=identity, content_sha=sha, stream_path=stream)
        fixtures._q08(con, wid, "QM5_9001", "EURUSD.DWX", aggregate, timestamp, verdict)
    con.commit()
    con.close()
    manifest = bundle.assemble_bundle(db_path=db, out_root=root / "bundle",
        pairs=[("QM5_9001", "EURUSD.DWX")], search_roots=[], verify_loadable=True)
    assert manifest["bound_count"] == 1
    assert manifest["loader_verification"]["verified"] is True
    actual = manifest["results"][0]["q08_work_item_id"]
    return {"older_verdict": older_verdict, "newer_verdict": newer_verdict,
        "reverse_insertion": reverse, "mixed_offsets": mixed_offsets,
        "expected": "newer", "actual": actual,
        "newest_instant_selected": actual == "newer", "loader_verified": True}


def main():
    cases = []
    with tempfile.TemporaryDirectory(prefix="qm_q08_passclass_review_") as tmp:
        root = Path(tmp)
        for mixed in (False, True):
            for old, new in (("PASS", "FAIL_SOFT"), ("FAIL_SOFT", "PASS")):
                for reverse in (False, True):
                    cases.append(selection_case(root / str(len(cases)), old, new, reverse, mixed))
    controls = [c for c in cases if not c["mixed_offsets"]]
    reproductions = [c for c in cases if c["mixed_offsets"]]
    assert all(c["newest_instant_selected"] for c in controls)
    assert all(not c["newest_instant_selected"] for c in reproductions)
    result = {"review_task": "348af875-69f2-4aa9-998b-bd1836bbe4cd",
        "result": "KNOWN_ORDERING_DEFECT_REPRODUCED", "controls_passed": len(controls),
        "mixed_offset_defects_reproduced": len(reproductions),
        "loader_checks_passed": len(cases), "cases": cases}
    output = Path(__file__).with_suffix(".json")
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
