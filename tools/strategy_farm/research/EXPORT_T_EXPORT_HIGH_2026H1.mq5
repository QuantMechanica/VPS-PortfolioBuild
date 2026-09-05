// Prepared from the private-lab multi-currency exporter for E1-A.
// OWNER/CEO runs this manually in T_Export, once per currency. Never an EA.
#property script_show_inputs
#property strict
input string InpCurrency="USD";

bool ExportCurrency(const string currency)
  {
   const datetime from=D'2026.01.01 00:00';
   const datetime to=D'2026.07.01 00:00';
   MqlCalendarValue values[];
   ResetLastError();
   const int count=CalendarValueHistory(values,from,to,"",currency);
   if(count<=0)
     {
      PrintFormat("CALENDAR_QUERY_FAILED currency=%s count=%d err=%d; retry this currency only (5401 timeout)",currency,count,GetLastError());
      return false;
     }
   int order[];
   string codes[], names[];
   ArrayResize(order,count); ArrayResize(codes,count); ArrayResize(names,count);
   int selected=0;
   for(int i=0;i<count;i++)
     {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id,event))
        {
         PrintFormat("CALENDAR_EVENT_LOOKUP_FAILED id=%I64u err=%d; no file written",values[i].event_id,GetLastError());
         return false;
        }
      if(event.importance!=CALENDAR_IMPORTANCE_HIGH || values[i].time<from || values[i].time>=to)
         continue;
      codes[i]=event.event_code; names[i]=event.name;
      int j=selected;
      while(j>0 && (values[order[j-1]].time>values[i].time ||
            (values[order[j-1]].time==values[i].time && values[order[j-1]].id>values[i].id)))
        { order[j]=order[j-1]; j--; }
      order[j]=i; selected++;
     }
   if(selected==0) { Print("NO_HIGH_ROWS; no file written"); return false; }
   const string filename="T_EXPORT_"+currency+"_HIGH_2026H1_NATIVE.csv";
   if(FileIsExist(filename))
     { PrintFormat("EXISTING_EXPORT_REFUSED file=%s; retain it and have OWNER resolve retries",filename); return false; }
   const int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(handle==INVALID_HANDLE) { PrintFormat("FILE_OPEN_FAIL err=%d",GetLastError()); return false; }
   FileWrite(handle,"broker_time","event_id","event_code","event_name","importance","value_id");
   for(int j=0;j<selected;j++)
     {
      const int i=order[j];
      if(FileWrite(handle,(long)values[i].time,(long)values[i].event_id,codes[i],names[i],"high",(long)values[i].id)==0)
        { PrintFormat("FILE_WRITE_FAIL file=%s row=%d; incomplete file must not be ingested",filename,j); FileClose(handle); return false; }
     }
   FileFlush(handle); FileClose(handle);
   PrintFormat("E1A_2026H1_EXPORT_COMPLETE currency=%s rows=%d first=%s last=%s file=%s; raw encoding still requires official-anchor verification",
               currency,selected,TimeToString(values[order[0]].time,TIME_DATE|TIME_MINUTES),
               TimeToString(values[order[selected-1]].time,TIME_DATE|TIME_MINUTES),filename);
   return true;
  }

void OnStart()
  {
   const string terminal_path=TerminalInfoString(TERMINAL_PATH);
   if(StringFind(terminal_path,"T_Export")<0)
     { PrintFormat("HARD_FAIL_WRONG_TERMINAL path=%s",terminal_path); return; }
   const string allowed="|USD|EUR|GBP|JPY|AUD|CAD|";
   if(StringFind(allowed,"|"+InpCurrency+"|")<0)
     { Print("INVALID_CURRENCY; choose USD EUR GBP JPY AUD CAD"); return; }
   ExportCurrency(InpCurrency);
  }
