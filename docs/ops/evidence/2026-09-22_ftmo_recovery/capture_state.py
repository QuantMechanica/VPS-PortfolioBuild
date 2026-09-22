"""Read-only census for the OWNER's BR/NNFX recovery packs."""
from __future__ import annotations

import csv
import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

REPO = Path('C:/QM/repo')
FARM = Path('D:/QM/strategy_farm')
IDS = (9241, 12038, 20078, 11963, 11964, 11965, 36001, 36003, 36004, 36008)


def file_record(path: Path) -> dict:
    return {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size}


def main() -> None:
    conn = sqlite3.connect(f'file:{FARM.as_posix()}/state/farm_state.sqlite?mode=ro', uri=True)
    conn.row_factory = sqlite3.Row
    magic = list(csv.DictReader((REPO / 'framework/registry/magic_numbers.csv').open(encoding='utf-8-sig')))
    rows = []
    for ea_id in IDS:
        label = f'QM5_{ea_id}'
        dirs = list((REPO / 'framework/EAs').glob(label + '_*'))
        cards = {state: [file_record(p) for p in (FARM / 'artifacts' / state).glob(label + '_*.md')]
                 for state in ('cards_approved', 'cards_rejected')}
        files = [file_record(p) for d in dirs for p in d.rglob('*')
                 if p.is_file() and p.suffix in ('.mq5', '.ex5', '.set')]
        tasks = [dict(r) for r in conn.execute('SELECT * FROM agent_tasks WHERE payload_json LIKE ?',
                                             (f'%"ea_id":"{ea_id}"%',))]
        engine_tasks = [dict(r) for r in conn.execute('SELECT * FROM tasks WHERE card_id LIKE ?', (label + '%',))]
        work = [dict(r) for r in conn.execute('SELECT * FROM work_items WHERE ea_id=?', (label,))]
        rows.append({'ea_id': ea_id, 'cards': cards, 'files': files,
                     'active_magic': [r for r in magic if r['ea_id'].removeprefix('QM5_') == str(ea_id)
                                      and r['status'] == 'active'],
                     'agent_tasks': tasks, 'engine_tasks': engine_tasks, 'work_items': work})
    dest = Path(__file__).with_name('baseline.json')
    dest.write_text(json.dumps({'schema': 'qm.ftmo-recovery-census/v1',
                              'at_utc': datetime.now(timezone.utc).isoformat(), 'rows': rows}, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'written': str(dest), 'summary': [
        {'ea_id': r['ea_id'], 'magics': len(r['active_magic']), 'work_items': len(r['work_items']),
         'engine_tasks': [{'id': t['id'], 'status': t['status'], 'kind': t['kind']} for t in r['engine_tasks']]}
        for r in rows]}, indent=2))


if __name__ == '__main__':
    main()
