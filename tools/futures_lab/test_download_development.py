import hashlib
import json
import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace
from quote_development import requests
from download_development import selected_rows, AcquisitionError, SIZES, transfer, RESERVE

def fixture():
    rows=[]
    for req in requests():
        size=SIZES.get(req['schema'],80)
        rows.append({'request':req,'request_sha256':hashlib.sha256(json.dumps(req,sort_keys=True).encode()).hexdigest(),
                     'cost_usd':'0.01','records':1,'record_bytes':size})
    return {'status':'QUOTED_NO_DOWNLOAD','quotes':rows}

class AcquisitionTests(unittest.TestCase):
    def test_exact_fixed_pre_result_scope_and_definition_first(self):
        rows=selected_rows(fixture())
        self.assertEqual(len(rows),10)
        self.assertTrue(all(r['request']['schema']=='definition' for r in rows[:4]))
        self.assertTrue(all(r['request']['start'].startswith('2019-06-') for r in rows))
        self.assertFalse(any(r['request']['schema'] in ('ohlcv-1m','tbbo') for r in rows))

    def test_no_nonfinite_cost_or_expanded_request(self):
        for value in ('NaN','Infinity','-0.1','100'):
            q=fixture();q['quotes'][0]['cost_usd']=value
            with self.assertRaises(AcquisitionError):selected_rows(q)
        q=fixture();q['quotes'][0]['request']['start']='2026-09-23T00:00:00Z'
        with self.assertRaises(AcquisitionError):selected_rows(q)

    def test_unknown_missing_reordered_or_corrupt_counts_fail(self):
        for mutate in (lambda q:q['quotes'].pop(),lambda q:q['quotes'].reverse(),
                       lambda q:q['quotes'][0].update(records=True),
                       lambda q:q['quotes'][0].update(record_bytes=999),
                       lambda q:q.update(status='IN_PROGRESS')):
            q=fixture();mutate(q)
            with self.assertRaises(AcquisitionError):selected_rows(q)


class FakeResponse:
    def __init__(self,body,status=200,headers=None):self.body=body;self.status=status;self.headers=headers or {};self.offset=0
    def getheader(self,name,default=None):return self.headers.get(name,default)
    def read(self,size):
        block=self.body[self.offset:self.offset+size];self.offset+=len(block);return block


class TransferTests(unittest.TestCase):
    def exercise(self,response,expect_failure):
        row=selected_rows(fixture())[0]
        with tempfile.TemporaryDirectory(prefix='qm-dev-transfer-test-') as folder:
            root=Path(folder).resolve();authfile=root/'allocation.json';authfile.write_text('{}')
            plan={'quote_sha256':'a'*64};calls=[]
            class Connection:
                def request(self,*args,**kwargs):
                    receipt=json.loads((root/'ESM9/definition.attempt.json').read_text())
                    if receipt['status']!='NETWORK_STARTED' or receipt['network_requests']!=1:raise AssertionError('reservation not durable before network')
                    calls.append(args[:2])
                def getresponse(self):return response
                def close(self):pass
            with patch('download_development.ROOT',root),patch('download_development.AUTHORIZATION',authfile), \
                 patch('download_development.shutil.disk_usage',return_value=SimpleNamespace(free=RESERVE+10*1024**3)), \
                 patch('download_development.definition_proof',return_value={'status':'DEFINITION_VERIFIED'}):
                if expect_failure:
                    with self.assertRaises(AcquisitionError):transfer(row,plan,'synthetic',connection_factory=lambda *a,**k:Connection())
                else:
                    transfer(row,plan,'synthetic',connection_factory=lambda *a,**k:Connection())
                with self.assertRaises(AcquisitionError):transfer(row,plan,'synthetic',connection_factory=lambda *a,**k:Connection())
            receipt=json.loads((root/'ESM9/definition.attempt.json').read_text())
            self.assertEqual(len(calls),1)
            self.assertEqual(receipt['reserved_cost_usd'],'0.01')
            self.assertEqual(receipt['status'],'BLOCKED_NO_RETRY' if expect_failure else 'DEFINITION_VERIFIED')
            self.assertEqual((root/'ESM9/definition.dbn').exists(),not expect_failure)

    def body(self):return b'DBN\x03'+(352).to_bytes(4,'little')+bytes(352)+bytes(520)

    def test_single_attempt_reserved_before_post_and_no_retry_after_success(self):
        self.exercise(FakeResponse(self.body()),False)

    def test_redirect_warning_short_and_oversized_bodies_remain_reserved(self):
        for response in [FakeResponse(b'',302),FakeResponse(self.body(),headers={'X-Warning':'untrusted'}),
                         FakeResponse(self.body()[:-1]),FakeResponse(self.body(),headers={'Content-Length':'9999'}),
                         FakeResponse(self.body()+bytes(1048585))]:
            with self.subTest(status=response.status,headers=response.headers):self.exercise(response,True)
if __name__=='__main__':unittest.main()
