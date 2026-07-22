#property strict
#property version   "5.0"
#property description "QM5_20032 scheduled 08:30 ET macro breakout"

#include <QM/QM_Common.mqh>
#include <QM/QM_XetraCashCalendar.mqh>

// Strategy Card: QM5_20032_macro0830-brk, G0 APPROVED 2026-07-22.
// Eligible events and German cash exits come from a provenance-bearing ledger.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20032;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf  = PERIOD_M5;
input int    strategy_pre_release_bars    = 3;
input double strategy_max_cost_r          = 0.10;

const string STRATEGY_CALENDAR_PATH =
   "QM5_20023_announcement_calendar_20150101_20250404.csv";
const string STRATEGY_CALENDAR_SHA256 =
   "411AE4AF3DBE261E373705660E28B81E7C5DFC7398F38516E07EFFFF71CD73AF";
const string STRATEGY_PROVENANCE_SHA256 =
   "5585DA3C1EDA2CA6BFD08CB972C9FAC05B8246D8386674C11D5B2ADE4D8AD68B";
const int STRATEGY_CALENDAR_EXPECTED_ROWS = 451;
const int STRATEGY_CALENDAR_EXPECTED_ELIGIBLE_ROWS = 370;

datetime g_event_entry_utc[];
datetime g_event_exit_utc[];
string   g_event_family[];
bool     g_calendar_ready = false;
bool     g_xetra_calendar_ready = false;
datetime g_last_attempt_entry_utc = 0;
datetime g_active_exit_broker = 0;

bool IsExactNewYork0830(const datetime event_utc)
  {
   const int offset_hours = QM_IsUSDSTUTC(event_utc) ? -4 : -5;
   const datetime ny_local = event_utc + offset_hours * 60 * 60;
   MqlDateTime parts;
   if(!TimeToStruct(ny_local, parts))
      return false;
   return (parts.hour == 8 && parts.min == 30 && parts.sec == 0);
  }

datetime UtcDateTime(const int year,
                     const int month,
                     const int day,
                     const int hour,
                     const int minute)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = year;
   parts.mon = month;
   parts.day = day;
   parts.hour = hour;
   parts.min = minute;
   return StructToTime(parts);
  }

datetime LastSundayUtc(const int year, const int month, const int hour)
  {
   const int next_year = (month == 12) ? year + 1 : year;
   const int next_month = (month == 12) ? 1 : month + 1;
   const datetime last_day = UtcDateTime(next_year, next_month, 1, 0, 0) - 24 * 60 * 60;
   MqlDateTime parts;
   if(!TimeToStruct(last_day, parts))
      return 0;
   return last_day - parts.day_of_week * 24 * 60 * 60 + hour * 60 * 60;
  }

bool IsEuropeDSTUtc(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   const datetime starts = LastSundayUtc(parts.year, 3, 1);
   const datetime ends = LastSundayUtc(parts.year, 10, 1);
   return (utc >= starts && utc < ends);
  }

datetime Berlin1720Utc(const datetime event_utc)
  {
   MqlDateTime event_parts;
   ZeroMemory(event_parts);
   if(event_utc <= 0 || !TimeToStruct(event_utc, event_parts))
      return 0;
   datetime exit_utc = UtcDateTime(event_parts.year,
                                   event_parts.mon,
                                   event_parts.day,
                                   16,
                                   20);
   if(IsEuropeDSTUtc(exit_utc))
      exit_utc -= 60 * 60;
   return (exit_utc > event_utc + 5 * 60 ? exit_utc : 0);
  }

