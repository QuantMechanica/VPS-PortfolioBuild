"""Inert DSR correction using a sealed, loser-inclusive selection context.

Formula: Bailey & Lopez de Prado (2014), equation 2,
https://www.davidhbailey.com/dhbpapers/deflated-sharpe.pdf .
Daily Sharpe and daily cohort dispersion enter the formula; annual values are
display-only. This module never reads or writes farm state or historical verdicts.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import re
import statistics
from zoneinfo import ZoneInfo

from .common import make_result, trade_timestamp

SCHEMA = 'qm.dsr-selection-context/v1'
GATE_NAME = '8.2_dsr_mc_fdr'
EULER = 0.5772156649015329
SHA = re.compile(r'^[0-9a-f]{64}$')


class DsrEvidenceError(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise DsrEvidenceError(reason)


def finite(value):
    require(not isinstance(value, bool), 'NONFINITE_OR_INVALID_NUMBER')
    try:
        number = float(value)
    except (ValueError, TypeError) as exc:
        raise DsrEvidenceError('NONFINITE_OR_INVALID_NUMBER') from exc
    require(math.isfinite(number), 'NONFINITE_OR_INVALID_NUMBER')
    return number


def _pairs(pairs):
    obj = {}
    for key, value in pairs:
        require(key not in obj, 'DUPLICATE_JSON_KEY')
        obj[key] = value
    return obj


def bound(binding):
    require(isinstance(binding, dict) and set(binding) == {'path', 'sha256'}, 'UNCORRECTED_SELECTION_MISSING_HASH_BOUND_CONTEXT')
    path = Path(str(binding['path']))
    require(path.is_absolute() and path.suffix.lower() not in ('.db', '.sqlite'), 'MUTABLE_OR_RELATIVE_CONTEXT')
    require(bool(SHA.fullmatch(str(binding['sha256']))), 'INVALID_CONTEXT_SHA256')
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise DsrEvidenceError('CONTEXT_FILE_UNAVAILABLE') from exc
    require(hashlib.sha256(raw).hexdigest() == binding['sha256'], 'CONTEXT_SHA256_MISMATCH')
    try:
        value = json.loads(raw.decode('utf-8-sig'), object_pairs_hook=_pairs)
    except (ValueError, UnicodeError) as exc:
        raise DsrEvidenceError('INVALID_CONTEXT_JSON') from exc
    require(isinstance(value, dict), 'CONTEXT_OBJECT_REQUIRED')
    return value


def daily_series(trades, start, end, *, timezone, initial_balance):
    """Explicit full calendar window; net cash divided by fixed initial balance."""
    try:
        first, last = dt.date.fromisoformat(start), dt.date.fromisoformat(end)
        zone = ZoneInfo(timezone)
    except (ValueError, TypeError, KeyError) as exc:
        raise DsrEvidenceError('EXPLICIT_CALENDAR_WINDOW_REQUIRED') from exc
    require(first <= last, 'REVERSED_CALENDAR_WINDOW')
    initial = finite(initial_balance)
    require(initial > 0, 'POSITIVE_INITIAL_BALANCE_REQUIRED')
    values = [0.0] * ((last - first).days + 1)
    active = set()
    for trade in trades:
        timestamp = trade_timestamp(trade)
        require(timestamp is not None and timestamp.tzinfo is not None, 'INVALID_OR_NAIVE_TRADE_TIMESTAMP')
        date = timestamp.astimezone(zone).date()
        require(first <= date <= last, 'TRADE_OUTSIDE_SEALED_CALENDAR')
        require('net' in trade, 'NET_AFTER_COSTS_REQUIRED')
        index = (date - first).days
        values[index] += finite(trade['net']) / initial
        active.add(index)
    return values, len(active)


def moments(values):
    require(len(values) >= 2, 'LOW_SAMPLE_CALENDAR_DAYS')
    values = [finite(x) for x in values]
    n = len(values)
    mean = statistics.fmean(values)
    sample_sd = statistics.stdev(values)
    require(sample_sd > 0, 'DEGENERATE_DAILY_VARIANCE')
    m2 = math.fsum((x - mean)**2 for x in values) / n
    skew = math.fsum((x - mean)**3 for x in values) / n / m2**1.5
    kurtosis = math.fsum((x - mean)**4 for x in values) / n / m2**2
    return {'sharpe_daily': mean / sample_sd, 'skew': skew, 'pearson_kurtosis': kurtosis,
            'n_calendar_days': n, 'net_return': math.fsum(values)}


def expected_max_sharpe(n_trials, cohort_std_daily):
    require(type(n_trials) is int and n_trials >= 1, 'POSITIVE_INTEGER_TRIAL_COUNT_REQUIRED')
    sigma = finite(cohort_std_daily)
    require(sigma >= 0, 'NEGATIVE_COHORT_DISPERSION')
    if n_trials == 1:
        return 0.0
    require(sigma > 0, 'UNCORRECTED_SELECTION_COHORT_DISPERSION_UNAVAILABLE')
    normal = statistics.NormalDist()
    return sigma * ((1 - EULER) * normal.inv_cdf(1 - 1 / n_trials)
                    + EULER * normal.inv_cdf(1 - 1 / (n_trials * math.e)))


def calculate(stats, n_trials, cohort_std_daily, *, annual_days=365):
    sr, skew, kurtosis = (finite(stats[k]) for k in ('sharpe_daily', 'skew', 'pearson_kurtosis'))
    n = stats['n_calendar_days']
    require(type(n) is int and n >= 60, 'LOW_SAMPLE_CALENDAR_DAYS')
    require(annual_days in (250, 252, 365), 'INVALID_DISPLAY_ANNUALIZATION')
    benchmark = expected_max_sharpe(n_trials, cohort_std_daily)
    variance_factor = 1 - skew * sr + (kurtosis - 1) * sr**2 / 4
    require(variance_factor > 0 and math.isfinite(variance_factor), 'INVALID_SHARPE_VARIANCE')
    z = (sr - benchmark) * math.sqrt(n - 1) / math.sqrt(variance_factor)
    p = .5 * math.erfc(z / math.sqrt(2))
    return {**stats, 'effective_trial_count': n_trials, 'cohort_std_daily': cohort_std_daily,
            'expected_max_sharpe_daily': benchmark, 'z': z, 'dsr_p': p,
            'dsr_probability': 1 - p, 'sharpe_annual_display': sr * math.sqrt(annual_days),
            'annual_days_display': annual_days, 'statistical_status': 'sufficient'}


def _ids(raw):
    require(isinstance(raw, list) and all(isinstance(x, str) and x for x in raw), 'TRIAL_ID_LIST_REQUIRED')
    require(len(raw) == len(set(raw)), 'DUPLICATE_TRIAL_ID')
    return set(raw)


def selection_context(binding, *, ea_id, symbol, values):
    context = bound(binding)
    require(context.get('schema') == SCHEMA and context.get('sealed') is True, 'UNCORRECTED_SELECTION_UNSEALED_CONTEXT')
    require(str(context.get('ea_id')) == str(ea_id) and context.get('symbol') == symbol, 'CONTEXT_CANDIDATE_IDENTITY_MISMATCH')
    require(context.get('frequency') == 'CALENDAR_DAY' and context.get('costs_attested') is True, 'CONTEXT_FREQUENCY_OR_COST_ATTESTATION_REQUIRED')
    history = bound(context.get('search_history'))
    cohort = bound(context.get('research_cohort'))
    require(history.get('schema') == 'qm.dsr-search-history/v1' and history.get('complete') is True, 'UNCORRECTED_SELECTION_INCOMPLETE_SEARCH_HISTORY')
    require(cohort.get('schema') == 'qm.dsr-research-cohort/v1' and cohort.get('complete') is True
            and cohort.get('losers_included') is True, 'UNCORRECTED_SELECTION_NOT_LOSER_INCLUSIVE')
    require(history.get('unit') == 'candidate_configuration' and history.get('annual_measurements_are_trials') is False, 'TRIAL_COUNT_UNIT_AMBIGUOUS')
    research, selected = _ids(history.get('research_trial_ids')), _ids(history.get('selection_trial_ids'))
    require(bool(research), 'UNCORRECTED_SELECTION_EMPTY_RESEARCH_COHORT')
    mode = context.get('selection_mode')
    declaration_count = None
    if mode == 'DL089_V3':
        declaration = bound(context.get('trial_declaration'))
        numeric = history.get('numeric_trial_count')
        require(type(numeric) is int and numeric >= 0, 'NUMERIC_TRIAL_COUNT_REQUIRED')
        # Import only the adopted constants; no census or routing operation runs.
        try:
            from tools.strategy_farm.opt_census import DECLARED_TRIAL_COUNT, SEALED_RULE_SHA256
        except ModuleNotFoundError:
            import sys
            sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'tools/strategy_farm'))
            from opt_census import DECLARED_TRIAL_COUNT, SEALED_RULE_SHA256
        require(declaration.get('authority') == 'DL-089'
                and declaration.get('sealed_rule_sha256') == SEALED_RULE_SHA256, 'DL089_SEALED_RULE_REQUIRED')
        declaration_count = declaration.get('declared_trial_count')
        require(declaration_count == DECLARED_TRIAL_COUNT + numeric
                and len(selected) == declaration_count, 'DL089_DECLARED_SELECTION_COUNT_MISMATCH')
    else:
        require(mode == 'RESEARCH_ONLY' and not selected, 'UNCORRECTED_SELECTION_MODE_REQUIRED')
    all_ids = research | selected
    require(context.get('candidate_trial_id') in all_ids, 'CANDIDATE_ABSENT_FROM_SEARCH_HISTORY')
    require(cohort.get('frequency') == 'CALENDAR_DAY'
            and cohort.get('window') == context.get('window'), 'COHORT_WINDOW_OR_FREQUENCY_MISMATCH')
    rows = cohort.get('rows')
    require(isinstance(rows, list), 'COHORT_ROWS_REQUIRED')
    require(_ids([row.get('trial_id') for row in rows]) == all_ids, 'UNCORRECTED_SELECTION_COHORT_HISTORY_COVERAGE_MISMATCH')
    for row in rows:
        require(row.get('n_calendar_days') == len(values) and bool(SHA.fullmatch(str(row.get('series_sha256')))), 'COHORT_SERIES_PROVENANCE_REQUIRED')
    canonical = json.dumps(values, separators=(',', ':'), allow_nan=False).encode()
    winner = next(row for row in rows if row['trial_id'] == context['candidate_trial_id'])
    require(winner['series_sha256'] == hashlib.sha256(canonical).hexdigest(), 'SELECTED_SERIES_CONTEXT_MISMATCH')
    srs = [finite(row['sharpe_daily']) for row in rows]
    require(math.isclose(winner['sharpe_daily'], moments(values)['sharpe_daily'], rel_tol=1e-12, abs_tol=1e-12), 'SELECTED_SHARPE_CONTEXT_MISMATCH')
    sigma = statistics.stdev(srs) if len(srs) > 1 else 0.0
    declared_sigma = finite(context.get('cohort_std_daily'))
    require(math.isclose(sigma, declared_sigma, rel_tol=1e-12, abs_tol=1e-12), 'COHORT_DISPERSION_MISMATCH')
    return context, {'effective_trial_count': len(all_ids), 'research_trial_count': len(research),
                     'selection_trial_count': len(selected), 'overlap_trial_count': len(research & selected),
                     'declared_trial_count': declaration_count, 'selection_mode': mode, 'cohort_std_daily': sigma,
                     'context_sha256': binding['sha256']}


def evaluate(trades, *, binding, ea_id, symbol):
    # Keep the existing p threshold by reference, including strict p < .05.
    from .sub_8_2_dsr_mc_fdr import DSR_P_MIN
    stats = {}
    try:
        context = bound(binding)
        window = context.get('window', {})
        values, active = daily_series(trades, window.get('from'), window.get('to'),
                          timezone=context.get('timezone'), initial_balance=context.get('initial_balance'))
        stats = {**moments(values), 'active_trading_days': active}
        require(stats['n_calendar_days'] >= 60, 'LOW_SAMPLE_CALENDAR_DAYS')
        context, selection = selection_context(binding, ea_id=ea_id, symbol=symbol, values=values)
        result = calculate(stats, selection['effective_trial_count'], selection['cohort_std_daily'])
        result.update(selection)
        result['engine'] = 'QM_DSR_V2'
        return make_result(GATE_NAME, 'PASS' if result['dsr_p'] < DSR_P_MIN else 'FAIL',
                           result['dsr_p'], DSR_P_MIN, 'DSR_V2_COMPUTED', result)
    except (DsrEvidenceError, KeyError, TypeError, AttributeError, ValueError) as exc:
        reason = str(exc)
        low = reason.startswith('LOW_SAMPLE') or reason == 'DEGENERATE_DAILY_VARIANCE'
        return make_result(GATE_NAME, 'INVALID', None, DSR_P_MIN, 'DSR_V2_' + reason,
                           {**stats, 'engine': 'QM_DSR_V2', 'statistical_status': 'low_sample' if low else 'uncorrected_selection',
                            'dsr_probability': None, 'selection_correction_applied': False})
