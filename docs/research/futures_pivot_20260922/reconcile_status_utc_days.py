"""One bounded diagnostic: two fixed UTC-day status files; never an automatic retry.

Compare every record byte (without deduplication) with the original intraday
status response. Quote first, max $0.01 extra credit and $2 total pilot credit.
No account/contract changes, orders, raw-data repairs or general count tolerance.
"""
from datetime import datetime, timezone
from decimal import Decimal
import hashlib, http.client, json, os
from pathlib import Path
import ssl, struct, sys
from urllib.parse import urlencode

sys.path.insert(0, 'D:/QM/worktrees/codex-futures-pivot-20260922/tools/futures_lab')
from credential_store import load_key
from download_databento_pilot import money, no_reparse, sha_file
from quote_databento import MetadataTransport, number

BASE = Path('D:/QM/reports/research/futures_pivot_20260922')
PILOT = Path('D:/QM/futures_lab/pilots/mesz6_20260916')
DEST = PILOT / 'status_utc_day_diagnostic'
OUT = BASE / 'databento_status_utc_day_reconciliation_20260922.json'
DAY_WINDOWS = [('20260915', '2026-09-15T00:00:00Z', '2026-09-16T00:00:00Z'),
               ('20260916', '2026-09-16T00:00:00Z', '2026-09-17T00:00:00Z')]
CAP = 16384


def ns(stamp):
    return int(datetime.fromisoformat(stamp.replace('Z', '+00:00')).timestamp()) * 1000000000


def records(raw):
    assert raw[:4] == b'DBN\x03' and len(raw) >= 8
    offset = 8 + struct.unpack_from('<I', raw, 4)[0]
    assert offset <= len(raw) and raw[8:24].split(b'\0')[0] == b'GLBX.MDP3'
    assert struct.unpack_from('<H', raw, 24)[0] == 11
    payload = raw[offset:]
    assert len(payload) % 40 == 0
    result = [payload[i:i+40] for i in range(0,len(payload),40)]
    assert all(r[0] == 10 and r[1] == 0x12 and struct.unpack_from('<I',r,4)[0] == 42001581 for r in result)
    return result, offset


def filtered(rows, start, end):
    return [r for r in rows if ns(start) <= struct.unpack_from('<Q',r,16)[0] < ns(end)]


def save(receipt, mode='w'):
    with OUT.open(mode, encoding='utf-8') as f:
        json.dump(receipt,f,indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())