bool ResolveEventExitUtc(const datetime event_utc,
                         datetime &exit_utc,
                         bool &exchange_excluded,
                         string &exchange_session)
  {
   exit_utc = 0;
   exchange_excluded = false;
   exchange_session = "NOT_APPLICABLE";
   if(_Symbol != "GDAXI.DWX")
     {
      exit_utc = Berlin1720Utc(event_utc);
      return (exit_utc > event_utc + 5 * 60);
     }

   if(!g_xetra_calendar_ready)
      return false;
   const int date_key = QM_XetraCashBerlinDateKeyFromUTC(event_utc);
   const QM_XetraCashSessionType session_type =
      QM_XetraCashCalendarClassify(date_key);
   exchange_session = QM_XetraCashSessionTypeName(session_type);
   if(session_type == QM_XETRA_CASH_FULL_CLOSE)
     {
      exchange_excluded = true;
      return true;
     }
   if(session_type != QM_XETRA_CASH_NORMAL &&
      session_type != QM_XETRA_CASH_EARLY_CLOSE)
      return false;

   const int exit_hour =
      (session_type == QM_XETRA_CASH_EARLY_CLOSE ? 14 : 17);
   const int exit_minute =
      (session_type == QM_XETRA_CASH_EARLY_CLOSE ? 0 : 20);
   if(!QM_XetraCashBerlinLocalToUTC(date_key,
                                    exit_hour,
                                    exit_minute,
                                    exit_utc))
      return false;
   if(exit_utc <= event_utc + 5 * 60)
     {
      exchange_excluded = true;
      exit_utc = 0;
     }
   return true;
  }

string EligibleFamilyForName(const string raw_name)
  {
   const string event_name = QM_NewsUpper(QM_NewsStripQuotes(raw_name));
   if(event_name == "NON-FARM EMPLOYMENT CHANGE" || event_name == "NONFARM PAYROLLS")
      return "NONFARM_PAYROLLS";
   if(event_name == "CPI M/M")
      return "CPI";
   if(event_name == "PPI M/M")
      return "PPI";
   return "";
  }

bool CalendarHashMatches()
  {
   uchar bytes[];
   datetime modified_utc = 0;
   if(!QM_NewsReadFileBytes(STRATEGY_CALENDAR_PATH, bytes, modified_utc))
      return false;
   string actual_hash = "";
   if(!QM_NewsHashBytes(bytes, actual_hash))
      return false;
   StringToUpper(actual_hash);
   return (actual_hash == STRATEGY_CALENDAR_SHA256);
  }

bool AppendEvent(const datetime entry_utc,
                 const datetime exit_utc,
                 const string family)
  {
   const int n = ArraySize(g_event_entry_utc);
   if(n > 0 && g_event_entry_utc[n - 1] >= entry_utc)
      return false;
   if(ArrayResize(g_event_entry_utc, n + 1) != n + 1 ||
       ArrayResize(g_event_exit_utc, n + 1) != n + 1 ||
       ArrayResize(g_event_family, n + 1) != n + 1)
      return false;
   g_event_entry_utc[n] = entry_utc;
   g_event_exit_utc[n] = exit_utc;
   g_event_family[n] = family;
   return true;
  }

