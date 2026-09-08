"""Read-only canary observer contracts; no compiler, MT5 or UI is executed."""

import csv
import io
from pathlib import Path
import re

import pytest


SOURCE = Path(__file__).resolve().parents[3] / 'framework/tests/mql5/QM_Console_CanaryAudit.mq5'
TOKENS = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*.*?\*/', re.S)


def source():
    return SOURCE.read_text(encoding='utf-8')


def code(text, strings=False):
    return TOKENS.sub(lambda m: ' ' * len(m.group()) if strings or m.group().startswith(('//', '/*')) else m.group(), text)


def body(name):
    text = code(source())
    masked = code(text, strings=True)
    match = re.search(r'\b' + name + r'\s*\([^;{}]*\)\s*\{', masked)
    assert match, name
    depth = 1
    for index in range(match.end(), len(masked)):
        depth += (masked[index] == '{') - (masked[index] == '}')
        if depth == 0:
            return text[match.end():index]
    raise AssertionError('Unbalanced ' + name)


def compact(text):
    return re.sub(r'\s+', '', text)


def test_script_is_standalone_and_has_no_chart_object_trade_or_terminal_mutators():
    text = code(source(), strings=True)
    assert not re.search(r'^\s*#\s*(?:include|import|define)\b', text, re.M)
    assert not re.search(r'\b(?:OnInit|OnTick|OnTimer|OnTrade|OnChartEvent)\s*\(', text)
    forbidden = (r'\b(?:ChartSet\w*|ChartOpen|ChartClose|ChartApplyTemplate|ChartSaveTemplate|ChartRedraw|'
                 r'ObjectCreate|ObjectDelete|ObjectsDeleteAll|ObjectSet\w*|ObjectMove|'
                 r'Order\w*|Position\w*|Buy\w*|Sell\w*|TerminalClose|ExpertRemove|'
                 r'EventSetTimer|EventChartCustom|GlobalVariableSet\w*|GlobalVariableDel|'
                 r'FileDelete|FileMove|FileCopy|FolderDelete|ShellExecute\w*|WebRequest|Socket\w*)\s*\(')
    assert not re.search(forbidden, text)
    assert 'CTrade' not in text and 'MqlTradeRequest' not in text and 'FILE_COMMON' not in text


def test_exact_account_chart_hwnd_expert_guard_precedes_every_output():
    text = source()
    for constant in ('AUDIT_ACCOUNT=1514536732', 'AUDIT_CHART=40880270757609', 'AUDIT_HWND=182059870',
                     'AUDIT_EXPERT="QM5_11421_ohlc-daily-squeeze-reversal-d1"'):
        assert constant in text
    guard = compact(body('AuditTarget'))
    for condition in ('AccountInfoInteger(ACCOUNT_LOGIN)==AUDIT_ACCOUNT',
                      'AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO',
                      'AccountInfoString(ACCOUNT_SERVER)=="FTMO-Demo"', 'ChartID()==AUDIT_CHART',
                      'ChartGetInteger(AUDIT_CHART,CHART_WINDOW_HANDLE)==AUDIT_HWND',
                      'ChartSymbol(AUDIT_CHART)=="EURUSD"', 'ChartPeriod(AUDIT_CHART)==PERIOD_D1',
                      'ChartGetString(AUDIT_CHART,CHART_EXPERT_NAME)==AUDIT_EXPERT'):
        assert condition in guard
    start = compact(body('OnStart'))
    assert start.startswith('if(!AuditTarget())')
    for operation in ('FileIsExist(', 'AuditCalibration(', 'AuditObjects(', 'AuditProperties(', 'ChartScreenShot('):
        assert start.index('return;') < start.index(operation)
    assert start.index('outputidalreadyexists') < start.index('AuditObjects(')


