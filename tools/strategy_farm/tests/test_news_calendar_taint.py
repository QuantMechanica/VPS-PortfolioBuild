"""Claimability policy tests use only temporary farm databases and files."""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

import farmctl
import terminal_worker
from tools.strategy_farm import news_calendar_taint as taint

SHA = 'a' * 64


def write_json(path, data):
    path.write_text(json.dumps(data), encoding='utf-8')
    return path


@pytest.fixture
def inputs(tmp_path, monkeypatch):
    policy = {
        'schema': 'qm.news-calendar-taint/v1', 'enabled': True,
        'activation_evidence': 'fixture-only CEO receipt',
        'tainted': [{'sha256': SHA, 'evidence_path': 'diagnostic.md',
                     'declared_at': '2026-09-05T15:12:29+00:00'}],
    }
    config = write_json(tmp_path / 'policy.json', policy)
    pin = write_json(tmp_path / 'manifest.json', {'content_sha256': SHA})
    monkeypatch.setattr(taint, 'CONFIG', config)
    monkeypatch.setattr(farmctl, 'Q09_AUTOPILOT_CALENDAR_MANIFEST', pin)
    return policy, config, pin


@pytest.fixture
def db():
    conn = sqlite3.connect(':memory:')
    conn.row_factory = sqlite3.Row
    conn.executescript('''
        CREATE TABLE work_items(id TEXT PRIMARY KEY,phase TEXT,status TEXT,
          ea_id TEXT,symbol TEXT,payload_json TEXT);
        CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY,
          hold_code TEXT,reason TEXT,active INTEGER,release_on_restart INTEGER,
          created_at TEXT,updated_at TEXT,released_at TEXT,release_note TEXT);
        CREATE TABLE events(id INTEGER PRIMARY KEY,ts TEXT,entity_type TEXT,
          entity_id TEXT,event TEXT,detail_json TEXT);
    ''')
    yield conn
    conn.close()


def insert(conn, item_id='news', phase='Q10_NEWS', status='pending'):
    conn.execute('INSERT INTO work_items VALUES(?,?,?,?,?,?)',
                 (item_id, phase, status, 'QM5_9999', 'EURUSD.DWX', '{}'))
    conn.commit()


def hold_rows(conn):
    return [dict(r) for r in conn.execute('SELECT * FROM work_item_holds ORDER BY work_item_id')]


@pytest.mark.parametrize('phase', ['Q09_NEWS', 'Q10_NEWS'])
def test_hold_is_transactional_idempotent_and_preserves_work_items(db, inputs, phase):
    policy, _, pin = inputs
    insert(db, phase=phase)
    before = list(db.execute('SELECT * FROM work_items'))
    dry = taint.synchronize(db, policy, pin)
    assert dry[0]['action'] == 'HOLD' and not hold_rows(db)
    db.execute('BEGIN IMMEDIATE')
    assert taint.guard_claim(db, 'news', pin).startswith('PINNED_CALENDAR_TAINTED:')
    db.commit()
    holds = hold_rows(db)
    assert holds[0]['active'] == 1 and holds[0]['release_on_restart'] == 0
    assert 'diagnostic.md' in holds[0]['reason']
    db.execute('BEGIN IMMEDIATE')
    again = taint.synchronize(db, policy, pin, apply=True)
    db.commit()
    assert again[0]['action'] == 'ALREADY_HELD'
    assert holds == hold_rows(db)
    assert db.execute('SELECT count(*) FROM events').fetchone()[0] == 1
    assert list(db.execute('SELECT * FROM work_items')) == before


@pytest.mark.parametrize('phase,status', [
    ('Q08', 'pending'), ('Q09', 'pending'), ('Q10', 'pending'),
    ('COMPILE_EA', 'pending'), ('Q10_NEWS', 'active'), ('Q09_NEWS', 'done'),
])
def test_unrelated_or_started_rows_are_untouched(db, inputs, phase, status):
    policy, _, pin = inputs
    insert(db, phase=phase, status=status)
    db.execute('BEGIN IMMEDIATE')
    assert taint.synchronize(db, policy, pin, apply=True) == []
    assert taint.guard_claim(db, 'news', pin) is None
    db.commit()
    assert not hold_rows(db)


