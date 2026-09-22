"""Full bounded raw validation for the fixed June-2019 development acquisition."""
from __future__ import annotations
import hashlib
import argparse
import json
from pathlib import Path
import struct
from datetime import datetime,timezone
import numpy as np
from download_development import ROOT, EVIDENCE, AUTHORIZATION, sha, need, save
from validate_databento_pilot import read_header, scan_dbn, fingerprint, ns, StreamingStats

TRADE_DTYPE=np.dtype({'names':['length','rtype','publisher_id','instrument_id','ts_event','price','size','action','side','flags','ts_recv','sequence'],
 'formats':['u1','u1','<u2','<u4','<u8','<i8','<u4','u1','u1','u1','<u8','<u4'],
 'offsets':[0,1,2,4,8,16,24,28,29,30,32,44],'itemsize':48})

def validate_scan_metadata_and_clock(scan,schema):
    need(scan['dbn_version']==3 and scan['schema_code']=={'definition':9,'status':11,'mbp-1':1,'trades':4}[schema],'DBN_METADATA_SCHEMA_OR_VERSION')
    clock=scan['timestamps']['ts_recv']
    need(clock['undefined_or_zero']==0 and clock['backsteps']==0 and clock['outside_query_window']==0,'RECEIVE_TIME')

def scan_trades(path,row,iid):
    before=fingerprint(path);digest=hashlib.sha256();req=row['request']
    stats=StreamingStats('trades',iid,ns(req['start']),ns(req['end']));count=0
    with path.open('rb') as f:
        meta=read_header(f,digest)
        need(meta['dbn_version']==3 and meta['schema_code']==4,'TRADE_SCHEMA')
        while True:
            block=f.read(16384*48)
            if not block:break
            need(len(block)%48==0,'TRUNCATED_TRADE_RECORD');digest.update(block)
            rows=np.frombuffer(block,dtype=TRADE_DTYPE);count+=len(rows)
            need(np.all(rows['length']==12) and np.all(rows['rtype']==0),'TRADE_FRAMING')
            need(np.all(rows['instrument_id']==iid) and np.all(rows['publisher_id']==1),'TRADE_IDENTITY')
            need(np.all(rows['action']==ord('T')),'TRADE_ACTION')
            need(np.all(rows['size']>0) and np.all(rows['price']>0) and np.all(rows['price']%250000000==0),'TRADE_PRICE_OR_SIZE')
            stats.clock('ts_event',rows['ts_event']);stats.clock('ts_recv',rows['ts_recv'])
    need(fingerprint(path)==before,'FILE_CHANGED')
    need(count==row['records'] and count*48==row['record_bytes'],'TRADE_COUNT_MISMATCH')
    return {'path':str(path),'schema':'trades','record_count':count,'record_bytes':count*48,
            'file_sha256':digest.hexdigest(),'instrument_id':iid,'timestamps':stats.report()['timestamps'],
            'all_records_scanned':True,**meta}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=EVIDENCE/'june2019_data_validation.json')
    args=parser.parse_args()
    plan=json.loads(AUTHORIZATION.read_text());out={'schema':'qm.june2019-data-validation/v1',
      'at_utc':datetime.now(timezone.utc).isoformat(),'plan_sha256':sha(AUTHORIZATION),'files':[],
      'status':'IN_PROGRESS','economic_results_viewed':False,'frozen_trial_authorized':False}
    target=args.output;save(target,out,exclusive=True)
    try:
        for row in plan['rows']:
            req=row['request'];schema=req['schema'];directory=ROOT/req['symbols'];path=directory/(schema+'.dbn')
            ledger=json.loads((directory/(schema+'.attempt.json')).read_text())
            need(ledger['status'] in ('DEFINITION_VERIFIED','DOWNLOADED_REQUIRES_FULL_VALIDATION') and ledger['plan_sha256']==sha(AUTHORIZATION),'DOWNLOAD_NOT_COMPLETE')
            proof=json.loads((directory/'definition.proof.json').read_text());iid=proof['instrument_id']
            if schema=='trades':scan=scan_trades(path,row,iid)
            else:scan=scan_dbn(path,schema,{'start':req['start'],'end':req['end'],'record_count':row['records'],'billable_uncompressed_bytes':row['record_bytes']},iid)
            need(scan['file_sha256']==ledger['file_sha256'],'HASH_MISMATCH')
            with path.open('rb') as f:prefix=f.read(42)
            need(struct.unpack_from('<Q',prefix,26)[0]==ns(req['start']) and struct.unpack_from('<Q',prefix,34)[0]==ns(req['end']),'HEADER_WINDOW')
            validate_scan_metadata_and_clock(scan,schema)
            scan.update(symbol=req['symbols'],download_receipt_sha256=sha(directory/(schema+'.attempt.json')))
            out['files'].append(scan);save(target,out)
            print(json.dumps({'symbol':req['symbols'],'schema':schema,'records':scan['record_count'],'status':'RAW_SCAN_PASS'}),flush=True)
        out['status']='RAW_VALIDATED_QUALITY_FLAGS_RETAINED';out['total_records']=sum(r['record_count'] for r in out['files'])
        out['validator_sha256']=sha(Path(__file__))
        out['limitations']=['Raw scan is not execution/native-strategy parity or economic approval.',
          'Definition timestamps and book flags retained, not repaired. Calendar coverage is separate.',
          'Mini signal and micro execution remain independent raw contracts.']
    except Exception as exc:
        out.update(status='BLOCKED',error_type=type(exc).__name__,local_error=str(exc));raise
    finally:save(target,out)

if __name__=='__main__':main()
