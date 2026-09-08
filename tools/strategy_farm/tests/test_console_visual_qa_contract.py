"""Static safety boundaries for the isolated FTMO-demo console visual probe.

These checks never launch MT5, attach an EA, change terminal settings or trade.
They are source-regression contracts, not an MQL parser or a runtime no-trade
proof. In particular, ChartOpen can apply default.tpl (including an EA): creation
must use the Python launcher's template preflight, or an independently verified
empty fixture chart. Calling the native script directly bypasses that preflight.
"""

import ast
from pathlib import Path
import re

import pytest


REPO = Path(__file__).resolve().parents[3]
LAUNCHER = REPO / "framework/tests/mql5/QM_Console_ProbeLauncher.mq5"
HARNESS = REPO / "framework/tests/mql5/QM_Console_Visual_QA.mq5"
RENDERER = REPO / "framework/include/QM/QM_StrategyConsole.mqh"
SCHEME = REPO / "framework/include/QM/QM_ChartScheme.mqh"
UI = REPO / "tools/strategy_farm/console_ftmo_ui.py"

# Recognize comments only outside quoted strings (including escaped quotes).
_LEXEMES = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*.*?\*/', re.S)
_UNSAFE_CALLS = re.compile(
    r"\b(?:OrderSend(?:Async)?|OrderCheck|OrderOpen|OrderClose|OrderDelete|"
    r"OrderModify|PositionOpen|PositionClose(?:Partial|By)?|PositionModify|"
    r"Buy(?:Limit|Stop|StopLimit)?|Sell(?:Limit|Stop|StopLimit)?|"
    r"ChartApplyTemplate|ChartSaveTemplate|ChartSetSymbolPeriod|ChartClose|"
    r"ExpertRemove|TerminalClose|EventChartCustom|SendNotification|SendMail|"
    r"WebRequest|Socket\w*|ShellExecute\w*|WinExec|CreateProcess\w*|"
    r"FileDelete|FileMove|FileCopy|FolderDelete|GlobalVariableSet(?:OnCondition)?|"
    r"GlobalVariableDel|GlobalVariablesDeleteAll|GlobalVariablesFlush)\s*\("
)


def _code(text: str, *, mask_strings: bool = False) -> str:
    def replace(match: re.Match) -> str:
        token = match.group()
        if token.startswith(("//", "/*")) or mask_strings:
            return " " * len(token)
        return token

    return _LEXEMES.sub(replace, text)


def _source(path: Path) -> str:
    return _code(path.read_text(encoding="utf-8"))


def _compact(text: str) -> str:
    return re.sub(r"\s+", "", text)


def _conditional_source(text: str, defines: set[str]) -> str:
    """Select this harness's ifdef/ifndef branches, without executing MQL."""
    enabled = True
    stack = []
    lines = []
    for line in text.splitlines():
        match = re.fullmatch(r'\s*#(ifdef|ifndef)\s+(\w+)\s*', line)
        if match:
            condition = match[2] in defines
            if match[1] == 'ifndef':
                condition = not condition
            stack.append((enabled, condition))
            enabled = enabled and condition
        elif line.strip() == '#else':
            parent, condition = stack[-1]
            stack[-1] = (parent, not condition)
            enabled = parent and not condition
        elif line.strip() == '#endif':
            enabled, _ = stack.pop()
        elif enabled:
            lines.append(line)
    assert not stack, 'Unbalanced compile-time branch'
    return '\n'.join(lines)


def _body(text: str, name: str) -> str:
    masked = _code(text, mask_strings=True)
    match = re.search(r"\b" + re.escape(name) + r"\s*\([^;{}]*\)\s*(?:const\s*)?\{", masked)
    assert match, f"Missing function {name}"
    depth = 1
    for offset in range(match.end(), len(masked)):
        depth += (masked[offset] == "{") - (masked[offset] == "}")
        if depth == 0:
            return text[match.end():offset]
    raise AssertionError(f"Unbalanced function {name}")


def _assert_no_unsafe_calls(text: str) -> None:
    code = _code(text, mask_strings=True)
    assert not _UNSAFE_CALLS.search(code), "Trading, external write or terminal-control call"
    assert not re.search(r"^\s*#\s*import\b|\bCTrade\b|\bMqlTradeRequest\b", code, re.M)


@pytest.mark.parametrize("path", [LAUNCHER, HARNESS], ids=["launcher", "fixture"])
def test_probe_has_no_direct_trade_or_external_control_calls(path):
    _assert_no_unsafe_calls(path.read_text(encoding="utf-8"))


@pytest.mark.parametrize("call", ["OrderSend", "OrderSendAsync", "PositionClose", "BuyStop",
                                  "ChartApplyTemplate", "ChartSetSymbolPeriod", "ChartClose",
                                  "ExpertRemove", "GlobalVariableSet", "ShellExecuteW"])
def test_unsafe_call_detector_rejects_executable_mutations(call):
    with pytest.raises(AssertionError):
        _assert_no_unsafe_calls(f"void OnStart() {{ {call}(0); }}")


def test_comment_or_string_cannot_hide_real_call_or_cause_false_positive():
    _assert_no_unsafe_calls('// OrderSend(0);\nPrint("OrderSend(0), escaped \\\" quote");')
    with pytest.raises(AssertionError):
        _assert_no_unsafe_calls('Print("safe"); /* comment */ OrderSend(0);')


def test_probe_entrypoints_do_not_process_trading_events():
    for path in (LAUNCHER, HARNESS):
        assert not re.search(r"\b(?:OnTick|OnTrade|OnTradeTransaction|OnBookEvent)\s*\(", _source(path))
    assert not re.search(r"^\s*#include", _source(LAUNCHER), re.M)
    assert re.findall(r"^\s*#include\s+(.+)$", _source(HARNESS), re.M) == [
        "<QM/QM_ChartScheme.mqh>", "<QM/QM_ChartPanelCompare.mqh>",
        '"QM_ChartPresentationV2_selftests.mqh"', "<QM/QM_StrategyConsoleV2.mqh>",
        "<QM/QM_ChartPanel.mqh>", '"QM_ConsoleData_selftests.mqh"',
        '"QM11421_ConsoleNews_helpers.mqh"', '"QM11421_ConsoleNews_selftests.mqh"',
    ]


