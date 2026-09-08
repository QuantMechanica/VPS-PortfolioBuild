#ifndef QM_STRATEGYCONSOLE_MQH
#define QM_STRATEGYCONSOLE_MQH

#include <QM/QM_ConsoleModel.mqh>

// Immutable snapshot references and presentation geometry, never decisions.
struct QM_ConsoleRenderRow
  {
   int kind;                         // 0 gates, 1 risk, 2 live, 3 performance, 4 summary
   int index;
   int second;
   int height;
   int page;
   int y;
   bool heading;
   string section;
  };

// Pure renderer: immutable snapshot in, owned chart objects out. Only chart
// geometry and screen DPI are read here, never account/history/filter/policy.
class CQMStrategyConsole
  {
private:
   long m_chart;
   string m_prefix;
   string m_used[];
   QM_ConsoleRenderRow m_rows[];
   QM_ConsoleSnapshot m_last_snapshot;
   bool m_has_snapshot,m_rendering,m_ready,m_ok;
   int m_scale,m_dpi,m_width,m_height,m_chart_width,m_chart_height,m_origin;
   int m_content_x,m_content_width;
   int m_pages,m_overview_page,m_performance_page;
   bool m_performance;
   QM_ConsoleMode m_mode;
   bool m_show_range,m_show_strategy,m_show_levels,m_show_markers;
   int m_level_label_y[];

   int Px(const int value) const { return (value*m_dpi*m_scale+4800)/9600; }
   int Logical(const int pixels) const { return (int)MathFloor(pixels*9600.0/(m_dpi*m_scale)); }
   // Pagination, not tiny fonts, solves short charts.
   int Font(const int value) const { return (int)MathMax(8,MathRound(value*m_scale/100.0)); }
   string Name(const string suffix) const { return m_prefix+suffix; }
   string DisplayText(const string text) const
     {
      string out="";
      for(int i=0;i<StringLen(text);++i)
        { const ushort c=StringGetCharacter(text,i); out+=ShortToString((ushort)(c>=32&&c!=127?c:32)); }
      return out;
     }
   color TextColor(const QM_ConsoleGateState state) const
     {
      // Blue on blue-soft misses AA at small sizes. Ink preserves legibility.
      return state==QM_GATE_WAIT?QM_COLOR_INK:QM_ConsoleGateColor(state);
     }
   int TextWidth(const string text,const int size,const bool bold=false) const
     {
      uint width=0,height=0;
      // MetaQuotes: -10 * OBJPROP_FONTSIZE matches OBJ_LABEL point geometry.
      if(TextSetFont(bold?QM_FONT_UI_BOLD:QM_FONT_UI,-10*Font(size),0) &&
         TextGetSize(DisplayText(text),width,height)) return (int)width;
      return (int)MathCeil(StringLen(text)*Font(size)*m_dpi/96.0);
     }
   int TextHeight(const int size,const bool bold=false) const
     {
      uint width=0,height=0;
      if(TextSetFont(bold?QM_FONT_UI_BOLD:QM_FONT_UI,-10*Font(size),0) &&
         TextGetSize("Ag",width,height)) return (int)height;
      return (int)MathCeil(Font(size)*m_dpi/72.0)+Px(3);
     }
   int TextLogicalHeight(const int size,const bool bold=false) const
     { return (int)MathCeil(TextHeight(size,bold)*9600.0/(m_dpi*m_scale)); }
   string Fit(const string text,const int logical_width,const int size,const bool bold=false) const
     {
      const string clean=DisplayText(text);
      const int available=Px((int)MathMax(0,logical_width))-Px(2);
      if(available<=0) return "";
      if(TextWidth(clean,size,bold)<=available) return clean;
      if(TextWidth("...",size,bold)>available) return "";
      int low=0,high=StringLen(clean);
      while(low<high)
        {
         const int mid=(low+high+1)/2;
         if(TextWidth(StringSubstr(clean,0,mid)+"...",size,bold)<=available) low=mid;
         else high=mid-1;
        }
      return StringSubstr(clean,0,low)+"...";
     }
   void Touch(const string name)
     { const int n=ArraySize(m_used); ArrayResize(m_used,n+1); m_used[n]=name; }
   bool Ensure(const string suffix,const ENUM_OBJECT kind)
     {
      const string name=Name(suffix); Touch(name);
      if(ObjectFind(m_chart,name)<0 && !ObjectCreate(m_chart,name,kind,0,0,0)) { m_ok=false; return false; }
      return true;
     }
   void I(const string suffix,const ENUM_OBJECT_PROPERTY_INTEGER prop,const long value)
     { if(!ObjectSetInteger(m_chart,Name(suffix),prop,value)) m_ok=false; }
   void S(const string suffix,const ENUM_OBJECT_PROPERTY_STRING prop,const string value)
     { if(!ObjectSetString(m_chart,Name(suffix),prop,value)) m_ok=false; }
   void Common(const string suffix,const int z)
     {
      I(suffix,OBJPROP_BACK,false); I(suffix,OBJPROP_SELECTABLE,false);
      I(suffix,OBJPROP_HIDDEN,true); I(suffix,OBJPROP_ZORDER,z);
     }
   bool Inside(const int x,const int y,const int width,const int height) const
     { return x>=0 && y>=0 && width>0 && height>0 && x+width<=m_width && y+height<=m_height; }
   void Rect(const string key,const int x,const int y,const int width,const int height,
              const color fill,const color border)
     {
      if(!Inside(x,y,width,height) || !Ensure(key,OBJ_RECTANGLE_LABEL)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_XDISTANCE,m_origin+Px(x));
      I(key,OBJPROP_YDISTANCE,m_origin+Px(y)); I(key,OBJPROP_XSIZE,Px(width)); I(key,OBJPROP_YSIZE,Px(height));
      I(key,OBJPROP_BGCOLOR,fill); I(key,OBJPROP_COLOR,border); I(key,OBJPROP_BORDER_TYPE,BORDER_FLAT); Common(key,900);
      S(key,OBJPROP_TOOLTIP,"\n");
     }
   void Label(const string key,const int x,const int y,const int width,const string value,
               const color tint=QM_COLOR_CARBON,const int size=9,const bool bold=false,const bool right=false)
     {
      const int text_height=TextHeight(size,bold);
      if(!Inside(x,y,width,1) || Px(y)+text_height>Px(m_height)) return;
      const string visible=Fit(value,width,size,bold);
      if(visible=="" || !Ensure(key,OBJ_LABEL)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_XDISTANCE,m_origin+Px(right?x+width:x));
      I(key,OBJPROP_YDISTANCE,m_origin+Px(y)); I(key,OBJPROP_ANCHOR,right?ANCHOR_RIGHT_UPPER:ANCHOR_LEFT_UPPER);
      I(key,OBJPROP_COLOR,tint); I(key,OBJPROP_FONTSIZE,Font(size)); Common(key,910);
      S(key,OBJPROP_FONT,bold?QM_FONT_UI_BOLD:QM_FONT_UI); S(key,OBJPROP_TEXT,visible); S(key,OBJPROP_TOOLTIP,DisplayText(value));
     }
   void Button(const string key,const int x,const int y,const int width,const int height,
                const string text,const string tooltip,const bool active=false)
     {
      if(!Inside(x,y,width,height) || !Ensure(key,OBJ_BUTTON)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_XDISTANCE,m_origin+Px(x));
      I(key,OBJPROP_YDISTANCE,m_origin+Px(y)); I(key,OBJPROP_XSIZE,Px(width)); I(key,OBJPROP_YSIZE,Px(height));
      I(key,OBJPROP_BGCOLOR,active?QM_COLOR_POSITIVE_SOFT:QM_COLOR_SURFACE);
      I(key,OBJPROP_BORDER_COLOR,active?QM_COLOR_QUANT_GREEN:QM_COLOR_BORDER);
      I(key,OBJPROP_COLOR,active?QM_COLOR_QUANT_GREEN_DARK:QM_COLOR_INK); I(key,OBJPROP_FONTSIZE,Font(9));
      S(key,OBJPROP_FONT,QM_FONT_UI); S(key,OBJPROP_TEXT,Fit(text,width-8,9)); S(key,OBJPROP_TOOLTIP,tooltip);
      Common(key,950); I(key,OBJPROP_STATE,false);
     }
   void Geometry()
     {
      m_dpi=(int)TerminalInfoInteger(TERMINAL_SCREEN_DPI); if(m_dpi<=0) m_dpi=96;
      m_chart_width=(int)ChartGetInteger(m_chart,CHART_WIDTH_IN_PIXELS,0);
      m_chart_height=(int)ChartGetInteger(m_chart,CHART_HEIGHT_IN_PIXELS,0);
      m_origin=8; // Physical safe inset, independent of DPI and user scale.
      const int desired_height=m_mode==QM_CONSOLE_FULL?428:(m_mode==QM_CONSOLE_COMPACT?232:132);
      const int available_width=Logical(m_chart_width-2*m_origin);
      m_height=(int)MathMax(0,MathMin(desired_height,Logical(m_chart_height-2*m_origin)));
      // OWNER: chart space takes precedence over a wide cockpit. Short charts
      // retain this narrow footprint and paginate; never widen on high DPI.
      const int desired_width=m_mode==QM_CONSOLE_FULL?416:(m_mode==QM_CONSOLE_COMPACT?360:320);
      m_width=(int)MathMax(0,MathMin(desired_width,available_width));
      m_content_x=12;
      m_content_width=m_width-m_content_x-12;
     }
   string ModeText() const
     { return m_mode==QM_CONSOLE_FULL?"Full":(m_mode==QM_CONSOLE_COMPACT?"Compact":"Minimal"); }
   int Header(const QM_ConsoleSnapshot &snapshot,const bool short_header)
     {
      const int mode_width=76,brand_width=m_width-mode_width-68;
      const int brand_size=m_width<360?13:14;
      if(brand_width>=180)
        {
         const int quant_width=(int)MathCeil(TextWidth("Quant",brand_size,true)*9600.0/(m_dpi*m_scale));
         Label("word_quant",16,8,quant_width+6,"Quant",QM_COLOR_CARBON,brand_size,true);
         Label("word_mechanica",16+quant_width,8,brand_width-quant_width,"Mechanica",QM_COLOR_QUANT_GREEN,brand_size,true);
        }
      else Label("word_quant",12,12,(int)MathMax(16,brand_width),"QM",QM_COLOR_QUANT_GREEN,14,true);
      Button("view",m_width-mode_width-12,7,mode_width,24,ModeText(),
         snapshot.strategy_name+" | "+snapshot.timeframe+"\nView: FULL > COMPACT > MINIMAL. Presentation only.");
      Button("design_version",m_width-mode_width-44,7,28,24,"01",
         "Switch to Design 2 - presentation only");
      if(short_header) return 36;
      const int module_y=8+TextLogicalHeight(brand_size,true)+1;
      const int strategy_y=module_y+TextLogicalHeight(8,true)+1;
      Label("module",16,module_y,m_width-32,"STRATEGY CONSOLE",QM_COLOR_SLATE,8,true);
      Label("strategy",16,strategy_y,m_width-32,snapshot.strategy_name+" | "+snapshot.timeframe,QM_COLOR_INK,10,true);
      return strategy_y+TextLogicalHeight(10,true)+3;
     }
   int StateCard(const QM_ConsoleSnapshot &snapshot,const int y)
     {
      QM_ConsoleGateState state=snapshot.state==QM_CONSOLE_BLOCKED || snapshot.state==QM_CONSOLE_ERROR?
         QM_GATE_BLOCK:(snapshot.state==QM_CONSOLE_INITIALIZING?QM_GATE_WAIT:QM_GATE_PASS);
      const string reason=snapshot.alert_reason!=""?snapshot.alert_reason:snapshot.reason;
      if(snapshot.alert_reason!="") state=snapshot.alert_state;
      const int reason_y=(int)MathMax(25,4+TextLogicalHeight(11,true)+1);
      const int next_y=(int)MathMax(41,reason_y+TextLogicalHeight(9)+1);
      const int meta_y=(int)MathMax(57,next_y+TextLogicalHeight(9)+1);
      const int needed=(int)MathMax(72,meta_y+TextLogicalHeight(8)+2);
      const int width=m_width-24,height=(int)MathMin(needed,m_height-y-8);
      if(width<=0 || height<=0) return y;
      Rect("state_bg",12,y,width,height,QM_ConsoleGateBackground(state),QM_COLOR_BORDER);
      Rect("state_accent",12,y,3,height,QM_ConsoleGateColor(state),QM_ConsoleGateColor(state));
      Label("state_headline",24,y+4,width-24,QM_ConsoleStateText(snapshot.state),QM_COLOR_INK,11,true);
      Label("state_reason",24,y+reason_y,width-24,reason,TextColor(state),9);
      Label("state_next",24,y+next_y,width-24,snapshot.next_event,QM_COLOR_SLATE,9);
      Label("state_meta",24,y+meta_y,width-24,snapshot.environment+" | "+snapshot.symbol+" | "+snapshot.timeframe,QM_COLOR_SLATE,8);
      return y+height;
     }
   void AddRow(const int kind,const int index,const int second,const int height,const string section)
     {
      const int n=ArraySize(m_rows); ArrayResize(m_rows,n+1);
      m_rows[n].kind=kind; m_rows[n].index=index; m_rows[n].second=second; m_rows[n].height=height;
      m_rows[n].section=section; m_rows[n].page=0; m_rows[n].y=0; m_rows[n].heading=false;
     }
   int LineHeight(const QM_ConsoleLine &line) const
     {
      const int inner=m_content_width-8,label_width=(int)(inner*0.38),value_width=inner-label_width-10;
      return TextWidth(line.label,9)<=Px(label_width)-Px(2) &&
             TextWidth(line.value,9)<=Px(value_width)-Px(2)?26:40;
     }
   int PagedLineHeight(const QM_ConsoleLine &line,const int budget) const
     {
      // The full string remains in the tooltip even when a very short page
      // needs one row. Do not create an unreachable 40-pixel row on a 26-pixel
      // page merely because a formatted amount happens to become longer.
      return budget<40?26:LineHeight(line);
     }
   int GateHeight() const
     { return (int)MathMax(30,TextLogicalHeight(9,true)+TextLogicalHeight(9)); }
   int HeadingHeight() const
     { return (int)MathMax(14,TextLogicalHeight(8,true)+1); }
   void BuildRows(const QM_ConsoleSnapshot &snapshot,const int budget)
     {
      ArrayResize(m_rows,0);
      if(m_performance)
        {
         for(int i=0;i<ArraySize(snapshot.performance);++i) AddRow(3,i,-1,PagedLineHeight(snapshot.performance[i],budget),"PERFORMANCE | THIS EA");
         return;
        }
      // Risk is the first overview group after the primary state: the OWNER's
      // compact monitoring view must expose next-trade/open risk immediately.
      for(int i=0;i<ArraySize(snapshot.risk);++i) AddRow(1,i,-1,PagedLineHeight(snapshot.risk[i],budget),"RISK");
      const int columns=m_content_width>=360?2:1;
      for(int i=0;i<ArraySize(snapshot.gates);i+=columns)
         AddRow(0,i,columns==2 && i+1<ArraySize(snapshot.gates)?i+1:-1,budget<GateHeight()?26:GateHeight(),"FILTER GATE");
      // Dynamic LIVE: exactly the real snapshot rows, no empty fixed slots.
      for(int i=0;i<ArraySize(snapshot.live);++i) AddRow(2,i,-1,PagedLineHeight(snapshot.live[i],budget),"LIVE");
      if(budget>=50) AddRow(4,0,-1,50,"");
      else { AddRow(5,0,-1,26,"TODAY / WEEK"); AddRow(6,0,-1,26,"TODAY / WEEK"); }
     }
   void Paginate(const int top,const int bottom)
     {
      const int budget=(int)MathMax(0,bottom-top);
      int page=0,used=0; string previous="";
      for(int i=0;i<ArraySize(m_rows);++i)
        {
         int heading=m_rows[i].section!="" && m_rows[i].section!=previous?HeadingHeight():0;
         if(used>0 && used+heading+m_rows[i].height>budget)
           { ++page; used=0; previous=""; heading=m_rows[i].section!=""?HeadingHeight():0; }
         // A short viewport may omit a repeated heading, never part of a row.
         if(heading+m_rows[i].height>budget) heading=0;
         m_rows[i].page=m_rows[i].height<=budget?page:-1; m_rows[i].heading=heading>0;
         m_rows[i].y=top+used; used+=heading+m_rows[i].height; previous=m_rows[i].section;
        }
      m_pages=(int)MathMax(1,page+1);
      if(m_performance) m_performance_page=(int)MathMax(0,MathMin(m_performance_page,m_pages-1));
      else m_overview_page=(int)MathMax(0,MathMin(m_overview_page,m_pages-1));
     }
   void Gate(const string key,const QM_ConsoleGate &gate,const int x,const int y,const int width,const int height)
     {
      const int chip_width=44;
      if(height>=GateHeight())
        {
         Label(key+"_label",x,y,width-chip_width-8,gate.label,QM_COLOR_INK,9,true);
         Label(key+"_reason",x,y+TextLogicalHeight(9,true),width-chip_width-8,gate.reason,QM_COLOR_SLATE,9);
        }
      else Label(key+"_reason",x,y+5,width-chip_width-8,gate.label+" - "+gate.reason,QM_COLOR_INK,9);
      Rect(key+"_chip",x+width-chip_width,y+4,chip_width,22,QM_ConsoleGateBackground(gate.state),QM_ConsoleGateBackground(gate.state));
      Label(key+"_state",x+width-chip_width+3,y+7,chip_width-6,QM_ConsoleGateText(gate.state),TextColor(gate.state),9,true,true);
     }
   void Line(const string key,const QM_ConsoleLine &line,const int y,const int height)
     {
      const int x=m_content_x+4,inner=m_content_width-8,label_width=(int)(inner*0.38);
      if(height<=26)
        {
         Label(key+"_label",x,y+4,label_width,line.label,QM_COLOR_SLATE,9);
         Label(key+"_value",x+label_width+10,y+4,inner-label_width-10,line.value,TextColor(line.state),9,false,true);
        }
      else
        {
         Label(key+"_label",x,y+1,inner,line.label,QM_COLOR_SLATE,9);
         Label(key+"_value",x,y+18,inner,line.value,TextColor(line.state),9);
        }
      Rect(key+"_rule",x,y+height-3,inner,1,QM_COLOR_BORDER,QM_COLOR_BORDER);
     }
   void Summary(const QM_ConsoleSnapshot &snapshot,const int y,const bool in_body=false)
     {
      const int x=in_body?m_content_x:12,inner=in_body?m_content_width:m_width-24;
      if(!Inside(x,y,inner,44)) return;
      Rect("strip",x,y,inner,44,QM_COLOR_CLOUD,QM_COLOR_BORDER);
      const int half=(inner-24)/2;
      Rect("strip_rule",x+inner/2,y+8,1,28,QM_COLOR_BORDER,QM_COLOR_BORDER);
      Label("today_label",x+12,y+5,half-8,"Today",QM_COLOR_INK,9,true);
      Label("today",x+12,y+23,half-8,snapshot.today,QM_COLOR_SLATE,9);
      Label("week_label",x+inner/2+12,y+5,half-8,"Week",QM_COLOR_INK,9,true);
      Label("week",x+inner/2+12,y+23,half-8,snapshot.week,QM_COLOR_SLATE,9);
     }
   void Body(const QM_ConsoleSnapshot &snapshot,const int top,const int bottom)
     {
      BuildRows(snapshot,bottom-top); Paginate(top,bottom);
      const int selected=m_performance?m_performance_page:m_overview_page;
      bool drawn=false;
      for(int i=0;i<ArraySize(m_rows);++i)
        {
         const QM_ConsoleRenderRow row=m_rows[i]; if(row.page!=selected) continue;
         int y=row.y;
         if(row.heading)
           { Label("section_"+IntegerToString(i),m_content_x+4,y,m_content_width-8,row.section,QM_COLOR_SLATE,8,true); y+=HeadingHeight(); }
         if(y+row.height>bottom) continue;
         const string key="row_"+IntegerToString(i);
         if(row.kind==0)
           {
            const int gap=12,width=m_content_width>=360?(m_content_width-8-gap)/2:m_content_width-8;
            Gate(key+"_a",snapshot.gates[row.index],m_content_x+4,y,width,row.height);
            if(row.second>=0) Gate(key+"_b",snapshot.gates[row.second],m_content_x+4+width+gap,y,width,row.height);
           }
         else if(row.kind==1) Line(key,snapshot.risk[row.index],y,row.height);
         else if(row.kind==2) Line(key,snapshot.live[row.index],y,row.height);
         else if(row.kind==3) Line(key,snapshot.performance[row.index],y,row.height);
         else if(row.kind==4) Summary(snapshot,y,true);
         else
           {
            QM_ConsoleLine summary; summary.label=row.kind==5?"Today":"Week";
            summary.value=row.kind==5?snapshot.today:snapshot.week; summary.state=QM_GATE_NA;
            Line(key,summary,y,row.height);
           }
         drawn=true;
        }
      if(!drawn) Label("body_empty",m_content_x+4,top,m_content_width-8,ArraySize(m_rows)==0?"No performance observations yet":"Enlarge chart to view details",QM_COLOR_SLATE,8);
     }
   void Footer(const QM_ConsoleSnapshot &snapshot,const bool pages)
     {
      const int y=m_height-28; if(y<0) return;
      Rect("footer_rule",12,y-5,m_width-24,1,QM_COLOR_BORDER,QM_COLOR_BORDER);
      Label("footer",16,y+4,m_width-32-(pages?116:0),"© QuantMechanica  v"+snapshot.version,QM_COLOR_SLATE,8);
      if(pages)
        {
         const int page=m_performance?m_performance_page:m_overview_page;
         Label("page_number",m_width-91,y+4,46,IntegerToString(page+1)+" / "+IntegerToString(m_pages),QM_COLOR_SLATE,9,false,true);
         Button("previous",m_width-126,y,28,22,"<","Previous complete page");
         Button("next",m_width-40,y,28,22,">","Next complete page");
        }
     }
   bool OverlayEndpoint(datetime &when,int &label_x)
     {
      label_x=m_chart_width-Px(72);
      if(label_x<=m_origin+Px(m_width)+Px(24)) return false;
      int window=0; double price=0.0;
      return ChartXYToTimePrice(m_chart,label_x,m_chart_height/2,window,when,price) && window==0;
     }
   void PriceLabel(const string key,const datetime when,const double price,const string text,const color tint,const int label_x)
     {
      int x=0,y=0;
      if(price<=0.0 || !ChartTimePriceToXY(m_chart,0,when,price,x,y)) return;
      const int label_height=Px(18);
      // Off-screen prices are not pinned to an unrelated visible edge price.
      if(y<0 || y>=m_chart_height) return;
      y=(int)MathMax(2,MathMin(y-label_height,m_chart_height-label_height-2));
      // Recheck after each displacement: a later SL/TP label must not land on
      // an earlier range label that was already visited in the first pass.
      for(int pass=0;pass<=ArraySize(m_level_label_y);++pass)
        {
         bool collision=false;
         for(int i=0;i<ArraySize(m_level_label_y);++i)
            if(MathAbs(y-m_level_label_y[i])<label_height)
              { y=m_level_label_y[i]-label_height; collision=true; break; }
         if(!collision || y<2) break;
        }
      if(y<2 || y+label_height>=m_chart_height) return;
      const int n=ArraySize(m_level_label_y); ArrayResize(m_level_label_y,n+1); m_level_label_y[n]=y;
      if(!Ensure(key,OBJ_LABEL)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_XDISTANCE,label_x); I(key,OBJPROP_YDISTANCE,y);
      I(key,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); I(key,OBJPROP_COLOR,tint); I(key,OBJPROP_FONTSIZE,Font(8)); Common(key,10);
      const int room=Logical(label_x-m_origin-Px(m_width)-Px(16));
      S(key,OBJPROP_FONT,QM_FONT_UI); S(key,OBJPROP_TEXT,Fit(text,room,8)); S(key,OBJPROP_TOOLTIP,DisplayText(text));
     }
   void Level(const string key,const datetime start,const datetime end,const double price,const string text,const color tint,const int label_x)
     {
      if(price<=0.0 || start<=0 || end<=0) return;
      // An intrabar execution can be later than the right-edge D1 bar time.
      // A reverse horizontal leader is valid; never suppress its price label
      // or invent a future trading timestamp solely to make it visible.
      if(start!=end && Ensure(key+"_line",OBJ_TREND))
        {
         if(!ObjectMove(m_chart,Name(key+"_line"),0,start,price) || !ObjectMove(m_chart,Name(key+"_line"),1,end,price)) m_ok=false;
         I(key+"_line",OBJPROP_COLOR,tint); I(key+"_line",OBJPROP_STYLE,STYLE_DASH); I(key+"_line",OBJPROP_WIDTH,1);
         I(key+"_line",OBJPROP_RAY_LEFT,false); I(key+"_line",OBJPROP_RAY_RIGHT,false); Common(key+"_line",1); I(key+"_line",OBJPROP_BACK,true);
         S(key+"_line",OBJPROP_TOOLTIP,DisplayText(text));
        }
      PriceLabel(key+"_label",end,price,text,tint,label_x);
     }
   void Overlay(const QM_ConsoleSnapshot &snapshot)
     {
      ArrayResize(m_level_label_y,0);
      datetime end=0; int label_x=0; const bool endpoint=OverlayEndpoint(end,label_x);
      if(snapshot.active_range && m_show_range)
        {
         const string key="range";
         if(Ensure(key,OBJ_RECTANGLE))
           {
            if(!ObjectMove(m_chart,Name(key),0,snapshot.range_start,snapshot.range_high) || !ObjectMove(m_chart,Name(key),1,snapshot.range_end,snapshot.range_low)) m_ok=false;
            I(key,OBJPROP_COLOR,QM_COLOR_RANGE_FILL); I(key,OBJPROP_FILL,true); Common(key,1); I(key,OBJPROP_BACK,true); S(key,OBJPROP_TOOLTIP,"Active strategy range");
           }
        }
      if(snapshot.active_range && m_show_strategy && endpoint)
        {
         const string high=snapshot.range_high_text!=""?snapshot.range_high_text:DoubleToString(snapshot.range_high,5);
         const string low=snapshot.range_low_text!=""?snapshot.range_low_text:DoubleToString(snapshot.range_low,5);
         Level("range_high",snapshot.range_start,end,snapshot.range_high,"Range High "+high,QM_COLOR_SLATE,label_x);
         Level("range_low",snapshot.range_start,end,snapshot.range_low,"Range Low "+low,QM_COLOR_SLATE,label_x);
        }
      for(int i=0;i<ArraySize(snapshot.exposure);++i)
        {
         const QM_ConsoleExposure e=snapshot.exposure[i]; if(e.symbol!=snapshot.symbol) continue;
         const string key="trade_"+StringFormat("%I64u",e.ticket);
         if(m_show_levels && endpoint)
           {
            const string entry=e.pending?(e.buy?"Buy Trigger ":"Sell Trigger "):(e.buy?"Buy Entry ":"Sell Entry ");
            Level(key+"_entry",e.opened,end,e.entry,entry+e.entry_text,QM_COLOR_INK,label_x);
            Level(key+"_sl",e.opened,end,e.sl,"SL "+e.sl_text,QM_COLOR_NEGATIVE,label_x);
            Level(key+"_tp",e.opened,end,e.tp,"TP "+e.tp_text,QM_COLOR_POSITIVE,label_x);
           }
         if(m_show_markers && !e.pending)
           {
            const string mark=key+"_marker";
            if(Ensure(mark,e.buy?OBJ_ARROW_BUY:OBJ_ARROW_SELL))
              {
               if(!ObjectMove(m_chart,Name(mark),0,e.opened,e.entry)) m_ok=false;
               I(mark,OBJPROP_COLOR,e.buy?QM_COLOR_POSITIVE:QM_COLOR_NEGATIVE); Common(mark,1); I(mark,OBJPROP_BACK,true);
              }
           }
        }
     }
   void RemoveUnused()
     {
      for(int i=ObjectsTotal(m_chart)-1;i>=0;--i)
        {
         const string name=ObjectName(m_chart,i); if(StringFind(name,m_prefix)!=0) continue;
         bool used=false;
         for(int j=0;j<ArraySize(m_used);++j) if(m_used[j]==name) { used=true; break; }
         if(!used) ObjectDelete(m_chart,name);
        }
     }

public:
   CQMStrategyConsole()
     {
      m_chart=0; m_prefix=""; m_ready=false; m_ok=true; m_scale=100; m_dpi=96;
      m_mode=QM_CONSOLE_FULL; m_show_range=true; m_show_strategy=true; m_show_levels=true; m_show_markers=true;
      m_width=0; m_height=0; m_chart_width=0; m_chart_height=0; m_origin=8;
      m_content_x=12; m_content_width=0;
      m_pages=1; m_overview_page=0; m_performance_page=0; m_performance=false; m_has_snapshot=false; m_rendering=false;
     }
   bool Initialize(const long chart,const string prefix,const bool enabled,const QM_ConsoleMode mode,
                    const int scale,const bool show_range,const bool show_strategy,const bool show_levels,const bool show_markers)
     {
      if(!enabled || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0 || prefix=="") return false;
      m_chart=chart; m_prefix=prefix; m_mode=mode; m_scale=(int)MathMax(80,MathMin(150,scale));
      m_show_range=show_range; m_show_strategy=show_strategy; m_show_levels=show_levels; m_show_markers=show_markers;
      m_overview_page=0; m_performance_page=0; m_performance=false; m_has_snapshot=false; m_ready=true; return true;
     }
   bool Ready() const { return m_ready; }
   QM_ConsoleMode Mode() const { return m_mode; }
   int PanelRightPixels() const { return m_origin+Px(m_width); }
   void OnChartEvent(const int id,const string object_name)
     {
      if(!m_ready || m_rendering) return;
      bool repaint=id==CHARTEVENT_CHART_CHANGE;
      if(id==CHARTEVENT_OBJECT_CLICK)
        {
         if(object_name==Name("view")) { m_mode=QM_ConsoleNextMode(m_mode); repaint=true; }
         else if(object_name==Name("tab_overview")) { m_performance=false; repaint=true; }
         else if(object_name==Name("tab_performance")) { m_performance=true; repaint=true; }
         else if(object_name==Name("previous") || object_name==Name("next"))
           {
            const int delta=object_name==Name("next")?1:-1;
            if(m_performance) m_performance_page=(int)MathMax(0,MathMin(m_performance_page+delta,m_pages-1));
            else m_overview_page=(int)MathMax(0,MathMin(m_overview_page+delta,m_pages-1));
            repaint=true;
           }
        }
      // Immediate feedback from a cached immutable snapshot. No data refresh.
      if(repaint && m_has_snapshot) Render(m_last_snapshot);
     }
   void Render(const QM_ConsoleSnapshot &snapshot)
     {
      if(!m_ready || m_rendering || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0) return;
      m_rendering=true;
      // A View/resize event passes the cache itself. Copy through a temporary
      // so nested dynamic arrays never depend on self-assignment behavior.
      QM_ConsoleSnapshot stable_snapshot=snapshot;
      m_last_snapshot=stable_snapshot; m_has_snapshot=true;
      ArrayResize(m_used,0); m_ok=true; Geometry();
      if(m_width>=120 && m_height>=100)
        {
         Rect("bg",0,0,m_width,m_height,QM_COLOR_SURFACE,QM_COLOR_BORDER_STRONG);
         const bool short_header=m_mode==QM_CONSOLE_MINIMAL || (m_mode==QM_CONSOLE_FULL && m_height<300);
         const int state_y=Header(snapshot,short_header),state_end=StateCard(snapshot,state_y);
         if(m_mode==QM_CONSOLE_FULL && m_height>=205)
           {
            const int tabs_y=state_end+3,tab_width=(m_content_width-8)/2;
            Button("tab_overview",m_content_x,tabs_y,tab_width,22,"Overview","Risk, real admission gates, live exposure and today/week",!m_performance);
            Button("tab_performance",m_content_x+8+tab_width,tabs_y,tab_width,22,"Performance","All cached performance rows for this EA",m_performance);
            Body(snapshot,tabs_y+24,m_height-35); Footer(snapshot,true);
           }
         else if(m_mode==QM_CONSOLE_COMPACT && state_end+52<=m_height-35)
           { Summary(snapshot,state_end+8); Footer(snapshot,false); }
         else if(m_mode!=QM_CONSOLE_MINIMAL && state_end+40<=m_height) Footer(snapshot,false);
        }
      Overlay(snapshot); RemoveUnused();
      if(!m_ok)
        {
         ObjectsDeleteAll(m_chart,m_prefix); m_ready=false;
         Print("QM_CONSOLE_RENDER_DISABLED: chart object update failed; trading unaffected");
        }
      ChartRedraw(m_chart); m_rendering=false;
     }
   void Shutdown()
     {
      if(m_prefix!="") { ObjectsDeleteAll(m_chart,m_prefix); ChartRedraw(m_chart); }
      m_ready=false; m_has_snapshot=false;
     }
  };

#endif
