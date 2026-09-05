// Read-only native export, restricted to the export terminal. No trading API.
#property strict
enum IMPACT_FILTER { HIGH_ONLY=0, ALL_IMPACTS=1 };
input string InpCurrency="USD";
input datetime InpFrom=D'2026.01.01';
input datetime InpTo=D'2026.07.01';
input IMPACT_FILTER InpImpact=HIGH_ONLY;
input string InpEventName="";
input string InpOutput="T_EXPORT_USD_HIGH_2026H1_NATIVE.csv";
input bool InpBatch=false;
input bool InpCatalogOnly=false;
input bool InpCatalogH1=false;
input string InpCompletion="E1B2_EXPORT_COMPLETE.txt";

bool ExportOne(const string currency,const datetime from,const datetime to,
               const IMPACT_FILTER impact,const string name,const string filename)
  {
   if(from>=to || from<D'2018.01.01' || to>D'2027.01.01' || StringFind(filename,"/")>=0 || StringFind(filename,"\\")>=0 ||
      StringFind(filename,":")>=0 || FileIsExist(filename))
     { PrintFormat("REFUSED_RANGE_OR_OUTPUT %s",filename); return false; }
   MqlCalendarValue values[], chunk[];
   int total=0;
   ulong selected_event_id=0;
   if(name!="")
     {
      MqlCalendarEvent catalog[];
      int events=CalendarEventByCurrency(currency,catalog);
      if(events<0) { PrintFormat("CATALOG_FAIL %d",GetLastError()); return false; }
      for(int i=0;i<events;i++)
        if(catalog[i].name==name || (name=="NY Empire State Manufacturing Index" &&
           (StringFind(catalog[i].name,"Empire")>=0 || StringFind(catalog[i].event_code,"ny-fed-manufacturing")>=0)))
          { if(selected_event_id!=0) { Print("AMBIGUOUS_EVENT_NAME"); return false; } selected_event_id=catalog[i].id;
            PrintFormat("CATALOG_SELECTED id=%I64u code=%s name=%s",catalog[i].id,catalog[i].event_code,catalog[i].name); }
      if(selected_event_id==0) { PrintFormat("CATALOG_NAME_MISSING %s",name); return false; }
     }
   // Annual queries avoid a single oversized eight-year Calendar request.
   datetime start=from;
   while(start<to)
     {
      MqlDateTime civil; TimeToStruct(start,civil);
      civil.year++; civil.mon=1; civil.day=1; civil.hour=0; civil.min=0; civil.sec=0;
      datetime end=StructToTime(civil); if(end>to) end=to;
      ResetLastError();
      int n=(selected_event_id!=0 ? CalendarValueHistoryByEvent(selected_event_id,chunk,start,end) :
                                  CalendarValueHistory(chunk,start,end,"",currency));
      if(selected_event_id!=0) PrintFormat("CATALOG_QUERY id=%I64u from=%s to=%s count=%d err=%d",selected_event_id,
                     TimeToString(start),TimeToString(end),n,GetLastError());
      if(n<0) { PrintFormat("QUERY_FAIL %s %d %d",currency,n,GetLastError()); return false; }
      ArrayResize(values,total+n);
      for(int k=0;k<n;k++) values[total+k]=chunk[k];
      total+=n; start=end;
     }
   int order[]; string codes[], names[], impacts[];
   ArrayResize(order,total); ArrayResize(codes,total); ArrayResize(names,total); ArrayResize(impacts,total);
   int selected=0;
   for(int i=0;i<total;i++)
     {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id,event)) { Print("EVENT_LOOKUP_FAIL"); return false; }
      if(values[i].time<from || values[i].time>=to ||
         (impact==HIGH_ONLY && event.importance!=CALENDAR_IMPORTANCE_HIGH) ||
         (name!="" && values[i].event_id!=selected_event_id)) continue;
      bool duplicate=false;
      for(int d=0;d<selected;d++) if(values[order[d]].id==values[i].id) { duplicate=true; break; }
      if(duplicate) continue;
      codes[i]=event.event_code; names[i]=event.name;
      impacts[i]=(event.importance==CALENDAR_IMPORTANCE_HIGH ? "high" :
                  event.importance==CALENDAR_IMPORTANCE_MODERATE ? "medium" :
                  event.importance==CALENDAR_IMPORTANCE_LOW ? "low" : "none");
      int j=selected;
      while(j>0 && (values[order[j-1]].time>values[i].time ||
           (values[order[j-1]].time==values[i].time && values[order[j-1]].id>values[i].id)))
        { order[j]=order[j-1]; j--; }
      order[j]=i; selected++;
     }
   if(selected==0) { PrintFormat("NO_MATCHES %s %s",currency,name); return false; }
   int h=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(h==INVALID_HANDLE) return false;
   FileWrite(h,"broker_time","event_id","event_code","event_name","importance","value_id");
   for(int j=0;j<selected;j++)
     {
      int i=order[j];
      if(FileWrite(h,(long)values[i].time,(long)values[i].event_id,codes[i],names[i],impacts[i],(long)values[i].id)==0)
        { FileClose(h); return false; }
     }
   FileFlush(h); FileClose(h);
   PrintFormat("E1B2_EXPORT_OK file=%s rows=%d raw_timestamp_encoding=UNVERIFIED_SERVER_CIVIL",filename,selected);
   return true;
  }

void OnStart()
  {
   string root=TerminalInfoString(TERMINAL_PATH); StringReplace(root,"/","\\"); StringToLower(root);
   if(root!="d:\\qm\\mt5\\t_export") { Print("WRONG_TERMINAL_REFUSED"); return; }
   if(FileIsExist(InpCompletion)) { Print("COMPLETION_EXISTS_REFUSED"); return; }
   int failures=0, successes=0;
   if(!InpBatch)
     {
      if(StringFind("|USD|EUR|GBP|JPY|AUD|CAD|","|"+InpCurrency+"|")<0) return;
      if(ExportOne(InpCurrency,InpFrom,InpTo,InpImpact,InpEventName,InpOutput)) successes++; else failures++;
     }
   else
     {
      string currencies[]={"USD","EUR","GBP","JPY","AUD","CAD"};
      for(int i=0;i<6 && !InpCatalogOnly;i++)
        if(ExportOne(currencies[i],D'2026.01.01',D'2026.07.01',HIGH_ONLY,"",
                     "T_EXPORT_"+currencies[i]+"_HIGH_2026H1_NATIVE.csv")) successes++; else failures++;
      string names[]={"Core PPI m/m","NY Empire State Manufacturing Index","Building Permits","Trade Balance"};
      string tags[]={"CORE_PPI","EMPIRE_STATE","BUILDING_PERMITS","TRADE_BALANCE"};
      for(int i=0;i<4;i++)
        if(ExportOne("USD",InpCatalogH1 ? D'2026.01.01' : D'2018.01.01',
                     InpCatalogH1 ? D'2026.07.01' : D'2026.01.01',ALL_IMPACTS,names[i],
                     "T_EXPORT_USD_ALL_"+tags[i]+(InpCatalogH1 ? "_2026H1_NATIVE.csv" : "_2018_2025_NATIVE.csv"))) successes++; else failures++;
     }
   int h=FileOpen(InpCompletion,FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(h!=INVALID_HANDLE)
     { FileWrite(h,StringFormat("successes=%d failures=%d",successes,failures)); FileFlush(h); FileClose(h); }
   PrintFormat("E1B2_BATCH_COMPLETE successes=%d failures=%d",successes,failures);
  }
