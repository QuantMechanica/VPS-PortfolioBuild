//+------------------------------------------------------------------+
//| Export_FTMO_EventComplete_Ticks.mq5                              |
//| Strict, read-only raw-tick evidence export for FTMO replay.      |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

// This script never places, changes, or closes an order.  It reads the exact
// custom-symbol tick store with CopyTicksRange and writes evidence under
// Common\Files\QM\ftmo_event_replay.  A consumer must bind every output by
// SHA-256; the small *.complete.json marker is only a structural completeness
// signal and is not an integrity signature.

input string   InpEvidenceRunId = "";
input string   InpSymbols = "USDJPY.DWX;XAUUSD.DWX;XTIUSD.DWX";
input datetime InpFromBrokerWall = D'2018.01.01 00:00';
input datetime InpToBrokerWallExclusive = D'2026.01.01 00:00';
input int      InpChunkHours = 24;
input int      InpCopyRetries = 5;
input string   InpExpectedAccountCurrency = "USD";
input int      InpExpectedAccountLeverage = 100;
input ENUM_ACCOUNT_MARGIN_MODE InpExpectedAccountMarginMode =
   ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
input string   InpSessionTimezoneBasis = "MT5_CUSTOM_SYMBOL_SERVER_TIME";
input string   InpRawTimeBasis = "DARWINEX_US_DST_BROKER_WALL_EPOCH";

const string QM_FTMO_EVENT_TICK_PRODUCER =
   "QM_FTMO_EVENT_COMPLETE_TICK_EXPORT_V1";

string EscapeJson(const string value)
  {
   string escaped = value;
   StringReplace(escaped, "\\", "\\\\");
   StringReplace(escaped, "\"", "\\\"");
   StringReplace(escaped, "\r", "\\r");
   StringReplace(escaped, "\n", "\\n");
   StringReplace(escaped, "\t", "\\t");
   return escaped;
  }

bool SafeToken(const string value)
  {
   const int length = StringLen(value);
   if(length < 1 || length > 96)
      return false;
   for(int i = 0; i < length; ++i)
     {
      const ushort ch = StringGetCharacter(value, i);
      const bool alpha = (ch >= 'A' && ch <= 'Z') ||
                         (ch >= 'a' && ch <= 'z');
      const bool digit = ch >= '0' && ch <= '9';
      if(!alpha && !digit && ch != '_' && ch != '-')
         return false;
     }
   return true;
  }

string SafeSymbol(const string symbol)
  {
   string value = symbol;
   StringReplace(value, ".", "_");
   StringReplace(value, "#", "_");
   StringReplace(value, "-", "_");
   return value;
  }

string StableDouble(const double value, const int digits = 16)
  {
   if(!MathIsValidNumber(value))
      return "null";
   return DoubleToString(value, digits);
  }

string CalcModeName(const long calc_mode)
  {
   if(calc_mode == SYMBOL_CALC_MODE_FOREX ||
      calc_mode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)
      return "FOREX";
   if(calc_mode == SYMBOL_CALC_MODE_CFD ||
      calc_mode == SYMBOL_CALC_MODE_CFDINDEX ||
      calc_mode == SYMBOL_CALC_MODE_CFDLEVERAGE)
      return "CFD_LINEAR";
   return StringFormat("UNSUPPORTED_%I64d", calc_mode);
  }

string ConversionModeName(const string currency_base,
                          const string currency_profit,
                          const string calc_mode)
  {
   if(currency_profit == InpExpectedAccountCurrency)
      return "IDENTITY";
   if(calc_mode == "FOREX" &&
      currency_base == InpExpectedAccountCurrency)
      return "FOREX_QUOTE_ACCOUNT_INVERSE";
   return "UNSUPPORTED";
  }

int SessionSecondOfDay(const datetime value)
  {
   MqlDateTime parts = {0};
   TimeToStruct(value, parts);
   return parts.hour * 3600 + parts.min * 60 + parts.sec;
  }

