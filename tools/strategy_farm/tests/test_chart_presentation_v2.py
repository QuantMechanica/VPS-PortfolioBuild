"""Version 2 chart presentation safety contracts; native fixtures test real MQL geometry."""

from pathlib import Path
import re


REPO = Path(__file__).resolve().parents[3]
HEADER = REPO / "framework/include/QM/QM_ChartPresentationV2.mqh"
FIXTURES = REPO / "framework/tests/mql5/QM_ChartPresentationV2_selftests.mqh"
PROBE = REPO / "framework/tests/mql5/QM_ChartPresentationV2_compile_probe.mq5"


def source():
    return HEADER.read_text(encoding="utf-8")


def body(name):
    match = re.search(r"\b" + name + r"\([^;{}]*\)\s*\{", source())
    assert match, name
    depth = 0
    for i in range(match.end() - 1, len(source())):
        depth += (source()[i] == "{") - (source()[i] == "}")
        if not depth:
            return source()[match.end():i]
    raise AssertionError(name)


def test_presentation_has_no_trade_data_or_terminal_operation_calls():
    assert not re.search(
        r"\b(?:Order\w*|Position\w*|History\w*|Account\w*|SymbolInfo\w*|Copy\w*|"
        r"Calendar\w*|ChartSetSymbolPeriod|ChartApplyTemplate|ChartNavigate|"
        r"GlobalVariable\w*|EventSet\w*|EventKillTimer|ExpertRemove)\s*\(", source()
    )
    assert "#include <QM/QM_ConsoleModel.mqh>" in source()
    assert "#include <Trade/" not in source()
    assert "CHART_DRAG_TRADE_LEVELS" not in source()


def test_exact_snapshot_precedes_any_apply_and_restore_uses_same_property_table():
    assert body("Initialize").index("Capture()") < body("Initialize").index("Apply()")
    assert "ChartGetInteger(m_chart,m_properties[i].key,0,m_properties[i].before)" in body("Capture")
    assert "ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,m_shift_before)" in body("Capture")
    assert "ChartSetInteger(m_chart,m_properties[i].key,m_properties[i].target)" in body("Apply")
    assert "ChartSetInteger(m_chart,m_properties[i].key,m_properties[i].before)" in body("Restore")
    assert "ChartSetDouble(m_chart,CHART_SHIFT_SIZE,m_shift_before)" in body("Restore")
    assert "actual!=m_properties[i].before" in body("Restore")
    assert "if(ok) m_saved=false" in body("Restore")
    keys = re.findall(r"Property\((CHART_\w+),", body("DefineProperties"))
    assert len(keys) == len(set(keys)) == 20
    native_tests = FIXTURES.read_text(encoding="utf-8")
    for key in keys:
        assert key in native_tests


def test_optional_theme_respects_existing_switch_without_losing_overlays():
    assert "const bool apply_theme=true" in source()
    assert re.search(r"if\(apply_theme\)\s*\{\s*DefineProperties\(\);\s*if\(!Capture", body("Initialize"))
    assert "m_ready=true" in body("Initialize")
    assert "const bool own_overlays=false" in source()
    assert "if(!m_own_overlays) return" in body("Overlays")
    assert "const bool show_strategy=true" in source()
    assert "if(range && m_show_strategy)" in body("Overlays")
    assert "if(range && m_show_range" in body("Overlays")


def test_missing_foreign_or_invalid_observations_cannot_draw_invented_levels():
    render = body("Render")
    assert 'snapshot.symbol==ChartSymbol(m_chart)' in render
    assert 'same_symbol && QM_ChartV2Price(bid) && bid_text!=""' in render
    assert "if(same_symbol && Endpoint(end))" in render
    overlay = body("Overlays")
    assert "snapshot.active_range && snapshot.range_start>0" in overlay
    assert "snapshot.range_high>snapshot.range_low" in overlay
    assert "exposure.ticket==0 || exposure.symbol!=snapshot.symbol" in overlay
    assert "!QM_ChartV2Price(price) || started<=0 || end<=0" in body("QM_ChartV2LevelSegment")
    assert "DoubleToString" not in source()  # Never guess symbol precision/formatting.
    assert "!QM_ChartV2LabelInView(labels[i].price_y,layout)" in body("QM_ChartV2ArrangeLabels")


