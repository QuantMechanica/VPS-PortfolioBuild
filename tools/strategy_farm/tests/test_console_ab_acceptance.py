"""Synthetic native-evidence bundles; no terminal, GUI or trading actions."""

import csv
import json
from pathlib import Path
import struct
import zlib

import pytest

from tools.strategy_farm.console_ab_acceptance import (
    CHART_PROPERTIES, PNG_SIGNATURE, UNTOUCHED_PROPERTIES, accept_ab, main, png_dimensions,
)
from tools.strategy_farm.tests.test_console_census import metadata, object_row, panel, receipts, write_csv


def chunk(kind, payload):
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)


def png(width=800, height=600):
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    pixels = (b'\0' + b'\0' * (width * 3)) * height
    return PNG_SIGNATURE + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(pixels, 1)) + chunk(b'IEND', b'')


def read_rows(path):
    with path.open(encoding='utf-8', newline='') as stream:
        return list(csv.DictReader(stream))


def change_meta(path, **values):
    target = path.with_suffix('.meta.csv')
    rows = read_rows(target)
    rows[0].update({key: str(value) for key, value in values.items()})
    write_csv(target, rows)


def change_property(path, name, value):
    target = path.with_suffix('.chart.csv')
    rows = read_rows(target)
    next(row for row in rows if row['property'] == name)['value'] = str(value)
    write_csv(target, rows)


@pytest.fixture
def triplet(tmp_path):
    paths = []
    for serial, design in [(301, 'V2'), (302, 'V1'), (303, 'V2')]:
        path = tmp_path / f'qa_{serial}.csv'
        rows = [panel(), object_row(text='© 0,31 % | "value"\nfixture')]
        if design == 'V2':
            rows.append({**object_row(x=500, y=30, scope='overlay'),
                         'name': 'QM_CHART_V2_QM_QA_identity'})
        for row in rows:
            row['serial'] = str(serial)
        meta = metadata(rows, serial=serial, design=design,
                        expert_name='QM_Console_Visual_QA', qa_trade_allowed=0,
                        terminal_trade_allowed=1, cached_bid='1.17342',
                        screenshot_calibrated=1, screenshot_width=856, screenshot_height=623,
                        quote_observed_at='2026.09.08 01:23:00 BT')
        write_csv(path, rows)
        write_csv(path.with_suffix('.meta.csv'), [meta])
        write_csv(tmp_path / meta['selftest_receipt'], receipts(meta))
        binding = dict(init_run_id=meta['init_run_id'], chart_id=meta['chart_id'])
        write_csv(tmp_path / f'news_selftests_{meta["init_run_id"]}.csv', [
            dict(**binding, suite='news_observation', status='PASS', expected_cases='24', detail='')])
        write_csv(tmp_path / f'chart_selftests_{meta["init_run_id"]}.csv', [
            dict(**binding, suite=suite, status='PASS', detail='')
            for suite in ('chart_geometry', 'chart_property_roundtrip', 'chart_zoom_roundtrip')])
        write_csv(tmp_path / f'compare_selftests_{meta["init_run_id"]}.csv', [
            dict(**binding, suite=suite, status='PASS', detail='')
            for suite in ('compare_start_failure_rollback', 'compare_render_failure_recovery',
                          'initial_start_failure_retry')])
        properties = {key: 0 for key in CHART_PROPERTIES}
        properties.update(CHART_COLOR_BACKGROUND=16777215 if design == 'V2' else 16000000,
                          CHART_SCALE=3, CHART_AUTOSCROLL=1, CHART_SHOW_TRADE_LEVELS=1,
                          CHART_DRAG_TRADE_LEVELS=1, CHART_SHOW_TRADE_HISTORY=0,
                          CHART_SHIFT=1 if design == 'V2' else 0,
                          CHART_SHIFT_SIZE=20.0 if design == 'V2' else 17.5)
        write_csv(path.with_suffix('.chart.csv'), [dict(serial=str(serial), chart_id=meta['chart_id'],
                                                       property=key, value=str(value))
                                                  for key, value in sorted(properties.items())])
        path.with_suffix('.png').write_bytes(png(856, 623))
        paths.append(path)
    return paths


