//+------------------------------------------------------------------+
//| QM_M1_SpreadHarvest.mq5                                         |
//| Read-only M1 OHLC/spread and native tick-window evidence.       |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

input string InpSymbols   = "XAUUSD";
input string InpOutputTag = "FTMO_STREAM1";
// Fixed offset is declared for this bounded summer window, not inferred from
// TimeTradeServer (which is not historical timezone evidence).
input int InpServerUtcOffsetMinutes = 180;
input datetime InpFromServer = D'2026.05.20 00:00';
input datetime InpToServer = D'2026.09.05 00:00';
input bool InpObserveTicks = false;

#define QM_HARVEST_FROM D'2026.01.01 00:00'
#define QM_BAR_CHUNK_DAYS 7
#define QM_TICK_CHUNK_DAYS 1
#define QM_COPY_ATTEMPTS 3
#define QM_CONNECT_WAIT_SECONDS 180
#define QM_SYNC_ATTEMPTS 90
#define QM_ERR_HISTORY_NOT_FOUND 4401
#define QM_ERR_HISTORY_TIMEOUT 4403

const string QM_HARVEST_DIRECTORY = "QM\\m1_harvest";
const string QM_EXTRACTION_METHOD = "MQL5_COPYRATES_PERIOD_M1_SPREAD";
const string QM_COVERAGE_SCHEMA = "qm.m1-spread-harvest-coverage/v2";

string Trimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

bool SafeToken(const string value)
  {
   const int length = StringLen(value);
   if(length < 1 || length > 96)
      return false;
   for(int index = 0; index < length; ++index)
     {
      const ushort code = StringGetCharacter(value, index);
      const bool allowed =
         (code >= 'A' && code <= 'Z') ||
         (code >= 'a' && code <= 'z') ||
         (code >= '0' && code <= '9') ||
         code == '_' || code == '-';
      if(!allowed)
         return false;
     }
   return true;
  }

string SafeSymbolToken(const string symbol)
  {
   string value = symbol;
   StringReplace(value, ".", "_");
   StringReplace(value, "-", "_");
   return value;
  }

string IsoServerMinute(const datetime value)
  {
   MqlDateTime parts = {0};
   TimeToStruct(value, parts);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:00",
                       parts.year,
                       parts.mon,
                       parts.day,
                       parts.hour,
                       parts.min);
  }

string IsoMinute(const datetime value)
  {
   return IsoServerMinute(value - InpServerUtcOffsetMinutes * 60) + "Z";
  }

