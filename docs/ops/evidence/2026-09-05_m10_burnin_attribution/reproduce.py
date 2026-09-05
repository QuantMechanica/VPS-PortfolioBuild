"""Offline M10 position attribution and bounded account-equity projection.

Default is stdout only. Explicit output is exclusive-create. No terminal, DB,
pointer, window, gate, or reference writes. Inputs are the accompanying capture.
"""
import argparse
import csv
import datetime as dt
import hashlib
import io
import json
import math
import statistics
from collections import Counter, defaultdict
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def timestamp(value):
    parsed = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('timezone_required')
    return parsed.astimezone(dt.timezone.utc)


def money(rows):
    return float(sum((Decimal(r['net_actual']) for r in rows), Decimal(0)))


def attribute(rows, roster):
    """Use opening DEAL_POSITION_ID lifecycle, never infer identity from symbol."""
    groups, cash, seen = defaultdict(list), [], {}
    for row in rows:
        if row['deal_id'] in seen:
            if seen[row['deal_id']] != row:
                raise ValueError('conflicting_duplicate_deal:' + row['deal_id'])
            continue
        seen[row['deal_id']] = row
        expected = sum((Decimal(row[k]) for k in ('profit', 'swap', 'commission', 'fee')), Decimal(0))
        if expected != Decimal(row['net_actual']):
            raise ValueError('net_reconciliation:' + row['deal_id'])
        if row['type'] not in ('BUY', 'SELL') or row['position_id'] in ('', '0'):
            cash.append(row)
        else:
            groups[row['position_id']].append(row)
    positions, resolutions = [], []
    for key, deals in sorted(groups.items()):
        deals.sort(key=lambda r: (timestamp(r['time_utc']), int(r['deal_id'])))
        openings = [r for r in deals if r['entry'] == 'IN']
        closings = [r for r in deals if r['entry'] in ('OUT', 'OUT_BY')]
        opening_magics = {int(r['deal_magic']) for r in openings if int(r['deal_magic'])}
        nonzero = {int(r['deal_magic']) for r in deals if int(r['deal_magic'])}
        symbols = {r['symbol'] for r in deals}
        magic = next(iter(opening_magics)) if len(opening_magics) == 1 else None
        if any(r['entry'] not in ('IN', 'OUT', 'OUT_BY') for r in deals):
            kind = 'UNRESOLVED_COMPLEX_LIFECYCLE'
        elif len(nonzero) > 1 or len(symbols) > 1:
            kind = 'CONFLICTING_IDENTITY'
        elif not openings:
            kind = 'UNRESOLVED_OPENING_MISSING'
        elif magic is None:
            kind = 'UNATTRIBUTED_MAGIC_0_POSITION'
        elif magic not in roster:
            kind = 'NON_ROSTER_EA'
        elif roster[magic]['symbol'].split('.')[0] != deals[0]['symbol']:
            kind = 'CONFLICTING_ROSTER_SYMBOL'
        else:
            kind = 'ROSTER_EA'
        vin = sum(Decimal(r['volume']) for r in openings)
        vout = sum(Decimal(r['volume']) for r in closings)
        closed = bool(openings and closings and vin == vout)
        if vout > vin:
            kind = 'UNRESOLVED_VOLUME_LIFECYCLE'
        identified = kind in ('ROSTER_EA', 'NON_ROSTER_EA')
        row = {'position_id': key, 'symbol': deals[0]['symbol'], 'classification': kind,
               'logical_magic': magic if identified else None,
               'ea_id': roster[magic]['ea_id'] if kind == 'ROSTER_EA' else None,
               'opened_at_utc': openings[0]['time_utc'] if openings else None,
               'closed_at_utc': closings[-1]['time_utc'] if closed else None,
               'closed': closed, 'volume_in': float(vin), 'volume_out': float(vout),
               'net_actual': money(deals), 'deal_ids': [r['deal_id'] for r in deals],
               'deal_count': len(deals), 'deal_rows': deals}
        positions.append(row)
        for deal in deals:
            if int(deal['deal_magic']) == 0:
                resolutions.append({'deal_id': deal['deal_id'], 'position_id': key,
                    'time_utc': deal['time_utc'], 'symbol': deal['symbol'],
                    'net_actual': float(deal['net_actual']), 'entry': deal['entry'],
                    'classification': ('EA_POSITION_ZERO_MAGIC_DEAL' if identified else kind),
                    'logical_magic': row['logical_magic'], 'ea_id': row['ea_id'],
                    'evidence_deal_ids': row['deal_ids']})
    for row in cash:
        if int(row['deal_magic']) == 0:
            resolutions.append({'deal_id': row['deal_id'], 'position_id': row['position_id'],
                'time_utc': row['time_utc'], 'symbol': row['symbol'],
                'net_actual': float(row['net_actual']), 'entry': row['entry'],
                'classification': 'ACCOUNT_CASHFLOW_' + row['type'],
                'logical_magic': None, 'ea_id': None, 'evidence_deal_ids': [row['deal_id']]})
    return positions, cash, sorted(resolutions, key=lambda r: (r['time_utc'], r['deal_id']))


