"""Static A/B presentation contracts for EA11421; no terminal is accessed.

These checks protect source-level ownership, event and data-flow boundaries.
They cannot prove native rendering, asynchronous property restoration or live
trade equivalence; compile/runtime receipts and the separate trading-path
baseline tests remain necessary. Missing in-flight renderer files are explicitly
skipped, never represented as passing native evidence.
"""

import csv
from pathlib import Path
import re

import pytest


REPO = Path(__file__).resolve().parents[3]
INCLUDE = REPO / 'framework/include/QM'
COMPARE = INCLUDE / 'QM_ChartPanelCompare.mqh'
V1 = INCLUDE / 'QM_StrategyConsole.mqh'
V2 = INCLUDE / 'QM_StrategyConsoleV2.mqh'
CHART = INCLUDE / 'QM_ChartPresentationV2.mqh'
EA = REPO / 'framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5'
_TOKENS = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*.*?\*/', re.S)


def code(text, strings=False):
    return _TOKENS.sub(lambda m: ' ' * len(m.group()) if strings or m.group().startswith(('//', '/*')) else m.group(), text)


def source(path):
    if not path.is_file():
        pytest.skip(f'In-flight presentation source not yet available: {path.name}')
    return code(path.read_text(encoding='utf-8'))


def compact(text):
    return re.sub(r'\s+', '', text)


def body(text, name):
    masked = code(text, strings=True)
    match = re.search(r'\b' + re.escape(name) + r'\s*\([^;{}]*\)\s*(?:const\s*)?\{', masked)
    assert match, f'Missing function {name}'
    depth = 1
    for index in range(match.end(), len(masked)):
        depth += (masked[index] == '{') - (masked[index] == '}')
        if depth == 0:
            return text[match.end():index]
    raise AssertionError(f'Unbalanced function {name}')


@pytest.mark.parametrize('path', [COMPARE, V1, V2, CHART], ids=['adapter', 'v1', 'v2', 'chart_v2'])
def test_presentation_sources_have_no_trading_or_terminal_lifecycle_mutators(path):
    text = code(source(path), strings=True)
    assert not re.search(r'\b(?:OrderSend(?:Async)?|OrderCheck|Position(?:Open|Close|Modify)\w*|'
                         r'Order(?:Open|Close|Modify|Delete)|Buy(?:Stop|Limit)?|Sell(?:Stop|Limit)?|'
                         r'ChartApplyTemplate|ChartSetSymbolPeriod|ChartOpen|ChartClose|ExpertRemove|'
                         r'TerminalClose|EventChartCustom|GlobalVariableSet(?:OnCondition)?|GlobalVariableDel|'
                         r'GlobalVariablesDeleteAll|ShellExecute\w*|SendMessage\w*|PostMessage\w*|'
                         r'QM_TM_\w*|QM_KillSwitch\w*|QM_Framework(?:Init|Shutdown))\s*\(', text)
    assert not re.search(r'^\s*#\s*import\b|\b(?:CTrade|MqlTradeRequest)\b', text, re.M)


@pytest.mark.parametrize('function', ['OnChartEvent', 'PaintCached', 'StartRenderer', 'StopRenderer',
                                      'RecoverPrevious', 'ShowRecovery', 'HideRecovery', 'RenderFailed'])
def test_ab_event_call_chain_never_refreshes_account_history_quote_or_gate_state(function):
    text = code(body(source(COMPARE), function), strings=True)
    assert not re.search(r'\b(?:AccountInfo\w*|History\w*|Position\w*|Order\w*|SymbolInfo\w*|'
                         r'Copy\w*|TimeCurrent|TimeLocal|TimeGMT|QM_News\w*|QM_Risk\w*|'
                         r'QM_Framework\w*|Populate|Invalidate|Refresh)\s*\(', text)
    assert 'm_data.' not in text


def test_switch_is_guarded_by_exact_namespaced_button_and_reentrancy_guard():
    event = compact(body(source(COMPARE), 'OnChartEvent'))
    assert event.startswith('if(m_busy)return;')
    assert event.index('if(m_recovering)') < event.index('if(!m_ready)return;')
    assert 'if(id==CHARTEVENT_OBJECT_CLICK&&object_name==m_prefix+"design_version")' in event
    assert event.index('m_busy=true;') < event.index('m_mode=Mode();')
    assert event.index('if(!StopRenderer())') < event.index('m_design=m_design==')
    assert event.index('m_design=m_design==') < event.index('m_ready=StartRenderer();')
    assert 'PaintCached();m_busy=false;return;' in event