def codes(result):
    return {issue['code'] for issue in result['issues']}


def test_complete_v2_v1_v2_bundle_passes_without_claiming_strategy_certification(triplet):
    before = {path: (path.stat().st_size, path.stat().st_mtime_ns)
              for path in triplet[0].parent.iterdir()}
    result = accept_ab(*triplet)
    assert result['status'] == 'PASS' and result['issues'] == []
    assert [capture['design'] for capture in result['captures']] == ['V2', 'V1', 'V2']
    assert result['trading_strategy_certified'] is False
    assert result['reference_context']['cached_bid'] == '1.17342'
    assert result['compared_chart_properties'] == 26
    assert all(capture['png_dimensions'] == (856, 623) for capture in result['captures'])
    assert all(capture['plot_dimensions'] == (800, 600) for capture in result['captures'])
    assert all(capture['screenshot_calibrated'] for capture in result['captures'])
    assert any('news:24' in capture['native_suites'] for capture in result['captures'])
    assert all('compare_start_failure_rollback:PASS' in capture['native_suites']
               for capture in result['captures'])
    assert all('compare_render_failure_recovery:PASS' in capture['native_suites']
               for capture in result['captures'])
    assert all('initial_start_failure_retry:PASS' in capture['native_suites']
               for capture in result['captures'])
    assert any('not transient capture-failure recovery' in limit for limit in result['limits'])
    assert all('chart_zoom_roundtrip:PASS' in capture['native_suites']
               for capture in result['captures'])
    assert before == {path: (path.stat().st_size, path.stat().st_mtime_ns)
                      for path in triplet[0].parent.iterdir()}


@pytest.mark.parametrize('values', [dict(cached_bid='1.17343'),
                                   dict(quote_observed_at='2026.09.08 01:23:01 BT')])
def test_changed_cached_quote_or_observation_time_fails(triplet, values):
    change_meta(triplet[1], **values)
    assert 'cached_quote_changed' in codes(accept_ab(*triplet))


@pytest.mark.parametrize('values', [dict(scenario=1), dict(scale=125), dict(dpi=120),
                                   dict(mode=1, mode_name='QM_CONSOLE_COMPACT'),
                                   dict(terminal_trade_allowed=0), dict(fixture_bar=123)])
def test_changed_capture_context_or_global_permission_fails(triplet, values):
    change_meta(triplet[1], **values)
    assert 'capture_context_changed' in codes(accept_ab(*triplet))


@pytest.mark.parametrize('values', [dict(expert_name='QM5_11421_real_EA'), dict(qa_trade_allowed=1)])
def test_wrong_expert_or_enabled_qa_trading_fails(triplet, values):
    change_meta(triplet[1], **values)
    assert 'unsafe_qa_binding' in codes(accept_ab(*triplet))


@pytest.mark.parametrize('values', [dict(chart_id='123'), dict(init_run_id='123_456')])
def test_changed_binding_cannot_reuse_old_native_proofs(triplet, values):
    change_meta(triplet[1], **values)
    assert accept_ab(*triplet)['status'] == 'FAIL'


def test_legacy_capture_without_new_metadata_is_not_accepted(triplet):
    target = triplet[0].with_suffix('.meta.csv')
    rows = read_rows(target)
    del rows[0]['expert_name']
    write_csv(target, rows)
    result = accept_ab(*triplet)
    assert 'missing_ab_metadata' in codes(result)
    assert 'New native A/B capture required' in result['issues'][0]['detail']


