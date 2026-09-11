// Governed, read-only M1 export for the fixed DWX/Dukascopy overlap window.
#property strict

input string InpOutputDir="QM\\dwx_m1_overlap";
input string InpCompletion="QM_DWX_M1_OVERLAP_COMPLETE.txt";
input long InpStartBrokerEpoch=1759287600;
input long InpEndBrokerEpoch=1775012400;
input int InpChunkDays=7;
input int InpSyncAttempts=30;

int CopyChunk(const string symbol,const datetime start_time,const datetime end_time,MqlRates &rates[])
  {
   ArrayResize(rates,0);
   ArraySetAsSeries(rates,false);
   int copied=-1;
   for(int attempt=0;attempt<InpSyncAttempts;attempt++)
     {
      ResetLastError();
      copied=CopyRates(symbol,PERIOD_M1,start_time,end_time,rates);
      const int copy_error=GetLastError();
      ResetLastError();
      const int available=Bars(symbol,PERIOD_M1,start_time,end_time);
      const int bars_error=GetLastError();
      const bool synchronized=(bool)SeriesInfoInteger(symbol,PERIOD_M1,SERIES_SYNCHRONIZED);
      if(copied>=0 && copy_error!=ERR_HISTORY_TIMEOUT &&
         available==copied && bars_error!=ERR_HISTORY_TIMEOUT && synchronized)
         return copied;
      Sleep(1000);
     }
   return copied;
  }

bool ExportOne(const string symbol,long &written_rows)
  {
   written_rows=0;
   if(!SymbolSelect(symbol,true))
     {
      PrintFormat("SYMBOL_SELECT_FAIL symbol=%s err=%d",symbol,GetLastError());
      return false;
     }
   if(!(bool)SymbolInfoInteger(symbol,SYMBOL_CUSTOM))
     {
      PrintFormat("NON_CUSTOM_SYMBOL_REFUSED symbol=%s",symbol);
      return false;
     }
   const int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   if(digits<0 || digits>12)
     {
      PrintFormat("SYMBOL_DIGITS_REFUSED symbol=%s digits=%d",symbol,digits);
      return false;
     }

   const string output_file=InpOutputDir+"\\"+symbol+"_M1.csv";
   const int handle=FileOpen(output_file,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("OUTPUT_OPEN_FAIL symbol=%s path=%s err=%d",symbol,output_file,GetLastError());
      return false;
     }
   if(FileWrite(handle,"time","open","high","low","close","tickvol")<=0)
     {
      PrintFormat("HEADER_WRITE_FAIL symbol=%s err=%d",symbol,GetLastError());
      FileClose(handle);
      return false;
     }

   const long chunk_seconds=(long)InpChunkDays*86400;
   long cursor=InpStartBrokerEpoch;
   long previous_time=0;
   bool ok=true;
   while(cursor<=InpEndBrokerEpoch && ok)
     {
      long chunk_end=cursor+chunk_seconds-60;
      if(chunk_end>InpEndBrokerEpoch) chunk_end=InpEndBrokerEpoch;
      MqlRates rates[];
      const int copied=CopyChunk(symbol,(datetime)cursor,(datetime)chunk_end,rates);
      if(copied<0)
        {
         PrintFormat("COPY_RATES_FAIL symbol=%s from=%I64d to=%I64d err=%d",
                     symbol,cursor,chunk_end,GetLastError());
         ok=false;
         break;
        }
      for(int i=0;i<copied;i++)
        {
         const long bar_time=(long)rates[i].time;
         if(bar_time<InpStartBrokerEpoch || bar_time>InpEndBrokerEpoch ||
            bar_time<cursor || bar_time>chunk_end || bar_time%60!=0 ||
            (previous_time>0 && bar_time<=previous_time) ||
            rates[i].open<=0.0 || rates[i].high<=0.0 ||
            rates[i].low<=0.0 || rates[i].close<=0.0 ||
            rates[i].high<MathMax(rates[i].open,rates[i].close) ||
            rates[i].low>MathMin(rates[i].open,rates[i].close) ||
            rates[i].high<rates[i].low || rates[i].tick_volume<0)
           {
            PrintFormat("BAR_REFUSED symbol=%s index=%d time=%I64d",symbol,i,bar_time);
            ok=false;
            break;
           }
         if(FileWrite(handle,bar_time,
                      DoubleToString(rates[i].open,digits),
                      DoubleToString(rates[i].high,digits),
                      DoubleToString(rates[i].low,digits),
                      DoubleToString(rates[i].close,digits),
                      (long)rates[i].tick_volume)<=0)
           {
            PrintFormat("ROW_WRITE_FAIL symbol=%s time=%I64d err=%d",
                        symbol,bar_time,GetLastError());
            ok=false;
            break;
           }
         previous_time=bar_time;
         written_rows++;
        }
      cursor=chunk_end+60;
     }
   FileFlush(handle);
   FileClose(handle);
   if(!ok || written_rows<=0)
     {
      PrintFormat("EXPORT_FAIL symbol=%s rows=%I64d",symbol,written_rows);
      return false;
     }
   PrintFormat("DWX_M1_OVERLAP_OK symbol=%s rows=%I64d",symbol,written_rows);
   return true;
  }

