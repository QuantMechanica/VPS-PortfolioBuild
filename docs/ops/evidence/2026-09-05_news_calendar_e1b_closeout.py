"""Read-only proof capture for router-assigned E1-B1/B2; no calendar publisher."""
from collections import Counter
import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

CANON=Path('C:/QM/repo')
EVIDENCE=CANON/'docs/ops/evidence'
DATA_CODE=Path('C:/QM/worktrees/codex-lock-attribution-20260905')
CONTROL_CODE=Path('C:/QM/worktrees/codex-calendar-control-20260905')
FINAL=Path('D:/QM/reports/news_calendar/repair_e1a/20260905T102700Z_e1b2_candidates')
OLD=Path('D:/QM/reports/news_calendar/repair_e1a/20260905T094500Z')
EXPORT=Path('D:/QM/reports/news_calendar/repair_e1a/20260905T102100Z_export_empire/export_receipt.json')

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,value):
    with p.open('x',encoding='utf-8',newline='\n') as f:
        f.write(value if isinstance(value,str) else json.dumps(value,indent=2,sort_keys=True)+'\n')
def git(root,*args):return subprocess.check_output(['git',*args],cwd=root).decode().strip()
def bind(p):return {'path':str(p),'sha256':sha(p),'bytes':p.stat().st_size}

assert git(CANON,'branch','--show-current')=='agents/board-advisor'
data_commit=git(DATA_CODE,'rev-parse','HEAD')
control_commit=git(CONTROL_CODE,'rev-parse','HEAD')
stamp=dt.datetime.now(dt.timezone.utc).isoformat()
data_out=EVIDENCE/'2026-09-05_news_calendar_e1b2_data_completion'
control_out=EVIDENCE/'2026-09-05_news_calendar_e1b1_control_plane'
data_out.mkdir();control_out.mkdir()
manifest=read(FINAL/'manifest.json');verification=read(FINAL/'verification.json')
exports=read(EXPORT)
assert exports['status']=='PASS' and len(exports['exports'])==10
assert all(sha(Path(r['path']))==r['sha256'] for r in exports['exports'])
for name in ['manifest.json','verification.json','nonusd_completeness.csv','e2_e4_gap_inventory.csv','fresh_export_anchor_checks.json','nonusd_offset_decisions.json']:
    shutil.copyfile(FINAL/name,data_out/name)
shutil.copyfile(EXPORT,data_out/'export_receipt.json')
cleanup=Path('D:/QM/reports/news_calendar/repair_e1a/20260905T101200Z_export_catalog/handoff_cleanup.json')
shutil.copyfile(cleanup,data_out/'handoff_cleanup.json')
fallback=sum(r['rows'] for r in read(FINAL/'per_class_transforms.json') if r['transform']=='COMMON_MINUTE_PRIMARY_FALLBACK_UNVERIFIED')
production=[{'path':r['path'],'before_sha256':r['sha256'],'after_sha256':sha(Path(r['path']))} for r in manifest['input_files'][:2]]
assert all(r['before_sha256']==r['after_sha256'] for r in production)
inventory=[bind(p) for p in sorted(FINAL.rglob('*')) if p.is_file()]
data={'task_id':'07add720-26c2-4e30-9c29-e2c801681df9','captured_at':stamp,'code_commit':data_commit,
      'candidate_manifest':bind(FINAL/'manifest.json'),'verification':bind(FINAL/'verification.json'),
      'exports':exports['exports'],'gates':verification['gates'],'primary_fallback_unverified_rows':fallback,
      'production_input_hashes':production,'artifacts':inventory,'tests':{'passed':22},'production_write':False}
write(data_out/'result.json',data)
with (EVIDENCE/'2026-09-05_news_calendar_e1b2_data_completion.patch').open('wb') as f:
    f.write(subprocess.check_output(['git','show','--format=fuller','--binary',data_commit],cwd=DATA_CODE))