@pytest.mark.parametrize('release', ['repin', 'remove_entry'])
def test_release_is_automatic_and_preserves_other_holds(db, inputs, release):
    policy, config, pin = inputs
    insert(db)
    insert(db, 'other')
    db.execute("INSERT INTO work_item_holds VALUES('other','OOS','keep',1,0,'old','old',NULL,NULL)")
    db.commit()
    db.execute('BEGIN IMMEDIATE')
    taint.synchronize(db, policy, pin, apply=True)
    db.commit()
    if release == 'repin':
        write_json(pin, {'content_sha256': 'b' * 64})
    else:
        policy['tainted'] = []
        write_json(config, policy)
    db.execute('BEGIN IMMEDIATE')
    rows = taint.synchronize(db, policy, pin, apply=True)
    db.commit()
    assert [r['action'] for r in rows] == ['RELEASE', 'NONE']
    holds = {r['work_item_id']: r for r in hold_rows(db)}
    assert holds['news']['active'] == 0
    assert holds['other']['active'] == 1 and holds['other']['reason'] == 'keep'
    db.execute('BEGIN IMMEDIATE')
    taint.synchronize(db, policy, pin, apply=True)
    db.commit()
    assert db.execute('SELECT count(*) FROM events').fetchone()[0] == 2


def test_other_hold_release_cannot_expose_new_successor(db, inputs):
    policy, _, pin = inputs
    # The sweep ran before this successor was appended.
    assert taint.synchronize(db, policy, pin) == []
    insert(db)
    db.execute("INSERT INTO work_item_holds VALUES('news','OOS','keep',1,0,'old','old',NULL,NULL)")
    db.commit()
    db.execute('BEGIN IMMEDIATE')
    assert taint.guard_claim(db, 'news', pin)
    assert hold_rows(db)[0]['hold_code'] == 'OOS'
    db.execute("UPDATE work_item_holds SET active=0 WHERE work_item_id='news'")
    assert taint.guard_claim(db, 'news', pin)
    db.commit()
    assert hold_rows(db)[0]['hold_code'] == taint.HOLD


def test_disabled_policy_and_preview_cannot_apply(db, inputs, tmp_path):
    policy, config, pin = inputs
    policy['enabled'] = False
    write_json(config, policy)
    insert(db)
    db.execute('BEGIN IMMEDIATE')
    assert taint.guard_claim(db, 'news', pin) is None
    db.commit()
    assert not hold_rows(db)
    assert taint.sweep(tmp_path, pin, apply=True)['applied'] is False
    with pytest.raises(ValueError, match='preview cannot apply'):
        taint.sweep(tmp_path, pin, apply=True, preview=True)


@pytest.mark.parametrize('content', ['[]', 'null', '{}', '{"enabled":true,"enabled":false}',
                                      '{"schema":"qm.news-calendar-taint/v1","enabled":true,"tainted":[]}'])
def test_bad_policy_blocks_only_news(db, inputs, content):
    _, config, pin = inputs
    config.write_text(content, encoding='utf-8')
    insert(db)
    insert(db, 'other', 'Q08')
    db.execute('BEGIN IMMEDIATE')
    assert taint.guard_claim(db, 'news', pin).startswith('TAINT_POLICY_UNAVAILABLE:')
    assert taint.guard_claim(db, 'other', pin) is None
    db.commit()
    assert len(hold_rows(db)) == 1


def test_missing_pin_retains_news_hold(db, inputs):
    policy, _, pin = inputs
    insert(db)
    pin.unlink()
    db.execute('BEGIN IMMEDIATE')
    assert taint.guard_claim(db, 'news', pin).startswith('CALENDAR_TAINT_IDENTITY_UNAVAILABLE:')
    db.commit()
    assert hold_rows(db)[0]['active'] == 1


def test_mutation_requires_transaction(db, inputs):
    policy, _, pin = inputs
    insert(db)
    with pytest.raises(ValueError, match='transaction required'):
        taint.synchronize(db, policy, pin, apply=True)


