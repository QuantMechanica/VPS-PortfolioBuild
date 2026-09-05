"""Read-only, aggregate closed-position performance for the public snapshot."""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import io
import json
import math
from collections import defaultdict
from decimal import Decimal
from pathlib import Path
from zoneinfo import ZoneInfo

LIVE_EXPORT = Path('C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv')
POINTER = Path('D:/QM/reports/state/live_deployment_pointer.json')
DEFAULT_OUT = Path(__file__).resolve().parents[2] / 'public-data/live-performance.json'
EPOCH = '2026-07-24'
DARWIN_URL = 'https://www.darwinexzero.com/darwin/KQDS/performance'
REFERENCE_CAPITAL = Decimal('100000')
BASIS = ('Darwinex Zero strategy-attributed closed-position net P&L in USD, including lifecycle costs; '
         'Europe/Prague close days; excludes manual positions, cashflows and floating P&L. '
         'Index starts at 100 before the epoch day and uses USD 100,000 reference capital; '
         'daily points are closing values, not account equity or DARWIN investor returns.')
ROOT_FIELDS = {'schema_version','generated_at','basis','account_currency','epoch','darwin_url','series','totals'}
TOTAL_FIELDS = {'net_pnl','closes','active_days','last_deal_utc'}


def timestamp(raw):
    value = dt.datetime.fromisoformat(str(raw).replace('Z', '+00:00'))
    if value.tzinfo is None:
        raise ValueError('timestamp must include timezone')
    return value.astimezone(dt.timezone.utc)


def decimal(raw):
    value = Decimal(str(raw))
    if not value.is_finite():
        raise ValueError('non-finite source amount')
    return value


def position_magic(openings):
    identities = set()
    for row in openings:
        identities.add(next((int(row.get(k) or 0) for k in ('logical_magic','deal_magic','magic')
                             if int(row.get(k) or 0)), 0))
    if len(identities) != 1:
        raise ValueError('ambiguous position attribution')
    return identities.pop()


def build(rows, roster, *, generated_at=None):
    """Attribute complete lifecycles by position id and opening identity.

    A zero-identity closing deal retains its opening identity. Unsupported
    reversals, duplicate deals, missing entries and cost inconsistencies fail
    closed; still-open/partially closed positions wait for complete closure.
    """
    if not rows or not roster or 0 in roster:
        raise ValueError('empty source/roster or invalid roster')
    positions = defaultdict(list)
    seen = set()
    for row in rows:
        key = int(row['deal_id'])
        if key in seen:
            raise ValueError('duplicate deal')
        seen.add(key)
        timestamp(row['time_utc'])
        if row['type'].upper() not in ('BUY','SELL'):
            continue
        if int(row['position_id']) <= 0:
            raise ValueError('missing position identity')
        if row['entry'] not in ('IN','OUT','OUT_BY'):
            raise ValueError('unsupported reversal lifecycle')
        net = decimal(row['net_actual'])
        costs = sum((decimal(row[k]) for k in ('profit','swap','commission','fee')), Decimal(0))
        if abs(net - costs) > Decimal('0.005'):
            raise ValueError('inconsistent lifecycle net')
        if decimal(row['volume']) <= 0:
            raise ValueError('invalid trade volume')
        positions[int(row['position_id'])].append(row)
    daily = defaultdict(lambda: [Decimal(0), 0])
    governed_close_times = []
    for lifecycle in positions.values():
        lifecycle.sort(key=lambda r: (timestamp(r['time_utc']), int(r['deal_id'])))
        openings = [r for r in lifecycle if r['entry'] == 'IN']
        exits = [r for r in lifecycle if r['entry'] in ('OUT','OUT_BY')]
        if not openings or lifecycle[0]['entry'] != 'IN':
            raise ValueError('opening lifecycle missing')
        identity = position_magic(openings)
        if identity not in roster:
            continue
        balance = Decimal(0)
        for row in lifecycle:
            balance += decimal(row['volume']) * (1 if row['entry']=='IN' else -1)
            if balance < 0:
                raise ValueError('exit volume exceeds entry volume')
        if balance or not exits:
            continue
        closed = max(timestamp(r['time_utc']) for r in exits)
        day = closed.astimezone(ZoneInfo('Europe/Prague')).date().isoformat()
        if day < EPOCH:
            continue
        net = sum((decimal(r['net_actual']) for r in lifecycle), Decimal(0))
        daily[day][0] += net
        daily[day][1] += 1
        governed_close_times.append(closed)
    if not governed_close_times:
        raise ValueError('no governed closes in epoch')
    # Stop at the last observed export day; never fabricate future zero days.
    end = max(timestamp(r['time_utc']) for r in rows).astimezone(ZoneInfo('Europe/Prague')).date()
    start = dt.date.fromisoformat(EPOCH)
    cumulative = Decimal(0)
    series = []
    for offset in range((end-start).days+1):
        day = (start + dt.timedelta(days=offset)).isoformat()
        net, closes = daily[day]
        net = net.quantize(Decimal('0.01'))
        cumulative += net
        index = Decimal(100) + cumulative / REFERENCE_CAPITAL * 100
        series.append([day, float(net), float(cumulative), round(float(index), 8), closes])
    result = {'schema_version': 1, 'generated_at': generated_at or dt.datetime.now(dt.timezone.utc).isoformat(),
              'basis': BASIS, 'account_currency': 'USD', 'epoch': EPOCH, 'darwin_url': DARWIN_URL,
              'series': series, 'totals': {'net_pnl': float(cumulative),
              'closes': sum(p[4] for p in series), 'active_days': sum(p[4] > 0 for p in series),
              'last_deal_utc': max(governed_close_times).isoformat().replace('+00:00','Z')}}
    validate(result)
    return result