def test_switch_preserves_exact_cached_snapshot_and_last_observed_quote():
    text = source(COMPARE)
    refresh = compact(body(text, 'Refresh'))
    assert 'm_cached=snapshot;m_has_snapshot=true;' in refresh
    assert len(re.findall(r'\bm_cached\s*=(?!=)', text)) == 1
    event = body(text, 'OnChartEvent')
    assert not re.search(r'\b(?:m_cached(?:\.\w+)?|m_bid|m_bid_text|m_quote_time|m_has_snapshot)\s*=(?!=)', event)
    paint = compact(body(text, 'PaintCached'))
    assert 'm_v1.Render(m_cached);' in paint
    assert 'm_v2.Render(m_cached);' in paint
    assert 'm_chart_v2.Render(m_cached,m_v2.PanelRightPixels(),m_bid,m_bid_text,m_quote_time)' in paint
    assert 'snapshot.Reset(' not in paint and 'QM_ConsoleAdd' not in paint


def test_missing_quotes_are_not_fabricated_and_timestamp_stays_visible():
    refresh = compact(body(source(COMPARE), 'Refresh'))
    assert 'm_bid=0.0;m_bid_text="";m_quote_time="";' in refresh
    assert 'if(SymbolInfoTick(snapshot.symbol,quote)&&quote.bid>0.0&&quote.time>0)' in refresh
    assert 'm_bid=quote.bid;' in refresh
    assert 'm_quote_time=TimeToString(quote.time,TIME_DATE|TIME_SECONDS)+"BT";' in refresh
    render = body(source(CHART), 'Render')
    assert 'observed_text' in render
    assert 'snapshot.symbol==ChartSymbol(m_chart)' in compact(render)


def test_synthetic_entrypoint_never_initializes_or_populates_live_collector():
    text = source(COMPARE)
    presentation = body(text, 'InitializePresentation')
    assert 'm_data.' not in presentation
    assert 'MQL_TESTER' in presentation and 'MQL_OPTIMIZATION' in presentation
    assert compact(body(text, 'Populate')) == 'if(Ready())m_data.Populate(snapshot);'


def test_v2_dashboard_and_chart_have_disjoint_namespaces_for_real_canary_magic():
    start = compact(body(source(COMPARE), 'StartRenderer'))
    assert 'm_v2.Initialize(m_chart,m_prefix,' in start
    match = re.search(r'm_chart_v2\.Initialize\(m_chart,"([^"]+)"\+m_prefix,', start)
    assert match, 'Chart namespace must be explicitly disjoint, not nested inside dashboard prefix'
    with (REPO / 'framework/registry/magic_numbers.csv').open(encoding='utf-8-sig', newline='') as stream:
        rows = [row for row in csv.DictReader(stream)
                if row['ea_id'] == '11421' and row['symbol_slot'] == '0' and row['status'] == 'active']
    assert len(rows) == 1, 'Canary identity must come from one exact registry mapping'
    for dashboard in ('QM_QA_', f'QM_SIG_11421_{rows[0]["magic"]}_'):
        chart = match.group(1) + dashboard
        assert not chart.startswith(dashboard) and not dashboard.startswith(chart)
        limit = re.search(r'StringLen\(prefix\)>(\d+)', compact(body(source(CHART), 'Initialize')))
        assert limit and len(chart) <= int(limit.group(1)), 'Live chart prefix must fit native chart adapter bound'


def test_single_overlay_owner_and_no_native_trade_markers_hidden():
    start = compact(body(source(COMPARE), 'StartRenderer'))
    assert 'm_v2.Initialize(m_chart,m_prefix,true,m_mode,m_scale,false,false,false,false)' in start
    assert 'm_range,m_levels,m_markers,m_strategy,m_apply_theme)' in start
    v2 = source(V2)
    assert not re.search(r'\b(?:OBJ_TREND|OBJ_RECTANGLE|OBJ_ARROW_BUY|OBJ_ARROW_SELL|ObjectMove)\b', code(v2, strings=True))
    properties = body(source(CHART), 'DefineProperties')
    for untouched in ('CHART_SHOW_TRADE_LEVELS', 'CHART_SHOW_TRADE_HISTORY', 'CHART_SCALE', 'CHART_AUTOSCROLL'):
        assert untouched not in properties