def test_collision_leaders_viewport_bounds_and_bounded_work():
    assert "panel_right+24.0*scale" in body("QM_ChartV2Geometry")
    assert "width-(int)MathCeil(76.0*scale)" in body("QM_ChartV2Geometry")
    assert "if(i>=99)" in body("PriceLabel")
    assert "MathMin(ArraySize(snapshot.exposure),32)" in body("Overlays")
    assert 'item.key+"_leader_v"' in body("DrawPriceLabels")
    assert "m_layout.label_left-Px(6)" in body("DrawPriceLabels")
    assert "TextGetSize" in body("TextWidth")
    assert "while(lo<hi)" in body("Fit")


def test_only_owned_objects_are_mutated_or_deleted():
    assert "const bool present=ObjectFind(m_chart,name)>=0" in body("Object")
    assert "if(present && !owned)" in body("Object")
    assert "if(!present)" in body("Object")
    assert "if(!ObjectCreate(m_chart,name,type,0,0,0))" in body("Object")
    assert "ExistsIn(m_objects,name)" in body("Object")
    assert "ObjectDelete(m_chart,m_objects[i])" in body("Sweep")
    assert "ObjectsDeleteAll" not in source()
    assert "const bool objects_ok=Sweep(true)" in body("Shutdown")
    assert "const bool restored=Restore()" in body("Shutdown")
    assert 'StringLen(prefix)>35' in body("Initialize")
    assert 'const string key="t"+(string)i' in body("Overlays")
    assert 35 + len("t31_entry_label_leader_v") <= 63


def test_native_fixture_coverage_and_safe_default_probe():
    fixtures = FIXTURES.read_text(encoding="utf-8")
    for name in (
        "wide_chart_reserves_panel_axis_and_labels", "narrow_chart_hides_annotations",
        "short_high_dpi_chart_hides_annotations", "dpi_geometry_scales_consistently",
        "equal_price_labels_never_overlap", "offscreen_prices_are_never_pinned_to_edges",
        "zero_negative_missing_levels_are_hidden", "nan_level_rejected",
        "empty_observation_draws_no_bid_and_restores", "theme_disabled_never_writes_chart_properties",
        "manually_deleted_owned_object_recovers", "foreign_symbol_quote_is_not_drawn",
    ):
        assert name in fixtures
    probe = PROBE.read_text(encoding="utf-8")
    assert "input bool qm_verify_chart_roundtrip=false" in probe
    assert "if(passed && qm_verify_chart_roundtrip)" in probe
    assert "OnTick" not in probe and "OnInit" not in probe


def test_failed_initialization_diagnostics_preserve_exact_restore_verification():
    assert "property=%s expected=%s actual=%s error=%d" in body("Diagnostic")
    for stage in ("CAPTURE_GET", "APPLY_SET", "APPLY_VERIFY", "RESTORE_SET", "RESTORE_VERIFY",
                  "INITIALIZE_GUARD", "INITIALIZE_APPLY_FAILED"):
        assert '"' + stage + '"' in source()
    assert "MathAbs(shift-20.0)>0.000001" in body("Apply")
    assert "MathAbs(shift-m_shift_before)>0.000001" in body("Restore")
    assert "const int error=GetLastError()" in body("Apply")
    assert "const int error=GetLastError()" in body("Restore")
    assert "ResetLastError()" in body("Capture")


def test_native_shift_acceptance_is_geometry_bounded_and_stable():
    helper = body("QM_ChartV2ShiftMatches")
    assert "MathAbs(actual-expected)*chart_width/100.0" in helper
    assert "error_px<=bar_step_px+0.000001" in helper
    assert "bar_step_px<=0.0 || bar_step_px>chart_width" in helper
    apply = body("Apply")
    assert "ChartGetInteger(m_chart,CHART_WIDTH_IN_PIXELS,0,width)" in apply
    assert "ChartGetInteger(m_chart,CHART_WIDTH_IN_BARS,0,bars)" in apply
    assert "const double step=bars>1?(double)width/(double)bars:0.0" in apply
    assert "QM_ChartV2ShiftMatches(20.0,shift,(int)width,step)" in apply
    assert "ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,persisted)" in apply
    assert "MathAbs(persisted-shift)>0.000001" in apply
    assert '"APPLY_NORMALIZED"' in apply
    assert "QM_ChartV2ShiftMatches" not in body("Restore")
    assert "CHART_WIDTH_IN_BARS" not in body("DefineProperties")
    fixtures = FIXTURES.read_text(encoding="utf-8")
    for name in ("observed_native_shift_normalization_accepted", "one_bar_boundary_accepted_both_directions",
                 "over_one_bar_rejected_both_directions", "tolerance_tracks_real_raster_not_fixed_percent",
                 "missing_or_impossible_shift_geometry_rejected", "invalid_shift_values_are_never_normalization"):
        assert name in fixtures


