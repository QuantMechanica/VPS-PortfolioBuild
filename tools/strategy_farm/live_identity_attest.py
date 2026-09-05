"""INERT M06 current-book attestation proposal; no runtime writer or T_Live I/O."""
from __future__ import annotations
import argparse
import datetime as dt
from decimal import Decimal, InvalidOperation
import hashlib
import json
import ntpath
from pathlib import Path
import re

SCHEMA='qm.live-identity-attest-proposal/v1'
OBSERVATION_SCHEMA='qm.live-identity-observation/v1'
MAX_AGE_SECONDS=300
EVIDENCE=Path('C:/QM/repo/docs/ops/evidence')
STATE=Path('D:/QM/reports/state/live_risk_freeze.json')
POINTER=Path('D:/QM/reports/state/live_deployment_pointer.json')
SOURCE_TOOL=Path('C:/QM/repo/tools/strategy_farm/risk_freeze.py')
HASH=re.compile(r'^[0-9a-f]{64}$')


def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def raw_sha(raw):return hashlib.sha256(raw).hexdigest()
def utc(raw):
    t=dt.datetime.fromisoformat(raw.replace('Z','+00:00'))
    if t.tzinfo is None:raise ValueError('explicit timezone required')
    return t.astimezone(dt.timezone.utc)


def safe_path(path):
    # Inspect lexical ancestors before resolving; resolving first hides aliases.
    path=Path(path).absolute()
    if 't_live' in [p.lower() for p in path.parts]:raise ValueError('T_Live filesystem access refused')
    for candidate in (path,path.resolve()):
        if 't_live' in [p.lower() for p in candidate.parts]:raise ValueError('T_Live filesystem access refused')
        for item in [candidate,*candidate.parents]:
            if item.is_symlink() or (item.exists() and getattr(item.stat(),'st_file_attributes',0)&1024):
                raise ValueError('reparse/symlink input or output refused')
    return path.resolve()


def load(path):
    path=safe_path(path);raw=path.read_bytes()
    def pairs(items):
        result={}
        for k,v in items:
            if k in result:raise ValueError('duplicate JSON key: '+k)
            result[k]=v
        return result
    return json.loads(raw,object_pairs_hook=pairs),{'path':str(path),'sha256':raw_sha(raw)}


def fingerprint(measurement):
    if measurement.get('ok') is not True or measurement.get('problems'):
        raise ValueError('measurement is incomplete or reports drift')
    sleeves=measurement.get('sleeves')
    if not isinstance(sleeves,list) or not sleeves or measurement.get('sleeve_count')!=len(sleeves):
        raise ValueError('measurement sleeve coverage invalid')
    if len({s['preset'] for s in sleeves})!=len(sleeves):raise ValueError('duplicate preset in measurement')
    roster=[];binary=[];sets=[];risks=[]
    for s in sleeves:
        for k in ['preset_sha256','binary_sha256']:
            if not HASH.fullmatch(str(s.get(k) or '')):raise ValueError('missing binary/setfile byte hash')
        risk={k:str(Decimal(str(s[k])).normalize()) for k in ['RISK_PERCENT','RISK_FIXED','PORTFOLIO_WEIGHT','qm_magic_slot_offset']}
        if any(not Decimal(v).is_finite() or Decimal(v)<0 for v in risk.values()):raise ValueError('invalid risk vector')
        if Decimal(risk['qm_magic_slot_offset'])!=Decimal(risk['qm_magic_slot_offset']).to_integral_value():
            raise ValueError('fractional magic slot')
        magic=int(s['ea_id'])*10000+int(Decimal(risk['qm_magic_slot_offset']))
        key=s['preset']
        roster.append([key,int(s['ea_id']),s['symbol'],s['timeframe'],magic])
        binary.append([key,s['ea_label'],s['binary_sha256']])
        sets.append([key,s['preset_sha256']]);risks.append([key,risk])
    if len({s[-1] for s in roster})!=len(roster):raise ValueError('duplicate magic in roster')
    return {'count':len(sleeves),'roster_sha256':digest(sorted(roster)),
            'binary_sha256':digest(sorted(binary)),'setfile_sha256':digest(sorted(sets)),
            'risk_sha256':digest(sorted(risks))}


