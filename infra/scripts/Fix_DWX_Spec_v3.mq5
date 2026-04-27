//+------------------------------------------------------------------+
//| Fix_DWX_Spec_v3.mq5                                              |
//| Corrected DWX spec patch: tvp/tvl are derived (read-only).       |
//| spec_ok := custom.tv > 0 and rel_err(custom.tv, broker.tv) < 5%. |
//+------------------------------------------------------------------+
#property copyright "QuantMechanica"
#property version   "3.01"
#property strict

string SOURCE_OVERRIDES[][2] =
{
   {"GDAXIm", "GDAXI"},
   {"NDXm",   "NDX"}
};

string CUSTOM_SYMBOLS[] =
{
   "AUDCAD.DWX","AUDCHF.DWX","AUDJPY.DWX","AUDNZD.DWX","AUDUSD.DWX",
   "CADCHF.DWX","CADJPY.DWX","CHFJPY.DWX","EURAUD.DWX","EURCAD.DWX",
   "EURCHF.DWX","EURGBP.DWX","EURJPY.DWX","EURNZD.DWX","EURUSD.DWX",
   "GBPAUD.DWX","GBPCAD.DWX","GBPCHF.DWX","GBPJPY.DWX","GBPNZD.DWX",
   "GBPUSD.DWX","GDAXIm.DWX","NDXm.DWX","NZDCAD.DWX","NZDCHF.DWX",
   "NZDJPY.DWX","NZDUSD.DWX","UK100.DWX","USDCAD.DWX","USDCHF.DWX",
   "USDJPY.DWX","WS30.DWX","XAGUSD.DWX","XAUUSD.DWX","XNGUSD.DWX",
   "XTIUSD.DWX"
};

bool ReadSpec(const string symbol,
              double &tick_value,
              double &swap_long,
              double &swap_short,
              double &contract_size)
{
   if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE, tick_value)) return false;
   if(!SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG, swap_long)) return false;
   if(!SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT, swap_short)) return false;
   if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE, contract_size)) return false;
   return true;
}

bool TryResolveSource(const string custom_symbol, string &source_symbol)
{
   string root = custom_symbol;
   int suffix_pos = StringLen(root) - 4;
   if(suffix_pos < 1 || StringSubstr(root, suffix_pos) != ".DWX")
      return false;

   root = StringSubstr(root, 0, suffix_pos);

   for(int i = 0; i < ArrayRange(SOURCE_OVERRIDES, 0); i++)
   {
      if(root == SOURCE_OVERRIDES[i][0])
      {
         source_symbol = SOURCE_OVERRIDES[i][1];
         return true;
      }
   }

   string candidates[3];
   int count = 0;
   candidates[count++] = root;

   int len = StringLen(root);
   if(len > 1 && StringSubstr(root, len - 1) == "m")
      candidates[count++] = StringSubstr(root, 0, len - 1);

   candidates[count++] = root + "m";

   for(int c = 0; c < count; c++)
   {
      string candidate = candidates[c];
      bool candidate_is_custom = false;
      if(!SymbolExist(candidate, candidate_is_custom))
         continue;
      if(candidate_is_custom)
         continue;
      source_symbol = candidate;
      return true;
   }

   return false;
}

double RelativeError(const double custom_tv, const double broker_tv)
{
   if(broker_tv <= 0.0)
      return 1.0;
   return MathAbs(custom_tv - broker_tv) / broker_tv;
}

bool IsTickValueSpecOk(const double custom_tv, const double broker_tv)
{
   if(custom_tv <= 0.0 || broker_tv <= 0.0)
      return false;
   return RelativeError(custom_tv, broker_tv) < 0.05;
}

bool MatchWithinRounding(const double actual, const double expected, const int digits)
{
   return NormalizeDouble(actual, digits) == NormalizeDouble(expected, digits);
}

