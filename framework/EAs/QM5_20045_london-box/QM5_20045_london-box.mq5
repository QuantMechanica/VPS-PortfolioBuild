#property strict
#property version   "5.0"
#property description "QM5_20045 fixed-UTC London box breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 framework inputs
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20045;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
// Backtest setfiles keep RISK_PERCENT at zero and RISK_FIXED at USD 1,000.
// A later governed live setfile may select 0.5% only by setting RISK_FIXED=0.
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_variant_id          = "LONDON_BOX_027_BASELINE";
input ENUM_TIMEFRAMES strategy_timeframe  = PERIOD_M15;
input int    strategy_box_start_hour_utc  = 3;
input int    strategy_box_end_hour_utc    = 6;
input double strategy_extension_fraction  = 0.27;
input double strategy_max_box_pips        = 40.0;
input double strategy_pip_size            = 0.0001;
input int    strategy_pending_expiry_hour_london = 12;
input int    strategy_flat_hour_london    = 16;
input double strategy_max_cost_r          = 0.10;
input double strategy_target_cost_multiple = 4.0;
input double strategy_round_turn_commission_account_per_lot = 0.0;
input string strategy_commission_source_id = "";
input string strategy_commission_source_sha256 = "";
input string strategy_trading_calendar_file = "QM5_20045_trading_calendar.csv";
input string strategy_trading_calendar_sha256 = "";
input string strategy_trading_calendar_source_id = "";
input string strategy_calendar_valid_through = "2025.12.31";
input string strategy_tzdb_version        = "";
input string strategy_expected_tick_feed_server = "";
input string strategy_tick_history_sha256 = "";
input string strategy_dataset_valid_through = "2025.12.31";

// =============================================================================
// Deterministic strategy state
// =============================================================================

int    g_trading_dates[];
bool   g_dependencies_attempted = false;
bool   g_dependencies_ready = false;

int    g_consumed_date_key = 0;
int    g_box_date_key = 0;
double g_box_high = 0.0;
double g_box_low = 0.0;
double g_box_size = 0.0;
ulong  g_fill_checked_ticket = 0;

// =============================================================================
// Provenance, calendar, and clock helpers
// =============================================================================

string Strategy_Trimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

string Strategy_Upper(string value)
  {
   StringToUpper(value);
   return value;
  }

