#property strict
#property version   "5.0"
#property description "QM5_20034 WMR post-fix reversal fade"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20034_wmr-postfix, G0 APPROVED 2026-07-22.
// London business dates and exact UTC fix endpoints come from a governed ledger.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20034;
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
input int    strategy_median_days         = 20;
input double strategy_displacement_mult   = 1.50;
input double strategy_max_cost_r          = 0.10;
input string strategy_fix_ledger_file     = "QM5_20034_wmr_fix_calendar.csv";
input string strategy_calendar_valid_through = "2025.12.31";

int      g_fix_date_key[];
datetime g_fix_day_start_utc[];
datetime g_fix_p0_cutoff_utc[];
datetime g_fix_p1_cutoff_utc[];
datetime g_fix_entry_utc[];
datetime g_fix_exit_utc[];
bool     g_fix_entry_allowed[];
bool     g_calendar_ready = false;

double   g_prior_displacements[];
bool     g_history_initialized = false;
datetime g_last_processed_entry_utc = 0;
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

bool IsUKDSTUtc(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   const datetime starts = LastSundayUtc(parts.year, 3, 1);
   const datetime ends = LastSundayUtc(parts.year, 10, 1);
   return (utc >= starts && utc < ends);
  }

datetime LondonLocal(const datetime utc)
  {
   return utc + (IsUKDSTUtc(utc) ? 60 * 60 : 0);
  }

int DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int ParseDateKey(string value)
  {
   value = Trimmed(value);
   StringReplace(value, "-", ".");
   return DateKey(StringToTime(value + " 00:00"));
  }

bool LondonClockMatches(const datetime utc,
                        const int date_key,
                        const int hour,
                        const int minute,
                        const int second)
  {
   const datetime local = LondonLocal(utc);
   MqlDateTime parts;
   if(!TimeToStruct(local, parts))
      return false;
   return (DateKey(local) == date_key && parts.hour == hour &&
           parts.min == minute && parts.sec == second);
  }

bool ValidCalendarSource(const string url)
  {
   if(StringFind(url, "https") != 0 || StringFind(url, "://") <= 0)
      return false;
   return (StringFind(url, "gov.uk") > 0 ||
           StringFind(url, "iana.org") > 0 ||
           StringFind(url, "lseg.com") > 0 ||
           StringFind(url, "wmcompany.com") > 0 ||
           StringFind(url, "fca.org.uk") > 0);
  }

bool AppendFixDate(const int date_key,
                   const datetime day_start_utc,
                   const datetime p0_cutoff_utc,
                   const datetime p1_cutoff_utc,
                   const datetime entry_utc,
                   const datetime exit_utc,
                   const bool entry_allowed)
  {
   const int n = ArraySize(g_fix_entry_utc);
   if(ArrayResize(g_fix_date_key, n + 1) != n + 1 ||
      ArrayResize(g_fix_day_start_utc, n + 1) != n + 1 ||
      ArrayResize(g_fix_p0_cutoff_utc, n + 1) != n + 1 ||
      ArrayResize(g_fix_p1_cutoff_utc, n + 1) != n + 1 ||
      ArrayResize(g_fix_entry_utc, n + 1) != n + 1 ||
      ArrayResize(g_fix_exit_utc, n + 1) != n + 1 ||
      ArrayResize(g_fix_entry_allowed, n + 1) != n + 1)
      return false;
   g_fix_date_key[n] = date_key;
   g_fix_day_start_utc[n] = day_start_utc;
   g_fix_p0_cutoff_utc[n] = p0_cutoff_utc;
   g_fix_p1_cutoff_utc[n] = p1_cutoff_utc;
   g_fix_entry_utc[n] = entry_utc;
   g_fix_exit_utc[n] = exit_utc;
   g_fix_entry_allowed[n] = entry_allowed;
   return true;
  }