def test_launcher_demo_server_guard_precedes_every_side_effect():
    body = _compact(_body(_source(LAUNCHER), "OnStart"))
    guard = ('if(AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO||'
             'AccountInfoString(ACCOUNT_SERVER)!="FTMO-Demo")')
    assert body.startswith(guard)
    refusal = body.index("return;", len(guard))
    for effect in ("FolderCreate(", "FileOpen(", "FileWrite(", "ChartOpen(", "ChartSetString("):
        assert refusal < body.index(effect)


def test_original_eurusd_d1_ea_must_be_found_before_fixture_creation():
    body = _compact(_body(_source(LAUNCHER), "OnStart"))
    identity = ('if(ChartSymbol(chart)=="EURUSD"&&ChartPeriod(chart)==PERIOD_D1&&'
                'StringFind(expert,"QM5_11421_")==0)')
    assert identity in body
    assert 'conststringexpert=ChartGetString(chart,CHART_EXPERT_NAME);' in body
    refusal = body.index("if(!found)")
    assert "return;" in body[refusal:body.index("conststringmarker=")]
    assert refusal < body.index("ChartOpen(")


def test_existing_chart_audit_does_not_mutate_chart_objects_or_bindings():
    body = _body(_source(LAUNCHER), "OnStart")
    audit = body[body.index("for(long chart="):body.index("if(!found)")]
    assert "ChartScreenShot(chart," in audit  # Evidence write, not chart mutation.
    assert not re.search(r"\b(?:ChartSet\w*|ObjectSet\w*|ObjectCreate|ObjectMove|"
                         r"ObjectDelete|ObjectsDeleteAll|ChartOpen)\s*\(", audit)
    assert 'if(StringFind(name,"QM_")!=0) continue;' in audit


def test_existing_marker_is_reused_only_for_expected_symbol_period_and_expert():
    body = _compact(_body(_source(LAUNCHER), "OnStart"))
    existing = body[body.index("if(FileIsExist(marker))"):body.index('else{fixture=ChartOpen')]
    assert 'FileOpen(marker,FILE_READ|FILE_TXT|FILE_ANSI)' in existing
    assert 'fixture=StringToInteger(FileReadString(existing))' in existing
    guard = ('if(fixture==0||ChartSymbol(fixture)!="EURUSD"||ChartPeriod(fixture)!=PERIOD_D1||'
             '(StringLen(ChartGetString(fixture,CHART_EXPERT_NAME))>0&&'
             'ChartGetString(fixture,CHART_EXPERT_NAME)!="QM_Console_Visual_QA"))')
    assert guard in existing and "return;" in existing[existing.index(guard):]


def test_launcher_only_opens_one_explicit_fixture_and_mutates_that_chart():
    body = _compact(_body(_source(LAUNCHER), "OnStart"))
    assert body.count("ChartOpen(") == 1
    assert 'else{fixture=ChartOpen("EURUSD",PERIOD_D1);' in body
    assert 'if(fixture==0)' in body
    assert re.findall(r"\bChartSet(?:String|Integer|Double)\(([^,]+),([^,]+),", body) == [
        ("fixture", "CHART_COMMENT"), ("fixture", "CHART_BRING_TO_TOP"),
    ]
    assert '"DESIGNQA-SYNTHETICDATA-NOTRADING"' in body


def test_new_fixture_rejects_unexpected_expert_before_publishing_binding():
    body = _compact(_body(_source(LAUNCHER), "OnStart"))
    guard = 'if(fixture>0&&StringLen(ChartGetString(fixture,CHART_EXPERT_NAME))>0)'
    assert body.index('ChartOpen(') < body.index(guard)
    refusal = body.index('return;', body.index(guard))
    assert refusal < body.index('FileOpen(marker,FILE_WRITE')
    assert refusal < body.index('ChartSetString(fixture,')


def _template_preflight(tmp_path: Path):
    """Execute only the read-only helper, never import pywinauto or run main."""
    tree = ast.parse(UI.read_text(encoding="utf-8"))
    function = next(node for node in tree.body
                    if isinstance(node, ast.FunctionDef) and node.name == 'check_default_template')
    namespace = {'Path': Path, 'DATA': tmp_path / 'data',
                 'TERMINAL': str(tmp_path / 'install/terminal64.exe')}
    exec(compile(ast.Module(body=[function], type_ignores=[]), str(UI), 'exec'), namespace)
    return namespace['check_default_template']


@pytest.mark.parametrize('root', ['data', 'install'])
@pytest.mark.parametrize('raw', [
    b'<chart>\n<expert>unsafe EA</expert>\n</chart>',
    '<CHART>\n<EXPERT>unsafe EA</EXPERT>\n</CHART>'.encode('utf-16'),
    b'not a verified chart template',
])
def test_template_preflight_rejects_ea_or_unverified_template_in_both_locations(tmp_path, root, raw):
    template = tmp_path / root / 'MQL5/Profiles/Templates/default.tpl'
    template.parent.mkdir(parents=True)
    template.write_bytes(raw)
    with pytest.raises(RuntimeError, match='not verified EA-free'):
        _template_preflight(tmp_path)()


@pytest.mark.parametrize('raw', [b'<chart>\n</chart>', '<chart>\n</chart>'.encode('utf-16'),
                                 '<chart>\n</chart>'.encode('utf-16-le'),
                                 b'\xfe\xff' + '<chart>\n</chart>'.encode('utf-16-be')])
def test_template_preflight_accepts_verified_ea_free_native_encodings(tmp_path, raw):
    template = tmp_path / 'data/MQL5/Profiles/Templates/default.tpl'
    template.parent.mkdir(parents=True)
    template.write_bytes(raw)
    _template_preflight(tmp_path)()


