"""Offline fixture contracts; no running terminal, MCP, credentials or farm DB."""
import json
from pathlib import Path
from types import SimpleNamespace

import pytest

from tools.strategy_farm import mt5_qm_warm_fixture as qm
from tools.strategy_farm import mt5_warm_lab as lab


@pytest.fixture
def isolated(tmp_path, monkeypatch):
    monkeypatch.setattr(qm, 'ROOT', tmp_path)
    monkeypatch.setattr(qm, 'FIXTURE', tmp_path / 'fixture')
    monkeypatch.setattr(qm, 'PROFILES', tmp_path / 'profiles')
    monkeypatch.setattr(qm, 'EA_SOURCE', tmp_path / 'source')
    monkeypatch.setattr(qm, 'no_factory_conflict', lambda: None)
    qm.FIXTURE.mkdir()
    qm.PROFILES.mkdir()
    source = qm.EA_SOURCE / 'sets' / f'{qm.EA}_EURUSD.DWX_M30_backtest.set'
    source.parent.mkdir(parents=True)
    source.write_bytes(b'; exact original\r\nRISK_FIXED=1000\r\nRISK_PERCENT=0\r\n')
    monkeypatch.setattr(qm, 'SET_HASH', qm.sha(source))
    for arm in qm.ARMS:
        (qm.PROFILES / f'QM_lab_qm10012_{arm}.set').write_bytes(qm.expected_inputs(arm))
    return tmp_path


def make_ini(monkeypatch, arm='a'):
    monkeypatch.setattr(qm, 'verify_fixture', lambda **_: {})
    ini = qm.PROFILES / f'QM_lab_qm10012_{arm}test1.ini'
    config = qm.cold_config('qm10012_' + arm, 'fixture.htm')
    ini.write_text(config.replace('Report=fixture.htm', 'Report=' + ini.stem + '.htm'), encoding='utf-16')
    return ini, {'config_path': str(ini), 'inputs_path': str(qm.PROFILES / f'QM_lab_qm10012_{arm}.set'), 'wait': False}


@pytest.mark.parametrize('arm', list(qm.ARMS))
def test_fixed_arms_and_only_risk_difference(isolated, monkeypatch, arm):
    raw = qm.expected_inputs(arm)
    assert raw.replace(b'RISK_FIXED=500', b'RISK_FIXED=1000') == qm.expected_inputs('a')
    assert qm.expected_inputs('c') == qm.expected_inputs('a')
    assert qm.expected_inputs('d') == qm.expected_inputs('b')
    ini, args = make_ini(monkeypatch, arm)
    assert f'ToDate={qm.ARMS[arm][1]}' in ini.read_text(encoding='utf-16')
    qm.validate_run(args)
    lab.validate_call('tools/call', {'name': 'tester_run_backtest', 'arguments': args})


def test_source_set_hash_change_rejected(isolated):
    source = next((qm.EA_SOURCE / 'sets').iterdir())
    source.write_bytes(source.read_bytes() + b'OTHER=1\n')
    with pytest.raises(ValueError, match='Original fixture setfile changed'):
        qm.expected_inputs('a')


@pytest.mark.parametrize('old,new', [('Model=4', 'Model=1'), ('UseCloud=0', 'UseCloud=1'),
    ('UseRemote=0', 'UseRemote=1'), ('Optimization=0', 'Optimization=1'),
    ('Symbol=EURUSD.DWX', 'Symbol=USDJPY.DWX'), ('Visual=0', 'Visual=1'),
    ('ToDate=2025.01.11', 'ToDate=2025.01.10'), ('Deposit=100000', 'Deposit=10000'),
    ('Expert=QM\\' + qm.EA, 'Expert=QM\\different'),
    ('ExpertParameters=QM_lab_qm10012_a.set', 'ExpertParameters=other.set'),
    ('Report=QM_lab_qm10012_atest1.htm', 'Report=../other.htm')])
def test_exact_quality_and_identity_pinned(isolated, monkeypatch, old, new):
    ini, args = make_ini(monkeypatch)
    ini.write_text(ini.read_text(encoding='utf-16').replace(old, new), encoding='utf-16')
    with pytest.raises(ValueError):
        qm.validate_run(args)


@pytest.mark.parametrize('mutation', ['missing_inputs', 'wrong_inputs', 'wait', 'extra', 'external_ini'])
def test_explicit_inputs_and_scoped_paths_required(isolated, monkeypatch, mutation):
    _, args = make_ini(monkeypatch)
    if mutation == 'missing_inputs':
        args.pop('inputs_path')
    elif mutation == 'wrong_inputs':
        args['inputs_path'] = str(qm.PROFILES / 'QM_lab_qm10012_b.set')
    elif mutation == 'wait':
        args['wait'] = True
    elif mutation == 'extra':
        args['account'] = 'anything'
    else:
        args['config_path'] = str(isolated / 'QM_lab_qm10012_atest1.ini')
    with pytest.raises(ValueError):
        qm.validate_run(args)


def logger(root, port, rows):
    path = root / f'Tester/Agent-127.0.0.1-{port}/MQL5/Files/QM/QM5_10012_ea-10012.log'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b''.join(json.dumps(row).encode() + b'\n' for row in rows))
    return path


def event(**fields):
    return dict(ea_id=10012, symbol='EURUSD.DWX', tf='M30', **fields)