def test_capture_brackets_complete_snapshot_with_valid_stable_raster_and_shift():
    capture = body("Capture")
    assert capture.index("ChartRedraw(m_chart)") < capture.index('ReadRaster(first,"CAPTURE_RASTER")')
    assert capture.index('ReadRaster(first,"CAPTURE_RASTER")') < capture.index("m_properties[i].before")
    assert capture.index("ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,persisted)") < capture.index('ReadRaster(second,"CAPTURE_RASTER")')
    assert capture.index("QM_ChartV2CaptureStable(first,second,m_shift_before,persisted)") < capture.index("m_raster_before=first") < capture.index("m_saved=true")
    assert '"CAPTURE_UNSTABLE"' in capture
    raster = body("ReadRaster")
    for key, field in (("CHART_WIDTH_IN_PIXELS", "width"), ("CHART_WIDTH_IN_BARS", "bars"), ("CHART_SCALE", "scale")):
        assert f"ChartGetInteger(m_chart,{key},0,raster.{field})" in raster
    assert "QM_ChartV2RasterValid(raster)" in raster
    assert "raster.width>0 && raster.width<=2147483647" in body("QM_ChartV2RasterValid")
    assert "raster.bars>1 && raster.bars<=2147483647" in body("QM_ChartV2RasterValid")
    assert "raster.scale>=0 && raster.scale<=5" in body("QM_ChartV2RasterValid")
    stable = body("QM_ChartV2CaptureStable")
    assert "QM_ChartV2RasterEqual(first,second)" in stable
    assert "MathAbs(shift-persisted)<=0.000001" in stable


def test_restore_policy_is_exact_on_original_raster_and_bounded_only_after_change():
    policy = body("QM_ChartV2ShiftRestorePolicy")
    assert policy.index("QM_ChartV2CaptureStable") < policy.index("QM_CHART_V2_RESTORE_EXACT")
    assert "if(MathAbs(actual-expected)<=0.000001) return QM_CHART_V2_RESTORE_EXACT" in policy
    assert "if(QM_ChartV2RasterEqual(captured,first)) return QM_CHART_V2_RESTORE_REJECT" in policy
    assert policy.index("QM_ChartV2RasterEqual(captured,first)") < policy.index("QM_ChartV2ShiftMatches")
    assert "const double step=(double)first.width/(double)first.bars" in policy
    assert "QM_ChartV2ShiftMatches(expected,actual,(int)first.width,step)" in policy
    assert "CHART_VISIBLE_BARS" not in policy
    assert "stable raster change" in source() and "not an undocumented guarantee" in source()


def test_restore_verifies_two_readbacks_without_losing_original_intent_on_retry():
    restore = body("Restore")
    assert restore.index('ReadRaster(first,"RESTORE_RASTER")') < restore.index("ChartSetDouble(m_chart,CHART_SHIFT_SIZE,m_shift_before)")
    assert restore.index("actual!=m_properties[i].before") < restore.index("ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,shift)")
    assert restore.index("ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,persisted)") < restore.index('ReadRaster(second,"RESTORE_RASTER")')
    assert "QM_ChartV2ShiftRestorePolicy(m_shift_before,shift,persisted,m_raster_before,first,second)" in restore
    assert "!read_shift || !read_persisted || !read_first || !read_second || result==QM_CHART_V2_RESTORE_REJECT" in restore
    assert '"RESTORE_NORMALIZED"' in restore and "else if(ok && result==QM_CHART_V2_RESTORE_NORMALIZED)" in restore
    assert "RasterText(m_raster_before)" in restore and "RasterText(second)" in restore
    assert not re.search(r"m_(?:shift_before|raster_before)\s*=", restore)
    assert "if(ok) m_saved=false" in restore
    assert "bool ok=read_first" in restore
    assert not re.search(r"ChartSet(?:Integer|Double)\([^;]*CHART_(?:SCALE|AUTOSCROLL|WIDTH_IN_BARS|WIDTH_IN_PIXELS)", source())