def test_template_preflight_allows_absent_defaults_without_creating_files(tmp_path):
    _template_preflight(tmp_path)()
    assert list(tmp_path.iterdir()) == []


def test_python_launcher_checks_default_before_requesting_native_creation():
    text = UI.read_text(encoding='utf-8')
    launch = text.split('elif args.action == "launch-probe":', 1)[1].split('elif ', 1)[0]
    assert launch.index('check_default_template()') < launch.index('select_node(')
    assert launch.index('check_default_template()') < launch.index('command(window, ATTACH_TO_CHART)')


def test_fixture_identity_requires_demo_server_symbol_period_and_exact_chart_id():
    body = _compact(_body(_source(HARNESS), "FixtureChartAllowed"))
    assert body.startswith(
        'if(AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO||'
        'AccountInfoString(ACCOUNT_SERVER)!="FTMO-Demo"||_Symbol!="EURUSD"||_Period!=PERIOD_D1)'
        'returnfalse;'
    )
    assert 'FileOpen("QM_Console_QA\\\\fixture_chart.txt",FILE_READ|FILE_TXT|FILE_ANSI)' in body
    assert 'if(f==INVALID_HANDLE)returnfalse;' in body
    assert 'constlongexpected=StringToInteger(FileReadString(f));FileClose(f);' in body
    assert body.endswith('returnexpected==ChartID();')


def test_rejected_fixture_init_cannot_apply_style_initialize_renderer_or_start_timer():
    body = _compact(_body(_source(HARNESS), "OnInit"))
    assert body.startswith('if(!FixtureChartAllowed())')
    refusal = body.index("returnINIT_FAILED;")
    for call in ("QM_PanelFormatterSelfTest(", "QM_ConsoleDataSelfTest(",
                 "QM_ChartScheme_Apply(", "InitializeRenderer(", "EventSetTimer("):
        assert refusal < body.index(call)
    assert 'QM_ChartScheme_Apply(ChartID());' in body
    assert 'if(!InitializeRenderer())returnINIT_FAILED;' in body


def test_wrong_chart_failed_init_cleanup_is_inert_without_prior_initialization():
    renderer = _source(RENDERER)
    constructor = _compact(_body(renderer, "CQMStrategyConsole"))
    assert 'm_prefix="";' in constructor and 'm_ready=false;' in constructor
    shutdown = _compact(_body(renderer, "Shutdown"))
    assert 'if(m_prefix!=""){ObjectsDeleteAll(m_chart,m_prefix);ChartRedraw(m_chart);}' in shutdown
    restore = _compact(_body(_source(SCHEME), "QM_ChartScheme_Restore"))
    assert restore.startswith('if(!g_qm_chart_scheme_snapshot.applied||'
                              'g_qm_chart_scheme_snapshot.chart_id!=chart_id)return;')
    deinit = _compact(_body(_source(HARNESS), "OnDeinit"))
    assert deinit == 'EventKillTimer();g_renderer.Shutdown();QM_ChartScheme_Restore(ChartID());'


def test_fixture_values_are_explicitly_synthetic_without_live_data_collection():
    body = _body(_source(HARNESS), "BuildFixture")
    assert 's.environment="DESIGN QA"' in body
    assert 's.reason="Synthetic fixture - no trading functions"' in body
    assert "s.exposure[0].ticket=999999001;" in body
    assert not re.search(r"\b(?:AccountInfo\w*|History\w*|Position\w*|Order\w*|"
                         r"SymbolInfo\w*|Copy\w*|TimeCurrent|TimeTradeServer|"
                         r"QM_PanelBuild\w*|File\w*)\s*\(", _code(body, mask_strings=True))
    assert "CQMConsoleData" not in _source(HARNESS)


def test_commands_are_local_read_only_monotonic_and_bounded():
    body = _compact(_body(_source(HARNESS), "OnTimer"))
    assert 'FileOpen("QM_Console_QA\\\\command.csv",FILE_READ|FILE_CSV|FILE_ANSI,' in body
    guard = 'if(serial<=g_serial||scenario<0||scenario>7||mode<0||mode>2||scale<80||scale>150)return;'
    assert guard in body
    assert body.index(guard) < body.index('g_serial=serial;')
    assert body.index(guard) < body.index('g_case=scenario;')
    assert 'PresentationEvent(CHARTEVENT_OBJECT_CLICK,g_prefix+action);' in body
    assert not re.search(r"FileOpen\([^;]*\baction\b|ChartSet\w*\([^;]*\baction\b", body)


def test_probe_namespace_and_chart_binding_cannot_be_changed_by_commands():
    text = _source(HARNESS)
    assert re.findall(r"\bg_prefix\s*=(?!=)\s*([^;]+);", text) == ['"QM_QA_"']
    assert text.count("g_renderer.Initialize(") == 2
    assert text.count("g_renderer.Initialize(ChartID(),g_prefix,") == 2
    assert text.count('g_renderer.InitializePresentation(ChartID(),g_prefix,') == 1
    assert _compact(_body(text, "OnChartEvent")) == 'PresentationEvent(id,sparam);'
    event = _compact(_body(text, 'PresentationEvent'))
    assert event.startswith('#ifndefQM_CONSOLE_DESIGN_COMPAREif(!g_renderer.Ready())return;#endif')
    assert 'g_renderer.OnChartEvent(id,name);' in event
    assert event.endswith('#ifdefQM_CONSOLE_DESIGN_COMPAREg_display_mode=g_renderer.Mode();#endif')
    assert event.index('g_renderer.OnChartEvent(id,name);') < event.index('g_display_mode=g_renderer.Mode();')
    assert 'name==g_prefix+"view"' in event
    assert not re.search(r"\bChart(?:Open|Set\w*)\s*\(", text)