def validate(value):
    if set(value) != ROOT_FIELDS or set(value['totals']) != TOTAL_FIELDS:
        raise ValueError('public exposure whitelist')
    if (value['schema_version'] != 1 or value['basis'] != BASIS or value['account_currency'] != 'USD'
        or value['epoch'] != EPOCH or value['darwin_url'] != DARWIN_URL):
        raise ValueError('public metadata contract')
    timestamp(value['generated_at']); timestamp(value['totals']['last_deal_utc'])
    previous = dt.date.fromisoformat(EPOCH) - dt.timedelta(days=1)
    cumulative = Decimal(0)
    if not value['series']:
        raise ValueError('empty public series')
    for row in value['series']:
        if len(row) != 5 or dt.date.fromisoformat(row[0]) != previous + dt.timedelta(days=1):
            raise ValueError('public series shape/calendar')
        previous = dt.date.fromisoformat(row[0])
        if any(type(n) not in (int,float) or not math.isfinite(n) for n in row[1:4]):
            raise ValueError('public series numeric type')
        if type(row[4]) is not int or row[4] < 0:
            raise ValueError('invalid close count')
        cumulative += decimal(row[1])
        if cumulative != decimal(row[2]) or abs(row[3]-(100+float(cumulative/REFERENCE_CAPITAL*100))) > 1e-7:
            raise ValueError('public series arithmetic')
    if (decimal(value['totals']['net_pnl']) != cumulative
        or value['totals']['closes'] != sum(p[4] for p in value['series'])
        or value['totals']['active_days'] != sum(p[4]>0 for p in value['series'])):
        raise ValueError('public totals mismatch')


def read_source(export=LIVE_EXPORT, pointer=POINTER):
    # Capture each source once. Both are opened only for reading.
    rows = list(csv.DictReader(io.StringIO(Path(export).read_bytes().decode('utf-8-sig'))))
    roster_doc = json.loads(Path(pointer).read_bytes().decode('utf-8-sig'))
    roster = {int(r['magic_number']) for r in roster_doc['binary_setfile_fingerprint']['per_sleeve']}
    return rows, roster


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stdout', action='store_true')
    parser.add_argument('--output', type=Path, default=DEFAULT_OUT)
    parser.add_argument('--source', type=Path, default=LIVE_EXPORT)
    parser.add_argument('--pointer', type=Path, default=POINTER)
    args = parser.parse_args(argv)
    result = build(*read_source(args.source, args.pointer))
    encoded = json.dumps(result, indent=2, allow_nan=False) + '\n'
    if args.stdout:
        print(encoded, end='')
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
