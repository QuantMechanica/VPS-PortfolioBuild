//+------------------------------------------------------------------+
//| QM_Dump_DWX_TickValue.mq5                                       |
//|                                                                  |
//| H5/P1.8 verification-only diagnostic for non-FX .DWX sizing.    |
//| Reads symbol metadata, calls the canonical framework snapshot and|
//| lot functions, and compares them with independent OrderCalcProfit|
//| probes. It never sends, modifies, or closes an order.            |
//|                                                                  |
//| Output is staged in FILE_COMMON. The checked-in PowerShell runner|
//| validates the completion marker and atomically publishes evidence.|
//+------------------------------------------------------------------+
#property copyright "QuantMechanica"
#property version   "1.00"
#property strict

#include "..\..\include\QM\QM_RiskSizer.mqh"

const string QM_DWX_SCHEMA_VERSION = "1";
const string QM_DWX_CSV_PATH = "QM\\state\\dwx_tickvalue_dump_staging.csv";
const string QM_DWX_MARKER_PATH = "QM\\state\\dwx_tickvalue_dump_complete.marker";
const double QM_DWX_RISK_MONEY = 1000.0;
const int QM_DWX_PROBE_TICKS = 100;
const double QM_DWX_MATCH_TOLERANCE_PCT = 0.5;
const int QM_DWX_DATA_WAIT_MS = 60000;

const string QM_DWX_CSV_HEADER =
   "schema_version,timestamp_utc,terminal_id,terminal_build,server,account_currency,"
   "symbol,symbol_exists,symbol_custom,symbol_selected,trade_calc_mode,trade_calc_mode_name,"
   "currency_base,currency_profit,currency_margin,digits,point,tick_size,tick_value,"
   "tick_value_profit,tick_value_loss,contract_size,volume_min,volume_max,volume_step,"
   "bid,ask,last,reference_price,risk_money,probe_ticks,price_delta,sl_points,"
   "buy_profit_ok,buy_profit_error,buy_profit,buy_loss_ok,buy_loss_error,buy_loss,"
   "sell_profit_ok,sell_profit_error,sell_profit,sell_loss_ok,sell_loss_error,sell_loss,"
   "ordercalc_tick_value_profit,ordercalc_tick_value_loss,ordercalc_tick_value_conservative,"
   "snapshot_ok,snapshot_tick_value,snapshot_tick_size,snapshot_point,snapshot_contract_size,"
   "framework_value_path,framework_point_value_per_lot,framework_loss_per_lot,"
   "framework_raw_lots,framework_quantized_lots,ordercalc_loss_per_lot,ordercalc_raw_lots,"
   "ordercalc_quantized_lots,framework_lots_ordercalc_loss,tick_value_rel_diff_pct,"
   "raw_lots_rel_diff_pct,quantized_lots_match,verdict,error_class";

string BoolText(const bool value)
  {
   return value ? "true" : "false";
  }

bool WaitForConnectedQuotes(const string &symbols[])
  {
   for(int i = 0; i < ArraySize(symbols); i++)
      SymbolSelect(symbols[i], true);

   const ulong started_ms = GetTickCount64();
   while((GetTickCount64() - started_ms) < (ulong)QM_DWX_DATA_WAIT_MS)
     {
      if((bool)TerminalInfoInteger(TERMINAL_CONNECTED))
        {
         bool all_ready = true;
         for(int i = 0; i < ArraySize(symbols); i++)
           {
            MqlTick tick;
            ResetLastError();
            if(!SymbolInfoTick(symbols[i], tick) ||
               (tick.bid <= 0.0 && tick.ask <= 0.0 && tick.last <= 0.0))
              {
               all_ready = false;
               break;
              }
           }
         if(all_ready)
           {
            PrintFormat("QM_DWX_TICKVALUE_PREFLIGHT connected=true quotes=true wait_ms=%I64u",
                        GetTickCount64() - started_ms);
            return true;
           }
        }
      Sleep(250);
     }

   PrintFormat("QM_DWX_TICKVALUE_PREFLIGHT connected=%s quotes=false wait_ms=%d",
               BoolText((bool)TerminalInfoInteger(TERMINAL_CONNECTED)),
               QM_DWX_DATA_WAIT_MS);
   return false;
  }