def test_capture_is_deferred_to_next_timer_event_for_native_object_measurement():
    body = _compact(_body(_source(HARNESS), "OnTimer"))
    assert body.startswith('if(g_capture_pending>=0){Capture(g_capture_pending);g_capture_pending=-1;return;}')
    assert body.count('Capture(') == 1
    assert 0 <= body.rfind('RenderFixture(s);') < body.index('g_capture_pending=serial;')
    assert body.endswith('g_capture_pending=serial;')


def test_ab_command_without_reset_reuses_cached_snapshot_and_quote_before_capture():
    timer = _compact(_body(_source(HARNESS), 'OnTimer'))
    assert ('constboolreset=g_case!=scenario||g_mode!=(QM_ConsoleMode)mode||'
            'g_scale!=scale||action=="reset";') in timer
    assert 'if(reset){g_case=scenario;g_mode=(QM_ConsoleMode)mode;g_scale=scale;' in timer
    refresh = ('if(reset||action!="design_version")'
               '{QM_ConsoleSnapshot s;BuildFixture(s);RenderFixture(s);}')
    refresh = _compact(refresh)
    assert refresh in timer
    # The only other refresh is the no-command fallback. Nothing may refresh
    # unconditionally before/after the cached A/B event.
    assert 'if(f==INVALID_HANDLE){QM_ConsoleSnapshot s;BuildFixture(s);RenderFixture(s);return;}'.replace(' ', '') in timer
    assert timer.count('BuildFixture(s);') == 2 and timer.count('RenderFixture(s);') == 2
    event = 'PresentationEvent(CHARTEVENT_OBJECT_CLICK,g_prefix+action);'
    assert timer.index(refresh) < timer.index(event) < timer.index('g_capture_pending=serial;')
    assert 'g_renderer.Refresh(' not in timer and 'SymbolInfoTick(' not in timer


def test_capture_exports_only_fixture_objects_on_its_current_chart():
    body = _compact(_body(_source(HARNESS), "Capture"))
    assert 'conststringroot="QM_Console_QA\\\\qa_"+IntegerToString(serial);' in body
    assert 'ChartScreenShot(0,root+".png",screenshot_width,screenshot_height,ALIGN_LEFT);' in body
    for guard in ('chart==ChartID()', 'window==ChartGetInteger(0,CHART_WINDOW_HANDLE)',
                  'plot_width==width', 'plot_height==height',
                  'dpi==TerminalInfoInteger(TERMINAL_SCREEN_DPI)',
                  'client_width<=width+512', 'client_height<=height+512'):
        assert guard in body
    assert 'FileOpen(root+".csv",FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8)' in body
    assert 'if(StringFind(name,g_prefix)!=0&&StringFind(name,"QM_CHART_V2_"+g_prefix)!=0)continue;' in body
    assert 'constbooloverlay=StringFind(name,"QM_CHART_V2_"+g_prefix)==0||' in body
    assert 'ObjectName(0,i)' in body
    assert not re.search(r"\bObjectGet(?:Integer|String|Double)\((?!0,)", body)
    for field in ('OBJPROP_TYPE', 'OBJPROP_XDISTANCE', 'OBJPROP_YDISTANCE',
                  'OBJPROP_XSIZE', 'OBJPROP_YSIZE', 'OBJPROP_ANCHOR',
                  'OBJPROP_TEXT', 'OBJPROP_TOOLTIP'):
        assert field in body
    assert 'CHART_WIDTH_IN_PIXELS' in body and 'CHART_HEIGHT_IN_PIXELS' in body


def test_all_file_access_stays_in_terminal_local_qa_folder():
    for path in (LAUNCHER, HARNESS):
        text = _source(path)
        assert 'FILE_COMMON' not in text
        args = re.findall(r'\bFileOpen\(\s*("(?:\\.|[^"\\])*"|[^,]+),', text)
        assert args
        for arg in args:
            assert arg.startswith('"QM_Console_QA\\\\') or arg in (
                'marker', 'root+".csv"', 'root+".meta.csv"', 'root+".chart.csv"', 'receipt'), arg
    assert 'const string marker="QM_Console_QA\\\\fixture_chart.txt";' in _source(LAUNCHER)
    assert 'const string receipt="QM_Console_QA\\\\selftests_"+g_init_token+".csv";' in _source(HARNESS)


def test_native_csv_writer_quotes_commas_quotes_and_multiline_fields():
    body = _body(_source(HARNESS), 'WriteCsvRow')
    assert 'StringReplace(value,"\\\"","\\\"\\\"")' in body
    assert 'line+="\\\""+value+"\\\"";' in body
    assert 'FileWriteString(file,line+"\\r\\n")>0' in body


def test_metadata_is_written_after_objects_and_records_actual_mode_and_run():
    body = _body(_source(HARNESS), 'Capture')
    assert body.index('FileClose(f)') < body.index('FileOpen(root+".meta.csv"')
    for field in ('schema_version', 'chart_width', 'chart_height', 'dpi', 'scenario',
                  'mode_name', 'requested_mode', 'scale', 'capture_complete', 'object_count',
                  'init_run_id', 'selftest_receipt', 'type_name', 'anchor_name', 'corner_name', 'scope'):
        assert '"' + field + '"' in body
    assert 'EnumToString(g_display_mode)' in body
    assert 'ObjectGetDouble(0,name,OBJPROP_ANGLE)' in body
    assert 'row[14]=!pixel?"time_price":overlay?"overlay":"panel";' in body


def test_native_selftest_receipt_covers_formatter_model_and_exact_data_suite_count():
    body = _body(_source(HARNESS), 'OnInit')
    assert body.index('if(!FixtureChartAllowed())') < body.index('FileOpen(receipt,')
    assert 'TimeLocal()' in body and 'GetTickCount64()' in body
    for suite in ('formatter', 'model', 'data'):
        assert f'result[2]="{suite}"' in body
    assert 'result[4]="11"; result[5]=data_ok?"11":"0";' in body
    fixture = _source(REPO / 'framework/tests/mql5/QM_ConsoleData_selftests.mqh')
    assert _body(fixture, 'QM_ConsoleDataSelfTest').count('QM_ConsoleDataExpect(') == 11
    assert body.index('if(!data_ok || !proof_ok)') < body.index('InitializeRenderer()')


