"""Single-attempt, quote-bound acquisition of the fixed June-2019 development slice.

Credits only ($10 cap), 4 GiB raw/derived reservation, 60 GiB Factory reserve.
Only exact pre-result windows from quote_development are accepted. This is not a
general data downloader, and no result makes the data an approved economic trial.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import http.client
import json
import os
import re
import shutil
import ssl
import struct
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlencode
from quote_development import requests
from validate_databento_pilot import no_reparse, official_decode, make_loader, scan_dbn, ns

ROOT = Path('D:/QM/futures_lab/development/june2019')
EVIDENCE = Path('D:/QM/reports/research/futures_pivot_20260922/progress_20260922')
QUOTE = EVIDENCE / 'june2019_schema_quotes.json'
AUTHORIZATION = EVIDENCE / 'june2019_acquisition_plan.json'
CREDIT_CAP = Decimal('10')
STORAGE_CAP = 4 * 1024**3
RESERVE = 60 * 1024**3
SIZES = {'definition': 520, 'status': 40, 'mbp-1': 80, 'trades': 48}
RTYPES = {'definition': 19, 'status': 18, 'mbp-1': 1, 'trades': 0}

class AcquisitionError(ValueError): pass

def need(value, code):
    if not value: raise AcquisitionError(code)

def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''): digest.update(block)
    return digest.hexdigest()

def save(path, value, exclusive=False):
    with Path(path).open('x' if exclusive else 'w', encoding='utf-8') as f:
        json.dump(value, f, indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())

def selected_rows(quote):
    need(quote.get('status') == 'QUOTED_NO_DOWNLOAD', 'QUOTE_INCOMPLETE')
    expected = list(requests())
    need(len(quote['quotes']) == len(expected), 'QUOTE_ROWS_MISMATCH')
    chosen = []
    for row, req in zip(quote['quotes'], expected):
        need(row['request'] == req, 'REQUEST_CHANGED')
        need(row['request_sha256'] == hashlib.sha256(json.dumps(req, sort_keys=True).encode()).hexdigest(), 'REQUEST_HASH_CHANGED')
        value = Decimal(row['cost_usd'])
        need(value.is_finite() and value >= 0, 'INVALID_COST')
        need(type(row['records']) is int and row['records'] > 0 and type(row['record_bytes']) is int and row['record_bytes'] > 0, 'INVALID_COUNTS')
        if req['schema'] in SIZES:
            need(row['record_bytes'] == row['records'] * SIZES[req['schema']], 'RECORD_SIZE_CHANGED')
            chosen.append(row)
    need(sum(Decimal(r['cost_usd']) for r in chosen) <= CREDIT_CAP, 'CREDIT_CAP')
    need(sum(r['record_bytes'] + 1048584 for r in chosen) <= STORAGE_CAP, 'STORAGE_CAP')
    return sorted(chosen, key=lambda r: (r['request']['schema'] != 'definition', r['request']['symbols'], r['request']['schema']))

def create_plan():
    quote = json.loads(QUOTE.read_text())
    rows = selected_rows(quote)
    initial = Path('D:/QM/reports/research/futures_pivot_20260922/databento_pilot_result_20260922.json')
    account = json.loads(initial.read_text())
    total = sum(Decimal(r['cost_usd']) for r in rows)
    need(account['credits_observed_before_download_usd'] == '125.00', 'CREDIT_EVIDENCE')
    need(Decimal(account['quoted_usage_reserved_usd']) + CREDIT_CAP < Decimal('125'), 'CREDIT_REMAINDER')
    need(shutil.disk_usage(ROOT.anchor).free >= RESERVE + STORAGE_CAP, 'DISK_RESERVE')
    plan = {'schema': 'qm.june2019-credit-allocation/v1', 'at_utc': datetime.now(timezone.utc).isoformat(),
            'owner_authority': '2026-09-22 direct continuation; full autonomy for economical research, API and $125 credits supplied by OWNER.',
            'quote_sha256': sha(QUOTE), 'prior_pilot_result_sha256': sha(initial),
            'new_credit_cap_usd': str(CREDIT_CAP), 'additional_cash_cap_usd': '0',
            'quoted_cost_usd': str(total), 'prior_quoted_credit_usage_usd': account['quoted_usage_reserved_usd'],
            'remaining_credits_not_reverified': True, 'storage_cap': STORAGE_CAP, 'reserve_bytes': RESERVE,
            'rows': rows, 'scope': 'Raw individual MES/ES development data only, not validation/holdout; no economics read yet.',
            'automatic_retry': False, 'definition_before_market_data': True}
    save(AUTHORIZATION, plan, exclusive=True)
    return plan

def validate_plan():
    plan = json.loads(AUTHORIZATION.read_text())
    need(plan['quote_sha256'] == sha(QUOTE), 'QUOTE_CHANGED')
    quote = json.loads(QUOTE.read_text())
    age = (datetime.now(timezone.utc) - datetime.fromisoformat(quote['at_utc'])).total_seconds()
    need(0 <= age <= 86400, 'STALE_QUOTE')
    need(plan['rows'] == selected_rows(quote), 'PLAN_ROWS_CHANGED')
    need(plan['new_credit_cap_usd'] == '10' and plan['additional_cash_cap_usd'] == '0', 'BUDGET_CHANGED')
    return plan

def definition_proof(path, row):
    raw = path.read_bytes()
    need(len(raw) < 2*1024*1024 and raw[:4] == b'DBN\x03', 'DEFINITION_FORMAT')
    offset = 8 + int.from_bytes(raw[4:8], 'little')
    instrument_id = struct.unpack_from('<I', raw, offset+4)[0]
    req = row['request']; symbol = req['symbols']
    scan = scan_dbn(path, 'definition', {'start':req['start'],'end':req['end'],
                    'record_count':row['records'],'billable_uncompressed_bytes':row['record_bytes']}, instrument_id)
    instruments = official_decode(path, 'definition', make_loader(), definitions=True)
    need(len(instruments) == row['records'], 'NATIVE_DEFINITION_COUNT')
    economics = []
    for obj in instruments:
        info = obj.to_dict(obj)
        need(info['raw_symbol'] == symbol and info['id'] == symbol+'.GLBX', 'RAW_SYMBOL_MISMATCH')
        need(Decimal(str(info['price_increment'])) == Decimal('0.25'), 'TICK_MISMATCH')
        need(Decimal(str(info['multiplier'])) == (5 if symbol.startswith('MES') else 50), 'MULTIPLIER_MISMATCH')
        need(info['currency'] == 'USD', 'CURRENCY_MISMATCH')
        need(obj.activation_ns <= ns(req['start']) < ns(req['end']) <= obj.expiration_ns, 'CONTRACT_NOT_ACTIVE')
        economics.append({k:info[k] for k in ('id','raw_symbol','price_increment','multiplier','currency','expiration_ns','ts_event','ts_init')})
    return {'status':'DEFINITION_VERIFIED','file_sha256':scan['file_sha256'],'instrument_id':instrument_id,'rows':economics,'scan':scan}

def transfer(row, plan, authorization, *, connection_factory=http.client.HTTPSConnection):
    req = row['request']; symbol = req['symbols']; schema = req['schema']
    directory = ROOT / symbol; directory.mkdir(parents=True, exist_ok=True); no_reparse(directory)
    target = directory / (schema+'.dbn'); partial = directory / (schema+'.dbn.part'); ledger = directory / (schema+'.attempt.json')
    need(not target.exists() and not partial.exists() and not ledger.exists(), 'EXISTING_ATTEMPT_NO_RETRY')
    if schema != 'definition':
        proof = json.loads((directory/'definition.proof.json').read_text())
        need(proof['status']=='DEFINITION_VERIFIED' and proof['file_sha256']==sha(directory/'definition.dbn'), 'DEFINITION_NOT_VERIFIED')
    cap = row['record_bytes'] + 1048584
    need(shutil.disk_usage(ROOT).free >= RESERVE + cap, 'DISK_RESERVE')
    receipt = {'status':'RESERVED','at_utc':datetime.now(timezone.utc).isoformat(), 'request':req,
               'plan_sha256':sha(AUTHORIZATION),'quote_sha256':plan['quote_sha256'],
               'reserved_cost_usd':row['cost_usd'],'actual_charge_verified':False,'network_requests':0,'actual_bytes':0}
    save(ledger, receipt, exclusive=True)
    connection = None
    try:
        connection = connection_factory('hist.databento.com', timeout=45, context=ssl.create_default_context())
        receipt.update(status='NETWORK_STARTED',network_requests=1);save(ledger,receipt)
        params = {**req,'stype_out':'instrument_id','encoding':'dbn','compression':'none'}
        connection.request('POST','/v0/timeseries.get_range',body=urlencode(params),
            headers={'Authorization':authorization,'Content-Type':'application/x-www-form-urlencoded','Accept':'application/octet-stream','User-Agent':'QM-Bounded-Development/1'})
        response = connection.getresponse()
        need(response.status == 200,'HTTP_STATUS_'+str(response.status))
        need(not response.getheader('X-Warning'),'REMOTE_WARNING')
        need(response.getheader('Content-Encoding','identity') in ('identity',''),'CONTENT_ENCODING')
        length = response.getheader('Content-Length')
        need(length is None or (re.fullmatch(r'\d+',length) and int(length)<=cap),'CONTENT_LENGTH')
        digest = hashlib.sha256(); count=0;prefix=b''
        with partial.open('xb') as f:
            while True:
                block=response.read(1024*1024)
                if not block:break
                need(count+len(block)<=cap,'BYTE_CAP')
                need(shutil.disk_usage(ROOT).free-len(block)>=RESERVE,'DISK_RESERVE')
                prefix=(prefix+block)[:8]
                need(len(prefix)<4 or prefix[:4]==b'DBN\x03','DBN_FORMAT')
                f.write(block);digest.update(block);count+=len(block);receipt['actual_bytes']=count
            f.flush();os.fsync(f.fileno())
        need(length is None or count==int(length),'TRUNCATED_HTTP_BODY')
        need(len(prefix)==8 and 0<int.from_bytes(prefix[4:8],'little')<=1048576,'METADATA_SIZE')
        need(count==8+int.from_bytes(prefix[4:8],'little')+row['record_bytes'],'EXACT_RECORD_BYTES_MISMATCH')
        partial.rename(target)
        receipt.update(status='DOWNLOADED_REQUIRES_FULL_VALIDATION',file_sha256=digest.hexdigest())
        if schema=='definition':
            proof=definition_proof(target,row);save(directory/'definition.proof.json',proof,exclusive=True)
            receipt['status']='DEFINITION_VERIFIED'
    except Exception as exc:
        receipt.update(status='BLOCKED_NO_RETRY',error_type=type(exc).__name__)
        if isinstance(exc,AcquisitionError):receipt['local_code']=str(exc)
        raise AcquisitionError('DOWNLOAD_BLOCKED_SEE_SANITIZED_LEDGER') from None
    finally:
        if connection is not None:connection.close()
        receipt['finished_at_utc']=datetime.now(timezone.utc).isoformat();save(ledger,receipt)
    return receipt

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');args=parser.parse_args()
    if args.prepare:
        p=create_plan();print(json.dumps({'quoted_cost_usd':p['quoted_cost_usd'],'requests':len(p['rows'])}));return
    plan=validate_plan();ROOT.mkdir(parents=True,exist_ok=True);no_reparse(ROOT)
    from credential_store import load_key
    key=load_key();authorization='Basic '+base64.b64encode((key+':').encode()).decode();del key
    for row in plan['rows']:
        ledger=ROOT/row['request']['symbols']/(row['request']['schema']+'.attempt.json')
        if ledger.exists():
            old=json.loads(ledger.read_text());need(old['plan_sha256']==sha(AUTHORIZATION) and old['status'] in ('DEFINITION_VERIFIED','DOWNLOADED_REQUIRES_FULL_VALIDATION'),'EXISTING_UNFINISHED_ATTEMPT_NO_RETRY')
            need(old['file_sha256']==sha(ledger.with_name(row['request']['schema']+'.dbn')),'EXISTING_FILE_CHANGED');continue
        result=transfer(row,plan,authorization)
        print(json.dumps({'symbol':row['request']['symbols'],'schema':row['request']['schema'],'status':result['status'],'bytes':result['actual_bytes']}),flush=True)

if __name__=='__main__': main()
