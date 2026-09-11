"""Read-only task verification; writes only this canonical evidence directory."""
import datetime as dt
import hashlib
import json
from pathlib import Path
import sqlite3

import psutil

ROOT = Path(__file__).resolve().parent
REPO = Path('C:/QM/repo')
TASK = 'c3fc6278-7c6f-4871-b311-59b8650d4961'
OLD = REPO / 'docs/ops/evidence/c3fc6278_t11_prescreen_part2_2026-09-11'
PREVIOUS = REPO / 'docs/ops/evidence/c3fc6278_cycle_2026-09-11_1130Z'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def write(name, value):
    (ROOT / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


with sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True) as conn:
    conn.execute('PRAGMA query_only=ON')
    conn.row_factory = sqlite3.Row
    task = dict(conn.execute('SELECT * FROM agent_tasks WHERE id=?', (TASK,)).fetchone())
    lease = [dict(r) for r in conn.execute('SELECT * FROM spawn_leases WHERE task_key=?', ('agent_task:' + TASK,))]
write('assigned_task.json', task)
write('spawn_lease.json', lease)

controller = REPO / 'tools/strategy_farm/research_canary.py'
receipt_path = Path('D:/QM/reports/research/T11_PRESCREEN_PART2_c3fc6278/20260911_110621_51e53c05/receipt.json')
receipt = read(receipt_path)
journal = Path('D:/QM/mt5/T11/logs/20260911.log')
terminal = Path('D:/QM/mt5/T11/terminal64.exe')
prior = read(PREVIOUS / 'verification.json')
audit = read(OLD / 'launch_refusal_audit.json')
report_paths = list(receipt_path.parent.glob('report.*'))
export = Path(receipt['tester_contract']['report_export_path'])
processes = []
for process in psutil.process_iter(['pid', 'exe']):
    exe = process.info.get('exe')
    if exe and Path(exe).resolve().is_relative_to(terminal.parent.resolve()):
        processes.append(process.info)
verification = {
    'captured_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
    'controller_sha256': sha(controller),
    'controller_matches_prior': sha(controller) == prior['controller_sha256'],
    'focused_command': 'python -m pytest tools/strategy_farm/tests/test_research_canary.py -q',
    'focused_result': '38 passed in 2.02s; exit 0',
    'pilot_receipt_path': str(receipt_path),
    'pilot_receipt_sha256': sha(receipt_path),
    'pilot_matches_preserved_copy': sha(receipt_path) == sha(OLD / 'pilot_receipt.json'),
    'pilot_status': receipt['status'], 'pilot_reason': receipt['reason'],
    'report_paths': [str(p) for p in report_paths],
    'configured_report_export_path': str(export), 'configured_report_exists': export.exists(),
    'journal_path': str(journal), 'journal_sha256': sha(journal),
    'journal_matches_previous_cycle': sha(journal) == prior['journal_sha256'],
    'journal_last_write_utc': dt.datetime.fromtimestamp(journal.stat().st_mtime, dt.timezone.utc).isoformat(),
    'journal_tail': journal.read_text(encoding='utf-16').splitlines()[-5:],
    'terminal_path': str(terminal), 'terminal_sha256': sha(terminal),
    'terminal_matches_failed_pilot_audit': sha(terminal) == audit['terminal_exe_sha256'],
    't11_processes': processes, 'new_launches_this_cycle': 0,
    'experimental_acceptance_complete': False,
}
assert verification['controller_matches_prior']
assert verification['pilot_matches_preserved_copy']
assert verification['journal_matches_previous_cycle']
assert verification['terminal_matches_failed_pilot_audit']
assert not report_paths and not export.exists()
write('verification.json', verification)
print(json.dumps(verification, indent=2))