def test_native_raster_policy_fixtures_cover_same_changed_invalid_unstable_and_bounds():
    fixtures = FIXTURES.read_text(encoding="utf-8")
    assert "if(!QM_ChartV2RasterSelfTest(failure)) return false" in fixtures
    for name in (
        "stable_valid_capture_is_accepted", "capture_rejects_raster_or_shift_in_flight",
        "capture_rejects_scale_change_before_capacity_settles",
        "capture_rejects_capacity_change_with_same_width_and_scale",
        "same_raster_restores_exactly_at_float_epsilon", "same_raster_never_receives_one_bar_tolerance",
        "changed_raster_exact_result_is_not_claimed_normalized", "logged_shift_values_need_changed_stable_raster_proof",
        "documented_shift_endpoints_restore_exactly",
        "logged_values_alone_do_not_prove_raster_change", "stable_width_only_change_can_normalize",
        "restore_one_current_bar_boundary_both_directions", "restore_over_current_bar_rejected_not_old_bar_bound",
        "stable_scale_change_is_observation_not_user_causality", "restore_unstable_raster_rejected_even_for_exact_shift",
        "restore_second_shift_read_must_persist", "invalid_capture_or_restore_raster_rejected",
        "restore_nonfinite_or_out_of_documented_shift_range_rejected", "restore_policy_never_mutates_captured_raster",
    ):
        assert name in fixtures


def test_optional_native_zoom_fixture_is_explicit_qa_only_and_cleans_all_paths():
    fixtures = FIXTURES.read_text(encoding="utf-8")
    fixture = fixtures[fixtures.index("bool QM_ChartPresentationV2ZoomSelfTest("):]
    assert "const bool disposable_qa_confirmed=false" in fixture
    assert "if(!disposable_qa_confirmed)" in fixture
    assert "zoom_fixture_requires_disposable_qa_confirmation" in fixture
    mutated = fixture[fixture.index("bool ok=presenter.Initialize"):]
    assert "return false" not in mutated
    assert "presenter.Render" not in fixture and "ObjectCreate" not in fixture
    assert "ChartSetInteger(chart,CHART_SCALE,target_scale)" in fixture
    assert "changed_again.scale!=target_scale" in fixture
    assert fixture.index("ChartSetInteger(chart,CHART_SCALE,captured.scale)") < fixture.rindex("presenter.Shutdown(false)")
    assert "ChartSetDouble(chart,CHART_SHIFT_SIZE,shift_before)" in fixture
    assert "ChartSetInteger(chart,keys[i],before[i])" in fixture
    assert "MathAbs(cleaned_shift-shift_before)>0.000001" in fixture
    assert "QM_ChartV2RasterEqual(captured,cleaned)" in fixture
    assert "zoom_fixture_cleanup_incomplete" in fixture and "cleanup=%d" in fixture
    probe = PROBE.read_text(encoding="utf-8")
    assert "input bool qm_verify_zoom_roundtrip=false" in probe
    assert "if(passed && qm_verify_zoom_roundtrip)" in probe
    assert "QM_ChartPresentationV2ZoomSelfTest(ChartID(),failure,true)" in probe


def test_qa_zoom_wait_has_one_bounded_budget_and_no_production_side_effects():
    fixtures = FIXTURES.read_text(encoding="utf-8")
    settle = fixtures.split("bool QM_ChartV2FixtureSettleRaster(", 1)[1].split("// TEST-ONLY zoom mutation", 1)[0]
    assert "while(GetTickCount64()<deadline && samples<51)" in settle
    assert "if(GetTickCount64()>deadline) break" in settle
    assert "if(now>=deadline || deadline-now<20) break" in settle
    assert re.findall(r"Sleep\((\d+)\)", settle) == ["20"]
    assert "observed_at-previous_at" in settle and "read && have_previous" in settle
    assert "QM_ChartV2FixtureSettlePair(previous,current,baseline,target_scale" in settle
    assert "ChartSet" not in settle and "presenter.Shutdown" not in settle
    assert "first_read=%d first_error=%d last_read=%d last_error=%d" in settle
    assert '" first="' in settle and '" previous="' in settle and '" current="' in settle
    assert "QM_CHART_V2_QA_SETTLE" in settle
    fixture = fixtures.split("bool QM_ChartPresentationV2ZoomSelfTest(", 1)[1]
    assert "const ulong settle_deadline=GetTickCount64()+1000" in fixture
    assert "QM_ChartV2FixtureSettleRaster(chart,captured,target_scale,true,settle_deadline-200,changed,settle_detail)" in fixture
    assert "QM_ChartV2FixtureSettleRaster(chart,captured,captured.scale,false,settle_deadline,cleaned,cleanup_detail)" in fixture
    assert "zoom_fixture_changed_raster_unstable: " in fixture
    assert "zoom_fixture_cleanup_incomplete: " in fixture
    assert "Sleep(" not in source() and "FixtureSettle" not in source()


