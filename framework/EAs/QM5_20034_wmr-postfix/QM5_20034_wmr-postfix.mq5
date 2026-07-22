#property strict
#property version   "5.0"
#property description "QM5_20034 WMR post-fix reversal fade"

#include <QM/QM_Common.mqh>
#include <QM/QM_LondonCalendars.mqh>

// Strategy Card: QM5_20034_wmr-postfix, G0 APPROVED 2026-07-22.
// WMR fixing-day eligibility comes only from the verified WMR service
// contract.  UK holidays and LSE cash sessions are not substitutes.

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
input int    strategy_p0_hour_london      = 15;
input int    strategy_p0_minute_london    = 57;
input int    strategy_p0_second_london    = 30;
input int    strategy_p1_hour_london      = 16;
input int    strategy_p1_minute_london    = 2;
input int    strategy_p1_second_london    = 30;
input int    strategy_entry_hour_london   = 16;
input int    strategy_entry_minute_london = 5;
input int    strategy_exit_hour_london    = 16;
input int    strategy_exit_minute_london  = 30;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points   = 0;

double   g_prior_displacements[];
bool     g_history_initialized = false;
datetime g_last_processed_entry_utc = 0;
datetime g_active_exit_broker = 0;

void LogStrategyEntryReject(const string detail,
                            const int london_date_key,
                            const datetime entry_utc,
                            const string diagnostics = "")
  {
   QM_LogEvent(QM_WARN,
               "ENTRY_REJECTED",
               StringFormat("{\"result\":\"STRATEGY_HOOK_REJECTED\",\"symbol\":\"%s\",\"reason\":\"WMR_POSTFIX\",\"detail\":\"%s\",\"london_date_key\":%d,\"entry_utc\":%I64d,\"broker_now\":%I64d%s}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            london_date_key,
                            (long)entry_utc,
                            (long)TimeCurrent(),
                            diagnostics));
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

datetime LondonDateTimeToUtc(const int date_key,
                             const int hour,
                             const int minute,
                             const int second)
  {
   if(date_key < 19000101 || hour < 0 || hour > 23 ||
      minute < 0 || minute > 59 || second < 0 || second > 59)
      return 0;
   const int year = date_key / 10000;
   const int month = (date_key / 100) % 100;
   const int day = date_key % 100;
   const datetime nominal = UtcDateTime(year, month, day, hour, minute) + second;
   return nominal - (IsUKDSTUtc(nominal) ? 60 * 60 : 0);
  }

bool IsUtcWeekday(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

int PreviousDateKey(const int date_key)
  {
   if(date_key < 19000102)
      return 0;
   const datetime noon = UtcDateTime(date_key / 10000,
                                     (date_key / 100) % 100,
                                     date_key % 100,
                                     12,
                                     0);
   return DateKey(noon - 24 * 60 * 60);
  }

bool ResolveFixTimes(const int london_date_key,
                     datetime &day_start_utc,
                     datetime &p0_cutoff_utc,
                     datetime &p1_cutoff_utc,
                     datetime &entry_utc,
                     datetime &exit_utc)
  {
   day_start_utc = LondonDateTimeToUtc(london_date_key, 0, 0, 0);
   p0_cutoff_utc = LondonDateTimeToUtc(london_date_key,
                                       strategy_p0_hour_london,
                                       strategy_p0_minute_london,
                                       strategy_p0_second_london);
   p1_cutoff_utc = LondonDateTimeToUtc(london_date_key,
                                       strategy_p1_hour_london,
                                       strategy_p1_minute_london,
                                       strategy_p1_second_london);
   entry_utc = LondonDateTimeToUtc(london_date_key,
                                   strategy_entry_hour_london,
                                   strategy_entry_minute_london,
                                   0);
   exit_utc = LondonDateTimeToUtc(london_date_key,
                                  strategy_exit_hour_london,
                                  strategy_exit_minute_london,
                                  0);
   return (day_start_utc > 0 && p0_cutoff_utc > day_start_utc &&
           p1_cutoff_utc - p0_cutoff_utc == 5 * 60 &&
           entry_utc - p1_cutoff_utc == 150 &&
           exit_utc - entry_utc == 25 * 60);
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

bool FindP0(const datetime day_start_utc,
            const datetime p0_cutoff_utc,
            double &p0,
            ulong &p0_msc)
  {
   p0 = 0.0;
   p0_msc = 0;
   if(day_start_utc <= 0 || p0_cutoff_utc <= day_start_utc)
      return false;
   const ulong day_start_msc = (ulong)day_start_utc * 1000;
   ulong chunk_end = (ulong)p0_cutoff_utc * 1000;
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

bool FixDisplacement(const datetime day_start_utc,
                     const datetime p0_cutoff_utc,
                     const datetime p1_cutoff_utc,
                     double &signed_displacement,
                     double &p0)
  {
   signed_displacement = 0.0;
   p0 = 0.0;
   ulong p0_msc = 0;
   if(!FindP0(day_start_utc, p0_cutoff_utc, p0, p0_msc))
      return false;

   double p1 = 0.0;
   ulong p1_msc = 0;
   const ulong p1_cutoff_msc = (ulong)p1_cutoff_utc * 1000;
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

bool InitializePriorHistory(const int current_london_date_key)
  {
   if(g_history_initialized)
      return true;
   ArrayResize(g_prior_displacements, 0);
   double reverse_values[20];
   int found = 0;
   int date_key = PreviousDateKey(current_london_date_key);
   for(int scanned = 0; date_key > 0 && scanned < 60 &&
       found < strategy_median_days; ++scanned)
     {
      datetime day_start_utc = 0;
      datetime p0_cutoff_utc = 0;
      datetime p1_cutoff_utc = 0;
      datetime entry_utc = 0;
      datetime exit_utc = 0;
       if(!ResolveFixTimes(date_key,
                           day_start_utc,
                           p0_cutoff_utc,
                           p1_cutoff_utc,
                           entry_utc,
                           exit_utc) ||
          !IsUtcWeekday(entry_utc) ||
          !QM_LondonWmr1600IsAvailable(
             QM_LondonWmr1600Classify(date_key)))
        {
         date_key = PreviousDateKey(date_key);
         continue;
        }
      double displacement = 0.0;
      double prior_p0 = 0.0;
      if(FixDisplacement(day_start_utc,
                         p0_cutoff_utc,
                         p1_cutoff_utc,
                         displacement,
                         prior_p0))
        {
         reverse_values[found] = MathAbs(displacement);
         ++found;
        }
      date_key = PreviousDateKey(date_key);
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

datetime FallbackLondonExitBroker(const int london_date_key)
  {
   const datetime exit_utc = LondonDateTimeToUtc(london_date_key,
                                                 strategy_exit_hour_london,
                                                 strategy_exit_minute_london,
                                                 0);
   return QM_UTCToBroker(exit_utc);
  }

bool TradeGeometryAndVolumeAllow(const double entry_price,
                                 const double stop_price,
                                 const double target_price,
                                 string &out_reject_detail)
  {
   out_reject_detail = "";
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0)
     {
      out_reject_detail = "invalid_symbol_risk_metadata";
      return false;
     }

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   if(risk_per_lot <= 0.0 || target_distance <= 0.0)
     {
      out_reject_detail = "non_positive_distance_or_risk";
      return false;
     }

   const double sl_points = stop_distance / point;
   const double tp_points = target_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || tp_points <= 0.0 ||
      sl_points < (double)stop_level || tp_points < (double)stop_level)
     {
      out_reject_detail = "broker_stop_level";
      return false;
     }

   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0)
     {
      out_reject_detail = "risk_sizing_unavailable";
      return false;
     }
   if(volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0)
     {
      out_reject_detail = "invalid_volume_metadata";
      return false;
     }
   if(lots < volume_min || lots > volume_max)
     {
      out_reject_detail = "sized_volume_out_of_range";
      return false;
     }
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   if(MathAbs(aligned - lots) > volume_step * 1.0e-6)
     {
      out_reject_detail = "sized_volume_step_misaligned";
      return false;
     }
   return true;
  }

bool Strategy_InputsValid()
  {
   return (strategy_signal_tf == PERIOD_M5 &&
           strategy_median_days == 20 &&
           strategy_displacement_mult == 1.50 &&
           strategy_p0_hour_london == 15 &&
           strategy_p0_minute_london == 57 &&
           strategy_p0_second_london == 30 &&
           strategy_p1_hour_london == 16 &&
           strategy_p1_minute_london == 2 &&
           strategy_p1_second_london == 30 &&
           strategy_entry_hour_london == 16 &&
           strategy_entry_minute_london == 5 &&
           strategy_exit_hour_london == 16 &&
           strategy_exit_minute_london == 30);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(FindOurPosition(open_time))
      return false;
   if(!IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      !Strategy_InputsValid() || !QM_LondonWmr1600CalendarReady())
      return true;
   return Strategy_WideSpread();
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

   if(!IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      !Strategy_InputsValid())
      return false;
   const datetime current_bar = iTime(_Symbol, strategy_signal_tf, 0); // perf-allowed: exact broker-clock 16:05 London entry bar behind QM_IsNewBar.
   if(current_bar <= 0)
      return false;
   const datetime entry_utc = QM_BrokerToUTC(current_bar);
   if(entry_utc == g_last_processed_entry_utc)
      return false;
   const int london_date_key = DateKey(LondonLocal(entry_utc));
   datetime day_start_utc = 0;
   datetime p0_cutoff_utc = 0;
   datetime p1_cutoff_utc = 0;
   datetime expected_entry_utc = 0;
   datetime exit_utc = 0;
    if(!ResolveFixTimes(london_date_key,
                       day_start_utc,
                       p0_cutoff_utc,
                       p1_cutoff_utc,
                       expected_entry_utc,
                       exit_utc) ||
      entry_utc != expected_entry_utc ||
       !IsUtcWeekday(entry_utc))
       return false;
    g_last_processed_entry_utc = entry_utc;

    const QM_LondonWmr1600Status wmr_status =
       QM_LondonWmr1600Classify(london_date_key);
    if(!QM_LondonWmr1600IsAvailable(wmr_status))
      {
       const string calendar_detail =
          (wmr_status == QM_LONDON_WMR_1600_NO_FIX)
          ? "WMR_1600_SERVICE_UNAVAILABLE"
          : (wmr_status == QM_LONDON_WMR_1600_OUT_OF_COVERAGE)
            ? "WMR_SERVICE_CALENDAR_OUT_OF_COVERAGE"
            : "WMR_SERVICE_CALENDAR_INVALID";
       LogStrategyEntryReject(calendar_detail,
                              london_date_key,
                              entry_utc,
                              StringFormat(",\"wmr_status\":\"%s\",\"coverage_start\":%d,\"coverage_end\":%d,\"holiday_or_lse_substitution\":false",
                                           QM_LoggerEscapeJson(
                                              QM_LondonWmr1600StatusName(
                                                 wmr_status)),
                                           QM_LONDON_WMR_1600_COVERAGE_START,
                                           QM_LONDON_WMR_1600_COVERAGE_END));
       return false;
      }
    if(!InitializePriorHistory(london_date_key))
     {
      LogStrategyEntryReject("PRIOR_MEDIAN_INCOMPLETE",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"prior_count\":%d",
                                          ArraySize(g_prior_displacements)));
      return false;
     }

   double displacement = 0.0;
   double p0 = 0.0;
   if(!FixDisplacement(day_start_utc,
                       p0_cutoff_utc,
                       p1_cutoff_utc,
                        displacement,
                        p0))
     {
      LogStrategyEntryReject("FIX_ENDPOINT_TICKS_MISSING",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"day_start_utc\":%I64d,\"p0_cutoff_utc\":%I64d,\"p1_cutoff_utc\":%I64d",
                                          (long)day_start_utc,
                                          (long)p0_cutoff_utc,
                                          (long)p1_cutoff_utc));
      return false;
     }
   const double median20 = PriorMedian20();
   AddPriorDisplacement(MathAbs(displacement));
   if(median20 <= 0.0 || !MathIsValidNumber(median20))
     {
      const int displacement_count = ArraySize(g_prior_displacements);
      const int prior_count_before_current =
         (displacement_count > 0 ? displacement_count - 1 : 0);
      LogStrategyEntryReject("PRIOR_MEDIAN_INCOMPLETE",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"prior_count_before_current\":%d,\"median20\":%.8f,\"current_displacement\":%.8f",
                                          prior_count_before_current,
                                          median20,
                                          displacement));
      return false;
     }
   if(MathAbs(displacement) <= strategy_displacement_mult * median20)
     {
      LogStrategyEntryReject("DISPLACEMENT_BELOW_1_5_MEDIAN",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"displacement\":%.8f,\"abs_displacement\":%.8f,\"median20\":%.8f,\"threshold\":%.8f",
                                          displacement,
                                          MathAbs(displacement),
                                          median20,
                                          strategy_displacement_mult * median20));
      return false;
     }

   const datetime confirmation_bar = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: exact completed 16:00-16:05 London confirmation bar.
   const double confirmation_close = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: card-authorized confirmation close.
   if(confirmation_bar <= 0 || QM_BrokerToUTC(confirmation_bar) != entry_utc - 5 * 60 ||
      confirmation_close <= 0.0)
     {
      LogStrategyEntryReject("CONFIRMATION_REVERSED",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"confirmation_detail\":\"bar_missing_or_misaligned\",\"confirmation_bar_broker\":%I64d,\"confirmation_bar_utc\":%I64d,\"expected_utc\":%I64d,\"confirmation_close\":%.8f",
                                          (long)confirmation_bar,
                                          (long)QM_BrokerToUTC(confirmation_bar),
                                          (long)(entry_utc - 5 * 60),
                                          confirmation_close));
      return false;
     }

   const bool sell = (displacement > 0.0 && confirmation_close > p0);
   const bool buy = (displacement < 0.0 && confirmation_close < p0);
   if(!buy && !sell)
     {
      LogStrategyEntryReject("CONFIRMATION_REVERSED",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"confirmation_detail\":\"direction_not_preserved\",\"displacement\":%.8f,\"p0\":%.8f,\"confirmation_close\":%.8f",
                                          displacement,
                                          p0,
                                          confirmation_close));
      return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
     {
      LogStrategyEntryReject("TRADE_GEOMETRY_REJECTED",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"geometry_detail\":\"invalid_quote\",\"bid\":%.8f,\"ask\":%.8f,\"displacement\":%.8f,\"median20\":%.8f",
                                          bid,
                                          ask,
                                          displacement,
                                          median20));
      return false;
     }
   const double entry_price = buy ? ask : bid;
   const double target_price = QM_StopRulesNormalizePrice(_Symbol, p0);
   const double stop_distance = MathAbs(displacement);
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol,
                                                         buy ? entry_price - stop_distance
                                                             : entry_price + stop_distance);
   string geometry_reject = "";
   if(stop_price <= 0.0 || target_price <= 0.0 ||
       (buy && !(stop_price < entry_price && entry_price < target_price)) ||
       (sell && !(target_price < entry_price && entry_price < stop_price)))
     {
      LogStrategyEntryReject("TRADE_GEOMETRY_REJECTED",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"geometry_detail\":\"directional_geometry_invalid\",\"side\":\"%s\",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"displacement\":%.8f,\"median20\":%.8f",
                                          buy ? "BUY" : "SELL",
                                          entry_price,
                                          stop_price,
                                          target_price,
                                          displacement,
                                          median20));
      return false;
     }
   if(!TradeGeometryAndVolumeAllow(entry_price,
                                   stop_price,
                                   target_price,
                                   geometry_reject))
     {
      LogStrategyEntryReject("TRADE_GEOMETRY_REJECTED",
                             london_date_key,
                             entry_utc,
                             StringFormat(",\"geometry_detail\":\"%s\",\"side\":\"%s\",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"displacement\":%.8f,\"median20\":%.8f",
                                          QM_LoggerEscapeJson(geometry_reject),
                                          buy ? "BUY" : "SELL",
                                          entry_price,
                                          stop_price,
                                          target_price,
                                          displacement,
                                          median20));
      return false;
     }

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.tp = target_price;
   req.reason = buy ? "WMR_POSTFIX_FADE_LONG" : "WMR_POSTFIX_FADE_SHORT";
   g_active_exit_broker = QM_UTCToBroker(exit_utc);
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"symbol\":\"%s\",\"side\":\"%s\",\"london_date_key\":%d,\"entry_utc\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"displacement\":%.8f,\"median20\":%.8f,\"confirmation_close\":%.8f,\"exit_broker\":%I64d}",
                            QM_LoggerEscapeJson(_Symbol),
                            buy ? "BUY" : "SELL",
                            london_date_key,
                            (long)entry_utc,
                            entry_price,
                            stop_price,
                            target_price,
                            displacement,
                            median20,
                            confirmation_close,
                            (long)g_active_exit_broker));
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

    const bool calendar_ready = QM_LondonWmr1600CalendarLoad();
    QM_LogEvent(calendar_ready ? QM_INFO : QM_ERROR,
                "LONDON_WMR_1600_CALENDAR_STATE",
                StringFormat("{\"required\":true,\"ready\":%s,\"file\":\"%s\",\"coverage_start\":%d,\"coverage_end\":%d,\"manifest_sha256\":\"%s\",\"expected_sha256\":\"%s\",\"actual_sha256\":\"%s\",\"error\":\"%s\",\"holiday_or_lse_substitution\":false}",
                             calendar_ready ? "true" : "false",
                             QM_LONDON_WMR_1600_FILE,
                             QM_LONDON_WMR_1600_COVERAGE_START,
                             QM_LONDON_WMR_1600_COVERAGE_END,
                             QM_LondonCalendarManifestActualSha256(),
                             QM_LONDON_WMR_1600_SHA256,
                             QM_LondonWmr1600CalendarActualSha256(),
                             QM_LoggerEscapeJson(
                                QM_LondonWmr1600CalendarLastError())));

   // Each canonical setfile is an independent single-symbol instance.  The
   // framework init above installs the host-symbol guard; requiring sibling
   // history here made a valid host cold-run depend on an unrelated FX pair.
   QM_LogEvent(QM_INFO,
               "INIT_OK",
                StringFormat("{\"routed\":%s,\"period\":%d,\"signal_tf\":%d,\"inputs_valid\":%s,\"wmr_calendar_ready\":%s,\"median_days\":%d,\"displacement_mult\":%.8f,\"p0_london\":\"%02d:%02d:%02d\",\"p1_london\":\"%02d:%02d:%02d\",\"entry_london\":\"%02d:%02d\",\"exit_london\":\"%02d:%02d\",\"max_spread_points\":%d,\"risk_fixed\":%.2f,\"risk_percent\":%.8f,\"host_only\":true}",
                             IsRoutedSymbol(_Symbol) ? "true" : "false",
                             (int)_Period,
                             (int)strategy_signal_tf,
                             Strategy_InputsValid() ? "true" : "false",
                             calendar_ready ? "true" : "false",
                             strategy_median_days,
                            strategy_displacement_mult,
                            strategy_p0_hour_london,
                            strategy_p0_minute_london,
                            strategy_p0_second_london,
                            strategy_p1_hour_london,
                            strategy_p1_minute_london,
                            strategy_p1_second_london,
                            strategy_entry_hour_london,
                            strategy_entry_minute_london,
                            strategy_exit_hour_london,
                            strategy_exit_minute_london,
                            strategy_max_spread_points,
                            RISK_FIXED,
                            RISK_PERCENT));
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