bool Strategy_IsSha256(const string value)
  {
   if(StringLen(value) != 64)
      return false;
   const string hex = "0123456789abcdefABCDEF";
   for(int i = 0; i < 64; ++i)
     {
      if(StringFind(hex, StringSubstr(value, i, 1)) < 0)
         return false;
     }
   return true;
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_ParseDateKey(string value)
  {
   value = Strategy_Trimmed(value);
   StringReplace(value, "-", ".");
   return Strategy_DateKey(StringToTime(value + " 00:00"));
  }

datetime Strategy_DateStartUtc(const int date_key)
  {
   if(date_key < 19000101)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   return StructToTime(parts);
  }

datetime Strategy_LastSundayAtOneUtc(const int year, const int month)
  {
   MqlDateTime next_month;
   ZeroMemory(next_month);
   next_month.year = year;
   next_month.mon = month + 1;
   if(next_month.mon > 12)
     {
      next_month.mon = 1;
      ++next_month.year;
     }
   next_month.day = 1;
   const datetime next_month_start = StructToTime(next_month);
   if(next_month_start <= 86400)
      return 0;

   MqlDateTime last_day;
   if(!TimeToStruct(next_month_start - 86400, last_day))
      return 0;
   last_day.day -= last_day.day_of_week;
   last_day.hour = 1;
   last_day.min = 0;
   last_day.sec = 0;
   return StructToTime(last_day);
  }

bool Strategy_IsLondonDstUtc(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   const datetime start_utc = Strategy_LastSundayAtOneUtc(parts.year, 3);
   const datetime end_utc = Strategy_LastSundayAtOneUtc(parts.year, 10);
   return (start_utc > 0 && end_utc > start_utc &&
           utc >= start_utc && utc < end_utc);
  }

datetime Strategy_LondonLocal(const datetime utc)
  {
   if(utc <= 0)
      return 0;
   return utc + (Strategy_IsLondonDstUtc(utc) ? 3600 : 0);
  }

datetime Strategy_LondonHourToUtc(const int date_key, const int london_hour)
  {
   const datetime day_start = Strategy_DateStartUtc(date_key);
   if(day_start <= 0 || london_hour < 0 || london_hour > 23)
      return 0;
   const datetime nominal = day_start + london_hour * 3600;
   return nominal - (Strategy_IsLondonDstUtc(nominal) ? 3600 : 0);
  }

bool Strategy_CommonFileSha256(const string file_name, string &hash_hex)
  {
   hash_hex = "";
   const int handle = FileOpen(file_name,
                               FILE_READ | FILE_BIN | FILE_SHARE_READ | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;
   const int size = (int)FileSize(handle);
   if(size <= 0)
     {
      FileClose(handle);
      return false;
     }

   uchar bytes[];
   if(ArrayResize(bytes, size) != size ||
      FileReadArray(handle, bytes, 0, size) != size)
     {
      FileClose(handle);
      return false;
     }
   FileClose(handle);

   uchar digest[];
   uchar key[];
   ArrayResize(key, 0);
   const int digest_size = CryptEncode(CRYPT_HASH_SHA256, bytes, key, digest);
   if(digest_size <= 0)
      return false;
   for(int i = 0; i < digest_size; ++i)
      hash_hex += StringFormat("%02X", digest[i]);
   return true;
  }

bool Strategy_AppendTradingDate(const int date_key)
  {
   const datetime utc_start = Strategy_DateStartUtc(date_key);
   MqlDateTime parts;
   if(utc_start <= 0 || !TimeToStruct(utc_start, parts) ||
      parts.day_of_week == 0 || parts.day_of_week == 6)
      return false;
   const int count = ArraySize(g_trading_dates);
   if(count > 0 && date_key <= g_trading_dates[count - 1])
      return false;
   if(ArrayResize(g_trading_dates, count + 1) != count + 1)
      return false;
   g_trading_dates[count] = date_key;
   return true;
  }

bool Strategy_LoadTradingCalendar()
  {
   ArrayResize(g_trading_dates, 0);
   if(Strategy_ParseDateKey(strategy_calendar_valid_through) != 20251231 ||
      StringLen(strategy_tzdb_version) == 0 ||
      StringLen(strategy_trading_calendar_source_id) == 0 ||
      !Strategy_IsSha256(strategy_trading_calendar_sha256))
      return false;

   string actual_hash = "";
   if(!Strategy_CommonFileSha256(strategy_trading_calendar_file, actual_hash) ||
      Strategy_Upper(actual_hash) != Strategy_Upper(strategy_trading_calendar_sha256))
      return false;

   const int handle = FileOpen(strategy_trading_calendar_file,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   int rows = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string date_text = Strategy_Trimmed(FileReadString(handle));
      const string valid_through_text = Strategy_Trimmed(FileReadString(handle));
      const string source_identity = Strategy_Trimmed(FileReadString(handle));
      string retrieved_date = Strategy_Trimmed(FileReadString(handle));
      const string source_sha256 = Strategy_Trimmed(FileReadString(handle));
      const string tzdb_version = Strategy_Trimmed(FileReadString(handle));

      if(rows == 0 && date_text == "utc_date" &&
         valid_through_text == "valid_through")
         continue;
      if(date_text == "" && valid_through_text == "" && source_identity == "")
         continue;

      StringReplace(retrieved_date, "-", ".");
      const int date_key = Strategy_ParseDateKey(date_text);
      if(date_key <= 0 ||
         Strategy_ParseDateKey(valid_through_text) != 20251231 ||
         source_identity != strategy_trading_calendar_source_id ||
         StringToTime(retrieved_date + " 00:00") <= 0 ||
         !Strategy_IsSha256(source_sha256) ||
         tzdb_version != strategy_tzdb_version ||
         !Strategy_AppendTradingDate(date_key))
        {
         valid = false;
         break;
        }
      ++rows;
     }
   FileClose(handle);

   if(!valid || rows <= 0)
      return false;
   const int first_year = g_trading_dates[0] / 10000;
   const int last_year = g_trading_dates[rows - 1] / 10000;
   return (first_year <= 2018 && last_year >= 2025);
  }

bool Strategy_IsTradingDate(const int date_key)
  {
   int low = 0;
   int high = ArraySize(g_trading_dates);
   while(low < high)
     {
      const int middle = low + (high - low) / 2;
      if(g_trading_dates[middle] < date_key)
         low = middle + 1;
      else
         high = middle;
     }
   return (low < ArraySize(g_trading_dates) &&
           g_trading_dates[low] == date_key);
  }

bool Strategy_EnsureDependencies()
  {
   if(g_dependencies_attempted)
      return g_dependencies_ready;
   g_dependencies_attempted = true;

   const string actual_server = AccountInfoString(ACCOUNT_SERVER);
   const bool metadata_ready =
      (Strategy_ParseDateKey(strategy_dataset_valid_through) == 20251231 &&
       StringLen(strategy_expected_tick_feed_server) > 0 &&
       actual_server == strategy_expected_tick_feed_server &&
       Strategy_IsSha256(strategy_tick_history_sha256) &&
       strategy_round_turn_commission_account_per_lot > 0.0 &&
       StringLen(strategy_commission_source_id) > 0 &&
       Strategy_IsSha256(strategy_commission_source_sha256));
   const bool calendar_ready = Strategy_LoadTradingCalendar();
   g_dependencies_ready = (metadata_ready && calendar_ready);

   if(!g_dependencies_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"calendar\":\"%s\",\"calendar_ready\":%s,\"expected_server\":\"%s\",\"actual_server\":\"%s\",\"tzdb\":\"%s\"}",
                               strategy_trading_calendar_file,
                               calendar_ready ? "true" : "false",
                               strategy_expected_tick_feed_server,
                               actual_server,
                               strategy_tzdb_version));
   return g_dependencies_ready;
  }

// =============================================================================
// Position, order, and history helpers
// =============================================================================

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "GBPUSD.DWX" || symbol == "EURGBP.DWX");
  }