def test_v2_is_opt_in_and_dashboard_only():
    text = _source(HARNESS)
    assert '#define QM_CONSOLE_DESIGN_V2' not in text
    assert '#define QM_CONSOLE_DESIGN_COMPARE' not in text
    assert '#ifdef QM_CONSOLE_DESIGN_V2\nCQMStrategyConsoleV2 g_renderer;\n#else\nCQMStrategyConsole g_renderer;' in text
    v2 = _body(_conditional_source(text, {'QM_CONSOLE_DESIGN_V2'}), 'InitializeRenderer')
    v1 = _body(_conditional_source(text, set()), 'InitializeRenderer')
    assert 'g_scale,false,false,false,false)' in v2
    assert 'g_scale,true,true,true,true)' in v1


@pytest.mark.parametrize('defines,expected_type,compare', [
    (set(), 'CQMStrategyConsole', False),
    ({'QM_CONSOLE_DESIGN_V2'}, 'CQMStrategyConsoleV2', False),
    ({'QM_CONSOLE_DESIGN_COMPARE'}, 'CQMChartPanelCompare', True),
    ({'QM_CONSOLE_DESIGN_COMPARE', 'QM_CONSOLE_DESIGN_V2'}, 'CQMChartPanelCompare', True),
])
def test_each_compile_mode_keeps_fixture_binding_and_only_expected_presentation_api(defines, expected_type, compare):
    text = _conditional_source(_source(HARNESS), defines)
    assert re.findall(r'\b(CQM\w+)\s+g_renderer;', text) == [expected_type]
    init = _compact(_body(text, 'OnInit'))
    assert init.startswith('if(!FixtureChartAllowed())')
    assert init.index('returnINIT_FAILED;') < init.index('InitializeRenderer()')
    initialize = _compact(_body(text, 'InitializeRenderer'))
    if compare:
        assert ('g_renderer.InitializePresentation(ChartID(),g_prefix,true,g_mode,g_scale,'
                'true,true,true,true,QM_DESIGN_2,true)') in initialize
        assert 'g_renderer.Initialize(' not in initialize  # No account collector initialization.
    else:
        assert 'g_renderer.Initialize(ChartID(),g_prefix,' in initialize
        assert 'InitializePresentation(' not in initialize
    render = _compact(_body(text, 'RenderFixture'))
    assert render == ('g_renderer.Refresh(snapshot);' if compare else 'g_renderer.Render(snapshot);')
    assert 'BuildFixture(' not in render and 'Populate(' not in render
    assert 'CQMConsoleData' not in text


def test_compare_render_refresh_observes_quote_without_modifying_fixture_or_reading_account_history():
    adapter = _source(REPO / 'framework/include/QM/QM_ChartPanelCompare.mqh')
    refresh = _compact(_body(adapter, 'Refresh'))
    assert 'm_cached=snapshot;m_has_snapshot=true;' in refresh
    assert 'SymbolInfoTick(snapshot.symbol,quote)' in refresh
    assert 'm_bid=quote.bid;' in refresh
    assert not re.search(r'\b(?:AccountInfo\w*|History\w*|Position\w*|Order\w*|Populate|Invalidate)\s*\(', refresh)
    assert not re.search(r'\bsnapshot\.\w+\s*=(?!=)', refresh)
    event = _body(adapter, 'OnChartEvent')
    assert 'SymbolInfoTick(' not in event and 'Refresh(' not in event


def test_compare_metadata_reports_effective_design_and_mode_after_ab_click():
    text = _conditional_source(_source(HARNESS), {'QM_CONSOLE_DESIGN_COMPARE'})
    event = _compact(_body(text, 'PresentationEvent'))
    assert event.endswith('g_renderer.OnChartEvent(id,name);g_display_mode=g_renderer.Mode();')
    capture = _compact(_body(text, 'Capture'))
    assert 'values[18]=g_renderer.Design()==QM_DESIGN_2?"V2":"V1";' in capture
    assert 'values[7]=IntegerToString((int)g_display_mode);values[8]=EnumToString(g_display_mode);' in capture
    assert 'values[9]=IntegerToString((int)g_mode);' in capture


@pytest.mark.parametrize('defines,news,chart', [
    (set(), False, False), ({'QM_CONSOLE_NEWS_SELFTEST'}, True, False),
    ({'QM_CONSOLE_DESIGN_V2', 'QM_CONSOLE_NEWS_SELFTEST'}, True, False),
    ({'QM_CONSOLE_DESIGN_COMPARE'}, False, True),
    ({'QM_CONSOLE_DESIGN_COMPARE', 'QM_CONSOLE_NEWS_SELFTEST'}, True, True),
])
def test_optional_native_selftests_execute_only_after_fixture_guard_and_before_renderer(defines, news, chart):
    text = _conditional_source(_source(HARNESS), defines)
    init = _compact(_body(text, 'OnInit'))
    guard = init.index('if(!FixtureChartAllowed())')
    refused = init.index('returnINIT_FAILED;', guard)
    for call, included in [('QM11421_ConsoleNewsSelfTest(failure)', news),
                           ('QM_ChartPresentationV2SelfTest(failure)', chart),
                           ('QM_ChartPresentationV2ChartSelfTest(ChartID(),failure)', chart),
                           ('QM_ChartPresentationV2ZoomSelfTest(ChartID(),failure,true)', chart),
                           ('CompareStartFailureSelfTest(ChartID(),failure)', chart),
                           ('CompareRenderFailureSelfTest(ChartID(),failure)', chart),
                           ('CompareInitialStartFailureSelfTest(ChartID(),failure)', chart)]:
        if included:
            assert refused < init.index(call) < init.index('QM_ChartScheme_Apply(ChartID())')
            assert init.index(call) < init.index('InitializeRenderer()')
        else:
            assert call not in init
    assert ('#include "QM11421_ConsoleNews_helpers.mqh"' in text) is news
    assert ('#include "QM11421_ConsoleNews_selftests.mqh"' in text) is news
    assert ('#include "QM_ChartPresentationV2_selftests.mqh"' in text) is chart
    if news:
        assert 'if(!news_ok||!news_proof_ok)' in init
    if chart:
        assert 'if(!geometry_ok||!roundtrip_ok||!zoom_ok||!chart_proof_ok)' in init
        assert 'if(!compare_ok||!compare_proof_ok)' in init
    assert not re.search(r'\bStrategy_\w*\s*\(', _code(text, mask_strings=True))


