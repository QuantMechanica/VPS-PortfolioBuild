#property strict
#property version "1.00"
#property description "Visual QA launcher: read-only audit, then one empty no-trade chart."

// A script coexists with the attached EA. No template, timeframe, EA permission,
// account, trading setting, order or position is changed on existing charts.
void OnStart()
  {
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO ||
      AccountInfoString(ACCOUNT_SERVER)!="FTMO-Demo")
     { Print("QM_CONSOLE_QA refused: FTMO demo only"); return; }
   FolderCreate("QM_Console_QA");
   const int audit=FileOpen("QM_Console_QA\\charts_before.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(audit==INVALID_HANDLE) return;
   FileWrite(audit,"chart_id","symbol","period","width","height","expert","objects","window_handle");
   bool found=false;
   for(long chart=ChartFirst();chart>=0;chart=ChartNext(chart))
     {
      const string expert=ChartGetString(chart,CHART_EXPERT_NAME);
      const int width=(int)ChartGetInteger(chart,CHART_WIDTH_IN_PIXELS);
      const int height=(int)ChartGetInteger(chart,CHART_HEIGHT_IN_PIXELS);
      FileWrite(audit,chart,ChartSymbol(chart),EnumToString(ChartPeriod(chart)),width,height,expert,ObjectsTotal(chart),
         ChartGetInteger(chart,CHART_WINDOW_HANDLE));
      if(ChartSymbol(chart)=="EURUSD" && ChartPeriod(chart)==PERIOD_D1 &&
         StringFind(expert,"QM5_11421_")==0)
        {
         found=true;
         ChartScreenShot(chart,"QM_Console_QA\\eurusd_before.png",width,height,ALIGN_LEFT);
         const int objects=FileOpen("QM_Console_QA\\objects_before.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
         if(objects!=INVALID_HANDLE)
           {
            FileWrite(objects,"name","type","x","y","width","height","text");
            for(int i=0;i<ObjectsTotal(chart);++i)
              {
               const string name=ObjectName(chart,i);
               if(StringFind(name,"QM_")!=0) continue;
               FileWrite(objects,name,ObjectGetInteger(chart,name,OBJPROP_TYPE),
                  ObjectGetInteger(chart,name,OBJPROP_XDISTANCE),ObjectGetInteger(chart,name,OBJPROP_YDISTANCE),
                  ObjectGetInteger(chart,name,OBJPROP_XSIZE),ObjectGetInteger(chart,name,OBJPROP_YSIZE),
                  ObjectGetString(chart,name,OBJPROP_TEXT));
              }
            FileClose(objects);
           }
        }
     }
   FileClose(audit);
   if(!found) { Print("QM_CONSOLE_QA refused: expected live EURUSD EA not found"); return; }
   // Do not create duplicate fixture charts on an accidental repeated launch.
   const string marker="QM_Console_QA\\fixture_chart.txt";
   long fixture=0;
   if(FileIsExist(marker))
     {
      const int existing=FileOpen(marker,FILE_READ|FILE_TXT|FILE_ANSI);
      if(existing!=INVALID_HANDLE) { fixture=StringToInteger(FileReadString(existing)); FileClose(existing); }
      if(fixture==0 || ChartSymbol(fixture)!="EURUSD" || ChartPeriod(fixture)!=PERIOD_D1 ||
         (StringLen(ChartGetString(fixture,CHART_EXPERT_NAME))>0 && ChartGetString(fixture,CHART_EXPERT_NAME)!="QM_Console_Visual_QA"))
        {
         const int diagnostic=FileOpen("QM_Console_QA\\binding_error.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
         if(diagnostic!=INVALID_HANDLE)
           { FileWrite(diagnostic,fixture,ChartSymbol(fixture),EnumToString(ChartPeriod(fixture)),
              ChartGetString(fixture,CHART_EXPERT_NAME),GetLastError()); FileClose(diagnostic); }
         Print("QM_CONSOLE_QA existing fixture binding invalid - refused"); return;
        }
     }
   else
     {
      fixture=ChartOpen("EURUSD",PERIOD_D1);
      // Default-template safety is prechecked by the local launcher. Verify
      // the resulting chart as well before publishing any reusable binding.
      if(fixture>0 && StringLen(ChartGetString(fixture,CHART_EXPERT_NAME))>0)
        { Print("QM_CONSOLE_QA unexpected default-template EA - binding refused"); return; }
     }
   if(fixture==0) { Print("QM_CONSOLE_QA ChartOpen failed ",GetLastError()); return; }
   ChartSetString(fixture,CHART_COMMENT,"DESIGN QA - SYNTHETIC DATA - NO TRADING");
   ChartSetInteger(fixture,CHART_BRING_TO_TOP,true);
   const int receipt=FileOpen(marker,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(receipt!=INVALID_HANDLE) { FileWrite(receipt,fixture); FileClose(receipt); }
   const int binding=FileOpen("QM_Console_QA\\fixture_window.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(binding!=INVALID_HANDLE)
     { FileWrite(binding,ChartGetInteger(fixture,CHART_WINDOW_HANDLE)); FileClose(binding); }
   Print("QM_CONSOLE_QA created empty fixture chart ",fixture,"; original EA untouched");
  }