def run():
    no_reparse(DEST)
    if OUT.exists() or DEST.exists():
        raise RuntimeError('EXISTING_DIAGNOSTIC_NO_RETRY')
    account=json.loads((BASE/'databento_account_evidence_20260922.json').read_text())
    quote_path=BASE/'databento_quote_20260922T1248.json'
    quote=json.loads(quote_path.read_text())
    assert account['quote_sha256'] == sha_file(quote_path)
    assert money(account['credits_remaining_usd']) >= Decimal('2')
    assert account['usage_based_access_enabled'] is True
    original=(PILOT/'status.dbn').read_bytes()
    original_receipt=json.loads((PILOT/'status.attempt.json').read_text())
    assert original_receipt['status'] == 'COMPLETE' and original_receipt['file_sha256'] == hashlib.sha256(original).hexdigest()
    original_rows, original_header=records(original)
    prior_reserved=sum((money(json.loads(p.read_text())['reserved_usage_cost_usd']) for p in PILOT.glob('*.attempt.json')), Decimal(0))
    transport=MetadataTransport(load_key())
    requested=[]
    for label,start,end in DAY_WINDOWS:
        params={'dataset':'GLBX.MDP3','symbols':'MESZ6','schema':'status','stype_in':'raw_symbol','stype_out':'instrument_id','start':start,'end':end}
        cost=money(transport.post_json('metadata.get_cost',params))
        count=number(transport.post_json('metadata.get_record_count',{k:v for k,v in params.items() if k!='stype_out'}),integer=True)
        size=number(transport.post_json('metadata.get_billable_size',params),integer=True)
        assert 0 < count <= 100 and 0 < size <= CAP//2
        requested.append({'label':label,'params':params,'quote_cost_usd':str(cost),'quote_record_count':count,'quote_billable_bytes':size,'network_data_requests_attempted':0,'status':'QUOTED'})
    extra=sum((money(r['quote_cost_usd']) for r in requested),Decimal(0))
    assert extra <= Decimal('0.01') and prior_reserved+extra <= Decimal('2.00')
    receipt={'schema':'qm.databento-status-utc-day-reconciliation/v1','status':'DIAGNOSTIC_RESERVED','at_utc':datetime.now(timezone.utc).isoformat(),
             'original_quote_sha256':sha_file(quote_path),'original_status_sha256':hashlib.sha256(original).hexdigest(),
             'original_quote_record_count':12,'original_actual_record_count':len(original_rows),'original_metadata_bytes':original_header,
             'prior_reserved_credit_usd':str(prior_reserved),'diagnostic_reserved_credit_usd':str(extra),'total_reserved_credit_usd':str(prior_reserved+extra),
             'actual_billing_debit_verified':False,'days':requested,'comparisons':[],
             'limitations':['Empirical reconciliation is restricted to these exact status files, instrument and dates.',
                            'Does not establish the vendor internal index design or general rounding semantics.',
                            'Does not independently verify CME feed completeness or authorize strategy deployment.']}
    save(receipt,'x')
    DEST.mkdir(parents=True)
    all_rows=[]
    try:
        for row in requested:
            row['status']='NETWORK_STARTED'; row['network_data_requests_attempted']=1; save(receipt)
            con=http.client.HTTPSConnection('hist.databento.com',timeout=45,context=ssl.create_default_context())
            try:
                con.request('POST','/v0/timeseries.get_range',body=urlencode({**row['params'],'encoding':'dbn','compression':'none'}),
                            headers={'Authorization':transport._authorization,'Content-Type':'application/x-www-form-urlencoded','Accept':'application/octet-stream'})
                response=con.getresponse(); row['http_status']=response.status
                assert response.status==200 and not response.getheader('X-Warning')
                declared=response.getheader('Content-Length')
                assert declared is None or 0 < int(declared) <= CAP
                raw=response.read(CAP+1)
                assert len(raw)<=CAP and (declared is None or len(raw)==int(declared))
                assert response.length in (None,0)
            finally:
                con.close()
            decoded, header_size=records(raw)
            assert len(decoded)==row['quote_record_count'] and len(decoded)*40==row['quote_billable_bytes']
            assert decoded==filtered(decoded,row['params']['start'],row['params']['end'])
            path=DEST/(row['label']+'.status.dbn')
            with path.open('xb') as f: f.write(raw); f.flush(); os.fsync(f.fileno())
            row.update(status='COMPLETE',path=str(path),file_sha256=hashlib.sha256(raw).hexdigest(),file_bytes=len(raw),metadata_bytes=header_size,actual_record_count=len(decoded),record_bytes=len(decoded)*40)
            all_rows.extend(decoded); save(receipt)
        chosen=filtered(all_rows,quote['request']['start'],quote['request']['end'])
        receipt['original_window_reconstructed_count']=len(chosen)
        receipt['original_record_bytes_equal_in_order_without_deduplication']=chosen==original_rows
        assert chosen==original_rows
        windows=json.loads((BASE/'databento_status_window_quotes_20260922.json').read_text())
        for row in windows['rows']:
            selected=filtered(all_rows,row['start'],row['end'])
            receipt['comparisons'].append({**row,'actual_reconstructed_record_count':len(selected)})
        receipt['status']='MATCHED_FOR_THESE_EXACT_FILES'
        receipt['finding']='For MESZ6/status on these UTC dates, metadata counts behave as full UTC-day counts; time-filtered raw data matches the original response byte-for-byte.'
    except Exception:
        receipt['status']='DIAGNOSTIC_BLOCKED_NO_GENERAL_COUNT_TOLERANCE'
    finally:
        receipt['finished_at_utc']=datetime.now(timezone.utc).isoformat(); save(receipt)
    print(json.dumps({'status':receipt['status'],'total_reserved_credit_usd':receipt['total_reserved_credit_usd'],'days':[{k:r.get(k) for k in ('label','status','actual_record_count','file_bytes')} for r in requested]}))
    return 0 if receipt['status']=='MATCHED_FOR_THESE_EXACT_FILES' else 2


if __name__=='__main__':
    try:
        raise SystemExit(run())
    except Exception:
        print('STATUS_RECONCILIATION_BLOCKED_NO_SECRET_OUTPUT')
        raise SystemExit(2)