bool SymbolSessionsJson(const string symbol,
                        const bool quote_sessions,
                        string &json)
  {
   string rows = "";
   int count = 0;
   for(int day = 0; day <= 6; ++day)
     {
      bool end_observed = false;
      for(uint session_index = 0; session_index <= 64; ++session_index)
        {
         datetime from_time = 0;
         datetime to_time = 0;
         ResetLastError();
         const bool found = quote_sessions
            ? SymbolInfoSessionQuote(symbol,
                                     (ENUM_DAY_OF_WEEK)day,
                                     session_index,
                                     from_time,
                                     to_time)
            : SymbolInfoSessionTrade(symbol,
                                     (ENUM_DAY_OF_WEEK)day,
                                     session_index,
                                     from_time,
                                     to_time);
         if(!found)
           {
            const int error = GetLastError();
            if(error != 0 && error != ERR_MARKET_SESSION_INDEX)
               return false;
            end_observed = true;
            break;
           }
         // Index 64 is a sentinel probe.  A real session here means the
         // bounded snapshot would be truncated and must not be receipted.
         if(session_index == 64)
            return false;
         if(count > 0)
            rows += ",";
         rows += StringFormat(
            "{\"day_of_week\":%d,\"session_index\":%u,"
            "\"from_second\":%d,\"to_second\":%d,"
            "\"wraps_midnight\":%s}",
            day,
            session_index,
            SessionSecondOfDay(from_time),
            SessionSecondOfDay(to_time),
            SessionSecondOfDay(to_time) <= SessionSecondOfDay(from_time)
               ? "true" : "false");
         ++count;
        }
      if(!end_observed)
         return false;
     }
   json = "[" + rows + "]";
   return true;
  }