def evaluate(manifest,pointer,freeze,observation,bindings,at):
    failures=[];baseline=freeze.get('baseline') or {};frozen=None;current=None
    if freeze.get('schema')!='qm.live_risk_freeze.v1' or freeze.get('status')!='ACTIVE':failures.append('FREEZE_MUST_REMAIN_ACTIVE')
    try:frozen=fingerprint(baseline)
    except (ValueError,KeyError,TypeError,InvalidOperation) as exc:failures.append('FROZEN_BASELINE_INVALID:'+str(exc))
    account=re.search(r'(\d{6,})',str(manifest.get('book') or ''))
    if (pointer.get('schema_version')!='qm.live_deployment_pointer.v1' or not account
            or pointer.get('expected_account')!=account.group(1)
            or not pointer.get('expected_server') or not pointer.get('expected_phase')):
        failures.append('POINTER_ACCOUNT_SERVER_PHASE_BINDING_INVALID')
    if pointer.get('manifest_sha256')!=bindings['manifest']['sha256']:failures.append('POINTER_MANIFEST_HASH_DRIFT')
    if manifest.get('status')!='LIVE':failures.append('MANIFEST_NOT_CURRENT_LIVE_BOOK')
    entries=manifest.get('sleeves') or [];by_preset={s['preset']:s for s in baseline.get('sleeves',[])}
    binaries=(pointer.get('binary_setfile_fingerprint') or {}).get('per_sleeve') or []
    by_magic={s.get('magic_number'):s for s in binaries}
    binary_envelope=pointer.get('binary_setfile_fingerprint') or {}
    if (binary_envelope.get('n_sleeves')!=len(binaries) or binary_envelope.get('n_binary_missing')!=0
            or binary_envelope.get('fingerprint_sha256')!=digest(sorted(binaries,key=lambda s:s['magic_number']))):
        failures.append('POINTER_BINARY_ENVELOPE_HASH_DRIFT')
    if len(entries)!=len(by_preset) or len(binaries)!=len(entries) or len(by_magic)!=len(binaries):
        failures.append('CURRENT_BOOK_ROSTER_COVERAGE_DRIFT')
    manifest_roster=[]
    for s in entries:
        magic=s.get('magic_number',s.get('magic'))
        manifest_roster.append({'ea_id':s.get('ea_id'),'symbol':s.get('symbol'),'magic_number':magic})
        key=ntpath.basename(str(s.get('deployed_preset') or ''));base=by_preset.get(key);p=by_magic.get(magic)
        if not base or not p:failures.append('CURRENT_BOOK_SLEEVE_BINDING_MISSING:'+key);continue
        if (int(s['ea_id'])!=int(base['ea_id']) or s['symbol'].removesuffix('.DWX')!=base['symbol']
                or magic!=int(base['ea_id'])*10000+int(base['qm_magic_slot_offset'])):
            failures.append('CURRENT_BOOK_ROSTER_DRIFT:'+key)
        if p.get('ex5_status')!='OK' or p.get('ex5_sha256')!=base.get('binary_sha256'):
            failures.append('POINTER_BINARY_HASH_DRIFT:'+key)
        if ntpath.basename(str(p.get('deployed_preset') or ''))!=key:
            failures.append('POINTER_PRESET_IDENTITY_DRIFT:'+key)
        expectation=s.get('set_file_expectation') or {}
        for k in ['RISK_PERCENT','RISK_FIXED','PORTFOLIO_WEIGHT']:
            try:
                if Decimal(str(expectation[k]))!=Decimal(str(base[k])) or Decimal(str((p.get('set_file_expectation') or {})[k]))!=Decimal(str(base[k])):
                    failures.append('CURRENT_BOOK_RISK_DRIFT:'+key+':'+k)
            except (KeyError,ValueError,TypeError,InvalidOperation):failures.append('CURRENT_BOOK_RISK_MISSING:'+key+':'+k)
    expected=pointer.get('expected_sleeves') or {}
    manifest_roster.sort(key=lambda x:x['magic_number'] if x['magic_number'] is not None else -1)
    if (expected.get('count')!=len(entries) or expected.get('identity_sha256')!=digest(manifest_roster)
            or expected.get('roster')!=manifest_roster):
        failures.append('POINTER_ROSTER_HASH_DRIFT')
    age=None
    if observation is None:failures.append('FRESH_BOUND_OBSERVATION_MISSING')
    else:
        if observation.get('schema')!=OBSERVATION_SCHEMA or observation.get('source_tool')!='risk_freeze.measure':
            failures.append('OBSERVATION_SCHEMA_OR_SOURCE_INVALID')
        for role in ['manifest','pointer','freeze']:
            if observation.get(role+'_sha256')!=bindings[role]['sha256']:failures.append('OBSERVATION_'+role.upper()+'_BINDING_DRIFT')
        if observation.get('source_tool_sha256')!=bindings['source_tool']['sha256']:failures.append('OBSERVATION_SOURCE_TOOL_DRIFT')
        try:
            age=(at-utc(observation['captured_at_utc'])).total_seconds()
            if not 0<=age<=MAX_AGE_SECONDS:failures.append('OBSERVATION_STALE_OR_FUTURE')
        except (KeyError,ValueError,TypeError):failures.append('OBSERVATION_TIMESTAMP_INVALID')
        try:
            current=fingerprint(observation['measurement'])
            if frozen:
                for key in frozen:
                    if frozen[key]!=current[key]:failures.append('OBSERVED_'+key.upper()+'_DRIFT')
        except (ValueError,KeyError,TypeError,InvalidOperation) as exc:failures.append('OBSERVATION_INCOMPLETE:'+str(exc))
    return {'schema':SCHEMA,'mode':'INERT_PROPOSAL_ONLY','status':'REFUSED' if failures else 'ELIGIBLE_FOR_OWNER_REVIEW',
            'failures':sorted(set(failures)),'signed':False,'runtime_pointer_write':False,'freeze_mutation':False,
            'activation_authorized':False,'created_at_utc':at.isoformat(),'valid_for_seconds':MAX_AGE_SECONDS,
            'freeze_status':freeze.get('status'),'existing_pointer_signed':pointer.get('signed'),
            'frozen_fingerprint':frozen,'observed_fingerprint':current,'observation_age_seconds':age,
            'bindings':bindings,'transition':'ACTIVE/current_book -> ACTIVE/unsigned_attestation_proposal',
            'owner_actions_remaining':['accept independent current-state capture','approve and sign identity attestation under Mission-Control card',
                                       'separately decide consumers and freeze condition 1; no implicit lift','separate new-version activation ceremony']}


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest',required=True,type=Path)
    p.add_argument('--current-pointer',type=Path,default=POINTER)
    p.add_argument('--freeze-state',type=Path,default=STATE)
    p.add_argument('--observation',type=Path)
    p.add_argument('--observation-sha256')
    p.add_argument('--dry-run',action='store_true',help='Default: evaluate/print an unsigned inert proposal only')
    p.add_argument('--write-proposal',action='store_true',help='Create proposal and receipt in the explicit evidence directory')
    p.add_argument('--proposal-dir',type=Path)
    args=p.parse_args(argv)
    if args.dry_run and args.write_proposal:p.error('dry-run and write-proposal are mutually exclusive')
    if args.write_proposal!=bool(args.proposal_dir):p.error('write-proposal requires proposal-dir and vice versa')
    inputs={};bindings={}
    for role,path in [('manifest',args.manifest),('pointer',args.current_pointer),('freeze',args.freeze_state)]:
        inputs[role],bindings[role]=load(path)
    bindings['source_tool']={'path':str(SOURCE_TOOL),'sha256':raw_sha(SOURCE_TOOL.read_bytes())}
    observation=None
    if bool(args.observation)!=bool(args.observation_sha256):p.error('observation path and externally reviewed SHA256 required together')
    if args.observation:
        observation,bindings['observation']=load(args.observation)
        if bindings['observation']['sha256']!=args.observation_sha256:raise ValueError('observation file SHA256 mismatch')
    at=dt.datetime.now(dt.timezone.utc)
    result=evaluate(inputs['manifest'],inputs['pointer'],inputs['freeze'],observation,bindings,at)
    if any(raw_sha(Path(b['path']).read_bytes())!=b['sha256'] for b in bindings.values()):
        result['status']='REFUSED';result['failures'].append('INPUT_CHANGED_DURING_PROPOSAL')
    if args.write_proposal:
        target=safe_path(args.proposal_dir)
        if EVIDENCE.resolve() not in target.parents or target.exists():raise ValueError('proposal requires a NEW canonical evidence child')
        target.mkdir(parents=True)
        raw=(json.dumps(result,sort_keys=True,indent=2)+'\n').encode()
        with (target/'proposal.json').open('xb') as f:f.write(raw)
        receipt={'schema':'qm.live-identity-attest-proposal-receipt/v1','proposal_sha256':raw_sha(raw),
                 'proposal_path':str(target/'proposal.json'),'status':result['status'],'signed':False,
                 'runtime_pointer_write':False,'freeze_mutation':False,'tool_sha256':raw_sha(Path(__file__).read_bytes())}
        with (target/'receipt.json').open('x',encoding='utf-8') as f:json.dump(receipt,f,indent=2,sort_keys=True);f.write('\n')
    print(json.dumps(result,indent=2,sort_keys=True))
    return 0 if result['status']=='ELIGIBLE_FOR_OWNER_REVIEW' else 2