def test_news_helpers_and_twenty_four_native_cases_are_pure_observation_logic():
    # The helper include is generated only inside the compile artifact from
    # these exact production functions; do not require a copied EA in the repo.
    ea = _source(REPO / 'framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/'
                       'QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5')
    for name in ('QM11421_ConsoleNewsKeyMatches', 'QM11421_ConsoleNewsObservation', 'QM11421_ConsoleGateAlerts'):
        body = _code(_body(ea, name), mask_strings=True)
        calls = set(re.findall(r'\b(\w+)\s*\(', body))
        assert calls <= {'if', 'for', 'ArraySize', 'return'}, (name, calls)
    tests = _source(REPO / 'framework/tests/mql5/QM11421_ConsoleNews_selftests.mqh')
    assert _body(tests, 'QM11421_ConsoleNewsSelfTest').count('QM11421_NewsExpect(') == 24
    assert not re.search(r'\b(?:Strategy_\w*|QM_News\w*|Calendar\w*|AccountInfo\w*|History\w*|'
                         r'SymbolInfo\w*|TimeCurrent|TimeGMT|File\w*|Chart\w*)\s*\(', _code(tests, mask_strings=True))
    _assert_no_unsafe_calls(tests)


def test_native_chart_roundtrip_uses_only_guard_passed_chart_and_own_fixture_objects():
    tests = _source(REPO / 'framework/tests/mql5/QM_ChartPresentationV2_selftests.mqh')
    _assert_no_unsafe_calls(tests)
    native = _compact(_body(tests, 'QM_ChartPresentationV2ChartSelfTest'))
    assert 'conststringprefix="QM_V2_RT_";' in native
    assert 'presenter.Initialize(chart,prefix,' in native
    assert 'ObjectDelete(chart,prefix+"identity")' in native
    assert 'presenter.Shutdown(' in native
    assert not re.search(r'\b(?:ChartOpen|ChartClose|ChartSetSymbolPeriod|ChartApplyTemplate|Strategy_\w*)\s*\(', native)
    harness = _source(HARNESS)
    assert harness.count('QM_ChartPresentationV2ChartSelfTest(') == 1
    assert 'QM_ChartPresentationV2ChartSelfTest(ChartID(),failure)' in _body(harness, 'OnInit')


def test_pending_fixture_dates_follow_chart_bar_without_live_trade_state():
    body = _body(_source(HARNESS), 'BuildFixture')
    assert 'g_fixture_bar=iTime(_Symbol,PERIOD_D1,0)' in body
    assert 'if(g_fixture_bar<=0) g_fixture_bar=D\'2026.09.07 00:00\';' in body
    assert 's.exposure[0].opened=g_fixture_bar-PeriodSeconds(PERIOD_D1)/2;' in body
    assert 's.range_end=g_fixture_bar;' in body


def test_compare_presentation_event_delegates_recovery_clicks_even_when_unready():
    compare = _conditional_source(_source(HARNESS), {'QM_CONSOLE_DESIGN_COMPARE'})
    event = _compact(_body(compare, 'PresentationEvent'))
    assert 'if(!g_renderer.Ready())return;' not in event
    assert 'g_renderer.OnChartEvent(id,name);' in event
    assert 'if(g_renderer.Ready()&&id==CHARTEVENT_OBJECT_CLICK&&name==g_prefix+"view")' in event
    for defines in (set(), {'QM_CONSOLE_DESIGN_V2'}):
        plain = _compact(_body(_conditional_source(_source(HARNESS), defines), 'PresentationEvent'))
        assert plain.startswith('if(!g_renderer.Ready())return;')


def test_native_compare_failure_uses_real_prefix_guard_without_production_hooks():
    text = _conditional_source(_source(HARNESS), {'QM_CONSOLE_DESIGN_COMPARE'})
    native = _compact(_body(text, 'CompareStartFailureSelfTest'))
    assert 'conststringprefix="QM_QA_FAIL_"+StringSubstr(g_init_token,' in native
    assert 'StringLen(prefix)!=30' in native
    assert 'StringLen("QM_CHART_V2_"+prefix)<=35' in native
    assert 'chart!=ChartID()' in native and 'CompareFixtureObjects(chart,prefix)!=0' in native
    assert 'probe.InitializePresentation(chart,prefix,true,QM_CONSOLE_COMPACT,100,false,false,false,false,QM_DESIGN_1,true)' in native
    chart = _source(REPO / 'framework/include/QM/QM_ChartPresentationV2.mqh')
    assert 'StringLen(prefix)>35' in _compact(_body(chart, 'Initialize'))
    assert 'StringLen(g_init_token)-19' in native
    assert len('QM_QA_FAIL_' + '1' * 19) == 30
    assert len('QM_CHART_V2_' + 'QM_QA_FAIL_' + '1' * 19) == 42
    assert 'restore_failure_injected=0' in native
    assert not re.search(r'\b(?:ChartSet\w*|ChartOpen|ChartClose|AccountInfo\w*|History\w*|Order\w*|Position\w*|SymbolInfo\w*)\s*\(', native)
    assert not re.search(r'^\s*#\s*define\b', text, re.M)