def init_farm(root):
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute('''INSERT INTO work_items
          (id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,created_at,updated_at)
          VALUES('news','backtest','Q10_NEWS','QM5_9999','EURUSD.DWX','dummy.set','pending',0,'{}',?,?)''', (now, now))
        binding = {'q09_binding_version': 'q09-news-dispatch-binding/v1',
                   'q09_run_plan_path': 'fixture-only.json',
                   'q09_run_plan_file_sha256': 'c' * 64,
                   'q09_dispatch_binding_sha256': 'd' * 64}
        conn.execute("UPDATE work_items SET payload_json=? WHERE id='news'", (json.dumps(binding),))


def test_sweep_apply_backup_and_automatic_release_use_only_fixture_database(tmp_path, inputs):
    _, _, pin = inputs
    root = tmp_path / 'farm'
    init_farm(root)
    dry = taint.sweep(root, pin)
    assert not dry['applied'] and dry['rows'][0]['action'] == 'HOLD'
    applied = taint.sweep(root, pin, apply=True)
    assert applied['applied'] and Path(applied['backup']).is_file()
    assert len(applied['backup_sha256']) == 64
    write_json(pin, {'content_sha256': 'b' * 64})
    released = taint.sweep(root, pin, apply=True)
    assert released['rows'][0]['action'] == 'RELEASE'
    with farmctl.connect(root) as conn:
        assert hold_rows(conn)[0]['active'] == 0
        assert conn.execute('SELECT status FROM work_items').fetchone()[0] == 'pending'


@pytest.mark.parametrize('claim_path', ['targeted', 'worker', 'dispatcher'])
def test_real_claim_boundaries_block_before_claim_and_ledger(tmp_path, inputs, monkeypatch, claim_path):
    _, _, pin = inputs
    root = tmp_path / 'farm'
    init_farm(root)
    monkeypatch.setattr(farmctl, '_news_calendar_preflight', lambda **kw: {'ok': True})
    monkeypatch.setattr(farmctl, '_running_mt5_terminals', lambda: set())
    monkeypatch.setattr(farmctl, 'active_mt5_terminals', lambda **kw: ['T1'])
    monkeypatch.setattr(terminal_worker, '_commit_headroom_gb', lambda: 10000.)
    monkeypatch.setattr(terminal_worker, '_free_ram_gb', lambda: 10000.)
    monkeypatch.setenv(terminal_worker.TEST_FREE_RAM_GB_ENV, '10000')
    # Isolate the new hold from independent evidence/input gates. No runner runs.
    monkeypatch.setattr(terminal_worker, '_governed_analytic_claim_block', lambda *a, **k: None)
    monkeypatch.setattr(terminal_worker, '_p2_history_claimable', lambda *a, **k: (True, {}))
    monkeypatch.setattr(terminal_worker, '_work_item_preflight_failure', lambda *a, **k: None)
    monkeypatch.setattr(farmctl, '_spawn_work_item_runner', lambda *a, **k: pytest.fail('runner must not spawn'))
    if claim_path == 'targeted':
        (root / 'state/FACTORY_OFF.flag').write_text('fixture only', encoding='utf-8')
        result = terminal_worker.claim_specific_atomic(root, 'T1', 'news')
        assert not result['claimed']
    elif claim_path == 'worker':
        result = terminal_worker.claim_atomic(root, 'T1')
        assert not result['claimed']
    else:
        result = farmctl.dispatch_work_items(root)
    with farmctl.connect(root) as conn:
        row = conn.execute("SELECT status,claimed_by,attempt_count FROM work_items WHERE id='news'").fetchone()
        assert tuple(row) == ('pending', None, 0), result
        assert conn.execute('SELECT count(*) FROM claim_class_ledger').fetchone()[0] == 0
        holds = hold_rows(conn)
        assert len(holds) == 1 and holds[0]['hold_code'] == taint.HOLD, json.dumps(result, default=str)

def test_activation_evidence_accepts_structured_ceo_receipt():
    from tools.strategy_farm.news_calendar_taint import _activation_evidence_ok
    assert _activation_evidence_ok('fixture-only CEO receipt')
    assert _activation_evidence_ok({'declared_by': 'CEO (Claude)', 'evidence': ['docs/ops/evidence/x.md']})
    assert not _activation_evidence_ok({'declared_by': '', 'evidence': ['x']})
    assert not _activation_evidence_ok({'declared_by': 'CEO', 'evidence': []})
    assert not _activation_evidence_ok('   ') and not _activation_evidence_ok(None) and not _activation_evidence_ok(7)
