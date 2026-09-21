"""Read-only inventory for the OWNER's Break/Retest + NNFX research order.

Writes evidence only to --out. Does not change the farm, registries or verdicts.
"""
import argparse
import collections
import csv
import datetime as dt
import hashlib
import json
import sqlite3
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', type=Path, required=True)
    ap.add_argument('--db', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    reg = args.repo / 'framework/registry/ea_id_registry.csv'
    rows = list(csv.DictReader(reg.open(encoding='utf-8-sig')))
    matched = {}
    for row in rows:
        if not any(s in row['slug'].lower() for s in ('nnfx', 'retest')):
            continue
        eid = row['ea_id']
        eid = eid if eid.startswith('QM5_') else 'QM5_' + eid
        matched.setdefault(eid, []).append(row)
    conn = sqlite3.connect(args.db.resolve().as_uri() + '?mode=ro', uri=True)
    conn.row_factory = sqlite3.Row
    conn.execute('BEGIN')
    task_rows = [dict(r) for r in conn.execute('SELECT * FROM agent_tasks')]
    evidence = []
    for eid, registry_rows in matched.items():
        work = [dict(r) for r in conn.execute(
            'SELECT id,phase,symbol,status,verdict,evidence_path,created_at,updated_at,'
            'ex5_sha256,setfile_sha256,gate_contract_version FROM work_items WHERE ea_id=?', (eid,))]
        groups = collections.Counter((w['phase'], w['symbol'], w['status'], w['verdict']) for w in work)
        strategic = [w for w in work if w['status'] == 'done' and w['phase'].startswith('Q')
                     and w['verdict'] and (w['verdict'].startswith('PASS') or w['verdict'].startswith('FAIL'))
                     and w['verdict'] not in ('FAIL_INFRA',)]
        dirs = sorted((args.repo / 'framework/EAs').glob(eid + '_*'))
        files = []
        for d in dirs:
            for pat in ('*.mq5', '*.ex5', 'SPEC.md'):
                for p in d.glob(pat):
                    files.append({'path': str(p), 'sha256': sha(p), 'size': p.stat().st_size})
        linked = []
        for task in task_rows:
            payload = json.loads(task['payload_json'] or '{}')
            # Explicit identity or boundary match; never QM5_2001 -> QM5_20010.
            import re
            hit = re.search(re.escape(eid) + r'(?!\d)', task['payload_json'] or '')
            hit = hit or str(payload.get('ea_id', '')).removeprefix('QM5_') == eid.removeprefix('QM5_')
            if hit:
                linked.append({k: task[k] for k in ('id','task_type','state','priority','assigned_agent','artifact_path','verdict','updated_at')})
        evidence.append({'ea_id': eid, 'slug': registry_rows[0]['slug'], 'registry_rows': registry_rows,
                         'work_item_count': len(work), 'economic_verdict_row_count': len(strategic),
                         'classification': 'NO_WORK_ITEMS_IN_CURRENT_LEDGER' if not work else
                         ('ECONOMIC_VERDICTS_EXIST' if strategic else 'QUEUED_OR_TECHNICAL_ONLY'),
                         'groups': [dict(zip(('phase','symbol','status','verdict','count'), (*k,v))) for k,v in groups.items()],
                         'latest_economic_evidence': sorted(strategic, key=lambda w:w['updated_at'])[-4:],
                         'work_items': work, 'files': files, 'linked_agent_tasks': linked})
    conn.rollback()
    conn.close()
    nnfx = [r for r in evidence if 'nnfx' in r['slug']]
    retest = [r for r in evidence if 'retest' in r['slug']]
    summary = {'nnfx_count': len(nnfx), 'retest_count': len(retest),
               'nnfx_no_work_items': [r['ea_id'] for r in nnfx if not r['work_item_count']],
               'nnfx_no_economic_verdict': [r['ea_id'] for r in nnfx if not r['economic_verdict_row_count']],
               'retest_no_work_items_active': [r['ea_id'] for r in retest if not r['work_item_count']
                                              and any(x['status']=='active' for x in r['registry_rows'])]}
    doc = {'schema':'qm.ftmo-br-nnfx-intake-inventory/v1',
           'captured_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
           'db': str(args.db), 'registry_path': str(reg), 'registry_sha256': sha(reg),
           'scope': 'Slug-matched NNFX/retest identities; current work_items ledger, not proof that no archived or external tests exist. Historical verdicts are not current deployability.',
           'summary': summary, 'strategies': evidence}
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out/'inventory.json').write_text(json.dumps(doc,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(summary,indent=2))


if __name__ == '__main__':
    main()
