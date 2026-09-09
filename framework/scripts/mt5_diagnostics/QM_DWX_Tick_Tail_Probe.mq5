// Governed, read-only tick-tail inventory for the 37 QuantMechanica .DWX symbols.
#property strict

input string InpOutputFile="QM\\dwx_tick_tail\\tick_tail_raw.csv";
input string InpMetadataFile="QM\\dwx_tick_tail\\price_scale_raw.csv";
input string InpCompletion="QM_DWX_TICK_TAIL_COMPLETE.txt";
input int InpSyncAttempts=90;

bool ProbeOne(const string symbol,const int handle)
  {
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

   MqlTick tail[];
   ArraySetAsSeries(tail,false);
   int tail_count=-1;
   for(int attempt=0;attempt<InpSyncAttempts;attempt++)
     {
      ResetLastError();
      tail_count=CopyTicks(symbol,tail,COPY_TICKS_ALL,0,1);
      if(tail_count==1 && tail[0].time_msc>0) break;
      Sleep(1000);
     }
   if(tail_count!=1 || tail[0].time_msc<=0)
     {
      PrintFormat("TAIL_COPY_FAIL symbol=%s count=%d err=%d",symbol,tail_count,GetLastError());
      return false;
     }

   MqlTick first[];
   ArraySetAsSeries(first,false);
   ResetLastError();
   const int first_count=CopyTicks(symbol,first,COPY_TICKS_ALL,1,1);
   if(first_count!=1 || first[0].time_msc<=0 || first[0].time_msc>tail[0].time_msc)
     {
      PrintFormat("FIRST_COPY_FAIL symbol=%s count=%d err=%d",symbol,first_count,GetLastError());
      return false;
     }

   const ulong last_msc=(ulong)tail[0].time_msc;
   const ulong day_from=(last_msc>86400000 ? last_msc-86400000+1 : 1);
   MqlTick day_ticks[];
   ArraySetAsSeries(day_ticks,false);
   ResetLastError();
   const int day_count=CopyTicksRange(symbol,day_ticks,COPY_TICKS_ALL,day_from,last_msc);
   if(day_count<=0)
     {
      PrintFormat("DAY_COPY_FAIL symbol=%s count=%d err=%d",symbol,day_count,GetLastError());
      return false;
     }

   const int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   if(tail[0].bid<=0.0 || tail[0].ask<=0.0 || tail[0].ask<tail[0].bid)
     {
      PrintFormat("TAIL_PRICE_FAIL symbol=%s bid=%.12f ask=%.12f",symbol,tail[0].bid,tail[0].ask);
      return false;
     }
   if(FileWrite(handle,symbol,(long)tail[0].time_msc,
                DoubleToString(tail[0].bid,digits),DoubleToString(tail[0].ask,digits),
                day_count,(long)first[0].time_msc,"T1")<=0)
     {
      PrintFormat("ROW_WRITE_FAIL symbol=%s err=%d",symbol,GetLastError());
      return false;
     }
   PrintFormat("DWX_TICK_TAIL_OK symbol=%s first=%I64d last=%I64d day_count=%d",
               symbol,first[0].time_msc,tail[0].time_msc,day_count);
   return true;
  }

