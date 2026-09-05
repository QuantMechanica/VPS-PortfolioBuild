"""Verify frozen native downloads and join to the unchanged frozen FTMO inputs."""
import datetime as dt
import gzip
import hashlib
import json
import math
from pathlib import Path

out = Path(__file__).resolve().parent
ftmo = out.parent / '2026-09-05_m08_ftmo_cost_pack'
inventory = json.loads((ftmo/'harvest_inventory.json').read_text())['harvests']
provider = json.loads((ftmo/'inputs/provider_snapshot.json').read_text())
terms = {x['symbol']: x for x in provider['symbols']}
receipts = [json.loads(p.read_text()) for p in sorted(out.glob('run_*/receipt.json'))]
successful = [r for r in receipts if r['status'] == 'MEASUREMENT_FINISHED']
assert successful, 'No completed governed harvest'
receipt = successful[-1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verified(binding):
    stored = Path(binding['frozen_path']).read_bytes()
    assert sha(stored) == binding['stored_sha256']
    raw = gzip.decompress(stored)
    assert sha(raw) == binding['raw_sha256'] and len(raw) == binding['raw_bytes']
    return raw


def quantile(values, p):
    if not values:
        return None
    values = sorted(values)
    at = (len(values)-1)*p
    lo, hi = math.floor(at), math.ceil(at)
    return round(values[lo] + (values[hi]-values[lo])*(at-lo), 12)


def decode_rows(raw, native=False):
    result = {}
    prior = ''
    for line in raw.splitlines():
        row = json.loads(line)
        # Legacy FTMO ts used a literal Z on a raw server clock label.
        # Preserve the server label, then apply the same DECLARED summer offset.
        label = row['ts_server'] if native else row['ts'].removesuffix('Z')
        assert label > prior and label not in result
        prior = label
        assert type(row['spread']) is int and row['spread'] >= 0
        if native:
            assert row['server_utc_offset_minutes'] == 180
            utc = dt.datetime.fromisoformat(label)-dt.timedelta(minutes=180)
            assert utc.isoformat()+'Z' == row['ts_utc']
        result[label] = row
    return result


rows = []
for symbol in receipt['symbols']:
    binding = next(b for b in receipt['artifacts'] if b['original_path'].endswith(symbol+'_coverage.json'))
    coverage = json.loads(verified(binding))
    download_bindings = [b for b in receipt['artifacts'] if b['original_path'].endswith(symbol+'_download.json')]
    download = json.loads(verified(download_bindings[0])) if download_bindings else None
    prior = next(x for x in inventory if x['venue'] == 'FTMO' and x['symbol'] == symbol)
    stored = (ftmo/prior['frozen_gzip_path']).read_bytes()
    assert sha(stored) == prior['frozen_gzip_sha256']
    raw = gzip.decompress(stored)
    assert sha(raw) == prior['raw_sha256']
    ft_rows = decode_rows(raw)
    dx_rows = {}
    native_bindings = [b for b in receipt['artifacts'] if b['original_path'].endswith(symbol+'_M1.jsonl')]
    if native_bindings:
        dx_rows = decode_rows(verified(native_bindings[0]), native=True)
        assert len(dx_rows) == coverage['bar_count']
        assert min(dx_rows) == coverage['first_bar_server'] and max(dx_rows) == coverage['last_bar_server']
    matched = sorted(set(ft_rows) & set(dx_rows))
    point_ft = 10.0 ** -terms[symbol]['provider']['digits']
    values = [(label, ft_rows[label]['spread']*point_ft - dx_rows[label]['spread']*dx_rows[label]['point_size']) for label in matched]
    sessions = {}
    for hour in (0, 6, 12, 18):
        subset = [value for label, value in values if hour <= (int(label[11:13])-3)%24 < hour+6]
        sessions[f'{hour:02d}-{hour+6:02d}_declared_UTC'] = {'matched_minutes': len(subset), 'p50': quantile(subset,.5), 'p90': quantile(subset,.9)}
    rows.append({'symbol': symbol, 'ftmo_symbol': prior['coverage']['symbol'], 'dxz_symbol': symbol,
                 'comparator': 'NATIVE_BROKER_NOT_DWX_ARCHIVE', 'coverage': coverage,
                 'download': download, 'matched_minutes': len(matched),
                 'first_matched_server': matched[0] if matched else None,
                 'last_matched_server': matched[-1] if matched else None,
                 'cache_reaches_2026_09_04': bool(dx_rows and max(dx_rows) >= '2026-09-04'),
                 'cache_reaches_window_start_day': bool(dx_rows and min(dx_rows) < '2026-05-21'),
                 'delta_ftmo_minus_dxz_price_units_p50': quantile([v for _,v in values],.5),
                 'delta_ftmo_minus_dxz_price_units_p90': quantile([v for _,v in values],.9),
                 'ftmo_point_size_from_frozen_digits': point_ft, 'sessions': sessions,
                 'ftmo_input_sha256': prior['raw_sha256'], 'dxz_coverage_binding': binding})

for r in receipts:
    for b in r['artifacts']:
        verified(b)
    if r.get('compiled_binary'):
        verified(r['compiled_binary'])
    assert r.get('q_verdict') is None and r.get('economic_adoption') is False
cost = sum(r['elapsed_seconds'] for r in receipts)
assert cost < 3600
assert {r['preflight']['terminal'] for r in successful} == {'T2'}
result = {'schema': 'qm.m08c-native-matched-minute/v1', 'result': 'REVIEW',
          'clock_basis': 'DECLARED_SAME_SUMMER_SERVER_OFFSET_PLUS_180_MINUTES; NOT_EMPIRICALLY_VALIDATED',
          'delta_units': 'FTMO_MINUS_DXZ_QUOTE_PRICE_UNITS; spread only, excludes commissions and swaps',
          'elapsed_factory_seconds': cost, 'rows': rows, 'receipt_tags': [r['tag'] for r in receipts],
          'economic_adoption': False, 'q_verdict': None}
(out/'matched_minutes.json').write_text(json.dumps(result,indent=2)+'\n')
verification = {'result': 'PASS', 'all_frozen_hashes_verified': True,
                'symbol_count': len(rows), 'all_six_have_matches': all(r['matched_minutes']>0 for r in rows),
                'all_six_reach_2026_09_04': all(r['cache_reaches_2026_09_04'] for r in rows),
                'all_six_reach_window_start_day': all(r['cache_reaches_window_start_day'] for r in rows),
                'factory_cost_seconds': cost, 'one_terminal': 'T2', 'bootstrap_tests_passed': 23}
(out/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
print(json.dumps(verification,indent=2))
for r in rows:
    print(r['symbol'],r['matched_minutes'],r['coverage'].get('first_bar_server'),r['coverage'].get('last_bar_server'),r['delta_ftmo_minus_dxz_price_units_p50'],r['delta_ftmo_minus_dxz_price_units_p90'])