def test_observation_namespace_is_exact_and_never_claims_synthetic_qa_or_selftests():
    text = source()
    assert 'AUDIT_PREFIX="QM_SIG_11421_114210000_"' in text
    assert 'AUDIT_OVERLAY="QM_CHART_V2_QM_SIG_11421_114210000_"' in text
    assert 'AUDIT_RETRY="QM_RETRY_QM_SIG_11421_114210000_"' in text
    owned = compact(body('AuditOwned'))
    assert owned == ('returnStringFind(name,AUDIT_PREFIX)==0||StringFind(name,AUDIT_OVERLAY)==0||'
                     'StringFind(name,AUDIT_RETRY)==0;')
    assert 'live_canary_observation' in text
    assert 'QM_Console_QA' not in text and 'selftest' not in text.lower() and 'synthetic' not in text.lower()
    assert '"PASS"' not in text and 'capture_non_atomic' in text


def test_screenshot_requires_bound_full_client_calibration_without_fallback_or_resize():
    calibration = compact(body('AuditCalibration'))
    for check in ('chart!=AUDIT_CHART', 'window!=AUDIT_HWND', 'plot_width!=width', 'plot_height!=height',
                  'captured_dpi!=dpi', 'captured_width<width', 'captured_width>width+512',
                  'captured_height<height', 'captured_height>height+512'):
        assert check in calibration
    start = compact(body('OnStart'))
    assert start.count('ChartScreenShot(') == 1
    assert 'if(calibrated&&binding_stable)screenshot_ok=ChartScreenShot(AUDIT_CHART,root+".png",client_width,client_height,ALIGN_LEFT);' in start
    assert 'binding_stable=AuditTarget()&&width==ChartGetInteger' in start
    assert 'height==ChartGetInteger(AUDIT_CHART,CHART_HEIGHT_IN_PIXELS)' in start
    assert 'dpi==TerminalInfoInteger(TERMINAL_SCREEN_DPI)' in start
    assert 'client_width=0,client_height=0' in start


@pytest.mark.parametrize('record,expected', [
    ((40880270757609, 182059870, 1187, 380, 1243, 403, 96), True),
    ((41774365623703, 182059870, 1187, 380, 1243, 403, 96), False),
    ((40880270757609, 1, 1187, 380, 1243, 403, 96), False),
    ((40880270757609, 182059870, 1186, 380, 1243, 403, 96), False),
    ((40880270757609, 182059870, 1187, 379, 1243, 403, 96), False),
    ((40880270757609, 182059870, 1187, 380, 1186, 403, 96), False),
    ((40880270757609, 182059870, 1187, 380, 1243, 379, 96), False),
    ((40880270757609, 182059870, 1187, 380, 1700, 403, 96), False),
    ((40880270757609, 182059870, 1187, 380, 1243, 893, 96), False),
    ((40880270757609, 182059870, 1187, 380, 1243, 403, 120), False),
])
def test_calibration_binding_arithmetic(record, expected):
    chart, hwnd, pw, ph, cw, ch, dpi = record
    assert ((chart == 40880270757609 and hwnd == 182059870 and pw == 1187 and ph == 380 and dpi == 96
             and pw <= cw <= pw + 512 and ph <= ch <= ph + 512) is expected)


def test_csv_is_utf8_and_preserves_full_unicode_quoted_multiline_values():
    text = source()
    assert 'StringReplace(value,"\\\"","\\\"\\\"")' in body('AuditCsv')
    assert 'line+="\\\""+value+"\\\"";' in body('AuditCsv')
    assert 'FileWriteString(file,line+"\\r\\n")>0' in body('AuditCsv')
    file_calls = re.findall(r'\bFileOpen\(([^;]+)\);', code(text))
    assert len(file_calls) == 4 and all('CP_UTF8' in call for call in file_calls)
    values = ['© QuantMechanica', 'USD 1.234,56', '"actual"\nfull tooltip', '']
    row = ','.join('"' + value.replace('"', '""') + '"' for value in values) + '\r\n'
    assert next(csv.reader(io.StringIO(row.encode('utf-8').decode('utf-8')))) == values
    assert 'FILE_WRITE|FILE_TXT|FILE_ANSI' in text


