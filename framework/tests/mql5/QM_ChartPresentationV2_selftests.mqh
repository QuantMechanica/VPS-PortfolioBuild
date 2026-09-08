#ifndef QM_CHARTPRESENTATIONV2_SELFTESTS_MQH
#define QM_CHARTPRESENTATIONV2_SELFTESTS_MQH

#include <QM/QM_ChartPresentationV2.mqh>

bool QM_ChartV2Expect(const bool condition,const string name,string &failure)
  { if(condition) return true; failure=name; return false; }

void QM_ChartV2FixtureLabel(QM_ChartV2LabelCandidate &labels[],const string key,const int y,const int priority=3,const double price=1.0)
  {
   const int i=ArraySize(labels); ArrayResize(labels,i+1);
   labels[i].key=key; labels[i].label=key; labels[i].price_y=y; labels[i].priority=priority;
   labels[i].price=price; labels[i].placed=-1; labels[i].tint=QM_COLOR_INK; labels[i].fill=QM_COLOR_SURFACE;
  }

// QA-only settling rule. Two valid, equal observations must be time-separated;
// neither a requested scale value alone nor two immediate reads prove layout
// completion. Cleanup additionally requires the exact original geometry.
bool QM_ChartV2FixtureSettlePair(const QM_ChartV2Raster &previous,const QM_ChartV2Raster &current,
                               const QM_ChartV2Raster &baseline,const long target_scale,
                               const bool require_changed,const ulong elapsed_ms)
  {
   if(elapsed_ms<20 || !QM_ChartV2RasterValid(previous) || !QM_ChartV2RasterValid(current) ||
      !QM_ChartV2RasterValid(baseline) || !QM_ChartV2RasterEqual(previous,current) || current.scale!=target_scale) return false;
   if(!require_changed) return QM_ChartV2RasterEqual(baseline,current);
   // This fixture changes zoom only, never width. Also require full bar
   // capacity to move in the zoom direction: a new CHART_SCALE flag with the
   // previous capacity can still be an unfinished native layout observation.
   // mql5.com/en/book/applications/charts/charts_scale_time (scale 4 -> 3 example).
   if(current.width!=baseline.width || target_scale==baseline.scale) return false;
   return target_scale>baseline.scale?current.bars<baseline.bars:current.bars>baseline.bars;
  }

