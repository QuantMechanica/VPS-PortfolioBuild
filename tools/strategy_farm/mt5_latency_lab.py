"""Owner-authorized, isolated T11 native-EURUSD report latency experiment.

Not a pipeline runner. Never emits gate verdicts or shares Custom history.
Requires the exact diagnostic reservation; only owns newly created lab files.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import sqlite3
import subprocess
import time

import psutil

from tools.strategy_farm.backtest_tail_watch import tail

ROOT = Path('D:/QM/mt5/T11/latency_lab_20260908')
SOURCE = Path('D:/QM/mt5/T11')
OWNER = 'codex-report-latency-20260908'


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def admitted() -> None:
    reservation = json.loads(Path('D:/QM/strategy_farm/state/terminal_reservations.json').read_text())['reservations']['T11']
    assert reservation['reserved_by'] == OWNER
    assert datetime.fromisoformat(reservation['until_utc']) > datetime.now(timezone.utc)
    with sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True) as con:
        assert not con.execute("SELECT id FROM work_items WHERE status='active' AND claimed_by='T11'").fetchall()
    for process in psutil.process_iter(['exe', 'cmdline']):
        exe = (process.info['exe'] or '').lower()
        if exe.startswith(str(SOURCE).lower() + '\\') or is_lab_updater(process.info):
            raise RuntimeError('T11 already has a process; refuse concurrent use')
    if psutil.virtual_memory().available < 18 * 2**30:
        raise RuntimeError('Insufficient measured memory headroom')


def is_lab_updater(info: dict) -> bool:
    """MT5 updater runs outside the portable root; don't mistake handoff for exit."""
    args = [arg.strip('"').lower() for arg in (info.get('cmdline') or [])]
    return (Path(info.get('exe') or '').name.lower() == 'terminal64.exe' and
            '/update' in args and '/path:' + str(ROOT).lower() in args)


