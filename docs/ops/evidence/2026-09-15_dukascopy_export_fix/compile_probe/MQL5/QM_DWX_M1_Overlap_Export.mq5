// Governed, read-only M1 export for the fixed DWX/Dukascopy overlap window.
#property strict

input string InpOutputDir="QM\\dwx_m1_overlap";
input string InpCompletion="QM_DWX_M1_OVERLAP_COMPLETE.txt";
input long InpStartBrokerEpoch=1759287600;
input long InpEndBrokerEpoch=1775012400;
input int InpChunkDays=7;
input int InpSyncAttempts=30;

void JournalChunk(const int handle,const string symbol,const long chunk_start,
                   const long chunk_end,const string phase,const int attempt,
                   const int copied,const int error_code,const string status)
  {
   if(handle==INVALID_HANDLE) return;
   FileWrite(handle,symbol,chunk_start,chunk_end,phase,attempt,copied,error_code,status);
   FileFlush(handle);
  }

int CopyChunk(const int journal_handle,const string symbol,const long chunk_start,
              const long chunk_end,const ulong start_msc,const ulong end_msc,MqlTick &ticks[])
  {
   ArrayResize(ticks,0);
   ArraySetAsSeries(ticks,false);
   int copied=-1;
   int copy_error=0;
   for(int attempt=1;attempt<=InpSyncAttempts;attempt++)
     {
      ResetLastError();
      copied=CopyTicksRange(symbol,ticks,COPY_TICKS_ALL,start_msc,end_msc);
      copy_error=GetLastError();
      JournalChunk(journal_handle,symbol,chunk_start,chunk_end,"sync",attempt,copied,copy_error,"ATTEMPT");
      if(copied>=0 && copy_error!=ERR_HISTORY_TIMEOUT)
         break;
      Sleep(1000);
     }
   if(copied<0)
     {
      JournalChunk(journal_handle,symbol,chunk_start,chunk_end,"sync",0,copied,copy_error,"COPY_FAIL");
      return copied;
     }
   // A copied=0 result is a legitimate CopyTicksRange return (no history-timeout
   // error) both when a symbol genuinely traded zero ticks in the 7-day window and
   // when the terminal's tick database has not finished serving it yet. Accepting
   // it immediately (the prior defect) silently produced 11 near-empty symbol
   // exports in the 2026-09-13 run; retry with backoff before treating it as final.
   if(copied==0)
     {
      const int backoff_ms[3]={2000,5000,10000};
      for(int retry=0;retry<3 && copied==0;retry++)
        {
         Sleep(backoff_ms[retry]);
         ResetLastError();
         copied=CopyTicksRange(symbol,ticks,COPY_TICKS_ALL,start_msc,end_msc);
         copy_error=GetLastError();
         JournalChunk(journal_handle,symbol,chunk_start,chunk_end,"zero_retry",retry+1,copied,copy_error,"ATTEMPT");
        }
     }
   const string final_status=(copied>0)?"OK":"ZERO_TICK_CHUNK";
   JournalChunk(journal_handle,symbol,chunk_start,chunk_end,"final",0,copied,0,final_status);
   if(copied<=0)
      PrintFormat("ZERO_TICK_CHUNK symbol=%s from=%I64d to=%I64d",symbol,chunk_start,chunk_end);
   return copied;
  }