bool LoadEventCalendar()
  {
   ArrayResize(g_event_entry_utc, 0);
   ArrayResize(g_event_exit_utc, 0);
   ArrayResize(g_event_family, 0);
   if(!CalendarHashMatches())
      return false;

   // Keep the load order identical to QM_NewsReadFileBytes so the bytes that
   // passed the SHA-256 check are also the bytes parsed below.
   int handle = FileOpen(STRATEGY_CALENDAR_PATH,
                         FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
                         ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(STRATEGY_CALENDAR_PATH,
                        FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON,
                        ',');
   if(handle == INVALID_HANDLE)
      return false;

   int parsed_rows = 0;
   int eligible_rows = 0;
   int exchange_excluded_rows = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string event_text = FileReadString(handle);
      if(FileIsEnding(handle) && StringLen(event_text) == 0)
         break;
      const string currency = FileReadString(handle);
      const string event_name = FileReadString(handle);
      FileReadString(handle); // impact; schedule-only strategy never reads values.
      while(!FileIsEnding(handle) && !FileIsLineEnding(handle))
         FileReadString(handle);

      if(QM_NewsUpper(QM_NewsStripQuotes(event_text)) == "DATETIME")
         continue;
      if(StringLen(QM_NewsTrim(event_text)) == 0)
         continue;

      datetime event_utc = 0;
      if(QM_NewsUpper(QM_NewsStripQuotes(currency)) != "USD" ||
         !QM_NewsParseDateTimeUTC(event_text, event_utc) || event_utc <= 0)
        {
         valid = false;
         break;
        }
      ++parsed_rows;

      const string family = EligibleFamilyForName(event_name);
      if(family == "")
         continue; // FOMC is present for QM5_20023 but forbidden by this card.

      datetime exit_utc = 0;
      bool exchange_excluded = false;
      string exchange_session = "";
      if(!IsExactNewYork0830(event_utc) ||
         !ResolveEventExitUtc(event_utc,
                              exit_utc,
                              exchange_excluded,
                              exchange_session))
        {
         valid = false;
         break;
        }
      ++eligible_rows;
      if(exchange_excluded)
        {
         ++exchange_excluded_rows;
         continue;
        }
      if(exit_utc <= 0 ||
         !AppendEvent(event_utc + 5 * 60, exit_utc, family))
        {
         valid = false;
         break;
        }
     }
   FileClose(handle);

   if(!valid || parsed_rows != STRATEGY_CALENDAR_EXPECTED_ROWS ||
      eligible_rows != STRATEGY_CALENDAR_EXPECTED_ELIGIBLE_ROWS ||
      ArraySize(g_event_entry_utc) + exchange_excluded_rows !=
         STRATEGY_CALENDAR_EXPECTED_ELIGIBLE_ROWS)
      return false;

   QM_LogEvent(QM_INFO,
               "STRATEGY_CALENDAR_LOADED",
               StringFormat("{\"file\":\"%s\",\"sha256\":\"%s\",\"provenance_sha256\":\"%s\",\"source_rows\":%d,\"eligible_rows\":%d,\"admitted_rows\":%d,\"exchange_excluded_rows\":%d,\"families\":\"NFP,CPI,PPI\"}",
                            STRATEGY_CALENDAR_PATH,
                            STRATEGY_CALENDAR_SHA256,
                            STRATEGY_PROVENANCE_SHA256,
                            parsed_rows,
                            eligible_rows,
                            ArraySize(g_event_entry_utc),
                            exchange_excluded_rows));
   QM_LogEvent(QM_WARN,
               "STRATEGY_CALENDAR_COVERAGE_GAP",
               StringFormat("{\"missing_families\":\"GDP,RETAIL_SALES,PERSONAL_INCOME_PCE,DURABLE_GOODS,BUSINESS_INVENTORIES,TRADE_BALANCE,HOUSING_STARTS,LEADING_INDICATORS,INITIAL_CLAIMS\",\"available_through\":\"2025-04-04\",\"required_through\":\"2025-12-31\",\"issuer_ledger_complete\":false,\"xetra_calendar\":\"%s\"}",
                            _Symbol == "GDAXI.DWX"
                            ? (g_xetra_calendar_ready ? "ready" : "unavailable")
                            : "not_required"));
   return true;
  }

int LowerBoundEntry(const datetime target_utc)
  {
   int lo = 0;
   int hi = ArraySize(g_event_entry_utc);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_event_entry_utc[mid] < target_utc)
         lo = mid + 1;
      else
         hi = mid;
     }
   return lo;
  }

int FindEventAtEntry(const datetime entry_utc)
  {
   const int i = LowerBoundEntry(entry_utc);
   if(i < ArraySize(g_event_entry_utc) && g_event_entry_utc[i] == entry_utc)
      return i;
   return -1;
  }

bool IsRoutedSymbol(const string symbol)
  {
   return (symbol == "GDAXI.DWX" || symbol == "SP500.DWX");
  }

int ExpectedSlotForSymbol(const string symbol)
  {
   if(symbol == "GDAXI.DWX")
      return 0;
   if(symbol == "SP500.DWX")
      return 1;
   return -1;
  }

