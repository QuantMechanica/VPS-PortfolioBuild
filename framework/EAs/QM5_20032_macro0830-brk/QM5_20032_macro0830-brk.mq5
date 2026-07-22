#property strict
#property version   "5.0"
#property description "QM5_20032 scheduled 08:30 ET macro breakout"

#include <QM/QM_Common.mqh>

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
input string strategy_event_ledger_file   = "QM5_20032_macro0830_events.csv";
input string strategy_calendar_valid_through = "2025.12.31";

datetime g_event_entry_utc[];
datetime g_event_exit_utc[];
bool     g_event_entry_allowed[];
bool     g_calendar_ready = false;
datetime g_last_attempt_entry_utc = 0;
datetime g_active_exit_broker = 0;

string Trimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

bool IsSha256(const string value)
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

bool ParseBoolean(const string value, bool &parsed)
  {
   if(value == "1" || value == "true" || value == "TRUE")
     {
      parsed = true;
      return true;
     }
   if(value == "0" || value == "false" || value == "FALSE")
     {
      parsed = false;
      return true;
     }
   return false;
  }

datetime ParseUtcTimestamp(string value)
  {
   value = Trimmed(value);
   const int n = StringLen(value);
   if(n < 2 || StringSubstr(value, n - 1, 1) != "Z")
      return 0;
   value = StringSubstr(value, 0, n - 1);
   StringReplace(value, "-", ".");
   StringReplace(value, "T", " ");
   return StringToTime(value);
  }

bool IsEligibleFamily(const string family)
  {
   return (family == "GDP" ||
           family == "NONFARM_PAYROLLS" ||
           family == "RETAIL_SALES" ||
           family == "PERSONAL_INCOME_PCE" ||
           family == "DURABLE_GOODS" ||
           family == "BUSINESS_INVENTORIES" ||
           family == "TRADE_BALANCE" ||
           family == "PPI" ||
           family == "CPI" ||
           family == "HOUSING_STARTS" ||
           family == "LEADING_INDICATORS" ||
           family == "INITIAL_CLAIMS");
  }

bool ValidIssuerUrl(const string url)
  {
   if(StringFind(url, "https") != 0 || StringFind(url, "://") <= 0)
      return false;
   return (StringFind(url, "bls.gov") > 0 ||
           StringFind(url, "bea.gov") > 0 ||
           StringFind(url, "census.gov") > 0 ||
           StringFind(url, "dol.gov") > 0 ||
           StringFind(url, "conference-board.org") > 0 ||
           StringFind(url, "commerce.gov") > 0);
  }

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

bool ValidateBerlinExit(const datetime event_utc,
                        const datetime exit_utc,
                        const string exit_kind)
  {
   if(exit_utc <= event_utc + 5 * 60)
      return false;
   const int offset_hours = IsEuropeDSTUtc(exit_utc) ? 2 : 1;
   const datetime berlin_local = exit_utc + offset_hours * 60 * 60;
   MqlDateTime event_parts;
   MqlDateTime exit_parts;
   if(!TimeToStruct(event_utc, event_parts) || !TimeToStruct(berlin_local, exit_parts))
      return false;
   if(event_parts.year != exit_parts.year || event_parts.mon != exit_parts.mon ||
      event_parts.day != exit_parts.day)
      return false;
   const int exit_minute = exit_parts.hour * 60 + exit_parts.min;
   if(exit_kind == "normal")
      return (exit_minute == 17 * 60 + 20 && exit_parts.sec == 0);
   if(exit_kind == "early")
      return (exit_minute > 0 && exit_minute < 17 * 60 + 20 && exit_parts.sec == 0);
   return false;
  }

bool AppendOrMergeEvent(const datetime entry_utc,
                        const datetime exit_utc,
                        const bool entry_allowed)
  {
   const int n = ArraySize(g_event_entry_utc);
   if(n > 0 && g_event_entry_utc[n - 1] == entry_utc)
      return (g_event_exit_utc[n - 1] == exit_utc &&
              g_event_entry_allowed[n - 1] == entry_allowed);
   if(n > 0 && g_event_entry_utc[n - 1] > entry_utc)
      return false;
   if(ArrayResize(g_event_entry_utc, n + 1) != n + 1 ||
      ArrayResize(g_event_exit_utc, n + 1) != n + 1 ||
      ArrayResize(g_event_entry_allowed, n + 1) != n + 1)
      return false;
   g_event_entry_utc[n] = entry_utc;
   g_event_exit_utc[n] = exit_utc;
   g_event_entry_allowed[n] = entry_allowed;
   return true;
  }

