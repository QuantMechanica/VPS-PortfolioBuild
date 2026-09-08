#property strict
#property version "1.00"
#property description "Read-only observation of the pinned EA11421 FTMO canary. No chart or trading mutations."

// Interface: terminal-local QM_Console_Canary/canary_viewport.csv, one headerless
// row: chart_id,hwnd,plot_width,plot_height,client_width,client_height,dpi.
// Outputs share one unique audit id. Missing calibration suppresses PNG only.
const long AUDIT_ACCOUNT=1514536732;
const long AUDIT_CHART=40880270757609;
const long AUDIT_HWND=182059870;
const string AUDIT_EXPERT="QM5_11421_ohlc-daily-squeeze-reversal-d1";
const string AUDIT_PREFIX="QM_SIG_11421_114210000_";
const string AUDIT_OVERLAY="QM_CHART_V2_QM_SIG_11421_114210000_";
const string AUDIT_RETRY="QM_RETRY_QM_SIG_11421_114210000_";

bool AuditCsv(const int file,const string &values[])
  {
   string line="";
   for(int i=0;i<ArraySize(values);++i)
     {
      string value=values[i]; StringReplace(value,"\"","\"\"");
      if(i>0) line+=",";
      line+="\""+value+"\"";
     }
   return FileWriteString(file,line+"\r\n")>0;
  }

bool AuditTarget()
  {
   return AccountInfoInteger(ACCOUNT_LOGIN)==AUDIT_ACCOUNT &&
      AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO &&
      AccountInfoString(ACCOUNT_SERVER)=="FTMO-Demo" && ChartID()==AUDIT_CHART &&
      ChartGetInteger(AUDIT_CHART,CHART_WINDOW_HANDLE)==AUDIT_HWND &&
      ChartSymbol(AUDIT_CHART)=="EURUSD" && ChartPeriod(AUDIT_CHART)==PERIOD_D1 &&
      ChartGetString(AUDIT_CHART,CHART_EXPERT_NAME)==AUDIT_EXPERT;
  }

bool AuditOwned(const string name)
  {
   return StringFind(name,AUDIT_PREFIX)==0 || StringFind(name,AUDIT_OVERLAY)==0 ||
      StringFind(name,AUDIT_RETRY)==0;
  }

