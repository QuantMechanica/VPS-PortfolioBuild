from pathlib import Path
import datetime as dt
import hashlib
import json
import sqlite3
import time

OUT=Path(__file__).resolve().parent
queries=json.loads((OUT/'sweep_queries.json').read_text())
source=next(r for r in queries if 'SELECT id,status,payload_json,updated_at' in r['sql'])
old=source['sql'];new=old.replace('FROM work_items','FROM work_items INDEXED BY idx_work_items_ea_phase',1)
c=sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True)
c.execute('PRAGMA query_only=ON');c.execute('BEGIN')
keys=[]
for r in queries:
    if 'SELECT x.ea_id, x.symbol, x.setfile_path, MAX(x.updated_at), COUNT(*)' in r['sql']:
        phase=r['example_parameters'][0]
        for ea,symbol,setfile,*_ in c.execute(r['sql'],r['example_parameters']).fetchall():
            keys.append((ea,phase,symbol,setfile))
results={};prior=None
for label,sql in [('before',old),('after',new)]:
    started=time.perf_counter();selected=[c.execute(sql,key).fetchone() for key in keys]
    results[label]={'seconds':round(time.perf_counter()-started,6),'lookups':len(keys),
        'result_sha256':hashlib.sha256(json.dumps(selected,sort_keys=True).encode()).hexdigest(),
        'query_plan':c.execute('EXPLAIN QUERY PLAN '+sql,keys[0]).fetchall()}
    if prior is not None:assert selected==prior
    prior=selected
c.rollback()
(OUT/'source_lookup_equivalence.json').write_text(json.dumps({'captured_at':dt.datetime.now(dt.timezone.utc).isoformat(),
    'read_only_single_snapshot':True,'identical':True,'results':results,'keys':keys},indent=2)+'\n',encoding='utf-8')
print(json.dumps(results,indent=2))