def equity_days(samples, epoch, end):
    by_day = defaultdict(list)
    for row in samples:
        ts = timestamp(row['record']['ts_utc'])
        equity = float(row['record']['payload']['equity'])
        if not math.isfinite(equity):
            raise ValueError('nonfinite_equity')
        if epoch <= ts <= end:
            by_day[ts.date()].append((ts, equity, row))
    days, previous = [], None
    day = epoch.date()
    while day <= end.date():
        values = sorted(by_day[day], key=lambda r: (r[0], r[1]))
        start = dt.datetime.combine(day, dt.time(), dt.timezone.utc)
        stop = start + dt.timedelta(days=1)
        item = {'date': day.isoformat(), 'sample_count': len(values), 'eod_equity': None,
                'true_intraday_minimum_equity': None, 'status': 'MISSING'}
        if values:
            first, last = values[0], values[-1]
            gaps = [(first[0] - max(start, epoch)).total_seconds(),
                    (min(stop, end) - last[0]).total_seconds()]
            gaps.extend((b[0] - a[0]).total_seconds() for a, b in zip(values, values[1:]))
            item.update({'status': 'OBSERVED_PROXY_ONLY', 'first_sample_utc': first[0].isoformat(),
                         'last_sample_utc': last[0].isoformat(), 'last_observed_equity': last[1],
                         'last_observed_equity_change': None if previous is None else round(last[1] - previous[1], 2),
                         'change_from_date': previous[0].isoformat() if previous else None,
                         'calendar_daily_change_available': bool(previous and (day-previous[0]).days == 1),
                         'sampled_minimum_equity_upper_bound_on_true_low': min(r[1] for r in values),
                         'daily_median_legacy': statistics.median(r[1] for r in values),
                         'maximum_unobserved_gap_seconds': max(gaps),
                         'endpoint_lag_seconds': max(0, (stop - last[0]).total_seconds()),
                         'last_sample_source': {'path': last[2]['source_path'], 'line': last[2]['source_line']}})
            previous = (day, last[1])
        days.append(item)
        day += dt.timedelta(days=1)
    return days