void OnStart()
  {
   string root=TerminalInfoString(TERMINAL_PATH);
   StringReplace(root,"/","\\");
   StringToLower(root);
   if(root!="d:\\qm\\mt5\\t1") { Print("WRONG_TERMINAL_REFUSED"); return; }
   if(InpStartBrokerEpoch!=1759287600 || InpEndBrokerEpoch!=1775012400 ||
      InpStartBrokerEpoch%60!=0 || InpEndBrokerEpoch%60!=0 ||
      InpStartBrokerEpoch>=InpEndBrokerEpoch)
     { Print("FIXED_WINDOW_REFUSED"); return; }
   if(InpChunkDays<1 || InpChunkDays>14 || InpSyncAttempts<1 || InpSyncAttempts>120)
     { Print("EXPORT_BOUNDS_REFUSED"); return; }
   if(FileIsExist(InpCompletion)) { Print("EXISTING_COMPLETION_REFUSED"); return; }

   string symbols[]={
      "AUDCAD.DWX","AUDCHF.DWX","AUDJPY.DWX","AUDNZD.DWX","AUDUSD.DWX",
      "CADCHF.DWX","CADJPY.DWX","CHFJPY.DWX","EURAUD.DWX","EURCAD.DWX",
      "EURCHF.DWX","EURGBP.DWX","EURJPY.DWX","EURNZD.DWX","EURUSD.DWX",
      "GBPAUD.DWX","GBPCAD.DWX","GBPCHF.DWX","GBPJPY.DWX","GBPNZD.DWX",
      "GBPUSD.DWX","GDAXI.DWX","NDX.DWX","NZDCAD.DWX","NZDCHF.DWX",
      "NZDJPY.DWX","NZDUSD.DWX","SP500.DWX","UK100.DWX","USDCAD.DWX",
      "USDCHF.DWX","USDJPY.DWX","WS30.DWX","XAGUSD.DWX","XAUUSD.DWX",
      "XNGUSD.DWX","XTIUSD.DWX"};
   if(ArraySize(symbols)!=37) { Print("UNIVERSE_SIZE_REFUSED"); return; }

   int successes=0,failures=0;
   long total_rows=0;
   for(int i=0;i<ArraySize(symbols);i++)
     {
      long rows=0;
      if(ExportOne(symbols[i],rows)) successes++; else failures++;
      total_rows+=rows;
     }

   const int marker=FileOpen(InpCompletion,FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(marker==INVALID_HANDLE)
     { PrintFormat("COMPLETION_OPEN_FAIL err=%d",GetLastError()); return; }
   FileWrite(marker,StringFormat(
      "successes=%d failures=%d terminal=T1 build=%d total_rows=%I64d",
      successes,failures,(int)TerminalInfoInteger(TERMINAL_BUILD),total_rows));
   FileFlush(marker);
   FileClose(marker);
   PrintFormat("DWX_M1_OVERLAP_COMPLETE successes=%d failures=%d total_rows=%I64d",
               successes,failures,total_rows);
  }
