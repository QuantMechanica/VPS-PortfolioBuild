from __future__ import annotations
import datetime as dt
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import random
import statistics
import subprocess
import sys
import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT), str(ROOT / 'framework/scripts'), str(ROOT / 'tools/strategy_farm')]
from q08_davey import dsr_v2 as v2, sub_8_2_dsr_mc_fdr as legacy, aggregate
import evidence_status


def trades(values):
    first = dt.datetime(2025, 1, 1, tzinfo=dt.UTC)
    return [{'time': (first + dt.timedelta(days=i)).timestamp(), 'net': value, 'profit': value}
            for i, value in enumerate(values)]


def save(path, data):
    path.write_text(json.dumps(data, allow_nan=False), encoding='utf-8')
    return {'path': str(path.resolve()), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def sealed(tmp_path, values, *, selection=False, numeric=0):
    window = {'from': '2025-01-01', 'to': (dt.date(2025, 1, 1) + dt.timedelta(days=len(values)-1)).isoformat()}
    research = ['candidate', 'loser-1', 'loser-2']
    selected = ['arm-' + str(i) for i in range(154 + numeric)] if selection else []
    ids = research + selected
    sr = v2.moments(values)['sharpe_daily']
    srs = [sr] + [-.01 + i * .0001 for i in range(len(ids)-1)]
    rows = [{'trial_id': key, 'sharpe_daily': srs[i], 'n_calendar_days': len(values),
             'series_sha256': hashlib.sha256(json.dumps(values, separators=(',', ':')).encode()).hexdigest()
                 if i == 0 else hashlib.sha256(key.encode()).hexdigest()} for i, key in enumerate(ids)]
    history = {'schema': 'qm.dsr-search-history/v1', 'complete': True, 'unit': 'candidate_configuration',
               'annual_measurements_are_trials': False, 'research_trial_ids': research,
               'selection_trial_ids': selected, 'numeric_trial_count': numeric}
    cohort = {'schema': 'qm.dsr-research-cohort/v1', 'complete': True, 'losers_included': True,
              'frequency': 'CALENDAR_DAY', 'window': window, 'rows': rows}
    context = {'schema': v2.SCHEMA, 'sealed': True, 'ea_id': 42, 'symbol': 'EURUSD.DWX',
               'frequency': 'CALENDAR_DAY', 'timezone': 'UTC', 'initial_balance': 1,
               'window': window, 'costs_attested': True, 'candidate_trial_id': 'candidate',
               'selection_mode': 'DL089_V3' if selection else 'RESEARCH_ONLY',
               'cohort_std_daily': statistics.stdev(srs),
               'search_history': save(tmp_path/'history.json', history),
               'research_cohort': save(tmp_path/'cohort.json', cohort)}
    if selection:
        from opt_census import SEALED_RULE_SHA256
        context['trial_declaration'] = save(tmp_path/'declaration.json', {
            'authority': 'DL-089', 'sealed_rule_sha256': SEALED_RULE_SHA256,
            'declared_trial_count': 154 + numeric})
    return save(tmp_path/'context.json', context), context, history, cohort


def test_known_answer_normal_single_trial():
    # Analytical PSR special case: skew=0, Pearson kurtosis=3, SR=.1, T=101.
    result = v2.calculate({'sharpe_daily': .1, 'skew': 0, 'pearson_kurtosis': 3,
                           'n_calendar_days': 101}, 1, 0)
    assert result['z'] == pytest.approx(1 / math.sqrt(1.005), abs=1e-14)
    # 70-decimal independent mpmath erf evaluation, not rounded paper typography.
    assert result['dsr_probability'] == pytest.approx(.840741327801351825670037533614557, abs=1e-12)


def test_known_answer_expected_max_two_trials():
    # Phi^-1(.5)=0; independently calculated Phi^-1(1-1/(2e))=.9004525966377902.
    assert v2.expected_max_sharpe(2, .1) == pytest.approx(.051975534428059392454489126406228, abs=1e-12)


def test_full_calendar_zero_days_and_timezone():
    values, active = v2.daily_series([{'ts_utc': '2025-01-01T23:30:00Z', 'net': 10}],
                                     '2025-01-01', '2025-01-03', timezone='Europe/Prague', initial_balance=100)
    assert values == [0, .1, 0] and active == 1


def test_units_and_pearson_kurtosis():
    values = [x for _ in range(60) for x in (-1., 0., 1.)]
    stats = v2.moments(values)
    assert stats['pearson_kurtosis'] == pytest.approx(1.5)
    a, b = [v2.calculate(stats, 10, .02, annual_days=n) for n in (252, 365)]
    assert a['dsr_p'] == b['dsr_p']
    assert v2.moments([x*100 for x in values]) == pytest.approx(stats, abs=1e-12)


def test_legacy_empty_peers_deferred_pass_and_default_unchanged(monkeypatch):
    monkeypatch.delenv('QM_DSR_V2', raising=False)
    sample = trades([.01, .02, -.005] * 100)
    old = legacy.run(sample, portfolio=[])
    assert old['status'] == 'PASS' and 'deferred' in old['detail'].lower()
    assert legacy.run(sample, portfolio=[], dsr_context={'invalid': True}) == old


def test_enabled_missing_context_cannot_pass(monkeypatch):
    monkeypatch.setenv('QM_DSR_V2', '1')
    result = legacy.run(trades([.01, .02, -.005] * 100), portfolio=[])
    assert result['status'] == 'INVALID'
    assert result['evidence']['statistical_status'] == 'uncorrected_selection'
    verdict, labels = aggregate._aggregate_verdict([result], trades=trades([1, 2]))
    assert verdict == 'INVALID' and labels[result['name']] == 'UNCORRECTED_SELECTION'


def test_selected_noise_never_gets_empty_peer_pass(tmp_path):
    rng = random.Random(20260905)
    series = [[rng.gauss(0, .01) for _ in range(365)] for _ in range(154)]
    winner = max(series, key=lambda x: v2.moments(x)['sharpe_daily'])
    # Use the actual whole simulated search cohort, not only the winner.
    sigma = statistics.stdev(v2.moments(x)['sharpe_daily'] for x in series)
    result = v2.calculate(v2.moments(winner), 154, sigma)
    assert result['dsr_p'] > .05
    assert v2.calculate(v2.moments([-.01, .01]*100), 154, sigma)['dsr_p'] > .5


def test_sealed_dl089_numeric_trials_and_years_not_counted(tmp_path):
    values = [.01, -.01, .002] * 120
    binding, *_ = sealed(tmp_path, values, selection=True, numeric=7)
    result = v2.evaluate(trades(values), binding=binding, ea_id=42, symbol='EURUSD.DWX')
    assert result['detail'] == 'DSR_V2_COMPUTED'
    assert result['evidence']['selection_trial_count'] == 161
    assert result['evidence']['effective_trial_count'] == 164


@pytest.mark.parametrize('defect', ['stale_context', 'wrong_identity', 'missing_loser', 'winner_only',
                                  'wrong_sigma', 'wrong_series', 'missing_history', 'wrong_declaration'])
def test_inadmissible_context_abstains(tmp_path, defect):
    values = [.01, -.01, .002] * 120
    binding, context, history, cohort = sealed(tmp_path, values, selection=True)
    if defect == 'wrong_identity': context['ea_id'] = 43
    if defect == 'winner_only': cohort['losers_included'] = False
    if defect == 'missing_loser': cohort['rows'].pop()
    if defect == 'wrong_sigma': context['cohort_std_daily'] *= 2
    if defect == 'wrong_series': cohort['rows'][0]['series_sha256'] = 'f'*64
    if defect == 'missing_history': history['complete'] = False
    if defect == 'wrong_declaration': history['numeric_trial_count'] = 7
    context['research_cohort'] = save(tmp_path/'cohort.json', cohort)
    context['search_history'] = save(tmp_path/'history.json', history)
    binding = save(tmp_path/'context.json', context)
    if defect == 'stale_context': Path(binding['path']).write_text('{}')
    result = v2.evaluate(trades(values), binding=binding, ea_id=42, symbol='EURUSD.DWX')
    assert result['status'] == 'INVALID' and result['evidence']['statistical_status'] == 'uncorrected_selection'


def test_cli_wires_context_without_running_backtests(tmp_path, monkeypatch):
    seen = {}
    def fake(*args, **kwargs):
        seen.update(kwargs)
        return {'verdict': 'PASS'}
    monkeypatch.setattr(aggregate, 'run_all', fake)
    monkeypatch.setattr(aggregate, '_print_summary', lambda _: None)
    monkeypatch.setattr(sys, 'argv', ['aggregate.py', '--ea-id', '42', '--symbol', 'EURUSD.DWX',
        '--log', str(tmp_path/'missing.jsonl'), '--dsr-context', str(tmp_path/'context.json'),
        '--expected-dsr-context-sha256', 'a'*64])
    assert aggregate.main() == 0
    assert seen['dsr_context'] == {'path': str(tmp_path/'context.json'), 'sha256': 'a'*64}


def test_projection_never_promotes_usage_and_checks_binding(tmp_path):
    source = tmp_path/'receipt.txt'
    source.write_text('receipt')
    digest = evidence_status.sha(source)
    baseline = {f'baseline_{k}_{s}': str(source) if s == 'path' else digest
                for k in ('summary', 'report', 'mq5', 'ex5', 'setfile') for s in ('path', 'sha256')}
    data = {'evidence_schema': 'q08_aggregate/v2', 'n_trades': 20, 'gross_total': 10, 'commission_total': 2,
            'baseline_run': baseline, 'portfolio_stream': {'path': str(source), 'content_sha256': digest},
            'sub_gates': [{'name': '8.2_dsr_mc_fdr', 'status': 'PASS', 'detail': 'deferred'}]}
    binding = save(tmp_path/'aggregate.json', data)
    before = Path(binding['path']).read_bytes()
    result = evidence_status.project(binding['path'])
    assert (result['technical_validity'], result['economic_result'], result['statistical_sufficiency'],
            result['evidence_binding'], result['usage']) == ('valid', 'positive', 'uncorrected_selection', 'current', 'research')
    source.write_text('changed')
    assert evidence_status.project(binding['path'])['evidence_binding'] == 'stale'
    assert Path(binding['path']).read_bytes() == before


@pytest.mark.parametrize('bad', [float('nan'), float('inf'), True])
def test_bad_numbers_rejected(bad):
    with pytest.raises(v2.DsrEvidenceError):
        v2.moments([1, bad])


def test_informative_edge_can_pass_and_short_window_retains_low_sample(tmp_path, monkeypatch):
    result = v2.calculate({'sharpe_daily': .3, 'skew': 0, 'pearson_kurtosis': 3,
                           'n_calendar_days': 1000}, 154, .03)
    assert result['dsr_p'] < .05
    values = [.01, -.01] * 20
    binding, *_ = sealed(tmp_path, values)
    result = v2.evaluate(trades(values), binding=binding, ea_id=42, symbol='EURUSD.DWX')
    assert result['evidence']['statistical_status'] == 'low_sample'
    monkeypatch.setenv('QM_DSR_V2', '1')
    _, labels = aggregate._aggregate_verdict([result], trades=trades([1, 2]))
    assert labels[result['name']] == 'LOW_SAMPLE'