bool LoadFixCalendar()
  {
   ArrayResize(g_fix_date_key, 0);
   ArrayResize(g_fix_day_start_utc, 0);
   ArrayResize(g_fix_p0_cutoff_utc, 0);
   ArrayResize(g_fix_p1_cutoff_utc, 0);
   ArrayResize(g_fix_entry_utc, 0);
   ArrayResize(g_fix_exit_utc, 0);
   ArrayResize(g_fix_entry_allowed, 0);
   if(strategy_calendar_valid_through != "2025.12.31")
      return false;

   const int handle = FileOpen(strategy_fix_ledger_file,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   int rows = 0;
   datetime previous_entry_utc = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string date_text = Trimmed(FileReadString(handle));
      const string day_start_text = Trimmed(FileReadString(handle));
      const string p0_text = Trimmed(FileReadString(handle));
      const string p1_text = Trimmed(FileReadString(handle));
      const string entry_text = Trimmed(FileReadString(handle));
      const string exit_text = Trimmed(FileReadString(handle));
      const string allowed_text = Trimmed(FileReadString(handle));
      const string source_url = Trimmed(FileReadString(handle));
      string retrieved_date = Trimmed(FileReadString(handle));
      const string source_sha256 = Trimmed(FileReadString(handle));

      if(rows == 0 && date_text == "london_date" && day_start_text == "day_start_utc")
         continue;
      if(date_text == "" && p0_text == "" && entry_text == "")
         continue;

      const int date_key = ParseDateKey(date_text);
      const datetime day_start_utc = ParseUtcTimestamp(day_start_text);
      const datetime p0_cutoff_utc = ParseUtcTimestamp(p0_text);
      const datetime p1_cutoff_utc = ParseUtcTimestamp(p1_text);
      const datetime entry_utc = ParseUtcTimestamp(entry_text);
      const datetime exit_utc = ParseUtcTimestamp(exit_text);
      bool entry_allowed = false;
      StringReplace(retrieved_date, "-", ".");
      if(date_key <= 0 || day_start_utc <= 0 || p0_cutoff_utc <= 0 ||
         p1_cutoff_utc <= 0 || entry_utc <= 0 || exit_utc <= 0 ||
         (previous_entry_utc > 0 && entry_utc <= previous_entry_utc) ||
         !LondonClockMatches(day_start_utc, date_key, 0, 0, 0) ||
         !LondonClockMatches(p0_cutoff_utc, date_key, 15, 57, 30) ||
         !LondonClockMatches(p1_cutoff_utc, date_key, 16, 2, 30) ||
         !LondonClockMatches(entry_utc, date_key, 16, 5, 0) ||
         !LondonClockMatches(exit_utc, date_key, 16, 30, 0) ||
         p1_cutoff_utc - p0_cutoff_utc != 5 * 60 ||
         entry_utc - p1_cutoff_utc != 150 ||
         exit_utc - entry_utc != 25 * 60 ||
         !ParseBoolean(allowed_text, entry_allowed) ||
         !ValidCalendarSource(source_url) || StringToTime(retrieved_date) <= 0 ||
         !IsSha256(source_sha256) ||
         !AppendFixDate(date_key, day_start_utc, p0_cutoff_utc, p1_cutoff_utc,
                        entry_utc, exit_utc, entry_allowed))
        {
         valid = false;
         break;
        }
      previous_entry_utc = entry_utc;
      ++rows;
     }
   FileClose(handle);

   return (valid && rows > 0 && g_fix_date_key[0] <= 20150215 &&
           g_fix_date_key[rows - 1] >= 20251231);
  }

int LowerBoundEntry(const datetime target_utc)
  {
   int lo = 0;
   int hi = ArraySize(g_fix_entry_utc);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_fix_entry_utc[mid] < target_utc)
         lo = mid + 1;
      else
         hi = mid;
     }
   return lo;
  }

int FindFixAtEntry(const datetime entry_utc)
  {
   const int i = LowerBoundEntry(entry_utc);
   if(i < ArraySize(g_fix_entry_utc) && g_fix_entry_utc[i] == entry_utc)
      return i;
   return -1;
  }

bool TickMid(const MqlTick &tick, double &mid)
  {
   mid = 0.0;
   if(tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      return false;
   mid = 0.5 * (tick.bid + tick.ask);
   return (mid > 0.0 && MathIsValidNumber(mid));
  }

bool LastValidMidInRange(const ulong from_msc,
                         const ulong to_msc,
                         double &mid,
                         ulong &mid_msc)
  {
   mid = 0.0;
   mid_msc = 0;
   if(to_msc < from_msc)
      return false;
   MqlTick ticks[];
   const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, from_msc, to_msc);
   if(copied <= 0)
      return false;
   long previous_msc = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
         return false;
      previous_msc = ticks[i].time_msc;
     }
   for(int i = copied - 1; i >= 0; --i)
     {
      double candidate = 0.0;
      if(TickMid(ticks[i], candidate))
        {
         mid = candidate;
         mid_msc = (ulong)ticks[i].time_msc;
         return true;
        }
     }
   return false;
  }