bool ProbeMetadataOne(const string symbol,const int handle)
  {
   if(!SymbolSelect(symbol,true))
     {
      PrintFormat("METADATA_SYMBOL_SELECT_FAIL symbol=%s err=%d",symbol,GetLastError());
      return false;
     }
   long digits_raw=0;
   double point=0.0;
   ResetLastError();
   if(!SymbolInfoInteger(symbol,SYMBOL_DIGITS,digits_raw))
     {
      PrintFormat("SYMBOL_DIGITS_FAIL symbol=%s err=%d",symbol,GetLastError());
      return false;
     }
   ResetLastError();
   if(!SymbolInfoDouble(symbol,SYMBOL_POINT,point))
     {
      PrintFormat("SYMBOL_POINT_FAIL symbol=%s err=%d",symbol,GetLastError());
      return false;
     }
   const int digits=(int)digits_raw;
   if(digits<0 || digits>12 || point<=0.0)
     {
      PrintFormat("SYMBOL_METADATA_INVALID symbol=%s digits=%d point=%.12f",symbol,digits,point);
      return false;
     }
   long price_scale=1;
   for(int i=0;i<digits;i++) price_scale*=10;
   if(FileWrite(handle,symbol,digits,DoubleToString(point,digits),price_scale)<=0)
     {
      PrintFormat("METADATA_ROW_WRITE_FAIL symbol=%s err=%d",symbol,GetLastError());
      return false;
     }
   PrintFormat("DWX_PRICE_SCALE_OK symbol=%s digits=%d point=%s price_scale=%I64d",
               symbol,digits,DoubleToString(point,digits),price_scale);
   return true;
  }

void OnStart()
  {
   string root=TerminalInfoString(TERMINAL_PATH);
   StringReplace(root,"/","\\");
   StringToLower(root);
   if(root!="d:\\qm\\mt5\\t1") { Print("WRONG_TERMINAL_REFUSED"); return; }
   if(InpSyncAttempts<1 || InpSyncAttempts>300) { Print("SYNC_ATTEMPTS_REFUSED"); return; }
   if(FileIsExist(InpOutputFile) || FileIsExist(InpMetadataFile) || FileIsExist(InpCompletion))
     { Print("EXISTING_OUTPUT_REFUSED"); return; }

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

   const int handle=FileOpen(InpOutputFile,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     { PrintFormat("OUTPUT_OPEN_FAIL path=%s err=%d",InpOutputFile,GetLastError()); return; }
   FileWrite(handle,"symbol","last_tick_time_msc","last_tick_bid","last_tick_ask",
             "tick_count_last_day","first_tick_time_msc","source_terminal");
   int successes=0,failures=0;
   for(int i=0;i<ArraySize(symbols);i++)
     if(ProbeOne(symbols[i],handle)) successes++; else failures++;
   FileFlush(handle);
   FileClose(handle);

   string metadata_symbols[]={
      "GDAXI.DWX","NDX.DWX","SP500.DWX","UK100.DWX","WS30.DWX",
      "XAGUSD.DWX","XAUUSD.DWX","XNGUSD.DWX","XTIUSD.DWX"};
   if(ArraySize(metadata_symbols)!=9) { Print("METADATA_UNIVERSE_SIZE_REFUSED"); return; }
   const int metadata_handle=FileOpen(InpMetadataFile,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(metadata_handle==INVALID_HANDLE)
     { PrintFormat("METADATA_OUTPUT_OPEN_FAIL path=%s err=%d",InpMetadataFile,GetLastError()); return; }
   FileWrite(metadata_handle,"symbol","digits","point","price_scale");
   int metadata_successes=0,metadata_failures=0;
   for(int i=0;i<ArraySize(metadata_symbols);i++)
     if(ProbeMetadataOne(metadata_symbols[i],metadata_handle)) metadata_successes++; else metadata_failures++;
   FileFlush(metadata_handle);
   FileClose(metadata_handle);

   const int marker=FileOpen(InpCompletion,FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(marker==INVALID_HANDLE)
     { PrintFormat("COMPLETION_OPEN_FAIL err=%d",GetLastError()); return; }
   FileWrite(marker,StringFormat(
      "successes=%d failures=%d terminal=T1 build=%d metadata_successes=%d metadata_failures=%d",
      successes,failures,(int)TerminalInfoInteger(TERMINAL_BUILD),metadata_successes,metadata_failures));
   FileFlush(marker);
   FileClose(marker);
   PrintFormat("DWX_TICK_TAIL_COMPLETE successes=%d failures=%d metadata_successes=%d metadata_failures=%d",
               successes,failures,metadata_successes,metadata_failures);
  }
