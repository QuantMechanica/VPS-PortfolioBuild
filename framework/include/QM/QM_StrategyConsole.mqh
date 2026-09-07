#ifndef QM_STRATEGYCONSOLE_MQH
#define QM_STRATEGYCONSOLE_MQH

#include <QM/QM_ConsoleModel.mqh>

// Pure renderer: immutable snapshot in, owned chart objects out. No policy,
// account, position, history, filter, governor, or trading APIs belong here.
class CQMStrategyConsole
  {
private:
   long m_chart;
   string m_prefix;
   string m_used[];
   bool m_ready;
   int m_scale;
   int m_dpi;
   QM_ConsoleMode m_mode;
   bool m_show_range;
   bool m_show_strategy;
   bool m_show_levels;
   bool m_show_markers;
   bool m_ok;

   int Px(const int value) const { return (value*m_dpi*m_scale+4800)/9600; }
   int Font(const int value) const { return (int)MathMax(6,MathRound(value*m_scale/100.0)); }
   string Name(const string suffix) const { return m_prefix+suffix; }
   string Ascii(const string text) const
     {
      string out="";
      for(int i=0;i<StringLen(text);++i)
        { const ushort c=StringGetCharacter(text,i); out+=ShortToString((ushort)(c>=32&&c<=126?c:32)); }
      return out;
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
   void Rect(const string key,const int x,const int y,const int width,const int height,
              const color fill,const color border)
     {
      if(!Ensure(key,OBJ_RECTANGLE_LABEL)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_XDISTANCE,Px(x+16));
      I(key,OBJPROP_YDISTANCE,Px(y+20)); I(key,OBJPROP_XSIZE,Px(width));
      I(key,OBJPROP_YSIZE,Px(height)); I(key,OBJPROP_BGCOLOR,fill);
      I(key,OBJPROP_COLOR,border); I(key,OBJPROP_BORDER_TYPE,BORDER_FLAT); Common(key,900);
     }
   void Label(const string key,const int x,const int y,const string value,
               const color tint=QM_COLOR_CARBON,const int size=9,const bool bold=false,
               const bool right=false)
     {
      if(!Ensure(key,OBJ_LABEL)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_XDISTANCE,Px(x+16));
      I(key,OBJPROP_YDISTANCE,Px(y+20)); I(key,OBJPROP_ANCHOR,right?ANCHOR_RIGHT_UPPER:ANCHOR_LEFT_UPPER);
      I(key,OBJPROP_COLOR,tint); I(key,OBJPROP_FONTSIZE,Font(size)); Common(key,910);
      S(key,OBJPROP_FONT,bold?QM_FONT_UI_BOLD:QM_FONT_UI); S(key,OBJPROP_TEXT,Ascii(value));
     }
   void View()
     {
      const string key="view"; if(!Ensure(key,OBJ_BUTTON)) return;
      I(key,OBJPROP_CORNER,CORNER_LEFT_UPPER); I(key,OBJPROP_XDISTANCE,Px(472));
      I(key,OBJPROP_YDISTANCE,Px(32)); I(key,OBJPROP_XSIZE,Px(64)); I(key,OBJPROP_YSIZE,Px(28));
      I(key,OBJPROP_BGCOLOR,QM_COLOR_SURFACE); I(key,OBJPROP_BORDER_COLOR,QM_COLOR_BORDER);
      I(key,OBJPROP_COLOR,QM_COLOR_SLATE); I(key,OBJPROP_FONTSIZE,Font(9));
      S(key,OBJPROP_FONT,QM_FONT_UI); S(key,OBJPROP_TEXT,"View");
      S(key,OBJPROP_TOOLTIP,"FULL > COMPACT > MINIMAL"); Common(key,950);
      I(key,OBJPROP_STATE,false);
     }
   int Section(const string key,const string title,const int y)
     {
      Rect(key+"_rule",16,y,QM_CONSOLE_WIDTH-32,1,QM_COLOR_BORDER,QM_COLOR_BORDER);
      Label(key+"_title",16,y+12,title,QM_COLOR_SLATE,8,true);
      return y+36;
     }
   int Lines(const string key,const string title,const QM_ConsoleLine &lines[],const int y)
     {
      if(ArraySize(lines)==0) return y;
      int cursor=Section(key,title,y);
      for(int i=0;i<ArraySize(lines);++i)
        {
         const string row=key+IntegerToString(i);
         Label(row+"_label",16,cursor,lines[i].label,QM_COLOR_SLATE,8);
         Label(row+"_value",QM_CONSOLE_WIDTH-16,cursor,lines[i].value,
               QM_ConsoleGateColor(lines[i].state),8,false,true);
         Rect(row+"_rule",16,cursor+20,QM_CONSOLE_WIDTH-32,1,QM_COLOR_BORDER,QM_COLOR_BORDER);
         cursor+=24;
        }
      return cursor+12;
     }
   void PriceLabel(const string key,const datetime when,const double price,
                    const string text,const color tint)
     {
      if(price<=0.0 || !Ensure(key,OBJ_TEXT)) return;
      if(!ObjectMove(m_chart,Name(key),0,when,price)) m_ok=false;
      I(key,OBJPROP_COLOR,tint); I(key,OBJPROP_FONTSIZE,Font(8));
      I(key,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER); Common(key,10);
      S(key,OBJPROP_FONT,QM_FONT_UI); S(key,OBJPROP_TEXT,Ascii(text));
     }
   void Overlay(const QM_ConsoleSnapshot &snapshot)
     {
      if(snapshot.active_range && m_show_range)
        {
         const string key="range";
         if(Ensure(key,OBJ_RECTANGLE))
           {
            if(!ObjectMove(m_chart,Name(key),0,snapshot.range_start,snapshot.range_high) ||
               !ObjectMove(m_chart,Name(key),1,snapshot.range_end,snapshot.range_low)) m_ok=false;
            I(key,OBJPROP_COLOR,QM_COLOR_RANGE_FILL); I(key,OBJPROP_FILL,true);
            Common(key,1); I(key,OBJPROP_BACK,true);
           }
        }
      if(snapshot.active_range && m_show_strategy)
        {
         PriceLabel("range_high",snapshot.range_end,snapshot.range_high,"Range High",QM_COLOR_RANGE_BORDER);
         PriceLabel("range_low",snapshot.range_end,snapshot.range_low,"Range Low",QM_COLOR_RANGE_BORDER);
        }
      for(int i=0;i<ArraySize(snapshot.exposure);++i)
        {
         const QM_ConsoleExposure e=snapshot.exposure[i];
         if(e.symbol!=snapshot.symbol) continue;
         const string key="trade_"+StringFormat("%I64u",e.ticket);
         if(m_show_levels)
           {
            PriceLabel(key+"_entry",e.opened,e.entry,(e.pending?"Trigger ":"Entry ")+e.entry_text,QM_COLOR_SLATE);
            PriceLabel(key+"_sl",e.opened,e.sl,"SL "+e.sl_text,QM_COLOR_NEGATIVE);
            PriceLabel(key+"_tp",e.opened,e.tp,"TP "+e.tp_text,QM_COLOR_POSITIVE);
           }
         if(m_show_markers && !e.pending)
           {
            const string mark=key+"_marker";
            if(Ensure(mark,e.buy?OBJ_ARROW_BUY:OBJ_ARROW_SELL))
              {
               if(!ObjectMove(m_chart,Name(mark),0,e.opened,e.entry)) m_ok=false;
               I(mark,OBJPROP_COLOR,e.buy?QM_COLOR_POSITIVE:QM_COLOR_NEGATIVE); Common(mark,10);
              }
           }
        }
     }
   void RemoveUnused()
     {
      for(int i=ObjectsTotal(m_chart)-1;i>=0;--i)
        {
         const string name=ObjectName(m_chart,i);
         if(StringFind(name,m_prefix)!=0) continue;
         bool used=false;
         for(int j=0;j<ArraySize(m_used);++j) if(m_used[j]==name) { used=true; break; }
         if(!used) ObjectDelete(m_chart,name);
        }
     }

public:
   CQMStrategyConsole() { m_chart=0; m_prefix=""; m_ready=false; m_scale=100; m_dpi=96;
      m_mode=QM_CONSOLE_FULL; m_show_range=true; m_show_strategy=true; m_show_levels=true; m_show_markers=true; m_ok=true; }
   bool Initialize(const long chart,const string prefix,const bool enabled,const QM_ConsoleMode mode,
                    const int scale,const bool show_range,const bool show_strategy,
                    const bool show_levels,const bool show_markers)
     {
      if(!enabled || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0) return false;
      m_chart=chart; m_prefix=prefix; m_mode=mode; m_scale=(int)MathMax(80,MathMin(150,scale));
      m_dpi=(int)TerminalInfoInteger(TERMINAL_SCREEN_DPI); if(m_dpi<=0) m_dpi=96;
      m_show_range=show_range; m_show_strategy=show_strategy; m_show_levels=show_levels; m_show_markers=show_markers;
      m_ready=true; return true;
     }
   bool Ready() const { return m_ready; }
   void OnChartEvent(const int id,const string object_name)
     {
      if(m_ready && id==CHARTEVENT_OBJECT_CLICK && object_name==Name("view"))
         m_mode=QM_ConsoleNextMode(m_mode); // Rendering remains timer-only.
     }
   void Render(const QM_ConsoleSnapshot &snapshot)
     {
      if(!m_ready || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0) return;
      ArrayResize(m_used,0); m_ok=true;
      int height=124;
      if(m_mode!=QM_CONSOLE_MINIMAL)
        {
         height=268;
         if(m_mode==QM_CONSOLE_FULL)
            height=268+36+((ArraySize(snapshot.gates)+1)/2)*32+12+
               (ArraySize(snapshot.risk)>0?48+24*ArraySize(snapshot.risk):0)+
               (ArraySize(snapshot.live)>0?48+24*ArraySize(snapshot.live):0)+
               (ArraySize(snapshot.performance)>0?48+24*ArraySize(snapshot.performance):0);
        }
      Rect("bg",0,0,QM_CONSOLE_WIDTH,height,QM_COLOR_SURFACE,QM_COLOR_BORDER_STRONG);
      Label("word_quant",16,12,"Quant",QM_COLOR_CARBON,16,true);
      Label("word_mechanica",78,12,"Mechanica",QM_COLOR_QUANT_GREEN,16,true);
      View();
      int y=52;
      if(m_mode!=QM_CONSOLE_MINIMAL)
        {
         Label("module",16,48,"STRATEGY CONSOLE",QM_COLOR_SLATE,8,true);
         Label("strategy",16,68,snapshot.strategy_name+" | "+snapshot.timeframe,QM_COLOR_INK,12,true);
         y=100;
        }
      const QM_ConsoleGateState state=snapshot.state==QM_CONSOLE_BLOCKED || snapshot.state==QM_CONSOLE_ERROR?
         QM_GATE_BLOCK:(snapshot.state==QM_CONSOLE_INITIALIZING?QM_GATE_WAIT:QM_GATE_PASS);
      Rect("state_bg",16,y,QM_CONSOLE_WIDTH-32,m_mode==QM_CONSOLE_MINIMAL?56:92,
         QM_ConsoleGateBackground(state),QM_COLOR_BORDER);
      Label("state_headline",28,y+10,QM_ConsoleStateText(snapshot.state),QM_ConsoleGateColor(state),11,true);
      if(m_mode!=QM_CONSOLE_MINIMAL)
        {
         Label("state_meta",QM_CONSOLE_WIDTH-28,y+12,snapshot.environment+" | "+snapshot.symbol,QM_COLOR_SLATE,8,false,true);
         Label("state_reason",28,y+36,snapshot.reason,QM_ConsoleGateColor(state),9);
         Label("state_next",28,y+62,snapshot.next_event,QM_COLOR_SLATE,8);
         y+=104;
        }
      else Label("state_next",28,y+34,snapshot.next_event,QM_COLOR_SLATE,8);
      if(m_mode==QM_CONSOLE_FULL)
        {
         y=Section("gates","FILTER GATE",y);
         for(int i=0;i<ArraySize(snapshot.gates);++i)
           {
            const string key="gate_"+snapshot.gates[i].key;
            const int x=16+(i%2)*262; const int row_y=y+(i/2)*32;
            Label(key+"_reason",x,row_y+5,snapshot.gates[i].label+" - "+snapshot.gates[i].reason,QM_COLOR_SLATE,8);
            Rect(key+"_chip",x+202,row_y,48,24,QM_ConsoleGateBackground(snapshot.gates[i].state),QM_ConsoleGateBackground(snapshot.gates[i].state));
            Label(key+"_state",x+246,row_y+5,QM_ConsoleGateText(snapshot.gates[i].state),QM_ConsoleGateColor(snapshot.gates[i].state),8,true,true);
           }
         y+=((ArraySize(snapshot.gates)+1)/2)*32+12;
         y=Lines("risk","RISK",snapshot.risk,y);
         y=Lines("live","LIVE",snapshot.live,y);
        }
      if(m_mode!=QM_CONSOLE_MINIMAL)
        {
         Rect("strip",16,y,QM_CONSOLE_WIDTH-32,40,QM_COLOR_CLOUD,QM_COLOR_BORDER);
         Label("today",28,y+12,"Today  "+snapshot.today,QM_COLOR_SLATE,8);
         Label("week",284,y+12,"Week  "+snapshot.week,QM_COLOR_SLATE,8);
         y+=52;
         if(m_mode==QM_CONSOLE_FULL) y=Lines("performance","PERFORMANCE | THIS EA",snapshot.performance,y);
         Label("footer",16,y,"(c) QuantMechanica",QM_COLOR_MUTED,8);
         Label("version",QM_CONSOLE_WIDTH-16,y,"v"+snapshot.version,QM_COLOR_MUTED,8,false,true);
        }
      Overlay(snapshot); RemoveUnused();
      if(!m_ok)
        {
         ObjectsDeleteAll(m_chart,m_prefix); m_ready=false;
         Print("QM_CONSOLE_RENDER_DISABLED: chart object update failed; trading unaffected");
        }
      ChartRedraw(m_chart);
     }
   void Shutdown()
     {
      if(m_prefix!="") { ObjectsDeleteAll(m_chart,m_prefix); ChartRedraw(m_chart); }
      m_ready=false;
     }
  };

#endif
