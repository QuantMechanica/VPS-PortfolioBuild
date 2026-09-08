import os
import time
from pathlib import Path
import pytest
from tools.strategy_farm import compress_closed_tester_reports as mod

pytestmark = pytest.mark.skipif(os.name != 'nt', reason='NTFS-specific operation')


def test_only_old_single_link_factory_root_reports_are_candidates(tmp_path: Path):
    root = tmp_path / 'T1'; root.mkdir()
    report = root / 'QM5_fixture.htm'
    report.write_bytes(b'x' * (10 * 1024**2))
    old = time.time() - 72 * 3600
    os.utime(report, (old, old))
    assert [r['path'] for r in mod.candidates(tmp_path, now=time.time())] == [str(report)]
    os.link(report, root / 'QM5_link.htm')
    assert mod.candidates(tmp_path, now=time.time()) == []


def test_compression_preserves_exact_content_and_timestamp(tmp_path: Path):
    path = tmp_path / 'canary.htm'
    contents = b'<html>immutable tester report</html>\n' * 10000
    path.write_bytes(contents)
    before = path.stat()
    receipt = mod.compress({'path': str(path), 'bytes': before.st_size,
                            'mtime_ns': before.st_mtime_ns})
    assert receipt['hash_unchanged'] and receipt['compressed']
    assert path.read_bytes() == contents
    assert path.stat().st_mtime_ns == before.st_mtime_ns