def test_failed_theme_restore_keeps_switch_button_and_original_design_for_retry():
    text = source(COMPARE)
    assert re.search(r'\bbool\s+StopRenderer\(', text)
    stop = compact(body(text, 'StopRenderer'))
    guard = stop.index('if(!stopped||m_chart_v2.RestorePending())')
    assert guard < stop.index('returnfalse;') < stop.index('m_v2.Shutdown();')
    assert 'if(!StopRenderer()){m_busy=false;return;}' in compact(body(text, 'OnChartEvent'))
    assert 'if(ok)m_saved=false;' in compact(body(source(CHART), 'Restore'))


def test_failed_target_start_cleans_target_before_restoring_previous_design():
    text = source(COMPARE)
    event = compact(body(text, 'OnChartEvent'))
    assert event.index('constQM_ConsoleDesignprevious=m_design;') < event.index('if(!StopRenderer())')
    failed = event.split('m_ready=StartRenderer();', 1)[1].split('//', 1)[0]
    assert 'if(!m_ready)' in failed
    assert 'm_recovery_design=previous;m_recovering=true;' in failed
    assert 'RecoverPrevious();m_busy=false;return;' in failed
    recover = compact(body(text, 'RecoverPrevious'))
    guard = 'if(!StopRenderer()||!HideRecovery()){ShowRecovery();return;}'
    assert guard in recover
    assert recover.index(guard) < recover.index('m_design=m_recovery_design;') < recover.index('m_ready=StartRenderer();')
    failed_restart = recover.split('if(!m_ready)', 1)[1].split('m_recovering=false;', 1)[0]
    assert failed_restart.index('StopRenderer();') < failed_restart.index('ShowRecovery();return;')
    assert 'm_recovering=false;' in recover and 'PaintCached();' in recover
    assert 'if(m_chart_v2.RestorePending())' in compact(body(text, 'StartRenderer'))


def test_initial_start_failure_preserves_false_result_and_exposes_owned_explicit_retry():
    initialization = compact(body(source(COMPARE), 'InitializePresentation'))
    failed = initialization.split('m_has_snapshot=false;m_ready=StartRenderer();', 1)[1]
    assert failed.startswith('if(!m_ready){')
    assert 'm_recovering=true;m_recovery_design=m_design;' in failed
    assert failed.index('m_recovery_design=m_design;') < failed.index('constboolcleaned=StopRenderer();')
    assert failed.index('StopRenderer();') < failed.index('ShowRecovery();returnfalse;')
    assert 'StartRenderer(' not in failed and 'RecoverPrevious(' not in failed
    assert 'm_ready=true' not in failed and 'm_has_snapshot=true' not in failed
    assert not re.search(r'\bm_design\s*=(?!=)', failed)
    assert failed.endswith('returntrue;')
    assert not re.search(r'\b(?:EventSet\w*|EventKillTimer|Refresh|Populate)\s*\(', initialization)


def test_reinitialization_cannot_replace_initial_failure_cleanup_or_restore_owner():
    initialization = compact(body(source(COMPARE), 'InitializePresentation'))
    guard = 'if(m_ready||m_recovering||m_chart_v2.RestorePending())'
    assert guard in initialization
    assert initialization.index(guard) < initialization.index('HideRecovery()')
    assert initialization.index(guard) < initialization.index('m_chart=chart;')
    assert initialization.index(guard) < initialization.index('m_prefix=prefix;')
    assert initialization.index(guard) < initialization.index('m_design=design==')
    assert 'returnfalse;' in initialization.split(guard, 1)[1].split('HideRecovery()', 1)[0]
    live_source = source(COMPARE).split('bool Initialize(const long chart,const int ea_id', 1)[1]
    live_initialization = compact(body('bool Initialize(const long chart,const int ea_id' + live_source, 'Initialize'))
    assert live_initialization.index(guard) < live_initialization.index('m_data.Initialize(magic);')


