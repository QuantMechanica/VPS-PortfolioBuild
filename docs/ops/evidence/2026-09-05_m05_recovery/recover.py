"""Read-only forensic reconciliation; writes only this new canonical evidence folder."""
from pathlib import Path
import collections
import datetime as dt
import gzip
import hashlib
import json
import re
import shutil
import sqlite3
import subprocess
import zipfile

OUT=Path(__file__).resolve().parent
EVIDENCE=OUT.parent
PRIOR=EVIDENCE/'2026-09-05_m05_evidence_loss_adjudication'
SPECIAL='312d2888-9381-4866-9701-ad99ccb611c3'


def norm(path):return str(path).replace('\\','/').lower()
def sha(data):return hashlib.sha256(data).hexdigest()
def stamp(epoch):return dt.datetime.fromtimestamp(epoch,dt.timezone.utc).isoformat()
def save(name,data):
    p=OUT/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')


def run():
    inventory=json.loads((PRIOR/'snapshot_final/inventory.json').read_text(encoding='utf-8'))
    baseline=json.loads((PRIOR/'snapshot_final/baseline_snapshot.json').read_text(encoding='utf-8'))
    cohort=[r for r in inventory['entries'] if r['classification']=='UNEXPLAINED'];assert len(cohort)==156
    ids={r['work_item_id'] for r in cohort}|{SPECIAL}
    rules={r['work_item_id']:r['current_rule_class'] for r in json.loads((PRIOR/'unexplained_current_rule.json').read_text())['rows']}
    con=sqlite3.connect(Path('D:/QM/strategy_farm/state/farm_state.sqlite').as_uri()+'?mode=ro',uri=True)
    con.row_factory=sqlite3.Row;con.execute('PRAGMA query_only=ON');con.execute('BEGIN')
    dbrows={i:dict(con.execute('SELECT * FROM work_items WHERE id=?',(i,)).fetchone()) for i in ids};con.close()
    special=dbrows[SPECIAL];cohort_plus=cohort+[{'work_item_id':SPECIAL,'ea_id':special['ea_id'],'symbol':special['symbol'],'evidence_path':special['evidence_path'],'report_root':'D:/QM/reports/work_items/'+SPECIAL,'baselined_at_utc':None,'first_recorded_missing_utc':None}]
    save('database_rows.json',dbrows)
    all_hits=json.loads((OUT/'retention_receipt_hits.json').read_text())
    # Verify both compressed bytes and the canonical uncompressed receipt stream.
    receipt_verification=[]
    for d in EVIDENCE.glob('2026-08-31_4c0a5ae7_backup_retention_phase2_receipts*'):
        for p in d.glob('*exact_paths.jsonl.gz'):
            bp=d/p.name.replace('_exact_paths.jsonl.gz','.json');b=json.loads(bp.read_text());raw=p.read_bytes();decoded=gzip.decompress(raw)
            assert sha(raw)==b['exact_paths_gzip_sha256'] and sha(decoded)==b['exact_paths_canonical_sha256']
            receipt_verification.append({'path':str(p),'gzip_sha256':sha(raw),'canonical_sha256':sha(decoded),'records':len(decoded.splitlines()),'batch_path':str(bp),'batch_sha256':sha(bp.read_bytes())})
    save('receipt_hash_verification.json',receipt_verification)
    roots=[Path(s) for s in ['D:/QM/reports/pipeline_evidence_archive','D:/QM/reports/_retention_quarantine','D:/QM/reports/_purge_quarantine_20260724','D:/QM/reports/recovery','D:/QM/reports/zero_trades_recovery','D:/QM/exports','D:/QM/strategy_farm/artifacts','C:/QM/backups_relocated','C:/QM/repo/artifacts']]
    existing=[p for p in roots if p.is_dir()]
    scan=subprocess.run(['rg','--files','-uu',*[str(p) for p in existing]],capture_output=True,text=True,encoding='utf-8',errors='replace')
    assert scan.returncode in (0,1)
    paths=[Path(s) for s in scan.stdout.splitlines()];pattern=re.compile('|'.join(map(re.escape,sorted(ids))))
    candidates=collections.defaultdict(list);zip_hits=[]
    for p in paths:
        for ident in set(pattern.findall(str(p))):candidates[ident].append(str(p))
        if p.suffix.lower()=='.zip':
            try:
                with zipfile.ZipFile(p) as z:
                    for member in z.namelist():
                        for ident in set(pattern.findall(member)):zip_hits.append({'zip':str(p),'member':member,'target':ident})
            except (OSError,zipfile.BadZipFile):pass
    save('alternative_search.json',{'roots':[str(p) for p in roots],'existing_roots':[str(p) for p in existing],'indexed_files':len(paths),'rg_stderr':scan.stderr,'identity_path_candidates':dict(candidates),'zip_member_hits':zip_hits,'scope_limit':'Identity/path search over listed local roots, not a forensic scan of unallocated disk or unavailable off-host backups.'})
    observations=baseline['observations'];losses=baseline['losses'];results=[]
    logs={p.name:p.read_text(encoding='utf-8-sig',errors='replace').splitlines() for p in (PRIOR/'snapshot_final').glob('*.log')}
    guard=json.loads((PRIOR/'purge_guard_final.json').read_text())
    save('guard_snapshot.json',guard)
    for entry in cohort_plus:
        ident=entry['work_item_id'];target=Path(entry['evidence_path']);suffix=norm(target).split('/reports/',1)[1]
        hits=[h for h in all_hits if ident in h['targets']]
        exact=[h for h in hits if norm(h['entry'].get('source','')).endswith(suffix) or norm(h['entry'].get('source','')).endswith(suffix+'.gz')]
        deleted=[h for h in exact if h['entry'].get('status')=='DELETED']
        existing_exact=[h for h in exact if Path(h['entry'].get('source','')).is_file()]
        root=Path(entry['report_root']) if entry.get('report_root') else target.parent
        siblings=[]
        if root.exists():
            for p in root.rglob('*'):
                st=p.stat();siblings.append({'path':str(p),'is_file':p.is_file(),'mtime_utc':stamp(st.st_mtime),'ctime_utc':stamp(st.st_ctime),'size':st.st_size if p.is_file() else None})
        first=entry.get('first_recorded_missing_utc');prior_checks=[o['checked_at_utc'] for o in observations if first and o['checked_at_utc']<first]
        # A check not listing this identity as absent provides a conditional last-seen bound.
        loss_times={l['observed_missing_at_utc'] for l in losses if l['work_item_id']==ident}
        last_seen=max((t for t in prior_checks if t not in loss_times),default=entry.get('baselined_at_utc'))
        row={'work_item_id':ident,'ea_id':entry['ea_id'],'symbol':entry['symbol'],'original_path':str(target),'within_156':ident!=SPECIAL,'current_rule_class':rules.get(ident),'last_seen_literal_bound_utc':last_seen,'first_missing_literal_utc':first,'original_parent_mtime_utc':stamp(target.parent.stat().st_mtime) if target.parent.exists() else None,'siblings':siblings,'surviving_primary_files':sum(p['is_file'] for p in siblings),'exact_target_events':exact,'related_receipt_count':len(hits),'other_identity_candidates':candidates[ident]}
        row['exact_purge_log_hits']=[{'log':name,'line':i,'text':line} for name,lines in logs.items() for i,line in enumerate(lines,1) if ident in line or str(target).lower() in line.lower()]
        if existing_exact:
            h=existing_exact[0];source=Path(h['entry']['source']);st=source.stat();raw=source.read_bytes();decoded=gzip.decompress(raw) if source.suffix.lower()=='.gz' else raw;json.loads(decoded.decode('utf-8-sig'))
            assert st.st_size==h['entry']['size'] and st.st_ino==h['entry']['inode']
            output=OUT/'restored'/ident/target.name;output.parent.mkdir(parents=True,exist_ok=True)
            if output.exists():assert output.read_bytes()==decoded
            else:
                with output.open('xb') as f:f.write(decoded)
            assert sha(source.read_bytes())==sha(raw) and sha(output.read_bytes())==sha(decoded)
            row.update({'classification':'RECOVERED_COPY','reason':'Relocated retained file found with receipt-bound path, logical size and NTFS identity; copied without changing source.','restoration':{'source_path':str(source),'source_sha256':sha(raw),'source_mtime_utc':stamp(st.st_mtime),'source_inode':st.st_ino,'receipt_inode_match':True,'receipt_size_match':True,'output_path':str(output),'output_sha256':sha(decoded),'original_pre_loss_content_hash':'not recorded','command':'python C:/QM/repo/docs/ops/evidence/2026-09-05_m05_recovery/recover.py'}})
            row['strongest_cause']='DL090_QUARANTINE_THEN_C_RELOCATION; data survived; original path became absent'
        elif deleted:
            row.update({'classification':'IRRECOVERABLE','reason':'Exact target or its gzip copy has a verified DELETED receipt; all primary run inputs are absent and no exact-identity retained copy was located in the enumerated local sources. No deterministic aggregate reconstruction is possible from these inputs. This is a local-source finding, not a claim about unavailable backups or disk recovery.','strongest_cause':'OWNER_BACKUP_RETENTION_PHASE2_DELETE_NONRETAINED','deletion_completed_by_utc':max(h['batch_completed_at'] for h in deleted),'deleted_representation':['gzip' if h['entry']['source'].endswith('.gz') else 'raw' for h in deleted]})
        else:row.update({'classification':'STILL_UNEXPLAINED','reason':'No surviving exact copy or exact deletion receipt found.','strongest_cause':'UNPROVEN'})
        row['tester_cache_91_pair_guard_prevents_this_path']=False
        row['guard_reason']='The backup-retention executor uses its own classification and does not invoke tester_cache_purge_guard. Adding a pair to that separate guard does not protect this deletion path.'
        results.append(row)
    counts=collections.Counter(r['classification'] for r in results if r['within_156']);assert sum(counts.values())==156
    save('per_path_forensics.json',results)
    save('summary.json',{'schema':'qm.evidence-recovery-forensics/v1','observed_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'counts':{k:counts[k] for k in ['RECOVERED_COPY','REGENERATED','IRRECOVERABLE','STILL_UNEXPLAINED']},'verified_receipt_files':len(receipt_verification),'source_content_hash_at_original_baseline':False,'classification_by_current_rule':dict(collections.Counter(r['current_rule_class']+':'+r['classification'] for r in results if r['within_156'])),'no_in_place_writes':True,'special_1328':next(r for r in results if r['work_item_id']==SPECIAL),'special_13128':next(r for r in results if r['work_item_id'].startswith('6f4fff24'))})
    print(json.dumps({'counts':dict(counts),'verified_receipt_files':len(receipt_verification),'alternate_files_indexed':len(paths),'zip_hits':len(zip_hits)}))


if __name__=='__main__':run()