bool AuditCalibration(const int width,const int height,const int dpi,int &client_width,int &client_height)
  {
   client_width=0; client_height=0;
   const int file=FileOpen("QM_Console_Canary\\canary_viewport.csv",FILE_READ|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(file==INVALID_HANDLE) return false;
   const long chart=(long)FileReadNumber(file),window=(long)FileReadNumber(file);
   const int plot_width=(int)FileReadNumber(file),plot_height=(int)FileReadNumber(file);
   const int captured_width=(int)FileReadNumber(file),captured_height=(int)FileReadNumber(file);
   const int captured_dpi=(int)FileReadNumber(file);
   FileClose(file);
   if(chart!=AUDIT_CHART || window!=AUDIT_HWND || plot_width!=width || plot_height!=height ||
      captured_dpi!=dpi || width<=0 || height<=0 || dpi<=0 ||
      captured_width<width || captured_width>width+512 || captured_height<height || captured_height>height+512)
      return false;
   client_width=captured_width; client_height=captured_height;
   return true;
  }

bool AuditInteger(const string name,const ENUM_OBJECT_PROPERTY_INTEGER property,long &value)
  { return ObjectGetInteger(AUDIT_CHART,name,property,0,value); }

bool AuditBox(const int plot_width,const int plot_height,const long x,const long y,const long width,
              const long height,const ENUM_BASE_CORNER corner,const ENUM_ANCHOR_POINT anchor,
              const double angle,double &left,double &top)
  {
   if(width<=0 || height<=0 || angle!=0.0) return false;
   double ax=0.0,ay=0.0;
   switch(anchor)
     {
      case ANCHOR_LEFT_UPPER: ax=0.0; ay=0.0; break;
      case ANCHOR_LEFT: ax=0.0; ay=0.5; break;
      case ANCHOR_LEFT_LOWER: ax=0.0; ay=1.0; break;
      case ANCHOR_LOWER: ax=0.5; ay=1.0; break;
      case ANCHOR_RIGHT_LOWER: ax=1.0; ay=1.0; break;
      case ANCHOR_RIGHT: ax=1.0; ay=0.5; break;
      case ANCHOR_RIGHT_UPPER: ax=1.0; ay=0.0; break;
      case ANCHOR_UPPER: ax=0.5; ay=0.0; break;
      case ANCHOR_CENTER: ax=0.5; ay=0.5; break;
      default: return false;
     }
   const bool right=corner==CORNER_RIGHT_UPPER || corner==CORNER_RIGHT_LOWER;
   const bool bottom=corner==CORNER_LEFT_LOWER || corner==CORNER_RIGHT_LOWER;
   if(corner!=CORNER_LEFT_UPPER && corner!=CORNER_LEFT_LOWER && !right) return false;
   left=(double)(right?plot_width-x:x)-ax*(double)width;
   top=(double)(bottom?plot_height-y:y)-ay*(double)height;
   return true;
  }

bool AuditObjects(const string root,const string audit_id,const int width,const int height,int &captured)
  {
   string names[];
   for(int i=0;i<ObjectsTotal(AUDIT_CHART);++i)
     {
      const string name=ObjectName(AUDIT_CHART,i);
      if(!AuditOwned(name)) continue;
      const int n=ArraySize(names); ArrayResize(names,n+1); names[n]=name;
     }
   const int file=FileOpen(root+".objects.csv",FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(file==INVALID_HANDLE) return false;
   string columns[]={"audit_id","chart_id","name","type","type_name","scope","subwindow",
      "x","y","width","height","anchor","anchor_name","corner","corner_name","angle",
      "bbox_available","bbox_left","bbox_top","bbox_right","bbox_bottom","text","tooltip","read_complete"};
   bool complete=AuditCsv(file,columns); captured=0;
   for(int i=0;i<ArraySize(names);++i)
     {
      const string name=names[i];
      const int window=ObjectFind(AUDIT_CHART,name);
      long raw_type=0; bool ok=window>=0;
      ok=AuditInteger(name,OBJPROP_TYPE,raw_type) && ok;
      const ENUM_OBJECT type=(ENUM_OBJECT)raw_type;
      const bool pixel=type==OBJ_LABEL || type==OBJ_BUTTON || type==OBJ_RECTANGLE_LABEL ||
         type==OBJ_EDIT || type==OBJ_BITMAP_LABEL || type==OBJ_CHART;
      const bool anchored=type==OBJ_LABEL || type==OBJ_BITMAP_LABEL;
      long x=0,y=0,w=0,h=0,raw_anchor=ANCHOR_LEFT_UPPER,raw_corner=CORNER_LEFT_UPPER;
      double angle=0.0,left=0.0,top=0.0;
      if(pixel)
        {
         ok=AuditInteger(name,OBJPROP_XDISTANCE,x) && ok; ok=AuditInteger(name,OBJPROP_YDISTANCE,y) && ok;
         ok=AuditInteger(name,OBJPROP_XSIZE,w) && ok; ok=AuditInteger(name,OBJPROP_YSIZE,h) && ok;
         ok=AuditInteger(name,OBJPROP_CORNER,raw_corner) && ok;
         if(anchored) ok=AuditInteger(name,OBJPROP_ANCHOR,raw_anchor) && ok;
         if(type==OBJ_LABEL) ok=ObjectGetDouble(AUDIT_CHART,name,OBJPROP_ANGLE,0,angle) && ok;
        }
      string text="",tooltip="";
      ok=ObjectGetString(AUDIT_CHART,name,OBJPROP_TEXT,0,text) && ok;
      ok=ObjectGetString(AUDIT_CHART,name,OBJPROP_TOOLTIP,0,tooltip) && ok;
      const bool bbox=ok && pixel && window==0 && AuditBox(width,height,x,y,w,h,
         (ENUM_BASE_CORNER)raw_corner,(ENUM_ANCHOR_POINT)raw_anchor,angle,left,top);
      string row[]; ArrayResize(row,24);
      row[0]=audit_id; row[1]=IntegerToString(AUDIT_CHART); row[2]=name; row[3]=IntegerToString(raw_type); row[4]=EnumToString(type);
      row[5]=StringFind(name,AUDIT_OVERLAY)==0?"overlay":(StringFind(name,AUDIT_RETRY)==0?"recovery":"dashboard");
      row[6]=IntegerToString(window);
      row[7]=pixel?IntegerToString(x):""; row[8]=pixel?IntegerToString(y):"";
      row[9]=pixel?IntegerToString(w):""; row[10]=pixel?IntegerToString(h):"";
      row[11]=pixel?IntegerToString(raw_anchor):""; row[12]=pixel?EnumToString((ENUM_ANCHOR_POINT)raw_anchor):"N/A";
      row[13]=pixel?IntegerToString(raw_corner):""; row[14]=pixel?EnumToString((ENUM_BASE_CORNER)raw_corner):"N/A";
      row[15]=pixel?DoubleToString(angle,8):""; row[16]=bbox?"1":"0";
      row[17]=bbox?DoubleToString(left,2):""; row[18]=bbox?DoubleToString(top,2):"";
      row[19]=bbox?DoubleToString(left+(double)w,2):""; row[20]=bbox?DoubleToString(top+(double)h,2):"";
      row[21]=text; row[22]=tooltip; row[23]=ok?"1":"0";
      complete=AuditCsv(file,row) && ok && complete; ++captured;
     }
   FileFlush(file); FileClose(file);
   // Detect namespace additions/removals without claiming an atomic snapshot
   // of a concurrently running EA's changing object values.
   int after=0;
   for(int i=0;i<ObjectsTotal(AUDIT_CHART);++i)
     {
      const string name=ObjectName(AUDIT_CHART,i); if(!AuditOwned(name)) continue;
      ++after; bool seen=false;
      for(int j=0;j<ArraySize(names);++j) if(names[j]==name) { seen=true; break; }
      if(!seen) complete=false;
     }
   return complete && after==ArraySize(names);
  }

bool AuditProperties(const string root,const string audit_id)
  {
   const int file=FileOpen(root+".chart.csv",FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(file==INVALID_HANDLE) return false;
   string columns[]={"audit_id","chart_id","property","value","read_complete"};
   bool complete=AuditCsv(file,columns);
   ENUM_CHART_PROPERTY_INTEGER properties[]={CHART_COLOR_BACKGROUND,CHART_COLOR_FOREGROUND,
      CHART_COLOR_GRID,CHART_COLOR_CHART_UP,CHART_COLOR_CHART_DOWN,CHART_COLOR_CANDLE_BULL,
      CHART_COLOR_CANDLE_BEAR,CHART_COLOR_CHART_LINE,CHART_COLOR_VOLUME,CHART_COLOR_BID,
      CHART_COLOR_ASK,CHART_COLOR_LAST,CHART_MODE,CHART_FOREGROUND,CHART_SHOW_GRID,
      CHART_SHOW_VOLUMES,CHART_SHOW_BID_LINE,CHART_SHOW_ASK_LINE,CHART_SHOW_LAST_LINE,
      CHART_SHIFT,CHART_SCALE,CHART_AUTOSCROLL,CHART_SHOW_TRADE_LEVELS,CHART_DRAG_TRADE_LEVELS,
      CHART_SHOW_TRADE_HISTORY,CHART_FIRST_VISIBLE_BAR,CHART_WIDTH_IN_BARS};
   string row[]; ArrayResize(row,5); row[0]=audit_id; row[1]=IntegerToString(AUDIT_CHART);
   for(int i=0;i<ArraySize(properties);++i)
     {
      long value=0; const bool read=ChartGetInteger(AUDIT_CHART,properties[i],0,value);
      row[2]=EnumToString(properties[i]); row[3]=read?IntegerToString(value):""; row[4]=read?"1":"0";
      complete=AuditCsv(file,row) && read && complete;
     }
   double shift=0.0; const bool read_shift=ChartGetDouble(AUDIT_CHART,CHART_SHIFT_SIZE,0,shift);
   row[2]="CHART_SHIFT_SIZE"; row[3]=read_shift?DoubleToString(shift,16):""; row[4]=read_shift?"1":"0";
   complete=AuditCsv(file,row) && read_shift && complete;
   FileFlush(file); FileClose(file); return complete;
  }

void OnStart()
  {
   if(!AuditTarget()) { Print("QM_CANARY_AUDIT refused: exact account/chart/HWND/EA binding does not match"); return; }
   const string audit_id=StringFormat("%I64d_%I64u",AUDIT_CHART,GetTickCount64());
   const string root="QM_Console_Canary\\canary_"+audit_id;
   if(FileIsExist(root+".objects.csv") || FileIsExist(root+".chart.csv") ||
      FileIsExist(root+".meta.csv") || FileIsExist(root+".png"))
     { Print("QM_CANARY_AUDIT refused: output id already exists"); return; }
   const int width=(int)ChartGetInteger(AUDIT_CHART,CHART_WIDTH_IN_PIXELS);
   const int height=(int)ChartGetInteger(AUDIT_CHART,CHART_HEIGHT_IN_PIXELS);
   const int dpi=(int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   const string started=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS)+" UTC";
   int client_width=0,client_height=0,captured=0;
   const bool calibrated=AuditCalibration(width,height,dpi,client_width,client_height);
   const bool objects_ok=AuditObjects(root,audit_id,width,height,captured);
   const bool properties_ok=AuditProperties(root,audit_id);
   const bool binding_stable=AuditTarget() && width==ChartGetInteger(AUDIT_CHART,CHART_WIDTH_IN_PIXELS) &&
      height==ChartGetInteger(AUDIT_CHART,CHART_HEIGHT_IN_PIXELS) && dpi==TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   bool screenshot_ok=false;
   if(calibrated && binding_stable)
      screenshot_ok=ChartScreenShot(AUDIT_CHART,root+".png",client_width,client_height,ALIGN_LEFT);
   string design="UNOBSERVED",view="UNOBSERVED";
   if(ObjectFind(AUDIT_CHART,AUDIT_PREFIX+"design_version")>=0)
      design=ObjectGetString(AUDIT_CHART,AUDIT_PREFIX+"design_version",OBJPROP_TEXT);
   if(ObjectFind(AUDIT_CHART,AUDIT_PREFIX+"view")>=0)
      view=ObjectGetString(AUDIT_CHART,AUDIT_PREFIX+"view",OBJPROP_TEXT);
   const int file=FileOpen(root+".meta.csv",FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(file==INVALID_HANDLE) { Print("QM_CANARY_AUDIT metadata write failed; observation incomplete"); return; }
   string columns[]={"schema_version","artifact_kind","audit_id","account_login","server","account_mode",
      "chart_id","hwnd","symbol","timeframe","expert","prefix","overlay_prefix","design","view",
      "plot_width","plot_height","dpi","object_count","objects_complete","properties_complete",
      "binding_stable","capture_non_atomic","screenshot_calibrated","screenshot_ok","screenshot_width",
      "screenshot_height","started_utc","finished_utc","observation_complete"};
   const bool complete=objects_ok && properties_ok && binding_stable;
   string values[]={"1","live_canary_observation",audit_id,IntegerToString(AUDIT_ACCOUNT),"FTMO-Demo","DEMO",
      IntegerToString(AUDIT_CHART),IntegerToString(AUDIT_HWND),"EURUSD","D1",AUDIT_EXPERT,AUDIT_PREFIX,AUDIT_OVERLAY,
      design,view,IntegerToString(width),IntegerToString(height),IntegerToString(dpi),IntegerToString(captured),
      objects_ok?"1":"0",properties_ok?"1":"0",binding_stable?"1":"0","1",calibrated?"1":"0",screenshot_ok?"1":"0",
      IntegerToString(client_width),IntegerToString(client_height),started,TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS)+" UTC",complete?"1":"0"};
   const bool written=AuditCsv(file,columns) && AuditCsv(file,values);
   FileFlush(file); FileClose(file);
   Print("QM_CANARY_AUDIT ",audit_id," observation_complete=",complete && written,
      " calibrated_png=",screenshot_ok,"; live chart observed without chart/trading mutations");
  }