// Pure policy fixtures, including the logged shift values. Raster sizes below
// are synthetic: the old failure log did not record its original/current tuple.
bool QM_ChartV2RasterSelfTest(string &failure)
  {
   QM_ChartV2Raster captured,changed,unstable,invalid;
   captured.width=1000; captured.bars=125; captured.scale=3;
   changed=captured; changed.width=1200; changed.bars=150;
   if(!QM_ChartV2Expect(QM_ChartV2CaptureStable(captured,captured,20.0,20.0),
      "stable_valid_capture_is_accepted",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2CaptureStable(captured,changed,20.0,20.0) &&
      !QM_ChartV2CaptureStable(captured,captured,20.0,20.000002),
      "capture_rejects_raster_or_shift_in_flight",failure)) return false;
   unstable=captured; unstable.scale=4;
   if(!QM_ChartV2Expect(!QM_ChartV2CaptureStable(captured,unstable,20.0,20.0),
      "capture_rejects_scale_change_before_capacity_settles",failure)) return false;
   unstable=captured; unstable.bars=126;
   if(!QM_ChartV2Expect(!QM_ChartV2CaptureStable(captured,unstable,20.0,20.0),
      "capture_rejects_capacity_change_with_same_width_and_scale",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.0,20.0,captured,captured,captured)==QM_CHART_V2_RESTORE_EXACT &&
      QM_ChartV2ShiftRestorePolicy(20.0,20.0000005,20.0000005,captured,captured,captured)==QM_CHART_V2_RESTORE_EXACT,
      "same_raster_restores_exactly_at_float_epsilon",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.000002,20.000002,captured,captured,captured)==QM_CHART_V2_RESTORE_REJECT &&
      QM_ChartV2ShiftRestorePolicy(20.0,20.5,20.5,captured,captured,captured)==QM_CHART_V2_RESTORE_REJECT,
      "same_raster_never_receives_one_bar_tolerance",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.0,20.0,captured,changed,changed)==QM_CHART_V2_RESTORE_EXACT,
      "changed_raster_exact_result_is_not_claimed_normalized",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(10.0,10.0,10.0,captured,changed,changed)==QM_CHART_V2_RESTORE_EXACT &&
      QM_ChartV2ShiftRestorePolicy(50.0,50.0,50.0,captured,changed,changed)==QM_CHART_V2_RESTORE_EXACT,
      "documented_shift_endpoints_restore_exactly",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(19.1919191919191974,19.1011235955056122,19.1011235955056122,
      captured,changed,changed)==QM_CHART_V2_RESTORE_NORMALIZED,
      "logged_shift_values_need_changed_stable_raster_proof",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(19.1919191919191974,19.1011235955056122,19.1011235955056122,
      captured,captured,captured)==QM_CHART_V2_RESTORE_REJECT,
      "logged_values_alone_do_not_prove_raster_change",failure)) return false;
   changed=captured; changed.width=999;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.5,20.5,captured,changed,changed)==QM_CHART_V2_RESTORE_NORMALIZED,
      "stable_width_only_change_can_normalize",failure)) return false;
   changed=captured; changed.bars=250;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.4,20.4,captured,changed,changed)==QM_CHART_V2_RESTORE_NORMALIZED &&
      QM_ChartV2ShiftRestorePolicy(20.0,19.6,19.6,captured,changed,changed)==QM_CHART_V2_RESTORE_NORMALIZED,
      "restore_one_current_bar_boundary_both_directions",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.4001,20.4001,captured,changed,changed)==QM_CHART_V2_RESTORE_REJECT &&
      QM_ChartV2ShiftRestorePolicy(20.0,19.5999,19.5999,captured,changed,changed)==QM_CHART_V2_RESTORE_REJECT,
      "restore_over_current_bar_rejected_not_old_bar_bound",failure)) return false;
   changed=captured; changed.scale=4;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.5,20.5,captured,changed,changed)==QM_CHART_V2_RESTORE_NORMALIZED,
      "stable_scale_change_is_observation_not_user_causality",failure)) return false;
   unstable=changed; unstable.bars=250;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.0,20.0,captured,changed,unstable)==QM_CHART_V2_RESTORE_REJECT &&
      QM_ChartV2ShiftRestorePolicy(20.0,20.1,20.1,captured,changed,unstable)==QM_CHART_V2_RESTORE_REJECT,
      "restore_unstable_raster_rejected_even_for_exact_shift",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(20.0,20.1,20.100002,captured,changed,changed)==QM_CHART_V2_RESTORE_REJECT,
      "restore_second_shift_read_must_persist",failure)) return false;
   for(int i=0;i<7;++i)
     {
      invalid=captured;
      if(i==0) invalid.width=0;
      if(i==1) invalid.width=2147483648;
      if(i==2) invalid.bars=1;
      if(i==3) invalid.bars=2147483648;
      if(i==4) invalid.scale=-1;
      if(i==5) invalid.scale=6;
      if(i==6) invalid.bars=-1;
      if(!QM_ChartV2Expect(!QM_ChartV2CaptureStable(invalid,invalid,20.0,20.0) &&
         QM_ChartV2ShiftRestorePolicy(20.0,20.0,20.0,invalid,changed,changed)==QM_CHART_V2_RESTORE_REJECT &&
         QM_ChartV2ShiftRestorePolicy(20.0,20.0,20.0,captured,invalid,invalid)==QM_CHART_V2_RESTORE_REJECT,
         "invalid_capture_or_restore_raster_rejected",failure)) return false;
     }
   const double nan=MathArcsin(2.0);
   if(!QM_ChartV2Expect(QM_ChartV2ShiftRestorePolicy(nan,20.0,20.0,captured,changed,changed)==QM_CHART_V2_RESTORE_REJECT &&
      QM_ChartV2ShiftRestorePolicy(20.0,nan,20.0,captured,changed,changed)==QM_CHART_V2_RESTORE_REJECT &&
      QM_ChartV2ShiftRestorePolicy(20.0,20.0,nan,captured,changed,changed)==QM_CHART_V2_RESTORE_REJECT &&
      QM_ChartV2ShiftRestorePolicy(9.999,10.0,10.0,captured,changed,changed)==QM_CHART_V2_RESTORE_REJECT &&
      QM_ChartV2ShiftRestorePolicy(50.0,50.001,50.001,captured,changed,changed)==QM_CHART_V2_RESTORE_REJECT,
      "restore_nonfinite_or_out_of_documented_shift_range_rejected",failure)) return false;
   if(!QM_ChartV2Expect(captured.width==1000 && captured.bars==125 && captured.scale==3,
      "restore_policy_never_mutates_captured_raster",failure)) return false;
   changed=captured; changed.scale=4; changed.bars=63;
   if(!QM_ChartV2Expect(QM_ChartV2FixtureSettlePair(changed,changed,captured,4,true,20) &&
      !QM_ChartV2FixtureSettlePair(changed,changed,captured,4,true,0) &&
      !QM_ChartV2FixtureSettlePair(changed,changed,captured,4,true,19),
      "qa_settle_requires_time_separated_identical_target_raster",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2FixtureSettlePair(changed,changed,captured,5,true,20) &&
      !QM_ChartV2FixtureSettlePair(captured,captured,captured,3,true,20),
      "qa_settle_rejects_wrong_target_or_unchanged_baseline",failure)) return false;
   unstable=captured; unstable.scale=4;
   if(!QM_ChartV2Expect(!QM_ChartV2FixtureSettlePair(unstable,unstable,captured,4,true,20),
      "qa_settle_rejects_new_scale_flag_with_old_bar_capacity",failure)) return false;
   unstable=changed; unstable.width=999;
   if(!QM_ChartV2Expect(!QM_ChartV2FixtureSettlePair(unstable,unstable,captured,4,true,20),
      "qa_zoom_fixture_rejects_concurrent_width_change",failure)) return false;
   unstable=captured; unstable.scale=2; unstable.bars=250;
   if(!QM_ChartV2Expect(QM_ChartV2FixtureSettlePair(unstable,unstable,captured,2,true,20),
      "qa_settle_accepts_both_zoom_directions_after_capacity_settles",failure)) return false;
   unstable=changed; unstable.bars=64;
   invalid=changed; invalid.width=0;
   if(!QM_ChartV2Expect(!QM_ChartV2FixtureSettlePair(changed,unstable,captured,4,true,20) &&
      !QM_ChartV2FixtureSettlePair(invalid,invalid,captured,4,true,20),
      "qa_settle_rejects_moving_or_invalid_raster",failure)) return false;
   unstable=captured; unstable.width=999;
   if(!QM_ChartV2Expect(QM_ChartV2FixtureSettlePair(captured,captured,captured,3,false,20) &&
      !QM_ChartV2FixtureSettlePair(unstable,unstable,captured,3,false,20),
      "qa_cleanup_settle_requires_exact_original_raster",failure)) return false;
   return true;
  }