bool Strategy_IsStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP ||
           order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_FindOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      return true;
     }
   return false;
  }

int Strategy_OurPendingCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

int Strategy_PendingSetupDateKey()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         !Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      const datetime setup_broker = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      return Strategy_DateKey(QM_BrokerToUTC(setup_broker));
     }
   return 0;
  }

void Strategy_CancelOurPending(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         !Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_DateAlreadyUsed(const int date_key)
  {
   if(date_key <= 0)
      return true;
   if(g_consumed_date_key == date_key)
      return true;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(Strategy_DateKey(QM_BrokerToUTC((datetime)OrderGetInteger(ORDER_TIME_SETUP))) ==
         date_key)
         return true;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(Strategy_DateKey(QM_BrokerToUTC((datetime)PositionGetInteger(POSITION_TIME))) ==
         date_key)
         return true;
     }

   const datetime utc_from = Strategy_DateStartUtc(date_key);
   const datetime utc_to = utc_from + 86400;
   if(utc_from <= 0 ||
      !HistorySelect(QM_UTCToBroker(utc_from), QM_UTCToBroker(utc_to)))
      return true;

   for(int i = HistoryOrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
      if(Strategy_IsStopOrderType(type) ||
         type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
         return true;
     }

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

// =============================================================================
// Price, cost, volume, and box helpers
// =============================================================================

double Strategy_RoundPriceUp(const double price, const double tick_size)
  {
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_TM_NormalizePrice(_Symbol,
                               MathCeil((price - 1.0e-12) / tick_size) * tick_size);
  }

double Strategy_RoundPriceDown(const double price, const double tick_size)
  {
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_TM_NormalizePrice(_Symbol,
                               MathFloor((price + 1.0e-12) / tick_size) * tick_size);
  }

bool Strategy_CostGeometryAllows(const double entry_price,
                                 const double stop_price,
                                 const double target_price,
                                 double &risk_per_lot,
                                 double &cost_per_lot)
  {
   risk_per_lot = 0.0;
   cost_per_lot = 0.0;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value_loss =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   const double tick_value_profit =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" ||
      point <= 0.0 || tick_size <= 0.0 ||
      tick_value_loss <= 0.0 || tick_value_profit <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid ||
      entry_price <= 0.0 || stop_price <= 0.0 || target_price <= 0.0 ||
      strategy_round_turn_commission_account_per_lot <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   risk_per_lot = (stop_distance / tick_size) * tick_value_loss;
   const double target_per_lot =
      (target_distance / tick_size) * tick_value_profit;
   const double spread_per_lot =
      ((ask - bid) / tick_size) * tick_value_loss;
   cost_per_lot =
      strategy_round_turn_commission_account_per_lot + spread_per_lot;
   if(stop_distance <= 0.0 || target_distance <= 0.0 ||
      risk_per_lot <= 0.0 || target_per_lot <= 0.0 ||
      cost_per_lot <= 0.0 ||
      cost_per_lot / risk_per_lot > strategy_max_cost_r + 1.0e-12 ||
      target_per_lot + 1.0e-8 <
         strategy_target_cost_multiple * cost_per_lot)
      return false;

   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stop_distance / point + 1.0e-8 < (double)stop_level ||
      target_distance / point + 1.0e-8 < (double)stop_level)
      return false;
   return true;
  }

bool Strategy_VolumeRepresentsFixedRisk(const double volume,
                                        const double risk_per_lot)
  {
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume <= 0.0 || risk_per_lot <= 0.0 ||
      volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      volume < volume_min - 1.0e-8 || volume > volume_max + 1.0e-8)
      return false;

   const double steps = volume / volume_step;
   if(MathAbs(steps - MathRound(steps)) > 1.0e-6)
      return false;

   const double represented_risk = volume * risk_per_lot;
   const double one_step_risk = volume_step * risk_per_lot;
   return (represented_risk <= RISK_FIXED + 1.0e-6 &&
           RISK_FIXED - represented_risk <= one_step_risk + 1.0e-6);
  }