bool FindP0(const int fix_index, double &p0, ulong &p0_msc)
  {
   p0 = 0.0;
   p0_msc = 0;
   const ulong day_start_msc = (ulong)g_fix_day_start_utc[fix_index] * 1000;
   ulong chunk_end = (ulong)g_fix_p0_cutoff_utc[fix_index] * 1000;
   const ulong chunk_width = 5 * 60 * 1000;
   while(chunk_end >= day_start_msc)
     {
      const ulong chunk_start = (chunk_end - day_start_msc > chunk_width)
                                ? chunk_end - chunk_width
                                : day_start_msc;
      if(LastValidMidInRange(chunk_start, chunk_end, p0, p0_msc))
         return true;
      if(chunk_start == day_start_msc)
         break;
      chunk_end = chunk_start - 1;
     }
   return false;
  }

bool FixDisplacement(const int fix_index,
                     double &signed_displacement,
                     double &p0)
  {
   signed_displacement = 0.0;
   p0 = 0.0;
   if(fix_index < 0 || fix_index >= ArraySize(g_fix_entry_utc))
      return false;
   ulong p0_msc = 0;
   if(!FindP0(fix_index, p0, p0_msc))
      return false;

   double p1 = 0.0;
   ulong p1_msc = 0;
   const ulong p1_cutoff_msc = (ulong)g_fix_p1_cutoff_utc[fix_index] * 1000;
   if(p0_msc >= p1_cutoff_msc ||
      !LastValidMidInRange(p0_msc + 1, p1_cutoff_msc, p1, p1_msc) ||
      p1_msc <= p0_msc)
      return false;

   p0 = QM_TM_NormalizePrice(_Symbol, p0);
   p1 = QM_TM_NormalizePrice(_Symbol, p1);
   signed_displacement = p1 - p0;
   return (p0 > 0.0 && p1 > 0.0 && signed_displacement != 0.0 &&
           MathIsValidNumber(signed_displacement));
  }

void AddPriorDisplacement(const double absolute_displacement)
  {
   if(absolute_displacement <= 0.0 || !MathIsValidNumber(absolute_displacement))
      return;
   const int n = ArraySize(g_prior_displacements);
   if(n < strategy_median_days)
     {
      if(ArrayResize(g_prior_displacements, n + 1) == n + 1)
         g_prior_displacements[n] = absolute_displacement;
      return;
     }
   for(int i = 1; i < n; ++i)
      g_prior_displacements[i - 1] = g_prior_displacements[i];
   g_prior_displacements[n - 1] = absolute_displacement;
  }

bool InitializePriorHistory(const int current_fix_index)
  {
   if(g_history_initialized)
      return true;
   ArrayResize(g_prior_displacements, 0);
   double reverse_values[20];
   int found = 0;
   for(int i = current_fix_index - 1; i >= 0 && found < strategy_median_days; --i)
     {
      if(!g_fix_entry_allowed[i])
         continue;
      double displacement = 0.0;
      double prior_p0 = 0.0;
      if(!FixDisplacement(i, displacement, prior_p0))
         continue;
      reverse_values[found] = MathAbs(displacement);
      ++found;
     }
   for(int i = found - 1; i >= 0; --i)
      AddPriorDisplacement(reverse_values[i]);
   g_history_initialized = true;
   return true;
  }

double PriorMedian20()
  {
   if(ArraySize(g_prior_displacements) != strategy_median_days ||
      strategy_median_days != 20)
      return 0.0;
   double sorted[];
   if(ArrayResize(sorted, strategy_median_days) != strategy_median_days)
      return 0.0;
   for(int i = 0; i < strategy_median_days; ++i)
      sorted[i] = g_prior_displacements[i];
   ArraySort(sorted);
   return 0.5 * (sorted[9] + sorted[10]);
  }

