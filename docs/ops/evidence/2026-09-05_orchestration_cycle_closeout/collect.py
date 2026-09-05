"""Read final cycle receipts and task states; do not route or change the queue."""
from pathlib import Path
from collections import Counter
import datetime as dt
import hashlib
import json
import sqlite3

HERE = Path(__file__).resolve().parent
TASKS = [
    ('efa156a4-c8e9-4f31-b9c2-b7e58bbe18ab', 'Archive retest collapse', '676f5e61f4'),
    ('74b400f5-6b98-45f1-8f3a-09aeda91f3e8', 'Compile authority bindings', '30928b0799'),
    ('f22f9a8c-1ef1-4897-8ab5-1644c7457030', 'Claim lock cost', '0322998ead'),
    ('b74e58e7-da8c-42c1-87ec-ade75db377dc', 'DXZ history harvest', 'fb0b58d980 + f6e796dabf'),
    ('9f80f58c-2faa-4dfe-a35a-bd019771779f', 'Default-off identity consumer', '6afebd8ece'),
    ('a3ec5b69-ae8f-475c-b939-2c9b04224761', 'Canonical setfile apply helper', 'a237868228'),
    ('90ca3dc0-3137-4a22-8179-450170069b4e', 'Website v5 critique', 'a45a33c188'),
    ('2de2ad78-5327-4e4e-9eea-13f82ac9ffd8', 'Funnel design and implementation', 'a45a33c188'),
]

def read_json(p):
    b=p.read_bytes()
    return json.loads(b.decode('utf-16' if b.startswith(b'\xff\xfe') else 'utf-8-sig'))

health = read_json(HERE/'health.json')
queue = read_json(HERE/'QM5_10260_queue.json')
with sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True) as conn:
    conn.row_factory=sqlite3.Row
    tasks=[]
    for tid,title,commit in TASKS:
        row=conn.execute('SELECT id, state, priority, assigned_agent, artifact_path, verdict, updated_at FROM agent_tasks WHERE id=?',(tid,)).fetchone()
        assert row is not None,tid
        rec=dict(row)
        artifact=Path(rec['artifact_path']) if rec['artifact_path'] else None
        if artifact and not artifact.is_absolute(): artifact=Path('C:/QM/repo')/artifact
        assert artifact and artifact.is_file(),tid
        rec.update(title=title,artifact_commit=commit)
        tasks.append(rec)

report={
    'recorded_utc':dt.datetime.now(dt.UTC).isoformat(),
    'cycle':'one scheduled orchestration pass; no cadence loop',
    'canonical_control_plane':'C:/QM/repo/tools/strategy_farm',
    'tasks_handled':tasks,
    'router_list_in_progress_after_updates':[],
    'health':health,
    'queue_QM5_10260':{
        'count':queue['count'],
        'status_counts':dict(Counter(i['status'] for i in queue['items'])),
        'unfinished':[i for i in queue['items'] if i['status'] not in ('done','failed','cancelled')],
        'phase_summary':queue['summary']
    },
    'raw_receipt_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (HERE/'health.json',HERE/'QM5_10260_queue.json')}
}
(HERE/'cycle.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps({
    'recorded_utc':report['recorded_utc'],
    'tasks':[{'id':t['id'],'priority':t['priority'],'state':t['state']} for t in tasks],
    'health_top':{k:v for k,v in health.items() if k!='checks'},
    'health_failures':[c for c in health.get('checks',[]) if c.get('status') in ('FAIL','fail')],
    'queue':report['queue_QM5_10260']
},indent=2,ensure_ascii=False))