string NumberText(const double value)
  {
   if(!MathIsValidNumber(value))
      return "";
   return DoubleToString(value, 12);
  }

string OptionalNumberText(const bool available, const double value)
  {
   if(!available)
      return "";
   return NumberText(value);
  }

string CsvEscape(const string value)
  {
   string escaped = value;
   StringReplace(escaped, "\"", "\"\"");
   if(StringFind(escaped, ",") >= 0 || StringFind(escaped, "\"") >= 0 ||
      StringFind(escaped, "\r") >= 0 || StringFind(escaped, "\n") >= 0)
      return "\"" + escaped + "\"";
   return escaped;
  }

void AddField(string &fields[], int &count, const string value)
  {
   ArrayResize(fields, count + 1);
   fields[count] = value;
   count++;
  }

void AppendError(string &error_class, const string value)
  {
   if(value == "")
      return;
   if(error_class != "")
      error_class += ";";
   error_class += value;
  }

string ErrorToken(const string prefix, const int error_code)
  {
   return prefix + ":" + IntegerToString(error_code);
  }

string TerminalLeafName()
  {
   const string path = TerminalInfoString(TERMINAL_DATA_PATH);
   int last_separator = -1;
   for(int i = 0; i < StringLen(path); i++)
     {
      const int ch = StringGetCharacter(path, i);
      if(ch == 92 || ch == 47)
         last_separator = i;
     }
   if(last_separator >= 0 && last_separator + 1 < StringLen(path))
      return StringSubstr(path, last_separator + 1);
   return path;
  }

bool ReadReferencePrice(const string symbol,
                        const int digits,
                        double &bid,
                        double &ask,
                        double &last,
                        double &reference_price)
  {
   bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   last = SymbolInfoDouble(symbol, SYMBOL_LAST);
   reference_price = 0.0;

   MqlTick tick;
   if(SymbolInfoTick(symbol, tick))
     {
      if(tick.bid > 0.0)
         bid = tick.bid;
      if(tick.ask > 0.0)
         ask = tick.ask;
      if(tick.last > 0.0)
         last = tick.last;
     }

   if(bid > 0.0 && ask > 0.0)
      reference_price = (bid + ask) * 0.5;
   else if(last > 0.0)
      reference_price = last;
   else if(bid > 0.0)
      reference_price = bid;
   else if(ask > 0.0)
      reference_price = ask;

   if(reference_price <= 0.0)
     {
      double closes[];
      ArraySetAsSeries(closes, true);
      ResetLastError();
      if(CopyClose(symbol, PERIOD_D1, 0, 1, closes) == 1 && closes[0] > 0.0)
         reference_price = closes[0];
     }

   if(reference_price <= 0.0)
      return false;
   reference_price = NormalizeDouble(reference_price, digits);
   return (reference_price > 0.0);
  }

bool ProbeOrderCalcProfit(const ENUM_ORDER_TYPE order_type,
                          const string symbol,
                          const double open_price,
                          const double close_price,
                          double &profit,
                          int &error_code)
  {
   profit = 0.0;
   ResetLastError();
   const bool ok = OrderCalcProfit(order_type, symbol, 1.0, open_price, close_price, profit);
   error_code = GetLastError();
   return (ok && MathIsValidNumber(profit));
  }

void ResetSnapshot(QM_SymbolRiskSnapshot &snapshot)
  {
   snapshot.tick_value = 0.0;
   snapshot.tick_size = 0.0;
   snapshot.point = 0.0;
   snapshot.volume_min = 0.0;
   snapshot.volume_max = 0.0;
   snapshot.volume_step = 0.0;
   snapshot.contract_size = 0.0;
   snapshot.margin_initial = 0.0;
  }

