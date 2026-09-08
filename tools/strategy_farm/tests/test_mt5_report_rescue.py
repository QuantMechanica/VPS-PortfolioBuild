"""Offline fault tests; no terminal, account, GUI or network operations."""
from datetime import datetime, timezone
import json
from pathlib import Path
from types import SimpleNamespace
import sqlite3
import time

import pytest

from tools.strategy_farm import mt5_report_rescue as rescue
from tools.strategy_farm.mt5_native_html_export import export


CONFIG = {'expert': r'QM\Fixture', 'symbol': 'EURUSD.DWX', 'period': 'D1',
          'fromdate': '2024.01.01', 'todate': '2024.12.31', 'deposit': '100000',
          'currency': 'USD', 'leverage': '100', 'model': '4'}


def report_fixture(tmp_path):
    values = {'Expert': 'Fixture', 'Symbol': 'EURUSD.DWX',
              'Period': 'Daily (2024.01.01 - 2024.12.31)', 'Currency': 'USD',
              'Initial Deposit': '100 000.00', 'Leverage': '1:100',
              'History Quality': '100%', 'Bars': '257', 'Ticks': '516822',
              'Total Trades': '60', 'Total Net Profit': '-347.84', 'Gross Profit': '159.62',
              'Gross Loss': '-507.46', 'Profit Factor': '0.31', 'Equity Drawdown Maximal': '600.00 (0.60%)'}
    text = '<html><meta name="generator" content="strategy tester"><table>'
    text += ''.join(f'<tr><td>{k}:</td><td><b>{v}</b></td></tr>' for k, v in values.items())
    text += '<tr><td>Inputs:</td><td>risk=1000.0</td><td>seed=42</td></tr></table></html>'
    path = tmp_path / 'native.html'
    path.write_text(text, encoding='utf-16')
    setfile = tmp_path / 'fixture.set'
    setfile.write_text('; fixture\nrisk=1000||1||1||9999||N\nseed=42\n', encoding='utf-16')
    return path, setfile


def test_complete_native_fields_and_exact_effective_inputs(tmp_path):
    path, setfile = report_fixture(tmp_path)
    result = rescue.validate_report(path, CONFIG, setfile)
    assert result['native_inputs_checked'] == 2
    assert result['settings']['Period'] == 'Daily (2024.01.01 - 2024.12.31)'
    assert result['sha256'] == rescue.sha(path)
    assert '-507.46' in rescue.read_text(path)


@pytest.mark.parametrize('key,value', [('expert', r'QM\Other'), ('symbol', 'USDJPY.DWX'),
    ('period', 'H1'), ('fromdate', '2023.01.01'), ('todate', '2024.12.30'),
    ('deposit', '10000'), ('currency', 'EUR'), ('leverage', '200')])
def test_other_run_cannot_be_published(tmp_path, key, value):
    path, setfile = report_fixture(tmp_path)
    with pytest.raises(ValueError):
        rescue.validate_report(path, {**CONFIG, key: value}, setfile)


@pytest.mark.parametrize('replacement', ['seed=43', 'unknown=42', 'seed=42\nbroken'])
def test_changed_unknown_or_malformed_setfile_refuses_rescue(tmp_path, replacement):
    path, setfile = report_fixture(tmp_path)
    setfile.write_text(replacement, encoding='utf-8')
    with pytest.raises(ValueError):
        rescue.validate_report(path, CONFIG, setfile)


@pytest.mark.parametrize('old,new', [('</html>', ''), ('content="strategy tester"', 'content="summary"'),
                                  ('Gross Loss:', 'Summary Loss:'), ('seed=42', 'risk=42')])
def test_partial_summary_duplicate_or_missing_metric_refuses_rescue(tmp_path, old, new):
    path, setfile = report_fixture(tmp_path)
    path.write_text(rescue.read_text(path).replace(old, new), encoding='utf-16')
    with pytest.raises(ValueError):
        rescue.validate_report(path, CONFIG, setfile)


@pytest.mark.parametrize('model,optimization,visual', [('1','0','0'), ('4','1','0'), ('4','0','1')])
def test_quality_model_never_weakened(tmp_path, model, optimization, visual):
    path = tmp_path / 'tester.ini'
    path.write_text(f'[Tester]\nModel={model}\nOptimization={optimization}\nVisual={visual}\n')
    with pytest.raises(ValueError):
        rescue.tester_config(path)