string SymbolPropertiesJson(const string symbol)
  {
   const long raw_calc_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
   const string calc_mode = CalcModeName(raw_calc_mode);
   const long digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const long custom = SymbolInfoInteger(symbol, SYMBOL_CUSTOM);
   const long trade_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_value_profit =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   const double tick_value_loss =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   const double contract_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   const double volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   const double margin_initial =
      SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
   const double margin_maintenance =
      SymbolInfoDouble(symbol, SYMBOL_MARGIN_MAINTENANCE);
   const double swap_long = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
   const double swap_short = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
   const double swap_sunday = SymbolInfoDouble(symbol, SYMBOL_SWAP_SUNDAY);
   const double swap_monday = SymbolInfoDouble(symbol, SYMBOL_SWAP_MONDAY);
   const double swap_tuesday = SymbolInfoDouble(symbol, SYMBOL_SWAP_TUESDAY);
   const double swap_wednesday = SymbolInfoDouble(symbol, SYMBOL_SWAP_WEDNESDAY);
   const double swap_thursday = SymbolInfoDouble(symbol, SYMBOL_SWAP_THURSDAY);
   const double swap_friday = SymbolInfoDouble(symbol, SYMBOL_SWAP_FRIDAY);
   const double swap_saturday = SymbolInfoDouble(symbol, SYMBOL_SWAP_SATURDAY);
   const long swap_mode = SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE);
   const long swap_rollover3days =
      SymbolInfoInteger(symbol, SYMBOL_SWAP_ROLLOVER3DAYS);
   const string currency_base =
      SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   const string currency_profit =
      SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   const string currency_margin =
      SymbolInfoString(symbol, SYMBOL_CURRENCY_MARGIN);

   if(custom == 0 || digits < 0 ||
      !MathIsValidNumber(point) || !MathIsValidNumber(tick_size) ||
      !MathIsValidNumber(tick_value) ||
      !MathIsValidNumber(tick_value_profit) ||
      !MathIsValidNumber(tick_value_loss) ||
      !MathIsValidNumber(contract_size) ||
      !MathIsValidNumber(volume_min) || !MathIsValidNumber(volume_max) ||
      !MathIsValidNumber(volume_step) ||
      !MathIsValidNumber(margin_initial) ||
      !MathIsValidNumber(margin_maintenance) ||
      !MathIsValidNumber(swap_long) || !MathIsValidNumber(swap_short) ||
      !MathIsValidNumber(swap_sunday) || !MathIsValidNumber(swap_monday) ||
      !MathIsValidNumber(swap_tuesday) || !MathIsValidNumber(swap_wednesday) ||
      !MathIsValidNumber(swap_thursday) || !MathIsValidNumber(swap_friday) ||
      !MathIsValidNumber(swap_saturday) ||
      point <= 0.0 || tick_size <= 0.0 ||
      contract_size <= 0.0 || volume_min <= 0.0 ||
      volume_max < volume_min || volume_step <= 0.0 ||
      currency_profit == "")
      return "";

   const string conversion_mode = ConversionModeName(
      currency_base, currency_profit, calc_mode);
   if(StringFind(calc_mode, "UNSUPPORTED_") == 0 ||
      conversion_mode == "UNSUPPORTED")
      return "";
   string quote_sessions = "";
   string trade_sessions = "";
   if(!SymbolSessionsJson(symbol, true, quote_sessions) ||
      !SymbolSessionsJson(symbol, false, trade_sessions))
      return "";

   return StringFormat(
      "{\"symbol\":\"%s\",\"custom\":%s,\"trade_mode\":%I64d,"
      "\"raw_calc_mode\":%I64d,\"calc_mode\":\"%s\","
      "\"digits\":%I64d,\"point\":%s,\"tick_size\":%s,"
      "\"tick_value\":%s,\"tick_value_profit\":%s,"
      "\"tick_value_loss\":%s,\"contract_size\":%s,"
      "\"volume_min\":%s,\"volume_max\":%s,\"volume_step\":%s,"
      "\"margin_initial\":%s,\"margin_maintenance\":%s,"
      "\"currency_base\":\"%s\",\"profit_currency\":\"%s\","
      "\"currency_margin\":\"%s\",\"account_currency\":\"%s\","
      "\"conversion_mode\":\"%s\",\"swap_long\":%s,"
      "\"swap_short\":%s,\"swap_mode\":%I64d,"
      "\"swap_rollover3days\":%I64d,"
      "\"swap_sunday\":%s,\"swap_monday\":%s,\"swap_tuesday\":%s,"
      "\"swap_wednesday\":%s,\"swap_thursday\":%s,"
      "\"swap_friday\":%s,\"swap_saturday\":%s,"
      "\"session_snapshot_complete\":true,"
      "\"quote_sessions\":%s,"
      "\"trade_sessions\":%s}",
      EscapeJson(symbol),
      custom != 0 ? "true" : "false",
      trade_mode,
      raw_calc_mode,
      calc_mode,
      digits,
      StableDouble(point),
      StableDouble(tick_size),
      StableDouble(tick_value),
      StableDouble(tick_value_profit),
      StableDouble(tick_value_loss),
      StableDouble(contract_size),
      StableDouble(volume_min),
      StableDouble(volume_max),
      StableDouble(volume_step),
      StableDouble(margin_initial),
      StableDouble(margin_maintenance),
      EscapeJson(currency_base),
      EscapeJson(currency_profit),
      EscapeJson(currency_margin),
      EscapeJson(InpExpectedAccountCurrency),
      conversion_mode,
      StableDouble(swap_long),
      StableDouble(swap_short),
      swap_mode,
      swap_rollover3days,
      StableDouble(swap_sunday),
      StableDouble(swap_monday),
      StableDouble(swap_tuesday),
      StableDouble(swap_wednesday),
      StableDouble(swap_thursday),
      StableDouble(swap_friday),
      StableDouble(swap_saturday),
      quote_sessions,
      trade_sessions);
  }

