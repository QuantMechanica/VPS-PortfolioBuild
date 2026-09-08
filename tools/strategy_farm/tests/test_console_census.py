"""Pure geometry and read-only CSV-bundle tests; never connects to MT5."""

import csv
from pathlib import Path

import pytest

from tools.strategy_farm.console_census import (
    ANCHORS, CORNERS, Box, analyze_census, analyze_rows, bounding_box, main, verify_selftests,
)


def object_row(name='label', **changes):
    row = dict(name='QM_QA_' + name, type='23', x='20', y='20', width='60', height='16',
               anchor='0', text='Label', tooltip='Value', type_name='OBJ_LABEL',
               anchor_name='ANCHOR_LEFT_UPPER', corner='0', corner_name='CORNER_LEFT_UPPER',
               angle='0', scope='panel', serial='12', subwindow='0')
    row.update({key: str(value) for key, value in changes.items()})
    return row


def panel():
    return object_row('bg', type_name='OBJ_RECTANGLE_LABEL', x=8, y=8, width=300, height=200, text='')


def metadata(rows, **changes):
    values = dict(schema_version='2', serial='12', chart_id='41774365623703', chart_width='800',
                  chart_height='600', dpi='96', scenario='0', mode='0', mode_name='QM_CONSOLE_FULL',
                  requested_mode='0', scale='100', prefix='QM_QA_', panel_name='QM_QA_bg',
                  object_count=str(len(rows)), capture_complete='1', screenshot_ok='1',
                  init_run_id='41774365623703_10000', selftest_receipt='selftests_41774365623703_10000.csv',
                  design='V1', fixture_bar='0')
    values.update({key: str(value) for key, value in changes.items()})
    return values


def receipts(meta):
    return [dict(init_run_id=meta['init_run_id'], chart_id=meta['chart_id'], suite=suite,
                 status='PASS', expected_cases=str(count), passed_cases=str(count), detail='')
            for suite, count in [('formatter', 1), ('model', 1), ('data', 11)]]