rows='\n'.join(f"| {Path(r['path']).name} | {r['rows']} | `{r['sha256']}` |" for r in exports['exports'])
gates='\n'.join(f"| {k} | {'PASS' if v['pass'] else 'FAIL'} |" for k,v in verification['gates'].items())
write(EVIDENCE/'2026-09-05_news_calendar_e1b2_data_completion.md',f'''# E1-B2 native data completion — REVIEW

Task `{data['task_id']}`. Code `{data_commit}` on `agents/codex-news-e1b2-20260905`; based on the reviewed E1-A builder commit. Ten native exports are on disk and hash-verified. Candidate verification remains **FAIL / NOT PUBLISHABLE**. No production calendar, Common mirror, bundle, dxz23 registry, detector enforcement or news hold was changed.

| Native export | Rows | SHA256 |
|---|---:|---|
{rows}

The exporter uses the canonical bootstrap's StartUp configuration pattern and process-observation helpers through a wrapper restricted to `D:/QM/mt5/T_Export`. The current canonical bootstrap classifies T_Export as unknown, so its lane/factory launch guard was preserved. The new wrapper validates the exact export path, unique task config and fresh process identity, compiles a read-only script, launches hidden with Experts/AllowLiveTrading/AllowDllImport disabled, and closes only the owned export process. Existing output names are refused. No T1–T10 process was interrupted and no T_Live process was signalled.

Currency-wide annual USD queries returned 5401. Event-specific annual queries produced the catalog files. The native Empire State catalog name is `NY Fed Empire State Manufacturing Index`, event ID 840230001. The single-export preset required numeric datetime epochs; diagnostic receipts preserve the refused/empty attempts. A MetaTrader update replaced one launcher process; a separate cleanup receipt binds its exact executable, unique StartUp config, creation time and completed script marker. Final wrapper handling covers that handoff. Final exporter compile: **0 errors, 0 warnings**; the compiled source/ex5 hashes and process cleanup are in `export_receipt.json`. Tests: **22 passed** (repair/detector/export validation and handoff identity).

The candidate is `{FINAL}`, manifest SHA256 `{sha(FINAL/'manifest.json')}`. Both files retain their exact 20/9-column schemas and all source rows. Native-confirmed matches take precedence. **{fallback:,}** remaining unambiguous one-minute SECONDARY differences were aligned to PRIMARY and explicitly logged `COMMON_MINUTE_PRIMARY_FALLBACK_UNVERIFIED`. This is consistency, not independent timestamp proof. Ambiguous matches remain unresolved. No impacts were promoted; catalog medium/low rows cannot generate HIGH backfills.

Fresh query timestamps are excluded from candidate truth until their own three distinct, consistent official anchors establish their UTC encoding. Ten new exports currently lack that proof. This avoids inheriting UTC from the old full-range export: its separate 2025 query was previously measured +3 hours. MQL5 documents calendar timestamps in [trade-server time](https://www.mql5.com/en/docs/calendar/calendarvaluehistorybyevent). Export presence therefore does not establish correct UTC blackouts.

| Gate | Result |
|---|---|
{gates}

`verification.json` records exact failed groups; `e2_e4_gap_inventory.csv` retains the EUR/JPY/AUD/CAD and other unresolved class/month gaps, and `nonusd_offset_decisions.json` retains offset evidence. H1 structural exports are present; official H1 anchors, unverified native time encodings and existing tick-footprint gaps still prevent publication. Production input hashes before/after match. Candidate files and the complete row audit remain under D:, bound by `result.json`'s artifact inventory. Leave REVIEW; no reseal or release is authorized by this FAIL result.
''')

# Exercise new read-only ingress with the canonical policy implementation.
# The isolated CLI correctly refuses production execution from a worktree.
sys.path.insert(0,str(CANON/'tools/strategy_farm'))
import news_calendar_gate as gate
path=CONTROL_CODE/'tools/strategy_farm/news_calendar_candidate_ingress.py'
spec=importlib.util.spec_from_file_location('reviewed_candidate_ingress',path)
ingress=importlib.util.module_from_spec(spec);spec.loader.exec_module(ingress)
checks=[]
for candidate in [OLD,FINAL]:
    before={p.name:sha(p) for p in candidate.iterdir() if p.is_file()}
    try:
        result=ingress.prepare(gate,candidate,sha(candidate/'manifest.json'))
    except (ValueError,gate.NewsCalendarError) as exc:
        result={'status':'REFUSED','error':str(exc)}
    after={p.name:sha(p) for p in candidate.iterdir() if p.is_file()}
    assert before==after and result['status']=='REFUSED' and 'verification FAIL' in result['error']
    checks.append({'candidate':str(candidate),'manifest_sha256':sha(candidate/'manifest.json'),'result':result,'input_hashes_unchanged':True})
control={'task_id':'3e3e903d-f03d-4f70-8f51-63efcf95159d','captured_at':stamp,'code_commit':control_commit,
         'dry_runs':checks,'tests':{'passed':47,'powershell_ast_errors':0},'production_write':False,
         'canonical_gate':bind(Path(gate.__file__)),'new_ingress':bind(path)}
