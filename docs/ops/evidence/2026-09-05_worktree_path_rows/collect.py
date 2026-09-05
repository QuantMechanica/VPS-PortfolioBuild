from pathlib import Path
import datetime as dt
import hashlib
import json
import sqlite3
import sys
import subprocess

OUT=Path(__file__).resolve().parent
sys.path[:0]=['C:/QM/worktrees/codex-worktree-paths-20260905/tools/strategy_farm','C:/QM/repo/tools/strategy_farm']
from canonical_setfile_paths import pending_successor_proposal
import farmctl


def main():
    c=sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True);c.row_factory=sqlite3.Row;c.execute('PRAGMA query_only=ON')
    raw=[dict(r) for r in c.execute("SELECT * FROM work_items WHERE status='pending' AND lower(replace(setfile_path,char(92),'/')) LIKE 'c:/qm/worktrees/%'")]
    rows=[]
    for row in raw:
        plan=pending_successor_proposal(row)
        ex5=Path(plan['canonical_ex5_path']);setfile=Path(plan['canonical_setfile_path'])
        plan['canonical_ex5_mtime_utc']=dt.datetime.fromtimestamp(ex5.stat().st_mtime,dt.timezone.utc).isoformat() if ex5.is_file() else None
        plan['mtime_is_not_compile_receipt']=True
        plan['fixed_risk_contract']=farmctl._q02_fixed_risk_contract(str(setfile)) if setfile.is_file() else [False,{'reason':'missing'}]
        plan['holds']=[dict(r) for r in c.execute('SELECT * FROM work_item_holds WHERE work_item_id=?',(row['id'],))]
        plan['existing_successors']=[dict(r) for r in c.execute('SELECT * FROM work_item_supersedes WHERE work_item_id=?',(row['id'],))]
        plan['latest_compile_rows']=[dict(r) for r in c.execute("SELECT id,status,verdict,evidence_path,updated_at,ex5_sha256,build_id FROM work_items WHERE ea_id=? AND phase='COMPILE_EA' ORDER BY updated_at DESC LIMIT 3",(row['ea_id'],))]
        plan['preview_command']='python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id '+row['id']
        plan['command_availability']='PROPOSAL_BRANCH_ONLY_UNTIL_INTEGRATED'
        target=OUT/(row['id']+'.json');target.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8')
        rows.append(plan)
    result={'captured_at':dt.datetime.now(dt.timezone.utc).isoformat(),'read_only':True,'rows':rows,'predecessors':raw}
    (OUT/'inventory.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps([{'id':r['source_work_item_id'],'ea':r['ea_id'],'phase':r['phase'],'canonical_exists':bool(r['canonical_setfile_sha256']),'ex5':r['canonical_ex5_sha256'],'mtime':r['canonical_ex5_mtime_utc'],'blockers':r['blockers'],'risk':r['fixed_risk_contract']} for r in rows],indent=2))


if __name__=='__main__':main()
