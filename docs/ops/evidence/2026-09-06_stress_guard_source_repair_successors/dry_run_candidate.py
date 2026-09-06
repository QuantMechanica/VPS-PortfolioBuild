"""Run the canonical CLI dry-run with the isolated candidate module in memory.
No canonical source replacement; --apply and positional labels are never used.
"""
from pathlib import Path
import contextlib,importlib.util,io,json,runpy,sqlite3,sys,hashlib
REPO=Path('C:/QM/repo')
OUT=REPO/'docs/ops/evidence/2026-09-06_stress_guard_source_repair_successors'
MODULE=Path('C:/QM/worktrees/codex-stress-guard-successors-20260906/tools/strategy_farm/compile_work_items.py')
sys.path[:0]=[str(REPO/'tools/strategy_farm'),str(REPO)]
spec=importlib.util.spec_from_file_location('compile_work_items',MODULE);module=importlib.util.module_from_spec(spec);sys.modules['compile_work_items']=module;spec.loader.exec_module(module)
def snapshot():
 with sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True) as c:
  c.row_factory=sqlite3.Row
  return [dict(r) for r in c.execute("select * from work_items where phase='COMPILE_EA' and ea_id in ('QM5_41171','QM5_41358','QM5_41359','QM5_41360','QM5_41361','QM5_41362') order by id")]
before=snapshot();results=[]
for authority,binding in module.STRESS_GUARD_SOURCE_REPAIR_REGISTRATIONS.items():
 args=['C:/QM/repo/tools/strategy_farm/farmctl.py','enqueue-compile','--from-file',str(OUT/f"QM5_{binding['ea_id']}.txt"),'--source-repair-authority',authority]
 assert '--apply' not in args
 sys.argv=args;buf=io.StringIO();code=0
 with contextlib.redirect_stdout(buf):
  try:runpy.run_path(args[0],run_name='__main__')
  except SystemExit as e:code=e.code or 0
 raw=buf.getvalue();(OUT/f"dry_run_QM5_{binding['ea_id']}.json").write_text(raw,encoding='utf-8')
 result=json.loads(raw);results.append({'ea_id':binding['ea_id'],'exit_code':code,'result':result})
 print(binding['ea_id'],'exit',code,'eligible',result.get('eligible_count'),'refused',result.get('refused_count'),flush=True)
after=snapshot()
summary={'method':'canonical farmctl CLI with isolated candidate compile_work_items module loaded in memory','candidate_module_path':str(MODULE),'candidate_module_sha256':hashlib.sha256(MODULE.read_bytes()).hexdigest(),'compile_rows_unchanged':before==after,'before_compile_rows':len(before),'after_compile_rows':len(after),'apply':False,'runs':[{'ea_id':r['ea_id'],'exit_code':r['exit_code'],'eligible_count':r['result'].get('eligible_count'),'candidate_classification':r['result'].get('candidate_classification')} for r in results]}
(OUT/'dry_run_summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
assert before==after,'Concurrent predecessor drift; do not claim unchanged'