def setup() -> None:
    admitted()
    ROOT.mkdir(exist_ok=False)
    # Match production executable build without modifying either installed build.
    for name in ('terminal64.exe', 'metatester64.exe'):
        shutil.copy2(Path('D:/QM/mt5/T1') / name, ROOT / name)
    config = ROOT / 'Config'
    config.mkdir()
    for name in ('accounts.dat', 'servers.dat', 'common.ini'):
        shutil.copy2(SOURCE / 'Config' / name, config / name)
    expert = ROOT / 'MQL5/Experts/Examples/Moving Average/Moving Average.ex5'
    expert.parent.mkdir(parents=True)
    shutil.copy2(SOURCE / 'MQL5/Experts/Examples/Moving Average/Moving Average.ex5', expert)
    # No service, startup EA, chart profile, Custom data or junction is copied.
    manifest = {'created_at_utc': datetime.now(timezone.utc).isoformat(),
                'authorization': OWNER, 'purpose': 'infrastructure experiment only; no gate admission',
                'terminal_sha256': sha(ROOT / 'terminal64.exe'),
                'tester_sha256': sha(ROOT / 'metatester64.exe'),
                'expert_sha256': sha(expert), 'shared_custom_history': False}
    (ROOT / 'lab_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps(manifest), flush=True)


def run(name: str, report_subdir: bool, from_date: str = '2026.09.01') -> None:
    admitted()
    assert name.isalnum() and len(name) <= 24
    assert from_date in {'2026.09.01', '2026.09.02'}
    assert (ROOT / 'lab_manifest.json').is_file()
    runroot = ROOT / 'experiments' / name
    runroot.mkdir(parents=True, exist_ok=False)
    report = (runroot if report_subdir else ROOT) / f'{name}.htm'
    ini = runroot / 'tester.ini'
    config = ('[Tester]\nExpert=Examples\\Moving Average\\Moving Average\n'
              'Symbol=EURUSD\nPeriod=M5\nModel=4\nExecutionMode=0\nOptimization=0\n'
              f'FromDate={from_date}\nToDate=2026.09.05\nDeposit=100000\nCurrency=USD\n'
              'Leverage=100\nUseLocal=1\nUseRemote=0\nUseCloud=0\nVisual=0\n'
              'Replace=1\nReplaceReport=1\nShutdownTerminal=1\n'
              f'Report={report.relative_to(ROOT)}\n')
    ini.write_text(config, encoding='utf-16')
    exe = ROOT / 'terminal64.exe'
    started = time.time()
    # Match factory launch semantics; explicit hidden startup, tester section only.
    command = f"$p=Start-Process -FilePath '{exe}' -ArgumentList '/portable','/config:{ini}' -WindowStyle Hidden -PassThru; $p.Id"
    launched = subprocess.run(['powershell.exe', '-NoProfile', '-Command', command], capture_output=True, text=True, check=True)
    launch_pid = int(launched.stdout.strip())
    print(json.dumps({'stage': 'launched', 'name': name, 'pid': launch_pid}), flush=True)
    report_seen = None
    stable = 0
    previous_size = None
    evidence = {'name': name, 'started_at_epoch': started, 'ini_sha256': sha(ini), 'report': str(report),
                'model': 4, 'fixture_from_date': from_date,
                'quality_scope': f'native EURUSD {from_date}..2026.09.05 M5, sample EA unchanged'}
    with (runroot / 'observations.jsonl').open('x', encoding='utf-8') as out:
        try:
            while time.time() - started < 300:
                processes = []
                for proc in psutil.process_iter(['pid', 'exe', 'create_time', 'cmdline']):
                    if (proc.info['exe'] or '').lower() in (str(exe).lower(), str(ROOT / 'metatester64.exe').lower()) or is_lab_updater(proc.info):
                        processes.append(proc)
                size = report.stat().st_size if report.is_file() else 0
                if size and report_seen is None:
                    report_seen = time.time() - started
                    print(json.dumps({'stage': 'report_first_byte', 'seconds': report_seen, 'size': size}), flush=True)
                stable = stable + 1 if size and size == previous_size else 0
                previous_size = size
                logs = list(ROOT.glob('Tester/Agent-*/logs/*.log'))
                markers = []
                if logs:
                    latest = max(logs, key=lambda p: p.stat().st_mtime)
                    markers = [line for line in tail(latest).splitlines() if any(x in line for x in ('thread finished', 'Test passed in', 'real ticks', 'final balance'))][-6:]
                observation = {'at_epoch': time.time(), 'elapsed': time.time() - started, 'size': size,
                               'pids': [p.pid for p in processes], 'markers': markers}
                out.write(json.dumps(observation) + '\n'); out.flush()
                if not processes and time.time() - started > 15:
                    evidence['natural_exit'] = True
                    break
                time.sleep(2)
        finally:
            # Only own fresh, exact-path lab processes; never root T11/factory/live.
            killed = []
            for proc in psutil.process_iter(['exe', 'create_time', 'cmdline']):
                if ((proc.info['exe'] or '').lower() in (str(exe).lower(), str(ROOT / 'metatester64.exe').lower()) or is_lab_updater(proc.info)) and proc.info['create_time'] >= started - 1:
                    try:
                        proc.kill(); killed.append(proc.pid)
                    except psutil.NoSuchProcess:
                        pass
            evidence.update({'elapsed_seconds': time.time() - started, 'report_first_byte_seconds': report_seen,
                             'report_size_bytes': report.stat().st_size if report.exists() else 0,
                             'report_sha256': sha(report) if report.exists() else None, 'cleanup_pids': killed,
                             'terminal_sha256_after': sha(exe)})
            (runroot / 'result.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
            print(json.dumps(evidence), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['setup', 'run'])
    parser.add_argument('--name', default='baseline1')
    parser.add_argument('--report-subdir', action='store_true')
    parser.add_argument('--from-date', choices=['2026.09.01', '2026.09.02'], default='2026.09.01')
    args = parser.parse_args()
    if args.action == 'setup':
        setup()
    else:
        run(args.name, args.report_subdir, args.from_date)
