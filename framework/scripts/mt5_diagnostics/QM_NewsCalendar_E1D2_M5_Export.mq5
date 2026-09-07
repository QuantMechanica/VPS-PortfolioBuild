// Read-only M5 footprint export, restricted to the dedicated T_Export lane.
#property strict

input datetime InpFrom=D'2018.01.01';
input datetime InpTo=D'2026.07.01';
input string InpCompletion="E1D2_M5_EXPORT_COMPLETE.txt";

bool ExportOne(const string symbol)
  {
   if(InpFrom>=InpTo || InpFrom<D'2017.01.01' || InpTo>D'2027.01.01')
     { Print("REFUSED_RANGE"); return false; }
   const string filename=symbol+"_M5.csv";
   if(FileIsExist(filename))
     { PrintFormat("EXISTING_OUTPUT_REFUSED %s",filename); return false; }
   if(!SymbolSelect(symbol,true))
     { PrintFormat("SYMBOL_SELECT_FAIL %s err=%d",symbol,GetLastError()); return false; }

   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   ResetLastError();
   const int copied=CopyRates(symbol,PERIOD_M5,InpFrom,InpTo,rates);
   if(copied<=0)
     { PrintFormat("COPY_RATES_FAIL %s count=%d err=%d",symbol,copied,GetLastError()); return false; }

   const int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     { PrintFormat("FILE_OPEN_FAIL %s err=%d",filename,GetLastError()); return false; }
   FileWrite(handle,"time","open","high","low","close","tickvol");
   bool ok=true;
   for(int i=0;i<copied;i++)
     {
      if(i>0 && rates[i].time<=rates[i-1].time) { ok=false; break; }
      if(FileWrite(handle,(long)rates[i].time,
                   DoubleToString(rates[i].open,6),
                   DoubleToString(rates[i].high,6),
                   DoubleToString(rates[i].low,6),
                   DoubleToString(rates[i].close,6),
                   (long)rates[i].tick_volume)==0)
        { ok=false; break; }
     }
   FileFlush(handle);
   FileClose(handle);
   if(!ok)
     { FileDelete(filename); PrintFormat("WRITE_OR_ORDER_FAIL %s",filename); return false; }
   PrintFormat("E1D2_M5_EXPORT_OK file=%s rows=%d first=%s last=%s",filename,copied,
               TimeToString(rates[0].time),TimeToString(rates[copied-1].time));
   return true;
  }

void OnStart()
  {
   string root=TerminalInfoString(TERMINAL_PATH);
   StringReplace(root,"/","\\");
   StringToLower(root);
   if(root!="d:\\qm\\mt5\\t_export") { Print("WRONG_TERMINAL_REFUSED"); return; }
   if(FileIsExist(InpCompletion)) { Print("COMPLETION_EXISTS_REFUSED"); return; }

   string symbols[]={"AUDUSD.DWX","USDCAD.DWX"};
   int successes=0,failures=0;
   for(int i=0;i<ArraySize(symbols);i++)
     if(ExportOne(symbols[i])) successes++; else failures++;

   const int handle=FileOpen(InpCompletion,FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(handle!=INVALID_HANDLE)
     {
      FileWrite(handle,StringFormat("successes=%d failures=%d",successes,failures));
      FileFlush(handle);
      FileClose(handle);
     }
   PrintFormat("E1D2_M5_BATCH_COMPLETE successes=%d failures=%d",successes,failures);
  }