@pytest.mark.parametrize('initial_cleanup,retry_cleanup,retry_start', [
    (True, True, True), (False, True, True), (False, False, True),
    (True, True, False), (False, True, False),
])
def test_initial_failure_sequence_waits_for_explicit_click_and_never_loses_owner(
        initial_cleanup, retry_cleanup, retry_start):
    # State model is tied to source order above. Native chart-fault evidence is
    # still required; this is not a simulated MT5 API implementation.
    owner = retained_design = 2
    ready, recovering = False, True
    calls = ['initial_start_failed', 'initial_cleanup', 'show_retry']
    restore_pending = not initial_cleanup
    initialization_result = ready
    for event in ('timer', 'resize', 'refresh'):
        assert not ready and recovering
        assert 'retry_start' not in calls
    assert not initialization_result
    calls.extend(['explicit_click', 'retry_cleanup'])
    if retry_cleanup:
        restore_pending = False
        calls.extend(['hide_retry', 'retry_start'])
        ready = retry_start
        recovering = not ready
        if not ready:
            calls.extend(['cleanup_failed_restart', 'show_retry'])
    else:
        calls.append('show_retry')
    assert owner == retained_design == 2
    assert ('retry_start' in calls) == retry_cleanup
    if 'retry_start' in calls:
        assert calls.index('explicit_click') < calls.index('retry_cleanup') < calls.index('retry_start')
        assert not restore_pending
    if not retry_cleanup or not retry_start:
        assert not ready and recovering


def test_recovery_remains_reachable_while_unready_but_never_auto_retries():
    text = source(COMPARE)
    event = compact(body(text, 'OnChartEvent'))
    recovery = event.split('if(m_recovering)', 1)[1].split('if(!m_ready)return;', 1)[0]
    assert 'id==CHARTEVENT_OBJECT_CLICK&&object_name==RecoveryName()' in recovery
    assert 'id==CHARTEVENT_CLICK' in recovery
    assert 'm_busy=true;RecoverPrevious();m_busy=false;' in recovery
    assert 'CHARTEVENT_CHART_CHANGE' not in recovery and 'Refresh(' not in recovery
    refresh = body(text, 'Refresh')
    assert 'RecoverPrevious(' not in refresh
    for function in ('RecoverPrevious', 'ShowRecovery', 'HideRecovery', 'RenderFailed'):
        pure = body(text, function)
        assert not re.search(r'\b(?:m_cached(?:\.\w+)?|m_bid|m_bid_text|m_quote_time|m_has_snapshot)\s*=(?!=)', pure)


def test_recovery_control_has_separate_exact_ownership_and_checked_cleanup():
    text = source(COMPARE)
    name = compact(body(text, 'RecoveryName'))
    assert name == 'return"QM_RETRY_"+m_prefix;'
    show = compact(body(text, 'ShowRecovery'))
    assert 'ObjectFind(m_chart,name)>=0||!ObjectCreate(m_chart,name,OBJ_BUTTON,0,0,0)' in show
    assert 'clickchartbackgroundtoretrypreviousdesign' in show
    hide = compact(body(text, 'HideRecovery'))
    assert 'ObjectDelete(m_chart,RecoveryName())&&ObjectFind(m_chart,RecoveryName())<0' in hide
    assert 'returnfalse;' in hide and 'ObjectsDeleteAll(' not in hide
    shutdown = compact(body(text, 'Shutdown'))
    assert 'constboolhidden=HideRecovery();' in shutdown
    assert shutdown.index('HideRecovery();') < shutdown.index('m_recovering=false;')


def test_render_failure_is_checked_after_dashboard_and_chart_rendering():
    text = source(COMPARE)
    paint = compact(body(text, 'PaintCached'))
    assert 'm_v1.Render(m_cached);if(!m_v1.Ready())RenderFailed("V1render");' in paint
    assert 'm_v2.Render(m_cached);if(!m_v2.Ready()){RenderFailed("V2render");return;}' in paint
    assert 'if(!m_chart_v2.Render(m_cached,m_v2.PanelRightPixels(),m_bid,m_bid_text,m_quote_time))RenderFailed("chartrender");' in paint
    event = compact(body(text, 'OnChartEvent'))
    assert 'm_v1.OnChartEvent(id,object_name);if(!m_v1.Ready())RenderFailed("V1eventrender");' in event
    assert 'm_v2.OnChartEvent(id,object_name);if(!m_v2.Ready()){RenderFailed("V2eventrender");return;}' in event
    assert 'if(!m_chart_v2.Render(m_cached,m_v2.PanelRightPixels(),m_bid,m_bid_text,m_quote_time))RenderFailed("charteventrender");' in event


