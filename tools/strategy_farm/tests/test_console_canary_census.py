"""Pure file fixtures for the live-observation consumer; no MT5/UI calls."""
import ast
import csv
import hashlib
import json
from pathlib import Path
import struct
import zlib

import pytest

from tools.strategy_farm import console_canary_census as census


AUDIT_ID = census.CHART + '_123456'


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


def png(width=856, height=623):
    # Complete valid RGB pixels, although the consumer deliberately does not decode them.
    raw = (b'\0' + b'\0' * (3 * width)) * height
    return (census.PNG_SIGNATURE + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 1)) + chunk(b'IEND', b''))


def row(suffix, kind='OBJ_LABEL', x=20, y=150, width=100, height=15, text='Value', **changes):
    value = dict(audit_id=AUDIT_ID, chart_id=census.CHART, name=census.PREFIX + suffix,
                 type=str(census.PIXEL_TYPES.get(kind, 1)), type_name=kind, scope='dashboard', subwindow='0',
                 x=str(x), y=str(y), width=str(width), height=str(height), anchor='0', anchor_name='ANCHOR_LEFT_UPPER',
                 corner='0', corner_name='CORNER_LEFT_UPPER', angle='0', bbox_available='1',
                 bbox_left=str(x), bbox_top=str(y), bbox_right=str(x + width), bbox_bottom=str(y + height),
                 text=text, tooltip=text, read_complete='1')
    value.update({key: str(item) for key, item in changes.items()})
    return value


def metadata(rows, design='02', view='Full'):
    return dict(schema_version='1', artifact_kind='live_canary_observation', audit_id=AUDIT_ID,
                account_login=census.ACCOUNT, server='FTMO-Demo', account_mode='DEMO', chart_id=census.CHART,
                hwnd=census.HWND, symbol='EURUSD', timeframe='D1', expert=census.EXPERT, prefix=census.PREFIX,
                overlay_prefix=census.OVERLAY, design=design, view=view, plot_width='800', plot_height='600', dpi='96',
                object_count=str(len(rows)), objects_complete='1', properties_complete='1', binding_stable='1',
                capture_non_atomic='1', screenshot_calibrated='1', screenshot_ok='1', screenshot_width='856',
                screenshot_height='623', started_utc='2026.09.08 00:00:00 UTC', finished_utc='2026.09.08 00:00:01 UTC',
                observation_complete='1')


def property_rows():
    return [dict(audit_id=AUDIT_ID, chart_id=census.CHART, property=key,
                 value='20.0' if key == 'CHART_SHIFT_SIZE' else '149' if key == 'CHART_WIDTH_IN_BARS' else '1',
                 read_complete='1') for key in sorted(census.CHART_PROPERTIES)]