def test_inventory_exports_raw_geometry_and_honest_unavailable_bbox_with_read_status():
    inventory = body('AuditObjects')
    for field in ('name', 'type', 'type_name', 'subwindow', 'anchor', 'corner', 'angle', 'text', 'tooltip',
                  'bbox_available', 'bbox_left', 'bbox_top', 'bbox_right', 'bbox_bottom', 'read_complete'):
        assert '"' + field + '"' in inventory
    assert 'ok && pixel && window==0 && AuditBox(' in inventory
    assert 'width<=0 || height<=0 || angle!=0.0' in body('AuditBox')
    assert 'ObjectGetString(AUDIT_CHART,name,OBJPROP_TEXT,0,text)' in inventory
    assert 'ObjectGetString(AUDIT_CHART,name,OBJPROP_TOOLTIP,0,tooltip)' in inventory
    assert 'return complete && after==ArraySize(names);' in inventory
    assert 'if(!seen) complete=false;' in inventory
    assert 'ObjectName(AUDIT_CHART,i)' in inventory and 'if(!AuditOwned(name)) continue;' in inventory


@pytest.mark.parametrize('anchor,ax,ay', [
    ('LEFT_UPPER', 0, 0), ('LEFT', 0, .5), ('LEFT_LOWER', 0, 1), ('LOWER', .5, 1),
    ('RIGHT_LOWER', 1, 1), ('RIGHT', 1, .5), ('RIGHT_UPPER', 1, 0), ('UPPER', .5, 0), ('CENTER', .5, .5),
])
@pytest.mark.parametrize('right,bottom', [(False, False), (True, False), (False, True), (True, True)])
def test_pixel_bbox_anchor_corner_arithmetic(anchor, ax, ay, right, bottom):
    # Arithmetic fixture, not native glyph-size verification.
    assert 'case ANCHOR_' + anchor + ':' in body('AuditBox')
    x, y, width, height = 12, 18, 80, 20
    anchor_x, anchor_y = (1187 - x if right else x), (380 - y if bottom else y)
    left, top = anchor_x - ax * width, anchor_y - ay * height
    assert left + ax * width == anchor_x and top + ay * height == anchor_y


def test_metadata_reports_live_identity_calibration_and_partial_observation_truthfully():
    start = body('OnStart')
    for field in ('artifact_kind', 'audit_id', 'account_login', 'server', 'account_mode', 'chart_id', 'hwnd',
                  'symbol', 'timeframe', 'expert', 'design', 'view', 'plot_width', 'plot_height', 'dpi',
                  'objects_complete', 'properties_complete', 'binding_stable', 'capture_non_atomic',
                  'screenshot_calibrated', 'screenshot_ok', 'screenshot_width', 'screenshot_height',
                  'started_utc', 'finished_utc', 'observation_complete'):
        assert '"' + field + '"' in start
    assert 'design="UNOBSERVED",view="UNOBSERVED"' in start
    assert 'ObjectGetString(AUDIT_CHART,AUDIT_PREFIX+"design_version",OBJPROP_TEXT)' in start
    assert 'ObjectGetString(AUDIT_CHART,AUDIT_PREFIX+"view",OBJPROP_TEXT)' in start
    assert 'const bool complete=objects_ok && properties_ok && binding_stable;' in start
    assert start.index('AuditObjects(') < start.index('FileOpen(root+".meta.csv"')
    properties = body('AuditProperties')
    for item in ('CHART_SHOW_TRADE_LEVELS', 'CHART_DRAG_TRADE_LEVELS', 'CHART_SCALE', 'CHART_SHIFT_SIZE',
                 'CHART_AUTOSCROLL', 'CHART_COLOR_BACKGROUND', 'CHART_SHOW_BID_LINE'):
        assert item in properties