void PrintRow(const string custom_symbol,
              const string source_symbol,
              const double src_tv,
              const double dst_tv,
              const double rel_err,
              const double src_swap_long,
              const double dst_swap_long,
              const double src_swap_short,
              const double dst_swap_short,
              const double src_contract_size,
              const double dst_contract_size,
              const bool tick_ok,
              const bool swap_long_ok,
              const bool swap_short_ok,
              const bool contract_ok,
              const string reason)
{
   PrintFormat("ROW|custom=%s|source=%s|broker_tv=%.8f|custom_tv=%.8f|rel_err=%.6f|swap_long(src=%.6f,dst=%.6f)|swap_short(src=%.6f,dst=%.6f)|contract(src=%.4f,dst=%.4f)|spec_ok=%s|swap_ok=%s|contract_ok=%s|reason=%s",
               custom_symbol,
               source_symbol,
               src_tv,
               dst_tv,
               rel_err,
               src_swap_long,
               dst_swap_long,
               src_swap_short,
               dst_swap_short,
               src_contract_size,
               dst_contract_size,
               tick_ok ? "OK" : "BAD",
               (swap_long_ok && swap_short_ok) ? "OK" : "BAD",
               contract_ok ? "OK" : "BAD",
               reason);
}

void OnStart()
{
   const int BATCH_SIZE = 5;
   const int BATCH_SLEEP_MS = 200;

   int matched = 0;
   int patched = 0;
   int unchanged = 0;
   int failed = 0;
   int processed_in_batch = 0;

   Print("=== Fix_DWX_Spec_v3: start ===");
   Print("TABLE|custom|source|broker_tv|custom_tv|rel_err|swap_long(src,dst)|swap_short(src,dst)|contract(src,dst)|spec_ok|swap_ok|contract_ok|reason");

   for(int i = 0; i < ArraySize(CUSTOM_SYMBOLS); i++)
   {
      if(processed_in_batch >= BATCH_SIZE)
      {
         PrintFormat("BATCH|processed=%d|sleep_ms=%d", processed_in_batch, BATCH_SLEEP_MS);
         Sleep(BATCH_SLEEP_MS);
         processed_in_batch = 0;
      }
      processed_in_batch++;

      string custom_symbol = CUSTOM_SYMBOLS[i];
      bool custom_is_custom = false;
      if(!SymbolExist(custom_symbol, custom_is_custom) || !custom_is_custom)
      {
         failed++;
         PrintFormat("ROW|custom=%s|source=UNKNOWN|spec_ok=BAD|reason=custom_symbol_missing_or_not_custom", custom_symbol);
         continue;
      }

      matched++;

      string source_symbol = "";
      if(!TryResolveSource(custom_symbol, source_symbol))
      {
         failed++;
         PrintFormat("ROW|custom=%s|source=UNKNOWN|spec_ok=BAD|reason=source_symbol_not_found", custom_symbol);
         continue;
      }

      if(!SymbolSelect(custom_symbol, true))
      {
         failed++;
         PrintFormat("ROW|custom=%s|source=%s|spec_ok=BAD|reason=custom_symbol_select_failed", custom_symbol, source_symbol);
         continue;
      }

      if(!SymbolSelect(source_symbol, true))
      {
         failed++;
         PrintFormat("ROW|custom=%s|source=%s|spec_ok=BAD|reason=source_symbol_select_failed", custom_symbol, source_symbol);
         continue;
      }

      double src_tv = 0.0, src_swap_long = 0.0, src_swap_short = 0.0, src_contract_size = 0.0;
      double dst_tv = 0.0, dst_swap_long = 0.0, dst_swap_short = 0.0, dst_contract_size = 0.0;

      if(!ReadSpec(source_symbol, src_tv, src_swap_long, src_swap_short, src_contract_size))
      {
         failed++;
         PrintFormat("ROW|custom=%s|source=%s|spec_ok=BAD|reason=source_spec_read_failed", custom_symbol, source_symbol);
         continue;
      }

      if(!ReadSpec(custom_symbol, dst_tv, dst_swap_long, dst_swap_short, dst_contract_size))
      {
         failed++;
         PrintFormat("ROW|custom=%s|source=%s|spec_ok=BAD|reason=custom_spec_read_failed_before", custom_symbol, source_symbol);
         continue;
      }

      if(src_tv <= 0.0)
      {
         failed++;
         PrintRow(custom_symbol, source_symbol, src_tv, dst_tv, RelativeError(dst_tv, src_tv),
                  src_swap_long, dst_swap_long, src_swap_short, dst_swap_short,
                  src_contract_size, dst_contract_size,
                  false,
                  MatchWithinRounding(dst_swap_long, src_swap_long, 6),
                  MatchWithinRounding(dst_swap_short, src_swap_short, 6),
                  MatchWithinRounding(dst_contract_size, src_contract_size, 4),
                  "source_tick_value_zero");
         continue;
      }

      bool tick_ok_before = IsTickValueSpecOk(dst_tv, src_tv);
      bool swap_long_ok_before = MatchWithinRounding(dst_swap_long, src_swap_long, 6);
      bool swap_short_ok_before = MatchWithinRounding(dst_swap_short, src_swap_short, 6);
      bool contract_ok_before = MatchWithinRounding(dst_contract_size, src_contract_size, 4);

      bool needs_update =
         !tick_ok_before ||
         !swap_long_ok_before ||
         !swap_short_ok_before ||
         !contract_ok_before;

      string reason = "no_change";
      if(needs_update)
      {
         bool ok_tv = CustomSymbolSetDouble(custom_symbol, SYMBOL_TRADE_TICK_VALUE, src_tv);
         bool ok_swap_long = CustomSymbolSetDouble(custom_symbol, SYMBOL_SWAP_LONG, src_swap_long);
         bool ok_swap_short = CustomSymbolSetDouble(custom_symbol, SYMBOL_SWAP_SHORT, src_swap_short);
         bool ok_contract_size = CustomSymbolSetDouble(custom_symbol, SYMBOL_TRADE_CONTRACT_SIZE, src_contract_size);

         if(!ok_tv || !ok_swap_long || !ok_swap_short || !ok_contract_size)
         {
            failed++;
            reason = "custom_set_failed";
            PrintFormat("DETAIL|custom=%s|set_ok(tv=%d,swap_long=%d,swap_short=%d,contract_size=%d)",
                        custom_symbol,
                        ok_tv,
                        ok_swap_long,
                        ok_swap_short,
                        ok_contract_size);
         }
         else
         {
            reason = "patched";
         }
      }

      if(!ReadSpec(custom_symbol, dst_tv, dst_swap_long, dst_swap_short, dst_contract_size))
      {
         failed++;
         PrintFormat("ROW|custom=%s|source=%s|spec_ok=BAD|reason=custom_spec_read_failed_after", custom_symbol, source_symbol);
         continue;
      }

      bool tick_ok_after = IsTickValueSpecOk(dst_tv, src_tv);
      bool swap_long_ok_after = MatchWithinRounding(dst_swap_long, src_swap_long, 6);
      bool swap_short_ok_after = MatchWithinRounding(dst_swap_short, src_swap_short, 6);
      bool contract_ok_after = MatchWithinRounding(dst_contract_size, src_contract_size, 4);

      bool row_ok = tick_ok_after && swap_long_ok_after && swap_short_ok_after && contract_ok_after;
      if(row_ok)
      {
         if(needs_update) patched++;
         else unchanged++;
      }
      else
      {
         failed++;
         if(reason == "no_change") reason = "post_read_mismatch";
      }

      PrintRow(custom_symbol,
               source_symbol,
               src_tv,
               dst_tv,
               RelativeError(dst_tv, src_tv),
               src_swap_long,
               dst_swap_long,
               src_swap_short,
               dst_swap_short,
               src_contract_size,
               dst_contract_size,
               tick_ok_after,
               swap_long_ok_after,
               swap_short_ok_after,
               contract_ok_after,
               reason);
   }

   PrintFormat("=== Fix_DWX_Spec_v3: done expected=%d matched=%d patched=%d unchanged=%d failed=%d ===",
               ArraySize(CUSTOM_SYMBOLS), matched, patched, unchanged, failed);
}
//+------------------------------------------------------------------+