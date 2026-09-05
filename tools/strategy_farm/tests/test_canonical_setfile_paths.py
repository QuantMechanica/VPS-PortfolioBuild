from pathlib import Path
import importlib.util
import json
import sys
import pytest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/strategy_farm'))
from canonical_setfile_paths import validate_enqueue_setfile,pending_successor_proposal


def fixture(tmp_path):
    repo=tmp_path/'repo';path=repo/'framework/EAs/QM5_9900_example/sets/example.set'
    path.parent.mkdir(parents=True);path.write_text('RISK_FIXED=1000\nRISK_PERCENT=0\n')
    return repo,path


def test_canonical_path_and_traversal_resolution(tmp_path):
    repo,path=fixture(tmp_path)
    assert validate_enqueue_setfile(path,repo)==path.resolve()
    foreign=tmp_path/'worktrees/old/framework/EAs/QM5_9900_example/sets/example.set'
    foreign.parent.mkdir(parents=True);foreign.write_text(path.read_text())
    with pytest.raises(ValueError,match='NOT_CANONICAL'):validate_enqueue_setfile(foreign,repo)
    with pytest.raises(ValueError,match='NOT_ABSOLUTE'):validate_enqueue_setfile(Path('example.set'),repo)
    with pytest.raises(FileNotFoundError):validate_enqueue_setfile(path.with_name('missing.set'),repo)


def test_existing_directory_or_non_set_refused(tmp_path):
    repo,path=fixture(tmp_path)
    with pytest.raises(ValueError):validate_enqueue_setfile(path.parent,repo)
    binary=path.with_suffix('.ex5');binary.write_bytes(b'compile')
    with pytest.raises(ValueError):validate_enqueue_setfile(binary,repo)


def test_junction_or_symlink_escape_refused(tmp_path):
    repo,path=fixture(tmp_path);foreign=tmp_path/'foreign';foreign.mkdir();(foreign/'escape.set').write_text('x')
    link=path.parent/'escape'
    try:link.symlink_to(foreign,target_is_directory=True)
    except OSError:pytest.skip('symlink creation unavailable')
    with pytest.raises(ValueError,match='NOT_CANONICAL'):validate_enqueue_setfile(link/'escape.set',repo)


def test_proposal_preserves_predecessor_and_refuses_unproven_equivalence(tmp_path):
    repo,path=fixture(tmp_path);old=tmp_path/'worktrees/old/framework/EAs/QM5_9900_example/sets/example.set'
    row={'id':'old','ea_id':'QM5_9900','phase':'Q04','symbol':'EURUSD.DWX','status':'pending','claimed_by':None,'setfile_path':str(old),'payload_json':'{}'}
    before=json.dumps(row,sort_keys=True);proposal=pending_successor_proposal(row,repo)
    assert json.dumps(row,sort_keys=True)==before
    assert 'ORIGINAL_SETFILE_UNAVAILABLE_EQUIVALENCE_UNPROVEN' in proposal['blockers']
    assert not proposal['apply_supported']
    old.parent.mkdir(parents=True);old.write_bytes(path.read_bytes())
    ex5=path.parent.parent/'QM5_9900_example.ex5';ex5.write_bytes(b'test')
    proposal=pending_successor_proposal(row,repo);assert not proposal['blockers']
    assert proposal['authority_status']=='PROPOSED_NOT_APPROVED'
    old.write_text('changed');assert 'SETFILE_BYTES_DIFFER_SOURCE_REVIEW_REQUIRED' in pending_successor_proposal(row,repo)['blockers']
