"""Execute only dry-run CLI paths and retain the nine exact responses."""
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import sys

out=Path(__file__).resolve().parent
branch=Path('C:/QM/worktrees/codex-canonical-paths-apply-20260905')
sys.path[:0]=[str(branch),str(branch/'tools/strategy_farm')]
from tools.strategy_farm import canonical_setfile_apply as repair
ids=sorted(repair.PREVIEW_HASHES)


def snapshot():
    with sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True) as c:
        c.execute('PRAGMA query_only=ON')
        result={}
        for table,column in [('work_items','id'),('work_item_holds','work_item_id'),('work_item_supersedes','work_item_id')]:
            rows=c.execute('SELECT * FROM '+table+' WHERE '+column+' IN ('+','.join('?' for _ in ids)+') ORDER BY '+column,ids).fetchall()
            result[table]=hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest()
        return result


before=snapshot();summary=[]
for item_id in ids:
    command=[sys.executable,str(branch/'tools/strategy_farm/canonical_setfile_paths.py'),'apply','--work-item-id',item_id]
    result=subprocess.run(command,cwd=branch,capture_output=True,text=True,timeout=60)
    if result.returncode not in (0,2):raise RuntimeError(result.stderr)
    doc=json.loads(result.stdout)
    assert doc['dry_run'] and not doc['applied']
    (out/(item_id+'.json')).write_text(json.dumps({'command':command,'exit_code':result.returncode,'result':doc},indent=2)+'\n')
    summary.append({'id':item_id,'eligible':doc['eligible'],'reason':doc['rows'][0].get('reason')})
command=[sys.executable,str(branch/'tools/strategy_farm/canonical_setfile_paths.py'),'apply','--all-previewed']
result=subprocess.run(command,cwd=branch,capture_output=True,text=True,timeout=60)
assert result.returncode in (0,2)
(out/'all_previewed.json').write_text(result.stdout)
after=snapshot()
assert before==after, 'Observed queue drift while reading; inspect before claiming stability'
verification={'result':'PASS','read_only_rows_unchanged':True,'before':before,'after':after,
              'individual_dry_runs':summary,'total':len(ids),'eligible':sum(r['eligible'] for r in summary),
              'canonical_apply_executed':False}
(out/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
print(json.dumps(verification,indent=2))
