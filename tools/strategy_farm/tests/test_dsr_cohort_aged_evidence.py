"""DSR cohort reads DL-090 aged (.gz) evidence siblings (2026-09-14, class C of OWNER-DEC-Q08-CONTEXT-REPAIR-V2).

DL-090 retention compresses aged report directories in place (``summary.json`` -> ``summary.json.gz``,
``report.htm`` -> ``report.htm.gz``).  QM5_21501/USDJPY and QM5_20266/XTIUSD were refused as
Q03_GOVERNED_SOURCE_UNAVAILABLE / REPORT_SHA256_MISMATCH only because dsr_cohort looked for the plain
paths and hashed the compressed bytes against the recorded content hash.
"""
import gzip
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import dsr_cohort  # noqa: E402


def test_evidence_file_resolves_the_gz_sibling_only_when_the_plain_file_is_gone(tmp_path):
    plain = tmp_path / "summary.json"
    assert dsr_cohort._evidence_file(plain) == plain  # missing, no sibling -> unchanged (fails closed downstream)
    gz = tmp_path / "summary.json.gz"
    with gzip.open(gz, "wb") as handle:
        handle.write(b'{"runs": []}')
    assert dsr_cohort._evidence_file(plain) == gz
    plain.write_bytes(b'{"runs": [1]}')
    assert dsr_cohort._evidence_file(plain) == plain  # the plain file wins while it exists


def test_load_json_and_content_hash_see_through_the_gz_sibling(tmp_path):
    content = json.dumps({"runs": [{"status": "OK"}]}).encode("utf-8")
    plain = tmp_path / "summary.json"
    with gzip.open(plain.with_name("summary.json.gz"), "wb") as handle:
        handle.write(content)
    assert dsr_cohort._load_json(plain) == {"runs": [{"status": "OK"}]}
    assert dsr_cohort._content_sha256(plain) == hashlib.sha256(content).hexdigest()
    # the binding keeps the on-disk file (what a consumer re-reads) and its own hash
    binding = dsr_cohort._binding(plain, role="native_report")
    assert binding["path"].endswith("summary.json.gz")
    assert binding["sha256"] == dsr_cohort.sha256_file(plain.with_name("summary.json.gz"))


def test_missing_evidence_still_fails_closed(tmp_path):
    plain = tmp_path / "summary.json"
    try:
        dsr_cohort._load_json(plain)
    except dsr_cohort.CohortUnavailable as exc:
        assert "UNREADABLE_JSON" in str(exc)
    else:  # pragma: no cover
        raise AssertionError("missing evidence must fail closed")