def fingerprint(manifest):
    sleeves = sorted([[int(s['magic_number']), int(s['ea_id']), s['symbol'].split('.')[0].upper(),
                       round(float(s.get('risk_percent', s.get('weight', 0))), 8)] for s in manifest['sleeves']])
    basis = {'sleeves': sleeves, 'starting_capital': round(float(manifest.get('starting_capital', 100000)), 6),
             'total_risk_pct': None if manifest.get('total_risk_pct') is None else round(float(manifest['total_risk_pct']), 6)}
    return hashlib.sha256(json.dumps(basis, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def build(root=ROOT):
    read = lambda name: json.loads((root / 'inputs' / name).read_text(encoding='utf-8-sig'))
    seal_path = root / 'input_seal.json'
    seal = json.loads(seal_path.read_text())
    for name, expected in seal.items():
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != expected:
            raise ValueError('input_seal_mismatch:' + name)
    capture = json.loads((root / 'capture.json').read_text())
    for binding in capture['bindings']:
        if 'frozen' in binding:
            actual = hashlib.sha256((root / binding['frozen']).read_bytes()).hexdigest()
            if actual != binding['sha256']:
                raise ValueError('frozen_input_hash_mismatch:' + binding['frozen'])
    pointer, manifest, mc = read('pointer.json'), read('manifest.json'), read('mc_reference.json')
    previous, config, pulse = read('previous_burnin.json'), read('config.json'), read('pulse.json')
    roster = {int(s['magic_number']): s for s in manifest['sleeves']}
    deals = list(csv.DictReader(io.StringIO((root / 'inputs/deals.csv').read_text(encoding='utf-8-sig'))))
    positions, cash, magic_zero = attribute(deals, roster)
    epoch = timestamp(pointer['deployment_epoch_utc'])
    end = timestamp(capture['captured_at_utc'])
    events = [json.loads(line) for line in (root / 'inputs/events.jsonl').read_text().splitlines()]
    samples = [r for r in events if r['record'].get('event') == 'EQUITY_SNAPSHOT'
               and r['record'].get('magic') in roster
               and str(r['record'].get('symbol', '')).split('.')[0] == roster[r['record']['magic']]['symbol'].split('.')[0]]
    days = equity_days(samples, epoch, end)
    by_magic = defaultdict(list)
    for row in events:
        by_magic[row['record'].get('magic')].append(row)
    silent = []
    for magic, sleeve in roster.items():
        rows = by_magic[magic]
        if any(r['record']['event'] == 'EQUITY_SNAPSHOT' and epoch <= timestamp(r['record']['ts_utc']) <= end for r in rows):
            continue
        life = sorted((r for r in rows if r['record']['event'] in ('INIT_OK', 'DEINIT')), key=lambda r: r['record']['ts_utc'])
        silent.append({'ea_id': sleeve['ea_id'], 'symbol': sleeve['symbol'], 'magic': magic,
                       'last_lifecycle': life[-1] if life else None,
                       'events': dict(Counter(r['record']['event'] for r in rows)),
                       'native_position_count': sum(p['logical_magic'] == magic for p in positions),
                       'native_in_window_deal_count': sum(p['logical_magic'] == magic and epoch <= timestamp(r['time_utc']) <= end for p in positions for r in p['deal_rows'])})
    closed = [p for p in positions if p['closed'] and epoch <= timestamp(p['closed_at_utc']) <= end]
    in_window_cash = [r for r in cash if epoch <= timestamp(r['time_utc']) <= end]
    totals = defaultdict(list)
    for p in positions:
        totals[p['classification']].extend(r for r in p['deal_rows'] if epoch <= timestamp(r['time_utc']) <= end)
    fp = fingerprint(manifest)
    mc_prov = mc.get('_provenance', {})
    mc_bound = (mc_prov.get('book_fingerprint') == fp
                and mc_prov.get('window_days') == config['burnin_window_days'])
    reasons = []
    if not mc_bound:
        reasons.append('MC_REFERENCE_NOT_BOUND_TO_CURRENT_24_SLEEVE_BOOK_AND_WINDOW')
    if not manifest.get('kpis', {}).get('sharpe'):
        reasons.append('MANIFEST_BACKTEST_SHARPE_MISSING')
    if not pointer.get('signed'):
        reasons.append('RUNTIME_POINTER_UNSIGNED')
    if silent:
        reasons.append('FOUR_TELEMETRY_SLEEVES_SILENT' if len(silent) == 4 else 'TELEMETRY_SLEEVES_SILENT')
    reasons.extend(['EXACT_EOD_AND_INTRADAY_LOWS_UNOBSERVED', '42_CALENDAR_DAYS_VS_42_OBSERVED_DAYS_NOT_ADJUDICATED'])
    observed = [d for d in days if d['sample_count']]
    return {'schema': 'qm.burnin-attribution-advisory/v1', 'task_id': 'b94b61c5-0629-4626-8077-5bd35491eb44',
            'captured_at_utc': capture['captured_at_utc'], 'advisory_only': True,
            'position_count': len(positions), 'deal_count': len(deals), 'positions': positions,
            'magic_zero_deals': magic_zero, 'cashflow_rows': cash,
            'window': {'start_inclusive_utc': epoch.isoformat(), 'end_inclusive_utc': end.isoformat(),
                       'restart': False, 'configured_days': config['burnin_window_days'],
                       'elapsed_calendar_days': (end-epoch).total_seconds()/86400,
                       'calendar_dates': len(days), 'observed_dates': len(observed),
                       'fixed_42_elapsed_day_endpoint_utc': (epoch + dt.timedelta(days=config['burnin_window_days'])).isoformat(),
                       'missing_dates': [r['date'] for r in days if not r['sample_count']],
                       'missing_dates_filled_with_zero': False},
            'in_window_deal_cash': {**{k: money(v) for k,v in totals.items()},
                                    'ACCOUNT_CASHFLOWS': money(in_window_cash),
                                    'ACCOUNT_TOTAL': money([r for v in totals.values() for r in v] + in_window_cash)},
            'closed_position_lifecycle_net': {k: round(sum(p['net_actual'] for p in closed if p['classification'] == k), 2) for k in sorted({p['classification'] for p in closed})},
            'account_equity_daily': days, 'silent_sleeves': silent,
            'ks_baselines': pulse['kill_switch_baselines'],
            'reference': {'book_fingerprint': fp, 'mc_bound': mc_bound, 'mc_provenance': mc_prov,
                          'manifest_declared_approval': bool(manifest.get('approved_by')), 'runtime_pointer_signed': pointer.get('signed')},
            'before_after': {'previous_verdict': previous['verdict']['verdict'],
                             'previous_observed_days': previous['maturity']['n_days_observed'],
                             'median_vs_last_sample_differing_days': sum(r['daily_median_legacy'] != r['last_observed_equity'] for r in observed),
                             'last_observed_equity': observed[-1]['last_observed_equity'] if observed else None,
                             'minimum_observed_equity': min((r['sampled_minimum_equity_upper_bound_on_true_low'] for r in observed), default=None)},
            'advisory': {'verdict': 'UNKNOWN', 'binding': False, 'reasons': reasons,
                         'gate_thresholds': config['pass_tolerances'], 'production_report_modified': False},
            'measurement_limits': ['Account equity includes every position and cashflow; it is not separable EA mark-to-market.',
                'The lowest observed equity is an upper bound on the true intraday low. Unobserved losses are unbounded by these samples.',
                'Last sample is a proxy; exact EOD fields remain null. Missing equity dates are not zero-return days.',
                'Closed lifecycle net includes opening costs even when opening predates the window; in-window deal cash uses deal timestamps.',
                'Source-to-deployed-binary build attestation is unavailable; source call-path findings are not runtime proof.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path)
    args = p.parse_args()
    result = build()
    encoded = json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + '\n'
    if args.out:
        with args.out.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(encoded)
        print(json.dumps({'path': str(args.out), 'positions': result['position_count'], 'advisory': result['advisory']}))
    else:
        print(encoded, end='')


if __name__ == '__main__':
    main()
