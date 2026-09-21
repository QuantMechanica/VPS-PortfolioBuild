"""Commission exactly the reviewed packet file through the canonical router API.

No EA work_items, verdicts, gates or existing task rows are mutated here. Sequential
re-execution reuses programme/packet keys; do not run concurrent schedulers for this file.
"""
import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', type=Path, required=True)
    ap.add_argument('--root', type=Path, required=True)
    ap.add_argument('--packets', type=Path, required=True)
    ap.add_argument('--receipt', type=Path, required=True)
    args = ap.parse_args()
    packet_bytes = args.packets.read_bytes()
    spec = json.loads(packet_bytes)
    assert len(spec['packets']) == 7
    assert len({p['packet_key'] for p in spec['packets']}) == 7
    for p in spec['packets']:
        assert (args.repo / p['payload']['plan_path']).is_file()
        assert (args.repo / p['payload']['owner_directive']).is_file()
    sys.path.insert(0, str(args.repo / 'tools/strategy_farm'))
    import agent_router

    db = args.root/'state/farm_state.sqlite'
    receipt = {'schema':'qm.ftmo-br-nnfx-scheduling-receipt/v1',
               'programme_id':spec['programme_id'], 'db':str(db),
               'packet_file_sha256':hashlib.sha256(packet_bytes).hexdigest(),
               'created_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
               'method':'agent_router.enqueue_task, lane pin in payload; no worker launched',
               'tasks':[]}
    for p in spec['packets']:
        conn = sqlite3.connect(db.resolve().as_uri()+'?mode=ro', uri=True)
        conn.row_factory = sqlite3.Row
        found = []
        for row in conn.execute('SELECT id,state,payload_json FROM agent_tasks WHERE payload_json LIKE ?',
                                ('%'+spec['programme_id']+'%',)):
            payload = json.loads(row['payload_json'] or '{}')
            if payload.get('programme_id') == spec['programme_id'] and payload.get('packet_key') == p['packet_key']:
                found.append(dict(row))
        conn.close()
        if len(found) > 1:
            raise RuntimeError('Duplicate packet key: '+p['packet_key'])
        if found:
            result = {'task_id':found[0]['id'], 'state':found[0]['state'], 'reused':True}
        else:
            result = agent_router.enqueue_task(args.root, p['task_type'], state=p['state'],
                        priority=p['priority'], payload=p['payload'], assigned_agent=p['assigned_agent'])
        receipt['tasks'].append({'packet_key':p['packet_key'], 'lane_pin':p['assigned_agent'],
                                 'priority':p['priority'], **result})
        args.receipt.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(receipt['tasks'][-1]))


if __name__ == '__main__':
    main()
