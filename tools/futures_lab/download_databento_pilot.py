"""Single-attempt, credit-funded historical DBN pilot. No orders or subscriptions.

Official wire interface: databento/databento-python historical/api/timeseries.py.
Only the exact fresh, validated single-contract quote can be downloaded. Attempt
receipts reserve the FULL quoted charge even after an interruption; no automatic
retry. Definition must be independently validated before market-data downloads.
Credentials remain in CurrentUser DPAPI and never enter receipts or errors.
"""
from __future__ import annotations

import argparse
import base64
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import shutil
import ssl
from urllib.parse import urlencode

from quote_databento import QuoteError, json_bytes, number, validate_plan

ROOT = Path('D:/QM/futures_lab/pilots/mesz6_20260916')
CREDIT_CAP = Decimal('2.00')
HEADER_ALLOWANCE = 1024 * 1024


class PilotError(Exception):
    pass


def now():
    return datetime.now(timezone.utc).isoformat()


def sha_file(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def no_reparse(path):
    path = Path(path).absolute()
    for part in [path, *path.parents]:
        if part.exists() and getattr(part.lstat(), 'st_file_attributes', 0) & 0x400:
            raise PilotError('REPARSE_PATH_REFUSED')


def fresh(stamp):
    try:
        parsed = datetime.fromisoformat(stamp.replace('Z', '+00:00'))
    except (AttributeError, TypeError, ValueError):
        raise PilotError('EVIDENCE_NOT_FRESH') from None
    if parsed.tzinfo is None or not 0 <= (datetime.now(timezone.utc) - parsed).total_seconds() <= 3600:
        raise PilotError('EVIDENCE_NOT_FRESH')


def money(value):
    try:
        return number(Decimal(value) if isinstance(value, str) else value)
    except (QuoteError, ArithmeticError, TypeError, ValueError):
        raise PilotError('INVALID_MONETARY_EVIDENCE') from None


def save_attempt(path, receipt, *, mode='w'):
    with path.open(mode, encoding='utf-8') as handle:
        json.dump(receipt, handle, indent=2)
        handle.write('\n')
        handle.flush()
        os.fsync(handle.fileno())


def validate_inputs(quote, plan, account, schema):
    req = validate_plan(plan)
    expected_checks = {'within_request_cost_cap', 'within_cash_budget_before_credit',
                       'billable_bytes_within_local_budget', 'factory_reserve_after_full_local_budget',
                       'nonempty_requested_schemas'}
    if (schema not in {'definition', 'status', 'mbp-1'}
            or quote.get('schema') != 'qm.databento-quote/v1'
            or quote.get('status') != 'WITHIN_QUOTE_LIMITS'
            or quote.get('classification') != 'QUOTE_ONLY'
            or quote.get('purchase_authorized') is not False
            or quote.get('download_performed') is not False
            or quote.get('request') != req
            or quote.get('request_sha256') != hashlib.sha256(json_bytes(req)).hexdigest()
            or set(quote.get('checks', {})) != expected_checks
            or not all(v is True for v in quote['checks'].values())
            or quote.get('blockers') != []):
        raise PilotError('QUOTE_NOT_VALIDATED')
    fresh(quote['recorded_at_utc'])
    fresh(account['observed_at_utc'])
    if (account.get('usage_based_access_enabled') is not True
            or account.get('source') != 'OWNER_SUPPLIED_BILLING_SCREENSHOT_VISUALLY_REVIEWED'
            or account.get('pilot_credit_cap_usd') != '2.00'
            or account.get('pilot_out_of_pocket_cap_usd') != '0.00'
            or account.get('quote_request_sha256') != quote['request_sha256']
            or money(account['credits_remaining_usd']) < CREDIT_CAP):
        raise PilotError('CREDIT_EVIDENCE_REQUIRED')
    if (req['dataset'] != 'GLBX.MDP3' or req['symbol'] != 'MESZ6'
            or req['start'] != '2026-09-15T22:00:00+00:00'
            or req['end'] != '2026-09-16T21:00:00+00:00'
            or set(req['schemas']) != {'definition', 'mbp-1', 'status'}):
        raise PilotError('OUTSIDE_FIXED_PILOT')
    rows = quote['quotes']
    if len(rows) != 3 or {row['schema'] for row in rows} != set(req['schemas']):
        raise PilotError('INCOMPLETE_QUOTE')
    for row in rows:
        if (row['start'], row['end']) != (req['schema_windows'][row['schema']]['start'], req['schema_windows'][row['schema']]['end']):
            raise PilotError('SCHEMA_WINDOW_MISMATCH')
        if money(row['usage_cost_usd']) > CREDIT_CAP:
            raise PilotError('PILOT_COST_CAP')
        if number(row['record_count'], integer=True) <= 0 or number(row['billable_uncompressed_bytes'], integer=True) <= 0:
            raise PilotError('EMPTY_DATA')
    cost = sum((money(row['usage_cost_usd']) for row in rows), Decimal(0))
    if cost != money(quote['totals']['usage_cost_usd']) or cost > CREDIT_CAP:
        raise PilotError('PILOT_COST_CAP')
    if (sum(row['record_count'] for row in rows) != number(quote['totals']['record_count'], integer=True)
            or sum(row['billable_uncompressed_bytes'] for row in rows) != number(quote['totals']['billable_uncompressed_bytes'], integer=True)):
        raise PilotError('QUOTE_TOTALS_MISMATCH')
    if sum(row['billable_uncompressed_bytes'] + HEADER_ALLOWANCE for row in rows) > req['local_storage_budget_bytes']:
        raise PilotError('PILOT_STORAGE_CAP')
    resolution = quote['resolution']
    instrument_id = resolution.get('instrument_id')
    if (resolution['status'] != 'FULL_DATE_COVERAGE_ONE_ID'
            or not isinstance(instrument_id, str) or re.fullmatch(r'[0-9]{1,10}', instrument_id) is None
            or not 0 < int(instrument_id) <= 4294967295
            or resolution.get('start_date') != req['start_date']
            or resolution.get('end_date') != req['end_date']):
        raise PilotError('SYMBOL_NOT_RESOLVED')
    return req, next(row for row in rows if row['schema'] == schema)


def download_one(quote_path, account_path, schema, definition_proof=None):
    quote_path, account_path = Path(quote_path), Path(account_path)
    no_reparse(quote_path)
    no_reparse(account_path)
    quote_bytes, account_bytes = quote_path.read_bytes(), account_path.read_bytes()
    quote = json.loads(quote_bytes)
    account = json.loads(account_bytes)
    quote_sha = hashlib.sha256(quote_bytes).hexdigest()
    if account.get('quote_sha256') != quote_sha:
        raise PilotError('ACCOUNT_QUOTE_HASH_MISMATCH')
    plan_path = Path(__file__).with_name('data_requests.json')
    plan_bytes = plan_path.read_bytes()
    if quote['plan_file_sha256'] != hashlib.sha256(plan_bytes).hexdigest():
        raise PilotError('PLAN_HASH_MISMATCH')
    req, row = validate_inputs(quote, json.loads(plan_bytes), account, schema)
    no_reparse(ROOT)
    ROOT.mkdir(parents=True, exist_ok=True)
    destination = ROOT / (schema + '.dbn')
    part = ROOT / (schema + '.dbn.part')
    attempt = ROOT / (schema + '.attempt.json')
    for path in (destination, part, attempt):
        no_reparse(path)
        if path.exists():
            raise PilotError('EXISTING_ATTEMPT_OR_DATA_NO_AUTOMATIC_RETRY')
    if schema != 'definition':
        if definition_proof is None:
            raise PilotError('DEFINITION_PROOF_REQUIRED')
        no_reparse(definition_proof)
        no_reparse(ROOT/'definition.dbn')
        proof = json.loads(Path(definition_proof).read_text(encoding='utf-8-sig'))
        if (proof.get('status') != 'PASS' or proof.get('quote_sha256') != quote_sha
                or proof.get('classification') != 'DEFINITION_ONLY_TECHNICAL_VALIDATION'
                or proof.get('quote_request_sha256') != quote['request_sha256']
                or proof.get('definition_sha256') != sha_file(ROOT/'definition.dbn')
                or proof.get('instrument_id') != quote['resolution']['instrument_id']
                or proof.get('symbol') != 'MESZ6'
                or proof.get('multiplier') != '5' or proof.get('tick_size') != '0.25'
                or proof.get('currency') != 'USD'):
            raise PilotError('DEFINITION_PROOF_INVALID')
        definition_attempt_path = ROOT/'definition.attempt.json'
        no_reparse(definition_attempt_path)
        if not definition_attempt_path.is_file():
            raise PilotError('DEFINITION_ATTEMPT_NOT_COMPLETE')
        definition_attempt = json.loads(definition_attempt_path.read_bytes())
        if (definition_attempt.get('schema_version') != 'qm.databento-download/v1'
                or definition_attempt.get('schema') != 'definition'
                or definition_attempt.get('status') != 'COMPLETE'
                or type(definition_attempt.get('network_requests_attempted')) is not int
                or definition_attempt['network_requests_attempted'] != 1
                or definition_attempt.get('quote_sha256') != quote_sha
                or definition_attempt.get('quote_request_sha256') != quote['request_sha256']
                or definition_attempt.get('file_sha256') != proof['definition_sha256']
                or definition_attempt.get('actual_file_bytes') != (ROOT/'definition.dbn').stat().st_size
                or definition_attempt.get('data_path') != str(ROOT/'definition.dbn')):
            raise PilotError('DEFINITION_ATTEMPT_NOT_COMPLETE')
    reserved = Decimal(0)
    prices = {r['schema']: money(r['usage_cost_usd']) for r in quote['quotes']}
    for previous in ROOT.glob('*.attempt.json'):
        no_reparse(previous)
        previous_receipt = json.loads(previous.read_text())
        previous_schema = previous_receipt.get('schema')
        previous_cost = money(previous_receipt['reserved_usage_cost_usd'])
        if (previous_schema not in prices or previous.name != previous_schema + '.attempt.json'
                or previous_receipt.get('schema_version') != 'qm.databento-download/v1'
                or previous_receipt.get('quote_sha256') != quote_sha
                or previous_receipt.get('quote_request_sha256') != quote['request_sha256']
                or previous_cost != prices[previous_schema]
                or previous_receipt.get('status') not in {'ATTEMPT_RESERVED', 'NETWORK_STARTED', 'COMPLETE', 'BLOCKED_OR_INCOMPLETE'}
                or type(previous_receipt.get('network_requests_attempted')) is not int
                or previous_receipt['network_requests_attempted'] not in (0, 1)):
            raise PilotError('PRIOR_ATTEMPT_INVALID')
        reserved += previous_cost
    if reserved + money(row['usage_cost_usd']) > CREDIT_CAP:
        raise PilotError('CUMULATIVE_ATTEMPT_CREDIT_CAP')
    file_cap = row['billable_uncompressed_bytes'] + HEADER_ALLOWANCE
    if shutil.disk_usage(ROOT).free - file_cap < req['factory_reserve_bytes']:
        raise PilotError('FACTORY_DISK_RESERVE')
    from credential_store import load_key
    key = load_key()
    auth = 'Basic ' + base64.b64encode((key + ':').encode('ascii')).decode('ascii')
    del key
    receipt = {'schema_version': 'qm.databento-download/v1', 'status': 'ATTEMPT_RESERVED',
               'schema': schema, 'at_utc': now(), 'quote_sha256': quote_sha,
               'quote_request_sha256': quote['request_sha256'],
               'account_evidence_sha256': hashlib.sha256(account_bytes).hexdigest(),
               'reserved_usage_cost_usd': row['usage_cost_usd'],
               'credit_allocation_usd': '2.00', 'out_of_pocket_cap_usd': '0.00',
               'actual_account_charge_verified': False, 'data_path': str(destination),
               'actual_file_bytes': 0, 'file_sha256': None, 'network_requests_attempted': 0,
               'request': {'dataset': req['dataset'], 'symbols': req['symbol'], 'schema': schema,
                           'start': row['start'], 'end': row['end'], 'stype_in': 'raw_symbol',
                           'stype_out': 'instrument_id', 'encoding': 'dbn', 'compression': 'none'},
               'limitations': ['Credit application is expected from reviewed portal evidence, not billing API verification.',
                               'Partial or failed requests may still incur usage; reserved charge is retained.',
                               'Downloaded bytes are not a completed quality check or economic backtest.']}
    save_attempt(attempt, receipt, mode='x')
    connection = None
    try:
        connection = http.client.HTTPSConnection('hist.databento.com', timeout=45, context=ssl.create_default_context())
        receipt['network_requests_attempted'] = 1
        receipt['status'] = 'NETWORK_STARTED'
        save_attempt(attempt, receipt)  # Durable before POST; a crash remains reserved, never retried.
        connection.request('POST', '/v0/timeseries.get_range', body=urlencode(receipt['request']),
                           headers={'Authorization': auth, 'Content-Type': 'application/x-www-form-urlencoded',
                                    'Accept': 'application/octet-stream', 'User-Agent': 'QM-Bounded-Historical-Pilot/1'})
        response = connection.getresponse()
        receipt['http_status'] = response.status
        if response.status != 200:
            # Retain fixed categories only; never remote bodies, URLs or headers.
            body = response.read(8192).decode('utf-8', errors='replace').lower()
            receipt['remote_error_categories'] = [word for word in ('license', 'agreement', 'subscription', 'credit', 'payment', 'permission', 'limit') if word in body]
            raise PilotError('HTTP_STATUS_' + str(response.status))
        if response.getheader('X-Warning'):
            raise PilotError('REMOTE_WARNING_REQUIRES_REVIEW')
        if response.getheader('Content-Encoding', 'identity').lower() not in ('identity', ''):
            raise PilotError('UNEXPECTED_CONTENT_ENCODING')
        declared_length = response.getheader('Content-Length')
        if declared_length is not None:
            if re.fullmatch(r'[0-9]+', declared_length) is None:
                raise PilotError('INVALID_CONTENT_LENGTH')
            declared_length = int(declared_length)
            if declared_length > file_cap:
                raise PilotError('RESPONSE_SIZE_CAP')
        count = 0
        digest = hashlib.sha256()
        prefix = b''
        with part.open('xb') as handle:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                if count + len(chunk) > file_cap:
                    raise PilotError('RESPONSE_SIZE_CAP')
                if shutil.disk_usage(ROOT).free - len(chunk) < req['factory_reserve_bytes']:
                    raise PilotError('FACTORY_DISK_RESERVE')
                prefix = (prefix + chunk)[:8]
                if len(prefix) >= 4 and (prefix[:3] != b'DBN' or prefix[3] not in (1, 2, 3)):
                    raise PilotError('UNEXPECTED_DBN_HEADER')
                handle.write(chunk)
                digest.update(chunk)
                count += len(chunk)
                receipt['actual_file_bytes'] = count
            handle.flush()
        if (declared_length is not None and count != declared_length):
            raise PilotError('TRUNCATED_HTTP_BODY')
        if (count < 8 or int.from_bytes(prefix[4:8], 'little') == 0
                or count < 8 + int.from_bytes(prefix[4:8], 'little')):
            raise PilotError('EMPTY_OR_TRUNCATED_DBN')
        receipt['dbn_version'] = prefix[3]
        receipt['file_sha256'] = digest.hexdigest()
        part.rename(destination)
        receipt['status'] = 'COMPLETE'
    except PilotError as exc:
        receipt['status'] = 'BLOCKED_OR_INCOMPLETE'
        receipt['blocker'] = str(exc)
    except Exception:
        receipt['status'] = 'BLOCKED_OR_INCOMPLETE'
        receipt['blocker'] = 'TRANSPORT_OR_LOCAL_IO_FAILURE'
    finally:
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass
        receipt['finished_at_utc'] = now()
        save_attempt(attempt, receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quote', type=Path, required=True)
    parser.add_argument('--account-evidence', type=Path, required=True)
    parser.add_argument('--schema', choices=['definition', 'status', 'mbp-1'], required=True)
    parser.add_argument('--definition-proof', type=Path)
    args = parser.parse_args()
    try:
        result = download_one(args.quote, args.account_evidence, args.schema, args.definition_proof)
        print(json.dumps({k: result[k] for k in ('schema', 'status', 'actual_file_bytes')}, sort_keys=True))
        return 0 if result['status'] == 'COMPLETE' else 2
    except PilotError as exc:
        print('PILOT_BLOCKED ' + str(exc))
        return 2
    except Exception:
        print('PILOT_BLOCKED INPUT_OR_CREDENTIAL_ERROR')
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