bool Strategy_PlacementSideAllows(const double entry_price,
                                  const double stop_price,
                                  const double target_price,
                                  double &lots,
                                  double &risk_per_lot)
  {
   lots = 0.0;
   double cost_per_lot = 0.0;
   if(!Strategy_CostGeometryAllows(entry_price,
                                   stop_price,
                                   target_price,
                                   risk_per_lot,
                                   cost_per_lot))
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   lots = QM_LotsForRisk(_Symbol,
                         MathAbs(entry_price - stop_price) / point,
                         QM_RISK_MODE_FIXED,
                         RISK_FIXED);
   return Strategy_VolumeRepresentsFixedRisk(lots, risk_per_lot);
  }

bool Strategy_OrderVolume(const ulong ticket, double &volume)
  {
   volume = 0.0;
   if(ticket == 0 || !OrderSelect(ticket))
      return false;
   volume = OrderGetDouble(ORDER_VOLUME_INITIAL);
   return (volume > 0.0);
  }

bool Strategy_BuildBox(int &date_key,
                       double &box_high,
                       double &box_low,
                       double &box_size)
  {
   date_key = 0;
   box_high = 0.0;
   box_low = 0.0;
   box_size = 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   // perf-allowed: exact twelve-bar fixed-UTC box, called once behind
   // the framework M15 new-bar gate.
   if(CopyRates(_Symbol, strategy_timeframe, 1, 12, rates) != 12) // perf-allowed
      return false;

   const datetime last_open_utc = QM_BrokerToUTC(rates[11].time);
   const datetime box_end_utc = last_open_utc + 15 * 60;
   MqlDateTime end_parts;
   if(last_open_utc <= 0 || !TimeToStruct(box_end_utc, end_parts) ||
      end_parts.hour != strategy_box_end_hour_utc ||
      end_parts.min != 0 || end_parts.sec != 0)
      return false;

   date_key = Strategy_DateKey(box_end_utc);
   const datetime day_start = Strategy_DateStartUtc(date_key);
   if(day_start <= 0 ||
      strategy_box_end_hour_utc - strategy_box_start_hour_utc != 3)
      return false;
   const datetime expected_first =
      day_start + strategy_box_start_hour_utc * 3600;

   box_high = -DBL_MAX;
   box_low = DBL_MAX;
   for(int i = 0; i < 12; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      if(bar_utc != expected_first + i * 15 * 60 ||
         rates[i].open <= 0.0 || rates[i].high <= 0.0 ||
         rates[i].low <= 0.0 || rates[i].close <= 0.0 ||
         rates[i].tick_volume <= 0 ||
         rates[i].high < rates[i].low ||
         rates[i].high + 1.0e-12 < MathMax(rates[i].open, rates[i].close) ||
         rates[i].low - 1.0e-12 > MathMin(rates[i].open, rates[i].close))
         return false;
      box_high = MathMax(box_high, rates[i].high);
      box_low = MathMin(box_low, rates[i].low);
     }

   box_size = box_high - box_low;
   return (box_high > 0.0 && box_low > 0.0 && box_size > 0.0 &&
           box_size <= strategy_max_box_pips * strategy_pip_size + 1.0e-12);
  }