def dump(path, rows):
    with path.open('w', encoding='utf-8', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(rows)


def bundle(tmp_path, design='02', view='Full'):
    rows = [row('bg', 'OBJ_RECTANGLE_LABEL', 8, 8, 384, 360, ''),
            row('design_version', 'OBJ_BUTTON', 280, 20, 26, 20, design),
            row('view', 'OBJ_BUTTON', 320, 20, 60, 24, view),
            row('state_headline', y=70, text='WAITING FOR SETUP'),
            row('state_reason', y=90, text='Current reason'), row('state_next', y=110, text='Next event'),
            row('footer', y=340, width=150, text='© QuantMechanica  v5.0' if design == '01' else '© QuantMechanica'),
            row('summary', text='USD 1.234,56 | "full"\nTooltip')]
    path = tmp_path / ('canary_' + AUDIT_ID + '.objects.csv')
    meta = metadata(rows, design, view)
    props = property_rows()
    dump(path, rows)
    dump(companion(path, 'meta.csv'), [meta])
    dump(companion(path, 'chart.csv'), props)
    companion(path, 'png').write_bytes(png())
    return path, rows, meta, props


def companion(path, suffix):
    return path.with_name(path.name.removesuffix('objects.csv') + suffix)


def codes(result):
    return {issue['code'] for issue in result['issues']}


@pytest.mark.parametrize('design', ['01', '02'])
@pytest.mark.parametrize('view', ['Full', 'Compact', 'Minimal'])
def test_valid_live_schema_retains_identity_and_never_claims_qa_or_trading_approval(tmp_path, design, view):
    path, _, meta, _ = bundle(tmp_path, design, view)
    result = census.analyze_canary(path)
    assert result['status'] == 'PASS' and result['metadata'] == meta
    assert result['capture_non_atomic'] is True
    assert not result['native_selftests_verified'] and not result['strategy_certified'] and not result['trading_authorized']
    assert len(result['chart_properties']) == 28
    assert result['screenshot_dimensions'] == [856, 623]
    assert set(result['files']) == {'objects', 'metadata', 'chart', 'png'}


@pytest.mark.parametrize('field,value', [
    ('schema_version', '2'), ('artifact_kind', 'synthetic_qa'), ('audit_id', 'other'),
    ('account_login', '1'), ('server', 'other'), ('account_mode', 'REAL'), ('chart_id', '1'), ('hwnd', '2'),
    ('symbol', 'GBPUSD'), ('timeframe', 'M1'), ('expert', 'QM_Console_Visual_QA'), ('prefix', 'QM_QA_'),
    ('overlay_prefix', 'QM_CHART_V2_QM_QA_'), ('objects_complete', '0'), ('properties_complete', '0'),
    ('binding_stable', '0'), ('capture_non_atomic', '0'), ('screenshot_calibrated', '0'), ('screenshot_ok', '0'),
    ('observation_complete', '0'), ('object_count', '999'), ('design', 'UNOBSERVED'), ('view', 'Unknown'),
    ('plot_width', '0'), ('dpi', '0'), ('screenshot_width', '2000'), ('screenshot_height', '599'),
    ('finished_utc', '2026.09.07 00:00:00 UTC'),
])
def test_wrong_or_incomplete_metadata_cannot_be_promoted_to_valid_observation(tmp_path, field, value):
    path, _, meta, _ = bundle(tmp_path)
    meta[field] = value
    dump(companion(path, 'meta.csv'), [meta])
    assert census.analyze_canary(path)['status'] == 'FAIL'


@pytest.mark.parametrize('field,value', [
    ('audit_id', 'other'), ('chart_id', '1'), ('read_complete', '0'), ('scope', 'overlay'),
    ('type', '23'), ('type_name', 'OBJ_UNKNOWN'), ('width', '0'), ('x', 'nan'), ('angle', '15'),
    ('anchor', '6'), ('corner_name', 'CORNER_RIGHT_UPPER'), ('bbox_available', '0'),
    ('bbox_left', '99'), ('subwindow', '1'),
])
def test_invalid_rows_and_unmeasured_or_inconsistent_geometry_fail(tmp_path, field, value):
    path, rows, _, _ = bundle(tmp_path)
    rows[-1][field] = value
    dump(path, rows)
    assert 'invalid_object' in codes(census.analyze_canary(path))


@pytest.mark.parametrize('name', ['QM_QA_fake', census.PREFIX + 'bg', 'X' * 64])
def test_duplicate_foreign_and_overlong_names_fail(tmp_path, name):
    path, rows, _, _ = bundle(tmp_path)
    rows[-1]['name'] = name
    dump(path, rows)
    assert 'object_identity' in codes(census.analyze_canary(path))


def test_missing_tooltip_column_is_not_a_complete_native_observation(tmp_path):
    path, rows, _, _ = bundle(tmp_path)
    for item in rows:
        del item['tooltip']
    dump(path, rows)
    assert 'invalid_object' in codes(census.analyze_canary(path))


@pytest.mark.parametrize('x,expected', [(500, 'outside_panel'), (790, 'outside_chart')])
def test_chart_and_panel_bounds_are_independently_checked(tmp_path, x, expected):
    path, rows, _, _ = bundle(tmp_path)
    rows[-1] = row('summary', x=x)
    dump(path, rows)
    assert expected in codes(census.analyze_canary(path))


@pytest.mark.parametrize('overlap,expected', [(1, 'PASS'), (2, 'FAIL')])
def test_label_overlap_has_exact_one_pixel_tolerance(tmp_path, overlap, expected):
    path, rows, _, _ = bundle(tmp_path)
    rows[-1] = row('summary', y=110 + 15 - overlap)
    dump(path, rows)
    assert census.analyze_canary(path)['status'] == expected


@pytest.mark.parametrize('suffix,value', [('footer', '(c) QuantMechanica'), ('footer', 'QuantMechanica'),
                                         ('design_version', '01'), ('view', 'Minimal'), ('state_reason', '')])
def test_real_copyright_state_and_native_button_values_are_required(tmp_path, suffix, value):
    path, rows, _, _ = bundle(tmp_path)
    next(item for item in rows if item['name'] == census.PREFIX + suffix)['text'] = value
    dump(path, rows)
    assert 'missing_or_wrong_control' in codes(census.analyze_canary(path))


@pytest.mark.parametrize('design,text', [
    ('01', '© QuantMechanica'), ('01', '© QuantMechanica v5.0'),
    ('01', '© QuantMechanica  v5.1'), ('01', '(c) QuantMechanica  v5.0'),
    ('01', '© QuantMechanica  v5.0 extra'), ('01', 'prefix © QuantMechanica  v5.0'),
    ('02', '© QuantMechanica  v5.0'), ('02', '© QuantMechanica extra'),
])
def test_footer_is_exact_for_pinned_design_and_version_not_a_substring(tmp_path, design, text):
    path, rows, _, _ = bundle(tmp_path, design=design)
    next(item for item in rows if item['name'] == census.PREFIX + 'footer')['text'] = text
    dump(path, rows)
    assert 'missing_or_wrong_control' in codes(census.analyze_canary(path))


def test_pinned_footer_contract_matches_current_ea_version_and_renderer_sources():
    repo = Path(__file__).resolve().parents[3]
    ea = (repo / 'framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/'
          'QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5').read_text(encoding='utf-8')
    v1 = (repo / 'framework/include/QM/QM_StrategyConsole.mqh').read_text(encoding='utf-8')
    v2 = (repo / 'framework/include/QM/QM_StrategyConsoleV2.mqh').read_text(encoding='utf-8')
    assert 'snapshot.version="5.0";' in ea
    assert '"© QuantMechanica  v"+snapshot.version' in v1
    assert 'ShortToString(0x00A9)+" QuantMechanica"' in v2
    assert census.FOOTERS == {'01': '© QuantMechanica  v5.0', '02': '© QuantMechanica'}


def test_unexpected_recovery_control_and_mixed_design_objects_cannot_pass(tmp_path):
    path, rows, _, _ = bundle(tmp_path)
    rows[-1] = row('retry', name=census.RETRY, scope='recovery')
    dump(path, rows)
    assert 'unexpected_recovery' in codes(census.analyze_canary(path))
    rows[-1] = row('trade_fake', x=440)
    dump(path, rows)
    assert 'mixed_design_objects' in codes(census.analyze_canary(path))


def test_time_price_overlays_remain_explicitly_unchecked_without_fake_pixel_box(tmp_path):
    path, rows, _, _ = bundle(tmp_path)
    overlay = row('bid_line', 'OBJ_HLINE', name=census.OVERLAY + 'bid_line', scope='overlay', bbox_available='0')
    for key in ('x', 'y', 'width', 'height', 'anchor', 'corner', 'angle', *census.BBOX_FIELDS):
        overlay[key] = ''
    overlay['anchor_name'] = overlay['corner_name'] = 'N/A'
    rows[-1] = overlay
    dump(path, rows)
    result = census.analyze_canary(path)
    assert result['status'] == 'PASS'
    assert result['time_price_overlays'] == [{'name': overlay['name'], 'type_name': 'OBJ_HLINE', 'geometry_checked': False}]
    overlay['bbox_left'] = '0'
    dump(path, rows)
    assert 'invalid_object' in codes(census.analyze_canary(path))


@pytest.mark.parametrize('fault', ['missing', 'duplicate', 'audit', 'chart', 'read', 'numeric', 'boolean', 'color'])
def test_chart_properties_require_exact_28_rows_binding_and_valid_native_values(tmp_path, fault):
    path, _, _, props = bundle(tmp_path)
    if fault == 'missing':
        props.pop()
    elif fault == 'duplicate':
        props[-1] = props[0].copy()
    elif fault in {'audit', 'chart', 'read'}:
        props[0][{'audit': 'audit_id', 'chart': 'chart_id', 'read': 'read_complete'}[fault]] = '0'
    elif fault == 'numeric':
        next(item for item in props if item['property'] == 'CHART_SHIFT_SIZE')['value'] = 'nan'
    elif fault == 'boolean':
        next(item for item in props if item['property'] == 'CHART_AUTOSCROLL')['value'] = '2'
    else:
        next(item for item in props if item['property'] == 'CHART_COLOR_BACKGROUND')['value'] = '-1'
    dump(companion(path, 'chart.csv'), props)
    assert census.analyze_canary(path)['status'] == 'FAIL'


@pytest.mark.parametrize('fault', ['signature', 'crc', 'truncated', 'trailing', 'dimensions', 'ihdr'])
def test_png_requires_valid_full_frame_crc_and_ihdr(tmp_path, fault):
    path, _, _, _ = bundle(tmp_path)
    content = png()
    if fault == 'signature':
        content = b'bad' + content[3:]
    elif fault == 'crc':
        content = content[:29] + bytes([content[29] ^ 1]) + content[30:]
    elif fault == 'truncated':
        content = content[:-5]
    elif fault == 'trailing':
        content += b'extra'
    elif fault == 'dimensions':
        content = png(800, 600)
    else:
        content = census.PNG_SIGNATURE + chunk(b'IHDR', struct.pack('>IIBBBBB', 856, 623, 3, 2, 0, 0, 0)) + content[33:]
    companion(path, 'png').write_bytes(content)
    assert codes(census.analyze_canary(path)) & {'png_invalid', 'png_dimensions'}


def test_mid_read_changes_fail_closed(tmp_path, monkeypatch):
    path, _, _, _ = bundle(tmp_path)
    original = census._read_csv

    def changing(file):
        parsed = original(file)
        if file == path:
            file.write_bytes(file.read_bytes() + b'\r\n')
        return parsed

    monkeypatch.setattr(census, '_read_csv', changing)
    result = census.analyze_canary(path)
    assert 'files_changed' in codes(result)
    assert result['issues'][0]['retryable']


def test_bundle_change_after_parsing_is_also_rejected(tmp_path, monkeypatch):
    path, _, _, _ = bundle(tmp_path)
    original = census._geometry

    def changing(rows, meta, result):
        original(rows, meta, result)
        file = companion(path, 'meta.csv')
        file.write_bytes(file.read_bytes() + b'\r\n')

    monkeypatch.setattr(census, '_geometry', changing)
    assert 'files_changed' in codes(census.analyze_canary(path))


def test_cli_and_consumer_do_not_mutate_evidence_or_import_synthetic_qa_analyzer(tmp_path, capsys):
    path, _, _, _ = bundle(tmp_path)
    before = {file.name: hashlib.sha256(file.read_bytes()).hexdigest() for file in tmp_path.iterdir()}
    assert census.main([str(path)]) == 0
    assert json.loads(capsys.readouterr().out)['status'] == 'PASS'
    assert before == {file.name: hashlib.sha256(file.read_bytes()).hexdigest() for file in tmp_path.iterdir()}
    source = Path(census.__file__).read_text(encoding='utf-8')
    tree = ast.parse(source)
    helpers = next(node for node in ast.walk(tree) if isinstance(node, ast.ImportFrom) and node.module == 'tools.strategy_farm.console_census')
    assert {item.name for item in helpers.names} == {'Box', 'bounding_box', '_read_csv'}
    assert 'analyze_census' not in source and 'verify_selftests(' not in source
    assert not any(token in source for token in ('write_text(', 'write_bytes(', 'subprocess', 'pywinauto', 'MetaTrader5', 'win32'))
