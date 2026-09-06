import hashlib
from pathlib import Path
import pytest
from tools.strategy_farm.include_mirror import validate_monitor_probe_contract, IncludeMirrorRefusal

ROOT = Path('C:/QM/repo/docs/ops/evidence/2026-09-06_ftmo_collector_native_acceptance/compile_probe')

def fixture(monkeypatch):
    monkeypatch.setattr(Path, 'is_file', lambda p: True)
    monkeypatch.setattr(Path, 'is_symlink', lambda p: False)
    monkeypatch.setattr(Path, 'resolve', lambda p: p.absolute())
    monkeypatch.setattr(Path, 'read_bytes', lambda p: b'fixture')
    task = dict(id='f4e95c80-c121-42cb-8e42-78e1334046f4', assigned_agent='codex', state='IN_PROGRESS')
    manifest = dict(schema='qm.monitor-compile-probe/v1', task_id=task['id'], files={p: hashlib.sha256(b'fixture').hexdigest() for p in (
        'editor/MetaEditor64.exe', 'MQL5/QM_FTMO_TrialTelemetry.mq5', 'MQL5/QM_FTMO_TrialTelemetryAcceptance.mq5', 'MQL5/Include/QM/QM_FTMOGovernorPolicy.mqh')})
    return task, manifest

def test_exact_contract(monkeypatch):
    task, manifest = fixture(monkeypatch)
    validate_monitor_probe_contract(manifest, task, ROOT)

@pytest.mark.parametrize('change', ['state', 'agent', 'task', 'root', 'hash', 'extra', 'missing', 'escape'])
def test_refusals(monkeypatch, change):
    task, manifest = fixture(monkeypatch)
    root = ROOT
    if change == 'state': task['state'] = 'REVIEW'
    if change == 'agent': task['assigned_agent'] = 'gemini'
    if change == 'task': manifest['task_id'] = 'other'
    if change == 'root': root = Path('D:/QM/mt5/T1')
    if change == 'hash': manifest['files']['editor/MetaEditor64.exe'] = '0'*64
    if change == 'extra': manifest['files']['terminal64.exe'] = '0'*64
    if change == 'missing': del manifest['files']['editor/MetaEditor64.exe']
    if change == 'escape':
        monkeypatch.setattr(Path, 'resolve', lambda p: Path('D:/QM/mt5/T1') if p.name == 'MetaEditor64.exe' else p.absolute())
    with pytest.raises(IncludeMirrorRefusal): validate_monitor_probe_contract(manifest, task, root)