@pytest.mark.parametrize('reset', [False, True])
def test_exact_fresh_logger_delta_ignores_stale_agents(isolated, reset):
    current = logger(isolated, 3000, [event(n=1)])
    logger(isolated, 3001, [event(n=99)])
    before = qm.logger_state()
    fresh = [event(n=2)]
    logger(isolated, 3000, fresh if reset else [event(n=1), *fresh])
    out = isolated / 'capture'; out.mkdir()
    result = qm.capture_logger(out, before=before)['files'][0]
    assert result['source'] == str(current)
    assert result['events'] == 1
    assert [json.loads(line) for line in Path(result['delta_path']).read_text().splitlines()] == fresh
    assert result['previous_exact_prefix_bytes'] == (0 if reset else len(before[str(current)]))
    with pytest.raises(FileExistsError):
        qm.capture_logger(out, before=before)


def test_no_fresh_logger_rejected(isolated):
    logger(isolated, 3000, [event()])
    with pytest.raises(RuntimeError, match='Exactly one fresh'):
        qm.capture_logger(isolated, before=qm.logger_state())


def test_multiple_fresh_logger_streams_rejected(isolated):
    logger(isolated, 3000, [event()]); logger(isolated, 3001, [event()])
    with pytest.raises(RuntimeError, match='Exactly one fresh'):
        qm.capture_logger(isolated)


def test_wrong_logger_ea_rejected(isolated):
    logger(isolated, 3000, [dict(ea_id=10013, symbol='EURUSD.DWX', tf='M30')])
    with pytest.raises(ValueError, match='identity differs'):
        qm.capture_logger(isolated)


def native_text(warning=False):
    return ('started with inputs:\nCS\t0\t22:00:00.100\tTrade\tx\n'
        + ('real ticks absent for 1 minutes\n' if warning else '')
        + '100 ticks, 10 bars generated. Test passed in 0:00:01.211.\nthread finished\n')


@pytest.mark.parametrize('arm,warning,accepted', [('a', True, True), ('c', False, True), ('c', True, False), ('d', True, False)])
def test_journal_delta_and_clean_window_warning_contract(isolated, arm, warning, accepted):
    path = isolated / 'Tester/Agent-127.0.0.1-3000/logs/20260909.log'
    path.parent.mkdir(parents=True)
    old = native_text().encode('utf-16')
    path.write_bytes(old + native_text(warning).encode('utf-16-le'))
    out = isolated / 'capture'; out.mkdir()
    if not accepted:
        with pytest.raises(RuntimeError, match='real-tick gaps'):
            qm.capture_journals(out, {str(path): len(old)}, arm)
    else:
        result = qm.capture_journals(out, {str(path): len(old)}, arm)
        assert result['native_journals'][0]['engine_seconds'] == 1.211
        assert bool(result['native_tick_gap_warnings']) == warning


def test_truncated_journal_refused(isolated):
    path = isolated / 'Tester/Agent-127.0.0.1-3000/logs/20260909.log'
    path.parent.mkdir(parents=True); path.write_bytes(b'')
    with pytest.raises(RuntimeError, match='truncated'):
        qm.capture_journals(isolated, {str(path): 100}, 'a')


def test_quiesce_only_new_exact_lab_agents_and_retain_main(isolated, monkeypatch):
    terminated = []
    def process(pid, exe, created):
        return SimpleNamespace(pid=pid, info={'exe': str(exe), 'create_time': created},
                               terminate=lambda: terminated.append(pid))
    fresh = process(1, isolated / 'metatester64.exe', 11)
    old = process(2, isolated / 'metatester64.exe', 9)
    foreign = process(3, isolated.parent / 'T1/metatester64.exe', 11)
    main = process(4, isolated / 'terminal64.exe', 11)
    monkeypatch.setattr(lab, 'fenced_process', lambda _: SimpleNamespace(is_running=lambda: True))
    monkeypatch.setattr(qm.psutil, 'process_iter', lambda _: [fresh, old, foreign, main])
    monkeypatch.setattr(qm.psutil, 'wait_procs', lambda items, **_: (items, []))
    assert qm.quiesce_agent({'started_epoch': 10}) == [1]
    assert terminated == [1]


def test_locked_history_requires_fence_and_unchanged_prestart_identity(isolated, monkeypatch):
    data = isolated / 'price.hcc'; data.write_bytes(b'private prices')
    digest = qm.sha(data)
    (qm.FIXTURE / 'manifest.json').write_text(json.dumps({'data_files': [
        {'destination': str(data), 'relative': 'price.hcc', 'sha256': digest}]}))
    (qm.FIXTURE / 'symbol_spec_manifest.json').write_text(json.dumps({'sha256': 'spec'}))
    def hash_file(path):
        if path == data:
            raise PermissionError('native exclusive handle')
        return 'spec' if path.name == 'symbols.custom.dat' else qm.EX5_HASH
    monkeypatch.setattr(qm, 'sha', hash_file)
    monkeypatch.setattr(qm, 'expected_inputs', lambda arm: (qm.PROFILES / f'QM_lab_qm10012_{arm}.set').read_bytes())
    monkeypatch.setattr(lab, 'SESSION', isolated)
    monkeypatch.setattr(lab, 'state', lambda: {'pid': 99})
    fences = []
    monkeypatch.setattr(lab, 'fenced_process', lambda record: fences.append(record['pid']))
    st = data.stat()
    attestation = {'files': {str(data): {'file_id': st.st_ino, 'size': st.st_size,
                                      'mtime_ns': st.st_mtime_ns, 'sha256': digest}}}
    preflight = isolated / 'data_preflight.json'
    preflight.write_text(json.dumps(attestation))
    with pytest.raises(PermissionError):
        qm.verify_fixture()
    qm.verify_fixture(resident=True)
    assert fences == [99]
    attestation['files'][str(data)]['file_id'] += 1
    preflight.write_text(json.dumps(attestation))
    with pytest.raises(ValueError, match='Locked history identity changed'):
        qm.verify_fixture(resident=True)