// Pure tests: no chart, account, quote or history state is accessed.
bool QM_ChartPresentationV2SelfTest(string &failure)
  {
   failure="";
   if(!QM_ChartV2RasterSelfTest(failure)) return false;
   QM_ChartV2Layout layout;
   QM_ChartV2LabelCandidate labels[];
   if(!QM_ChartV2Expect(QM_ChartV2Geometry(1920,1080,480,1.0,layout) &&
      layout.left>480 && layout.label_left>layout.left && layout.right<1920 && layout.bottom<1080,
      "wide_chart_reserves_panel_axis_and_labels",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2Geometry(700,400,480,1.0,layout),"narrow_chart_hides_annotations",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2Geometry(1600,180,480,2.0,layout),"short_high_dpi_chart_hides_annotations",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2Geometry(1600,900,-1,1.0,layout),"negative_panel_bound_rejected",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2Geometry(1600,900,400,0.0,layout),"invalid_scale_rejected",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2Geometry(3840,2160,960,2.0,layout) && layout.label_height==44,
      "dpi_geometry_scales_consistently",failure)) return false;
   QM_ChartV2Geometry(1920,1080,480,1.0,layout);
   QM_ChartV2FixtureLabel(labels,"first",200);
   if(!QM_ChartV2Expect(QM_ChartV2ArrangeLabels(labels,layout)==0 && labels[0].placed==200-layout.label_height/2,
      "single_label_centers_on_real_price",failure)) return false;
   QM_ChartV2FixtureLabel(labels,"second",200);
   if(!QM_ChartV2Expect(QM_ChartV2ArrangeLabels(labels,layout)==0 && labels[0].placed>=layout.top &&
      labels[1].placed-labels[0].placed>=layout.label_height+4,
      "equal_price_labels_never_overlap",failure)) return false;
   QM_ChartV2FixtureLabel(labels,"offscreen_high",layout.top-1,0);
   QM_ChartV2FixtureLabel(labels,"offscreen_low",layout.bottom+1,0);
   if(!QM_ChartV2Expect(QM_ChartV2ArrangeLabels(labels,layout)==0 && labels[2].placed==-1 && labels[3].placed==-1,
      "offscreen_prices_are_never_pinned_to_edges",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2LabelInView(layout.top-1,layout) && !QM_ChartV2LabelInView(layout.bottom+1,layout) &&
      QM_ChartV2LabelInView(layout.top,layout) && QM_ChartV2LabelInView(layout.bottom,layout),
      "outside_view_classification_has_exact_plot_bounds",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2LevelNotice(0,0)=="" && QM_ChartV2LevelNotice(0,1)=="1 level outside view" &&
      QM_ChartV2LevelNotice(0,2)=="2 levels outside view", "offscreen_only_notice_is_explicit",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2LevelNotice(3,0)=="3 labels omitted" &&
      QM_ChartV2LevelNotice(3,2)=="3 omitted / 2 outside view", "capacity_and_offscreen_notices_are_distinct",failure)) return false;
   ArrayResize(labels,0); layout.top=68; layout.bottom=236; // Six labels in 168 px.
   QM_ChartV2FixtureLabel(labels,"bid",165,3);
   QM_ChartV2FixtureLabel(labels,"trigger",150,1);
   QM_ChartV2FixtureLabel(labels,"sl",176,0);
   QM_ChartV2FixtureLabel(labels,"tp",140,2);
   QM_ChartV2FixtureLabel(labels,"range_high",152,4);
   QM_ChartV2FixtureLabel(labels,"range_low",173,4);
   if(!QM_ChartV2Expect(QM_ChartV2ArrangeLabels(labels,layout)==0 &&
      labels[3].placed<labels[1].placed && labels[1].placed<labels[4].placed &&
      labels[4].placed<labels[0].placed && labels[0].placed<labels[5].placed && labels[5].placed<labels[2].placed,
      "cluster_preserves_tp_trigger_range_bid_range_sl_order",failure)) return false;
   int order[]={3,1,4,0,5,2};
   for(int i=0;i<ArraySize(order);++i)
     {
      const int placed=labels[order[i]].placed;
      if(!QM_ChartV2Expect(placed>=layout.top && placed+layout.label_height<=layout.bottom &&
         (i==0 || placed-labels[order[i-1]].placed>=layout.label_height+4),"packed_cluster_inside_bounds_no_overlap",failure)) return false;
     }
   for(int i=0;i<ArraySize(labels);++i) labels[i].price_y=layout.bottom-1;
   if(!QM_ChartV2Expect(QM_ChartV2ArrangeLabels(labels,layout)==0,"bottom_cluster_two_pass_fits",failure)) return false;
   for(int i=0;i<ArraySize(labels);++i)
      if(!QM_ChartV2Expect(labels[i].placed>=layout.top && labels[i].placed+layout.label_height<=layout.bottom,
         "bottom_correction_never_pushes_labels_above_plot",failure)) return false;
   layout.bottom=142; // Only three rows fit. Priority is separate from price order.
   for(int i=0;i<ArraySize(labels);++i) labels[i].price_y=100+i;
   if(!QM_ChartV2Expect(QM_ChartV2ArrangeLabels(labels,layout)==3 && labels[2].placed>=0 && labels[1].placed>=0 && labels[3].placed>=0 &&
      labels[0].placed==-1 && labels[4].placed==-1 && labels[5].placed==-1,"overflow_retains_sl_entry_tp_before_bid_range",failure)) return false;
   labels[2].price_y=layout.top-1;
   if(!QM_ChartV2Expect(QM_ChartV2ArrangeLabels(labels,layout)==2 && labels[2].placed==-1 && labels[0].placed>=0,
      "offscreen_critical_label_never_consumes_visible_capacity",failure)) return false;
   ArrayResize(labels,0);
   QM_ChartV2FixtureLabel(labels,"lower",100,0,1.1);
   QM_ChartV2FixtureLabel(labels,"higher",100,3,1.2);
   if(!QM_ChartV2Expect(QM_ChartV2ArrangeLabels(labels,layout)==0 && labels[1].placed<labels[0].placed,
      "same_pixel_uses_true_price_order",failure)) return false;
   datetime from=0,to=0;
   if(!QM_ChartV2Expect(QM_ChartV2LevelSegment(100,200,1.1,from,to)==1 && from==100 && to==200,
      "forward_level_uses_only_observed_times",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2LevelSegment(200,100,1.1,from,to)==1 && from==100 && to==200,
      "reverse_endpoint_preserves_real_level",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2LevelSegment(100,100,1.1,from,to)==0 && from==100 && to==100,
      "equal_endpoint_keeps_label_without_fake_dated_line",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2LevelSegment(0,100,1.1,from,to)==-1 && QM_ChartV2LevelSegment(100,200,0.0,from,to)==-1,
      "missing_time_or_price_remains_hidden",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2Price(0.0) && !QM_ChartV2Price(-1.0) && QM_ChartV2Price(1.23456),
      "zero_negative_missing_levels_are_hidden",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2Price(MathArcsin(2.0)),"nan_level_rejected",failure)) return false;
   // Observed FTMO result, using a deliberately tight 2 px fixture raster.
   if(!QM_ChartV2Expect(QM_ChartV2ShiftMatches(20.0,19.8653198653198615,1187,2.0),
      "observed_native_shift_normalization_accepted",failure)) return false;
   if(!QM_ChartV2Expect(QM_ChartV2ShiftMatches(20.0,20.8,1000,8.0) &&
      QM_ChartV2ShiftMatches(20.0,19.2,1000,8.0),"one_bar_boundary_accepted_both_directions",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2ShiftMatches(20.0,20.8001,1000,8.0) &&
      !QM_ChartV2ShiftMatches(20.0,19.1999,1000,8.0),"over_one_bar_rejected_both_directions",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2ShiftMatches(20.0,20.5,1000,2.0) &&
      QM_ChartV2ShiftMatches(20.0,20.5,1000,8.0),"tolerance_tracks_real_raster_not_fixed_percent",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2ShiftMatches(20.0,20.0,0,8.0) &&
      !QM_ChartV2ShiftMatches(20.0,20.0,1000,0.0) && !QM_ChartV2ShiftMatches(20.0,20.0,1000,1001.0),
      "missing_or_impossible_shift_geometry_rejected",failure)) return false;
   if(!QM_ChartV2Expect(!QM_ChartV2ShiftMatches(20.0,9.99,1000,200.0) &&
      !QM_ChartV2ShiftMatches(20.0,50.01,1000,400.0) && !QM_ChartV2ShiftMatches(MathArcsin(2.0),20.0,1000,8.0),
      "invalid_shift_values_are_never_normalization",failure)) return false;
   return true;
  }

