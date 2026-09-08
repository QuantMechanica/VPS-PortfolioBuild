#ifndef QM_CHARTPRESENTATIONV2_MQH
#define QM_CHARTPRESENTATIONV2_MQH

#include <QM/QM_ConsoleModel.mqh>

// VERSION 2 / Paper chart. Presentation only. No market/account reads or trade APIs.
// Deliberate A/B distinction: hollow green up candles, filled red down candles.
// Initialize AFTER the previous scheme; Shutdown BEFORE that scheme is restored.
// own_overlays=true requires the dashboard's four overlay flags to be false.
// Snapshot/quote inputs are observations, never entry permissions or invented levels.

struct QM_ChartV2Property
  {
   ENUM_CHART_PROPERTY_INTEGER key;
   long before;
   long target;
  };

struct QM_ChartV2Raster
  {
   long width,bars,scale;
  };

enum QM_ChartV2RestoreResult
  {
   QM_CHART_V2_RESTORE_REJECT=0,
   QM_CHART_V2_RESTORE_EXACT=1,
   QM_CHART_V2_RESTORE_NORMALIZED=2
  };

bool QM_ChartV2RasterValid(const QM_ChartV2Raster &raster)
  {
   return raster.width>0 && raster.width<=2147483647 &&
          raster.bars>1 && raster.bars<=2147483647 && raster.scale>=0 && raster.scale<=5;
  }

bool QM_ChartV2RasterEqual(const QM_ChartV2Raster &a,const QM_ChartV2Raster &b)
  { return a.width==b.width && a.bars==b.bars && a.scale==b.scale; }

bool QM_ChartV2ShiftValid(const double shift)
  { return MathIsValidNumber(shift) && shift>=10.0 && shift<=50.0; }

bool QM_ChartV2CaptureStable(const QM_ChartV2Raster &first,const QM_ChartV2Raster &second,
                            const double shift,const double persisted)
  {
   return QM_ChartV2RasterValid(first) && QM_ChartV2RasterValid(second) &&
          QM_ChartV2RasterEqual(first,second) && QM_ChartV2ShiftValid(shift) &&
          QM_ChartV2ShiftValid(persisted) && MathAbs(shift-persisted)<=0.000001;
  }

struct QM_ChartV2Layout
  {
   int left,right,top,bottom,label_left,label_width,label_height;
  };

struct QM_ChartV2LabelCandidate
  {
   string key,label;
   color tint,fill;
   double price;
   int price_y,priority,placed;
  };

bool QM_ChartV2Price(const double price)
  { return MathIsValidNumber(price) && price>0.0; }

// A display target may be normalized to the native bar raster. Bound the error
// physically by ONE current bar, never by an arbitrary percentage allowance.
// bar_step_px comes from full chart capacity, not CHART_VISIBLE_BARS (which
// excludes the shift): mql5.com/en/book/applications/charts/charts_scale_time.
bool QM_ChartV2ShiftMatches(const double expected,const double actual,const int chart_width,const double bar_step_px)
  {
   if(!MathIsValidNumber(expected) || !MathIsValidNumber(actual) || !MathIsValidNumber(bar_step_px) ||
      expected<10.0 || expected>50.0 || actual<10.0 || actual>50.0 ||
      chart_width<=0 || bar_step_px<=0.0 || bar_step_px>chart_width) return false;
   const double error_px=MathAbs(actual-expected)*chart_width/100.0;
   return error_px<=bar_step_px+0.000001;
  }

// Exact restoration remains mandatory on the captured raster. An observed,
// stable raster change may make the original percentage unrepresentable. Only
// then accept a stable result within ONE current bar. This is our bounded visual
// equivalence policy, not an undocumented guarantee about MT5 rounding, nor a
// claim that a user caused the change. Never replace the saved original intent.
QM_ChartV2RestoreResult QM_ChartV2ShiftRestorePolicy(const double expected,const double actual,const double persisted,
                                                  const QM_ChartV2Raster &captured,const QM_ChartV2Raster &first,
                                                  const QM_ChartV2Raster &second)
  {
   if(!QM_ChartV2RasterValid(captured) || !QM_ChartV2ShiftValid(expected) ||
      !QM_ChartV2CaptureStable(first,second,actual,persisted)) return QM_CHART_V2_RESTORE_REJECT;
   if(MathAbs(actual-expected)<=0.000001) return QM_CHART_V2_RESTORE_EXACT;
   if(QM_ChartV2RasterEqual(captured,first)) return QM_CHART_V2_RESTORE_REJECT;
   const double step=(double)first.width/(double)first.bars;
   return QM_ChartV2ShiftMatches(expected,actual,(int)first.width,step)?
          QM_CHART_V2_RESTORE_NORMALIZED:QM_CHART_V2_RESTORE_REJECT;
  }