def test_render_failure_preserves_cleanup_owner_and_requires_an_explicit_retry():
    text = source(COMPARE)
    failure = compact(body(text, 'RenderFailed'))
    assert 'm_ready=false;m_recovering=true;m_recovery_design=m_design;' in failure
    assert failure.index('StopRenderer();') < failure.index('ShowRecovery();')
    assert 'StartRenderer(' not in failure and 'RecoverPrevious(' not in failure
    assert not re.search(r'\bm_design\s*=(?!=)', body(text, 'RenderFailed'))
    assert 'RecoverPrevious(' not in body(text, 'Refresh')
    recovered = compact(body(text, 'RecoverPrevious'))
    assert recovered.index('m_recovering=false;') < recovered.index('PaintCached();')
    after_paint = recovered.split('PaintCached();', 1)[1]
    assert 'if(m_ready&&!m_recovering)' in after_paint
    assert not re.search(r'\bm_recovering=(?![=])', after_paint)


def test_external_shutdown_reports_incomplete_cleanup_without_lifecycle_side_effects():
    shutdown = compact(body(source(COMPARE), 'Shutdown'))
    assert 'constboolstopped=StopRenderer();' in shutdown
    assert 'constboolhidden=HideRecovery();' in shutdown
    assert 'if(!stopped||!hidden||m_chart_v2.RestorePending())' in shutdown
    assert 'nofurtherretryafterexternaldeinitialization' in shutdown
    assert 'm_recovering=false;m_ready=false;m_has_snapshot=false;' in shutdown


@pytest.mark.parametrize('target_start,target_cleanup,previous_start,previous_cleanup', [
    (True, True, True, True),
    (False, True, True, True),
    (False, False, True, True),
    (False, True, False, True),
    (False, True, False, False),
])
def test_failure_sequence_model_never_starts_previous_over_an_unclean_target(
        target_start, target_cleanup, previous_start, previous_cleanup):
    # Behavior model complements the source-call ordering above; not native
    # fault injection and not a substitute for an actual chart restore receipt.
    calls = ['stop_previous', 'start_target']
    ready, recovering = target_start, not target_start
    if not target_start:
        calls.append('cleanup_target')
        if target_cleanup:
            calls.append('start_previous')
            ready = previous_start
            recovering = not previous_start
            if not previous_start:
                calls.append('cleanup_previous')
                if not previous_cleanup:
                    calls.append('preserve_cleanup_owner')
    assert ('start_previous' in calls) == (not target_start and target_cleanup)
    if not target_start and not target_cleanup:
        assert not ready and recovering and calls[-1] == 'cleanup_target'
    if not target_start and target_cleanup and previous_start:
        assert ready and not recovering
    if not target_start and target_cleanup and not previous_start:
        assert not ready and recovering and 'cleanup_previous' in calls


def test_theme_changes_are_captured_applied_verified_and_restored_in_reverse_order():
    chart = source(CHART)
    init = compact(body(chart, 'Initialize'))
    assert 'if(apply_theme)' in init
    assert init.index('Capture()') < init.index('Apply()')
    # Diagnostics may expand the failure branch, but rollback must still happen
    # before that branch returns failure (never mark the presenter ready).
    rollback = init.split('if(!Apply()){', 1)[1].split('}', 1)[0]
    assert rollback.index('Restore()') < rollback.index('returnfalse;')
    assert 'returntrue;' not in rollback and 'm_ready=true;' not in rollback
    restore = compact(body(chart, 'Restore'))
    assert restore.startswith('if(!m_saved)returntrue;')
    assert 'ChartSetDouble(m_chart,CHART_SHIFT_SIZE,m_shift_before)' in restore
    assert 'for(inti=ArraySize(m_properties)-1;i>=0;--i)' in restore
    assert 'ChartSetInteger(m_chart,m_properties[i].key,m_properties[i].before)' in restore
    assert 'actual!=m_properties[i].before' in restore
    assert 'MathAbs(shift-m_shift_before)>0.000001' in restore