bool WriteEmptyCoverage(const string symbol, const string output_tag,
                         const string coverage_path, const datetime cached_last,
                         const string reason)
  {
   int handle=FileOpen(coverage_path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(handle==INVALID_HANDLE) return false;
   string row=StringFormat("{\"schema\":\"qm.m1-spread-harvest-coverage/v2\",\"status\":\"EMPTY\",\"symbol\":\"%s\",\"output_tag\":\"%s\",\"bar_count\":0,\"reason\":\"%s\",\"last_cached_server\":\"%s\",\"server_utc_offset_minutes\":%d,\"requested_from_server\":\"%s\",\"requested_to_server\":\"%s\",\"clock_validation\":\"DECLARED_NOT_EMPIRICALLY_VALIDATED\"}",symbol,output_tag,reason,IsoServerMinute(cached_last),InpServerUtcOffsetMinutes,IsoServerMinute(InpFromServer),IsoServerMinute(InpToServer));
   bool ok=FileWriteString(handle,row+"\n")>0;
   FileFlush(handle); FileClose(handle); return ok;
  }

bool RetryableHistoryError(const int error)
  {
   return error == QM_ERR_HISTORY_NOT_FOUND || error == QM_ERR_HISTORY_TIMEOUT;
  }

bool CopyM1Chunk(const string symbol,
                 const datetime from_time,
                 const datetime to_time,
                 MqlRates &rates[],
                 int &copied,
                 int &last_error)
  {
   copied = -1;
   last_error = 0;
   for(int attempt = 0; attempt < QM_COPY_ATTEMPTS; ++attempt)
     {
      ArrayResize(rates, 0);
      ArraySetAsSeries(rates, false);
      ResetLastError();
      copied = CopyRates(symbol, PERIOD_M1, from_time, to_time, rates);
      last_error = GetLastError();
      if(copied >= 0 && !RetryableHistoryError(last_error))
         return true;
      if(!RetryableHistoryError(last_error) && copied < 0)
         return false;
      PrintFormat("QM_M1_HARVEST_COPYRATES_RETRY symbol=%s from=%s to=%s attempt=%d error=%d",
                  symbol,
                  IsoMinute(from_time),
                  IsoMinute(to_time),
                  attempt + 1,
                  last_error);
      Sleep(500 + attempt * 250);
     }
   return false;
  }

bool CopyTickChunk(const string symbol,
                   const ulong from_msc,
                   const ulong to_msc,
                   MqlTick &ticks[],
                   int &copied,
                   int &last_error)
  {
   copied = -1;
   last_error = 0;
   for(int attempt = 0; attempt < QM_COPY_ATTEMPTS; ++attempt)
     {
      ArrayResize(ticks, 0);
      ArraySetAsSeries(ticks, false);
      ResetLastError();
      copied = CopyTicksRange(symbol, ticks, COPY_TICKS_ALL, from_msc, to_msc);
      last_error = GetLastError();
      if(copied >= 0 && !RetryableHistoryError(last_error))
         return true;
      if(!RetryableHistoryError(last_error) && copied < 0)
         return false;
      PrintFormat("QM_M1_HARVEST_COPYTICKS_RETRY symbol=%s attempt=%d error=%d",
                  symbol,
                  attempt + 1,
                  last_error);
      Sleep(500 + attempt * 250);
     }
   // FTMO deliberately does not serve deep tick history.  An exhausted 4401
   // therefore proves "no ticks returned for this chunk"; it must not be
   // relabelled as tick coverage, but it also must not discard valid M1 bars.
   if(last_error == QM_ERR_HISTORY_NOT_FOUND)
     {
      copied = 0;
      return true;
     }
   return false;
  }

bool WriteRawBars(const string symbol,
                  const string output_path,
                  const datetime start_time,
                  const datetime end_time,
                  long &bar_count,
                  datetime &first_bar,
                  datetime &last_bar)
  {
   const int handle = FileOpen(output_path,
                               FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("QM_M1_HARVEST_OPEN_FAIL symbol=%s path=%s error=%d",
                  symbol, output_path, GetLastError());
      return false;
     }

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   datetime prior = 0;
   bar_count = 0;
   first_bar = 0;
   last_bar = 0;
   bool success = true;

   // Time-window CopyRates on a fresh /config profile returns instant 0/no
   // error outside the loaded series cache (proven live 2026-08-08); the
   // position-based request provably loads the full local series. Fetch all
   // available bars once, then filter to [start_time, end_time] ascending.
   MqlRates rates[];
   int copied = -1;
   for(int attempt = 0; attempt < QM_COPY_ATTEMPTS && !IsStopped(); ++attempt)
     {
      ArrayResize(rates, 0);
      ArraySetAsSeries(rates, false);
      ResetLastError();
      copied = CopyRates(symbol, PERIOD_M1, start_time, end_time, rates);
      if(copied > 0)
         break;
      PrintFormat("QM_M1_HARVEST_POSITION_RETRY symbol=%s attempt=%d copied=%d error=%d",
                  symbol, attempt + 1, copied, GetLastError());
      Sleep(500 + attempt * 250);
     }
   if(copied <= 0)
     {
      PrintFormat("QM_M1_HARVEST_COPYRATES_FAIL symbol=%s copied=%d error=%d",
                  symbol, copied, GetLastError());
      FileClose(handle);
      FileDelete(output_path);
      return false;
     }
   for(int index = 0; index < copied && success; ++index)
     {
      {
         if(rates[index].time < start_time || rates[index].time > end_time)
            continue;
         if(prior != 0 && rates[index].time <= prior)
           {
            PrintFormat("QM_M1_HARVEST_ORDER_VIOLATION symbol=%s ts=%s prior=%s",
                        symbol, IsoMinute(rates[index].time), IsoMinute(prior));
            success = false;
            break;
           }
         const string row = StringFormat(
            "{\"ts\":\"%s\",\"ts_utc\":\"%s\",\"ts_server\":\"%s\",\"server_utc_offset_minutes\":%d,\"timestamp_basis\":\"DECLARED_FIXED_OFFSET_WINDOW\",\"point_size\":%.10f,\"open\":%s,\"high\":%s,\"low\":%s,\"close\":%s,\"tick_volume\":%I64d,\"spread\":%d}",
            IsoMinute(rates[index].time),
            IsoMinute(rates[index].time),
            IsoServerMinute(rates[index].time),
            InpServerUtcOffsetMinutes,
            SymbolInfoDouble(symbol, SYMBOL_POINT),
            DoubleToString(rates[index].open, digits),
            DoubleToString(rates[index].high, digits),
            DoubleToString(rates[index].low, digits),
            DoubleToString(rates[index].close, digits),
            rates[index].tick_volume,
            rates[index].spread);
         if(FileWriteString(handle, row + "\n") <= 0)
           {
            PrintFormat("QM_M1_HARVEST_WRITE_FAIL symbol=%s error=%d", symbol, GetLastError());
            success = false;
            break;
           }
         if(first_bar == 0)
            first_bar = rates[index].time;
         last_bar = rates[index].time;
         prior = rates[index].time;
         ++bar_count;
        }
     }

   FileFlush(handle);
   FileClose(handle);
   if(!success || bar_count <= 0)
     {
      PrintFormat("QM_M1_HARVEST_NO_BARS_IN_WINDOW symbol=%s copied=%d kept=%I64d start=%s end=%s",
                  symbol, copied, bar_count, IsoMinute(start_time), IsoMinute(end_time));
      FileDelete(output_path);
      return false;
     }
   return true;
  }

bool ObserveTickWindow(const string symbol,
                       const datetime start_time,
                       const datetime end_time,
                       datetime &tick_first,
                       datetime &tick_last)
  {
   tick_first = 0;
   tick_last = 0;
   datetime cursor = start_time;
   while(cursor <= end_time)
     {
      datetime chunk_end = cursor + QM_TICK_CHUNK_DAYS * 86400 - 1;
      if(chunk_end > end_time)
         chunk_end = end_time;
      MqlTick ticks[];
      int copied = -1;
      int error = 0;
      const ulong from_msc = (ulong)cursor * 1000;
      const ulong to_msc = (ulong)chunk_end * 1000 + 999;
      if(!CopyTickChunk(symbol, from_msc, to_msc, ticks, copied, error))
        {
         PrintFormat("QM_M1_HARVEST_COPYTICKS_FAIL symbol=%s from=%s to=%s copied=%d error=%d",
                     symbol,
                     IsoMinute(cursor),
                     IsoMinute(chunk_end),
                     copied,
                     error);
         return false;
        }
      if(copied > 0)
        {
         const datetime chunk_first = (datetime)(ticks[0].time_msc / 1000);
         const datetime chunk_last = (datetime)(ticks[copied - 1].time_msc / 1000);
         if(tick_first == 0)
            tick_first = chunk_first;
         tick_last = chunk_last;
        }
      cursor = chunk_end + 1;
     }
   return true;
  }

bool WriteCoverage(const string symbol,
                   const string output_tag,
                   const string coverage_path,
                   const long bar_count,
                   const datetime first_bar,
                   const datetime last_bar,
                   const datetime tick_first,
                   const datetime tick_last)
  {
   const int handle = FileOpen(coverage_path,
                               FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("QM_M1_HARVEST_COVERAGE_OPEN_FAIL symbol=%s path=%s error=%d",
                  symbol, coverage_path, GetLastError());
      return false;
     }
   const double depth_days = (double)(last_bar - first_bar) / 86400.0;
   const string tick_first_json = tick_first > 0 ? "\"" + IsoMinute(tick_first) + "\"" : "null";
   const string tick_last_json = tick_last > 0 ? "\"" + IsoMinute(tick_last) + "\"" : "null";
   const string payload = StringFormat(
      "{\"schema\":\"%s\",\"status\":\"COMPLETE\",\"extraction_method\":\"%s\",\"output_tag\":\"%s\",\"symbol\":\"%s\",\"first_bar\":\"%s\",\"last_bar\":\"%s\",\"bar_count\":%I64d,\"depth_days\":%s,\"tick_first\":%s,\"tick_last\":%s,\"first_bar_server\":\"%s\",\"last_bar_server\":\"%s\",\"server_utc_offset_minutes\":%d,\"clock_validation\":\"DECLARED_NOT_EMPIRICALLY_VALIDATED\"}\n",
      QM_COVERAGE_SCHEMA,
      QM_EXTRACTION_METHOD,
      output_tag,
      symbol,
      IsoMinute(first_bar),
      IsoMinute(last_bar),
      bar_count,
      DoubleToString(depth_days, 6),
      tick_first_json,
      tick_last_json,
      IsoServerMinute(first_bar),
      IsoServerMinute(last_bar),
      InpServerUtcOffsetMinutes);
   const bool wrote = FileWriteString(handle, payload) > 0;
   FileFlush(handle);
   FileClose(handle);
   if(!wrote)
      FileDelete(coverage_path);
   return wrote;
  }


datetime ResolveHistoryStart(const string symbol, const string output_tag)
  {
   const string path=QM_HARVEST_DIRECTORY+"\\"+output_tag+"_"+SafeSymbolToken(symbol)+"_download.json";
   const int handle=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(handle==INVALID_HANDLE) return 0;
   const ulong deadline=GetTickCount64()+240000;
   datetime first=0,last=0;
   string attempts="";
   const datetime before=(datetime)SeriesInfoInteger(symbol,PERIOD_M1,SERIES_LASTBAR_DATE);
   for(int attempt=0;attempt<6 && GetTickCount64()<deadline && !IsStopped();++attempt)
     {
      MqlRates rates[];
      ArraySetAsSeries(rates,false);
      ResetLastError();
      // A date-bounded native request initiates server downloading (MQL5 CopyRates contract).
      const int copied=CopyRates(symbol,PERIOD_M1,InpFromServer,InpToServer-60,rates);
      const int error=GetLastError();
      if(copied>0) { first=rates[0].time; last=rates[copied-1].time; }
      if(attempt>0) attempts+=",";
      attempts+=StringFormat("{\"attempt\":%d,\"copied\":%d,\"error\":%d,\"first_server\":\"%s\",\"last_server\":\"%s\",\"connected\":%d}",attempt+1,copied,error,IsoServerMinute(first),IsoServerMinute(last),(int)TerminalInfoInteger(TERMINAL_CONNECTED));
      FileFlush(handle);
      if(first>0 && first<InpFromServer+86400 && last>=D'2026.09.04 00:00') break;
      Sleep(2000);
     }
   string payload=StringFormat("{\"schema\":\"qm.m08c-native-download/v1\",\"symbol\":\"%s\",\"is_custom\":%d,\"before_last_server\":\"%s\",\"server_first\":\"%s\",\"cache_last_server\":\"%s\",\"window_start_server\":\"%s\",\"window_end_server\":\"%s\",\"point_size\":%.10f,\"attempts\":[%s]}",symbol,(int)SymbolInfoInteger(symbol,SYMBOL_CUSTOM),IsoServerMinute(before),IsoServerMinute((datetime)SeriesInfoInteger(symbol,PERIOD_M1,SERIES_SERVER_FIRSTDATE)),IsoServerMinute((datetime)SeriesInfoInteger(symbol,PERIOD_M1,SERIES_LASTBAR_DATE)),IsoServerMinute(InpFromServer),IsoServerMinute(InpToServer),SymbolInfoDouble(symbol,SYMBOL_POINT),attempts);
   FileWriteString(handle,payload+"\n"); FileFlush(handle); FileClose(handle);
   return first;
  }


bool HarvestSymbol(const string symbol, const string output_tag)
  {
   datetime end_time = InpToServer;
   if(end_time <= 0)
      end_time = TimeCurrent();
   end_time = (end_time / 60) * 60 - 60;
   if(end_time < QM_HARVEST_FROM)
     {
      PrintFormat("QM_M1_HARVEST_CLOCK_FAIL symbol=%s end=%s", symbol, IsoMinute(end_time));
      return false;
     }

   const string symbol_token = SafeSymbolToken(symbol);
   if(!SafeToken(symbol_token))
     {
      PrintFormat("QM_M1_HARVEST_SYMBOL_TOKEN_FAIL symbol=%s", symbol);
      return false;
     }
   FolderCreate("QM");
   FolderCreate(QM_HARVEST_DIRECTORY);
   const string stem = output_tag + "_" + symbol_token;
   const string raw_path = QM_HARVEST_DIRECTORY + "\\" + stem + "_M1.jsonl";
   const string coverage_path = QM_HARVEST_DIRECTORY + "\\" + stem + "_coverage.json";
   if(FileIsExist(raw_path) || FileIsExist(coverage_path))
     {
      PrintFormat("QM_M1_HARVEST_REFUSE_EXISTING symbol=%s raw=%s coverage=%s",
                  symbol, raw_path, coverage_path);
      return false;
     }

   bool is_custom=false;
   if(!SymbolExist(symbol,is_custom))
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,0,"NATIVE_SYMBOL_NOT_OFFERED_BY_CONNECTED_BROKER");
   if(is_custom)
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,0,"CUSTOM_ARCHIVE_HAS_NO_BROKER_DOWNLOAD");
   if(!SymbolSelect(symbol,true))
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,0,"BROKER_SYMBOL_SELECT_FAILED");
   long bar_count = 0;
   datetime first_bar = 0;
   datetime last_bar = 0;
   const datetime available_start = ResolveHistoryStart(symbol,output_tag);
   const datetime cached_last = (datetime)SeriesInfoInteger(symbol, PERIOD_M1, SERIES_LASTBAR_DATE);
   if(cached_last < InpFromServer)
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,cached_last,"BROKER_HISTORY_WINDOW_UNAVAILABLE_AFTER_BOUNDED_REQUEST");
   const datetime start_time = available_start > InpFromServer ? available_start : InpFromServer;
   if(start_time <= 0 || start_time > end_time)
     {
      PrintFormat("QM_M1_HARVEST_SYNC_FAIL symbol=%s start=%s end=%s",
                  symbol, IsoMinute(start_time), IsoMinute(end_time));
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,cached_last,"BOUNDED_DOWNLOAD_NO_REQUESTED_BARS");
     }
   if(!WriteRawBars(symbol, raw_path, start_time, end_time, bar_count, first_bar, last_bar))
      return WriteEmptyCoverage(symbol,output_tag,coverage_path,cached_last,"COPYRATES_OR_EMPTY_WINDOW_FAILURE");

   datetime tick_first = 0;
   datetime tick_last = 0;
   if(InpObserveTicks && !ObserveTickWindow(symbol, start_time, end_time, tick_first, tick_last))
     {
      // Tick coverage is evidence, not a bar-harvest precondition: the
      // coverage contract accepts null ticks (with_ticks=false path). Never
      // discard valid M1 bars over a tick-window failure.
      PrintFormat("QM_M1_HARVEST_TICKS_UNAVAILABLE symbol=%s", symbol);
      tick_first = 0;
      tick_last = 0;
     }
   if(!WriteCoverage(symbol,
                     output_tag,
                     coverage_path,
                     bar_count,
                     first_bar,
                     last_bar,
                     tick_first,
                     tick_last))
     {
      FileDelete(raw_path);
      return false;
     }
   PrintFormat("QM_M1_HARVEST_COMPLETE tag=%s symbol=%s rows=%I64d raw=%s coverage=%s",
               output_tag, symbol, bar_count, raw_path, coverage_path);
   return true;
  }

