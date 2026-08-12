//+------------------------------------------------------------------+
//| Export_FTMO_Joint_M15.mq5                                       |
//| Read-only M15 export for report-linked FTMO joint-equity work.   |
//| Writes terminal-local CSV files; never places or modifies trades.|
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

void FlushM15Bucket(const int handle,
                    const int digits,
                    const datetime bucket,
                    const double bar_open,
                    const double bar_high,
                    const double bar_low,
                    const double bar_close,
                    const long tick_volume,
                    datetime &first_time,
                    datetime &last_time,
                    int &written)
  {
   if(bucket <= 0 || tick_volume <= 0)
      return;
   FileWrite(handle,
             (long)bucket,
             DoubleToString(bar_open, digits),
             DoubleToString(bar_high, digits),
             DoubleToString(bar_low, digits),
             DoubleToString(bar_close, digits),
             tick_volume);
   if(first_time == 0)
      first_time = bucket;
   last_time = bucket;
   ++written;
  }

void ConsumeTicksAsM15(const int handle,
                       const int digits,
                       MqlTick &ticks[],
                       const int count,
                       datetime &bucket,
                       double &bar_open,
                       double &bar_high,
                       double &bar_low,
                       double &bar_close,
                       long &tick_volume,
                       datetime &first_time,
                       datetime &last_time,
                       int &written)
  {
   for(int i = 0; i < count; ++i)
     {
      double price = ticks[i].bid;
      if(price <= 0.0)
         price = ticks[i].last;
      if(price <= 0.0)
         continue;
      const datetime tick_time = (datetime)(ticks[i].time_msc / 1000);
      const datetime tick_bucket = (datetime)(((long)tick_time / 900) * 900);
      if(bucket == 0 || tick_bucket != bucket)
        {
         if(bucket > 0)
            FlushM15Bucket(handle,
                           digits,
                           bucket,
                           bar_open,
                           bar_high,
                           bar_low,
                           bar_close,
                           tick_volume,
                           first_time,
                           last_time,
                           written);
         bucket = tick_bucket;
         bar_open = price;
         bar_high = price;
         bar_low = price;
         bar_close = price;
         tick_volume = 1;
         continue;
        }
      bar_high = MathMax(bar_high, price);
      bar_low = MathMin(bar_low, price);
      bar_close = price;
      ++tick_volume;
     }
  }

void ExportSymbol(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
     {
      PrintFormat("FTMO_JOINT_SELECT_FAIL symbol=%s error=%d", symbol, GetLastError());
      return;
     }

   string safe_symbol = symbol;
   StringReplace(safe_symbol, ".", "_");
   const string path = StringFormat("FTMO_JOINT_%s_M15.csv", safe_symbol);
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("FTMO_JOINT_OPEN_FAIL symbol=%s path=%s error=%d",
                  symbol, path, GetLastError());
      return;
     }

   FileWrite(handle, "time", "open", "high", "low", "close", "tickvol");
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   int total = 0;
   datetime first_time = 0;
   datetime last_time = 0;
   datetime bucket = 0;
   double bar_open = 0.0;
   double bar_high = 0.0;
   double bar_low = 0.0;
   double bar_close = 0.0;
   long tick_volume = 0;
   const datetime first_day = D'2020.01.01 00:00';
   const datetime after_last_day = D'2021.01.01 00:00';
   for(datetime day = first_day; day < after_last_day; day += 86400)
     {
      const long from_msc = (long)day * 1000;
      const long to_msc = ((long)day + 86400) * 1000 - 1;
      MqlTick ticks[];
      int copied = 0;
      int error = 0;
      for(int attempt = 0; attempt < 5; ++attempt)
        {
         ResetLastError();
         copied = CopyTicksRange(symbol, ticks, COPY_TICKS_ALL, from_msc, to_msc);
         error = GetLastError();
         if(copied >= 0 && error != 4403)
            break;
         Sleep(1000);
        }
      if(copied < 0 || error == 4403)
        {
         PrintFormat("FTMO_JOINT_DAY_SYNC_FAIL symbol=%s day=%s copied=%d error=%d",
                     symbol, TimeToString(day, TIME_DATE), copied, error);
         continue;
        }
      if(copied == 0)
         continue;
      ConsumeTicksAsM15(handle,
                        digits,
                        ticks,
                        copied,
                        bucket,
                        bar_open,
                        bar_high,
                        bar_low,
                        bar_close,
                        tick_volume,
                        first_time,
                        last_time,
                        total);
     }
   FlushM15Bucket(handle,
                  digits,
                  bucket,
                  bar_open,
                  bar_high,
                  bar_low,
                  bar_close,
                  tick_volume,
                  first_time,
                  last_time,
                  total);
   PrintFormat("FTMO_JOINT_YEAR symbol=%s year=2020 rows=%d", symbol, total);
   FileClose(handle);
   PrintFormat("FTMO_JOINT_WROTE symbol=%s path=%s rows=%d first=%s last=%s",
               symbol,
               path,
               total,
               TimeToString(first_time, TIME_DATE | TIME_MINUTES),
               TimeToString(last_time, TIME_DATE | TIME_MINUTES));
  }

void OnStart()
  {
   // NDX is the only central export with a missing report year (2020).
   // The other three sleeves already have complete, hashable M5/M15 exports.
   const string symbols[] = {"NDX.DWX"};
   for(int i = 0; i < ArraySize(symbols); ++i)
      ExportSymbol(symbols[i]);
   Print("FTMO_JOINT_EXPORT_DONE");
  }
