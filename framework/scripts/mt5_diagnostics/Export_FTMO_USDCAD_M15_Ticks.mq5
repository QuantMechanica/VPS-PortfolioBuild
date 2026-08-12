//+------------------------------------------------------------------+
//| Export_FTMO_USDCAD_M15_Ticks.mq5                               |
//| Read-only M15 aggregation from the full custom-symbol tick store.|
//+------------------------------------------------------------------+
#property script_show_inputs false

long MonthStartMs(const int year, const int month)
  {
   MqlDateTime value = {0};
   value.year = year;
   value.mon = month;
   value.day = 1;
   return (long)StructToTime(value) * 1000;
  }

long MonthEndMs(const int year, const int month)
  {
   int next_year = year;
   int next_month = month + 1;
   if(next_month > 12)
     {
      next_month = 1;
      ++next_year;
     }
   return MonthStartMs(next_year, next_month) - 1;
  }

int WriteMonth(const int handle, MqlTick &ticks[], const int count, const int digits)
  {
   datetime bucket = 0;
   double bar_open = 0.0;
   double bar_high = 0.0;
   double bar_low = 0.0;
   double bar_close = 0.0;
   long tick_volume = 0;
   int bars = 0;
   for(int index = 0; index < count; ++index)
     {
      double price = ticks[index].bid;
      if(price <= 0.0)
         price = ticks[index].last;
      if(price <= 0.0)
         continue;
      const datetime tick_time = (datetime)(ticks[index].time_msc / 1000);
      const datetime next_bucket = tick_time - (tick_time % 900);
      if(next_bucket != bucket)
        {
         if(bucket != 0)
           {
            FileWrite(handle,
                      (long)bucket,
                      DoubleToString(bar_open, digits),
                      DoubleToString(bar_high, digits),
                      DoubleToString(bar_low, digits),
                      DoubleToString(bar_close, digits),
                      tick_volume);
            ++bars;
           }
         bucket = next_bucket;
         bar_open = price;
         bar_high = price;
         bar_low = price;
         bar_close = price;
         tick_volume = 1;
        }
      else
        {
         if(price > bar_high)
            bar_high = price;
         if(price < bar_low)
            bar_low = price;
         bar_close = price;
         ++tick_volume;
        }
     }
   if(bucket != 0)
     {
      FileWrite(handle,
                (long)bucket,
                DoubleToString(bar_open, digits),
                DoubleToString(bar_high, digits),
                DoubleToString(bar_low, digits),
                DoubleToString(bar_close, digits),
                tick_volume);
      ++bars;
     }
   return bars;
  }

void OnStart()
  {
   const string symbol = "USDCAD.DWX";
   if(!SymbolSelect(symbol, true))
     {
      PrintFormat("FTMO_USDCAD_TICK_SELECT_FAIL error=%d", GetLastError());
      return;
     }
   const string path = "FTMO_JOINT_USDCAD_DWX_M15_TICKS.csv";
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("FTMO_USDCAD_TICK_OPEN_FAIL error=%d", GetLastError());
      return;
     }
   FileWrite(handle, "time", "open", "high", "low", "close", "tickvol");
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long total_ticks = 0;
   int total_bars = 0;
   for(int year = 2018; year <= 2025; ++year)
     {
      long year_ticks = 0;
      int year_bars = 0;
      for(int month = 1; month <= 12; ++month)
        {
         MqlTick ticks[];
         int copied = -1;
         int error = 0;
         for(int attempt = 0; attempt < 5; ++attempt)
           {
            ResetLastError();
            copied = CopyTicksRange(symbol,
                                    ticks,
                                    COPY_TICKS_INFO,
                                    MonthStartMs(year, month),
                                    MonthEndMs(year, month));
            error = GetLastError();
            if(copied >= 0 && error != ERR_HISTORY_TIMEOUT)
               break;
            Sleep(1000);
           }
         if(copied <= 0)
           {
            PrintFormat("FTMO_USDCAD_TICK_MONTH_EMPTY year=%d month=%d copied=%d error=%d",
                        year, month, copied, error);
            continue;
           }
         const int bars = WriteMonth(handle, ticks, copied, digits);
         year_ticks += copied;
         year_bars += bars;
         ArrayFree(ticks);
        }
      total_ticks += year_ticks;
      total_bars += year_bars;
      PrintFormat("FTMO_USDCAD_TICK_YEAR year=%d ticks=%I64d bars=%d", year, year_ticks, year_bars);
      FileFlush(handle);
     }
   FileClose(handle);
   PrintFormat("FTMO_USDCAD_TICK_WROTE path=%s ticks=%I64d bars=%d", path, total_ticks, total_bars);
  }