// Optional native proof. Run ONLY on a disposable no-trade visual-QA chart.
// It mutates presentation briefly, verifies both theme modes and restores it.
// No synthetic trading levels are drawn. The caller owns chart creation/removal.
bool QM_ChartPresentationV2ChartSelfTest(const long chart,string &failure)
  {
   failure="";
   ENUM_CHART_PROPERTY_INTEGER keys[]={
      CHART_COLOR_BACKGROUND,CHART_COLOR_FOREGROUND,CHART_COLOR_GRID,CHART_COLOR_CHART_UP,
      CHART_COLOR_CHART_DOWN,CHART_COLOR_CANDLE_BULL,CHART_COLOR_CANDLE_BEAR,CHART_COLOR_CHART_LINE,
      CHART_COLOR_VOLUME,CHART_COLOR_BID,CHART_COLOR_ASK,CHART_COLOR_LAST,CHART_MODE,
      CHART_FOREGROUND,CHART_SHOW_GRID,CHART_SHOW_VOLUMES,CHART_SHOW_BID_LINE,
      CHART_SHOW_ASK_LINE,CHART_SHOW_LAST_LINE,CHART_SHIFT,
      // Also prove these important untouched properties do not change.
      CHART_SCALE,CHART_AUTOSCROLL,CHART_SHOW_TRADE_LEVELS,CHART_DRAG_TRADE_LEVELS,CHART_SHOW_TRADE_HISTORY};
   long before[]; ArrayResize(before,ArraySize(keys));
   for(int i=0;i<ArraySize(keys);++i)
      if(!ChartGetInteger(chart,keys[i],0,before[i])) { failure="initial_property_read"; return false; }
   double shift_before=0.0;
   if(!ChartGetDouble(chart,CHART_SHIFT_SIZE,0,shift_before)) { failure="initial_shift_read"; return false; }
   const string prefix="QM_V2_RT_";
   CQMChartPresentationV2 presenter;
   if(!presenter.Initialize(chart,prefix,true,true,100,true,true,true,true,true))
     { presenter.Shutdown(); failure="theme_initialize_or_apply_readback"; return false; }
   QM_ConsoleSnapshot snapshot; snapshot.Reset(); snapshot.symbol=ChartSymbol(chart); snapshot.timeframe="QA";
   const bool rendered=presenter.Render(snapshot,0,0.0,"","",false);
   const bool no_fake_bid=ObjectFind(chart,prefix+"bid_line")<0;
   bool recovered=true;
   if(ObjectFind(chart,prefix+"identity")>=0)
     {
      recovered=ObjectDelete(chart,prefix+"identity") && presenter.Render(snapshot,0,0.0,"","",false) &&
                ObjectFind(chart,prefix+"identity")>=0;
     }
   // A valid-looking quote for a different symbol must still be suppressed.
   snapshot.symbol="FOREIGN_SYMBOL_FIXTURE";
   const bool foreign_hidden=presenter.Render(snapshot,0,1.23456,"1.23456","FIXTURE",false) &&
                             ObjectFind(chart,prefix+"bid_line")<0;
   const bool restored=presenter.Shutdown(false);
   if(!QM_ChartV2Expect(rendered && no_fake_bid && restored && !presenter.RestorePending(),
      "empty_observation_draws_no_bid_and_restores",failure)) return false;
   if(!QM_ChartV2Expect(recovered,"manually_deleted_owned_object_recovers",failure)) return false;
   if(!QM_ChartV2Expect(foreign_hidden,"foreign_symbol_quote_is_not_drawn",failure)) return false;
   for(int i=0;i<ArraySize(keys);++i)
     {
      long actual=0;
      if(!ChartGetInteger(chart,keys[i],0,actual) || actual!=before[i])
        { failure="property_not_restored_"+EnumToString(keys[i]); return false; }
     }
   double shift_actual=0.0;
   if(!ChartGetDouble(chart,CHART_SHIFT_SIZE,0,shift_actual) || MathAbs(shift_actual-shift_before)>0.000001)
     { failure="shift_size_not_restored"; return false; }
   if(!presenter.Initialize(chart,prefix,true,false,100,true,true,true,true,false))
     { failure="theme_disabled_initialize"; return false; }
   bool unchanged=true;
   for(int i=0;i<ArraySize(keys);++i)
     {
      long actual=0;
      if(!ChartGetInteger(chart,keys[i],0,actual) || actual!=before[i]) unchanged=false;
     }
   if(!ChartGetDouble(chart,CHART_SHIFT_SIZE,0,shift_actual) || MathAbs(shift_actual-shift_before)>0.000001) unchanged=false;
   const bool disabled_restore=presenter.Shutdown();
   if(!QM_ChartV2Expect(unchanged && disabled_restore,"theme_disabled_never_writes_chart_properties",failure)) return false;
   return true;
  }

