"""Time only the sweep's exact stranded SELECTs on a read-only connection."""
from pathlib import Path
import ast
import datetime as dt
import json
import sqlite3
import sys
import time

OUT=Path(__file__).resolve().parent
sys.path.insert(0,'C:/QM/repo/tools/strategy_farm')
from phase_ids import PHASE_ORDER,phase_rank
tree=ast.parse(Path('C:/QM/repo/tools/strategy_farm/sweep_enqueue_built_eas.py').read_text())
node=next(n for n in ast.walk(tree) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='stranded_rows' for t in n.targets))
sqlnode=node.value.func.value.args[0]
sqlcode=compile(ast.Expression(sqlnode),'sweep-select','eval')
conn=sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True);conn.execute('PRAGMA query_only=ON')
results=[]
for phase in ('Q02','Q03','Q04','Q07','Q08'):
    params=[phase];target_filter='';deeper_filter=''
    deeper_phases=tuple(x for x in PHASE_ORDER if phase_rank(x)>phase_rank(phase))
    if deeper_phases:
        deeper_filter=('AND NOT EXISTS (SELECT 1 FROM work_items z WHERE z.ea_id=x.ea_id AND z.symbol=x.symbol AND z.phase IN (%s))') % ','.join('?' for _ in deeper_phases)
        params.extend(deeper_phases)
    sql=eval(sqlcode,{'target_filter':target_filter,'deeper_filter':deeper_filter})
    started=time.monotonic();conn.set_progress_handler(lambda:int(time.monotonic()-started>25),10000)
    plan=conn.execute('EXPLAIN QUERY PLAN '+sql,params).fetchall()
    try:rows=conn.execute(sql,params).fetchall();error=None
    except sqlite3.Error as exc:rows=[];error=str(exc)
    results.append({'phase':phase,'seconds':round(time.monotonic()-started,6),'rows':len(rows),'error':error,'plan':plan,'sql':sql,'parameters':params})
    print(phase,results[-1]['seconds'],len(rows),error,flush=True)
(OUT/'sweep_select_profile.json').write_text(json.dumps({'captured_at':dt.datetime.now(dt.timezone.utc).isoformat(),'readonly':True,'results':results},indent=2)+'\n',encoding='utf-8')
