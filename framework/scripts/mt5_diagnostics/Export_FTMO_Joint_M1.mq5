//+------------------------------------------------------------------+
//| Export_FTMO_Joint_M1.mq5                                        |
//| Read-only M1 export from existing custom-symbol bar history.     |
//| Writes terminal-local CSV files; never places or modifies trades.|
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

void ExportSymbol(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
     {
      PrintFormat("FTMO_JOINT_M1_SELECT_FAIL symbol=%s error=%d", symbol, GetLastError());
      return;
     }

   string safe_symbol = symbol;
   StringReplace(safe_symbol, ".", "_");
   const string path = StringFormat("FTMO_JOINT_%s_M1.csv", safe_symbol);
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("FTMO_JOINT_M1_OPEN_FAIL symbol=%s path=%s error=%d",
                  symbol, path, GetLastError());
      return;
     }

   FileWrite(handle, "time", "open", "high", "low", "close", "tickvol");
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const int years[] = {2018, 2019, 2021, 2022, 2023, 2024, 2025};
   int total = 0;
   datetime first_time = 0;
   datetime last_time = 0;
   for(int yi = 0; yi < ArraySize(years); ++yi)
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
            copied = CopyRates(symbol,
                               PERIOD_M1,
                               MonthStart(years[yi], month),
                               MonthEnd(years[yi], month),
                               rates);
            error = GetLastError();
            if(copied >= 0 && error != ERR_HISTORY_TIMEOUT)
               break;
            Sleep(1000);
           }
         if(copied < 0 || error == ERR_HISTORY_TIMEOUT)
           {
            PrintFormat("FTMO_JOINT_M1_MONTH_FAIL symbol=%s year=%d month=%d copied=%d error=%d",
                        symbol, years[yi], month, copied, error);
            continue;
           }
         for(int i = 0; i < copied; ++i)
           {
            FileWrite(handle,
                      (long)rates[i].time,
                      DoubleToString(rates[i].open, digits),
                      DoubleToString(rates[i].high, digits),
                      DoubleToString(rates[i].low, digits),
                      DoubleToString(rates[i].close, digits),
                      rates[i].tick_volume);
            if(first_time == 0)
               first_time = rates[i].time;
            last_time = rates[i].time;
           }
         year_total += copied;
         total += copied;
        }
      PrintFormat("FTMO_JOINT_M1_YEAR symbol=%s year=%d rows=%d",
                  symbol, years[yi], year_total);
     }
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("FTMO_JOINT_M1_WROTE symbol=%s path=%s rows=%d first=%s last=%s",
               symbol,
               path,
               total,
               TimeToString(first_time, TIME_DATE | TIME_MINUTES),
               TimeToString(last_time, TIME_DATE | TIME_MINUTES));
  }

void OnStart()
  {
   ExportSymbol("NDX.DWX");
   Print("FTMO_JOINT_M1_EXPORT_DONE");
  }
