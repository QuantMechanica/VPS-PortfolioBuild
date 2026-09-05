"""C6-A synthetic path, finite sample, telemetry and inertness fixtures."""
import copy
import datetime as dt
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import random

import pytest

from tools.strategy_farm.portfolio import ftmo_c6_estimator as c6
from tools.strategy_farm.portfolio import ftmo_trial_telemetry as telemetry
from tools.strategy_farm.portfolio import ftmo_timebox_eval as timebox
from tools.strategy_farm.portfolio.ftmo_rule_contract import DEFAULT_RULEPACK_PATH

INITIAL = 10_000_000


def day(delta=22_000, low=-10_000, opened=True, flat=True):
    return c6.Day(delta, (c6.Point(delta, low, opened, flat),), True, flat)


def bind(path, value):
    path.write_text(json.dumps(value, sort_keys=True) + '\n', encoding='utf-8')
    return {'path': str(path.resolve()), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def file_binding(path):
    return {'path': str(path.resolve()), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def sealed_fixture(tmp_path, *, first=dt.date(2024, 1, 1), days=2, hazard=False):
    """A declared synthetic M5-sampled account; no external service is used."""
    raw = tmp_path / 'raw.jsonl'
    rows, boundaries, receipts = [], [], []
    balance, sequence = 100_000, 0
    for offset in range(days):
        date = first + dt.timedelta(days=offset)
        start = dt.datetime.combine(date, dt.time(), c6.PRAGUE).astimezone(dt.timezone.utc)
        end = dt.datetime.combine(date + dt.timedelta(days=1), dt.time(), c6.PRAGUE).astimezone(dt.timezone.utc)
        anchor = balance
        cursor = start
        while cursor < end:
            if cursor == end - dt.timedelta(seconds=300):
                balance += 220
                receipts.append({'deal_id': str(offset), 'position_id': str(offset + 1),
                                 'account_login': 123, 'magic': 1, 'entry': 'IN', 'ts_utc': cursor.isoformat()})
            planted = hazard and offset == 3 and cursor == start + dt.timedelta(hours=12)
            rows.append({'schema': telemetry.RAW_SCHEMA, 'event': 'SAMPLE', 'trial_id': 'SYNTHETIC',
                         'session_id': 'synthetic-1', 'sequence': sequence, 'ts_utc': cursor.isoformat(),
                         'ts_epoch': int(cursor.timestamp()), 'prague_day_key': int(date.strftime('%Y%m%d')),
                         'source': 'TIMER', 'account_login': 123, 'account_server': 'Synthetic-Tester',
                         'currency': 'USD', 'balance': balance, 'equity': balance - (5000.01 if planted else 0),
                         'open_positions': int(planted), 'pending_orders': 0, 'reconciliation_complete': True,
                         'positions': [{'ticket': 1, 'position_id': 1, 'magic': 1, 'profit': -5000.01}] if planted else [],
                         'orders': []})
            sequence += 1
            cursor += dt.timedelta(seconds=300)
        boundaries.append({'day': date.isoformat(), 'anchor_ts_utc': start.isoformat(),
                           'complete': True, 'anchor_balance': anchor, 'end_balance': balance,
                           'positions_start': 0, 'orders_start': 0, 'positions_end': 0, 'orders_end': 0})
    tail = dict(rows[-1], sequence=sequence, ts_utc=end.isoformat(), ts_epoch=int(end.timestamp()),
                prague_day_key=int(end.astimezone(c6.PRAGUE).strftime('%Y%m%d')))
    rows.append(tail)
    raw.write_text(''.join(json.dumps(r) + '\n' for r in rows), encoding='utf-8')
    evidence = bind(tmp_path / 'synthetic-evidence.json', {'fixture': 'synthetic-only'})
    binary = tmp_path / 'synthetic.ex5'
    binary.write_bytes(b'SYNTHETIC_TEST_BYTES_NOT_AN_EXECUTABLE')
    setfile = tmp_path / 'synthetic.set'
    setfile.write_text('RISK_FIXED=1000\nRISK_PERCENT=0\n', encoding='utf-8')
    binaries = bind(tmp_path / 'binaries.json', {'schema': 'qm.ftmo-c6-binary-manifest/v1',
                    'book_id': 'synthetic-book', 'rows': [{'candidate_id': 'fixture', 'binding': file_binding(binary)}]})
    sets = bind(tmp_path / 'sets.json', {'schema': 'qm.ftmo-c6-set-manifest/v1', 'book_id': 'synthetic-book',
                'rows': [{'candidate_id': 'fixture', 'magic': 1, 'binding': file_binding(setfile)}]})
    config = bind(tmp_path / 'config.json', {k: c6.BOOTSTRAP[k] for k in ('method', 'replicates', 'replicates_floor', 'seed', 'alpha', 'block_calendar_days', 'ci')})
    profile = {'schema': c6.PROFILE_SCHEMA, 'trial_id': 'SYNTHETIC', 'account_login': 123,
               'account_server': 'Synthetic-Tester', 'currency': 'USD', 'book_id': 'synthetic-book',
               'timebox_config_sha256': 'a' * 64,
               'initial_balance': 100000, 'RISK_FIXED': 1000, 'RISK_PERCENT': 0,
               'maximum_sample_gap_seconds': 300, 'estimator_config': config,
               'rules': file_binding(DEFAULT_RULEPACK_PATH),
               'book_binary_manifest': binaries, 'book_set_manifest': sets,
               **{key: evidence for key in ('cost_terms', 'collector_code')}}
    profile_binding = bind(tmp_path / 'profile.json', profile)
    receipt_binding = bind(tmp_path / 'receipts.json', {'schema': 'qm.ftmo-c6-opening-receipts/v1',
                           'profile_sha256': profile_binding['sha256'], 'rows': receipts})
    report = telemetry.build_report(raw, maximum_sample_gap_seconds=300)
    report_binding = bind(tmp_path / 'm5.json', report)
    recon = {'schema': c6.RECON_SCHEMA, 'status': 'PASS', 'telemetry_sha256': report_binding['sha256'],
             'raw_sha256': file_binding(raw)['sha256'], 'profile_sha256': profile_binding['sha256'],
             'checks': {k: 'PASS' for k in ('account_identity', 'positions', 'orders', 'balance', 'costs', 'swap', 'margin', 'openings', 'continuity')},
             'material_serial_dependence': False, 'receipts': receipt_binding, 'days': boundaries}
    recon_binding = bind(tmp_path / 'recon.json', recon)
    seal = {'schema': c6.SEAL_SCHEMA, 'sealed': True, 'manually_repaired_samples': False,
            'first_sealed_prague_day': first.isoformat(),
            'last_sealed_prague_day': (first + dt.timedelta(days=days - 1)).isoformat(),
            'profile': profile_binding, 'telemetry': report_binding, 'reconciliation': recon_binding}
    binding = bind(tmp_path / 'seal.json', seal)
    return binding, seal, recon, profile, report


def test_strict_loss_and_target_cents_and_position_opening_days():
    equality = [day(250_000, -500_000)] * 4
    assert c6.phase(equality, 0, 4, INITIAL, Decimal('.10'))[0] == 'TIMEOUT'
    assert c6.phase(equality[:3] + [day(250_001, -500_000)], 0, 4, INITIAL, Decimal('.10'))[0] == 'PASS'
    assert c6.phase([day(250_000, -500_001)] * 4, 0, 4, INITIAL, Decimal('.10'))[0] == 'BREACH'
    assert c6.phase([day(1_000_001, opened=False)] * 4, 0, 4, INITIAL, Decimal('.10'))[0] == 'TIMEOUT'


def test_intraday_breach_precedes_flat_close_and_maximum_loss_is_fixed():
    points = (c6.Point(0, -500_001, True, False), c6.Point(2_000_000, 0, True, True))
    path = [day(0)] * 3 + [c6.Day(2_000_000, points, True, True)]
    assert c6.phase(path, 0, 4, INITIAL, Decimal('.10'))[0] == 'BREACH'
    assert c6.phase([day(-400_000, -400_000)] * 3, 0, 3, INITIAL, Decimal('.10'))[0] == 'BREACH'


def test_no_breach_count_after_phase_completion_and_p2_resets():
    path = [day(300_000)] * 4 + [day(140_000)] * 4 + [day(0, -600_000)] * 82
    assert c6.gauntlet(path, INITIAL) == c6.Outcome(True, True, False)
    path[4:8] = [day(0)] * 4
    assert c6.gauntlet(path, INITIAL) == c6.Outcome(True, False, True)
    with pytest.raises(c6.C6Refusal, match='COMPLETE_90'):
        c6.gauntlet(path[:-1], INITIAL)


def test_interval_compaction_retains_first_opening_and_breach_order():
    points = (c6.Point(2_000_000, 0, False, True), c6.Point(0, 0, True, False),
              c6.Point(1_500_000, 0, True, True), c6.Point(0, -600_000, True, True))
    compressed = c6.compact_day(points, 0, True, True)
    assert c6.phase([day(0)] * 3 + [compressed], 0, 4, INITIAL, Decimal('.10')) == ('PASS', 3)
    # Differential check against uncompressed paths, including random rebases.
    rng = random.Random(20)
    for _ in range(100):
        points = tuple(c6.Point(rng.randint(-600000, 1300000), rng.randint(-600000, 0), i >= 7, i % 3 == 0) for i in range(20))
        full = c6.Day(0, points, True, True)
        small = c6.compact_day(points, 0, True, True)
        for base in (INITIAL, INITIAL + 700000, INITIAL - 700000):
            assert c6.phase([day(0)] * 3 + [full], 0, 4, base, Decimal('.10')) == c6.phase([day(0)] * 3 + [small], 0, 4, base, Decimal('.10'))


def test_exact_null_bounds_and_sample_floors():
    assert c6.cp_upper(0, 36) == pytest.approx(1 - .025 ** (1/36))
    assert c6.cp_upper(0, 35) > .10 >= c6.cp_upper(0, 36)
    assert c6.cp_lower(22, 22) < .85 <= c6.cp_lower(23, 23)
    assert c6.cp_lower(8, 8) < .65 <= c6.cp_lower(9, 9)
    assert c6.cp_upper(5, 10) == pytest.approx(.8129139715526015)
    assert c6.cp_lower(5, 10) == pytest.approx(.1870860284473985)
    # Stable beyond direct binomial coefficient floating-point capacity.
    assert .4 < c6.cp_lower(500, 1000) < .5 < c6.cp_upper(500, 1000) < .6


def test_worst_of_exact_guard_caps_optimistic_bootstrap_and_conditional_denominator():
    observed = c6.rates([c6.Outcome(True, True, False)] * 35 + [c6.Outcome(False, False, True)])
    optimistic = c6.rates([c6.Outcome(True, True, False)] * 36)
    value = c6.confidence(observed, [optimistic] * 100)
    assert value['breach_upper_95'] == c6.cp_upper(1, 36) > c6.cp_upper(0, 36)
    assert value['joint_credit'] == c6.cp_lower(35, 36)
    assert value['sample_size']['p2_conditional']['n'] == 35
    low = c6.confidence(c6.rates([c6.Outcome(False, False, False)] * 8), [optimistic] * 100)
    assert low['p2_conditional'] == 0
    assert all(v['status'] == 'LOW_SAMPLE' for v in low['sample_size'].values())


def test_known_synthetic_mixture_and_null_bootstrap():
    safe = c6.estimate([day()] * 180, INITIAL, replicates=100)
    assert safe['breach_upper_95'] == pytest.approx(1 - .025 ** .5)
    assert safe['status'] == 'LOW_SAMPLE' and safe['decision_eligible'] is False
    null = c6.estimate([day(0)] * 90, INITIAL, replicates=100)
    assert null['empty_p1_replica_count'] == 100 and null['joint_credit'] == 0
    hazard = c6.estimate([day(0, -600_000)] * 90, INITIAL, replicates=100)
    assert hazard['breach_upper_95'] == 1 and hazard['observed_disjoint']['breach'] == 1
    assert hazard['joint_identity_checked_replicates'] == 100
    # Exactly one hazard gauntlet and one safe gauntlet: known observed rate 1/2.
    mixture = c6.estimate([day(0, -600_000)] * 90 + [day()] * 90, INITIAL, replicates=100)
    assert mixture['observed_disjoint']['breach'] == .5
    assert mixture['exact']['breach_upper_95'] == c6.cp_upper(1, 2)
    assert mixture['mbb']['breach_upper_95'] >= .5


def test_known_bernoulli_path_generator_probability_recovered():
    rng = random.Random(20260905)
    p = .2
    outcomes = [c6.gauntlet(([day(0, -600_000)] + [day()] * 89) if rng.random() < p else [day()] * 90, INITIAL) for _ in range(200)]
    observed = c6.rates(outcomes)
    assert abs(observed['breach'] - p) < .06
    assert c6.cp_lower(observed['breach_count'], 200) <= p <= c6.cp_upper(observed['breach_count'], 200)


def test_incompatible_boundaries_abstain_without_dropping_starts():
    with pytest.raises(c6.C6Refusal, match='COMPATIBLE_BLOCKS'):
        c6.estimate([day(flat=False)] * 90, INITIAL, replicates=100)
    with pytest.raises(c6.C6Refusal, match='REPLICATE_FLOOR'):
        c6.estimate([day()] * 90, INITIAL, replicates=99)
    path = [day()] * 90
    path[0] = c6.Day(0, (), False, False)
    with pytest.raises(c6.C6Refusal, match='NONFLAT_REQUIRED'):
        c6.estimate(path, INITIAL, replicates=100)


@pytest.mark.parametrize('first,intervals', [(dt.date(2024,3,31), 276), (dt.date(2024,10,27), 300)])
def test_raw_compacted_replay_and_exact_prague_dst_day(tmp_path, first, intervals):
    binding, seal, recon, profile, report = sealed_fixture(tmp_path, first=first, days=1)
    days, initial, provenance = c6.load_trace(binding)
    assert initial == INITIAL and len(days) == 1 and provenance['origin'] == first.isoformat()
    assert len(report['m5_rows']) == intervals + 1
    assert c6.evaluate_binding(binding)['reason'] == 'ABSTAIN_FEWER_THAN_90_COMPLETE_DAYS'


@pytest.mark.parametrize('fault,reason', [('origin', 'RAW_FIRST_SEALED'), ('recon', 'RECONCILIATION_INCOMPLETE'),
                                        ('serial', 'EXCHANGEABILITY'), ('m5', 'COMPACTED_RAW'),
                                        ('gap', 'ABSTAIN_TELEMETRY_GAPS'), ('profile', 'RAW_EXACT_PROFILE')])
def test_inadmissible_trace_fails_closed(tmp_path, fault, reason):
    binding, seal, recon, profile, report = sealed_fixture(tmp_path)
    if fault == 'origin':
        seal['first_sealed_prague_day'] = '2024-01-02'
    elif fault in ('recon', 'serial'):
        if fault == 'recon':
            recon['checks']['margin'] = 'MISSING'
        else:
            recon['material_serial_dependence'] = True
        seal['reconciliation'] = bind(tmp_path / 'recon.json', recon)
    elif fault == 'profile':
        profile['account_server'] = 'wrong-server'
        seal['profile'] = bind(tmp_path / 'profile.json', profile)
    else:
        if fault == 'm5':
            report['m5_rows'][0]['interval_min_equity'] -= .01
        else:
            report['continuity']['status'] = 'FAIL_GAPS'
        seal['telemetry'] = bind(tmp_path / 'm5.json', report)
    binding = bind(tmp_path / 'seal.json', seal)
    result = c6.evaluate_binding(binding)
    assert result['status'] == 'ABSTAIN' and reason in result['reason']


def test_bound_closed_pnl_and_tampered_raw_are_refused(tmp_path):
    closed = bind(tmp_path / 'closed.json', {'schema': 'FTMO_DAILY_NET_V1'})
    assert 'CLOSED_PNL' in c6.evaluate_binding(closed)['reason']
    binding, *_ = sealed_fixture(tmp_path)
    with (tmp_path / 'raw.jsonl').open('a') as f:
        f.write(' ')
    assert 'INPUT_SHA256_MISMATCH' in c6.evaluate_binding(binding)['reason']


def test_candidate_binary_and_set_bytes_are_bound(tmp_path):
    binding, seal, recon, profile, report = sealed_fixture(tmp_path)
    (tmp_path / 'synthetic.set').write_text('RISK_FIXED=1000\nRISK_PERCENT=1\n')
    assert 'INPUT_SHA256_MISMATCH' in c6.evaluate_binding(binding)['reason']
    manifest = json.loads((tmp_path / 'sets.json').read_text())
    manifest['rows'][0]['binding'] = file_binding(tmp_path / 'synthetic.set')
    profile['book_set_manifest'] = bind(tmp_path / 'sets.json', manifest)
    seal['profile'] = bind(tmp_path / 'profile.json', profile)
    binding = bind(tmp_path / 'seal.json', seal)
    assert 'CANDIDATE_FIXED_RISK_PROFILE_MISMATCH' in c6.evaluate_binding(binding)['reason']


def test_full_90_day_compacted_path_with_planted_breach(tmp_path):
    binding, *_ = sealed_fixture(tmp_path, days=90, hazard=True)
    result = c6.evaluate_binding(binding, replicates=100)
    assert result['status'] == 'LOW_SAMPLE', result
    assert result['observed_disjoint']['breach_count'] == 1
    assert result['breach_upper_95'] == 1 and result['decision_eligible'] is False


def test_contract_inertness_never_reads_binding(monkeypatch):
    def fail(*args, **kwargs):
        raise AssertionError('inert input access')
    monkeypatch.setattr(c6, '_bound', fail)
    assert c6.evaluate_if_active(timebox.PROBABILITY_CONTRACT.payload, object()) is None
    changed = copy.deepcopy(timebox.PROBABILITY_CONTRACT.payload)
    changed['probability']['gates']['breach']['enforcement_status'] = c6.ACTIVE
    with pytest.raises(c6.C6Refusal, match='PARTIAL_OR_UNKNOWN'):
        c6.evaluate_if_active(changed, object())


def test_inert_timebox_bytes_ignore_even_invalid_c6_binding(tmp_path, monkeypatch):
    from tools.strategy_farm.tests import test_ftmo_timebox_eval as fixtures
    cost_sha = fixtures._cost(tmp_path / 'costs.json')
    stream = tmp_path / 'daily.jsonl'
    fixtures._jsonl(stream, fixtures._daily_rows('10128:XAUUSD', cost_sha, 140))
    streams = [{'sleeve_id': '10128:XAUUSD', 'symbol': 'XAUUSD', 'ftmo_code': 'XAU/USD',
                'stream_schema': timebox.DAILY_STREAM_SCHEMA, 'path': str(stream)}]
    config = timebox.prepare_config(fixtures._spec(tmp_path, streams, fixtures._single_comp()))
    baseline = timebox.canonical_json_bytes(timebox.evaluate_config(config, fixtures._config_sha(config)))
    changed = timebox.canonical_json_bytes(timebox.evaluate_config(config, fixtures._config_sha(config), c6_binding=object()))
    assert changed == baseline
    assert 'c6' not in json.loads(changed)
    monkeypatch.setattr(timebox, 'INERT_C6_GATES', {'breach': c6.ACTIVE, 'two_phase': c6.ACTIVE})
    monkeypatch.setattr(c6, 'evaluate_if_active', lambda *args: {
        'status': 'ESTIMATED', 'decision_eligible': True, 'would_meet_all_gates': True,
        'provenance': {'timebox_config_sha256': 'b' * 64, 'book_id': 'another-book', 'candidate_ids': ['other']}})
    mismatched = timebox.evaluate_config(config, fixtures._config_sha(config), c6_binding=object())
    assert mismatched['status'] == 'ABSTAIN_C6'
    assert mismatched['c6']['reason'] == 'C6_COMPOSITION_BINDING_MISMATCH'
    assert mismatched['c6']['decision_eligible'] is False
