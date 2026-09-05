"""C6-A on sealed book-wide M5 telemetry. Read-only; V1 gates remain inert.

The compacted collector output alone is insufficient: the hash-bound seal must
also supply exact-profile identities, reconciled boundary inventories and
position-opening receipts. These are evidence inputs, never inferred from P&L.
"""
from __future__ import annotations

import argparse
import datetime as dt
from decimal import Decimal, InvalidOperation
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import random
import re
from dataclasses import dataclass
from typing import Mapping, Sequence
from zoneinfo import ZoneInfo

try:
    from tools.strategy_farm.portfolio.ftmo_rule_contract import load_two_step_contract
    from tools.strategy_farm.portfolio.ftmo_probability_contract import load_probability_contract
    from tools.strategy_farm.portfolio import ftmo_trial_telemetry as telemetry
except ModuleNotFoundError:  # direct script execution
    from ftmo_rule_contract import load_two_step_contract
    from ftmo_probability_contract import load_probability_contract
    import ftmo_trial_telemetry as telemetry

INERT = 'INERT_UNTIL_C6_ENGINE_OWNER_APPROVED'
ACTIVE = 'OWNER_APPROVED_ACTIVE'
SEAL_SCHEMA = 'qm.ftmo-c6-sealed-trace/v1'
RECON_SCHEMA = 'qm.ftmo-c6-reconciliation/v1'
PROFILE_SCHEMA = 'qm.ftmo-c6-exact-profile/v1'
RESULT_SCHEMA = 'qm.ftmo-c6-estimate/v1'
LIMITATION = ('Minimum of terminal-observed tick/timer samples, not an exchange-tick '
              'completeness proof. Exact guard assumes exchangeable independent disjoint '
              'gauntlets; remaining material serial dependence refutes that treatment.')
RULES = load_two_step_contract()
PROBABILITY = load_probability_contract().probability
BOOTSTRAP = PROBABILITY['bootstrap']
PRAGUE = ZoneInfo(RULES.timezone)
SHA = re.compile(r'^[0-9a-f]{64}$')