def test_qa_settle_never_accepts_only_a_new_scale_flag_or_weakens_cleanup():
    fixtures = FIXTURES.read_text(encoding="utf-8")
    pair = fixtures.split("bool QM_ChartV2FixtureSettlePair(", 1)[1].split("// Pure policy fixtures", 1)[0]
    assert "elapsed_ms<20" in pair
    assert "!QM_ChartV2RasterEqual(previous,current) || current.scale!=target_scale" in pair
    assert "if(!require_changed) return QM_ChartV2RasterEqual(baseline,current)" in pair
    assert "current.width!=baseline.width || target_scale==baseline.scale" in pair
    assert "target_scale>baseline.scale?current.bars<baseline.bars:current.bars>baseline.bars" in pair
    for name in (
        "qa_settle_requires_time_separated_identical_target_raster",
        "qa_settle_rejects_wrong_target_or_unchanged_baseline",
        "qa_settle_rejects_new_scale_flag_with_old_bar_capacity",
        "qa_zoom_fixture_rejects_concurrent_width_change",
        "qa_settle_accepts_both_zoom_directions_after_capacity_settles",
        "qa_settle_rejects_moving_or_invalid_raster",
        "qa_cleanup_settle_requires_exact_original_raster",
    ):
        assert name in fixtures


def test_price_labels_are_queued_and_order_preserving_with_explicit_omissions():
    assert "m_labels[i].price_y=y" in body("PriceLabel")
    assert "Box(" not in body("PriceLabel")
    render = body("Render")
    assert render.index("Overlays(snapshot,end)") < render.index("DrawPriceLabels()")
    layout = body("QM_ChartV2ArrangeLabels")
    assert "labels[selected[j]].priority>labels[value].priority" in layout
    assert "QM_ChartV2LabelBefore(labels[value],labels[selected[j]])" in layout
    assert "labels[index].placed=(int)MathMax(next" in layout
    assert "labels[index].placed=(int)MathMin(labels[index].placed,limit)" in layout
    assert "return visible-keep" in layout
    assert '" labels omitted"' in body("QM_ChartV2LevelNotice")
    assert "QM_ChartV2LevelNotice(m_label_omitted,m_label_offscreen)" in body("DrawPriceLabels")
    assert "m_layout.bottom+Px(6)" in body("DrawPriceLabels")
    assert "item.price_y" in body("DrawPriceLabels")
    fixtures = FIXTURES.read_text(encoding="utf-8")
    for name in ("cluster_preserves_tp_trigger_range_bid_range_sl_order", "packed_cluster_inside_bounds_no_overlap",
                 "bottom_cluster_two_pass_fits", "overflow_retains_sl_entry_tp_before_bid_range",
                 "offscreen_critical_label_never_consumes_visible_capacity", "same_pixel_uses_true_price_order"):
        assert name in fixtures


def test_reverse_equal_level_times_do_not_invent_future_dates():
    helper = body("QM_ChartV2LevelSegment")
    assert "from=started<end?started:end; to=started>end?started:end" in helper
    assert "return started==end?0:1" in helper
    level = body("Level")
    assert "if(segment<0) return" in level
    assert "if(segment>0 && Object(key,OBJ_TREND))" in level
    assert "PriceLabel(" in level
    assert "end<=started" not in level
    fixtures = FIXTURES.read_text(encoding="utf-8")
    for name in ("forward_level_uses_only_observed_times", "reverse_endpoint_preserves_real_level",
                 "equal_endpoint_keeps_label_without_fake_dated_line", "missing_time_or_price_remains_hidden"):
        assert name in fixtures


def test_offscreen_levels_are_counted_without_edge_pinning_and_cleared_each_frame():
    label = body("PriceLabel")
    assert "if(!QM_ChartV2LabelInView(y,m_layout))" in label
    assert "++m_label_offscreen" in label and "m_offscreen_labels+=label" in label
    assert label.index("++m_label_offscreen") < label.index("const int i=ArraySize(m_labels)")
    assert "MathMin" not in label and "MathMax" not in label
    render = body("Render")
    assert 'm_label_omitted=0; m_label_offscreen=0; m_offscreen_labels=""' in render
    draw = body("DrawPriceLabels")
    assert 'Text("level_notice",notice' in draw
    assert 'S("level_notice",OBJPROP_TOOLTIP,detail)' in draw
    assert "including reserved header/axis margins" in draw
    assert "m_offscreen_labels" in draw
    fixtures = FIXTURES.read_text(encoding="utf-8")
    for name in ("outside_view_classification_has_exact_plot_bounds", "offscreen_only_notice_is_explicit",
                 "capacity_and_offscreen_notices_are_distinct"):
        assert name in fixtures