bool Strategy_CurrentNewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
  }

bool Strategy_PlaceOcoPair(const int date_key,
                           const double box_high,
                           const double box_low,
                           const double box_size)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(tick_size <= 0.0 || point <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double buy_entry =
      Strategy_RoundPriceUp(box_high +
                            strategy_extension_fraction * box_size +
                            tick_size,
                            tick_size);
   const double sell_entry =
      Strategy_RoundPriceDown(box_low -
                              strategy_extension_fraction * box_size -
                              tick_size,
                              tick_size);
   const double buy_stop = QM_TM_NormalizePrice(_Symbol, box_low);
   const double sell_stop = QM_TM_NormalizePrice(_Symbol, box_high);
   const double buy_target =
      Strategy_RoundPriceUp(buy_entry + box_size, tick_size);
   const double sell_target =
      Strategy_RoundPriceDown(sell_entry - box_size, tick_size);
   if(buy_entry <= ask || sell_entry >= bid ||
      buy_stop <= 0.0 || sell_stop <= 0.0 ||
      buy_stop >= buy_entry || buy_target <= buy_entry ||
      sell_stop <= sell_entry || sell_target >= sell_entry)
      return false;

   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const double market_clearance =
      (double)MathMax(stop_level, freeze_level) * point;
   if(buy_entry - ask + 1.0e-12 < market_clearance ||
      bid - sell_entry + 1.0e-12 < market_clearance)
      return false;

   double buy_lots = 0.0;
   double sell_lots = 0.0;
   double buy_risk_per_lot = 0.0;
   double sell_risk_per_lot = 0.0;
   if(!Strategy_PlacementSideAllows(buy_entry,
                                    buy_stop,
                                    buy_target,
                                    buy_lots,
                                    buy_risk_per_lot) ||
      !Strategy_PlacementSideAllows(sell_entry,
                                    sell_stop,
                                    sell_target,
                                    sell_lots,
                                    sell_risk_per_lot))
      return false;

   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume_step <= 0.0 ||
      MathAbs(buy_lots - sell_lots) > volume_step * 0.5 + 1.0e-8)
      return false;

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime expiry_utc =
      Strategy_LondonHourToUtc(date_key,
                               strategy_pending_expiry_hour_london);
   const int expiration_seconds = (int)(expiry_utc - now_utc);
   if(now_utc <= 0 || expiry_utc <= now_utc || expiration_seconds <= 0)
      return false;

   QM_EntryRequest buy_req;
   ZeroMemory(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = buy_stop;
   buy_req.tp = buy_target;
   buy_req.reason = "LONDON_BOX_027_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = expiration_seconds;

   QM_EntryRequest sell_req;
   ZeroMemory(sell_req);
   sell_req.type = QM_SELL_STOP;
   sell_req.price = sell_entry;
   sell_req.sl = sell_stop;
   sell_req.tp = sell_target;
   sell_req.reason = "LONDON_BOX_027_SELL_STOP";
   sell_req.symbol_slot = qm_magic_slot_offset;
   sell_req.expiration_seconds = expiration_seconds;

   ulong buy_ticket = 0;
   ulong sell_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req,
                          buy_ticket,
                          0,
                          QM_RISK_MODE_FIXED,
                          RISK_FIXED))
      return false;
   if(!QM_TM_OpenPosition(sell_req,
                          sell_ticket,
                          0,
                          QM_RISK_MODE_FIXED,
                          RISK_FIXED))
     {
      QM_TM_RemovePendingOrder(buy_ticket, "oco_second_leg_rejected");
      return false;
     }

   double actual_buy_volume = 0.0;
   double actual_sell_volume = 0.0;
   if(!Strategy_OrderVolume(buy_ticket, actual_buy_volume) ||
      !Strategy_OrderVolume(sell_ticket, actual_sell_volume) ||
      MathAbs(actual_buy_volume - actual_sell_volume) >
         volume_step * 0.5 + 1.0e-8 ||
      !Strategy_VolumeRepresentsFixedRisk(actual_buy_volume,
                                          buy_risk_per_lot) ||
      !Strategy_VolumeRepresentsFixedRisk(actual_sell_volume,
                                          sell_risk_per_lot))
     {
      QM_TM_RemovePendingOrder(buy_ticket, "oco_volume_mismatch");
      QM_TM_RemovePendingOrder(sell_ticket, "oco_volume_mismatch");
      return false;
     }

   g_box_date_key = date_key;
   g_box_high = box_high;
   g_box_low = box_low;
   g_box_size = box_size;
   return true;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No Trade Filter: configuration, route, and tester risk contract.