class C6Refusal(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise C6Refusal(reason)


def _pairs(pairs):
    result = {}
    for k, v in pairs:
        require(k not in result, 'DUPLICATE_JSON_KEY:' + k)
        result[k] = v
    return result


def _bound(binding, *, parse=True):
    require(isinstance(binding, Mapping) and set(binding) == {'path', 'sha256'}, 'MISSING_HASH_BINDING')
    path = Path(str(binding['path']))
    require(path.is_absolute() and path.suffix.lower() not in ('.sqlite', '.db'), 'MUTABLE_OR_RELATIVE_INPUT')
    require(bool(SHA.fullmatch(str(binding['sha256']))), 'INVALID_SHA256')
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise C6Refusal('BOUND_INPUT_UNAVAILABLE:' + str(path)) from exc
    require(hashlib.sha256(raw).hexdigest() == binding['sha256'], 'INPUT_SHA256_MISMATCH:' + str(path))
    if not parse:
        return raw
    try:
        return json.loads(raw.decode('utf-8-sig'), object_pairs_hook=_pairs,
                          parse_constant=lambda x: (_ for _ in ()).throw(C6Refusal('NONFINITE_JSON:' + x)))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise C6Refusal('INVALID_BOUND_JSON:' + str(path)) from exc


def cents(value):
    require(not isinstance(value, bool), 'INVALID_MONEY')
    try:
        x = Decimal(str(value)) * 100
        require(x.is_finite() and x == x.to_integral_value(), 'NONFINITE_OR_SUBCENT_MONEY')
        return int(x)
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise C6Refusal('INVALID_MONEY') from exc


def count(value):
    require(type(value) is int and value >= 0, 'INVALID_INVENTORY_OR_OPENING_COUNT')
    return value


def timestamp(value):
    try:
        x = dt.datetime.fromisoformat(str(value).replace('Z', '+00:00'))
        require(x.tzinfo is not None and x.utcoffset() == dt.timedelta(), 'TIMESTAMP_NOT_UTC')
        return x
    except ValueError as exc:
        raise C6Refusal('INVALID_TIMESTAMP') from exc


@dataclass(frozen=True)
class Point:
    # Cents relative to this day's midnight balance, never multiplicative returns.
    balance: int
    minimum: int
    opened: bool
    flat: bool


@dataclass(frozen=True)
class Day:
    delta: int
    points: tuple[Point, ...]
    flat_start: bool
    flat_end: bool


@dataclass(frozen=True)
class Outcome:
    p1: bool
    joint: bool
    breach: bool


def compact_day(points, delta, flat_start, flat_end):
    """Keep record lows, flat record highs and the first opening receipt.

    Any omitted point can neither cause the first breach nor first target hit
    for any rebase. The first opening event also matters on the fourth day.
    """
    kept = []
    low, high, opened_before = math.inf, {False: -math.inf, True: -math.inf}, False
    for point in points:
        if point.minimum < low or (point.flat and point.balance > high[point.opened]) or (point.opened and not opened_before):
            kept.append(point)
        low = min(low, point.minimum)
        if point.flat:
            high[point.opened] = max(high[point.opened], point.balance)
        opened_before |= point.opened
    return Day(delta, tuple(kept), flat_start, flat_end)


def load_trace(binding):
    seal = _bound(binding)
    require(isinstance(seal, dict) and seal.get('schema') == SEAL_SCHEMA, 'CLOSED_PNL_OR_UNSEALED_TRACE_INADMISSIBLE')
    require(seal.get('sealed') is True and seal.get('manually_repaired_samples') is False, 'TRACE_NOT_SEALED_OR_REPAIRED')
    profile = _bound(seal.get('profile'))
    require(isinstance(profile, dict) and profile.get('schema') == PROFILE_SCHEMA, 'EXACT_PROFILE_REQUIRED')
    for key in ('trial_id', 'account_login', 'account_server', 'currency', 'book_id'):
        require(bool(profile.get(key)), 'EXACT_PROFILE_IDENTITY_MISSING:' + key)
    require(bool(SHA.fullmatch(str(profile.get('timebox_config_sha256', '')))), 'TIMEBOX_CONFIG_BINDING_REQUIRED')
    initial = cents(profile.get('initial_balance'))
    require(initial == cents(RULES.initial_equity) and cents(profile.get('RISK_FIXED')) > 0 and cents(profile.get('RISK_PERCENT')) == 0, 'FIXED_RISK_PROFILE_REQUIRED')
    for key in ('book_binary_manifest', 'book_set_manifest', 'cost_terms', 'estimator_config', 'collector_code', 'rules'):
        _bound(profile.get(key), parse=False)
    candidate_sets = []
    magics = set()
    for key, schema in (('book_binary_manifest', 'qm.ftmo-c6-binary-manifest/v1'),
                        ('book_set_manifest', 'qm.ftmo-c6-set-manifest/v1')):
        manifest = _bound(profile[key])
        require(isinstance(manifest, dict) and manifest.get('schema') == schema
                and manifest.get('book_id') == profile['book_id'], 'CANDIDATE_MANIFEST_REQUIRED')
        identities = set()
        require(isinstance(manifest.get('rows'), list) and bool(manifest['rows']), 'EMPTY_CANDIDATE_MANIFEST')
        for row in manifest['rows']:
            candidate_id = row.get('candidate_id')
            require(isinstance(candidate_id, str) and candidate_id and candidate_id not in identities, 'DUPLICATE_OR_MISSING_CANDIDATE')
            identities.add(candidate_id)
            content = _bound(row.get('binding'), parse=False)
            if key == 'book_set_manifest':
                magic = count(row.get('magic'))
                require(magic > 0 and magic not in magics, 'AMBIGUOUS_CANDIDATE_MAGIC')
                magics.add(magic)
                settings = {}
                for line in content.decode('utf-8-sig').splitlines():
                    field, sep, value = line.partition('=')
                    if sep and field.strip() in ('RISK_FIXED', 'RISK_PERCENT'):
                        require(field.strip() not in settings, 'DUPLICATE_RISK_SETTING')
                        settings[field.strip()] = value.split('||')[0].strip()
                require(cents(settings.get('RISK_FIXED')) == cents(profile['RISK_FIXED'])
                        and cents(settings.get('RISK_PERCENT')) == 0, 'CANDIDATE_FIXED_RISK_PROFILE_MISMATCH')
        candidate_sets.append(identities)
    require(candidate_sets[0] == candidate_sets[1], 'BINARY_SET_CANDIDATE_MISMATCH')
    require(load_two_step_contract(profile['rules']['path']).canonical_sha256 == RULES.canonical_sha256, 'RULES_PROFILE_MISMATCH')
    config = _bound(profile['estimator_config'])
    require(config == {k: BOOTSTRAP[k] for k in ('method', 'replicates', 'replicates_floor', 'seed', 'alpha', 'block_calendar_days', 'ci')}, 'UNSEALED_ESTIMATOR_CONFIG')
    report = _bound(seal.get('telemetry'))
    require(isinstance(report, dict) and report.get('schema') == 'qm.ftmo-trial-telemetry.m5/v1', 'CLOSED_PNL_INPUT_INADMISSIBLE_FOR_BREACH_JOINT')
    raw_binding = {k: report.get('source', {}).get(k) for k in ('path', 'sha256')}
    _bound(raw_binding, parse=False)
    require(report.get('continuity', {}).get('status') == 'PASS', 'ABSTAIN_TELEMETRY_GAPS')
    contract = report.get('contract', {})
    require(contract.get('timezone') == RULES.timezone and contract.get('grid_seconds') == 300, 'M5_PRAGUE_REQUIRED')
    require(contract.get('equity_basis') == 'ACCOUNT_EQUITY_INCLUDING_OPEN_PNL_SWAP_COMMISSION'
            and contract.get('interval_min_basis') == 'MINIMUM_OF_ALL_TICK_AND_TIMER_SAMPLES_IN_INTERVAL', 'OPEN_PNL_INTERVAL_MINIMUM_REQUIRED')
    max_gap = profile.get('maximum_sample_gap_seconds')
    require(type(max_gap) is int and max_gap > 0 and contract.get('maximum_sample_gap_seconds') == max_gap, 'UNSEALED_SAMPLING_CADENCE')
    try:
        raw_rows, _ = telemetry.load_rows(Path(raw_binding['path']))
        for row in raw_rows:
            require(all(row.get(k) == profile[k] for k in ('trial_id', 'account_login', 'account_server', 'currency')), 'RAW_EXACT_PROFILE_MISMATCH')
            require(all(entry.get('magic') in magics for entry in row['positions'] + row['orders']), 'FOREIGN_POSITION_OR_ORDER_IN_BOOK')
        midnights = {}
        for row in raw_rows:
            local = row['_timestamp'].astimezone(PRAGUE)
            if local.time() == dt.time():
                midnights.setdefault(row['_timestamp'], row)
        rebuilt = telemetry.build_report(Path(raw_binding['path']), maximum_sample_gap_seconds=max_gap,
                    initial_balance=initial / 100, daily_loss_fraction=float(RULES.maximum_daily_loss_fraction),
                    target_fraction=float(RULES.phase1_target_fraction))
        require(rebuilt == report, 'COMPACTED_RAW_REPLAY_MISMATCH')
        _bound(raw_binding, parse=False)  # Detect source movement during replay.
    except telemetry.TelemetryError as exc:
        raise C6Refusal('RAW_TELEMETRY_INVALID:' + str(exc)) from exc
    recon = _bound(seal.get('reconciliation'))
    require(isinstance(recon, dict) and recon.get('schema') == RECON_SCHEMA and recon.get('status') == 'PASS', 'RECONCILIATION_REQUIRED')
    require(recon.get('telemetry_sha256') == seal['telemetry']['sha256']
            and recon.get('raw_sha256') == raw_binding['sha256']
            and recon.get('profile_sha256') == seal['profile']['sha256'], 'RECONCILIATION_BINDING_MISMATCH')
    for key in ('account_identity', 'positions', 'orders', 'balance', 'costs', 'swap', 'margin', 'openings', 'continuity'):
        require(recon.get('checks', {}).get(key) == 'PASS', 'RECONCILIATION_INCOMPLETE:' + key)
    require(recon.get('material_serial_dependence') is False, 'DISJOINT_EXCHANGEABILITY_REFUTED_OR_UNVERIFIED')
    # Receipts must be hash-bound, not a boolean inserted into a daily P&L file.
    receipts = _bound(recon.get('receipts'))
    require(isinstance(receipts, dict) and receipts.get('schema') == 'qm.ftmo-c6-opening-receipts/v1'
            and receipts.get('profile_sha256') == seal['profile']['sha256'], 'OPENING_RECEIPTS_REQUIRED')
    opened = {}
    seen = set()
    for entry in receipts.get('rows', []):
        key = str(entry.get('deal_id', ''))
        require(key and key not in seen, 'DUPLICATE_OR_MISSING_OPENING_DEAL')
        seen.add(key)
        ts = timestamp(entry['ts_utc'])
        require(entry.get('entry') == 'IN' and entry.get('position_id')
                and entry.get('account_login') == profile['account_login']
                and entry.get('magic') in magics, 'INVALID_POSITION_OPENING_RECEIPT')
        bucket = int(ts.timestamp()) // 300 * 300
        opened[bucket] = opened.get(bucket, 0) + 1
    try:
        first = dt.date.fromisoformat(seal['first_sealed_prague_day'])
        last = dt.date.fromisoformat(seal['last_sealed_prague_day'])
    except (KeyError, ValueError) as exc:
        raise C6Refusal('SEALED_DAY_RANGE_REQUIRED') from exc
    require(first <= last, 'INVALID_SEALED_DAY_RANGE')
    trace_start = dt.datetime.combine(first, dt.time(), PRAGUE).astimezone(dt.timezone.utc)
    trace_end = dt.datetime.combine(last + dt.timedelta(days=1), dt.time(), PRAGUE).astimezone(dt.timezone.utc)
    require(raw_rows[0]['_timestamp'] == trace_start and raw_rows[-1]['_timestamp'] == trace_end, 'RAW_FIRST_SEALED_ORIGIN_OR_END_MISMATCH')
    indexed = {}
    for row in report.get('m5_rows', []):
        ts = timestamp(row['interval_start_utc'])
        end = timestamp(row['interval_end_utc'])
        require(end - ts == dt.timedelta(seconds=300) and int(ts.timestamp()) % 300 == 0, 'INVALID_M5_INTERVAL')
        require(ts not in indexed, 'DUPLICATE_M5_INTERVAL')
        require(int(row['prague_day_key']) == int(ts.astimezone(PRAGUE).strftime('%Y%m%d')), 'PRAGUE_DAY_MISMATCH')
        require(count(row['sample_count']) > 0, 'EMPTY_M5_INTERVAL')
        require(cents(row['interval_min_equity']) <= cents(row['equity']), 'MINIMUM_ABOVE_ENDPOINT')
        require(count(row['open_positions']) == sum(count(x) for x in row['positions_by_magic'].values())
                and count(row['pending_orders']) == sum(count(x) for x in row['pending_orders_by_magic'].values()), 'INVENTORY_NOT_RECONCILED')
        indexed[ts] = row
    boundaries = recon.get('days', [])
    require(len(boundaries) == (last - first).days + 1, 'MISSING_SEALED_DAY')
    days = []
    previous_balance = previous_inventory = None
    consumed = set()
    for offset, boundary in enumerate(boundaries):
        date = first + dt.timedelta(days=offset)
        require(boundary.get('day') == date.isoformat(), 'DAY_GAP_OR_ORIGIN_CHANGED')
        start = dt.datetime.combine(date, dt.time(), PRAGUE).astimezone(dt.timezone.utc)
        end = dt.datetime.combine(date + dt.timedelta(days=1), dt.time(), PRAGUE).astimezone(dt.timezone.utc)
        require(timestamp(boundary['anchor_ts_utc']) == start and boundary.get('complete') is True, 'EXACT_COMPLETE_MIDNIGHT_REQUIRED')
        anchor = cents(boundary['anchor_balance'])
        inv = (count(boundary['positions_start']), count(boundary['orders_start']))
        midnight = midnights.get(start)
        require(midnight is not None and cents(midnight['balance']) == anchor
                and (midnight['open_positions'], midnight['pending_orders']) == inv, 'RAW_MIDNIGHT_ANCHOR_OR_INVENTORY_MISMATCH')
        require(previous_balance is None or (anchor == previous_balance and inv == previous_inventory), 'UNRECONCILED_DAY_BOUNDARY')
        points = []
        already_opened = False
        cursor = start
        while cursor < end:
            require(cursor in indexed, 'ABSTAIN_MISSING_M5_INTERVAL')
            row = indexed[cursor]
            consumed.add(cursor)
            already_opened |= opened.get(int(cursor.timestamp()), 0) > 0
            balance, equity = cents(row['balance']), cents(row['equity'])
            inventory_end = (count(row['open_positions']), count(row['pending_orders']))
            flat = inventory_end == (0, 0)
            require(not flat or balance == equity, 'FLAT_BALANCE_EQUITY_MISMATCH')
            points.append(Point(balance - anchor, cents(row['interval_min_equity']) - anchor, already_opened, flat))
            cursor += dt.timedelta(seconds=300)
        require(balance == cents(boundary['end_balance']) and inventory_end == (count(boundary['positions_end']), count(boundary['orders_end'])), 'END_BOUNDARY_MISMATCH')
        days.append(compact_day(points, balance - anchor, inv == (0, 0), flat))
        previous_balance, previous_inventory = balance, inventory_end
    # A seal names the entire for-record path; cropping/offset search is refused.
    # The final exact midnight sample is boundary evidence, not another day.
    require(set(indexed) - consumed == {trace_end} and indexed[trace_end]['sample_count'] == 1,
            'TRACE_OUTSIDE_SEALED_RANGE_OR_PARTIAL_DAYS')
    require(set(opened).issubset({int(t.timestamp()) for t in consumed}), 'OPENING_OUTSIDE_SEALED_TRACE')
    require(days[0].flat_start and days[-1].flat_end, 'ABSTAIN_NONFLAT_TRACE_BOUNDARY')
    require(cents(raw_rows[-1]['balance']) == previous_balance and raw_rows[-1]['open_positions'] == 0
            and raw_rows[-1]['pending_orders'] == 0, 'UNRECONCILED_FINAL_MIDNIGHT')
    return tuple(days), initial, {'seal_sha256': binding['sha256'], 'origin': first.isoformat(),
                                 'last_day': last.isoformat(), 'profile_sha256': seal['profile']['sha256'],
                                 'book_id': profile['book_id'], 'candidate_ids': sorted(candidate_sets[0]),
                                 'timebox_config_sha256': profile['timebox_config_sha256'],
                                 'raw_sha256': raw_binding['sha256'], 'telemetry_sha256': seal['telemetry']['sha256']}


def _less_fraction(value, base, fraction):
    n, d = Decimal(str(fraction)).as_integer_ratio()
    return value * d < base * n


def phase(days, start, horizon, initial, target):
    require(days[start].flat_start, 'ABSTAIN_NONFLAT_REQUIRED_GAUNTLET_OR_PHASE_START')
    balance, opening_days = initial, 0
    target_n, target_d = (1 + target).as_integer_ratio()
    for index in range(start, start + horizon):
        day = days[index]
        for point in day.points:
            minimum = balance + point.minimum
            if (_less_fraction(minimum, initial, 1 - RULES.maximum_total_loss_fraction)
                    or _less_fraction(point.minimum, initial, -RULES.maximum_daily_loss_fraction)):
                return 'BREACH', index
            traded = opening_days + int(point.opened)
            if (point.flat and traded >= RULES.minimum_trading_days
                    and (balance + point.balance) * target_d > initial * target_n):
                return 'PASS', index
        balance += day.delta
        opening_days += int(any(p.opened for p in day.points))
    return 'TIMEOUT', start + horizon - 1


def gauntlet(days, initial):
    require(len(days) == 90, 'COMPLETE_90_DAY_GAUNTLET_REQUIRED')
    p1, end = phase(days, 0, 60, initial, RULES.phase1_target_fraction)
    if p1 != 'PASS':
        return Outcome(False, False, p1 == 'BREACH')
    p2, _ = phase(days, end + 1, 30, initial, RULES.phase2_target_fraction)
    return Outcome(True, p2 == 'PASS', p2 == 'BREACH')


def rates(outcomes):
    rows = list(outcomes)
    require(bool(rows), 'ABSTAIN_NO_COMPLETE_GAUNTLETS')
    n, s1, s12, b = len(rows), sum(x.p1 for x in rows), sum(x.joint for x in rows), sum(x.breach for x in rows)
    require(s12 <= s1, 'JOINT_COUNT_EXCEEDS_P1')
    result = {'n': n, 'p1_count': s1, 'joint_count': s12, 'breach_count': b,
              'p1': s1 / n, 'joint': s12 / n, 'breach': b / n, 'p2_conditional': s12 / s1 if s1 else 0.0}
    require(math.isclose(result['joint'], result['p1'] * result['p2_conditional'], abs_tol=1e-15), 'JOINT_IDENTITY_FAILED')
    return result


def percentile(values, p):
    v = sorted(values)
    x = (len(v) - 1) * p
    lo, hi = math.floor(x), math.ceil(x)
    return v[lo] + (v[hi] - v[lo]) * (x - lo)


def _cdf(k, n, p):
    if p <= 0:
        return 1.0
    if p >= 1:
        return float(k >= n)
    logs = [math.lgamma(n + 1) - math.lgamma(i + 1) - math.lgamma(n - i + 1)
            + i * math.log(p) + (n - i) * math.log1p(-p) for i in range(k + 1)]
    peak = max(logs)
    return min(1.0, math.exp(peak) * math.fsum(math.exp(x - peak) for x in logs))


def cp_upper(k, n, tail=.025):
    require(type(k) is int and type(n) is int and 0 <= k <= n and n > 0 and 0 < tail < .5, 'INVALID_BINOMIAL_COUNT')
    if k == n:
        return 1.0
    if k == 0:
        return -math.expm1(math.log(tail) / n)
    lo, hi = 0.0, 1.0
    for _ in range(80):
        mid = (lo + hi) / 2
        if _cdf(k, n, mid) > tail:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def cp_lower(k, n, tail=.025):
    return 1.0 - cp_upper(n - k, n, tail)


def confidence(observed, replicas, alpha=.05):
    tail = alpha / 2
    mbb = {name: percentile([r[key] for r in replicas], 1 - tail if key == 'breach' else tail)
           for name, key in [('breach_upper_95', 'breach'), ('p1_lower_95', 'p1'),
                             ('p2_conditional', 'p2_conditional'), ('joint_credit', 'joint')]}
    n, s1, s12, b = (observed[k] for k in ('n', 'p1_count', 'joint_count', 'breach_count'))
    exact = {'breach_upper_95': cp_upper(b, n, tail), 'p1_lower_95': cp_lower(s1, n, tail),
             'p2_conditional': cp_lower(s12, s1, tail) if s1 else 0.0, 'joint_credit': cp_lower(s12, n, tail)}
    credit = {key: (max if key == 'breach_upper_95' else min)(mbb[key], exact[key]) for key in exact}
    floors = {'breach': {'n': n, 'floor': 36}, 'p2_conditional': {'n': s1, 'floor': 23}, 'joint': {'n': n, 'floor': 9}}
    for value in floors.values():
        value['status'] = 'SUFFICIENT' if value['n'] >= value['floor'] else 'LOW_SAMPLE'
    return {'mbb': mbb, 'exact': exact, **credit, 'sample_size': floors}


def estimate(days: Sequence[Day], initial: int, *, replicates=None):
    replicas_n = BOOTSTRAP['replicates'] if replicates is None else replicates
    require(type(replicas_n) is int and replicas_n >= BOOTSTRAP['replicates_floor'], 'BOOTSTRAP_BELOW_REPLICATE_FLOOR')
    require(len(days) >= 90, 'ABSTAIN_FEWER_THAN_90_COMPLETE_DAYS')
    block = BOOTSTRAP['block_calendar_days']
    require(block == 60, 'METHOD_VERSION_REQUIRES_60_DAY_BLOCKS')
    starts = [s for s in range(len(days) - block + 1) if days[s].flat_start and days[s + block - 1].flat_end]
    require(bool(starts), 'ABSTAIN_INSUFFICIENT_COMPATIBLE_BLOCKS')
    # Bounded memoization uses normalized paths, not original dates or sleeve samples.
    evaluate = lru_cache(maxsize=8192)(lambda path: gauntlet(path, initial))
    observed = rates(evaluate(tuple(days[s:s + 90])) for s in range(0, len(days) - 89, 90))
    rng = random.Random(BOOTSTRAP['seed'])
    replicas = []
    for _ in range(replicas_n):
        sampled = []
        while len(sampled) < len(days):
            s = rng.choice(starts)
            sampled.extend(days[s:s + block])
        sampled = sampled[:len(days)]
        replicas.append(rates(evaluate(tuple(sampled[s:s + 90])) for s in range(len(days) - 89)))
    bounds = confidence(observed, replicas, BOOTSTRAP['alpha'])
    gates = PROBABILITY['gates']
    checks = {'breach': bounds['breach_upper_95'] <= gates['breach']['upper_95_max'],
              'p2_conditional': bounds['p2_conditional'] >= gates['two_phase']['p2_conditional_min'],
              'joint': bounds['joint_credit'] >= gates['two_phase']['joint_min']}
    enough = all(v['status'] == 'SUFFICIENT' for v in bounds['sample_size'].values())
    return {'schema': RESULT_SCHEMA, 'method': 'C6-A_WORST_MBB_FIXED_ORIGIN_CP',
            'status': 'LOW_SAMPLE' if not enough else 'ESTIMATED', 'decision_eligible': False,
            'activation': INERT, 'limitation': LIMITATION, 'days': len(days),
            'block_days': [block], 'compatible_source_blocks': len(starts), 'replicates': replicas_n,
            'seed': BOOTSTRAP['seed'], 'observed_disjoint': observed, **bounds,
            'threshold_checks_diagnostic': checks, 'would_meet_all_gates': enough and all(checks.values()),
            'empty_p1_replica_count': sum(r['p1_count'] == 0 for r in replicas),
            'joint_identity_checked_replicates': len(replicas)}


def evaluate_binding(binding, *, replicates=None):
    try:
        days, initial, provenance = load_trace(binding)
        return {**estimate(days, initial, replicates=replicates), 'provenance': provenance}
    except (C6Refusal, KeyError, TypeError, AttributeError, UnicodeError, IndexError) as exc:
        return {'schema': RESULT_SCHEMA, 'status': 'ABSTAIN', 'reason': str(exc),
                'decision_eligible': False, 'activation': INERT, 'limitation': LIMITATION}


def evaluate_if_active(contract, binding):
    flags = [contract['probability']['gates'][k]['enforcement_status'] for k in ('breach', 'two_phase')]
    if flags == [INERT, INERT]:
        return None  # Deliberately do not inspect or open the binding while inert.
    require(flags == [ACTIVE, ACTIVE], 'C6_PARTIAL_OR_UNKNOWN_ACTIVATION_REFUSED')
    result = evaluate_binding(binding)
    return {**result, 'activation': ACTIVE, 'decision_eligible': result['status'] == 'ESTIMATED'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--seal', required=True)
    ap.add_argument('--expected-sha256', required=True)
    args = ap.parse_args()
    result = evaluate_binding({'path': args.seal, 'sha256': args.expected_sha256})
    print(json.dumps(result, indent=2, sort_keys=True))
    return 2 if result['status'] == 'ABSTAIN' else 0


if __name__ == '__main__':
    raise SystemExit(main())
