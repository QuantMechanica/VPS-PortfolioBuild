"""Read-only sweep of the two proposed predicates, preserving exact source hashes."""
from pathlib import Path
import datetime as dt
import hashlib
import importlib.util
import json
import subprocess
import sys
import time

OUT=Path(__file__).resolve().parent
CANON=Path('C:/QM/repo')
CANDIDATE=Path('C:/QM/worktrees/codex-buildcheck-predicates-20260905')
BASE='1240b069d540d611cd6e92c2e4e115ec743844a1'
sys.path.insert(0,str(CANDIDATE/'tools/strategy_farm'))
import build_gate_hardening as after


def git_file(relative):
    return subprocess.run(['git','show',BASE+':'+relative],cwd=CANON,capture_output=True,check=True).stdout


def load_old():
    path=OUT/'baseline_build_gate_hardening.py'
    path.write_bytes(git_file('tools/strategy_farm/build_gate_hardening.py'))
    spec=importlib.util.spec_from_file_location('baseline_build_gate_hardening',path)
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    return module


def scan_ml(script,root,label):
    function=script[script.index('function Invoke-ForbiddenScan {'):script.index('function Invoke-InputGroupCheck {')]
    harness=OUT/(label+'.ps1')
    harness.write_text("$ErrorActionPreference='Stop'\n$EALabel=$null\n$script:found=New-Object 'System.Collections.Generic.List[string]'\nfunction Add-Failure {param([string]$Message) if($Message.StartsWith('EA_ML_FORBIDDEN:')){$script:found.Add($Message)}}\nfunction Add-Warning {param([string]$Message)}\n"+function+"\nInvoke-ForbiddenScan -ResolvedRepoRoot '"+str(root).replace("'","''")+"'\nConvertTo-Json -InputObject @($script:found) -Compress\n",encoding='utf-8')
    run=subprocess.run(['powershell','-NoProfile','-NonInteractive','-File',str(harness)],capture_output=True,text=True)
    assert run.returncode==0,run.stderr
    return json.loads(run.stdout)


def main():
    started=time.monotonic();before=load_old()
    rows=[]
    for path in sorted((CANON/'framework/EAs').glob('*/*.mq5')):
        raw=path.read_bytes();text=after.read_text_compatible(path)
        source=after.SourceFile(path,text,after.strip_comments_preserve_lines(text))
        old=before.check_indicator_buffer_bounds(source);new=after.check_indicator_buffer_bounds(source)
        rows.append({'path':str(path),'ea_id':path.name.split('_')[0]+'_'+path.name.split('_')[1],
                     'sha256':hashlib.sha256(raw).hexdigest(),'before':old,'after':new})
    triage=json.loads((CANON/'docs/ops/evidence/2026-09-05_buffer_bound_family/triage.json').read_text())
    frozen=[]
    for item in triage['rows']:
        if 'fixture' in item:
            path=CANON/'docs/ops/evidence/2026-09-05_buffer_bound_family'/item['fixture']
        else:
            path=Path(item['source'])
        assert hashlib.sha256(path.read_bytes()).hexdigest()==item['source_sha256'],path
        if item['ea_id']=='QM5_41193':
            dest=OUT/'ml_fixture/framework/EAs'/path.stem/path.name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(path.read_bytes())
        text=after.read_text_compatible(path);source=after.SourceFile(path,text,after.strip_comments_preserve_lines(text))
        frozen.append({'ea_id':item['ea_id'],'source_sha256':item['source_sha256'],
                       'original_findings':item['findings'],'bounds_before':before.check_indicator_buffer_bounds(source),
                       'bounds_after':after.check_indicator_buffer_bounds(source)})
    old_ps=git_file('framework/scripts/build_check.ps1').decode('utf-8-sig')
    new_ps=(CANDIDATE/'framework/scripts/build_check.ps1').read_text(encoding='utf-8-sig')
    ml_before=scan_ml(old_ps,CANON,'ml_before');ml_after=scan_ml(new_ps,CANON,'ml_after')
    frozen_ml_before=scan_ml(old_ps,OUT/'ml_fixture','ml_frozen_before')
    frozen_ml_after=scan_ml(new_ps,OUT/'ml_fixture','ml_frozen_after')
    changed=[r for r in rows if r['before']!=r['after']]
    result={'captured_at':dt.datetime.now(dt.timezone.utc).isoformat(),'baseline':BASE,'candidate':str(CANDIDATE),
            'read_only':True,'scanned_eas':len(rows),'bounds_before':sum(len(r['before']) for r in rows),
            'bounds_after':sum(len(r['after']) for r in rows),'changed':changed,'sources':rows,'frozen':frozen,
            'ml_before':ml_before,'ml_after':ml_after,'frozen_ml_before':frozen_ml_before,'frozen_ml_after':frozen_ml_after,
            'duration_seconds':round(time.monotonic()-started,3)}
    (OUT/'sweep.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    lines=['# Predicate sweep','', '| EA | Buffer findings before | After |','|---|---:|---:|']
    lines.extend(f"| {r['ea_id']} | {len(r['before'])} | {len(r['after'])} |" for r in changed)
    lines.extend(['',f"Scanned {len(rows)} canonical EA files. All individual findings and source hashes are in sweep.json.",
                  f"ML scan (EA + framework includes/templates/tests): {len(ml_before)} to {len(ml_after)} findings.",
                  f"Frozen QM5_41193 ML scan: {len(frozen_ml_before)} to {len(frozen_ml_after)} findings."])
    (OUT/'sweep.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('sources','changed','frozen','ml_before','ml_after','frozen_ml_before','frozen_ml_after')}))
    print('changed_eas',len(changed),'ML',len(ml_before),len(ml_after))


if __name__=='__main__':main()