def test_policy_off_expired_foreign_terminal_and_changed_build_refused():
    now = datetime(2026, 9, 8, tzinfo=timezone.utc)
    policy = {'schema': 'qm.native-report-rescue/v1', 'enabled': True, 'terminals': ['T1'],
              'terminal_sha256': 'a' * 64, 'expires_at_utc': '2026-09-09T22:00:00+00:00'}
    rescue.validate_policy(policy, 'T1', 'a' * 64, now)
    for change, terminal, digest, when in [({'enabled': False}, 'T1', 'a'*64, now),
        ({}, 'T11', 'a'*64, now), ({}, 'T_Live', 'a'*64, now), ({}, 'T1', 'b'*64, now),
        ({}, 'T1', 'a'*64, datetime(2026, 9, 10, tzinfo=timezone.utc))]:
        with pytest.raises(ValueError):
            rescue.validate_policy({**policy, **change}, terminal, digest, when)


@pytest.mark.parametrize('terminal', ['T_Live', 'T11', 'T12', 'T100', '../T1'])
def test_live_lab_and_traversal_rejected_before_process_access(terminal):
    with pytest.raises(ValueError, match='factory root'):
        rescue.rescue({'terminal': terminal, 'terminal_root': str(rescue.MT5 / terminal)})


def test_ui_export_never_overwrites_existing_file(tmp_path):
    destination = tmp_path / 'existing.html'
    destination.write_bytes(b'user evidence')
    with pytest.raises(ValueError, match='must be new'):
        export(1, destination)
    assert destination.read_bytes() == b'user evidence'


def test_atomic_publication_cannot_replace_concurrent_report(tmp_path):
    source = tmp_path / 'rescue.html'
    source.write_bytes(b'native rescue')
    target = tmp_path / 'report.htm'
    target.write_bytes(b'CLI native report')
    with pytest.raises(FileExistsError):
        rescue.os.link(source, target)
    assert target.read_bytes() == b'CLI native report'
    assert source.read_bytes() == b'native rescue'


def test_no_mcp_or_trading_or_unbounded_helper_contract():
    source = Path(rescue.__file__).read_text(encoding='utf-8')
    assert 'tester_run_backtest' not in source
    assert 'urllib' not in source
    assert 'os.link(rescued, destination)' in source
    powershell = (rescue.REPO / 'framework/scripts/run_smoke.ps1').read_text(encoding='utf-8-sig')
    assert '$helper.WaitForExit(30000)' in powershell
    assert 'nativeRescueAttempted = $true' in powershell
    assert "[int]$GraceSeconds = 600" in powershell
    assert 'Test-TesterReportSafeToLatch -ReportPath $ReportPath' in powershell
    native = (rescue.REPO / 'tools/strategy_farm/mt5_native_html_export.py').read_text(encoding='utf-8')
    assert "control_text(dialog) != 'Save As'" in native
    assert "control_text(buttons[0]).replace('&', '') != 'Save'" in native


@pytest.fixture
def controlled_rescue(tmp_path, monkeypatch):
    mt5 = tmp_path / 'mt5'
    reports = tmp_path / 'reports'
    root = mt5 / 'T1'
    profiles = root / 'MQL5/Profiles/Tester'
    profiles.mkdir(parents=True)
    reports.mkdir()
    (root / 'MQL5/Experts/QM').mkdir(parents=True)
    for path in (root/'terminal64.exe', root/'metatester64.exe', root/'MQL5/Experts/QM/Fixture.ex5'):
        path.write_bytes(b'non-executable offline fixture')
    native, setfile = report_fixture(tmp_path)
    inputs = profiles / 'fixture.set'
    inputs.write_bytes(setfile.read_bytes())
    ini = reports / 'tester.ini'
    config = {**CONFIG, 'report': 'report.htm', 'expertparameters': inputs.name}
    ini.write_text('[Tester]\n' + '\n'.join(k+'='+v for k, v in config.items()))
    db = tmp_path / 'farm.sqlite'
    with sqlite3.connect(db) as con:
        con.execute('CREATE TABLE work_items (id TEXT, status TEXT, claimed_by TEXT)')
        con.execute('INSERT INTO work_items VALUES (?,?,?)', ('fixture', 'active', 'T1'))
    policy = tmp_path / 'policy.json'
    policy.write_text(json.dumps({'schema': 'qm.native-report-rescue/v1', 'enabled': True,
        'terminals': ['T1'], 'terminal_sha256': rescue.sha(root/'terminal64.exe'),
        'expires_at_utc': '2099-01-01T00:00:00+00:00'}))
    created = time.time() - 180
    finish = datetime.fromtimestamp(created + 10)
    journal = root / f'Tester/Agent-127.0.0.1-3000/logs/{finish:%Y%m%d}.log'
    journal.parent.mkdir(parents=True)
    journal.write_text(f'CS\t0\t{finish:%H:%M:%S.%f}\tTester\tTest passed in 0:00:00.200.\n'
        f'CS\t0\t{finish:%H:%M:%S.%f}\tTester\ttest Experts\\QM\\Fixture.ex5 on EURUSD.DWX,Daily thread finished\n')
    owner = SimpleNamespace(pid=10, create_time=lambda: created-1,
                            cmdline=lambda: ['pwsh', '-File', str(rescue.REPO/'framework/scripts/run_smoke.ps1')])
    terminal = SimpleNamespace(pid=20, create_time=lambda: created, exe=lambda: str(root/'terminal64.exe'),
                               parents=lambda: [owner])
    agent = SimpleNamespace(pid=30, create_time=lambda: created+1, exe=lambda: str(root/'metatester64.exe'))
    helper = SimpleNamespace(ppid=lambda: 10)
    processes = {None: helper, 10: owner, 20: terminal, 30: agent}
    monkeypatch.setattr(rescue.psutil, 'Process', lambda pid=None: processes[pid])
    for key, value in [('MT5', mt5), ('REPORTS', reports), ('DB', db), ('POLICY', policy)]:
        monkeypatch.setattr(rescue, key, value)
    monkeypatch.setenv('QM_WORK_ITEM_ID', 'fixture')
    calls = []
    def offline_export(pid, path, timeout, identity_guard):
        identity_guard()
        calls.append(pid)
        path.write_bytes(native.read_bytes())
        return {'native_html': str(path)}
    monkeypatch.setattr(rescue, 'export', offline_export)
    request = {'terminal': 'T1', 'terminal_root': str(root), 'terminal_pid': 20, 'owner_pid': 10,
        'terminal_created_utc': datetime.fromtimestamp(created, timezone.utc).isoformat(),
        'owner_created_utc': datetime.fromtimestamp(created-1, timezone.utc).isoformat(),
        'ini_path': str(ini), 'report_path': str(root/'report.htm'), 'work_item_id': 'fixture',
        'expected_ex5_sha256': rescue.sha(root/'MQL5/Experts/QM/Fixture.ex5'), 'idle_seconds': 61,
        'observation': {'agent_pid': 30, 'agent_started_at_utc': datetime.fromtimestamp(created+1, timezone.utc).isoformat(),
                        'journal_path': str(journal), 'journal_bytes': journal.stat().st_size}}
    return SimpleNamespace(request=request, root=root, calls=calls, processes=processes,
                           ini=ini, inputs=inputs, native=native, journal=journal)