def test_native_compare_failure_observes_one_cache_and_requires_actual_redraw():
    native = _compact(_body(_source(HARNESS), 'CompareStartFailureSelfTest'))
    assert native.count('probe.Refresh(snapshot);') == 1
    click = 'probe.OnChartEvent(CHARTEVENT_OBJECT_CLICK,prefix+"design_version");'
    assert native.index('probe.Refresh(snapshot);') < native.index('bid_before=probe.ObservedBidText();') < native.index(click)
    assert 'bid_before!=""&&time_before!=""' in native
    assert native.index('ObjectDelete(chart,prefix+"state_reason")') < native.index(click)
    assert 'ObjectFind(chart,prefix+"state_reason")<0;' in native
    after = native.split(click, 1)[1]
    assert 'probe.Refresh(' not in after
    assert 'probe.Ready()&&probe.Design()==QM_DESIGN_1&&probe.Mode()==QM_CONSOLE_COMPACT' in after
    assert 'bid_after==bid_before&&time_after==time_before&&after_objects==before_objects' in after
    assert 'ObjectFind(chart,prefix+"state_reason")>=0' in after
    assert 'ObjectGetString(chart,prefix+"state_reason",OBJPROP_TEXT)==snapshot.reason' in after
    assert 'ObjectGetString(chart,prefix+"state_next",OBJPROP_TEXT)==snapshot.next_event' in after
    assert 'ObjectGetString(chart,prefix+"design_version",OBJPROP_TEXT)=="01"' in after
    assert 'ObjectFind(chart,"QM_RETRY_"+prefix)<0' in after


def test_native_compare_failure_always_cleans_temporary_namespaces_and_binds_receipt():
    text = _source(HARNESS)
    native = _compact(_body(text, 'CompareStartFailureSelfTest'))
    assert native.index('probe.Shutdown();') < native.index('constintremaining=CompareFixtureObjects(chart,prefix);')
    assert 'constboolcleanup_ok=!probe.Ready()&&remaining==0;' in native
    assert native.endswith('returninitialized&&before_ok&&removed&&rollback_ok&&cleanup_ok;')
    census = _compact(_body(text, 'CompareFixtureObjects'))
    for prefix in ('name,prefix', 'name,"QM_CHART_V2_"+prefix', 'name,"QM_RETRY_"+prefix'):
        assert 'StringFind(' + prefix + ')==0' in census
    assert 'ObjectDelete(' not in census and 'ObjectsDeleteAll(' not in native
    init = _compact(_body(text, 'OnInit'))
    assert 'FileOpen("QM_Console_QA\\\\compare_selftests_"+g_init_token+".csv",' in init
    assert 'stringcompare_columns[]={"init_run_id","chart_id","suite","status","detail"};' in init
    assert 'stringcompare_result[]={g_init_token,IntegerToString(ChartID()),"compare_start_failure_rollback",compare_start_ok?"PASS":"FAIL",failure};' in init
    assert 'compare_result[2]="compare_render_failure_recovery";' in init
    assert 'constboolcompare_render_ok=compare_start_ok&&CompareRenderFailureSelfTest(ChartID(),failure);' in init
    assert 'compare_result[2]="initial_start_failure_retry";' in init
    assert 'constboolcompare_initial_ok=compare_render_ok&&CompareInitialStartFailureSelfTest(ChartID(),failure);' in init
    assert 'compare_result[3]=compare_initial_ok?"PASS":(compare_render_ok?"FAIL":"NOT_RUN");' in init
    assert 'constboolcompare_ok=compare_start_ok&&compare_render_ok&&compare_initial_ok;' in init
    assert 'if(!compare_ok||!compare_proof_ok)' in init
    assert init.index('FileClose(chart_proof);') < init.index('CompareStartFailureSelfTest(') < init.index('InitializeRenderer()')
    # Native chart proof includes the guarded changed-raster round-trip.
    assert re.findall(r'chart_result\[2\]="([^"]+)"', init) == ['chart_geometry', 'chart_property_roundtrip', 'chart_zoom_roundtrip']
    assert 'FixtureChartAllowed()' in init.split('constboolzoom_ok=')[1]
    assert 'QM_ChartPresentationV2ZoomSelfTest(ChartID(),failure,true)' in init
    assert '!zoom_ok' in init


def test_native_render_failure_uses_only_harness_owned_collision_and_explicit_cached_retry():
    native = _compact(_body(_source(HARNESS), 'CompareRenderFailureSelfTest'))
    assert 'conststringprefix="QM_RF_"+StringSubstr(g_init_token,' in native
    assert 'StringLen(prefix)!=18' in native and 'CompareFixtureObjects(chart,prefix)!=0' in native
    assert 'conststringcollision="QM_CHART_V2_"+prefix+"identity";' in native
    assert len('QM_RF_' + '1' * 12) == 18 and len('QM_CHART_V2_' + 'QM_RF_' + '1' * 12) <= 35
    assert 'probe.InitializePresentation(chart,prefix,true,QM_CONSOLE_COMPACT,100,false,false,false,false,QM_DESIGN_2,true)' in native
    assert 'created=ObjectFind(chart,collision)<0&&ObjectCreate(chart,collision,OBJ_LABEL,0,0,0);' in native
    assert 'rejected=!probe.Ready()&&probe.Design()==QM_DESIGN_2&&probe.Mode()==QM_CONSOLE_COMPACT' in native
    assert 'ObjectGetString(chart,collision,OBJPROP_TEXT)=="QAcollisionsentinel"' in native
    assert 'if(created)removed=ObjectDelete(chart,collision)&&ObjectFind(chart,collision)<0;' in native
    assert 'ObjectsDeleteAll(' not in native
    assert native.count('probe.Refresh(snapshot);') == 1
    click = 'probe.OnChartEvent(CHARTEVENT_CLICK,"");'
    assert native.index('probe.Refresh(snapshot);') < native.index('bid_before=probe.ObservedBidText();') < native.index(click)
    assert 'if(rejected&&removed)' in native
    after = native.split(click, 1)[1]
    assert 'probe.Refresh(' not in after
    assert 'recovered=probe.Ready()&&probe.Design()==QM_DESIGN_2&&probe.Mode()==QM_CONSOLE_COMPACT' in after
    assert 'bid_after==bid_before&&time_after==time_before' in after
    assert 'ObjectGetString(chart,prefix+"state_reason",OBJPROP_TEXT)==snapshot.reason' in after
    assert 'ObjectGetString(chart,prefix+"design_version",OBJPROP_TEXT)=="02"' in after
    assert 'ObjectFind(chart,collision)>=0&&ObjectGetString(chart,collision,OBJPROP_TEXT)!="QAcollisionsentinel"' in after
    assert 'ObjectFind(chart,"QM_RETRY_"+prefix)<0' in after
    assert 'probe.Shutdown();' in after and 'constboolcleanup_ok=!probe.Ready()&&remaining==0;' in after
    assert after.endswith('returninitialized&&injected&&rejected&&removed&&recovered&&cleanup_ok;')
    assert 'restore_failure_injected=0' in after