@pytest.mark.parametrize('prefix', ['news_selftests_', 'chart_selftests_', 'compare_selftests_'])
def test_missing_required_native_suite_proof_fails_with_retry_guidance(triplet, prefix):
    meta = read_rows(triplet[0].with_suffix('.meta.csv'))[0]
    (triplet[0].parent / f'{prefix}{meta["init_run_id"]}.csv').unlink()
    result = accept_ab(*triplet)
    assert 'missing_or_unreadable_proof' in codes(result)
    assert result['issues'][0]['retryable'] is True


@pytest.mark.parametrize('prefix,field,value', [
    ('news_selftests_', 'expected_cases', '23'), ('news_selftests_', 'status', 'FAIL'),
    ('news_selftests_', 'init_run_id', 'wrong'), ('chart_selftests_', 'status', 'FAIL'),
    ('chart_selftests_', 'chart_id', 'wrong'), ('chart_selftests_', 'suite', 'unknown'),
    ('compare_selftests_', 'status', 'FAIL'), ('compare_selftests_', 'chart_id', 'wrong'),
    ('compare_selftests_', 'init_run_id', 'wrong'), ('compare_selftests_', 'suite', 'unknown'),
])
def test_native_receipts_require_exact_suites_count_pass_and_binding(triplet, prefix, field, value):
    meta = read_rows(triplet[0].with_suffix('.meta.csv'))[0]
    path = triplet[0].parent / f'{prefix}{meta["init_run_id"]}.csv'
    rows = read_rows(path)
    rows[0][field] = value
    write_csv(path, rows)
    assert accept_ab(*triplet)['status'] == 'FAIL'


@pytest.mark.parametrize('mutation,code', [
    ('missing', 'invalid_native_receipt'), ('duplicate', 'invalid_native_receipt'),
    ('unknown', 'invalid_native_receipt'), ('FAIL', 'native_selftest_failed'),
    ('NOT_RUN', 'native_selftest_failed'), ('chart_id', 'receipt_binding_mismatch'),
    ('init_run_id', 'receipt_binding_mismatch'),
])
def test_initial_start_retry_receipt_is_mandatory_exact_pass_and_same_initialization(triplet, mutation, code):
    meta = read_rows(triplet[0].with_suffix('.meta.csv'))[0]
    path = triplet[0].parent / f'compare_selftests_{meta["init_run_id"]}.csv'
    rows = read_rows(path)
    row = next(row for row in rows if row['suite'] == 'initial_start_failure_retry')
    if mutation == 'missing':
        rows.remove(row)
    elif mutation == 'duplicate':
        rows.append(dict(row))
    elif mutation == 'unknown':
        row['suite'] = 'initial_start_failure_simulated'
    elif mutation in {'FAIL', 'NOT_RUN'}:
        row['status'] = mutation
    else:
        row[mutation] = 'wrong'
    write_csv(path, rows)
    result = accept_ab(*triplet)
    assert result['status'] == 'FAIL' and code in codes(result)


def test_data_receipt_is_still_enforced_by_census(triplet):
    meta = read_rows(triplet[0].with_suffix('.meta.csv'))[0]
    path = triplet[0].parent / meta['selftest_receipt']
    rows = read_rows(path)
    rows[-1]['passed_cases'] = '10'
    write_csv(path, rows)
    assert 'census_failed' in codes(accept_ab(*triplet))


@pytest.mark.parametrize('property_name', sorted(UNTOUCHED_PROPERTIES))
def test_all_protected_chart_properties_remain_unchanged_in_middle_capture(triplet, property_name):
    change_property(triplet[1], property_name, 99)
    assert 'protected_chart_property_changed' in codes(accept_ab(*triplet))


def test_first_last_chart_theme_mismatch_fails(triplet):
    change_property(triplet[2], 'CHART_COLOR_BACKGROUND', 123)
    assert 'v2_property_roundtrip_mismatch' in codes(accept_ab(*triplet))


