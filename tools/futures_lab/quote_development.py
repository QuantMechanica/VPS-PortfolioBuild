"""Free metadata comparison for a fixed, pre-result June-2019 development slice.

No download endpoint. Raw contracts only; no prospective or validation access.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from quote_databento import MetadataTransport, number

WINDOWS = (
    ('MESM9', '2019-06-03T00:00:00Z', '2019-06-17T00:00:00Z'),
    ('MESU9', '2019-06-18T00:00:00Z', '2019-06-29T00:00:00Z'),
    ('ESM9', '2019-06-03T00:00:00Z', '2019-06-17T00:00:00Z'),
    ('ESU9', '2019-06-18T00:00:00Z', '2019-06-29T00:00:00Z'),
)

def requests():
    for symbol, start, end in WINDOWS:
        schemas = ('definition', 'status', 'ohlcv-1m', 'tbbo', 'mbp-1') if symbol.startswith('MES') else ('definition', 'ohlcv-1m', 'trades')
        for schema in schemas:
            yield dict(dataset='GLBX.MDP3', symbols=symbol, stype_in='raw_symbol', schema=schema, start=start, end=end)

def compare(transport, output):
    result = {'schema': 'qm.development-data-comparison/v1',
              'at_utc': datetime.now(timezone.utc).isoformat(),
              'purpose': 'First chronological development month, selected before economics; exclude fixed roll day June 17.',
              'status': 'IN_PROGRESS', 'download_requests': 0, 'metadata_requests': 0, 'quotes': [],
              'schema_substitution_allowed_for_frozen_trial': False}
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('x', encoding='utf-8') as f:
        json.dump(result, f, indent=2)
    try:
        for req in requests():
            row = {'request': req, 'request_sha256': hashlib.sha256(json.dumps(req, sort_keys=True).encode()).hexdigest()}
            for method, field, integer in [('get_cost', 'cost_usd', False), ('get_record_count', 'records', True), ('get_billable_size', 'record_bytes', True)]:
                result['metadata_requests'] += 1
                value = number(transport.post_json('metadata.' + method, req), integer=integer)
                row[field] = value if integer else str(value)
            result['quotes'].append(row)
            output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
            print(json.dumps(row), flush=True)
        result['status'] = 'QUOTED_NO_DOWNLOAD'
    except Exception as exc:
        result['status'] = 'BLOCKED'
        result['error_type'] = type(exc).__name__
        # Production transport errors are fixed local codes, never remote text.
        from quote_databento import QuoteError
        if isinstance(exc, QuoteError):
            result['local_error_code'] = str(exc)
        raise
    finally:
        output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    from credential_store import load_key
    compare(MetadataTransport(load_key()), args.output)
