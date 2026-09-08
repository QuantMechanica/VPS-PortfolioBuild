import hashlib
import json

import pytest

from framework.scripts import q04_walkforward as q04


def test_worker_annotation_cannot_break_sealed_summary_hash(tmp_path):
    source = tmp_path / "summary.json"
    source.write_text(json.dumps({"runs": [{"status": "OK"}]}))
    proof = q04._run_smoke_report_identity(source)
    from pathlib import Path
    snapshot = Path(proof['source_summary_path'])
    assert snapshot != source
    before = snapshot.read_bytes()
    source.write_text(json.dumps({"runs": [{"status": "OK"}], "staged_ex5": {"verified": True}}))
    assert snapshot.read_bytes() == before
    assert hashlib.sha256(before).hexdigest() == proof['source_summary_sha256']


def test_existing_snapshot_is_idempotent_but_corruption_is_refused(tmp_path):
    source = tmp_path / "summary.json"
    source.write_text('{"runs": []}')
    proof = q04._run_smoke_report_identity(source)
    assert q04._run_smoke_report_identity(source) == proof
    from pathlib import Path
    Path(proof['source_summary_path']).write_bytes(b'changed')
    with pytest.raises(ValueError, match='immutable_source_summary_conflict'):
        q04._run_smoke_report_identity(source)