write(control_out/'dry_run.json',control)
with (EVIDENCE/'2026-09-05_news_calendar_e1b1_control_plane.patch').open('wb') as f:
    f.write(subprocess.check_output(['git','show','--format=fuller','--binary',control_commit],cwd=CONTROL_CODE))
write(EVIDENCE/'2026-09-05_news_calendar_e1b1_control_plane.md',f'''# E1-B1 governed candidate ingress — REVIEW

Task `{control['task_id']}`. Code `{control_commit}` on `agents/codex-news-candidate-ingress-20260905`. Implements verified candidate ingress, exact staged-pair reconciliation and a registered E1-A repin authority. **47 tests pass**, including mutation-free bad hash/failed gate refusals, exact create-only staging, fixture multi-plan compatibility, registered authority and refresh-parent refusal. PowerShell AST parse: zero errors. No production calendar, Common mirror, bundle, dxz23 record or enforcement flag was changed.

`candidate-ingress` validates the external manifest SHA, hash-bound verification JSON, all eight exact boolean PASS gates, schema/decision/publishability envelope, both canonical file hashes and parsed row counts. Links/reparse paths are rejected. Apply only creates a fresh `D:/QM/reports/state/news-calendar-staging-<32hex>` child and copies the already-verified bytes. The refresh skips weekly feed augmentation for this mode; normal multi-plan/publish/mirror/repin follows. Multi-plan rechecks the original candidate proof against the staged pair. The repin reason retains the candidate manifest hash. Existing production location and mutation-lock checks remain in force.

`--owner-decision-id` accepts the old `OWNER-DEC-CALENDAR-REPIN` and registered `OWNER-DEC-CALENDAR-E1A-20260905` only. Existing receipt chains still verify. The refresh requires E1-A authority with candidate ingress and retains the actual parent PID and operation proof for record; direct record without them is refused. No hand-edit of the contract registry is involved.

The 094500Z candidate's read-only diagnostic refused with: `{checks[0]['result']['error']}`. The new E1-B2 candidate also refuses: `{checks[1]['result']['error']}`. All candidate file hashes remained unchanged. Running the production CLI from the isolated worktree separately refused its noncanonical path, as designed; the diagnostic used the new library with the canonical policy implementation. Production command availability requires Claude+OWNER integration first.

After integration and after a fresh pair passes all eight gates, CEO uses this one sequence (replace only the reviewed directory and exact manifest hash):

```powershell
$ErrorActionPreference = 'Stop'
$candidateDir = 'D:/QM/reports/news_calendar/repair_e1a/<VERIFIED_RUN>'
$candidateSha = '<REVIEWED_MANIFEST_SHA256>'
& C:/QM/repo/tools/strategy_farm/refresh_news_calendar.ps1 -CandidatePair $candidateDir -CandidateManifestSha256 $candidateSha -OwnerDecisionId OWNER-DEC-CALENDAR-E1A-20260905 -ReconciliationPlanOnly
if ($LASTEXITCODE -ne 0) {{ throw 'Candidate validation refused' }}
& C:/QM/repo/tools/strategy_farm/refresh_news_calendar.ps1 -CandidatePair $candidateDir -CandidateManifestSha256 $candidateSha -OwnerDecisionId OWNER-DEC-CALENDAR-E1A-20260905
if ($LASTEXITCODE -ne 0) {{ throw 'Governed refresh/repin did not complete' }}
python C:/QM/repo/tools/strategy_farm/news_calendar_repin.py verify
if ($LASTEXITCODE -ne 0) {{ throw 'Repin chain verification failed' }}
```

That sequence has **not** been run for publication. Current candidates fail and must remain staged. Existing plausibility, publication proof, source coverage and runtime checks can still refuse a future pair; eight repair PASS gates are necessary, not a bypass of those checks. The 13 held news rows remain held, and any later release requires pipeline evidence through its normal governed close-out.
''')
print(json.dumps({'data_artifact':str(EVIDENCE/'2026-09-05_news_calendar_e1b2_data_completion.md'),
                  'control_artifact':str(EVIDENCE/'2026-09-05_news_calendar_e1b1_control_plane.md'),
                  'data_code':data_commit,'control_code':control_commit,'fallback_rows':fallback,
                  'gates':{k:v['pass'] for k,v in verification['gates'].items()}},indent=2))