bool WriteAllSymbolProperties(string &symbols[])
  {
   const string path = StringFormat(
      "QM\\ftmo_event_replay\\%s_symbol_properties_v1.json",
      InpEvidenceRunId);
   const int handle = FileOpen(
      path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;
   string rows = "";
   for(int i = 0; i < ArraySize(symbols); ++i)
     {
      const string item = SymbolPropertiesJson(symbols[i]);
      if(item == "")
        {
         FileClose(handle);
         return false;
        }
      if(i > 0)
         rows += ",";
      rows += item;
     }
   const string payload = StringFormat(
      "{\"schema\":\"FTMO_SYMBOL_PROPERTIES_V1\",\"schema_version\":1,"
      "\"producer\":\"%s\",\"run_id\":\"%s\","
      "\"account_currency\":\"%s\","
      "\"account_currency_source\":\"OPERATOR_DECLARED_REPLAY_CONTRACT\","
      "\"expected_account_leverage\":%d,\"expected_account_margin_mode\":%d,"
      "\"account_contract_requires_history_reconciliation\":true,"
      "\"session_timezone_basis\":\"%s\",\"symbols\":[%s]}\r\n",
      QM_FTMO_EVENT_TICK_PRODUCER,
      EscapeJson(InpEvidenceRunId),
      EscapeJson(InpExpectedAccountCurrency),
      InpExpectedAccountLeverage,
      (int)InpExpectedAccountMarginMode,
      EscapeJson(InpSessionTimezoneBasis),
      rows);
   const bool written =
      FileWriteString(handle, payload) == (uint)StringLen(payload);
   FileFlush(handle);
   FileClose(handle);
   return written;
  }

bool SameTick(const MqlTick &left, const MqlTick &right)
  {
   return left.time_msc == right.time_msc &&
          left.bid == right.bid && left.ask == right.ask &&
          left.last == right.last && left.volume == right.volume &&
          left.volume_real == right.volume_real && left.flags == right.flags;
  }

string TickStem(const string symbol)
  {
   return StringFormat("QM\\ftmo_event_replay\\%s_%s_ticks_v1",
                       InpEvidenceRunId,
                       SafeSymbol(symbol));
  }

string RunCompletePath()
  {
   return StringFormat("QM\\ftmo_event_replay\\%s_tick_set.complete.json",
                       InpEvidenceRunId);
  }

bool RemoveStaleComplete(const string path)
  {
   if(!FileIsExist(path, FILE_COMMON))
      return true;
   ResetLastError();
   if(!FileDelete(path, FILE_COMMON))
     {
      PrintFormat("FTMO_EVENT_STALE_COMPLETE_DELETE_FAILED path=%s error=%d",
                  path, GetLastError());
      return false;
     }
   return !FileIsExist(path, FILE_COMMON);
  }

bool ExportSymbol(const string symbol,
                  const long from_msc,
                  const long to_msc_exclusive,
                  const long chunk_msc)
  {
   if(symbol == "" || !SymbolSelect(symbol, true))
     {
      PrintFormat("FTMO_EVENT_TICK_SELECT_FAILED symbol=%s error=%d",
                  symbol, GetLastError());
      return false;
     }

   const string stem = TickStem(symbol);
   const string tick_path = stem + ".jsonl";
   const string chunk_path = stem + ".chunks.jsonl";
   const string complete_path = stem + ".complete.json";
   if(FileIsExist(complete_path, FILE_COMMON))
     {
      PrintFormat("FTMO_EVENT_STALE_COMPLETE_STILL_PRESENT path=%s",
                  complete_path);
      return false;
     }

   const int tick_handle = FileOpen(tick_path,
                                    FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   const int chunk_handle = FileOpen(chunk_path,
                                     FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(tick_handle == INVALID_HANDLE || chunk_handle == INVALID_HANDLE)
     {
      if(tick_handle != INVALID_HANDLE) FileClose(tick_handle);
      if(chunk_handle != INVALID_HANDLE) FileClose(chunk_handle);
      PrintFormat("FTMO_EVENT_TICK_OPEN_FAILED symbol=%s error=%d",
                  symbol, GetLastError());
      return false;
     }

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long source_index = 0;
   long prior_time_msc = -1;
   MqlTick prior_tick = {0};
   bool have_prior = false;
   int chunk_index = 0;

   for(long chunk_from = from_msc;
       chunk_from < to_msc_exclusive;
       chunk_from += chunk_msc)
     {
      const long chunk_to_exclusive =
         MathMin(chunk_from + chunk_msc, to_msc_exclusive);
      MqlTick ticks[];
      int copied = -1;
      int error = 0;
      for(int attempt = 0; attempt < InpCopyRetries; ++attempt)
        {
         ResetLastError();
         copied = CopyTicksRange(symbol,
                                 ticks,
                                 COPY_TICKS_ALL,
                                 (ulong)chunk_from,
                                 (ulong)(chunk_to_exclusive - 1));
         error = GetLastError();
         if(copied >= 0 && error == 0)
            break;
         Sleep(1000);
        }
      if(copied < 0 || error != 0)
        {
         FileClose(tick_handle);
         FileClose(chunk_handle);
         PrintFormat(
            "FTMO_EVENT_TICK_COPY_FAILED symbol=%s chunk=%d from=%I64d to=%I64d copied=%d error=%d",
            symbol, chunk_index, chunk_from, chunk_to_exclusive, copied, error);
         return false;
        }

      for(int i = 0; i < copied; ++i)
        {
         const MqlTick tick = ticks[i];
         if(!MathIsValidNumber(tick.bid) ||
            !MathIsValidNumber(tick.ask) ||
            !MathIsValidNumber(tick.last) ||
            !MathIsValidNumber(tick.volume_real) ||
            tick.bid <= 0.0 || tick.ask <= 0.0 ||
            tick.last < 0.0 || tick.volume_real < 0.0 ||
            tick.time_msc < chunk_from || tick.time_msc >= chunk_to_exclusive ||
            tick.time_msc < prior_time_msc ||
            (have_prior && SameTick(prior_tick, tick)))
           {
            FileClose(tick_handle);
            FileClose(chunk_handle);
            PrintFormat(
               "FTMO_EVENT_TICK_ORDER_INVALID symbol=%s chunk=%d index=%d time_msc=%I64d prior=%I64d",
               symbol, chunk_index, i, tick.time_msc, prior_time_msc);
            return false;
           }
         const string tick_row = StringFormat(
            "{\"schema\":\"FTMO_TICK_V1\",\"symbol\":\"%s\","
            "\"time_msc\":%I64d,\"source_sequence\":%I64d,"
            "\"bid\":%s,\"ask\":%s,\"last\":%s,"
            "\"volume\":%I64u,\"volume_real\":%s,\"flags\":%u}\r\n",
            EscapeJson(symbol),
            tick.time_msc,
            source_index,
            StableDouble(tick.bid, digits),
            StableDouble(tick.ask, digits),
            StableDouble(tick.last, digits),
            tick.volume,
            StableDouble(tick.volume_real),
            tick.flags);
         if(FileWriteString(tick_handle, tick_row) !=
            (uint)StringLen(tick_row))
           {
            FileClose(tick_handle);
            FileClose(chunk_handle);
            PrintFormat("FTMO_EVENT_TICK_WRITE_FAILED symbol=%s sequence=%I64d",
                        symbol, source_index);
            return false;
           }
         prior_time_msc = tick.time_msc;
         prior_tick = tick;
         have_prior = true;
         ++source_index;
        }

      const string chunk_row = StringFormat(
         "{\"event\":\"TICK_CHUNK\",\"schema_version\":1,"
         "\"run_id\":\"%s\",\"symbol\":\"%s\",\"chunk_index\":%d,"
         "\"time_basis\":\"DARWINEX_US_DST_BROKER_WALL_EPOCH\","
         "\"from_msc\":%I64d,\"to_msc_exclusive\":%I64d,"
         "\"copy_status\":\"COPY_RANGE_COMPLETE\","
         "\"market_coverage_status\":\"%s\",\"tick_count\":%d}\r\n",
         EscapeJson(InpEvidenceRunId), EscapeJson(symbol), chunk_index,
         chunk_from, chunk_to_exclusive,
         copied == 0 ? "REQUIRES_CLOSED_MARKET_PROOF" : "OBSERVED_TICKS_PRESENT",
         copied);
      if(FileWriteString(chunk_handle, chunk_row) != (uint)StringLen(chunk_row))
        {
         FileClose(tick_handle);
         FileClose(chunk_handle);
         PrintFormat("FTMO_EVENT_CHUNK_WRITE_FAILED symbol=%s chunk=%d",
                     symbol, chunk_index);
         return false;
        }
      ArrayFree(ticks);
      ++chunk_index;
      if((chunk_index % 7) == 0)
        {
         FileFlush(tick_handle);
         FileFlush(chunk_handle);
        }
     }

   FileFlush(tick_handle);
   FileFlush(chunk_handle);
   FileClose(tick_handle);
   FileClose(chunk_handle);

   const int complete_handle = FileOpen(
      complete_path,
      FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(complete_handle == INVALID_HANDLE)
      return false;
   const string complete = StringFormat(
      "{\"event\":\"TICK_RAW_COPY_COMPLETE\",\"schema_version\":1,"
      "\"producer\":\"%s\",\"run_id\":\"%s\",\"symbol\":\"%s\","
      "\"time_basis\":\"DARWINEX_US_DST_BROKER_WALL_EPOCH\","
      "\"from_msc\":%I64d,\"to_msc_exclusive\":%I64d,"
      "\"chunk_count\":%d,\"tick_count\":%I64d,"
      "\"raw_copy_complete\":true,\"market_coverage_complete\":false,"
      "\"market_coverage_requirement\":\"SEPARATE_HASH_BOUND_SESSION_AND_HOLIDAY_PROOF\"}\r\n",
      QM_FTMO_EVENT_TICK_PRODUCER,
      EscapeJson(InpEvidenceRunId), EscapeJson(symbol),
      from_msc, to_msc_exclusive, chunk_index, source_index);
   const bool complete_written =
      FileWriteString(complete_handle, complete) == (uint)StringLen(complete);
   FileFlush(complete_handle);
   FileClose(complete_handle);
   if(!complete_written)
      FileDelete(complete_path, FILE_COMMON);
   PrintFormat(
      "FTMO_EVENT_TICK_EXPORT symbol=%s ticks=%I64d chunks=%d complete=%s",
      symbol, source_index, chunk_index, complete_written ? "true" : "false");
   return complete_written;
  }

void OnStart()
  {
   if(!SafeToken(InpEvidenceRunId))
     {
      Print("FTMO_EVENT_TICK_RUN_ID_INVALID");
      return;
     }
   if(!RemoveStaleComplete(RunCompletePath()))
     {
      Print("FTMO_EVENT_RUN_STALE_COMPLETE_BLOCKED");
      return;
     }
   if(!SafeToken(InpExpectedAccountCurrency) ||
      !SafeToken(InpSessionTimezoneBasis) ||
      InpRawTimeBasis != "DARWINEX_US_DST_BROKER_WALL_EPOCH" ||
      InpExpectedAccountLeverage <= 0 ||
      InpFromBrokerWall <= 0 ||
      InpToBrokerWallExclusive <= InpFromBrokerWall ||
      InpChunkHours < 1 || InpChunkHours > 168 ||
      InpCopyRetries < 1 || InpCopyRetries > 10)
     {
      Print("FTMO_EVENT_TICK_CONFIG_INVALID");
      return;
     }

   string symbols[];
   const ushort separator = ';';
   const int symbol_count = StringSplit(InpSymbols, separator, symbols);
   if(symbol_count != 3)
     {
      PrintFormat("FTMO_EVENT_TICK_SYMBOL_COUNT_INVALID count=%d", symbol_count);
      return;
     }
   for(int i = 0; i < symbol_count; ++i)
     {
      StringTrimLeft(symbols[i]);
      StringTrimRight(symbols[i]);
      if(symbols[i] == "" || !SafeToken(SafeSymbol(symbols[i])))
        {
         Print("FTMO_EVENT_TICK_SYMBOL_PATH_TOKEN_INVALID");
         return;
        }
      for(int j = 0; j < i; ++j)
         if(symbols[i] == symbols[j] ||
            SafeSymbol(symbols[i]) == SafeSymbol(symbols[j]))
           {
            PrintFormat("FTMO_EVENT_TICK_SYMBOL_DUPLICATE symbol=%s", symbols[i]);
            return;
           }
     }

   for(int i = 0; i < symbol_count; ++i)
      if(!SymbolSelect(symbols[i], true))
        {
         PrintFormat("FTMO_EVENT_TICK_SELECT_FAILED symbol=%s error=%d",
                     symbols[i], GetLastError());
         return;
        }
   for(int i = 0; i < symbol_count; ++i)
      if(!RemoveStaleComplete(TickStem(symbols[i]) + ".complete.json"))
        {
         PrintFormat("FTMO_EVENT_SYMBOL_STALE_COMPLETE_BLOCKED symbol=%s",
                     symbols[i]);
         return;
        }

   if(!WriteAllSymbolProperties(symbols))
     {
      Print("FTMO_EVENT_SYMBOL_PROPERTIES_BLOCKED");
      return;
     }

   const long from_msc = (long)InpFromBrokerWall * 1000;
   const long to_msc_exclusive = (long)InpToBrokerWallExclusive * 1000;
   const long chunk_msc = (long)InpChunkHours * 3600 * 1000;
   for(int i = 0; i < symbol_count; ++i)
      if(!ExportSymbol(symbols[i], from_msc, to_msc_exclusive, chunk_msc))
        {
         PrintFormat("FTMO_EVENT_TICK_EXPORT_BLOCKED symbol=%s", symbols[i]);
         return;
        }
   const int run_complete_handle = FileOpen(
      RunCompletePath(),
      FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(run_complete_handle == INVALID_HANDLE)
     {
      PrintFormat("FTMO_EVENT_RUN_COMPLETE_OPEN_FAILED error=%d", GetLastError());
      return;
     }
   const string run_complete = StringFormat(
      "{\"event\":\"TICK_RAW_COPY_SET_COMPLETE\",\"schema_version\":1,"
      "\"producer\":\"%s\",\"run_id\":\"%s\",\"symbol_count\":3,"
      "\"time_basis\":\"DARWINEX_US_DST_BROKER_WALL_EPOCH\","
      "\"from_msc\":%I64d,\"to_msc_exclusive\":%I64d,"
      "\"raw_copy_complete\":true,\"market_coverage_complete\":false}\r\n",
      QM_FTMO_EVENT_TICK_PRODUCER,
      EscapeJson(InpEvidenceRunId),
      from_msc,
      to_msc_exclusive);
   if(FileWriteString(run_complete_handle, run_complete) !=
      (uint)StringLen(run_complete))
     {
      FileClose(run_complete_handle);
      FileDelete(RunCompletePath(), FILE_COMMON);
      Print("FTMO_EVENT_RUN_COMPLETE_WRITE_FAILED");
      return;
     }
   FileFlush(run_complete_handle);
   FileClose(run_complete_handle);
   PrintFormat("FTMO_EVENT_TICK_EXPORT_ALL_COMPLETE run_id=%s",
               InpEvidenceRunId);
  }