def write_csv(path: Path, rows):
    with path.open('w', encoding='utf-8', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(rows)


def bundle(tmp_path, rows=None):
    rows = rows if rows is not None else [panel(), object_row(text='© 0,31 % | "quoted"\nsecond line')]
    meta = metadata(rows)
    write_csv(tmp_path / 'qa_12.csv', rows)
    write_csv(tmp_path / 'qa_12.meta.csv', [meta])
    write_csv(tmp_path / meta['selftest_receipt'], receipts(meta))
    return tmp_path / 'qa_12.csv'


def codes(result):
    return {item['code'] for item in result['issues']}


@pytest.mark.parametrize('anchor,fractions', ANCHORS.items())
@pytest.mark.parametrize('corner,directions', CORNERS.items())
def test_all_symbolic_anchors_and_chart_corners(anchor, fractions, corner, directions):
    row = object_row(x=100, y=90, width=40, height=20, anchor_name=anchor, corner_name=corner)
    box = bounding_box(row, 800, 600)
    ax, ay = (700 if directions[0] else 100), (510 if directions[1] else 90)
    left, top = ax - fractions[0] * 40, ay - fractions[1] * 20
    assert box == Box(left, top, left + 40, top + 20)


@pytest.mark.parametrize('kind', ['OBJ_RECTANGLE_LABEL', 'OBJ_BUTTON', 'OBJ_EDIT', 'OBJ_CHART'])
def test_fixed_anchor_types_do_not_use_label_anchor(kind):
    assert bounding_box(object_row(type_name=kind, anchor_name='ANCHOR_RIGHT_LOWER'), 800, 600) == Box(20, 20, 80, 36)


def test_intentional_rectangle_containers_are_not_text_overlap():
    rows = [panel(), object_row('card', type_name='OBJ_RECTANGLE_LABEL', x=15, y=15, width=100, height=80),
            object_row('a'), object_row('b', x=200, anchor_name='ANCHOR_RIGHT_UPPER')]
    result = analyze_rows(rows, metadata(rows))
    assert result['status'] == 'PASS'
    assert result['counts']['measured_text_labels'] == 2
    assert result['selftests_verified'] is False  # Pure geometry is not native-suite proof.


def test_right_anchored_text_overlap_is_detected():
    rows = [panel(), object_row('key'), object_row('value', x=130, anchor_name='ANCHOR_RIGHT_UPPER')]
    result = analyze_rows(rows, metadata(rows))
    assert result['status'] == 'FAIL'
    assert 'text_overlap' in codes(result)


def test_one_pixel_touching_tolerance_is_explicit_and_bounded():
    rows = [panel(), object_row('a'), object_row('b', x=79)]
    assert analyze_rows(rows, metadata(rows), tolerance=1)['status'] == 'PASS'
    assert 'text_overlap' in codes(analyze_rows(rows, metadata(rows), tolerance=0))
    assert 'invalid_metadata' in codes(analyze_rows(rows, metadata(rows), tolerance=100))


@pytest.mark.parametrize('dimensions', [{'width': 0}, {'height': 0}, {'width': -1}])
def test_unmeasured_labels_fail_instead_of_passing_as_empty_boxes(dimensions):
    rows = [panel(), object_row(**dimensions)]
    assert 'label_not_measured' in codes(analyze_rows(rows, metadata(rows)))


@pytest.mark.parametrize('changes', [{'angle': 15}, {'x': 'NaN'}, {'height': 'inf'},
                                    {'anchor_name': '6'}, {'corner_name': '3'}, {'subwindow': 1}])
def test_unsupported_or_invalid_native_geometry_fails(changes):
    rows = [panel(), object_row(**changes)]
    assert 'invalid_geometry' in codes(analyze_rows(rows, metadata(rows)))


def test_chart_and_panel_bounds_are_checked_separately():
    rows = [panel(), object_row('outside_panel', x=400), object_row('outside_chart', x=790)]
    result = analyze_rows(rows, metadata(rows))
    assert {'outside_panel', 'outside_chart'} <= codes(result)


def test_time_price_overlays_are_separate_even_with_missing_pixel_coordinates():
    rows = [panel(), object_row(), object_row('trade_123_entry_line', type_name='OBJ_TREND',
                                            scope='time_price', x='', y='', width='', height='',
                                            anchor_name='N/A', corner_name='N/A')]
    result = analyze_rows(rows, metadata(rows))
    assert result['status'] == 'PASS'
    assert result['time_price_overlays'] == [dict(name='QM_QA_trade_123_entry_line', type_name='OBJ_TREND',
                                                 geometry_checked=False)]
    assert result['counts']['measured_pixel_objects'] == 2


def test_price_labels_use_chart_not_dashboard_bounds():
    rows = [panel(), object_row(), object_row('trade_123_entry_label', x=700, scope='overlay')]
    assert analyze_rows(rows, metadata(rows))['status'] == 'PASS'
    rows[-1]['x'] = '790'
    assert 'outside_chart' in codes(analyze_rows(rows, metadata(rows)))


def test_disjoint_compare_prefix_is_measured_as_overlay_not_panel_or_foreign():
    overlay = {**object_row('entry_label', x=700, scope='overlay'),
               'name': 'QM_CHART_V2_QM_QA_trade_123_entry_label'}
    rows = [panel(), object_row(), overlay]
    result = analyze_rows(rows, metadata(rows, design='V2'))
    assert result['status'] == 'PASS'
    found = next(box for box in result['boxes'] if box['name'] == overlay['name'])
    assert found['scope'] == 'overlay' and found['left'] == 700
    assert not {'invalid_object_identity', 'outside_panel'} & codes(result)


def test_disjoint_compare_time_price_overlay_is_not_assigned_fake_pixel_box():
    overlay = {**object_row(type_name='OBJ_TREND', scope='time_price', x='', y='', width='', height=''),
               'name': 'QM_CHART_V2_QM_QA_trade_123_entry_line'}
    rows = [panel(), object_row(), overlay]
    result = analyze_rows(rows, metadata(rows, design='V2'))
    assert result['status'] == 'PASS'
    assert result['time_price_overlays'][0]['name'] == overlay['name']
    assert result['counts']['measured_pixel_objects'] == 2


@pytest.mark.parametrize('name', ['QM_CHART_V2_QM_SIG_11421_114210000_entry_label',
                                 'QM_CHART_V2_QM_QA2_entry_label', 'QM_CHART_V3_QM_QA_entry_label',
                                 'QM_CHART_V2_QM_QAentry_label', 'QM_QAX_entry_label'])
def test_similar_but_unrelated_chart_prefixes_remain_rejected(name):
    rows = [panel(), object_row(), {**object_row(x=700, scope='overlay'), 'name': name}]
    result = analyze_rows(rows, metadata(rows, design='V2'))
    assert result['status'] == 'FAIL'
    assert 'invalid_object_identity' in codes(result)


@pytest.mark.parametrize('changes,expected', [({'scope': 'panel'}, 'invalid_object_scope'),
                                             ({'x': '790'}, 'outside_chart'),
                                             ({'width': '0'}, 'label_not_measured'),
                                             ({'x': '20'}, 'text_overlap')])
def test_allowlisted_compare_overlay_cannot_bypass_scope_geometry_or_collision_checks(changes, expected):
    overlay = {**object_row(x=700, scope='overlay'), 'name': 'QM_CHART_V2_QM_QA_entry_label', **changes}
    rows = [panel(), object_row(), overlay]
    result = analyze_rows(rows, metadata(rows, design='V2'))
    assert result['status'] == 'FAIL'
    assert expected in codes(result)


def test_effective_mode_may_differ_from_last_command_after_view_click():
    rows = [panel(), object_row()]
    result = analyze_rows(rows, metadata(rows, mode=1, mode_name='QM_CONSOLE_COMPACT', requested_mode=0, design='V2'))
    assert result['status'] == 'PASS'
    assert result['metadata']['mode'] == '1' and result['metadata']['requested_mode'] == '0'


def test_pixel_object_cannot_hide_in_time_price_scope():
    rows = [panel(), object_row(scope='time_price')]
    assert 'invalid_object_scope' in codes(analyze_rows(rows, metadata(rows)))


@pytest.mark.parametrize('changes', [{'serial': 11}, {'schema_version': 1}, {'object_count': 999},
                                    {'capture_complete': 0}, {'screenshot_ok': 0}, {'chart_width': 0},
                                    {'dpi': 0}, {'scale': 151}, {'scenario': 8}, {'mode_name': 'Full'},
                                    {'prefix': 'QM_SIG_'}, {'panel_name': 'wrong'}, {'design': 'unknown'}])
def test_metadata_or_capture_mismatch_is_not_a_pass(changes):
    rows = [panel(), object_row()]
    assert analyze_rows(rows, metadata(rows, **changes))['status'] == 'FAIL'


def test_missing_panel_duplicate_names_and_foreign_names_fail():
    rows = [object_row(), object_row(), {**object_row('foreign'), 'name': 'QM_SIG_live'}]
    assert {'panel_not_measured', 'invalid_object_identity'} <= codes(analyze_rows(rows, metadata(rows)))


def test_panel_without_text_is_not_visual_evidence():
    rows = [panel()]
    assert 'no_measured_text' in codes(analyze_rows(rows, metadata(rows)))


def test_utf8_commas_quotes_and_multiline_csv_bundle_with_native_receipts(tmp_path):
    path = bundle(tmp_path)
    result = analyze_census(path)
    assert result['status'] == 'PASS'
    assert result['selftests_verified'] is True


def test_stale_native_receipt_is_rejected(tmp_path):
    path = bundle(tmp_path)
    meta = metadata([panel(), object_row()])
    rows = receipts(meta)
    rows[-1]['init_run_id'] = 'another_run'
    write_csv(tmp_path / meta['selftest_receipt'], rows)
    assert analyze_census(path)['status'] == 'FAIL'
    assert analyze_census(path, verify_receipts=False)['selftests_verified'] is False


@pytest.mark.parametrize('changes', [{'status': 'FAIL'}, {'passed_cases': '10'},
                                    {'expected_cases': '12'}, {'chart_id': '123'}])
def test_native_data_receipt_must_prove_exactly_eleven_cases(changes):
    meta = metadata([])
    rows = receipts(meta)
    rows[-1].update(changes)
    with pytest.raises(ValueError):
        verify_selftests(meta, rows)


def test_duplicate_native_suites_are_not_accepted():
    meta = metadata([])
    rows = receipts(meta)
    rows[-1] = rows[0]
    with pytest.raises(ValueError):
        verify_selftests(meta, rows)


def test_bad_csv_escaping_and_missing_metadata_fail_closed(tmp_path):
    path = bundle(tmp_path)
    with path.open('a', encoding='utf-8') as stream:
        stream.write('unquoted,extra,comma\n')
    assert 'invalid_bundle' in codes(analyze_census(path))
    assert 'invalid_bundle' in codes(analyze_census(tmp_path / 'missing.csv'))


def test_receipt_path_cannot_escape_capture_directory(tmp_path):
    path = bundle(tmp_path)
    meta = metadata([panel(), object_row()], selftest_receipt='../outside.csv')
    write_csv(tmp_path / 'qa_12.meta.csv', [meta])
    assert analyze_census(path)['status'] == 'FAIL'


def test_cli_reports_json_and_exit_status_without_gui(tmp_path, capsys):
    path = bundle(tmp_path)
    assert main([str(path)]) == 0
    assert '"selftests_verified": true' in capsys.readouterr().out
    assert main([str(tmp_path / 'missing.csv')]) == 1
    assert '"status": "FAIL"' in capsys.readouterr().out