bool QM_ChartV2Geometry(const int width,const int height,const int panel_right,
                       const double scale,QM_ChartV2Layout &layout)
  {
   if(!MathIsValidNumber(scale) || scale<0.5 || scale>6.0) return false;
   layout.left=(int)MathMax(12.0*scale,panel_right+24.0*scale);
   layout.right=width-(int)MathCeil(76.0*scale);
   layout.top=(int)MathCeil(68.0*scale);
   layout.bottom=height-(int)MathCeil(34.0*scale);
   layout.label_width=(int)MathCeil(148.0*scale);
   layout.label_height=(int)MathCeil(22.0*scale);
   layout.label_left=layout.right-layout.label_width;
   return panel_right>=0 && width>0 && height>0 &&
          layout.label_left-layout.left>=(int)MathCeil(72.0*scale) &&
          layout.bottom-layout.top>=3*layout.label_height;
  }

// Return -1 for invalid data, 0 for a valid label without a dated segment,
// or 1 for a segment using ONLY the two provided times, in either direction.
int QM_ChartV2LevelSegment(const datetime started,const datetime end,const double price,datetime &from,datetime &to)
  {
   from=started<end?started:end; to=started>end?started:end;
   if(!QM_ChartV2Price(price) || started<=0 || end<=0) return -1;
   return started==end?0:1;
  }

bool QM_ChartV2LabelBefore(const QM_ChartV2LabelCandidate &a,const QM_ChartV2LabelCandidate &b)
  { return a.price_y<b.price_y || (a.price_y==b.price_y && a.price>b.price); }

bool QM_ChartV2LabelInView(const int price_y,const QM_ChartV2Layout &layout)
  { return price_y>=layout.top && price_y<=layout.bottom; }

string QM_ChartV2LevelNotice(const int omitted,const int outside_view)
  {
   if(omitted>0 && outside_view>0) return StringFormat("%d omitted / %d outside view",omitted,outside_view);
   if(omitted>0) return (string)omitted+" labels omitted";
   if(outside_view>0) return (string)outside_view+(outside_view==1?" level outside view":" levels outside view");
   return "";
  }

// The producer caps this queue at 99 candidates. Selection priority and visual
// order are separate: keep critical trade labels first, then place all retained
// labels in their actual top-to-bottom price order. Off-screen prices stay hidden.
int QM_ChartV2ArrangeLabels(QM_ChartV2LabelCandidate &labels[],const QM_ChartV2Layout &layout)
  {
   int selected[];
   const int count=ArraySize(labels);
   for(int i=0;i<count;++i)
     {
      labels[i].placed=-1;
      if(!QM_ChartV2LabelInView(labels[i].price_y,layout)) continue;
      const int n=ArraySize(selected); ArrayResize(selected,n+1); selected[n]=i;
     }
   const int visible=ArraySize(selected);
   if(layout.label_height<1 || layout.bottom<=layout.top) return visible;
   const int step=layout.label_height+4;
   const int capacity=(int)MathMax(0,(layout.bottom-layout.top+4)/step);
   // Stable priority selection. Lower priority number is more important.
   for(int i=1;i<visible;++i)
     {
      const int value=selected[i]; int j=i-1;
      while(j>=0 && labels[selected[j]].priority>labels[value].priority)
        { selected[j+1]=selected[j]; --j; }
      selected[j+1]=value;
     }
   const int keep=(int)MathMin(visible,capacity); ArrayResize(selected,keep);
   for(int i=1;i<keep;++i)
     {
      const int value=selected[i]; int j=i-1;
      while(j>=0 && QM_ChartV2LabelBefore(labels[value],labels[selected[j]]))
        { selected[j+1]=selected[j]; --j; }
      selected[j+1]=value;
     }
   // Forward packing, followed by a bottom correction that preserves order.
   int next=layout.top;
   for(int i=0;i<keep;++i)
     {
      const int index=selected[i];
      labels[index].placed=(int)MathMax(next,labels[index].price_y-layout.label_height/2);
      next=labels[index].placed+step;
     }
   int limit=layout.bottom-layout.label_height;
   for(int i=keep-1;i>=0;--i)
     {
      const int index=selected[i];
      labels[index].placed=(int)MathMin(labels[index].placed,limit);
      limit=labels[index].placed-step;
     }
   return visible-keep;
  }