string BuildSymbolRow(const string symbol, string &verdict_out)
  {
   string error_class = "";
   const string account_server = AccountInfoString(ACCOUNT_SERVER);
   const string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
   if(account_currency == "")
      AppendError(error_class, "ACCOUNT_CURRENCY_EMPTY");
   bool is_custom = false;
   const bool symbol_exists = SymbolExist(symbol, is_custom);
   bool selected_before = false;
   bool symbol_selected = false;

   if(!symbol_exists)
      AppendError(error_class, "SYMBOL_MISSING");
   else
     {
      selected_before = (bool)SymbolInfoInteger(symbol, SYMBOL_SELECT);
      ResetLastError();
      if(!SymbolSelect(symbol, true))
         AppendError(error_class, ErrorToken("SYMBOL_SELECT_FAILED", GetLastError()));
      symbol_selected = (bool)SymbolInfoInteger(symbol, SYMBOL_SELECT);
      if(!is_custom)
         AppendError(error_class, "SYMBOL_NOT_CUSTOM");
     }

   long calc_mode = -1;
   string calc_mode_name = "";
   string currency_base = "";
   string currency_profit = "";
   string currency_margin = "";
   int digits = 0;
   double point = 0.0;
   double tick_size = 0.0;
   double tick_value = 0.0;
   double tick_value_profit = 0.0;
   double tick_value_loss = 0.0;
   double contract_size = 0.0;
   double volume_min = 0.0;
   double volume_max = 0.0;
   double volume_step = 0.0;

   if(symbol_exists && symbol_selected)
     {
      calc_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
      calc_mode_name = EnumToString((ENUM_SYMBOL_CALC_MODE)calc_mode);
      currency_base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
      currency_profit = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
      currency_margin = SymbolInfoString(symbol, SYMBOL_CURRENCY_MARGIN);
      digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      tick_value_profit = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
      tick_value_loss = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      volume_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
     }

   if(point <= 0.0)
      AppendError(error_class, "INVALID_POINT");
   if(tick_size <= 0.0)
      AppendError(error_class, "INVALID_TICK_SIZE");
   if(volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0)
      AppendError(error_class, "INVALID_VOLUME_SPEC");

   double bid = 0.0;
   double ask = 0.0;
   double last = 0.0;
   double reference_price = 0.0;
   const bool reference_ok = (symbol_exists && symbol_selected &&
                              ReadReferencePrice(symbol, digits, bid, ask, last, reference_price));
   if(!reference_ok)
      AppendError(error_class, "INVALID_REFERENCE_PRICE");

   const double price_delta = (tick_size > 0.0 ? QM_DWX_PROBE_TICKS * tick_size : 0.0);
   const double sl_points = (point > 0.0 ? price_delta / point : 0.0);
   double probe_up = 0.0;
   double probe_down = 0.0;
   bool probe_prices_ok = false;
   if(reference_ok && price_delta > 0.0)
     {
      probe_up = NormalizeDouble(reference_price + price_delta, digits);
      probe_down = NormalizeDouble(reference_price - price_delta, digits);
      probe_prices_ok = (probe_up > reference_price && probe_down > 0.0 &&
                         probe_down < reference_price);
     }
   if(!probe_prices_ok)
      AppendError(error_class, "INVALID_PROBE_PRICES");

   double buy_profit = 0.0;
   double buy_loss = 0.0;
   double sell_profit = 0.0;
   double sell_loss = 0.0;
   int buy_profit_error = 0;
   int buy_loss_error = 0;
   int sell_profit_error = 0;
   int sell_loss_error = 0;
   bool buy_profit_ok = false;
   bool buy_loss_ok = false;
   bool sell_profit_ok = false;
   bool sell_loss_ok = false;

   if(probe_prices_ok)
     {
      buy_profit_ok = ProbeOrderCalcProfit(ORDER_TYPE_BUY, symbol, reference_price, probe_up,
                                           buy_profit, buy_profit_error);
      buy_loss_ok = ProbeOrderCalcProfit(ORDER_TYPE_BUY, symbol, reference_price, probe_down,
                                         buy_loss, buy_loss_error);
      sell_profit_ok = ProbeOrderCalcProfit(ORDER_TYPE_SELL, symbol, reference_price, probe_down,
                                            sell_profit, sell_profit_error);
      sell_loss_ok = ProbeOrderCalcProfit(ORDER_TYPE_SELL, symbol, reference_price, probe_up,
                                          sell_loss, sell_loss_error);
     }

   if(probe_prices_ok)
     {
      if(!buy_profit_ok)
         AppendError(error_class, ErrorToken("ORDER_CALC_BUY_PROFIT", buy_profit_error));
      if(!buy_loss_ok)
         AppendError(error_class, ErrorToken("ORDER_CALC_BUY_LOSS", buy_loss_error));
      if(!sell_profit_ok)
         AppendError(error_class, ErrorToken("ORDER_CALC_SELL_PROFIT", sell_profit_error));
      if(!sell_loss_ok)
         AppendError(error_class, ErrorToken("ORDER_CALC_SELL_LOSS", sell_loss_error));
     }

   const bool profit_probe_ok = (buy_profit_ok && sell_profit_ok);
   const bool loss_probe_ok = (buy_loss_ok && sell_loss_ok);
   const bool all_probes_ok = (profit_probe_ok && loss_probe_ok);
   double ordercalc_tick_value_profit = 0.0;
   double ordercalc_tick_value_loss = 0.0;
   double ordercalc_tick_value_conservative = 0.0;
   double ordercalc_loss_per_lot = 0.0;

   if(profit_probe_ok)
      ordercalc_tick_value_profit =
         (MathAbs(buy_profit) + MathAbs(sell_profit)) / (2.0 * QM_DWX_PROBE_TICKS);
   if(loss_probe_ok)
     {
      ordercalc_tick_value_loss =
         (MathAbs(buy_loss) + MathAbs(sell_loss)) / (2.0 * QM_DWX_PROBE_TICKS);
      ordercalc_tick_value_conservative =
         MathMax(MathAbs(buy_loss), MathAbs(sell_loss)) / QM_DWX_PROBE_TICKS;
      ordercalc_loss_per_lot =
         MathMax(MathAbs(buy_loss), MathAbs(sell_loss));
      if(ordercalc_loss_per_lot <= 0.0)
         AppendError(error_class, "ORDER_CALC_LOSS_ZERO");
     }

   QM_SymbolRiskSnapshot snapshot;
   ResetSnapshot(snapshot);
   const bool snapshot_ok = (symbol_exists && symbol_selected &&
                             QM_RiskSizerReadSymbolSnapshot(symbol, snapshot));
   if(!snapshot_ok)
      AppendError(error_class, "SNAPSHOT_FAILED");

   string framework_value_path = "unavailable";
   double framework_point_value_per_lot = 0.0;
   if(snapshot_ok && snapshot.tick_value > 0.0 && snapshot.tick_size > 0.0 &&
      snapshot.point > 0.0)
     {
      framework_value_path = "native_tick_value";
      framework_point_value_per_lot =
         snapshot.tick_value * (snapshot.point / snapshot.tick_size);
     }
   else if(snapshot_ok && snapshot.contract_size > 0.0 && snapshot.point > 0.0)
     {
      framework_value_path = "contract_point_fallback";
      framework_point_value_per_lot = snapshot.contract_size * snapshot.point;
     }

   const double framework_loss_per_lot = sl_points * framework_point_value_per_lot;
   const double framework_raw_lots =
      (framework_loss_per_lot > 0.0 ? QM_DWX_RISK_MONEY / framework_loss_per_lot : 0.0);
   const double framework_quantized_lots =
      (snapshot_ok ? QM_LotsForRiskFromSnapshot(snapshot, QM_DWX_RISK_MONEY, sl_points) : 0.0);
   if(snapshot_ok && framework_loss_per_lot <= 0.0)
      AppendError(error_class, "FRAMEWORK_LOSS_PER_LOT_ZERO");

   const double ordercalc_raw_lots =
      (ordercalc_loss_per_lot > 0.0 ? QM_DWX_RISK_MONEY / ordercalc_loss_per_lot : 0.0);
   const double ordercalc_quantized_lots =
      (snapshot_ok && ordercalc_raw_lots > 0.0 ?
       QM_RiskSizerQuantizeLots(ordercalc_raw_lots, snapshot.volume_min,
                                snapshot.volume_max, snapshot.volume_step) : 0.0);
   const double framework_lots_ordercalc_loss =
      framework_quantized_lots * ordercalc_loss_per_lot;

   const bool tick_diff_available =
      (snapshot_ok && snapshot.tick_value > 0.0 && ordercalc_tick_value_conservative > 0.0);
   const double tick_value_rel_diff_pct =
      (tick_diff_available ?
       100.0 * MathAbs(snapshot.tick_value - ordercalc_tick_value_conservative) /
       ordercalc_tick_value_conservative : 0.0);
   const bool raw_diff_available = (framework_raw_lots > 0.0 && ordercalc_raw_lots > 0.0);
   const double raw_lots_rel_diff_pct =
      (raw_diff_available ?
       100.0 * MathAbs(framework_raw_lots - ordercalc_raw_lots) /
       ordercalc_raw_lots : 0.0);
   const double lot_tolerance = MathMax(1e-8, snapshot.volume_step * 0.25);
   const bool quantized_lots_match =
      (snapshot_ok && loss_probe_ok &&
       MathAbs(framework_quantized_lots - ordercalc_quantized_lots) <= lot_tolerance);

   string verdict = "UNRESOLVED";
   const bool comparison_ready =
      (symbol_exists && is_custom && symbol_selected && snapshot_ok && all_probes_ok &&
       account_currency != "" && ordercalc_loss_per_lot > 0.0 &&
       framework_loss_per_lot > 0.0 && raw_diff_available);
   if(comparison_ready)
     {
      if(raw_lots_rel_diff_pct <= QM_DWX_MATCH_TOLERANCE_PCT && quantized_lots_match)
         verdict = "MATCH";
      else if(framework_lots_ordercalc_loss > QM_DWX_RISK_MONEY * 1.005 ||
              framework_quantized_lots > ordercalc_quantized_lots + lot_tolerance)
         verdict = "OVER_RISK";
      else if(framework_quantized_lots + lot_tolerance < ordercalc_quantized_lots)
         verdict = "CONSERVATIVE_UNDERSIZE";
      else
         verdict = "DIVERGENT";
     }
   verdict_out = verdict;

   string fields[];
   int count = 0;
   AddField(fields, count, QM_DWX_SCHEMA_VERSION);
   AddField(fields, count, TimeToString(TimeGMT(), TIME_DATE | TIME_SECONDS));
   AddField(fields, count, TerminalLeafName());
   AddField(fields, count, IntegerToString((int)TerminalInfoInteger(TERMINAL_BUILD)));
   AddField(fields, count, account_server);
   AddField(fields, count, account_currency);
   AddField(fields, count, symbol);
   AddField(fields, count, BoolText(symbol_exists));
   AddField(fields, count, BoolText(is_custom));
   AddField(fields, count, BoolText(symbol_selected));
   AddField(fields, count, IntegerToString((int)calc_mode));
   AddField(fields, count, calc_mode_name);
   AddField(fields, count, currency_base);
   AddField(fields, count, currency_profit);
   AddField(fields, count, currency_margin);
   AddField(fields, count, IntegerToString(digits));
   AddField(fields, count, NumberText(point));
   AddField(fields, count, NumberText(tick_size));
   AddField(fields, count, NumberText(tick_value));
   AddField(fields, count, NumberText(tick_value_profit));
   AddField(fields, count, NumberText(tick_value_loss));
   AddField(fields, count, NumberText(contract_size));
   AddField(fields, count, NumberText(volume_min));
   AddField(fields, count, NumberText(volume_max));
   AddField(fields, count, NumberText(volume_step));
   AddField(fields, count, NumberText(bid));
   AddField(fields, count, NumberText(ask));
   AddField(fields, count, NumberText(last));
   AddField(fields, count, OptionalNumberText(reference_ok, reference_price));
   AddField(fields, count, NumberText(QM_DWX_RISK_MONEY));
   AddField(fields, count, IntegerToString(QM_DWX_PROBE_TICKS));
   AddField(fields, count, NumberText(price_delta));
   AddField(fields, count, NumberText(sl_points));
   AddField(fields, count, BoolText(buy_profit_ok));
   AddField(fields, count, IntegerToString(buy_profit_error));
   AddField(fields, count, OptionalNumberText(buy_profit_ok, buy_profit));
   AddField(fields, count, BoolText(buy_loss_ok));
   AddField(fields, count, IntegerToString(buy_loss_error));
   AddField(fields, count, OptionalNumberText(buy_loss_ok, buy_loss));
   AddField(fields, count, BoolText(sell_profit_ok));
   AddField(fields, count, IntegerToString(sell_profit_error));
   AddField(fields, count, OptionalNumberText(sell_profit_ok, sell_profit));
   AddField(fields, count, BoolText(sell_loss_ok));
   AddField(fields, count, IntegerToString(sell_loss_error));
   AddField(fields, count, OptionalNumberText(sell_loss_ok, sell_loss));
   AddField(fields, count, OptionalNumberText(profit_probe_ok, ordercalc_tick_value_profit));
   AddField(fields, count, OptionalNumberText(loss_probe_ok, ordercalc_tick_value_loss));
   AddField(fields, count, OptionalNumberText(loss_probe_ok, ordercalc_tick_value_conservative));
   AddField(fields, count, BoolText(snapshot_ok));
   AddField(fields, count, OptionalNumberText(snapshot_ok, snapshot.tick_value));
   AddField(fields, count, OptionalNumberText(snapshot_ok, snapshot.tick_size));
   AddField(fields, count, OptionalNumberText(snapshot_ok, snapshot.point));
   AddField(fields, count, OptionalNumberText(snapshot_ok, snapshot.contract_size));
   AddField(fields, count, framework_value_path);
   AddField(fields, count, OptionalNumberText(snapshot_ok, framework_point_value_per_lot));
   AddField(fields, count, OptionalNumberText(snapshot_ok, framework_loss_per_lot));
   AddField(fields, count, OptionalNumberText(snapshot_ok && framework_loss_per_lot > 0.0,
                                               framework_raw_lots));
   AddField(fields, count, OptionalNumberText(snapshot_ok, framework_quantized_lots));
   AddField(fields, count, OptionalNumberText(loss_probe_ok, ordercalc_loss_per_lot));
   AddField(fields, count, OptionalNumberText(loss_probe_ok && ordercalc_loss_per_lot > 0.0,
                                               ordercalc_raw_lots));
   AddField(fields, count, OptionalNumberText(loss_probe_ok, ordercalc_quantized_lots));
   AddField(fields, count, OptionalNumberText(loss_probe_ok, framework_lots_ordercalc_loss));
   AddField(fields, count, OptionalNumberText(tick_diff_available, tick_value_rel_diff_pct));
   AddField(fields, count, OptionalNumberText(raw_diff_available, raw_lots_rel_diff_pct));
   AddField(fields, count, BoolText(quantized_lots_match));
   AddField(fields, count, verdict);
   AddField(fields, count, (error_class == "" ? "NONE" : error_class));

   string line = "";
   for(int i = 0; i < ArraySize(fields); i++)
     {
      if(i > 0)
         line += ",";
      line += CsvEscape(fields[i]);
     }

   if(symbol_exists && !selected_before)
      SymbolSelect(symbol, false);
   return line;
  }