def test_native_chart_owner_does_not_adopt_preexisting_objects_or_delete_by_broad_prefix():
    chart = source(CHART)
    create = compact(body(chart, 'Object'))
    assert 'constboolowned=ExistsIn(m_objects,name);' in create
    assert 'constboolpresent=ObjectFind(m_chart,name)>=0;' in create
    assert 'if(present&&!owned){m_ok=false;returnfalse;}' in create
    assert create.index('if(present&&!owned)') < create.index('if(!present)') < create.index('ObjectCreate(')
    sweep = compact(body(chart, 'Sweep'))
    assert 'ObjectDelete(m_chart,m_objects[i])' in sweep
    assert 'ObjectsDeleteAll(' not in chart


def test_ea_ab_event_only_dispatches_presentation_and_resumes_observer_when_ready():
    ea = source(EA)
    assert '#include <QM/QM_ChartPanelCompare.mqh>' in ea
    assert 'CQMChartPanelCompare g_qm_signature_panel;' in ea
    assert compact(body(ea, 'OnChartEvent')) == (
        'g_qm_signature_panel.OnChartEvent(id,sparam);'
        'if(!g_qm_fw_timer_active&&g_qm_signature_panel.Ready()){'
        'if(EventSetTimer(5))g_qm_fw_timer_active=true;elseg_qm_signature_panel.Shutdown();}'
    )
    event = code(body(ea, 'OnChartEvent'), strings=True)
    assert not re.search(r'\b(?:Refresh|Populate|SymbolInfo\w*|History\w*|AccountInfo\w*|'
                         r'Copy\w*|QM_News\w*|QM_Risk\w*|QM_Framework\w*)\s*\(', event)
    assert 'g_qm_signature_panel' not in body(ea, 'OnTick')


@pytest.mark.parametrize('function', ['SqueezePipFactor', 'Strategy_NoTradeFilter', 'Strategy_EntrySignal',
                                    'Strategy_ManageOpenPosition', 'Strategy_ExitSignal',
                                    'Strategy_NewsFilterHook', 'QM_PendingTTLSeconds', 'OnTick', 'OnTester'])
def test_design_and_display_inputs_never_enter_trading_functions(function):
    trading = body(source(EA), function)
    for name in ('qm_design_version', 'qm_dashboard_mode', 'qm_visual_scale', 'qm_number_locale',
                 'qm_apply_chart_scheme', 'qm_show_chart_panel', 'qm_show_active_range',
                 'qm_show_strategy_levels', 'qm_show_trade_levels', 'qm_show_trade_markers'):
        assert not re.search(r'\b' + name + r'\b', trading), f'{name} leaked into {function}'


def test_ea_shutdown_restores_nested_presentation_before_outer_scheme_and_framework():
    deinit = compact(body(source(EA), 'OnDeinit'))
    assert deinit.index('g_qm_signature_panel.Shutdown();') < deinit.index('QM_ChartScheme_Restore(ChartID());')
    assert deinit.index('QM_ChartScheme_Restore(ChartID());') < deinit.index('QM_FrameworkShutdown();')


def test_real_snapshot_fields_and_alerts_are_not_replaced_for_ab_comparison():
    producer = body(source(EA), 'QM11421_RefreshChartPanel')
    assert 'qm_design_version' not in producer
    assert 'g_qm_signature_panel.Populate(snapshot);' in producer
    assert 'QM11421_ConsoleGateAlerts(snapshot);' in producer
    assert 'g_qm_signature_panel.Refresh(snapshot);' in producer
    for field in ('snapshot.positions', 'snapshot.pending_orders', 'snapshot.exposure',
                  'snapshot.range_high', 'snapshot.range_low', 'snapshot.environment'):
        assert field in producer
    assert 'DESIGN QA' not in producer and 'Synthetic' not in producer
@pytest.mark.parametrize('requested,expected', [(-2147483648, 80), (-1, 80), (0, 80),
                                               (79, 80), (80, 80), (100, 100),
                                               (125, 125), (150, 150), (151, 150),
                                               (2147483647, 150)])
def test_adapter_clamps_one_display_scale_before_any_renderer_starts(requested, expected):
    initialization = compact(body(source(COMPARE), 'InitializePresentation'))
    clamp = 'm_scale=(int)MathMax(80,MathMin(150,scale));'
    assert clamp in initialization
    assert initialization.index(clamp) < initialization.index('StartRenderer()')
    assert max(80, min(150, requested)) == expected
