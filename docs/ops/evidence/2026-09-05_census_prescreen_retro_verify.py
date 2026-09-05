"""Read-only reconciliation: physical holds, validated skips, unchanged gate formula."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sqlite3
import subprocess
import sys

ROOT=Path('C:/QM/repo');CODE=Path('C:/QM/worktrees/codex-lock-attribution-20260905')
OUT=ROOT/'docs/ops/evidence/2026-09-05_census_prescreen_retro'
sys.path.insert(0,str(CODE))
from tools.strategy_farm import dl089_prescreen_retro as retro, rebaseline_census as revised, opt_census_select as selector
spec=importlib.util.spec_from_file_location('canonical_rebaseline_reference',ROOT/'tools/strategy_farm/rebaseline_census.py')
canonical=importlib.util.module_from_spec(spec);spec.loader.exec_module(canonical)
plan=json.loads((OUT/'dry_run.json').read_text())
con=sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True)
con.row_factory=sqlite3.Row;con.execute('BEGIN')
held=[dict(r) for r in con.execute("SELECT w.* FROM work_item_holds h JOIN work_items w ON w.id=h.work_item_id WHERE h.hold_code='PRESCREEN_SKIPPED' AND h.active=1 AND h.release_on_restart=0")]
assert all(r['status']=='pending' and r['verdict'] is None and r['claimed_by'] is None for r in held)
reader=selector._default_metric_reader(con)
assert all(reader(r['id'])[0]=='SKIPPED_EXCLUDED' for r in held)
events=[dict(r) for r in con.execute('SELECT * FROM events WHERE entity_type=? AND event=?',(retro.ENTITY,retro.EVENT))]
assert len(events)==len(plan['programs']) and len({r['entity_id'] for r in events})==len(events)
receipts=[]
for e in events:
    binding=json.loads(e['detail_json']);path=Path(binding['receipt_path'])
    assert retro.sha(path)==binding['receipt_sha256']
    receipt=json.loads(path.read_text());receipts.append(receipt)
    assert retro.digest(retro.declaration(json.loads(Path(receipt['ledger_path']).read_text())))==receipt['declaration_sha256']
    for c in json.loads(Path(receipt['ledger_path']).read_text())['cells']:
        assert con.execute('SELECT 1 FROM work_items WHERE id=?',(c['work_item_id'],)).fetchone()
assert sum(len(r['held_targets']) for r in receipts)==len(held)
reference=canonical.compute(con,None)
projection=revised.compute(con,None)
a=dict(reference['summary']);b=dict(projection['summary'])
a.pop('opt_census_prescreen',None);progress=b.pop('opt_census_prescreen')
assert a==b and reference['pair_rows']==projection['pair_rows'] and reference['finer_rows']==projection['finer_rows']
assert progress['valid_held_cells']==len(held)
con.close()
result={'schema':retro.SCHEMA,'task_id':retro.TASK,'read_only_database':True,
        'dry_run_sha256':retro.sha(OUT/'dry_run.json'),'code_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=CODE).decode().strip(),
        'planned_holds':plan['planned_holds'],'physical_active_nonrestart_holds':len(held),
        'all_held_rows_pending_unclaimed_no_verdict':True,'validated_unmeasured_skips':progress['valid_held_cells'],
        'program_receipt_rows':len(events),'all_declarations_and_declared_rows_preserved':True,
        'same_snapshot_gate_contiguity_and_pair_rows_unchanged':True,'reference_gate_summary':a,'progress':progress,
        'programs':[{'program_id':r['program_id'],'classification_counts':r['classification_counts'],
                     'planned_holds':r['candidate_holds'],'held':len(r['held_targets']),'raced_targets_preserved':r['raced_targets_preserved']} for r in receipts],
        'tests':{'initial_focused':40,'consumer_regression':154},'production_consumer_patch_integrated':(ROOT/'tools/strategy_farm/dl089_prescreen_retro.py').exists()}
with (OUT/'reconciliation.json').open('x',encoding='utf-8') as f:json.dump(result,f,indent=2,sort_keys=True);f.write('\n')
print(json.dumps({k:result[k] for k in ['planned_holds','physical_active_nonrestart_holds','validated_unmeasured_skips','program_receipt_rows','same_snapshot_gate_contiguity_and_pair_rows_unchanged','production_consumer_patch_integrated']},indent=2))