bool LoadEventCalendar()
  {
   ArrayResize(g_event_entry_utc, 0);
   ArrayResize(g_event_exit_utc, 0);
   ArrayResize(g_event_entry_allowed, 0);
   if(strategy_calendar_valid_through != "2025.12.31")
      return false;

   const int handle = FileOpen(strategy_event_ledger_file,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   int rows = 0;
   int earliest_year = 9999;
   int latest_year = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string family = Trimmed(FileReadString(handle));
      const string event_text = Trimmed(FileReadString(handle));
      const string allowed_text = Trimmed(FileReadString(handle));
      const string exit_text = Trimmed(FileReadString(handle));
      const string exit_kind = Trimmed(FileReadString(handle));
      const string source_url = Trimmed(FileReadString(handle));
      string retrieved_date = Trimmed(FileReadString(handle));
      const string source_sha256 = Trimmed(FileReadString(handle));

      if(rows == 0 && family == "event_family" && event_text == "event_utc")
         continue;
      if(family == "" && event_text == "" && exit_text == "")
         continue;

      bool entry_allowed = false;
      StringReplace(retrieved_date, "-", ".");
      const datetime event_utc = ParseUtcTimestamp(event_text);
      const datetime exit_utc = ParseUtcTimestamp(exit_text);
      if(!IsEligibleFamily(family) || event_utc <= 0 ||
         !IsExactNewYork0830(event_utc) ||
         !ParseBoolean(allowed_text, entry_allowed) ||
         !ValidateBerlinExit(event_utc, exit_utc, exit_kind) ||
         !ValidIssuerUrl(source_url) || StringToTime(retrieved_date) <= 0 ||
         !IsSha256(source_sha256) ||
         !AppendOrMergeEvent(event_utc + 5 * 60, exit_utc, entry_allowed))
        {
         valid = false;
         break;
        }

      MqlDateTime event_parts;
      if(!TimeToStruct(event_utc, event_parts))
        {
         valid = false;
         break;
        }
      earliest_year = MathMin(earliest_year, event_parts.year);
      latest_year = MathMax(latest_year, event_parts.year);
      ++rows;
     }
   FileClose(handle);

   return (valid && rows > 0 && ArraySize(g_event_entry_utc) > 0 &&
           earliest_year <= 2018 && latest_year >= 2025);
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

bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(FindOurPosition(open_time))
      return false;
   if(!IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf)
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

   if(!g_calendar_ready || !IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      strategy_pre_release_bars != 3 || strategy_max_cost_r != 0.10)
      return false;
   const datetime current_bar = iTime(_Symbol, strategy_signal_tf, 0); // perf-allowed: exact 08:35 ET entry-bar match behind QM_IsNewBar.
   if(current_bar <= 0)
      return false;
   const datetime entry_utc = QM_BrokerToUTC(current_bar);
   if(entry_utc == g_last_attempt_entry_utc)
      return false;
   const int event_index = FindEventAtEntry(entry_utc);
   if(event_index < 0 || !g_event_entry_allowed[event_index])
      return false;

   double pre_high = 0.0;
   double pre_low = 0.0;
   double release_close = 0.0;
   if(!PreReleaseStructure(entry_utc - 5 * 60, pre_high, pre_low, release_close))
      return false;
   const bool buy = (release_close > pre_high);
   const bool sell = (release_close < pre_low);
   if(!buy && !sell)
      return false;

   g_last_attempt_entry_utc = entry_utc;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double entry_price = buy ? ask : bid;
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol, buy ? pre_low : pre_high);
   if(stop_price <= 0.0 ||
      (buy && stop_price >= entry_price) ||
      (sell && stop_price <= entry_price) ||
      !CostAndVolumeAllow(entry_price, stop_price))
      return false;

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.reason = buy ? "MACRO0830_FIRST_BAR_LONG" : "MACRO0830_FIRST_BAR_SHORT";
   g_active_exit_broker = QM_UTCToBroker(g_event_exit_utc[event_index]);
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
         g_active_exit_broker = FallbackBerlinExitBroker(DateKey(open_utc));
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

   string allowed_symbols[3] = {"GDAXI.DWX", "SP500.DWX", "EURUSD.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   QM_BasketWarmupHistory(allowed_symbols, strategy_signal_tf, 16);

   g_calendar_ready = LoadEventCalendar();
   if(!g_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"event_ledger\":\"%s\"}", strategy_event_ledger_file));

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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

