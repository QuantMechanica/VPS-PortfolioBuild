// Read-only native Darwinex D1 export for the governed QM5_1537 universe.
#property strict

input datetime InpFrom=D'2023.01.01';
input datetime InpTo=D'2026.09.08';
input datetime InpMinimumLast=D'2026.09.01';
input string InpOutputDir="QM\\1537_native_d1";
input string InpCompletion="QM1537_NATIVE_D1_COMPLETE.txt";

bool WaitConnected()
  {
   for(int attempt=0;attempt<120;attempt++)
     {
      if((bool)TerminalInfoInteger(TERMINAL_CONNECTED)) return true;
      Sleep(1000);
     }
   Print("CONNECTION_TIMEOUT");
   return false;
  }

bool ExportOne(const string canonical,const string native)
  {
   if(InpFrom>=InpTo || InpFrom<D'2022.01.01' || InpTo>TimeTradeServer()+172800 ||
      InpMinimumLast<InpFrom || InpMinimumLast>=InpTo)
     { Print("REFUSED_RANGE"); return false; }
   const string filename=InpOutputDir+"\\"+canonical+"_D1.csv";
   if(FileIsExist(filename))
     { PrintFormat("EXISTING_OUTPUT_REFUSED %s",filename); return false; }
   if(!SymbolSelect(native,true))
     { PrintFormat("SYMBOL_SELECT_FAIL canonical=%s native=%s err=%d",canonical,native,GetLastError()); return false; }

   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int copied=-1;
   for(int attempt=0;attempt<120;attempt++)
     {
      ResetLastError();
      copied=CopyRates(native,PERIOD_D1,InpFrom,InpTo,rates);
      if(copied>=270 && rates[copied-1].time>=InpMinimumLast) break;
      Sleep(2000);
     }
   if(copied<270 || rates[copied-1].time<InpMinimumLast)
     {
      const long last=(copied>0 ? (long)rates[copied-1].time : 0);
      PrintFormat("COPY_RATES_INCOMPLETE canonical=%s native=%s count=%d last=%I64d err=%d",
                  canonical,native,copied,last,GetLastError());
      return false;
     }

   const int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     { PrintFormat("FILE_OPEN_FAIL %s err=%d",filename,GetLastError()); return false; }
   FileWrite(handle,"time","open","high","low","close","tickvol","spread");
   bool ok=true;
   for(int i=0;i<copied;i++)
     {
      if((i>0 && rates[i].time<=rates[i-1].time) || rates[i].close<=0.0)
        { ok=false; break; }
      if(FileWrite(handle,(long)rates[i].time,
                   DoubleToString(rates[i].open,8),
                   DoubleToString(rates[i].high,8),
                   DoubleToString(rates[i].low,8),
                   DoubleToString(rates[i].close,8),
                   (long)rates[i].tick_volume,(long)rates[i].spread)==0)
        { ok=false; break; }
     }
   FileFlush(handle);
   FileClose(handle);
   if(!ok)
     { FileDelete(filename); PrintFormat("WRITE_OR_ORDER_FAIL %s",filename); return false; }
   PrintFormat("QM1537_D1_EXPORT_OK canonical=%s native=%s rows=%d first=%I64d last=%I64d",
               canonical,native,copied,(long)rates[0].time,(long)rates[copied-1].time);
   return true;
  }

void OnStart()
  {
   string root=TerminalInfoString(TERMINAL_PATH);
   StringReplace(root,"/","\\");
   StringToLower(root);
   if(root!="d:\\qm\\mt5\\t_export") { Print("WRONG_TERMINAL_REFUSED"); return; }
   if(FileIsExist(InpCompletion)) { Print("COMPLETION_EXISTS_REFUSED"); return; }
   if(!WaitConnected()) return;

   string canonical[]={
      "XAUUSD.DWX","XAGUSD.DWX","XNGUSD.DWX","XTIUSD.DWX",
      "NDX.DWX","WS30.DWX","GDAXI.DWX","UK100.DWX","SP500.DWX",
      "AUDCAD.DWX","AUDCHF.DWX","AUDJPY.DWX","AUDNZD.DWX","AUDUSD.DWX",
      "CADCHF.DWX","CADJPY.DWX","CHFJPY.DWX","EURAUD.DWX","EURCAD.DWX",
      "EURCHF.DWX","EURGBP.DWX","EURJPY.DWX","EURNZD.DWX","EURUSD.DWX",
      "GBPAUD.DWX","GBPCAD.DWX","GBPCHF.DWX","GBPJPY.DWX","GBPNZD.DWX",
      "GBPUSD.DWX","NZDCAD.DWX","NZDCHF.DWX","NZDJPY.DWX","NZDUSD.DWX",
      "USDCAD.DWX","USDCHF.DWX","USDJPY.DWX"};
   string native[]={
      "XAUUSD","XAGUSD","XNGUSD","XTIUSD","NDX","WS30","GDAXI","UK100","SP500",
      "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD","CADCHF","CADJPY","CHFJPY",
      "EURAUD","EURCAD","EURCHF","EURGBP","EURJPY","EURNZD","EURUSD","GBPAUD",
      "GBPCAD","GBPCHF","GBPJPY","GBPNZD","GBPUSD","NZDCAD","NZDCHF","NZDJPY",
      "NZDUSD","USDCAD","USDCHF","USDJPY"};
   if(ArraySize(canonical)!=37 || ArraySize(native)!=37) { Print("UNIVERSE_SIZE_REFUSED"); return; }

   int successes=0,failures=0;
   for(int i=0;i<ArraySize(canonical);i++)
     if(ExportOne(canonical[i],native[i])) successes++; else failures++;

   const int handle=FileOpen(InpCompletion,FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(handle!=INVALID_HANDLE)
     {
      FileWrite(handle,StringFormat(
         "successes=%d failures=%d server=%s login=%I64d build=%d company=%s",
         successes,failures,AccountInfoString(ACCOUNT_SERVER),AccountInfoInteger(ACCOUNT_LOGIN),
         (int)TerminalInfoInteger(TERMINAL_BUILD),AccountInfoString(ACCOUNT_COMPANY)));
      FileFlush(handle);
      FileClose(handle);
     }
   PrintFormat("QM1537_D1_BATCH_COMPLETE successes=%d failures=%d",successes,failures);
  }
