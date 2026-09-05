import gzip
import importlib.util
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('m05_audit', Path(__file__).with_name('audit.py'))
audit = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(audit)


def test_gzip_recovery_has_decoded_hash_but_no_invented_original_hash(tmp_path):
    p = tmp_path/'aggregate.json'; raw=b'{"verdict":"PASS"}'
    Path(str(p)+'.gz').write_bytes(gzip.compress(raw))
    r=audit.inspect(p,[])
    assert r['classification']=='RETENTION_BY_RULE_GZIP'
    assert r['decoded_sha256']==audit.digest(raw)
    assert r['original_hash_comparison'].startswith('UNAVAILABLE')
    assert not p.exists()


def test_corrupt_gzip_and_absent_stay_unexplained(tmp_path):
    p=tmp_path/'summary.json';Path(str(p)+'.gz').write_bytes(b'broken')
    assert audit.inspect(p,[])['classification']=='UNEXPLAINED'
    assert audit.inspect(tmp_path/'missing.json',[])['classification']=='UNEXPLAINED'


def test_quarantine_does_not_prove_original_identity(tmp_path,monkeypatch):
    monkeypatch.setattr(audit,'REPORTS',tmp_path)
    p=tmp_path/'work_items/id/summary.json';q=tmp_path/'quarantine/day'
    destination=q/'work_items/id/summary.json';destination.parent.mkdir(parents=True);destination.write_text('{}')
    r=audit.inspect(p,[q])
    assert r['classification']=='ARCHIVED_QUARANTINE'
    assert r['original_hash_comparison'].startswith('UNAVAILABLE')