bool IsRoutedSymbol(const string symbol)
  {
   return (symbol == "EURUSD.DWX" || symbol == "GBPUSD.DWX");
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

int FindFixForOpenPosition(const datetime open_utc)
  {
   int i = LowerBoundEntry(open_utc + 1) - 1;
   while(i >= 0 && open_utc - g_fix_entry_utc[i] <= 10 * 60)
     {
      if(open_utc >= g_fix_entry_utc[i])
         return i;
      --i;
     }
   return -1;
  }

datetime FallbackLondonExitBroker(const int london_date_key)
  {
   const int year = london_date_key / 10000;
   const int month = (london_date_key / 100) % 100;
   const int day = london_date_key % 100;
   datetime exit_utc = UtcDateTime(year, month, day, 16, 30);
   if(IsUKDSTUtc(exit_utc))
      exit_utc -= 60 * 60;
   return QM_UTCToBroker(exit_utc);
  }

double CommissionPerLotUsd(const string symbol)
  {
   if(symbol != "EURUSD.DWX" && symbol != "GBPUSD.DWX")
      return 0.0;
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
      return 0.0;
   return MathMax(5.0, 5.0 * 0.5 * (bid + ask));
  }

bool CostAndVolumeAllow(const double entry_price,
                        const double stop_price,
                        const double target_price)
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
   const double target_distance = MathAbs(entry_price - target_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   const double spread_per_lot = ((ask - bid) / tick_size) * tick_value;
   if(risk_per_lot <= 0.0 || target_distance <= 0.0 ||
      (commission_per_lot + spread_per_lot) / risk_per_lot > strategy_max_cost_r)
      return false;

   const double sl_points = stop_distance / point;
   const double tp_points = target_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || tp_points <= 0.0 ||
      sl_points < (double)stop_level || tp_points < (double)stop_level)
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
      strategy_median_days != 20 || strategy_displacement_mult != 1.50 ||
      strategy_max_cost_r != 0.10)
      return false;
   const datetime current_bar = iTime(_Symbol, strategy_signal_tf, 0); // perf-allowed: exact governed 16:05 London entry bar behind QM_IsNewBar.
   if(current_bar <= 0)
      return false;
   const datetime entry_utc = QM_BrokerToUTC(current_bar);
   if(entry_utc == g_last_processed_entry_utc)
      return false;
   const int fix_index = FindFixAtEntry(entry_utc);
   if(fix_index < 0)
      return false;
   g_last_processed_entry_utc = entry_utc;
   if(!g_fix_entry_allowed[fix_index] || !InitializePriorHistory(fix_index))
      return false;

   double displacement = 0.0;
   double p0 = 0.0;
   if(!FixDisplacement(fix_index, displacement, p0))
      return false;
   const double median20 = PriorMedian20();
   AddPriorDisplacement(MathAbs(displacement));
   if(median20 <= 0.0 || !MathIsValidNumber(median20) ||
      MathAbs(displacement) <= strategy_displacement_mult * median20)
      return false;

   const datetime confirmation_bar = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: exact completed 16:00-16:05 London confirmation bar.
   const double confirmation_close = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: card-authorized confirmation close.
   if(confirmation_bar <= 0 || QM_BrokerToUTC(confirmation_bar) != entry_utc - 5 * 60 ||
      confirmation_close <= 0.0)
      return false;

   const bool sell = (displacement > 0.0 && confirmation_close > p0);
   const bool buy = (displacement < 0.0 && confirmation_close < p0);
   if(!buy && !sell)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double entry_price = buy ? ask : bid;
   const double target_price = QM_StopRulesNormalizePrice(_Symbol, p0);
   const double stop_distance = MathAbs(displacement);
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol,
                                                         buy ? entry_price - stop_distance
                                                             : entry_price + stop_distance);
   if(stop_price <= 0.0 || target_price <= 0.0 ||
      (buy && !(stop_price < entry_price && entry_price < target_price)) ||
      (sell && !(target_price < entry_price && entry_price < stop_price)) ||
      !CostAndVolumeAllow(entry_price, stop_price, target_price))
      return false;

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.tp = target_price;
   req.reason = buy ? "WMR_POSTFIX_FADE_LONG" : "WMR_POSTFIX_FADE_SHORT";
   g_active_exit_broker = QM_UTCToBroker(g_fix_exit_utc[fix_index]);
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
      const int fix_index = g_calendar_ready ? FindFixForOpenPosition(open_utc) : -1;
      if(fix_index >= 0)
         g_active_exit_broker = QM_UTCToBroker(g_fix_exit_utc[fix_index]);
      else
         g_active_exit_broker = FallbackLondonExitBroker(DateKey(LondonLocal(open_utc)));
     }
   return (g_active_exit_broker > 0 && TimeCurrent() >= g_active_exit_broker);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The approved baseline applies no generic news or month-end filter.
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

   string allowed_symbols[2] = {"EURUSD.DWX", "GBPUSD.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   QM_BasketWarmupHistory(allowed_symbols, strategy_signal_tf, 8);

   g_calendar_ready = LoadFixCalendar();
   if(!g_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"fix_ledger\":\"%s\"}", strategy_fix_ledger_file));

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