bool QM_ChartV2FixtureReadRaster(const long chart,QM_ChartV2Raster &raster)
  {
   raster.width=0; raster.bars=0; raster.scale=-1;
   return ChartGetInteger(chart,CHART_WIDTH_IN_PIXELS,0,raster.width) &&
          ChartGetInteger(chart,CHART_WIDTH_IN_BARS,0,raster.bars) &&
          ChartGetInteger(chart,CHART_SCALE,0,raster.scale) && QM_ChartV2RasterValid(raster);
  }

string QM_ChartV2FixtureRasterText(const QM_ChartV2Raster &raster)
  { return StringFormat("%I64d/%I64d/%I64d",raster.width,raster.bars,raster.scale); }

// QA-only wait, never used by the production presenter. The caller supplies one
// shared deadline for changed-zoom setup AND cleanup. No setter, tolerance, or
// production restore retry is hidden here; only the geometry is observed.
bool QM_ChartV2FixtureSettleRaster(const long chart,const QM_ChartV2Raster &baseline,
                                 const long target_scale,const bool require_changed,const ulong deadline,
                                 QM_ChartV2Raster &settled,string &detail)
  {
   const ulong started=GetTickCount64();
   QM_ChartV2Raster first,previous,current;
   first.width=0; first.bars=0; first.scale=-1; previous=first; current=first; settled=first;
   ulong previous_at=started;
   bool have_previous=false,read=false,accepted=false,first_read=false;
   int samples=0,error=0,first_error=0;
   while(GetTickCount64()<deadline && samples<51)
     {
      const ulong observed_at=GetTickCount64();
      ResetLastError();
      read=QM_ChartV2FixtureReadRaster(chart,current); error=GetLastError(); ++samples;
      if(samples==1) { first=current; first_read=read; first_error=error; }
      if(GetTickCount64()>deadline) break;
      if(read && have_previous && QM_ChartV2FixtureSettlePair(previous,current,baseline,target_scale,
            require_changed,observed_at-previous_at))
        { settled=current; accepted=true; break; }
      previous=current; previous_at=observed_at; have_previous=read;
      const ulong now=GetTickCount64();
      if(now>=deadline || deadline-now<20) break;
      Sleep(20);
     }
   detail=StringFormat("target=%I64d changed=%d samples=%d elapsed_ms=%I64u first_read=%d first_error=%d last_read=%d last_error=%d baseline=",
                       target_scale,(int)require_changed,samples,GetTickCount64()-started,(int)first_read,first_error,(int)read,error)+
          QM_ChartV2FixtureRasterText(baseline)+" first="+QM_ChartV2FixtureRasterText(first)+
          " previous="+QM_ChartV2FixtureRasterText(previous)+" current="+QM_ChartV2FixtureRasterText(current);
   Print("QM_CHART_V2_QA_SETTLE ",accepted?"PASS":"FAIL"," chart=",chart," ",detail);
   return accepted;
  }

