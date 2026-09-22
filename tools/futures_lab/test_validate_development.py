import struct
import tempfile
import unittest
from pathlib import Path
from download_development import AcquisitionError
from validate_databento_pilot import scan_dbn, ns
from validate_development import validate_scan_metadata_and_clock

class FullScanGuards(unittest.TestCase):
    def scan(self,recv=None,version=3,schema_code=11):
        start='2019-06-03T00:00:00Z';end='2019-06-04T00:00:00Z';stamp=ns(start)+10**9
        meta=bytearray(352);meta[:16]=b'GLBX.MDP3'+b'\0'*7;struct.pack_into('<H',meta,16,schema_code)
        prefix=b'DBN'+bytes([version])+struct.pack('<I',len(meta))
        record=struct.pack('<BBHIQQHHHBBB7x',10,18,1,123,stamp,stamp if recv is None else recv,7,0,0,89,89,126)
        with tempfile.TemporaryDirectory(prefix='qm-dev-raw-test-') as folder:
            p=Path(folder)/'status.dbn';p.write_bytes(prefix+meta+record)
            return scan_dbn(p,'status',{'start':start,'end':end,'record_count':1,'billable_uncompressed_bytes':40},123)

    def test_actual_wire_valid_scan_passes(self):
        validate_scan_metadata_and_clock(self.scan(),'status')

    def test_zero_and_undefined_wire_receive_times_cannot_pass_window_test(self):
        for bad in (0,2**64-1):
            result=self.scan(recv=bad)
            self.assertEqual(result['timestamps']['ts_recv']['outside_query_window'],0)
            with self.assertRaises(AcquisitionError):validate_scan_metadata_and_clock(result,'status')

    def test_correct_record_body_with_wrong_header_schema_or_version_rejected(self):
        for kwargs in ({'schema_code':1},{'version':2}):
            result=self.scan(**kwargs)
            self.assertEqual(result['record_count'],1)
            with self.assertRaises(AcquisitionError):validate_scan_metadata_and_clock(result,'status')

if __name__=='__main__':unittest.main()
