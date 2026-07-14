//+------------------------------------------------------------------+
//| Export_FTMO_XTI_M15.mq5                                        |
//| Read-only monthly M15 export for the FTMO joint-equity model.    |
//+------------------------------------------------------------------+
#property script_show_inputs false

datetime MonthStart(const int year, const int month)
  {
   MqlDateTime value = {0};
   value.year = year;
   value.mon = month;
   value.day = 1;
   return StructToTime(value);
  }

datetime MonthEnd(const int year, const int month)
  {
   int next_year = year;
   int next_month = month + 1;
   if(next_month > 12)
     {
      next_month = 1;
      ++next_year;
     }
   return MonthStart(next_year, next_month) - 1;
  }

void OnStart()
  {
   const string symbol = "XTIUSD.DWX";
   if(!SymbolSelect(symbol, true))
     {
      PrintFormat("FTMO_XTI_M15_SELECT_FAIL error=%d", GetLastError());
      return;
     }
   const string path = "FTMO_JOINT_XTIUSD_DWX_M15.csv";
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("FTMO_XTI_M15_OPEN_FAIL error=%d", GetLastError());
      return;
     }
   FileWrite(handle, "time", "open", "high", "low", "close", "tickvol");
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   int total = 0;
   datetime first_time = 0;
   datetime last_time = 0;
   for(int year = 2018; year <= 2025; ++year)
     {
      int year_total = 0;
      for(int month = 1; month <= 12; ++month)
        {
         MqlRates rates[];
         ArraySetAsSeries(rates, false);
         int copied = -1;
         int error = 0;
         for(int attempt = 0; attempt < 5; ++attempt)
           {
            ResetLastError();
            copied = CopyRates(symbol, PERIOD_M15, MonthStart(year, month), MonthEnd(year, month), rates);
            error = GetLastError();
            if(copied >= 0 && error != ERR_HISTORY_TIMEOUT)
               break;
            Sleep(1000);
           }
         if(copied < 0 || error == ERR_HISTORY_TIMEOUT)
           {
            PrintFormat("FTMO_XTI_M15_MONTH_FAIL year=%d month=%d copied=%d error=%d",
                        year, month, copied, error);
            continue;
           }
         for(int index = 0; index < copied; ++index)
           {
            FileWrite(handle,
                      (long)rates[index].time,
                      DoubleToString(rates[index].open, digits),
                      DoubleToString(rates[index].high, digits),
                      DoubleToString(rates[index].low, digits),
                      DoubleToString(rates[index].close, digits),
                      rates[index].tick_volume);
            if(first_time == 0)
               first_time = rates[index].time;
            last_time = rates[index].time;
           }
         year_total += copied;
         total += copied;
        }
      PrintFormat("FTMO_XTI_M15_YEAR year=%d rows=%d", year, year_total);
     }
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("FTMO_XTI_M15_WROTE path=%s rows=%d first=%s last=%s",
               path,
               total,
               TimeToString(first_time, TIME_DATE | TIME_MINUTES),
               TimeToString(last_time, TIME_DATE | TIME_MINUTES));
  }