bool Strategy_NoTradeFilter()
  {
   ulong position_ticket = 0;
   if(Strategy_FindOurPosition(position_ticket) ||
      Strategy_OurPendingCount() > 0)
      return false;

   return (!Strategy_IsRoutedSymbol(_Symbol) ||
           _Period != strategy_timeframe ||
           strategy_variant_id != "LONDON_BOX_027_BASELINE" ||
           strategy_timeframe != PERIOD_M15 ||
           strategy_box_start_hour_utc != 3 ||
           strategy_box_end_hour_utc != 6 ||
           strategy_extension_fraction != 0.27 ||
           strategy_max_box_pips != 40.0 ||
           strategy_pip_size != 0.0001 ||
           strategy_pending_expiry_hour_london != 12 ||
           strategy_flat_hour_london != 16 ||
           strategy_max_cost_r != 0.10 ||
           strategy_target_cost_multiple != 4.0 ||
           RISK_FIXED != 1000.0 ||
           RISK_PERCENT != 0.0);
  }

// Trade Entry: freeze the twelve complete 03:00-06:00 UTC M15 bars and place
// both stop legs as one fail-closed OCO attempt. The hook opens both framework
// requests itself so a rejected second leg can cancel the first atomically.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong position_ticket = 0;
   if(Strategy_FindOurPosition(position_ticket) ||
      Strategy_OurPendingCount() > 0)
      return false;

   int date_key = 0;
   double box_high = 0.0;
   double box_low = 0.0;
   double box_size = 0.0;
   if(!Strategy_BuildBox(date_key, box_high, box_low, box_size) ||
      date_key <= 0 || Strategy_DateAlreadyUsed(date_key))
      return false;

   // A symbol-date is consumed by its one 06:00 attempt, including every
   // fail-closed outcome. Later bars cannot chase or retry.
   g_consumed_date_key = date_key;
   if(!Strategy_EnsureDependencies() ||
      !Strategy_IsTradingDate(date_key))
      return false;

   Strategy_PlaceOcoPair(date_key, box_high, box_low, box_size);
   return false;
  }