bool FlushBar(const int handle,const int digits,const long minute,
              const double bar_open,const double bar_high,const double bar_low,
              const double bar_close,const long tick_volume,long &written_rows)
  {
   if(minute<=0 || tick_volume<=0) return true;
   if(FileWrite(handle,minute,
                DoubleToString(bar_open,digits),DoubleToString(bar_high,digits),
                DoubleToString(bar_low,digits),DoubleToString(bar_close,digits),
                tick_volume)<=0)
     {
      PrintFormat("ROW_WRITE_FAIL time=%I64d err=%d",minute,GetLastError());
      return false;
     }
   written_rows++;
   return true;
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

   const string journal_file=InpOutputDir+"\\"+symbol+"_M1_chunks.csv";
   const int journal_handle=FileOpen(journal_file,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(journal_handle==INVALID_HANDLE)
     {
      PrintFormat("CHUNK_JOURNAL_OPEN_FAIL symbol=%s path=%s err=%d",symbol,journal_file,GetLastError());
      FileClose(handle);
      return false;
     }
   if(FileWrite(journal_handle,"symbol","chunk_start_epoch","chunk_end_epoch","phase","attempt",
                "copied","error_code","status")<=0)
     {
      PrintFormat("CHUNK_JOURNAL_HEADER_FAIL symbol=%s err=%d",symbol,GetLastError());
      FileClose(handle);
      FileClose(journal_handle);
      return false;
     }

   const long chunk_seconds=(long)InpChunkDays*86400;
   long cursor=InpStartBrokerEpoch;
   long previous_tick_msc=0;
   long minute=0;
   double bar_open=0.0,bar_high=0.0,bar_low=0.0,bar_close=0.0;
   long tick_volume=0;
   bool ok=true;
   while(cursor<InpEndBrokerEpoch && ok)
     {
      long chunk_end=cursor+chunk_seconds;
      if(chunk_end>InpEndBrokerEpoch) chunk_end=InpEndBrokerEpoch;
      MqlTick ticks[];
      const ulong from_msc=(ulong)cursor*1000;
      const ulong to_msc=(ulong)chunk_end*1000-1;
      const int copied=CopyChunk(journal_handle,symbol,cursor,chunk_end,from_msc,to_msc,ticks);
      if(copied<0)
        {
         PrintFormat("COPY_TICKS_RANGE_FAIL symbol=%s from=%I64d to=%I64d err=%d",
                     symbol,cursor,chunk_end,GetLastError());
         ok=false;
         break;
        }
      for(int i=0;i<copied;i++)
        {
         const long tick_msc=(long)ticks[i].time_msc;
         const long tick_time=tick_msc/1000;
         const double price=ticks[i].bid;
         if(tick_msc<=0 || tick_time<cursor || tick_time>=chunk_end ||
            tick_time<InpStartBrokerEpoch || tick_time>=InpEndBrokerEpoch ||
            (previous_tick_msc>0 && tick_msc<previous_tick_msc))
           {
            PrintFormat("TICK_REFUSED symbol=%s index=%d time_msc=%I64d",symbol,i,tick_msc);
            ok=false;
            break;
           }
         previous_tick_msc=tick_msc;
         if(price<=0.0 || !MathIsValidNumber(price)) continue;
         const long tick_minute=(tick_time/60)*60;
         if(minute!=tick_minute)
           {
            if(!FlushBar(handle,digits,minute,bar_open,bar_high,bar_low,bar_close,
                         tick_volume,written_rows)) { ok=false; break; }
            minute=tick_minute;
            bar_open=price;
            bar_high=price;
            bar_low=price;
            bar_close=price;
            tick_volume=1;
           }
         else
           {
            if(price>bar_high) bar_high=price;
            if(price<bar_low) bar_low=price;
            bar_close=price;
            tick_volume++;
           }
        }
      cursor=chunk_end;
     }
   if(ok && !FlushBar(handle,digits,minute,bar_open,bar_high,bar_low,bar_close,
                      tick_volume,written_rows)) ok=false;
   FileFlush(handle);
   FileClose(handle);
   FileFlush(journal_handle);
   FileClose(journal_handle);
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
   const ulong fleet_started=GetTickCount64();
   for(int i=0;i<ArraySize(symbols);i++)
     {
      const ulong symbol_started=GetTickCount64();
      long rows=0;
      if(ExportOne(symbols[i],rows)) successes++; else failures++;
      total_rows+=rows;
      const ulong symbol_elapsed=GetTickCount64()-symbol_started;
      PrintFormat("DWX_M1_TICK_AGG_RUNTIME symbol=%s elapsed_ms=%I64u",symbols[i],symbol_elapsed);
      if(i==1)
        {
         const ulong first_two_elapsed=GetTickCount64()-fleet_started;
         PrintFormat("DWX_M1_TICK_AGG_PROJECTION sample_symbols=2 sample_elapsed_ms=%I64u projected_37_ms=%I64u",
                     first_two_elapsed,(first_two_elapsed*37)/2);
        }
     }

   const int marker=FileOpen(InpCompletion,FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(marker==INVALID_HANDLE)
     { PrintFormat("COMPLETION_OPEN_FAIL err=%d",GetLastError()); return; }
   FileWrite(marker,StringFormat(
      "successes=%d failures=%d terminal=T1 build=%d total_rows=%I64d elapsed_ms=%I64u",
      successes,failures,(int)TerminalInfoInteger(TERMINAL_BUILD),total_rows,
      GetTickCount64()-fleet_started));
   FileFlush(marker);
   FileClose(marker);
   PrintFormat("DWX_M1_OVERLAP_COMPLETE successes=%d failures=%d total_rows=%I64d",
               successes,failures,total_rows);
  }
