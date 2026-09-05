import copy
import datetime as dt
import json
from pathlib import Path

import pytest
import reproduce as m

ROSTER = {114210000: {'ea_id': 11421, 'symbol': 'EURUSD.DWX'}}


def deal(id, entry, magic, net='0', volume='1', position='9'):
    return {'deal_id': str(id), 'position_id': position, 'entry': entry,
            'deal_magic': str(magic), 'logical_magic': '999999999', 'symbol': 'EURUSD',
            'type': 'BUY' if entry == 'IN' else 'SELL', 'volume': volume,
            'profit': net, 'swap': '0', 'commission': '0', 'fee': '0',
            'net_actual': net, 'time_utc': f'2026-07-24T{8+id:02d}:00:00Z'}


def test_zero_closing_magic_and_both_commissions_remain_on_original_ea():
    rows = [deal(1, 'IN', 114210000, '-1.22'), deal(2, 'OUT', 0, '-260.77')]
    positions, cash, zeros = m.attribute(rows, ROSTER)
    assert not cash and positions[0]['closed']
    assert positions[0]['net_actual'] == -261.99
    assert zeros[0]['logical_magic'] == 114210000


def test_all_zero_is_unattributed_not_assigned_by_symbol_or_logical_magic():
    positions, _, _ = m.attribute([deal(1, 'IN', 0), deal(2, 'OUT', 0)], ROSTER)
    assert positions[0]['classification'] == 'UNATTRIBUTED_MAGIC_0_POSITION'
    assert positions[0]['logical_magic'] is None


@pytest.mark.parametrize('rows,classification', [
    ([deal(2, 'OUT', 114210000)], 'UNRESOLVED_VOLUME_LIFECYCLE'),
    ([deal(1, 'IN', 114210000), deal(2, 'OUT', 444)], 'CONFLICTING_IDENTITY'),
    ([deal(1, 'INOUT', 114210000)], 'UNRESOLVED_COMPLEX_LIFECYCLE'),
])
def test_ambiguous_lifecycles_do_not_acquire_ea_attribution(rows, classification):
    positions, _, _ = m.attribute(rows, ROSTER)
    assert positions[0]['classification'] == classification
    assert positions[0]['logical_magic'] is None


def test_partial_closes_and_idempotent_identical_duplicates():
    rows = [deal(1, 'IN', 114210000), deal(2, 'OUT', 0, volume='.25')]
    positions, _, _ = m.attribute(rows + [rows[0]], ROSTER)
    assert not positions[0]['closed'] and positions[0]['deal_count'] == 2
    rows.append(deal(3, 'OUT', 0, volume='.75'))
    assert m.attribute(rows, ROSTER)[0][0]['closed']
    conflict = dict(rows[0], volume='2')
    with pytest.raises(ValueError, match='conflicting_duplicate'):
        m.attribute(rows + [conflict], ROSTER)


def test_bad_cash_arithmetic_refuses_report():
    with pytest.raises(ValueError, match='net_reconciliation'):
        m.attribute([dict(deal(1, 'IN', 114210000), fee='-2')], ROSTER)


def sample(ts, equity):
    return {'source_path': 'fixture', 'source_line': 1,
            'record': {'ts_utc': ts, 'payload': {'equity': equity, 'day_key': 20260717}}}


def test_observed_endpoint_and_min_are_not_median_or_true_eod_and_no_gap_fill():
    rows = [sample('2026-07-24T20:00:00Z', 99), sample('2026-07-24T12:00:00Z', 80),
            sample('2026-07-24T01:00:00Z', 100), sample('2026-07-26T22:00:00Z', 98)]
    result = m.equity_days(rows, m.timestamp('2026-07-24T00:00:00Z'), m.timestamp('2026-07-27T00:00:00Z'))
    assert result[0]['last_observed_equity'] == 99
    assert result[0]['sampled_minimum_equity_upper_bound_on_true_low'] == 80
    assert result[0]['eod_equity'] is None and result[0]['true_intraday_minimum_equity'] is None
    assert result[1]['status'] == 'MISSING'
    assert result[2]['last_observed_equity_change'] == -1
    assert not result[2]['calendar_daily_change_available']
    assert result[0]['maximum_unobserved_gap_seconds'] == 11 * 3600


def test_frozen_capture_known_answer_and_replay_is_pure():
    result = m.build()
    saved = json.loads((m.ROOT / 'result.json').read_text())
    assert result == saved
    assert result['position_count'] == 108 and result['deal_count'] == 225
    assert len(result['magic_zero_deals']) == 18
    assert result['in_window_deal_cash']['ACCOUNT_TOTAL'] == -2967.76
    assert result['closed_position_lifecycle_net']['ROSTER_EA'] == -1436.59
    assert result['reference']['book_fingerprint'] == 'e8bc34e619a0c530bfd5c0156e27aef27abd41cff43f79f633b25c148672a07c'
    assert result['advisory']['verdict'] == 'UNKNOWN' and not result['advisory']['binding']
    assert result['window']['observed_dates'] == 36 and not result['window']['restart']
    p = next(p for p in result['positions'] if p['position_id'] == '3168177717')
    assert p['ea_id'] == 11421 and p['net_actual'] == -262.0