// Trade Management: cancel the opposite OCO leg after first fill; cancel both
// pending legs on governed news or London-noon expiry; preserve immutable SL;
// and correct the provisional target to exactly one box from actual fill.
void Strategy_ManageOpenPosition()
  {
   ulong position_ticket = 0;
   if(Strategy_FindOurPosition(position_ticket))
     {
      Strategy_CancelOurPending("oco_first_fill");
      if(g_fill_checked_ticket == position_ticket ||
         !PositionSelectByTicket(position_ticket))
         return;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double current_target = PositionGetDouble(POSITION_TP);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double tick_size =
         SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      double box_size = g_box_size;
      if(box_size <= 0.0 && current_target > 0.0 && open_price > 0.0)
         box_size = MathAbs(current_target - open_price);
      if(box_size <= 0.0 || tick_size <= 0.0)
        {
         QM_TM_ClosePosition(position_ticket, QM_EXIT_STRATEGY);
         return;
        }

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double target_price =
         is_buy
         ? Strategy_RoundPriceUp(open_price + box_size, tick_size)
         : Strategy_RoundPriceDown(open_price - box_size, tick_size);
      double risk_per_lot = 0.0;
      double cost_per_lot = 0.0;
      if(open_price <= 0.0 || stop_price <= 0.0 || target_price <= 0.0 ||
         (is_buy && (open_price <= stop_price || target_price <= open_price)) ||
         (!is_buy && (open_price >= stop_price || target_price >= open_price)) ||
         !Strategy_CostGeometryAllows(open_price,
                                      stop_price,
                                      target_price,
                                      risk_per_lot,
                                      cost_per_lot) ||
         !Strategy_VolumeRepresentsFixedRisk(volume, risk_per_lot))
        {
         QM_TM_ClosePosition(position_ticket, QM_EXIT_STRATEGY);
         return;
        }

      if(MathAbs(current_target - target_price) > tick_size * 0.5 &&
         !QM_TM_MoveTP(position_ticket,
                       target_price,
                       "one_box_from_actual_fill"))
        {
         QM_TM_ClosePosition(position_ticket, QM_EXIT_STRATEGY);
         return;
        }
      g_fill_checked_ticket = position_ticket;
      return;
     }

   if(Strategy_OurPendingCount() <= 0)
      return;
   int setup_date_key = Strategy_PendingSetupDateKey();
   if(setup_date_key <= 0)
      setup_date_key = g_box_date_key;
   const datetime now_broker = TimeCurrent();
   const datetime now_utc = QM_BrokerToUTC(now_broker);
   const datetime expiry_utc =
      Strategy_LondonHourToUtc(setup_date_key,
                               strategy_pending_expiry_hour_london);
   if(now_utc <= 0 || expiry_utc <= 0 || now_utc >= expiry_utc)
     {
      Strategy_CancelOurPending("london_noon_expiry");
      g_consumed_date_key = setup_date_key;
      return;
     }

   if(!Strategy_CurrentNewsAllows(now_broker))
     {
      Strategy_CancelOurPending("news_pause_consumes_date");
      g_consumed_date_key = setup_date_key;
     }
  }

// Trade Close: first tradable quote at or after 16:00 Europe/London.
bool Strategy_ExitSignal()
  {
   ulong position_ticket = 0;
   if(!Strategy_FindOurPosition(position_ticket) ||
      !PositionSelectByTicket(position_ticket))
      return false;

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime open_utc =
      QM_BrokerToUTC((datetime)PositionGetInteger(POSITION_TIME));
   const datetime now_london = Strategy_LondonLocal(now_utc);
   const datetime open_london = Strategy_LondonLocal(open_utc);
   if(now_london <= 0 || open_london <= 0)
      return false;

   const int now_date = Strategy_DateKey(now_london);
   const int open_date = Strategy_DateKey(open_london);
   if(now_date > open_date)
      return true;
   if(now_date < open_date)
      return false;

   MqlDateTime parts;
   if(!TimeToStruct(now_london, parts))
      return false;
   return (parts.hour >= strategy_flat_hour_london);
  }

// News Filter Hook: the central framework gate handles new entries. Pending
// OCO cancellation is performed in Strategy_ManageOpenPosition so management
// remains active during the blackout.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring
// =============================================================================

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20045\",\"variant\":\"LONDON_BOX_027_BASELINE\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows =
         QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