def test_native_initial_start_failure_uses_permanent_real_guard_and_checks_disabled_entry():
    native = _compact(_body(_source(HARNESS), 'CompareInitialStartFailureSelfTest'))
    assert 'conststringprefix="QM_QA_INIT_"+StringSubstr(g_init_token,' in native
    assert 'chart!=ChartID()' in native and 'StringLen(prefix)!=30' in native
    assert 'StringLen("QM_CHART_V2_"+prefix)<=35' in native
    assert 'CompareFixtureObjects(chart,prefix)!=0' in native
    assert len('QM_QA_INIT_' + '1' * 19) == 30
    assert len('QM_CHART_V2_' + 'QM_QA_INIT_' + '1' * 19) == 42
    assert 'disabled.InitializePresentation(chart,prefix,false,QM_CONSOLE_COMPACT,100,false,false,false,false,QM_DESIGN_2,true)' in native
    assert '!disabled_result&&!disabled.Ready()&&CompareFixtureObjects(chart,prefix)==0' in native
    assert 'disabled.ObservedBidText()==""&&disabled.QuoteObservedAt()==""' in native
    assert native.index('disabled.Shutdown();') < native.index('ObjectCreate(chart,sentinel,OBJ_LABEL,0,0,0)')
    assert 'probe.InitializePresentation(chart,prefix,true,QM_CONSOLE_COMPACT,100,false,false,false,false,QM_DESIGN_2,true)' in native
    assert 'initial_ok=!initialized&&!probe.Ready()&&probe.Design()==QM_DESIGN_2' in native
    assert 'before_objects==2&&bid_before==""&&time_before==""' in native
    assert 'ObjectGetInteger(chart,retry,OBJPROP_TYPE)==OBJ_BUTTON' in native
    assert 'ObjectGetString(chart,retry,OBJPROP_TEXT)=="Displayunavailable-retry"' in native
    for limit in ('transient_capture_failure_injected=0', 'same_invalid_prefix_recovered=0',
                  'restore_failure_injected=0', 'tester_guard_exercised=0'):
        assert limit in native
    assert not re.search(r'\b(?:ChartSet\w*|ChartOpen|ChartClose|AccountInfo\w*|History\w*|Order\w*|'
                         r'Position\w*|SymbolInfo\w*|EventSetTimer|EventSetMillisecondTimer)\s*\(', native)


def test_native_initial_start_failure_requires_processed_retry_without_quote_or_adoption():
    native = _compact(_body(_source(HARNESS), 'CompareInitialStartFailureSelfTest'))
    assert 'conststringretry="QM_RETRY_"+prefix;' in native
    assert 'conststringsentinel="QM_CHART_V2_"+prefix+"identity";' in native
    assert 'constboolcreated=ObjectFind(chart,sentinel)<0&&ObjectCreate(chart,sentinel,OBJ_LABEL,0,0,0);' in native
    assert native.count('probe.Refresh(snapshot);') == 1
    assert 'if(initial_ok)' in native
    assert 'refresh_blocked=!probe.Ready()&&probe.ObservedBidText()==""&&probe.QuoteObservedAt()=="";' in native
    click = 'probe.OnChartEvent(CHARTEVENT_OBJECT_CLICK,retry);'
    assert native.index('probe.Refresh(snapshot);') < native.index('ObjectDelete(chart,retry)') < native.index(click)
    assert 'removed_retry=ObjectDelete(chart,retry)&&ObjectFind(chart,retry)<0;' in native
    assert 'if(removed_retry)' in native
    after = native.split(click, 1)[1]
    assert 'probe.Refresh(' not in after
    assert 'retry_ok=!probe.Ready()&&probe.Design()==QM_DESIGN_2&&probe.Mode()==QM_CONSOLE_COMPACT' in after
    assert 'after_objects==2&&bid_after==bid_before&&time_after==time_before' in after
    assert 'ObjectFind(chart,retry)>=0&&ObjectGetInteger(chart,retry,OBJPROP_TYPE)==OBJ_BUTTON' in after
    assert 'ObjectGetString(chart,sentinel,OBJPROP_TEXT)=="Initialfailuresentinel"' in after
    assert 'ObjectFind(chart,prefix+"bg")<0;' in after
    assert after.index('probe.Shutdown();') < after.index('constboolnot_adopted=') < after.index('ObjectDelete(chart,sentinel)')
    assert 'if(created)removed_sentinel=ObjectDelete(chart,sentinel)&&ObjectFind(chart,sentinel)<0;' in after
    assert 'constboolcleanup_ok=!probe.Ready()&&removed_sentinel&&remaining==0;' in after
    assert after.endswith('returndisabled_ok&&seeded&&initial_ok&&refresh_blocked&&removed_retry&&retry_ok&&not_adopted&&cleanup_ok;')
    assert 'ObjectsDeleteAll(' not in native