// TEST-ONLY zoom mutation. Explicit opt-in on a DISPOSABLE, no-trade QA chart;
// never call from an EA or on the user's original trading chart. The production
// presenter must preserve the changed zoom; this fixture then restores its own
// original zoom and every saved property, including the exact original shift.
// It never renders or creates objects. No early returns after first mutation.
bool QM_ChartPresentationV2ZoomSelfTest(const long chart,string &failure,const bool disposable_qa_confirmed=false)
  {
   failure="";
   if(!disposable_qa_confirmed) { failure="zoom_fixture_requires_disposable_qa_confirmation"; return false; }
   ENUM_CHART_PROPERTY_INTEGER keys[]={
      CHART_COLOR_BACKGROUND,CHART_COLOR_FOREGROUND,CHART_COLOR_GRID,CHART_COLOR_CHART_UP,
      CHART_COLOR_CHART_DOWN,CHART_COLOR_CANDLE_BULL,CHART_COLOR_CANDLE_BEAR,CHART_COLOR_CHART_LINE,
      CHART_COLOR_VOLUME,CHART_COLOR_BID,CHART_COLOR_ASK,CHART_COLOR_LAST,CHART_MODE,
      CHART_FOREGROUND,CHART_SHOW_GRID,CHART_SHOW_VOLUMES,CHART_SHOW_BID_LINE,
      CHART_SHOW_ASK_LINE,CHART_SHOW_LAST_LINE,CHART_SHIFT,
      CHART_SCALE,CHART_AUTOSCROLL,CHART_SHOW_TRADE_LEVELS,CHART_DRAG_TRADE_LEVELS,CHART_SHOW_TRADE_HISTORY};
   long before[]; ArrayResize(before,ArraySize(keys));
   QM_ChartV2Raster captured,confirmed,changed,changed_again,cleaned;
   cleaned.width=0; cleaned.bars=0; cleaned.scale=-1;
   ChartRedraw(chart);
   if(!QM_ChartV2FixtureReadRaster(chart,captured)) { failure="zoom_initial_raster"; return false; }
   for(int i=0;i<ArraySize(keys);++i)
      if(!ChartGetInteger(chart,keys[i],0,before[i])) { failure="zoom_initial_property_read"; return false; }
   double shift_before=0.0,shift_confirmed=0.0;
   if(!ChartGetDouble(chart,CHART_SHIFT_SIZE,0,shift_before) ||
      !ChartGetDouble(chart,CHART_SHIFT_SIZE,0,shift_confirmed) || !QM_ChartV2FixtureReadRaster(chart,confirmed) ||
      !QM_ChartV2CaptureStable(captured,confirmed,shift_before,shift_confirmed))
     { failure="zoom_initial_snapshot_unstable"; return false; }
   const long target_scale=captured.scale<5?captured.scale+1:captured.scale-1;
   CQMChartPresentationV2 presenter;
   bool ok=presenter.Initialize(chart,"QM_V2_ZOOM_",true,false,100,true,true,true,true,true);
   if(!ok) failure="zoom_presenter_initialize";
   // Shared wait budget: reserve the last 200 ms for returning to the original
   // raster. Synchronous native calls themselves cannot be timed out by MQL.
   const ulong settle_deadline=GetTickCount64()+1000;
   string settle_detail="",cleanup_detail="";
   if(ok)
     {
      if(!ChartSetInteger(chart,CHART_SCALE,target_scale)) { ok=false; failure="zoom_fixture_set"; }
      ChartRedraw(chart);
     }
   if(ok && !QM_ChartV2FixtureSettleRaster(chart,captured,target_scale,true,settle_deadline-200,changed,settle_detail))
     { ok=false; failure="zoom_fixture_changed_raster_unstable: "+settle_detail; }
   // Always attempt Shutdown even if the test setup or its verification failed.
   const bool restored=presenter.Shutdown(false);
   if(ok && !restored) { ok=false; failure="zoom_changed_raster_shutdown"; }
   double shift_actual=0.0,shift_persisted=0.0;
   if(ok && (!ChartGetDouble(chart,CHART_SHIFT_SIZE,0,shift_actual) ||
      !ChartGetDouble(chart,CHART_SHIFT_SIZE,0,shift_persisted) || !QM_ChartV2FixtureReadRaster(chart,changed_again) ||
      changed_again.scale!=target_scale || presenter.RestorePending() ||
      QM_ChartV2ShiftRestorePolicy(shift_before,shift_actual,shift_persisted,captured,changed,changed_again)==QM_CHART_V2_RESTORE_REJECT))
     { ok=false; failure="zoom_restore_did_not_preserve_current_zoom_and_shift_intent"; }
   for(int i=0;i<ArraySize(keys);++i)
     {
      long actual=0;
      const long expected=keys[i]==CHART_SCALE?target_scale:before[i];
      if(ok && (!ChartGetInteger(chart,keys[i],0,actual) || actual!=expected))
        { ok=false; failure="zoom_restore_property_"+EnumToString(keys[i]); }
     }
   // Cleanup must run on every post-mutation path. Restore the original raster
   // first so an outstanding presenter snapshot can again be restored exactly.
   bool cleanup=ChartSetInteger(chart,CHART_SCALE,captured.scale);
   ChartRedraw(chart);
   if(!QM_ChartV2FixtureSettleRaster(chart,captured,captured.scale,false,settle_deadline,cleaned,cleanup_detail)) cleanup=false;
   if(!presenter.Shutdown(false)) cleanup=false;
   if(!ChartSetInteger(chart,CHART_SHIFT,true)) cleanup=false;
   if(!ChartSetDouble(chart,CHART_SHIFT_SIZE,shift_before)) cleanup=false;
   for(int i=ArraySize(keys)-1;i>=0;--i)
      if(!ChartSetInteger(chart,keys[i],before[i])) cleanup=false;
   ChartRedraw(chart);
   for(int i=0;i<ArraySize(keys);++i)
     {
      long actual=0;
      if(!ChartGetInteger(chart,keys[i],0,actual) || actual!=before[i]) cleanup=false;
     }
   double cleaned_shift=0.0;
   if(!ChartGetDouble(chart,CHART_SHIFT_SIZE,0,cleaned_shift) || !QM_ChartV2FixtureReadRaster(chart,cleaned) ||
      !QM_ChartV2RasterEqual(captured,cleaned) || !QM_ChartV2ShiftValid(cleaned_shift) ||
      MathAbs(cleaned_shift-shift_before)>0.000001 || presenter.RestorePending()) cleanup=false;
   if(!cleanup) { if(failure!="") failure+="; "; failure+="zoom_fixture_cleanup_incomplete: "+cleanup_detail; }
   PrintFormat("QM_CHART_V2_ZOOM_SELFTEST %s chart=%I64d scale_before=%I64d scale_during=%I64d scale_after=%I64d original_shift=%.16f changed_shift=%.16f cleaned_shift=%.16f cleanup=%d reason=%s",
               ok && cleanup?"PASS":"FAIL",chart,captured.scale,target_scale,cleaned.scale,shift_before,shift_actual,cleaned_shift,(int)cleanup,failure);
   return ok && cleanup;
  }

#endif