class CQMChartPresentationV2
  {
private:
   long m_chart;
   string m_prefix;
   bool m_ready,m_saved,m_own_overlays,m_show_range,m_show_strategy,m_show_levels,m_show_markers,m_ok;
   double m_scale,m_font_scale,m_shift_before;
   QM_ChartV2Raster m_raster_before;
   QM_ChartV2Property m_properties[];
   string m_objects[],m_used[];
   QM_ChartV2LabelCandidate m_labels[];
   int m_label_omitted,m_label_offscreen;
   string m_offscreen_labels;
   QM_ChartV2Layout m_layout;

   int Px(const int value) { return (int)MathRound(value*m_scale); }
   int Font(const int value) { return (int)MathMax(8,MathRound(value*m_font_scale)); }
   string Name(const string key) { return m_prefix+key; }
   void Diagnostic(const string stage,const string property,const string expected,const string actual,const int error)
     {
      PrintFormat("QM_CHART_V2 %s chart=%I64d property=%s expected=%s actual=%s error=%d",
                  stage,m_chart,property,expected,actual,error);
     }
   void Property(const ENUM_CHART_PROPERTY_INTEGER key,const long target)
     {
      const int i=ArraySize(m_properties);
      ArrayResize(m_properties,i+1);
      m_properties[i].key=key; m_properties[i].target=target; m_properties[i].before=0;
     }
   void DefineProperties()
     {
      ArrayResize(m_properties,0);
      Property(CHART_COLOR_BACKGROUND,QM_COLOR_SURFACE);
      Property(CHART_COLOR_FOREGROUND,QM_COLOR_SLATE);
      Property(CHART_COLOR_GRID,QM_COLOR_BORDER);
      Property(CHART_COLOR_CHART_UP,QM_COLOR_CANDLE_UP);
      Property(CHART_COLOR_CHART_DOWN,QM_COLOR_CANDLE_DOWN);
      Property(CHART_COLOR_CANDLE_BULL,QM_COLOR_SURFACE);
      Property(CHART_COLOR_CANDLE_BEAR,QM_COLOR_CANDLE_DOWN);
      Property(CHART_COLOR_CHART_LINE,QM_COLOR_SIGNAL_BLUE);
      Property(CHART_COLOR_VOLUME,QM_COLOR_BORDER);
      Property(CHART_COLOR_BID,QM_COLOR_SIGNAL_BLUE);
      Property(CHART_COLOR_ASK,QM_COLOR_MUTED);
      Property(CHART_COLOR_LAST,QM_COLOR_SIGNAL_BLUE);
      Property(CHART_MODE,CHART_CANDLES);
      Property(CHART_FOREGROUND,false);
      Property(CHART_SHOW_GRID,false);
      Property(CHART_SHOW_VOLUMES,CHART_VOLUME_HIDE);
      Property(CHART_SHOW_BID_LINE,false);
      Property(CHART_SHOW_ASK_LINE,false);
      Property(CHART_SHOW_LAST_LINE,false);
      Property(CHART_SHIFT,true);
      // CHART_SCALE, autoscroll, native trade levels/history and drag settings are untouched.
     }
   string RasterText(const QM_ChartV2Raster &raster)
     { return StringFormat("width=%I64d bars=%I64d scale=%I64d",raster.width,raster.bars,raster.scale); }
   bool ReadRaster(QM_ChartV2Raster &raster,const string stage)
     {
      raster.width=0; raster.bars=0; raster.scale=-1;
      ResetLastError();
      if(!ChartGetInteger(m_chart,CHART_WIDTH_IN_PIXELS,0,raster.width))
        { Diagnostic(stage,"CHART_WIDTH_IN_PIXELS","readable","N/A",GetLastError()); return false; }
      ResetLastError();
      if(!ChartGetInteger(m_chart,CHART_WIDTH_IN_BARS,0,raster.bars))
        { Diagnostic(stage,"CHART_WIDTH_IN_BARS","readable","N/A",GetLastError()); return false; }
      ResetLastError();
      if(!ChartGetInteger(m_chart,CHART_SCALE,0,raster.scale))
        { Diagnostic(stage,"CHART_SCALE","readable","N/A",GetLastError()); return false; }
      if(!QM_ChartV2RasterValid(raster))
        { Diagnostic(stage,"raster","positive width, bars>1, scale 0..5",RasterText(raster),0); return false; }
      return true;
     }
   bool Capture()
     {
      // Redraw and synchronous reads drain prior queued chart changes. Bracket
      // the snapshot with complete tuples; an in-progress zoom/layout is not a
      // valid baseline merely because its individual property reads succeeded.
      ChartRedraw(m_chart);
      QM_ChartV2Raster first,second;
      if(!ReadRaster(first,"CAPTURE_RASTER")) return false;
      for(int i=0;i<ArraySize(m_properties);++i)
        {
         ResetLastError();
         if(!ChartGetInteger(m_chart,m_properties[i].key,0,m_properties[i].before))
           { Diagnostic("CAPTURE_GET",EnumToString(m_properties[i].key),"readable","N/A",GetLastError()); return false; }
        }
      ResetLastError();
      if(!ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,m_shift_before))
        { Diagnostic("CAPTURE_GET","CHART_SHIFT_SIZE","readable","N/A",GetLastError()); return false; }
      double persisted=0.0;
      ResetLastError();
      if(!ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,persisted))
        { Diagnostic("CAPTURE_GET","CHART_SHIFT_SIZE","second readable observation","N/A",GetLastError()); return false; }
      if(!ReadRaster(second,"CAPTURE_RASTER")) return false;
      if(!QM_ChartV2CaptureStable(first,second,m_shift_before,persisted))
        {
         Diagnostic("CAPTURE_UNSTABLE","raster/shift",RasterText(first)+StringFormat(" shift=%.16f",m_shift_before),
                    RasterText(second)+StringFormat(" shift=%.16f",persisted),0);
         return false;
        }
      m_raster_before=first;
      m_saved=true;
      return true;
     }
   bool Apply()
     {
      bool ok=true;
      for(int i=0;i<ArraySize(m_properties);++i)
        {
         ResetLastError();
         if(!ChartSetInteger(m_chart,m_properties[i].key,m_properties[i].target))
           { Diagnostic("APPLY_SET",EnumToString(m_properties[i].key),(string)m_properties[i].target,"N/A",GetLastError()); ok=false; }
        }
      ResetLastError();
      if(!ChartSetDouble(m_chart,CHART_SHIFT_SIZE,20.0))
        { Diagnostic("APPLY_SET","CHART_SHIFT_SIZE","20.0","N/A",GetLastError()); ok=false; }
      // Synchronous getters flush queued setters and verify the actual chart state.
      for(int i=0;i<ArraySize(m_properties);++i)
        {
         long actual=0;
         ResetLastError();
         const bool read=ChartGetInteger(m_chart,m_properties[i].key,0,actual);
         const int error=GetLastError();
         if(!read || actual!=m_properties[i].target)
           { Diagnostic("APPLY_VERIFY",EnumToString(m_properties[i].key),(string)m_properties[i].target,read?(string)actual:"N/A",error); ok=false; }
        }
      double shift=0.0;
      ResetLastError();
      const bool read_shift=ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,shift);
      const int shift_error=GetLastError();
      if(!read_shift || !MathIsValidNumber(shift))
        { Diagnostic("APPLY_VERIFY","CHART_SHIFT_SIZE","20.0000000000000000",read_shift?"non-finite":"N/A",shift_error); ok=false; }
      else if(MathAbs(shift-20.0)>0.000001)
        {
         // Native evidence: 20.0 requested -> 19.8653198653198615, error=0.
         // The chart exposes its current pixel width and full bar capacity;
         // their ratio is a conservative current-bar-width bound (no zoom guess).
         long width=0,bars=0;
         ResetLastError();
         const bool read_width=ChartGetInteger(m_chart,CHART_WIDTH_IN_PIXELS,0,width);
         const int width_error=GetLastError();
         ResetLastError();
         const bool read_bars=ChartGetInteger(m_chart,CHART_WIDTH_IN_BARS,0,bars);
         const int bars_error=GetLastError();
         const double step=bars>1?(double)width/(double)bars:0.0;
         if(!read_width || !read_bars || !QM_ChartV2ShiftMatches(20.0,shift,(int)width,step))
           {
            Diagnostic("APPLY_VERIFY","CHART_SHIFT_SIZE","20.0 within one measured bar",
                       StringFormat("shift=%.16f width=%I64d bars=%I64d step_px=%.8f",shift,width,bars,step),
                       !read_width?width_error:(!read_bars?bars_error:0));
            ok=false;
           }
         else
           {
            // Accept only a stable native result, not a transient/unverified setter.
            double persisted=0.0;
            ResetLastError();
            const bool read_persisted=ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,persisted);
            const int persisted_error=GetLastError();
            if(!read_persisted || !MathIsValidNumber(persisted) || MathAbs(persisted-shift)>0.000001)
              { Diagnostic("APPLY_PERSIST","CHART_SHIFT_SIZE",StringFormat("%.16f",shift),read_persisted?StringFormat("%.16f",persisted):"N/A",persisted_error); ok=false; }
            else
               Diagnostic("APPLY_NORMALIZED","CHART_SHIFT_SIZE","20.0 within one measured bar",
                          StringFormat("shift=%.16f width=%I64d bars=%I64d step_px=%.8f error_px=%.8f",
                                       shift,width,bars,step,MathAbs(shift-20.0)*width/100.0),0);
           }
        }
      return ok;
     }
   bool Restore()
     {
      if(!m_saved) return true;
      ChartRedraw(m_chart);
      QM_ChartV2Raster first,second;
      // Still attempt every original setter if geometry cannot be read, but do
      // not relinquish the snapshot unless the complete restoration is verified.
      const bool read_first=ReadRaster(first,"RESTORE_RASTER");
      bool ok=read_first;
      // Restore size while shift is enabled, then restore the original shift toggle.
      ResetLastError();
      if(!ChartSetDouble(m_chart,CHART_SHIFT_SIZE,m_shift_before))
        { Diagnostic("RESTORE_SET","CHART_SHIFT_SIZE",StringFormat("%.16f",m_shift_before),"N/A",GetLastError()); ok=false; }
      for(int i=ArraySize(m_properties)-1;i>=0;--i)
        {
         ResetLastError();
         if(!ChartSetInteger(m_chart,m_properties[i].key,m_properties[i].before))
           { Diagnostic("RESTORE_SET",EnumToString(m_properties[i].key),(string)m_properties[i].before,"N/A",GetLastError()); ok=false; }
        }
      for(int i=0;i<ArraySize(m_properties);++i)
        {
         long actual=0;
         ResetLastError();
         const bool read=ChartGetInteger(m_chart,m_properties[i].key,0,actual);
         const int error=GetLastError();
         if(!read || actual!=m_properties[i].before)
           { Diagnostic("RESTORE_VERIFY",EnumToString(m_properties[i].key),(string)m_properties[i].before,read?(string)actual:"N/A",error); ok=false; }
        }
      double shift=0.0;
      ResetLastError();
      const bool read_shift=ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,shift);
      const int shift_error=GetLastError();
      double persisted=0.0;
      ResetLastError();
      const bool read_persisted=ChartGetDouble(m_chart,CHART_SHIFT_SIZE,0,persisted);
      const int persisted_error=GetLastError();
      const bool read_second=ReadRaster(second,"RESTORE_RASTER");
      const QM_ChartV2RestoreResult result=QM_ChartV2ShiftRestorePolicy(m_shift_before,shift,persisted,m_raster_before,first,second);
      const bool differs=MathAbs(shift-m_shift_before)>0.000001;
      if(!read_shift || !read_persisted || !read_first || !read_second || result==QM_CHART_V2_RESTORE_REJECT)
        {
         Diagnostic("RESTORE_VERIFY","CHART_SHIFT_SIZE",StringFormat("original=%.16f; ",m_shift_before)+RasterText(m_raster_before),
                    StringFormat("shift=%.16f persisted=%.16f differs=%d; first ",shift,persisted,(int)differs)+
                    RasterText(first)+"; second "+RasterText(second),!read_shift?shift_error:(!read_persisted?persisted_error:0));
         ok=false;
        }
      else if(ok && result==QM_CHART_V2_RESTORE_NORMALIZED)
        {
         Diagnostic("RESTORE_NORMALIZED","CHART_SHIFT_SIZE",StringFormat("original=%.16f; ",m_shift_before)+RasterText(m_raster_before),
                    StringFormat("shift=%.16f persisted=%.16f; ",shift,persisted)+RasterText(second)+
                    StringFormat(" step_px=%.8f error_px=%.8f",(double)second.width/(double)second.bars,
                                 MathAbs(shift-m_shift_before)*second.width/100.0),0);
        }
      if(ok) m_saved=false; // Keep the snapshot for an explicit retry after a failed restore.
      return ok;
     }
   bool ExistsIn(const string &items[],const string value)
     {
      for(int i=0;i<ArraySize(items);++i) if(items[i]==value) return true;
      return false;
     }
   bool Object(const string key,const ENUM_OBJECT type)
     {
      const string name=Name(key);
      const bool owned=ExistsIn(m_objects,name);
      const bool present=ObjectFind(m_chart,name)>=0;
      // Recover from manual deletion; a cached name is not proof the object exists.
      if(present && !owned) { m_ok=false; return false; }
      if(present && ObjectGetInteger(m_chart,name,OBJPROP_TYPE)!=(long)type) { m_ok=false; return false; }
      if(!present)
        {
         // Never adopt or mutate a pre-existing object, even with a colliding namespace.
         if(!ObjectCreate(m_chart,name,type,0,0,0)) { m_ok=false; return false; }
         if(!owned) { const int i=ArraySize(m_objects); ArrayResize(m_objects,i+1); m_objects[i]=name; }
         I(key,OBJPROP_SELECTABLE,false); I(key,OBJPROP_SELECTED,false); I(key,OBJPROP_HIDDEN,true);
        }
      if(!ExistsIn(m_used,name)) { const int i=ArraySize(m_used); ArrayResize(m_used,i+1); m_used[i]=name; }
      return true;
     }
   void I(const string key,const ENUM_OBJECT_PROPERTY_INTEGER property,const long value)
     { if(!ObjectSetInteger(m_chart,Name(key),property,value)) m_ok=false; }
   void S(const string key,const ENUM_OBJECT_PROPERTY_STRING property,const string value)
     { if(!ObjectSetString(m_chart,Name(key),property,value)) m_ok=false; }
   void Box(const string key,const int x,const int y,const int width,const int height,const color fill)
     {
      if(width<1 || height<1 || !Object(key,OBJ_RECTANGLE_LABEL)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_XDISTANCE,x); I(key,OBJPROP_YDISTANCE,y);
      I(key,OBJPROP_XSIZE,width); I(key,OBJPROP_YSIZE,height);
      I(key,OBJPROP_BGCOLOR,fill); I(key,OBJPROP_COLOR,fill); I(key,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      I(key,OBJPROP_BACK,false); S(key,OBJPROP_TOOLTIP,"\n");
     }
   int TextWidth(const string value,const int size,const bool bold=false)
     {
      uint width=0,height=0;
      if(TextSetFont(bold?QM_FONT_UI_BOLD:QM_FONT_UI,-10*Font(size),0) && TextGetSize(value,width,height)) return (int)width;
      return (int)MathCeil(StringLen(value)*Font(size)*m_scale/m_font_scale*1.5);
     }
   string Fit(const string value,const int room,const int size,const bool bold=false)
     {
      if(room<1) return "";
      string clean="";
      for(int i=0;i<StringLen(value);++i)
        { const ushort c=StringGetCharacter(value,i); clean+=ShortToString((ushort)(c>=32 && c!=127?c:32)); }
      if(TextWidth(clean,size,bold)<=room) return clean;
      if(TextWidth("...",size,bold)>room) return "";
      int lo=0,hi=StringLen(clean);
      while(lo<hi)
        {
         const int mid=(lo+hi+1)/2;
         if(TextWidth(StringSubstr(clean,0,mid)+"...",size,bold)<=room) lo=mid; else hi=mid-1;
        }
      return StringSubstr(clean,0,lo)+"...";
     }
   void Text(const string key,const string value,const int x,const int y,const int room,
             const color tint,const int size=9,const bool bold=false)
     {
      const string displayed=Fit(value,room,size,bold);
      if(displayed=="" || !Object(key,OBJ_LABEL)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      I(key,OBJPROP_XDISTANCE,x); I(key,OBJPROP_YDISTANCE,y); I(key,OBJPROP_FONTSIZE,Font(size));
      I(key,OBJPROP_COLOR,tint); I(key,OBJPROP_BACK,false);
      S(key,OBJPROP_FONT,bold?QM_FONT_UI_BOLD:QM_FONT_UI); S(key,OBJPROP_TEXT,displayed); S(key,OBJPROP_TOOLTIP,value);
     }
   bool Endpoint(datetime &when)
     {
      int window=0; double price=0.0;
      return ChartXYToTimePrice(m_chart,m_layout.label_left-Px(12),m_layout.top,window,when,price) && window==0 && when>0;
     }
   void PriceLabel(const string key,const datetime when,const double price,const string label,const color tint,
                   const color fill=QM_COLOR_SURFACE,const int priority=3)
     {
      int x=0,y=0;
      if(!QM_ChartV2Price(price) || !ChartTimePriceToXY(m_chart,0,when,price,x,y)) return;
      if(!QM_ChartV2LabelInView(y,m_layout))
        {
         ++m_label_offscreen;
         if(m_offscreen_labels!="") m_offscreen_labels+="; ";
         m_offscreen_labels+=label;
         return; // No edge marker: preserve the real price rather than pinning it.
        }
      const int i=ArraySize(m_labels);
      if(i>=99) { ++m_label_omitted; return; }
      ArrayResize(m_labels,i+1);
      m_labels[i].key=key; m_labels[i].label=label; m_labels[i].tint=tint; m_labels[i].fill=fill;
      m_labels[i].price=price; m_labels[i].price_y=y; m_labels[i].priority=priority; m_labels[i].placed=-1;
     }
   void DrawPriceLabels()
     {
      m_label_omitted+=QM_ChartV2ArrangeLabels(m_labels,m_layout);
      string omitted="";
      for(int i=0;i<ArraySize(m_labels);++i)
        {
         QM_ChartV2LabelCandidate item=m_labels[i];
         if(item.placed<0) { if(omitted!="") omitted+="; "; omitted+=item.label; continue; }
         const int center=item.placed+m_layout.label_height/2;
         // The source endpoint remains the real price, even after packed layout.
         Box(item.key+"_leader_v",m_layout.label_left-Px(6),(int)MathMin(item.price_y,center),1,(int)MathAbs(item.price_y-center)+1,item.tint);
         Box(item.key+"_leader_h",m_layout.label_left-Px(12),item.price_y,Px(6),1,item.tint);
         Box(item.key+"_join",m_layout.label_left-Px(6),center,Px(6),1,item.tint);
         Box(item.key+"_card",m_layout.label_left,item.placed,m_layout.label_width,m_layout.label_height,item.fill);
         Box(item.key+"_accent",m_layout.label_left,item.placed,Px(2),m_layout.label_height,item.tint);
         Text(item.key+"_text",item.label,m_layout.label_left+Px(8),item.placed+Px(3),m_layout.label_width-Px(14),item.tint,9,true);
        }
      const string notice=QM_ChartV2LevelNotice(m_label_omitted,m_label_offscreen);
      if(notice!="")
        {
         Text("level_notice",notice,m_layout.label_left,m_layout.bottom+Px(6),m_layout.label_width,QM_COLOR_WARNING,8);
         string detail=notice+".";
         if(m_label_omitted>0) detail+=" Insufficient label space; critical trade labels retained first. Omitted: "+omitted+".";
         if(m_label_offscreen>0) detail+=" Outside available price-label area (including reserved header/axis margins): "+m_offscreen_labels+". Prices are not pinned to the chart edge.";
         S("level_notice",OBJPROP_TOOLTIP,detail);
        }
     }
   void Level(const string key,const datetime started,const datetime end,const double price,
              const string label,const color tint,const ENUM_LINE_STYLE style=STYLE_DOT,const int priority=1)
     {
      datetime from=0,to=0;
      const int segment=QM_ChartV2LevelSegment(started,end,price,from,to);
      if(segment<0) return;
      if(segment>0 && Object(key,OBJ_TREND))
        {
         if(!ObjectMove(m_chart,Name(key),0,from,price) || !ObjectMove(m_chart,Name(key),1,to,price)) m_ok=false;
         I(key,OBJPROP_COLOR,tint); I(key,OBJPROP_WIDTH,1); I(key,OBJPROP_STYLE,style);
         I(key,OBJPROP_RAY_LEFT,false); I(key,OBJPROP_RAY_RIGHT,false); I(key,OBJPROP_BACK,true);
         S(key,OBJPROP_TOOLTIP,label);
        }
      PriceLabel(key+"_label",end,price,label,tint,QM_COLOR_SURFACE,priority);
     }
   void Overlays(const QM_ConsoleSnapshot &snapshot,const datetime end)
     {
      if(!m_own_overlays) return;
      const bool range=snapshot.active_range && snapshot.range_start>0 && snapshot.range_end>snapshot.range_start &&
                       QM_ChartV2Price(snapshot.range_high) && QM_ChartV2Price(snapshot.range_low) && snapshot.range_high>snapshot.range_low;
      if(range && m_show_range && Object("range_fill",OBJ_RECTANGLE))
        {
         if(!ObjectMove(m_chart,Name("range_fill"),0,snapshot.range_start,snapshot.range_high) ||
            !ObjectMove(m_chart,Name("range_fill"),1,snapshot.range_end,snapshot.range_low)) m_ok=false;
         I("range_fill",OBJPROP_COLOR,QM_COLOR_RANGE_FILL); I("range_fill",OBJPROP_FILL,true);
         I("range_fill",OBJPROP_BACK,true); S("range_fill",OBJPROP_TOOLTIP,"Observed strategy range");
        }
      // Priority applies only when labels do not all fit; visual order is by price.
      const int count=(int)MathMin(ArraySize(snapshot.exposure),32);
      for(int i=0;i<count;++i)
        {
         QM_ConsoleExposure exposure=snapshot.exposure[i];
         if(exposure.ticket==0 || exposure.symbol!=snapshot.symbol || !QM_ChartV2Price(exposure.entry)) continue;
         // Bounded slot names stay below MT5's 63-character limit, even for ulong tickets.
         const string key="t"+(string)i;
         const color tint=exposure.buy?QM_COLOR_QUANT_GREEN_DARK:QM_COLOR_NEGATIVE;
         const string direction=exposure.buy?"Buy ":"Sell ";
         if(m_show_levels)
           {
            Level(key+"_entry",exposure.opened,end,exposure.entry,direction+(exposure.pending?"trigger ":"entry ")+exposure.entry_text,tint,STYLE_DASH);
            Level(key+"_sl",exposure.opened,end,exposure.sl,"SL "+exposure.sl_text,QM_COLOR_NEGATIVE,STYLE_DOT,0);
            Level(key+"_tp",exposure.opened,end,exposure.tp,"TP "+exposure.tp_text,QM_COLOR_QUANT_GREEN_DARK,STYLE_DOT,2);
           }
         if(m_show_markers && !exposure.pending && exposure.opened>0 && Object(key+"_marker",OBJ_ARROW))
           {
            if(!ObjectMove(m_chart,Name(key+"_marker"),0,exposure.opened,exposure.entry)) m_ok=false;
            I(key+"_marker",OBJPROP_ARROWCODE,exposure.buy?233:234); I(key+"_marker",OBJPROP_COLOR,tint);
            I(key+"_marker",OBJPROP_ANCHOR,exposure.buy?ANCHOR_TOP:ANCHOR_BOTTOM);
            I(key+"_marker",OBJPROP_WIDTH,1); I(key+"_marker",OBJPROP_BACK,false);
            S(key+"_marker",OBJPROP_TOOLTIP,direction+"entry "+exposure.entry_text+" | #"+(string)exposure.ticket);
           }
        }
      if(range && m_show_strategy)
        {
         Level("range_high",snapshot.range_start,end,snapshot.range_high,"Range H "+snapshot.range_high_text,QM_COLOR_RANGE_BORDER,STYLE_DOT,4);
         Level("range_low",snapshot.range_start,end,snapshot.range_low,"Range L "+snapshot.range_low_text,QM_COLOR_RANGE_BORDER,STYLE_DOT,4);
        }
      if(ArraySize(snapshot.exposure)>count)
         Text("overflow","Chart annotations limited to 32 records",m_layout.left,m_layout.bottom+Px(6),m_layout.label_left-m_layout.left-Px(12),QM_COLOR_WARNING,8);
     }
   bool Sweep(const bool all=false)
     {
      bool ok=true;
      for(int i=ArraySize(m_objects)-1;i>=0;--i)
        {
         if(!all && ExistsIn(m_used,m_objects[i])) continue;
         if(ObjectFind(m_chart,m_objects[i])>=0 && !ObjectDelete(m_chart,m_objects[i])) { ok=false; continue; }
         for(int j=i+1;j<ArraySize(m_objects);++j) m_objects[j-1]=m_objects[j];
         ArrayResize(m_objects,ArraySize(m_objects)-1);
        }
      return ok;
     }

public:
   CQMChartPresentationV2() : m_chart(0),m_prefix(""),m_ready(false),m_saved(false),m_own_overlays(false),
      m_show_range(true),m_show_strategy(true),m_show_levels(true),m_show_markers(true),m_ok(true),m_scale(1.0),m_font_scale(1.0),m_shift_before(0.0),m_label_omitted(0),m_label_offscreen(0),m_offscreen_labels("") {}

   bool Initialize(const long chart,const string prefix,const bool enabled=true,const bool own_overlays=false,
                   const int scale=100,const bool show_range=true,const bool show_levels=true,
                   const bool show_markers=true,const bool show_strategy=true,const bool apply_theme=true)
     {
      if(m_ready || m_saved || ArraySize(m_objects)>0)
        {
         Diagnostic("INITIALIZE_GUARD","lifecycle","ready=0 saved=0 objects=0",
                    StringFormat("ready=%d saved=%d objects=%d",(int)m_ready,(int)m_saved,ArraySize(m_objects)),0);
         return false;
        }
      if(!enabled || chart<0 || prefix=="" || StringLen(prefix)>35 ||
         MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0)
        {
         Diagnostic("INITIALIZE_GUARD","arguments","enabled=1 chart>=0 prefix_len=1..35 tester=0 optimizer=0",
                    StringFormat("enabled=%d chart=%I64d prefix_len=%d tester=%d optimizer=%d",(int)enabled,chart,StringLen(prefix),
                                 (int)MQLInfoInteger(MQL_TESTER),(int)MQLInfoInteger(MQL_OPTIMIZATION)),0);
         return false;
        }
      m_chart=chart==0?ChartID():chart; m_prefix=prefix;
      m_font_scale=MathMax(0.75,MathMin(2.0,scale/100.0));
      m_scale=m_font_scale*MathMax(72.0,MathMin(288.0,(double)TerminalInfoInteger(TERMINAL_SCREEN_DPI)))/96.0;
      m_own_overlays=own_overlays; m_show_range=show_range; m_show_strategy=show_strategy;
      m_show_levels=show_levels; m_show_markers=show_markers;
      if(apply_theme)
        {
         DefineProperties();
         if(!Capture()) return false;
         if(!Apply())
           {
            const bool restored=Restore();
            Diagnostic("INITIALIZE_APPLY_FAILED","rollback","restored=1",restored?"restored=1":"restored=0",0);
            return false;
           }
        }
      m_ready=true;
      return true;
     }
   bool Render(const QM_ConsoleSnapshot &snapshot,const int panel_right_px=0,const double bid=0.0,
               const string bid_text="",const string observed_text="",const bool redraw=true)
     {
      if(!m_ready) return false;
      m_ok=true; ArrayResize(m_used,0); ArrayResize(m_labels,0);
      m_label_omitted=0; m_label_offscreen=0; m_offscreen_labels="";
      long width=0,height=0;
      const bool geometry=ChartGetInteger(m_chart,CHART_WIDTH_IN_PIXELS,0,width) && ChartGetInteger(m_chart,CHART_HEIGHT_IN_PIXELS,0,height) &&
                          QM_ChartV2Geometry((int)width,(int)height,panel_right_px,m_scale,m_layout);
      if(geometry)
        {
         const int room=m_layout.right-m_layout.left;
         const bool same_symbol=snapshot.symbol!="" && snapshot.symbol==ChartSymbol(m_chart);
         const bool has_bid=same_symbol && QM_ChartV2Price(bid) && bid_text!="";
         const int identity_room=has_bid && room>=Px(470)?room-Px(238):room;
         Text("identity",snapshot.symbol+"  /  "+snapshot.timeframe,m_layout.left,Px(26),identity_room,QM_COLOR_CARBON,10,true);
         Text("context",same_symbol?"PRICE CHART  /  STRATEGY TIMEFRAME":"SNAPSHOT SYMBOL DIFFERS FROM CHART",m_layout.left,Px(46),room,
              same_symbol?QM_COLOR_SLATE:QM_COLOR_WARNING,8);
         datetime end=0;
         if(same_symbol && Endpoint(end))
           {
            if(has_bid)
              {
               if(Object("bid_line",OBJ_HLINE))
                 {
                  if(!ObjectMove(m_chart,Name("bid_line"),0,0,bid)) m_ok=false;
                  I("bid_line",OBJPROP_COLOR,QM_COLOR_SIGNAL_BLUE); I("bid_line",OBJPROP_STYLE,STYLE_SOLID);
                  I("bid_line",OBJPROP_WIDTH,1); I("bid_line",OBJPROP_BACK,true);
                  S("bid_line",OBJPROP_TOOLTIP,"Last observed bid "+bid_text+(observed_text==""?"":" | "+observed_text));
                 }
               PriceLabel("bid",end,bid,"BID "+bid_text,QM_COLOR_SIGNAL_BLUE,QM_COLOR_SIGNAL_BLUE_SOFT);
               if(room>=Px(470))
                  Text("observation",observed_text==""?"Last observed bid":"Bid observed "+observed_text,
                       m_layout.right-Px(214),Px(28),Px(214),QM_COLOR_SLATE,8);
              }
            Overlays(snapshot,end);
            DrawPriceLabels();
           }
        }
      if(!Sweep()) m_ok=false;
      if(redraw) ChartRedraw(m_chart);
      return m_ok;
     }
   bool Shutdown(const bool redraw=true)
     {
      m_ready=false;
      const bool objects_ok=Sweep(true);
      const bool restored=Restore();
      if(redraw) ChartRedraw(m_chart);
      return objects_ok && restored;
     }
   bool Ready() { return m_ready; }
   bool RestorePending() { return m_saved; }
  };

#endif