bool FindOurPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int FindEventForOpenPosition(const datetime open_utc)
  {
   int i = LowerBoundEntry(open_utc + 1) - 1;
   while(i >= 0 && open_utc - g_event_entry_utc[i] <= 10 * 60)
     {
      if(open_utc >= g_event_entry_utc[i])
         return i;
      --i;
     }
   return -1;
  }

int DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime FallbackBerlinExitBroker(const int date_key)
  {
   if(_Symbol == "GDAXI.DWX" && g_xetra_calendar_ready)
     {
      const QM_XetraCashSessionType session_type =
         QM_XetraCashCalendarClassify(date_key);
      if(session_type == QM_XETRA_CASH_NORMAL ||
         session_type == QM_XETRA_CASH_EARLY_CLOSE)
        {
         datetime exit_utc = 0;
         const int exit_hour =
            (session_type == QM_XETRA_CASH_EARLY_CLOSE ? 14 : 17);
         const int exit_minute =
            (session_type == QM_XETRA_CASH_EARLY_CLOSE ? 0 : 20);
         if(QM_XetraCashBerlinLocalToUTC(date_key,
                                         exit_hour,
                                         exit_minute,
                                         exit_utc))
            return QM_UTCToBroker(exit_utc);
        }
     }
   const int year = date_key / 10000;
   const int month = (date_key / 100) % 100;
   const int day = date_key % 100;
   datetime standard_utc = UtcDateTime(year, month, day, 16, 20);
   if(IsEuropeDSTUtc(standard_utc))
      standard_utc -= 60 * 60;
   return QM_UTCToBroker(standard_utc);
  }

bool PreReleaseStructure(const datetime event_utc,
                         double &pre_high,
                         double &pre_low,
                         double &release_close)
  {
   pre_high = -DBL_MAX;
   pre_low = DBL_MAX;
   release_close = 0.0;
   const datetime release_bar = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: exact event-bar alignment behind the framework new-bar gate.
   if(release_bar <= 0 || QM_BrokerToUTC(release_bar) != event_utc)
      return false;
   release_close = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: card-authorized completed 08:30 release-bar close.
   if(release_close <= 0.0)
      return false;

   for(int shift = 2; shift <= 4; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, strategy_signal_tf, shift); // perf-allowed: fixed three-bar pre-release structure, evaluated once per event.
      if(bar_time <= 0 || QM_BrokerToUTC(bar_time) != event_utc - (shift - 1) * 5 * 60)
         return false;
      const double bar_high = iHigh(_Symbol, strategy_signal_tf, shift); // perf-allowed: fixed three-bar pre-release high.
      const double bar_low = iLow(_Symbol, strategy_signal_tf, shift); // perf-allowed: fixed three-bar pre-release low.
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high < bar_low)
         return false;
      pre_high = MathMax(pre_high, bar_high);
      pre_low = MathMin(pre_low, bar_low);
     }
   return (pre_high > pre_low && MathIsValidNumber(pre_high) && MathIsValidNumber(pre_low));
  }

double CommissionPerLotUsd(const string symbol)
  {
   if(symbol == "SP500.DWX")
      return 5.50;
   if(symbol == "GDAXI.DWX")
     {
      const double eurusd_bid = SymbolInfoDouble("EURUSD.DWX", SYMBOL_BID);
      const double eurusd_ask = SymbolInfoDouble("EURUSD.DWX", SYMBOL_ASK);
      if(eurusd_bid <= 0.0 || eurusd_ask <= 0.0 || eurusd_ask < eurusd_bid)
         return 0.0;
      return 5.50 * 0.5 * (eurusd_bid + eurusd_ask);
     }
   return 0.0;
  }

bool CostAndVolumeAllow(const double entry_price, const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double commission_per_lot = CommissionPerLotUsd(_Symbol);
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" ||
      point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid || commission_per_lot <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   const double spread_per_lot = ((ask - bid) / tick_size) * tick_value;
   if(risk_per_lot <= 0.0 ||
      (commission_per_lot + spread_per_lot) / risk_per_lot > strategy_max_cost_r)
      return false;

   const double sl_points = stop_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || sl_points < (double)stop_level)
      return false;

   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      lots < volume_min || lots > volume_max)
      return false;
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   return (MathAbs(aligned - lots) <= volume_step * 1.0e-6);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