def test_authenticated_native_publication_preserves_original_bytes(controlled_rescue):
    fixture = controlled_rescue
    result = rescue.rescue(fixture.request)
    assert fixture.calls == [20]
    assert (fixture.root/'report.htm').read_bytes() == fixture.native.read_bytes()
    assert result['validation']['native_inputs_checked'] == 2
    assert 'all normal run_smoke checks still required' in result['disposition']


@pytest.mark.parametrize('fault', ['wrong_ex5', 'wrong_parent', 'reused_terminal_pid', 'foreign_agent',
    'different_work_item', 'different_owner', 'old_journal', 'early', 'new_journal_bytes', 'existing_shell'])
def test_process_and_run_fences_refuse_before_ui(controlled_rescue, fault, monkeypatch):
    fixture = controlled_rescue
    request = fixture.request
    if fault == 'wrong_ex5': request['expected_ex5_sha256'] = '0'*64
    elif fault == 'wrong_parent': fixture.processes[20].parents = lambda: []
    elif fault == 'reused_terminal_pid': fixture.processes[20].create_time = lambda: time.time()
    elif fault == 'foreign_agent': fixture.processes[30].exe = lambda: str(fixture.root.parent/'T10/metatester64.exe')
    elif fault == 'different_work_item': monkeypatch.setenv('QM_WORK_ITEM_ID', 'other')
    elif fault == 'different_owner': fixture.processes[10].cmdline = lambda: ['pwsh', '-File', 'other.ps1']
    elif fault == 'old_journal': fixture.journal.write_text('old cached completed report')
    elif fault == 'early': request['idle_seconds'] = 59
    elif fault == 'new_journal_bytes': fixture.journal.write_text(fixture.journal.read_text()+'new work\n')
    elif fault == 'existing_shell': (fixture.root/'report.htm').write_bytes(b'')
    with pytest.raises((ValueError, RuntimeError)):
        rescue.rescue(request)
    assert fixture.calls == []


def test_input_change_during_export_never_published(controlled_rescue, monkeypatch):
    fixture = controlled_rescue
    original = rescue.export
    def changed(*args, **kwargs):
        result = original(*args, **kwargs)
        fixture.ini.write_text(fixture.ini.read_text()+'\n; changed while exporting\n')
        return result
    monkeypatch.setattr(rescue, 'export', changed)
    with pytest.raises(RuntimeError, match='inputs changed'):
        rescue.rescue(fixture.request)
    assert not (fixture.root/'report.htm').exists()
    assert len(list(fixture.root.glob('QM_rescue_*.html'))) == 1
