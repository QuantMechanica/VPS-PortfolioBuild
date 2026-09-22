"""Offline pilot boundary tests. Fake credentials and connections only."""
import copy
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import hashlib
import io
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

import download_databento_pilot as pilot
from quote_databento import GIB, quote_plan


class MetadataStub:
    def post_json(self, method, params):
        if method == 'symbology.resolve':
            return {'status': 0, 'partial': [], 'not_found': [], 'symbols': ['MESZ6'],
                    'stype_in': 'raw_symbol', 'stype_out': 'instrument_id',
                    'start_date': '2026-09-15', 'end_date': '2026-09-17',
                    'result': {'MESZ6': [{'d0': '2026-09-15', 'd1': '2026-09-17', 's': '42001581'}]}}
        return {'metadata.get_cost': Decimal('0.10'), 'metadata.get_record_count': 100,
                'metadata.get_billable_size': 1000}[method]


def dbn_body(payload=b'payload', metadata_size=4):
    # Transport fixture only; record parsing belongs to the independent validator.
    return b'DBN\x03' + metadata_size.to_bytes(4, 'little') + b'meta' + payload


class FakeResponse:
    def __init__(self, body=None, *, status=200, headers=None):
        self.status = status
        self.body = io.BytesIO(dbn_body() if body is None else body)
        self.headers = headers or {}
        self.read_count = 0

    def getheader(self, name, default=None):
        return self.headers.get(name, default)

    def read(self, size):
        self.read_count += 1
        return self.body.read(size)


class FakeConnection:
    def __init__(self, response, before_request=None):
        self.response = response
        self.before_request = before_request
        self.requests = []
        self.closed = False

    def request(self, method, path, **kwargs):
        if self.before_request:
            self.before_request()
        self.requests.append((method, path, kwargs))

    def getresponse(self):
        return self.response

    def close(self):
        self.closed = True


class PilotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='qm-pilot-offline-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base/'pilot'
        self.quote_path, self.account_path = self.base/'quote.json', self.base/'account.json'
        self.plan_bytes = Path(pilot.__file__).with_name('data_requests.json').read_bytes()
        self.plan = json.loads(self.plan_bytes)
        self.quote = quote_plan(self.plan, MetadataStub(), free_disk_bytes=100 * GIB)
        self.quote['plan_file_sha256'] = hashlib.sha256(self.plan_bytes).hexdigest()
        self.account = {'observed_at_utc': datetime.now(timezone.utc).isoformat(),
                        'usage_based_access_enabled': True,
                        'source': 'OWNER_SUPPLIED_BILLING_SCREENSHOT_VISUALLY_REVIEWED',
                        'pilot_credit_cap_usd': '2.00', 'pilot_out_of_pocket_cap_usd': '0.00',
                        'credits_remaining_usd': '125.00',
                        'quote_request_sha256': self.quote['request_sha256']}
        self.write_inputs()
        self.root_patch = patch.object(pilot, 'ROOT', self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.load_key = Mock(return_value='db-' + 'x' * 29)
        cred_patch = patch.dict('sys.modules', {'credential_store': types.SimpleNamespace(load_key=self.load_key)})
        cred_patch.start()
        self.addCleanup(cred_patch.stop)
        self.connection_factory = Mock(side_effect=AssertionError('UNEXPECTED_NETWORK_PATH'))
        conn_patch = patch.object(pilot.http.client, 'HTTPSConnection', self.connection_factory)
        conn_patch.start()
        self.addCleanup(conn_patch.stop)
        disk_patch = patch.object(pilot.shutil, 'disk_usage', return_value=types.SimpleNamespace(free=100 * GIB))
        self.disk = disk_patch.start()
        self.addCleanup(disk_patch.stop)

    def write_inputs(self, *, bind=True):
        self.quote_path.write_text(json.dumps(self.quote), encoding='utf-8')
        if bind:
            self.account['quote_sha256'] = pilot.sha_file(self.quote_path)
        self.account_path.write_text(json.dumps(self.account), encoding='utf-8')

    def connect(self, response=None, before_request=None):
        connection = FakeConnection(response or FakeResponse(), before_request)
        self.connection_factory.side_effect = None
        self.connection_factory.return_value = connection
        return connection

    def run_download(self, schema='definition', proof=None):
        return pilot.download_one(self.quote_path, self.account_path, schema, proof)

    def assert_preflight_blocked(self, pattern):
        with self.assertRaisesRegex(pilot.PilotError, pattern):
            self.run_download()
        self.load_key.assert_not_called()
        self.connection_factory.assert_not_called()

    def test_definition_success_has_durable_network_ledger_before_single_post(self):
        def inspect_ledger():
            ledger = json.loads((self.root/'definition.attempt.json').read_text())
            self.assertEqual((ledger['status'], ledger['network_requests_attempted']), ('NETWORK_STARTED', 1))
            self.assertEqual(ledger['reserved_usage_cost_usd'], '0.10')
        connection = self.connect(before_request=inspect_ledger)
        result = self.run_download()
        self.assertEqual(result['status'], 'COMPLETE')
        self.assertEqual(result['file_sha256'], hashlib.sha256(dbn_body()).hexdigest())
        self.assertEqual(result['actual_file_bytes'], len(dbn_body()))
        self.assertEqual(result['quote_sha256'], self.account['quote_sha256'])
        self.assertEqual(result['account_evidence_sha256'], pilot.sha_file(self.account_path))
        self.assertEqual(result['out_of_pocket_cap_usd'], '0.00')
        self.assertFalse(result['actual_account_charge_verified'])
        self.assertEqual(len(connection.requests), 1)
        self.assertEqual(connection.requests[0][:2], ('POST', '/v0/timeseries.get_range'))
        self.assertEqual(self.connection_factory.call_args.args, ('hist.databento.com',))
        self.assertTrue(connection.closed)
        self.assertNotIn('db-' + 'x'*29, (self.root/'definition.attempt.json').read_text())

    def test_quote_file_and_request_tampering_fail_before_credential(self):
        self.quote['quotes'][0]['usage_cost_usd'] = '0.00'
        self.write_inputs(bind=False)
        self.assert_preflight_blocked('ACCOUNT_QUOTE_HASH_MISMATCH')
        self.write_inputs()
        self.account['quote_request_sha256'] = '0'*64
        self.write_inputs()
        self.assert_preflight_blocked('CREDIT_EVIDENCE_REQUIRED')

    def test_stale_future_naive_or_invalid_evidence_fails_before_credential(self):
        current = datetime.now(timezone.utc)
        for field in ('quote', 'account'):
            for stamp in ((current-timedelta(hours=2)).isoformat(),
                          (current+timedelta(minutes=1)).isoformat(), '2026-09-22T12:00:00', 'invalid'):
                with self.subTest(field=field, stamp=stamp):
                    self.quote['recorded_at_utc'] = current.isoformat()
                    self.account['observed_at_utc'] = current.isoformat()
                    (self.quote if field == 'quote' else self.account)[
                        'recorded_at_utc' if field == 'quote' else 'observed_at_utc'] = stamp
                    self.write_inputs()
                    self.assert_preflight_blocked('EVIDENCE_NOT_FRESH')

    def test_account_credit_numbers_and_cash_scope_fail_closed(self):
        for value in ('-1', 'NaN', 'Infinity', '1.99', True):
            with self.subTest(value=value):
                self.account['credits_remaining_usd'] = value
                self.write_inputs()
                self.assert_preflight_blocked('MONETARY|CREDIT')
        self.account['credits_remaining_usd'] = '125.00'
        self.account['pilot_out_of_pocket_cap_usd'] = '1.00'
        self.write_inputs()
        self.assert_preflight_blocked('CREDIT_EVIDENCE_REQUIRED')

    def test_quote_cost_numeric_totals_and_cap_fail_closed(self):
        original = copy.deepcopy(self.quote)
        for value in ('-1', 'NaN', 'Infinity', '2.01'):
            with self.subTest(value=value):
                self.quote = copy.deepcopy(original)
                self.quote['quotes'][0]['usage_cost_usd'] = value
                self.write_inputs()
                self.assert_preflight_blocked('MONETARY|COST')
        self.quote = copy.deepcopy(original)
        self.quote['totals']['record_count'] += 1
        self.write_inputs()
        self.assert_preflight_blocked('QUOTE_TOTALS_MISMATCH')

    def test_combined_cost_storage_and_schema_windows_cannot_be_overridden(self):
        original = copy.deepcopy(self.quote)
        for row in self.quote['quotes']:
            row['usage_cost_usd'] = '0.75'
        self.quote['totals']['usage_cost_usd'] = '2.25'
        self.write_inputs()
        self.assert_preflight_blocked('PILOT_COST_CAP')
        self.quote = copy.deepcopy(original)
        self.quote['quotes'][0]['billable_uncompressed_bytes'] = 2 * GIB
        self.quote['totals']['billable_uncompressed_bytes'] = 2 * GIB + 2000
        self.write_inputs()
        self.assert_preflight_blocked('PILOT_STORAGE_CAP')
        self.quote = copy.deepcopy(original)
        self.quote['quotes'][0]['start'] = '2026-09-15T22:00:00+00:00'
        self.write_inputs()
        self.assert_preflight_blocked('SCHEMA_WINDOW_MISMATCH')

    def test_plan_hash_and_missing_validation_check_fail_before_credential(self):
        self.quote['plan_file_sha256'] = '0'*64
        self.write_inputs()
        self.assert_preflight_blocked('PLAN_HASH_MISMATCH')
        self.quote['plan_file_sha256'] = hashlib.sha256(self.plan_bytes).hexdigest()
        del self.quote['checks']['nonempty_requested_schemas']
        self.write_inputs()
        self.assert_preflight_blocked('QUOTE_NOT_VALIDATED')

    def test_existing_attempt_partial_or_final_prevents_credential_and_retry(self):
        self.root.mkdir()
        for filename in ('definition.attempt.json', 'definition.dbn.part', 'definition.dbn'):
            with self.subTest(filename=filename):
                path = self.root/filename
                path.write_bytes(b'previous')
                self.assert_preflight_blocked('EXISTING_ATTEMPT_OR_DATA_NO_AUTOMATIC_RETRY')
                path.unlink()

    def test_warning_and_http_failures_keep_cost_reserved_and_never_retry(self):
        for status, headers, blocker in ((200, {'X-Warning': 'SECRET_WARNING'}, 'REMOTE_WARNING_REQUIRES_REVIEW'),
                                         (302, {'Location': 'https://elsewhere.invalid'}, 'HTTP_STATUS_302'),
                                         (402, {}, 'HTTP_STATUS_402'), (500, {}, 'HTTP_STATUS_500')):
            with self.subTest(status=status, headers=headers):
                root = self.base/('warning-'+str(status))
                with patch.object(pilot, 'ROOT', root):
                    response = FakeResponse(b'SECRET_REMOTE_BODY credit', status=status, headers=headers)
                    connection = self.connect(response)
                    result = self.run_download()
                    self.assertEqual(result['blocker'], blocker)
                    self.assertEqual(result['status'], 'BLOCKED_OR_INCOMPLETE')
                    self.assertEqual(result['reserved_usage_cost_usd'], '0.10')
                    self.assertEqual(result['network_requests_attempted'], 1)
                    self.assertNotIn('SECRET', json.dumps(result))
                    self.assertFalse((root/'definition.dbn').exists())
                    if status == 200:
                        self.assertEqual(response.read_count, 0)
                    with self.assertRaisesRegex(pilot.PilotError, 'NO_AUTOMATIC_RETRY'):
                        self.run_download()
                    self.assertEqual(len(connection.requests), 1)

    def test_oversize_declared_or_streamed_body_never_becomes_final(self):
        cap = 1000 + pilot.HEADER_ALLOWANCE
        for label, response in (
                ('declared', FakeResponse(headers={'Content-Length': str(cap+1)})),
                ('streamed', FakeResponse(dbn_body(b'x'*cap)))):
            with self.subTest(label=label), patch.object(pilot, 'ROOT', self.base/label):
                connection = self.connect(response)
                result = self.run_download()
                self.assertEqual(result['blocker'], 'RESPONSE_SIZE_CAP')
                self.assertFalse((pilot.ROOT/'definition.dbn').exists())
                self.assertLessEqual(result['actual_file_bytes'], cap)
                self.assertEqual(len(connection.requests), 1)
                if label == 'declared': self.assertEqual(response.read_count, 0)

    def test_truncated_http_or_dbn_metadata_does_not_become_complete(self):
        for label, response, blocker in (
                ('http', FakeResponse(dbn_body(), headers={'Content-Length': '99'}), 'TRUNCATED_HTTP_BODY'),
                ('metadata', FakeResponse(dbn_body(metadata_size=99)), 'EMPTY_OR_TRUNCATED_DBN'),
                ('empty-metadata', FakeResponse(b'DBN\x03'+bytes(4)), 'EMPTY_OR_TRUNCATED_DBN'),
                ('bad-length', FakeResponse(headers={'Content-Length': '-1'}), 'INVALID_CONTENT_LENGTH')):
            with self.subTest(label=label), patch.object(pilot, 'ROOT', self.base/label):
                self.connect(response)
                result = self.run_download()
                self.assertEqual(result['blocker'], blocker)
                self.assertFalse((pilot.ROOT/'definition.dbn').exists())

    def test_disk_guard_before_request_and_during_body(self):
        self.disk.return_value = types.SimpleNamespace(free=60 * GIB)
        self.assert_preflight_blocked('FACTORY_DISK_RESERVE')
        self.disk.side_effect = [types.SimpleNamespace(free=100 * GIB), types.SimpleNamespace(free=60 * GIB)]
        self.connect()
        result = self.run_download()
        self.assertEqual(result['blocker'], 'FACTORY_DISK_RESERVE')
        self.assertEqual(result['actual_file_bytes'], 0)
        self.assertFalse((self.root/'definition.dbn').exists())

    def test_negative_or_mixed_quote_prior_attempt_is_not_a_credit_discount(self):
        self.root.mkdir()
        previous = {'schema_version': 'qm.databento-download/v1', 'schema': 'status',
                    'status': 'NETWORK_STARTED', 'network_requests_attempted': 1,
                    'quote_sha256': self.account['quote_sha256'], 'quote_request_sha256': self.quote['request_sha256'],
                    'reserved_usage_cost_usd': '0.10'}
        for changes in ({'reserved_usage_cost_usd': '-1'}, {'reserved_usage_cost_usd': 'NaN'},
                        {'reserved_usage_cost_usd': 'Infinity'}, {'reserved_usage_cost_usd': '0.01'},
                        {'quote_sha256': '0'*64}, {'network_requests_attempted': True}):
            with self.subTest(changes=changes):
                (self.root/'status.attempt.json').write_text(json.dumps({**previous, **changes}))
                self.assert_preflight_blocked('MONETARY|PRIOR_ATTEMPT_INVALID')

    def test_transport_exception_preserves_attempt_and_does_not_leak_or_retry(self):
        connection = self.connect()
        connection.getresponse = Mock(side_effect=RuntimeError('SECRET_ERROR'))
        result = self.run_download()
        self.assertEqual(result['blocker'], 'TRANSPORT_OR_LOCAL_IO_FAILURE')
        self.assertEqual(result['reserved_usage_cost_usd'], '0.10')
        self.assertNotIn('SECRET', json.dumps(result))
        self.assertTrue(connection.closed)
        with self.assertRaisesRegex(pilot.PilotError, 'NO_AUTOMATIC_RETRY'):
            self.run_download()
        self.assertEqual(len(connection.requests), 1)

    def test_interrupted_request_leaves_network_started_receipt(self):
        connection = self.connect()
        connection.getresponse = Mock(side_effect=KeyboardInterrupt)
        with self.assertRaises(KeyboardInterrupt):
            self.run_download()
        receipt = json.loads((self.root/'definition.attempt.json').read_text())
        self.assertEqual((receipt['status'], receipt['network_requests_attempted']), ('NETWORK_STARTED', 1))
        self.assertEqual(receipt['reserved_usage_cost_usd'], '0.10')
        with self.assertRaisesRegex(pilot.PilotError, 'NO_AUTOMATIC_RETRY'):
            self.run_download()

    def test_wrong_encoding_and_header_leave_only_incomplete_attempt(self):
        for label, response, blocker in (
                ('encoding', FakeResponse(headers={'Content-Encoding': 'gzip'}), 'UNEXPECTED_CONTENT_ENCODING'),
                ('header', FakeResponse(b'PRIVATE_INVALID_BINARY'), 'UNEXPECTED_DBN_HEADER')):
            with self.subTest(label=label), patch.object(pilot, 'ROOT', self.base/label):
                self.connect(response)
                result = self.run_download()
                self.assertEqual(result['blocker'], blocker)
                self.assertFalse((pilot.ROOT/'definition.dbn').exists())

    def test_market_data_requires_bound_definition_proof(self):
        with self.assertRaisesRegex(pilot.PilotError, 'DEFINITION_PROOF_REQUIRED'):
            self.run_download('mbp-1')
        self.load_key.assert_not_called()
        definition = self.root/'definition.dbn'
        definition.write_bytes(dbn_body())
        proof = {'status': 'PASS', 'classification': 'DEFINITION_ONLY_TECHNICAL_VALIDATION',
                 'quote_sha256': self.account['quote_sha256'], 'quote_request_sha256': self.quote['request_sha256'],
                 'definition_sha256': pilot.sha_file(definition), 'instrument_id': '42001581',
                 'symbol': 'MESZ6', 'multiplier': '5', 'tick_size': '0.25', 'currency': 'USD'}
        proof_path = self.base/'definition-proof.json'
        for field, bad in (('instrument_id', '123'), ('quote_request_sha256', '0'*64),
                           ('definition_sha256', '0'*64), ('currency', 'EUR')):
            with self.subTest(field=field):
                proof_path.write_text(json.dumps({**proof, field: bad}))
                with self.assertRaisesRegex(pilot.PilotError, 'DEFINITION_PROOF_INVALID'):
                    self.run_download('status', proof_path)
                self.load_key.assert_not_called()
        proof_path.write_text(json.dumps(proof))
        with self.assertRaisesRegex(pilot.PilotError, 'DEFINITION_ATTEMPT_NOT_COMPLETE'):
            self.run_download('status', proof_path)
        attempt = {'schema_version': 'qm.databento-download/v1', 'schema': 'definition',
                   'status': 'COMPLETE', 'network_requests_attempted': 1,
                   'quote_sha256': self.account['quote_sha256'], 'quote_request_sha256': self.quote['request_sha256'],
                   'file_sha256': proof['definition_sha256'], 'actual_file_bytes': len(dbn_body()),
                   'data_path': str(definition), 'reserved_usage_cost_usd': '0.10'}
        attempt_path = self.root/'definition.attempt.json'
        for field, bad in (('status', 'NETWORK_STARTED'), ('file_sha256', '0'*64), ('actual_file_bytes', 1),
                           ('quote_sha256', '0'*64), ('network_requests_attempted', 0)):
            with self.subTest(field=field):
                attempt_path.write_text(json.dumps({**attempt, field: bad}))
                with self.assertRaisesRegex(pilot.PilotError, 'DEFINITION_ATTEMPT_NOT_COMPLETE'):
                    self.run_download('status', proof_path)
                self.load_key.assert_not_called()
        attempt_path.write_text(json.dumps(attempt))
        self.connect()
        result = self.run_download('status', proof_path)
        self.assertEqual(result['status'], 'COMPLETE')
        self.connect()
        result = self.run_download('mbp-1', proof_path)
        self.assertEqual(result['status'], 'COMPLETE')
        costs = [Decimal(json.loads(p.read_text())['reserved_usage_cost_usd']) for p in self.root.glob('*.attempt.json')]
        self.assertEqual(sum(costs), Decimal('0.30'))


if __name__ == '__main__':
    unittest.main()