@pytest.mark.parametrize('last,passes', [(20.0000005, True), (20.000002, False)])
def test_shift_size_roundtrip_uses_only_one_micro_percent_tolerance(triplet, last, passes):
    change_property(triplet[2], 'CHART_SHIFT_SIZE', last)
    assert (accept_ab(*triplet)['status'] == 'PASS') is passes


@pytest.mark.parametrize('mutation', ['missing', 'duplicate', 'binding', 'nonfinite'])
def test_chart_property_receipt_is_complete_numeric_and_bound(triplet, mutation):
    path = triplet[1].with_suffix('.chart.csv')
    rows = read_rows(path)
    if mutation == 'missing':
        rows.pop()
    elif mutation == 'duplicate':
        rows[-1] = rows[0]
    elif mutation == 'binding':
        rows[0]['serial'] = '999'
    else:
        next(row for row in rows if row['property'] == 'CHART_SHIFT_SIZE')['value'] = 'nan'
    write_csv(path, rows)
    assert accept_ab(*triplet)['status'] == 'FAIL'


def test_unrelated_object_prefix_is_rejected_by_census(triplet):
    rows = read_rows(triplet[0])
    rows[-1]['name'] = 'QM_CHART_V2_QM_SIG_unrelated_identity'
    write_csv(triplet[0], rows)
    assert 'census_failed' in codes(accept_ab(*triplet))


def test_v1_must_have_no_v2_overlay_orphans(triplet):
    rows = read_rows(triplet[1])
    rows.append({**read_rows(triplet[0])[-1], 'serial': '302'})
    write_csv(triplet[1], rows)
    change_meta(triplet[1], object_count=len(rows))
    assert 'v1_overlay_orphans' in codes(accept_ab(*triplet))


@pytest.mark.parametrize('mutation', ['rename', 'retype', 'remove'])
def test_last_v2_object_names_and_types_match_first_without_missing_or_orphan_objects(triplet, mutation):
    rows = read_rows(triplet[2])
    if mutation == 'rename':
        rows[-1]['name'] = 'QM_CHART_V2_QM_QA_orphan'
    elif mutation == 'retype':
        rows[-1]['type_name'] = 'OBJ_BUTTON'
        rows[-1]['type'] = '99'
    else:
        rows.pop()
    write_csv(triplet[2], rows)
    change_meta(triplet[2], object_count=len(rows))
    assert 'v2_object_roundtrip_mismatch' in codes(accept_ab(*triplet))


def test_absent_overlays_cannot_vacuously_prove_lifecycle(triplet):
    for path in (triplet[0], triplet[2]):
        rows = read_rows(path)[:-1]
        write_csv(path, rows)
        change_meta(path, object_count=len(rows))
    assert 'insufficient_overlay_evidence' in codes(accept_ab(*triplet))


def test_wrong_sequence_or_reused_capture_is_rejected(triplet):
    assert 'wrong_design_sequence' in codes(accept_ab(triplet[1], triplet[0], triplet[2]))
    assert 'non_monotonic_captures' in codes(accept_ab(triplet[0], triplet[1], triplet[0]))


@pytest.mark.parametrize('payload', [b'', b'not png', PNG_SIGNATURE, png()[:-12],
                                    png()[:40], png()[:-1] + b'\0'])
def test_malformed_or_incomplete_png_is_clear_retryable_failure(triplet, payload):
    triplet[1].with_suffix('.png').write_bytes(payload)
    result = accept_ab(*triplet)
    assert 'png_incomplete_or_invalid' in codes(result)
    assert result['issues'][0]['retryable'] is True


def test_actual_png_dimensions_must_match_metadata(triplet):
    triplet[1].with_suffix('.png').write_bytes(png(799, 600))
    assert 'png_dimensions_mismatch' in codes(accept_ab(*triplet))