void OnStart()
  {
   const string symbols[] =
     {
      "NDX.DWX", "WS30.DWX", "SP500.DWX", "GDAXI.DWX",
      "XAUUSD.DWX", "XTIUSD.DWX", "XNGUSD.DWX"
     };

   // A /config startup script can be dispatched a few milliseconds before the
   // saved account finishes authorizing. Wait for live symbol data so a parked
   // export terminal cannot emit a false all-zero sizing comparison.
   WaitForConnectedQuotes(symbols);

   ResetLastError();
   const int csv_handle = FileOpen(QM_DWX_CSV_PATH,
                                   FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(csv_handle == INVALID_HANDLE)
     {
      PrintFormat("QM_DWX_TICKVALUE_FAIL stage=csv_open error=%d path=%s",
                  GetLastError(), QM_DWX_CSV_PATH);
      return;
     }

   if(FileWriteString(csv_handle, QM_DWX_CSV_HEADER + "\r\n") <= 0)
     {
      PrintFormat("QM_DWX_TICKVALUE_FAIL stage=header_write error=%d", GetLastError());
      FileClose(csv_handle);
      return;
     }

   int rows_written = 0;
   int unresolved_count = 0;
   for(int i = 0; i < ArraySize(symbols); i++)
     {
      string verdict = "UNRESOLVED";
      const string row = BuildSymbolRow(symbols[i], verdict);
      if(FileWriteString(csv_handle, row + "\r\n") <= 0)
        {
         PrintFormat("QM_DWX_TICKVALUE_FAIL stage=row_write symbol=%s error=%d",
                     symbols[i], GetLastError());
         FileClose(csv_handle);
         return;
        }
      rows_written++;
      if(verdict == "UNRESOLVED")
         unresolved_count++;
      PrintFormat("QM_DWX_TICKVALUE_ROW symbol=%s verdict=%s", symbols[i], verdict);
     }

   FileFlush(csv_handle);
   FileClose(csv_handle);

   ResetLastError();
   const int marker_handle = FileOpen(QM_DWX_MARKER_PATH,
                                      FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(marker_handle == INVALID_HANDLE)
     {
      PrintFormat("QM_DWX_TICKVALUE_FAIL stage=marker_open error=%d path=%s",
                  GetLastError(), QM_DWX_MARKER_PATH);
      return;
     }
   FileWriteString(marker_handle, "status=COMPLETE\r\n");
   FileWriteString(marker_handle, "schema_version=" + QM_DWX_SCHEMA_VERSION + "\r\n");
   FileWriteString(marker_handle, "rows=" + IntegerToString(rows_written) + "\r\n");
   FileWriteString(marker_handle, "unresolved_count=" + IntegerToString(unresolved_count) + "\r\n");
   FileWriteString(marker_handle, "csv=" + QM_DWX_CSV_PATH + "\r\n");
   FileWriteString(marker_handle,
                   "timestamp_utc=" + TimeToString(TimeGMT(), TIME_DATE | TIME_SECONDS) + "\r\n");
   FileFlush(marker_handle);
   FileClose(marker_handle);

   PrintFormat("QM_DWX_TICKVALUE_COMPLETE rows=%d unresolved=%d csv=%s marker=%s",
               rows_written, unresolved_count, QM_DWX_CSV_PATH, QM_DWX_MARKER_PATH);
  }
//+------------------------------------------------------------------+