bool WaitForConnection()
  {
   // A first-start portable terminal connects asynchronously after login;
   // harvesting before TERMINAL_CONNECTED yields endless 4401 (proven live
   // 2026-08-08). Deep server-side M1 sync also needs the link up first.
   for(int waited = 0; waited < QM_CONNECT_WAIT_SECONDS; ++waited)
     {
      if(TerminalInfoInteger(TERMINAL_CONNECTED) == 1)
        {
         PrintFormat("QM_M1_HARVEST_CONNECTED after=%ds", waited);
         return true;
        }
      if(waited % 15 == 0)
         PrintFormat("QM_M1_HARVEST_WAIT_CONNECT waited=%ds", waited);
      Sleep(1000);
     }
   Print("QM_M1_HARVEST_CONNECT_TIMEOUT");
   return false;
  }

void OnStart()
  {
   // Both US and EU summer intervals contain this entire permitted window.
   // A different season requires a per-interval declaration; fail closed here.
   if(InpFromServer < D'2026.03.29 04:00' || InpToServer > D'2026.10.25 03:00'
      || InpFromServer >= InpToServer || InpServerUtcOffsetMinutes != 180)
     { Print("QM_M1_HARVEST_CLOCK_DECLARATION_INVALID"); return; }
   const string output_tag = Trimmed(InpOutputTag);
   if(!SafeToken(output_tag))
     {
      PrintFormat("QM_M1_HARVEST_TAG_FAIL tag=%s", output_tag);
      return;
     }
   // Custom symbols (.DWX) harvest from the local store without a broker
   // link; only native-symbol sync needs it. On timeout we proceed and let
   // CopyRates fail honestly if the link was genuinely required.
   if(!WaitForConnection())
      Print("QM_M1_HARVEST_PROCEED_OFFLINE");
   string symbols[];
   const int count = StringSplit(InpSymbols, ',', symbols);
   if(count <= 0)
     {
      Print("QM_M1_HARVEST_SYMBOL_LIST_FAIL");
      return;
     }
   for(int index = 0; index < count; ++index)
     {
      const string symbol = Trimmed(symbols[index]);
      if(symbol == "" || !HarvestSymbol(symbol, output_tag))
        {
         PrintFormat("QM_M1_HARVEST_FAILED index=%d symbol=%s", index, symbol);
         continue;
        }
     }
   PrintFormat("QM_M1_HARVEST_ALL_COMPLETE tag=%s symbols=%d", output_tag, count);
  }
