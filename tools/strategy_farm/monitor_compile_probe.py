"""One task-specific, artifact-only native MetaEditor probe. Never runs a terminal."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import subprocess

from include_mirror import validate_monitor_probe_contract

ROOT = Path('C:/QM/repo/docs/ops/evidence/2026-09-06_ftmo_collector_native_acceptance/compile_probe')
DB = Path('D:/QM/strategy_farm/state/farm_state.sqlite')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'contract.json').read_text(encoding='utf-8'))
    with sqlite3.connect(DB.as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        row = db.execute('SELECT id, assigned_agent, state FROM agent_tasks WHERE id=?', (manifest['task_id'],)).fetchone()
    validate_monitor_probe_contract(manifest, dict(row or {}), ROOT)
    report = {'schema': 'qm.monitor-compile-probe-result/v1', 'contract': manifest,
              'terminal_installed': False, 'native_tester': 'NOT_RUN', 'compiles': []}
    if not args.execute:
        print(json.dumps({'status': 'ELIGIBLE', 'contract': manifest}, indent=2))
        return
    # Exclusive create is deliberately not automatically reclaimed after a crash.
    with (ROOT / 'probe.lock').open('x', encoding='utf-8') as lock:
        lock.write(manifest['task_id'])
    try:
        for name in ('QM_FTMO_TrialTelemetry', 'QM_FTMO_TrialTelemetryAcceptance'):
            validate_monitor_probe_contract(manifest, dict(row), ROOT)
            source = ROOT / 'MQL5' / (name + '.mq5')
            binary = source.with_suffix('.ex5')
            if binary.exists():
                raise RuntimeError('Fresh output required: ' + str(binary))
            command = [str(ROOT / 'editor/MetaEditor64.exe'), '/portable', '/compile:' + str(source), '/include:' + str(ROOT / 'MQL5'), '/log']
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
            process = subprocess.run(command, cwd=ROOT / 'editor', startupinfo=startup,
                                     creationflags=subprocess.CREATE_NO_WINDOW, timeout=120, capture_output=True)
            log = source.with_suffix('.log')
            log_text = log.read_text(encoding='utf-16', errors='replace') if log.exists() else ''
            passed = binary.is_file() and bool(re.search(r'Result: 0 errors, 0 warnings', log_text))
            report['compiles'].append({'source': source.name, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'status': 'PASS' if passed else 'FAIL', 'returncode': process.returncode,
                'ex5_sha256': hashlib.sha256(binary.read_bytes()).hexdigest() if binary.exists() else None, 'log': log.name})
        report['status'] = 'PASS' if all(c['status'] == 'PASS' for c in report['compiles']) else 'FAIL'
        (ROOT / 'result.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(report, indent=2))
    finally:
        (ROOT / 'probe.lock').unlink()


if __name__ == '__main__':
    main()