void LogEntryRejected(const int event_index,
                      const string reason,
                      const string context = "")
  {
   if(event_index < 0 || event_index >= ArraySize(g_event_entry_utc))
      return;
   QM_LogEvent(QM_INFO,
               "ENTRY_REJECTED",
               StringFormat("{\"event_family\":\"%s\",\"event_utc\":\"%s\",\"reason\":\"%s\",\"context\":\"%s\"}",
                            QM_LoggerEscapeJson(g_event_family[event_index]),
                            TimeToString(g_event_entry_utc[event_index] - 5 * 60,
                                         TIME_DATE | TIME_MINUTES),
                            QM_LoggerEscapeJson(reason),
                            QM_LoggerEscapeJson(context)));
  }

bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(FindOurPosition(open_time))
      return false;
   if(!IsRoutedSymbol(_Symbol) ||
      qm_magic_slot_offset != ExpectedSlotForSymbol(_Symbol) ||
      _Period != strategy_signal_tf)
      return true;
   return !g_calendar_ready;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_calendar_ready || !IsRoutedSymbol(_Symbol) ||
      qm_magic_slot_offset != ExpectedSlotForSymbol(_Symbol) ||
      _Period != strategy_signal_tf ||
      strategy_pre_release_bars != 3 || strategy_max_cost_r != 0.10)
      return false;
   const datetime current_bar = iTime(_Symbol, strategy_signal_tf, 0); // perf-allowed: exact 08:35 ET entry-bar match behind QM_IsNewBar.
   if(current_bar <= 0)
      return false;
   const datetime entry_utc = QM_BrokerToUTC(current_bar);
   if(entry_utc == g_last_attempt_entry_utc)
      return false;
   const int event_index = FindEventAtEntry(entry_utc);
   if(event_index < 0)
      return false;

   // Consume this exact 08:35 candidate before every downstream prerequisite.
   // A failed bar/cost/order check may not re-arm the same event package.
   g_last_attempt_entry_utc = entry_utc;

   double pre_high = 0.0;
   double pre_low = 0.0;
   double release_close = 0.0;
   if(!PreReleaseStructure(entry_utc - 5 * 60, pre_high, pre_low, release_close))
     {
      LogEntryRejected(event_index, "pre_release_or_release_bar_invalid");
      return false;
     }
   const bool buy = (release_close > pre_high);
   const bool sell = (release_close < pre_low);
   if(!buy && !sell)
     {
      LogEntryRejected(event_index,
                       "release_close_inside_pre_range",
                       StringFormat("pre_high=%.8f;pre_low=%.8f;release_close=%.8f",
                                    pre_high, pre_low, release_close));
      return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
     {
      LogEntryRejected(event_index, "tradable_quote_unavailable");
      return false;
     }
   const double entry_price = buy ? ask : bid;
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol, buy ? pre_low : pre_high);
   if(stop_price <= 0.0 ||
       (buy && stop_price >= entry_price) ||
       (sell && stop_price <= entry_price))
     {
      LogEntryRejected(event_index,
                       "opposite_range_stop_invalid",
                       StringFormat("entry=%.8f;stop=%.8f", entry_price, stop_price));
      return false;
     }
   if(!CostAndVolumeAllow(entry_price, stop_price))
     {
      LogEntryRejected(event_index, "cost_or_volume_gate_rejected");
      return false;
     }

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.reason = buy ? "MACRO0830_FIRST_BAR_LONG" : "MACRO0830_FIRST_BAR_SHORT";
   g_active_exit_broker = QM_UTCToBroker(g_event_exit_utc[event_index]);
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"event_family\":\"%s\",\"event_utc\":\"%s\",\"direction\":\"%s\",\"pre_high\":%.8f,\"pre_low\":%.8f,\"release_close\":%.8f,\"stop\":%.8f,\"exit_utc\":\"%s\"}",
                            QM_LoggerEscapeJson(g_event_family[event_index]),
                            TimeToString(entry_utc - 5 * 60, TIME_DATE | TIME_MINUTES),
                            buy ? "LONG" : "SHORT",
                            pre_high,
                            pre_low,
                            release_close,
                            stop_price,
                            TimeToString(g_event_exit_utc[event_index],
                                         TIME_DATE | TIME_MINUTES)));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      g_active_exit_broker = 0;
  }

bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      return false;
   if(g_active_exit_broker <= 0)
     {
      const datetime open_utc = QM_BrokerToUTC(open_time);
      const int event_index = g_calendar_ready ? FindEventForOpenPosition(open_utc) : -1;
      if(event_index >= 0)
         g_active_exit_broker = QM_UTCToBroker(g_event_exit_utc[event_index]);
      else
        {
         const int exit_date_key = (_Symbol == "GDAXI.DWX")
                                   ? QM_XetraCashBerlinDateKeyFromUTC(open_utc)
                                   : DateKey(open_utc);
         g_active_exit_broker = FallbackBerlinExitBroker(exit_date_key);
        }
     }
   return (g_active_exit_broker > 0 && TimeCurrent() >= g_active_exit_broker);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Only the immutable event ledger can create an entry; no generic news gate is added.
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — retained from framework/templates/EA_Skeleton.mq5.
// -----------------------------------------------------------------------------

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

   // Only the two order routes belong in the symbol guard.  EURUSD is a
   // conditional conversion input for GDAXI commission estimates; forcing it
   // into every basket warmup made the independent SP500 route fail before
   // OnInit completed whenever EURUSD history was unavailable.
   string allowed_symbols[2] = {"GDAXI.DWX", "SP500.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   string warmup_symbols[1] = {_Symbol};
   QM_BasketWarmupHistory(warmup_symbols, strategy_signal_tf, 16);

   const bool xetra_calendar_required = (_Symbol == "GDAXI.DWX");
   g_xetra_calendar_ready =
      (!xetra_calendar_required ||
       QM_XetraCashCalendarLoad(QM_XETRA_CASH_CALENDAR_RUNTIME_FILE,
                                QM_XETRA_CASH_CALENDAR_RUNTIME_SHA256));
   QM_LogEvent(g_xetra_calendar_ready ? QM_INFO : QM_ERROR,
               "XETRA_CASH_CALENDAR_STATE",
               StringFormat("{\"required\":%s,\"ready\":%s,\"file\":\"%s\",\"expected_sha256\":\"%s\",\"actual_sha256\":\"%s\",\"manifest_sha256\":\"%s\",\"error\":\"%s\"}",
                            xetra_calendar_required ? "true" : "false",
                            g_xetra_calendar_ready ? "true" : "false",
                            QM_LoggerEscapeJson(QM_XETRA_CASH_CALENDAR_RUNTIME_FILE),
                            QM_XETRA_CASH_CALENDAR_RUNTIME_SHA256,
                            QM_XetraCashCalendarActualSha256(),
                            QM_XETRA_CASH_CALENDAR_MANIFEST_SHA256,
                            QM_LoggerEscapeJson(QM_XetraCashCalendarLastError())));

   g_calendar_ready = LoadEventCalendar();
   if(!g_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"component\":\"macro0830_strategy_calendar\",\"file\":\"%s\",\"expected_sha256\":\"%s\"}",
                               STRATEGY_CALENDAR_PATH,
                               STRATEGY_CALENDAR_SHA256));

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"calendar_ready\":%s,\"eligible_events\":%d,\"route_slot\":%d,\"issuer_ledger_complete\":false,\"xetra_calendar_ready\":%s}",
                            g_calendar_ready ? "true" : "false",
                            ArraySize(g_event_entry_utc),
                            ExpectedSlotForSymbol(_Symbol),
                            g_xetra_calendar_ready ? "true" : "false"));
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
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