@pytest.mark.parametrize('field', ['screenshot_calibrated', 'screenshot_width', 'screenshot_height'])
def test_missing_calibration_metadata_is_not_full_frame_evidence(triplet, field):
    from tools.strategy_farm.console_census import analyze_census
    path = triplet[0].with_suffix('.meta.csv')
    rows = read_rows(path)
    del rows[0][field]
    write_csv(path, rows)
    assert analyze_census(triplet[0])['status'] == 'PASS'  # Prior geometry remains valid.
    result = accept_ab(*triplet)
    assert 'missing_screenshot_calibration' in codes(result)
    assert 'Recapture with calibration' in result['issues'][0]['detail']


@pytest.mark.parametrize('flag', ['0', '', '2', 'true'])
def test_calibration_flag_must_be_explicit_native_one(triplet, flag):
    change_meta(triplet[0], screenshot_calibrated=flag)
    assert 'uncalibrated_screenshot' in codes(accept_ab(*triplet))


@pytest.mark.parametrize('values', [dict(screenshot_width=0), dict(screenshot_height=-1),
                                   dict(screenshot_width=799), dict(screenshot_height=599),
                                   dict(screenshot_width='NaN'), dict(screenshot_height='623.0'),
                                   dict(screenshot_width=2**31)])
def test_invalid_or_smaller_than_plot_client_dimensions_are_rejected(triplet, values):
    change_meta(triplet[0], **values)
    assert 'invalid_screenshot_calibration' in codes(accept_ab(*triplet))


def test_old_plot_sized_png_fails_even_when_geometry_is_valid(triplet):
    from tools.strategy_farm.console_census import analyze_census
    triplet[0].with_suffix('.png').write_bytes(png(800, 600))
    assert analyze_census(triplet[0])['status'] == 'PASS'
    result = accept_ab(*triplet)
    assert 'png_dimensions_mismatch' in codes(result)
    assert 'calibrated native client is (856, 623)' in result['issues'][0]['detail']


@pytest.mark.parametrize('width,height', [(857, 623), (856, 624)])
def test_calibrated_client_size_must_be_same_across_ab_triplet(triplet, width, height):
    change_meta(triplet[1], screenshot_width=width, screenshot_height=height)
    triplet[1].with_suffix('.png').write_bytes(png(width, height))
    assert 'capture_context_changed' in codes(accept_ab(*triplet))


def test_missing_png_is_not_passed_from_screenshot_flag_alone(triplet):
    triplet[1].with_suffix('.png').unlink()
    result = accept_ab(*triplet)
    assert 'missing_or_unreadable_proof' in codes(result)


def test_png_header_reader_checks_crc_and_end_without_decoding_pixels():
    assert png_dimensions(png(12, 8)) == (12, 8)
    with pytest.raises(ValueError, match='checksum'):
        png_dimensions(png(12, 8)[:29] + b'\0\0\0\0' + png(12, 8)[33:])


def test_file_changed_during_validation_is_retryable_not_pass(triplet, monkeypatch):
    from tools.strategy_farm import console_ab_acceptance as acceptance
    original = acceptance._stamp
    calls = {}

    def changing_stamp(path):
        size, modified = original(path)
        calls[path] = calls.get(path, 0) + 1
        if path == triplet[0].with_suffix('.png') and calls[path] > 1:
            return size + 1, modified
        return size, modified

    monkeypatch.setattr(acceptance, '_stamp', changing_stamp)
    result = accept_ab(*triplet)
    assert 'capture_changed_while_reading' in codes(result)
    assert result['issues'][0]['retryable'] is True


def test_cli_outputs_json_and_exit_status(triplet, capsys):
    assert main([str(path) for path in triplet]) == 0
    assert json.loads(capsys.readouterr().out)['status'] == 'PASS'
    change_meta(triplet[0], qa_trade_allowed=1)
    assert main([str(path) for path in triplet]) == 1
    assert json.loads(capsys.readouterr().out)['trading_strategy_certified'] is False
