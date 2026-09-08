#ifndef QM_STRATEGYCONSOLEV2_MQH
#define QM_STRATEGYCONSOLEV2_MQH

#include <QM/QM_ConsoleModel.mqh>

// Immutable snapshot references and presentation geometry, never decisions.
struct QM_ConsoleV2Row
  {
   int kind;                         // Explicit display row kind; no policy data
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
class CQMStrategyConsoleV2
  {
private:
   long m_chart;
   string m_prefix;
   string m_used[];
   QM_ConsoleV2Row m_rows[];
   QM_ConsoleSnapshot m_last_snapshot;
   bool m_has_snapshot,m_rendering,m_ready,m_ok;
   int m_scale,m_dpi,m_width,m_height,m_chart_width,m_chart_height,m_origin;
   int m_content_x,m_content_width;
   int m_pages,m_tab;
   int m_tab_page[3];
   QM_ConsoleMode m_mode;

   int Px(const int value) const { return (value*m_dpi*m_scale+4800)/9600; }
   int Logical(const int pixels) const { return (int)MathFloor(pixels*9600.0/(m_dpi*m_scale)); }
   // Pagination, not tiny fonts, solves short charts.
   int Font(const int value) const { return (int)MathMax(8,MathRound(value*m_scale/100.0)); }
   string Name(const string suffix) const { return m_prefix+suffix; }
   string DisplayText(const string text) const
     {
      string out="";
      for(int i=0;i<StringLen(text);++i)
        { const ushort c=StringGetCharacter(text,i); out+=ShortToString((ushort)(c>=32 && !(c>=127&&c<=159)?c:32)); }
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
      const string ellipsis=ShortToString(0x2026);
      const int available=Px((int)MathMax(0,logical_width))-Px(2);
      if(available<=0) return "";
      if(TextWidth(clean,size,bold)<=available) return clean;
      if(TextWidth(ellipsis,size,bold)>available) return "";
      int low=0,high=StringLen(clean);
      while(low<high)
        {
         const int mid=(low+high+1)/2;
         if(TextWidth(StringSubstr(clean,0,mid)+ellipsis,size,bold)<=available) low=mid;
         else high=mid-1;
        }
      return StringSubstr(clean,0,low)+ellipsis;
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
      I(key,OBJPROP_BGCOLOR,active?QM_COLOR_SURFACE:QM_COLOR_CLOUD);
      I(key,OBJPROP_BORDER_COLOR,active?QM_COLOR_SURFACE:QM_COLOR_CLOUD);
      I(key,OBJPROP_COLOR,active?QM_COLOR_QUANT_GREEN_DARK:QM_COLOR_INK); I(key,OBJPROP_FONTSIZE,Font(9));
      S(key,OBJPROP_FONT,active?QM_FONT_UI_BOLD:QM_FONT_UI); S(key,OBJPROP_TEXT,Fit(text,width-8,9,active)); S(key,OBJPROP_TOOLTIP,tooltip);
      Common(key,950); I(key,OBJPROP_STATE,false);
     }
   void Geometry()
     {
      m_dpi=(int)TerminalInfoInteger(TERMINAL_SCREEN_DPI); if(m_dpi<=0) m_dpi=96;
      m_chart_width=(int)ChartGetInteger(m_chart,CHART_WIDTH_IN_PIXELS,0);
      m_chart_height=(int)ChartGetInteger(m_chart,CHART_HEIGHT_IN_PIXELS,0);
      m_origin=8;
      const int desired_width=m_mode==QM_CONSOLE_FULL?384:(m_mode==QM_CONSOLE_COMPACT?336:304);
      const int minimum=MinimumPanelHeight();
      const int desired_height=m_mode==QM_CONSOLE_FULL?390:(m_mode==QM_CONSOLE_COMPACT?(int)MathMax(214,minimum):(int)MathMax(164,minimum));
      m_width=(int)MathMax(0,MathMin(desired_width,Logical(m_chart_width-2*m_origin)));
      m_height=(int)MathMax(0,MathMin(desired_height,Logical(m_chart_height-2*m_origin)));
      m_content_x=12; m_content_width=m_width-24;
     }
   int MinimumPanelHeight() const
     {
      const int header=8+TextLogicalHeight(m_mode==QM_CONSOLE_FULL?14:13,true)+4+TextLogicalHeight(9)+6;
      const int state=6+TextLogicalHeight(11,true)+3+2*TextLogicalHeight(9)+3+4;
      return header+state+42;
     }
   string Dot() const { return " "+ShortToString(0x00B7)+" "; }
   string Copyright() const { return ShortToString(0x00A9)+" QuantMechanica"; }
   string ModeText() const
     { return m_mode==QM_CONSOLE_FULL?"Full":(m_mode==QM_CONSOLE_COMPACT?"Compact":"Minimal"); }
   int Header(const QM_ConsoleSnapshot &snapshot,const bool short_header)
     {
      const int size=m_mode==QM_CONSOLE_FULL?14:13;
      const int view_x=m_width-78;
      const int quant_width=(int)MathCeil(TextWidth("Quant",size,true)*9600.0/(m_dpi*m_scale));
      const int brand_room=view_x-48;
      if(brand_room>=150)
        {
         Label("word_quant",14,8,quant_width+6,"Quant",QM_COLOR_INK,size,true);
         Label("word_mechanica",14+quant_width,8,brand_room-quant_width,"Mechanica",QM_COLOR_QUANT_GREEN,size,true);
        }
      else Label("word_quant",14,9,(int)MathMax(20,brand_room),"QM",QM_COLOR_QUANT_GREEN,13,true);
      Button("design_version",view_x-32,10,26,20,"02",
         "Switch to Design 1"+Dot()+"presentation only");
      Button("view",view_x,8,66,24,ModeText(),snapshot.strategy_name+Dot()+snapshot.timeframe+
         "\nConsole 02. View: FULL > COMPACT > MINIMAL. Presentation only.");
      int y=8+TextLogicalHeight(size,true)+4;
      if(!short_header)
        {
         Label("strategy",14,y,m_width-28,snapshot.strategy_name,QM_COLOR_INK,10,true);
         y+=TextLogicalHeight(10,true)+3;
        }
      Label("instrument",14,y,m_width-28,snapshot.symbol+Dot()+snapshot.timeframe+Dot()+snapshot.environment,QM_COLOR_SLATE,9);
      return y+TextLogicalHeight(9)+6;
     }
   int StateCard(const QM_ConsoleSnapshot &snapshot,const int y)
     {
      QM_ConsoleGateState state=snapshot.state==QM_CONSOLE_BLOCKED || snapshot.state==QM_CONSOLE_ERROR?
         QM_GATE_BLOCK:(snapshot.state==QM_CONSOLE_INITIALIZING?QM_GATE_WAIT:QM_GATE_PASS);
      const string reason=snapshot.alert_reason!=""?snapshot.alert_reason:snapshot.reason;
      if(snapshot.alert_reason!="") state=snapshot.alert_state;
      const int reason_y=6+TextLogicalHeight(11,true)+3;
      const int next_y=reason_y+TextLogicalHeight(9)+3;
      const int height=next_y+TextLogicalHeight(9)+4;
      Rect("state_bg",12,y,m_width-24,height,QM_COLOR_SURFACE,QM_COLOR_BORDER);
      Rect("state_accent",12,y,3,height,QM_ConsoleGateColor(state),QM_ConsoleGateColor(state));
      Label("state_headline",24,y+6,m_width-48,QM_ConsoleStateText(snapshot.state),QM_COLOR_INK,11,true);
      Label("state_reason",24,y+reason_y,m_width-48,reason,TextColor(state),9);
      Label("state_next",24,y+next_y,m_width-48,snapshot.next_event,QM_COLOR_SLATE,9);
      return y+height;
     }
   void Parts(const string value,string &primary,string &secondary) const
     {
      // This is typography only: split the producer's formatted fields. No
      // numeric interpretation or admission decision is made from the text.
      const int divider=StringFind(value," | ");
      primary=divider>=0?StringSubstr(value,0,divider):value;
      secondary=divider>=0?StringSubstr(value,divider+3):"";
     }
   int KpiHeight() const
     { return 6+TextLogicalHeight(9)+3+TextLogicalHeight(14,true)+2+TextLogicalHeight(9)+8; }
   bool KpiFits(const QM_ConsoleLine &line,const int width) const
     {
      string primary="",secondary=""; Parts(line.value,primary,secondary);
      return TextWidth(line.label,9)<=Px(width-20) &&
         TextWidth(primary,14,true)<=Px(width-20) &&
         TextWidth(secondary,9)<=Px(width-20);
     }
   void Kpi(const string key,const QM_ConsoleLine &line,const int x,const int y,const int width)
     {
      string primary="",secondary=""; Parts(line.value,primary,secondary);
      Rect(key+"_surface",x,y,width,KpiHeight()-4,QM_COLOR_CLOUD,QM_COLOR_CLOUD);
      Label(key+"_label",x+10,y+6,width-20,line.label,QM_COLOR_SLATE,9);
      const int value_y=y+6+TextLogicalHeight(9)+3;
      Label(key+"_value",x+10,value_y,width-20,primary,QM_COLOR_INK,14,true);
      Label(key+"_secondary",x+10,value_y+TextLogicalHeight(14,true)+2,width-20,secondary,QM_COLOR_SLATE,9);
      S(key+"_surface",OBJPROP_TOOLTIP,DisplayText(line.label+Dot()+line.value));
     }
   int LineHeight(const QM_ConsoleLine &line,const int budget) const
     {
      const int inner=m_content_width-4,label_width=(int)(inner*0.38),value_width=inner-label_width-10;
      const int one=(int)MathMax(28,TextLogicalHeight(9)+10);
      const int two=TextLogicalHeight(9)+TextLogicalHeight(9)+9;
      if(budget<two) return one;
      return TextWidth(line.label,9)<=Px(label_width)-Px(2) &&
         TextWidth(line.value,9)<=Px(value_width)-Px(2)?one:two;
     }
   void Line(const string key,const QM_ConsoleLine &line,const int y,const int height)
     {
      const int x=m_content_x+2,inner=m_content_width-4,label_width=(int)(inner*0.38);
      const int one=(int)MathMax(28,TextLogicalHeight(9)+10);
      if(height<=one)
        {
         Label(key+"_label",x,y+5,label_width,line.label,QM_COLOR_SLATE,9);
         Label(key+"_value",x+label_width+10,y+5,inner-label_width-10,line.value,TextColor(line.state),9,false,true);
        }
      else
        {
         Label(key+"_label",x,y+2,inner,line.label,QM_COLOR_SLATE,9);
         Label(key+"_value",x,y+TextLogicalHeight(9)+5,inner,line.value,TextColor(line.state),9);
        }
      Rect(key+"_rule",x,y+height-2,inner,1,QM_COLOR_BORDER,QM_COLOR_BORDER);
     }
   string GateCounts(const QM_ConsoleSnapshot &snapshot) const
     {
      int counts[8]; ArrayInitialize(counts,0);
      for(int i=0;i<ArraySize(snapshot.gates);++i)
        {
         const int state=(int)snapshot.gates[i].state;
         if(state>=0 && state<8) ++counts[state];
        }
      string result="";
      // Explicit state counts, not an admission decision or an all-clear badge.
      int order[8]={0,1,6,7,2,5,3,4};
      for(int i=0;i<8;++i)
         if(counts[order[i]]>0)
           {
            if(result!="") result+=Dot();
            result+=IntegerToString(counts[order[i]])+" "+QM_ConsoleGateText((QM_ConsoleGateState)order[i]);
           }
      return result!=""?result:"No admission gates reported";
     }
   int GateSingleHeight() const
     { return (int)MathMax(21,MathMax(TextLogicalHeight(9),TextLogicalHeight(9,true))+6); }
   int GateHeight(const QM_ConsoleGate &gate,const int budget) const
     {
      const int text_width=m_content_width-60;
      const string value=gate.label+Dot()+gate.reason;
      const int one=GateSingleHeight();
      const int two=TextLogicalHeight(9,true)+TextLogicalHeight(9)+6;
      return budget<two || TextWidth(value,9)<=Px(text_width)-Px(2)?one:two;
     }
   void Gate(const string key,const QM_ConsoleGate &gate,const int y,const int height)
     {
      const int x=m_content_x+2,width=m_content_width-4,chip=44;
      const int one=GateSingleHeight();
      if(height<=one)
         Label(key+"_reason",x,y+3,width-chip-12,gate.label+Dot()+gate.reason,QM_COLOR_INK,9);
      else
        {
         Label(key+"_label",x,y+1,width-chip-12,gate.label,QM_COLOR_INK,9,true);
         Label(key+"_reason",x,y+TextLogicalHeight(9,true)+3,width-chip-12,gate.reason,QM_COLOR_SLATE,9);
        }
      const int chip_height=(int)MathMax(19,TextLogicalHeight(9,true)+4);
      Rect(key+"_chip",x+width-chip,y+1,chip,chip_height,QM_ConsoleGateBackground(gate.state),QM_ConsoleGateBackground(gate.state));
      Label(key+"_state",x+width-chip+3,y+3,chip-6,QM_ConsoleGateText(gate.state),TextColor(gate.state),9,true,true);
     }
   int SummaryHeight() const { return (int)MathMax(46,TextLogicalHeight(9)*2+15); }
   void Summary(const QM_ConsoleSnapshot &snapshot,const int y)
     {
      const int x=m_content_x,width=m_content_width,half=(width-12)/2;
      const int height=SummaryHeight()-2;
      Rect("summary_surface",x,y,width,height,QM_COLOR_CLOUD,QM_COLOR_CLOUD);
      Rect("summary_divider",x+width/2,y+8,1,height-16,QM_COLOR_BORDER,QM_COLOR_BORDER);
      string today_primary="",today_secondary="",week_primary="",week_secondary="";
      Parts(snapshot.today,today_primary,today_secondary); Parts(snapshot.week,week_primary,week_secondary);
      Label("today_label",x+10,y+5,half-16,"Today"+(today_secondary!=""?Dot()+today_primary:""),QM_COLOR_SLATE,9);
      Label("today",x+10,y+TextLogicalHeight(9)+8,half-16,today_secondary!=""?today_secondary:today_primary,QM_COLOR_INK,9,true);
      Label("week_label",x+width/2+10,y+5,half-16,"Week"+(week_secondary!=""?Dot()+week_primary:""),QM_COLOR_SLATE,9);
      Label("week",x+width/2+10,y+TextLogicalHeight(9)+8,half-16,week_secondary!=""?week_secondary:week_primary,QM_COLOR_INK,9,true);
      S("summary_surface",OBJPROP_TOOLTIP,DisplayText("Today "+snapshot.today+"; Week "+snapshot.week));
     }
   void AddRow(const int kind,const int index,const int second,const int height,const string section="")
     {
      const int n=ArraySize(m_rows); ArrayResize(m_rows,n+1);
      m_rows[n].kind=kind; m_rows[n].index=index; m_rows[n].second=second;
      m_rows[n].height=height; m_rows[n].section=section;
      m_rows[n].page=0; m_rows[n].y=0; m_rows[n].heading=false;
     }
   void BuildRows(const QM_ConsoleSnapshot &snapshot,const int budget)
     {
      ArrayResize(m_rows,0);
      if(m_tab==1)
        {
         for(int i=0;i<ArraySize(snapshot.gates);++i)
            AddRow(5,i,-1,GateHeight(snapshot.gates[i],budget));
         return;
        }
      if(m_tab==2)
        {
         for(int i=0;i<ArraySize(snapshot.performance);++i)
            AddRow(6,i,-1,LineHeight(snapshot.performance[i],budget));
         return;
        }
      int first=0;
      const int half=(m_content_width-12)/2;
      if(ArraySize(snapshot.risk)>=2 && KpiHeight()<=budget &&
         KpiFits(snapshot.risk[0],half) && KpiFits(snapshot.risk[1],half))
        { AddRow(0,0,1,KpiHeight()); first=2; }
      for(int i=first;i<ArraySize(snapshot.risk);++i)
         AddRow(1,i,-1,LineHeight(snapshot.risk[i],budget));
      for(int i=0;i<ArraySize(snapshot.live);++i)
         AddRow(2,i,-1,LineHeight(snapshot.live[i],budget),"LIVE");
      // Counts live in the footer; they never create a details-only extra page.
      if(SummaryHeight()<=budget) AddRow(3,0,-1,SummaryHeight());
      else { AddRow(7,0,-1,(int)MathMax(28,TextLogicalHeight(9)+10)); AddRow(8,0,-1,(int)MathMax(28,TextLogicalHeight(9)+10)); }
     }
   int HeadingHeight() const { return TextLogicalHeight(9,true)+3; }
   void Paginate(const int top,const int bottom)
     {
      const int budget=(int)MathMax(0,bottom-top);
      int page=0,used=0; string previous="";
      for(int i=0;i<ArraySize(m_rows);++i)
        {
         int heading=m_rows[i].section!="" && m_rows[i].section!=previous?HeadingHeight():0;
         if(used>0 && used+heading+m_rows[i].height>budget)
           { ++page; used=0; previous=""; heading=m_rows[i].section!=""?HeadingHeight():0; }
         if(heading+m_rows[i].height>budget) heading=0;
         m_rows[i].page=m_rows[i].height<=budget?page:-1;
         m_rows[i].heading=heading>0; m_rows[i].y=top+used;
         used+=heading+m_rows[i].height; previous=m_rows[i].section;
        }
      m_pages=(int)MathMax(1,page+1);
      m_tab_page[m_tab]=(int)MathMax(0,MathMin(m_tab_page[m_tab],m_pages-1));
     }
   void Body(const QM_ConsoleSnapshot &snapshot,const int top,const int bottom)
     {
      BuildRows(snapshot,bottom-top); Paginate(top,bottom);
      bool drawn=false;
      for(int i=0;i<ArraySize(m_rows);++i)
        {
         const QM_ConsoleV2Row row=m_rows[i]; if(row.page!=m_tab_page[m_tab]) continue;
         int y=row.y;
         if(row.heading)
           { Label("section_"+IntegerToString(i),m_content_x+2,y,m_content_width-4,row.section,QM_COLOR_SLATE,9,true); y+=HeadingHeight(); }
         if(y+row.height>bottom) continue;
         const string key="row_"+IntegerToString(i);
         if(row.kind==0)
           {
            const int half=(m_content_width-12)/2;
            Kpi(key+"_a",snapshot.risk[row.index],m_content_x,y,half);
            Kpi(key+"_b",snapshot.risk[row.second],m_content_x+half+12,y,half);
           }
         else if(row.kind==1) Line(key,snapshot.risk[row.index],y,row.height);
         else if(row.kind==2) Line(key,snapshot.live[row.index],y,row.height);
         else if(row.kind==3) Summary(snapshot,y);
         else if(row.kind==5) Gate(key,snapshot.gates[row.index],y,row.height);
         else if(row.kind==6) Line(key,snapshot.performance[row.index],y,row.height);
         else
           {
            QM_ConsoleLine summary; summary.label=row.kind==7?"Today":"Week";
            summary.value=row.kind==7?snapshot.today:snapshot.week; summary.state=QM_GATE_NA;
            Line(key,summary,y,row.height);
           }
         drawn=true;
        }
      if(!drawn)
         Label("body_empty",m_content_x+2,top,m_content_width-4,
            ArraySize(m_rows)==0?"No observations reported":"Enlarge chart to view complete details",QM_COLOR_SLATE,9);
     }
   void Tabs(const QM_ConsoleSnapshot &snapshot,const int y)
     {
      Rect("tabs_surface",12,y,m_width-24,26,QM_COLOR_CLOUD,QM_COLOR_CLOUD);
      const int width=(m_content_width-8)/3;
      string names[3]={"tab_overview","tab_checks","tab_performance"};
      string labels[3]={"Overview","Checks","Performance"};
      for(int i=0;i<3;++i)
        {
         const int x=m_content_x+i*(width+4);
         const string tooltip="Console 02: "+labels[i]+"; presentation only"+(i==1?"; "+GateCounts(snapshot):"");
         Button(names[i],x,y,width,24,labels[i],tooltip,m_tab==i);
         if(m_tab==i) Rect("tab_indicator",x+8,y+24,width-16,2,QM_COLOR_QUANT_GREEN,QM_COLOR_QUANT_GREEN);
        }
     }
   void Footer(const QM_ConsoleSnapshot &snapshot,const bool paged,const bool too_small=false)
     {
      const int y=m_height-28;
      const bool navigation=paged && m_pages>1;
      const int copyright_width=(int)MathMin(m_width-28-(navigation?108:0),Logical(TextWidth(Copyright(),9))+3);
      Rect("footer_rule",12,y-6,m_width-24,1,QM_COLOR_BORDER,QM_COLOR_BORDER);
      Label("footer",14,y+4,copyright_width,Copyright(),QM_COLOR_SLATE,9);
      S("footer",OBJPROP_TOOLTIP,DisplayText(Copyright()+Dot()+"Console 02"+Dot()+"EA v"+snapshot.version+"; "+GateCounts(snapshot)));
      if(navigation)
        {
         const int page=m_tab_page[m_tab];
         Button("previous",m_width-114,y,26,22,"<",page>0?"Previous complete page":"First page",false);
         Button("next",m_width-38,y,26,22,">",page+1<m_pages?"Next complete page":"Last page",false);
         Label("page_number",m_width-83,y+4,38,IntegerToString(page+1)+" / "+IntegerToString(m_pages),QM_COLOR_SLATE,9,false,true);
        }
      else if(too_small)
         S("footer",OBJPROP_TOOLTIP,"Enlarge the chart or reduce display scale to access complete details.");
      else
        {
         const int counts_x=14+copyright_width+12,counts_width=m_width-14-counts_x;
         if(counts_width>=24)
            Label("gate_counts",counts_x,y+4,counts_width,GateCounts(snapshot),QM_COLOR_SLATE,9,false,true);
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
   CQMStrategyConsoleV2()
     {
      m_chart=0; m_prefix=""; m_ready=false; m_ok=true; m_scale=100; m_dpi=96;
      m_mode=QM_CONSOLE_FULL; m_width=0; m_height=0; m_chart_width=0; m_chart_height=0;
      m_origin=8; m_content_x=12; m_content_width=0; m_pages=1; m_tab=0;
      ArrayInitialize(m_tab_page,0); m_has_snapshot=false; m_rendering=false;
     }
   bool Initialize(const long chart,const string prefix,const bool enabled,const QM_ConsoleMode mode,
                    const int scale,const bool show_range=false,const bool show_strategy=false,
                    const bool show_levels=false,const bool show_markers=false)
     {
      if(!enabled || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0 || prefix=="")
        {
         Print("QM_CONSOLE_V2_INIT_REFUSED: enabled=",enabled," tester=",MQLInfoInteger(MQL_TESTER),
            " optimization=",MQLInfoInteger(MQL_OPTIMIZATION)," prefix_empty=",prefix=="",
            "; presentation only, trading unaffected");
         return false;
        }
      m_chart=chart; m_prefix=prefix; m_mode=mode; m_scale=(int)MathMax(80,MathMin(150,scale));
      // Compatibility flags are intentionally not consumed. Console 02 never
      // draws overlays: QM_ChartPresentationV2 is their sole owner.
      m_tab=0; ArrayInitialize(m_tab_page,0); m_pages=1; m_has_snapshot=false; m_ready=true;
      return true;
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
         else if(object_name==Name("tab_overview")) { m_tab=0; repaint=true; }
         else if(object_name==Name("tab_checks")) { m_tab=1; repaint=true; }
         else if(object_name==Name("tab_performance")) { m_tab=2; repaint=true; }
         else if(object_name==Name("previous") || object_name==Name("next"))
           {
            const int delta=object_name==Name("next")?1:-1;
            m_tab_page[m_tab]=(int)MathMax(0,MathMin(m_tab_page[m_tab]+delta,m_pages-1));
            repaint=true;
           }
        }
      if(repaint && m_has_snapshot) Render(m_last_snapshot);
     }
   void Render(const QM_ConsoleSnapshot &snapshot)
     {
      if(!m_ready || m_rendering || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0) return;
      m_rendering=true;
      QM_ConsoleSnapshot stable_snapshot=snapshot; m_last_snapshot=stable_snapshot; m_has_snapshot=true;
      ArrayResize(m_used,0); m_ok=true; Geometry();
      if(m_width>=180 && m_height>=MinimumPanelHeight())
        {
         Rect("bg",0,0,m_width,m_height,QM_COLOR_SURFACE,QM_COLOR_BORDER_STRONG);
         const bool short_header=m_mode!=QM_CONSOLE_FULL || m_height<290;
         const int state_y=Header(snapshot,short_header),state_end=StateCard(snapshot,state_y);
         const int footer_top=m_height-36;
         const int tabs_y=state_end+6,body_top=tabs_y+28;
         const int minimum_row=(int)MathMax(28,TextLogicalHeight(9)+10);
         if(m_mode==QM_CONSOLE_FULL && footer_top-body_top>=minimum_row)
           { Tabs(snapshot,tabs_y); Body(snapshot,body_top,footer_top); Footer(snapshot,true); }
         else if(m_mode==QM_CONSOLE_COMPACT && state_end+8+SummaryHeight()<=footer_top)
           { Summary(snapshot,state_end+8); Footer(snapshot,false); }
         else if(state_end+6<=footer_top)
           {
            if(m_mode==QM_CONSOLE_FULL && state_end+TextLogicalHeight(9)+12<=footer_top)
               Label("resize_hint",14,state_end+8,m_width-28,"Enlarge chart for complete details",QM_COLOR_SLATE,9);
            Footer(snapshot,false,m_mode==QM_CONSOLE_FULL);
           }
        }
      else if(m_width>=120 && m_height>=48)
        {
         // An unusably small viewport is a display limitation, never an
         // invented trading block. Keep an explicit, bounded recovery cue.
         m_width=(int)MathMin(m_width,304); m_height=(int)MathMin(m_height,82);
         Rect("bg",0,0,m_width,m_height,QM_COLOR_SURFACE,QM_COLOR_BORDER_STRONG);
         Label("small_title",12,8,m_width-100,"Console 02",QM_COLOR_INK,11,true);
         Button("view",m_width-78,6,66,24,ModeText(),"View: FULL > COMPACT > MINIMAL. Presentation only.");
         Label("resize_hint",12,34,m_width-24,"Enlarge chart or reduce display scale",QM_COLOR_SLATE,9);
         if(m_height>=74) Label("footer",12,m_height-20,m_width-24,Copyright(),QM_COLOR_SLATE,9);
        }
      RemoveUnused();
      if(!m_ok)
        {
         ObjectsDeleteAll(m_chart,m_prefix); m_ready=false;
         Print("QM_CONSOLE_V2_RENDER_DISABLED: chart object update failed; trading unaffected");
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
