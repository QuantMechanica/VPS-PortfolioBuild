#property strict
#property version   "5.0"
#property description "QM5_20043 Prior-RTH TPO value-area rotation"

#include <QM/QM_Common.mqh>
#include <QM/QM_USCashCalendar.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20043;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;     // live setfiles use 0.5; tester keeps this disabled
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; framework news gate fails closed if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_variant_id        = "TPO_VA80_ROT_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M30;
input double strategy_value_area_fraction = 0.70;
input double strategy_min_reward_r      = 1.50;
input int    strategy_cash_open_hour_new_york = 9;
input int    strategy_cash_open_minute_new_york = 30;
input int    strategy_cash_close_hour_new_york = 16;
input int    strategy_cash_close_minute_new_york = 0;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points = 0;
input string strategy_cash_calendar_file = QM_US_CASH_CALENDAR_RUNTIME_FILE;
input string strategy_cash_calendar_sha256 = QM_US_CASH_CALENDAR_RUNTIME_SHA256;

int      g_attempt_date_key = 0;
bool     g_cash_calendar_ready = false;
bool     g_pending_signal = false;
int      g_pending_side = 0;
datetime g_pending_entry_bar_utc = 0;
double   g_pending_sl = 0.0;
double   g_pending_tp = 0.0;

void Strategy_LogEntryReject(const int date_key,
                             const datetime current_bar_utc,
                             const string detail,
                             const string diagnostics = "")
  {
   QM_LogEvent(QM_WARN,
               "ENTRY_REJECTED",
               StringFormat("{\"result\":\"STRATEGY_HOOK_REJECTED\",\"symbol\":\"%s\",\"reason\":\"TPO_VA80_ROT\",\"detail\":\"%s\",\"date_key\":%d,\"current_bar_utc\":%I64d,\"broker_now\":%I64d%s}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            date_key,
                            (long)current_bar_utc,
                            (long)TimeCurrent(),
                            diagnostics));
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime Strategy_NewYorkLocal(const datetime utc)
  {
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 60 * 60 : 5 * 60 * 60);
  }

datetime Strategy_NewYorkLocalToUtc(const int date_key,
                                    const int hour,
                                    const int minute)
  {
   if(date_key < 19000101 || hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   parts.hour = hour;
   parts.min = minute;
   datetime utc = StructToTime(parts) + 5 * 60 * 60;
   if(QM_IsUSDSTUTC(utc))
      utc -= 60 * 60;
   return utc;
  }

int Strategy_ShiftDateKey(const int date_key, const int days)
  {
   if(date_key < 19000101)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   return Strategy_DateKey(StructToTime(parts) + days * 24 * 60 * 60);
  }

bool Strategy_ResolveCashSession(const int date_key,
                                 datetime &open_utc,
                                 datetime &close_utc)
  {
   open_utc = 0;
   close_utc = 0;
   if(QM_USCashCalendarClassify(date_key) != QM_US_CASH_NORMAL)
      return false;
   open_utc = Strategy_NewYorkLocalToUtc(date_key,
                                         strategy_cash_open_hour_new_york,
                                         strategy_cash_open_minute_new_york);
   close_utc = Strategy_NewYorkLocalToUtc(date_key,
                                          strategy_cash_close_hour_new_york,
                                          strategy_cash_close_minute_new_york);
   return (open_utc > 0 && close_utc - open_utc == 390 * 60);
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "NDX.DWX" || symbol == "WS30.DWX" ||
           symbol == "SP500.DWX");
  }

bool Strategy_FindOurPosition(datetime &open_time)
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

double Strategy_TickNormalizedPrice(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return NormalizeDouble(MathRound(price / tick_size) * tick_size, digits);
  }

bool Strategy_BuildPriorProfile(const datetime cash_open_utc,
                                 const datetime cash_close_utc,
                                 double &out_val,
                                 double &out_vah,
                                 double &out_poc)
  {
   out_val = 0.0;
   out_vah = 0.0;
   out_poc = 0.0;
   if(cash_open_utc <= 0 || cash_close_utc - cash_open_utc != 390 * 60)
      return false;

   const datetime from_broker = QM_UTCToBroker(cash_open_utc);
   const datetime through_broker = QM_UTCToBroker(cash_close_utc - 1);
   if(from_broker <= 0 || through_broker <= from_broker)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, from_broker, through_broker, rates); // perf-allowed: exact 13-bar prior-RTH TPO profile, evaluated once at 10:30 ET.
   if(copied != 13)
      return false;

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      return false;

   long low_ticks[13];
   long high_ticks[13];
   long profile_low_tick = LONG_MAX;
   long profile_high_tick = LONG_MIN;
   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int i = 0; i < 13; ++i)
      {
      if(QM_BrokerToUTC(rates[i].time) !=
         cash_open_utc + i * 30 * 60 ||
         rates[i].low <= 0.0 || rates[i].high < rates[i].low)
         return false;
      low_ticks[i] = (long)MathRound(rates[i].low / tick_size);
      high_ticks[i] = (long)MathRound(rates[i].high / tick_size);
      if(low_ticks[i] > high_ticks[i])
         return false;
      if(low_ticks[i] < profile_low_tick)
         profile_low_tick = low_ticks[i];
      if(high_ticks[i] > profile_high_tick)
         profile_high_tick = high_ticks[i];
      prior_low = MathMin(prior_low, rates[i].low);
      prior_high = MathMax(prior_high, rates[i].high);
     }

   const long row_count_long = profile_high_tick - profile_low_tick + 1;
   if(row_count_long <= 1 || row_count_long > 2147483000)
      return false;
   const int row_count = (int)row_count_long;
   int differences[];
   int tpo_counts[];
   if(ArrayResize(differences, row_count + 1) != row_count + 1 ||
      ArrayResize(tpo_counts, row_count) != row_count)
      return false;
   ArrayInitialize(differences, 0);
   ArrayInitialize(tpo_counts, 0);

   for(int i = 0; i < 13; ++i)
     {
      const int low_index = (int)(low_ticks[i] - profile_low_tick);
      const int high_index = (int)(high_ticks[i] - profile_low_tick);
      ++differences[low_index];
      --differences[high_index + 1];
     }

   long total_tpo = 0;
   int running = 0;
   int max_count = 0;
   int poc_index = -1;
   double best_midpoint_distance = DBL_MAX;
   const double midpoint = (prior_high + prior_low) * 0.5;
   for(int i = 0; i < row_count; ++i)
     {
      running += differences[i];
      tpo_counts[i] = running;
      if(running <= 0)
         return false;
      total_tpo += running;
      const double row_price = (double)(profile_low_tick + i) * tick_size;
      const double midpoint_distance = MathAbs(row_price - midpoint);
      if(running > max_count ||
         (running == max_count &&
          midpoint_distance < best_midpoint_distance - tick_size * 1.0e-9))
        {
         max_count = running;
         poc_index = i;
         best_midpoint_distance = midpoint_distance;
        }
     }
   if(total_tpo <= 0 || poc_index < 0)
      return false;

   int lower = poc_index;
   int upper = poc_index;
   long selected_tpo = tpo_counts[poc_index];
   const long required_tpo = (total_tpo * 7 + 9) / 10;
   while(selected_tpo < required_tpo)
     {
      const bool has_lower = (lower > 0);
      const bool has_upper = (upper + 1 < row_count);
      if(!has_lower && !has_upper)
         return false;
      if(has_lower && has_upper)
        {
         const int lower_count = tpo_counts[lower - 1];
         const int upper_count = tpo_counts[upper + 1];
         if(lower_count > upper_count)
           {
            --lower;
            selected_tpo += lower_count;
           }
         else if(upper_count > lower_count)
           {
            ++upper;
            selected_tpo += upper_count;
           }
         else
           {
            --lower;
            selected_tpo += lower_count;
            ++upper;
            selected_tpo += upper_count;
           }
        }
      else if(has_lower)
        {
         --lower;
         selected_tpo += tpo_counts[lower];
        }
      else
        {
         ++upper;
         selected_tpo += tpo_counts[upper];
        }
     }

   out_val = Strategy_TickNormalizedPrice((double)(profile_low_tick + lower) * tick_size);
   out_vah = Strategy_TickNormalizedPrice((double)(profile_low_tick + upper) * tick_size);
   out_poc = Strategy_TickNormalizedPrice((double)(profile_low_tick + poc_index) * tick_size);
   return (out_val > 0.0 && out_vah > out_val &&
           out_poc >= out_val && out_poc <= out_vah);
  }

bool Strategy_FindPriorValidProfile(const int session_date_key,
                                    double &out_val,
                                    double &out_vah,
                                    double &out_poc)
  {
   for(int days_back = 1; days_back <= 10; ++days_back)
     {
      const int prior_date_key = Strategy_ShiftDateKey(session_date_key, -days_back);
      const QM_USCashSessionType prior_session_type =
         QM_USCashCalendarClassify(prior_date_key);
      if(prior_session_type == QM_US_CASH_FULL_CLOSE ||
         prior_session_type == QM_US_CASH_EARLY_CLOSE)
         continue;
      if(prior_session_type != QM_US_CASH_NORMAL)
         return false;
      datetime prior_open_utc = 0;
      datetime prior_close_utc = 0;
      if(!Strategy_ResolveCashSession(prior_date_key,
                                      prior_open_utc,
                                      prior_close_utc))
         return false;
      // The Card requires the immediately preceding complete normal session.
      // A data defect in that session fails closed; never substitute an older
      // normal day merely because its 13 bars happen to be available.
      return Strategy_BuildPriorProfile(prior_open_utc,
                                        prior_close_utc,
                                        out_val,
                                        out_vah,
                                        out_poc);
     }
   return false;
  }

bool Strategy_TradeGeometryAndVolumeAllow(const double entry_price,
                                          const double stop_price,
                                          const double target_price,
                                          double &out_lots,
                                          string &out_reject_detail)
  {
   out_lots = 0.0;
   out_reject_detail = "";
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(RISK_FIXED != 1000.0 || RISK_PERCENT != 0.0)
     {
      out_reject_detail = "risk_mode_invalid";
      return false;
     }
   if(point <= 0.0 || tick_size <= 0.0 ||
      entry_price <= 0.0 || stop_price <= 0.0 || target_price <= 0.0)
     {
      out_reject_detail = "invalid_geometry_inputs";
      return false;
     }

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   if(stop_distance <= 0.0 || target_distance <= 0.0)
     {
      out_reject_detail = "non_positive_distance";
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

   // The framework risk sizer is the canonical monetary-risk source.  It uses
   // SYMBOL_TRADE_TICK_VALUE when available and its governed contract-size
   // fallback otherwise.  Requiring SYMBOL_TRADE_TICK_VALUE_LOSS here was a
   // redundant fail-closed gate: SP500.DWX legitimately reports LOSS=0 while
   // the canonical tick value and contract metadata are usable.
   const double lots = QM_LotsForRisk(_Symbol,
                                      sl_points,
                                      QM_RISK_MODE_FIXED,
                                      RISK_FIXED);
   out_lots = lots;
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
   const double aligned_steps = (lots - volume_min) / volume_step;
   if(MathAbs(aligned_steps - MathRound(aligned_steps)) > 1.0e-6)
     {
      out_reject_detail = "sized_volume_step_misaligned";
      return false;
     }
   return true;
  }

void Strategy_ClearPending()
  {
   g_pending_signal = false;
   g_pending_side = 0;
   g_pending_entry_bar_utc = 0;
   g_pending_sl = 0.0;
   g_pending_tp = 0.0;
  }

bool Strategy_PrepareEntry(const int date_key,
                           const datetime current_bar_utc)
  {
   const QM_USCashSessionType current_session_type =
      QM_USCashCalendarClassify(date_key);
   if(current_session_type != QM_US_CASH_NORMAL)
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              "calendar_session_not_normal",
                              StringFormat(",\"calendar_session_type\":\"%s\",\"calendar_ready\":%s",
                                           QM_USCashSessionTypeName(current_session_type),
                                           QM_USCashCalendarReady()
                                           ? "true" : "false"));
      return false;
     }
   datetime cash_open_utc = 0;
   datetime cash_close_utc = 0;
   if(date_key <= 0 ||
      !Strategy_ResolveCashSession(date_key, cash_open_utc, cash_close_utc) ||
      current_bar_utc != cash_open_utc + 60 * 60)
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              "invalid_session_clock");
      return false;
     }

   double val = 0.0;
   double vah = 0.0;
   double poc = 0.0;
   if(!Strategy_FindPriorValidProfile(date_key, val, vah, poc) ||
      poc < val || poc > vah)
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              "prior_profile_unavailable_or_invalid");
      return false;
     }

   MqlRates first_hour[];
   ArraySetAsSeries(first_hour, false);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, 2, first_hour); // perf-allowed: the two card-mandated completed acceptance bars, once at 10:30 ET.
   if(copied != 2 ||
      QM_BrokerToUTC(first_hour[0].time) != cash_open_utc ||
      QM_BrokerToUTC(first_hour[1].time) != cash_open_utc + 30 * 60)
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              "first_hour_history_missing_or_misaligned",
                              StringFormat(",\"copied\":%d", copied));
      return false;
     }

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0 || first_hour[0].open <= 0.0 ||
      first_hour[0].low <= 0.0 || first_hour[1].low <= 0.0)
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              "invalid_tick_or_bar_data",
                              StringFormat(",\"tick_size\":%.8f", tick_size));
      return false;
     }

   int side = 0;
   if(first_hour[0].open < val &&
      first_hour[0].close > val && first_hour[0].close <= vah &&
      first_hour[1].close > val && first_hour[1].close <= vah)
      side = 1;
   else if(first_hour[0].open > vah &&
           first_hour[0].close >= val && first_hour[0].close < vah &&
           first_hour[1].close >= val && first_hour[1].close < vah)
      side = -1;
   if(side == 0)
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              "outside_open_or_acceptance_not_met",
                              StringFormat(",\"open\":%.8f,\"close_0930\":%.8f,\"close_1000\":%.8f,\"val\":%.8f,\"vah\":%.8f",
                                           first_hour[0].open,
                                           first_hour[0].close,
                                           first_hour[1].close,
                                           val,
                                           vah));
      return false;
     }

   MqlTick current_tick;
   if(!SymbolInfoTick(_Symbol, current_tick) ||
      current_tick.ask <= 0.0 || current_tick.bid <= 0.0 ||
      current_tick.ask < current_tick.bid)
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              "invalid_quote",
                              StringFormat(",\"bid\":%.8f,\"ask\":%.8f",
                                           current_tick.bid,
                                           current_tick.ask));
      return false;
     }

   double entry = 0.0;
   double stop = 0.0;
   double target = 0.0;
   if(side > 0)
     {
      entry = current_tick.ask;
      stop = Strategy_TickNormalizedPrice(MathMin(first_hour[0].low,
                                                  first_hour[1].low) - tick_size);
      target = vah;
      if(entry < val || entry > vah || entry <= stop || target <= entry ||
         MathMax(first_hour[0].high, first_hour[1].high) >= target)
        {
         Strategy_LogEntryReject(date_key,
                                 current_bar_utc,
                                 "long_fill_or_target_geometry_invalid",
                                 StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"val\":%.8f,\"vah\":%.8f",
                                              entry, stop, target, val, vah));
         return false;
        }
     }
   else
     {
      entry = current_tick.bid;
      stop = Strategy_TickNormalizedPrice(MathMax(first_hour[0].high,
                                                  first_hour[1].high) + tick_size);
      target = val;
      if(entry < val || entry > vah || entry >= stop || target >= entry ||
         MathMin(first_hour[0].low, first_hour[1].low) <= target)
        {
         Strategy_LogEntryReject(date_key,
                                 current_bar_utc,
                                 "short_fill_or_target_geometry_invalid",
                                 StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"val\":%.8f,\"vah\":%.8f",
                                              entry, stop, target, val, vah));
         return false;
        }
     }

   const double stop_distance = MathAbs(entry - stop);
   const double target_distance = MathAbs(target - entry);
   if(stop_distance <= 0.0 ||
       target_distance + tick_size * 1.0e-9 <
       strategy_min_reward_r * stop_distance)
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              "minimum_reward_not_met",
                              StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"reward_r\":%.8f",
                                           entry,
                                           stop,
                                           target,
                                           stop_distance > 0.0
                                           ? target_distance / stop_distance
                                           : 0.0));
      return false;
     }

   double lots = 0.0;
   string geometry_reject = "";
   if(!Strategy_TradeGeometryAndVolumeAllow(entry,
                                            stop,
                                            target,
                                            lots,
                                            geometry_reject))
     {
      Strategy_LogEntryReject(date_key,
                              current_bar_utc,
                              geometry_reject,
                              StringFormat(",\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"lots\":%.8f",
                                           entry, stop, target, lots));
      return false;
     }

   g_pending_signal = true;
   g_pending_side = side;
   g_pending_entry_bar_utc = current_bar_utc;
   g_pending_sl = stop;
   g_pending_tp = target;
   return true;
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points < 0 || spread_points > strategy_max_spread_points);
  }

void Strategy_AdvanceStateOnNewBar()
  {
   Strategy_ClearPending();
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf)
      return;

   MqlRates current_bar[];
   ArraySetAsSeries(current_bar, false);
   if(CopyRates(_Symbol, strategy_signal_tf, 0, 1, current_bar) != 1) // perf-allowed: one current bar read under the single framework new-bar event.
      return;
   const datetime current_bar_utc = QM_BrokerToUTC(current_bar[0].time);
   MqlDateTime ny_parts;
   const datetime current_ny = Strategy_NewYorkLocal(current_bar_utc);
   if(current_bar_utc <= 0 || !TimeToStruct(current_ny, ny_parts) ||
      ny_parts.hour != 10 || ny_parts.min != 30 || ny_parts.sec != 0)
      return;

   const int date_key = Strategy_DateKey(current_ny);
   if(date_key <= 0 || date_key == g_attempt_date_key)
      return;
   g_attempt_date_key = date_key;

   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return;
   Strategy_PrepareEntry(date_key, current_bar_utc);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Data/configuration failure blocks entries only. Existing positions must
   // still reach the immutable broker exits and the mandatory 16:00 ET close.
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return false;
   return (!Strategy_IsRoutedSymbol(_Symbol) ||
           _Period != strategy_signal_tf ||
           strategy_variant_id != "TPO_VA80_ROT_BASELINE" ||
            strategy_signal_tf != PERIOD_M30 ||
            strategy_value_area_fraction != 0.70 ||
            strategy_min_reward_r != 1.50 ||
            strategy_cash_open_hour_new_york != 9 ||
            strategy_cash_open_minute_new_york != 30 ||
            strategy_cash_close_hour_new_york != 16 ||
            strategy_cash_close_minute_new_york != 0 ||
            strategy_max_spread_points < 0 ||
            !g_cash_calendar_ready ||
            strategy_cash_calendar_file != QM_US_CASH_CALENDAR_RUNTIME_FILE ||
            QM_USCashUpper(strategy_cash_calendar_sha256) !=
               QM_US_CASH_CALENDAR_RUNTIME_SHA256 ||
            RISK_FIXED != 1000.0 ||
            RISK_PERCENT != 0.0);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_pending_signal || g_pending_entry_bar_utc <= 0)
      return false;

   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
     {
      Strategy_LogEntryReject(g_attempt_date_key,
                              g_pending_entry_bar_utc,
                              "position_already_open");
      Strategy_ClearPending();
      return false;
     }
   if(Strategy_WideSpread())
     {
      Strategy_LogEntryReject(g_attempt_date_key,
                              g_pending_entry_bar_utc,
                              "spread_limit_exceeded",
                              StringFormat(",\"spread_points\":%I64d,\"max_spread_points\":%d",
                                           SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
                                           strategy_max_spread_points));
      Strategy_ClearPending();
      return false;
     }

   req.type = (g_pending_side > 0) ? QM_BUY : QM_SELL;
   req.sl = g_pending_sl;
   req.tp = g_pending_tp;
   req.reason = (g_pending_side > 0)
                ? "TPO_VA80_ROT_LONG"
                : "TPO_VA80_ROT_SHORT";
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"symbol\":\"%s\",\"side\":\"%s\",\"date_key\":%d,\"current_bar_utc\":%I64d,\"sl\":%.8f,\"tp\":%.8f}",
                            QM_LoggerEscapeJson(_Symbol),
                            g_pending_side > 0 ? "BUY" : "SELL",
                            g_attempt_date_key,
                            (long)g_pending_entry_bar_utc,
                            g_pending_sl,
                            g_pending_tp));
   Strategy_ClearPending();
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card: immutable first-hour stop and opposite-value target. No partial,
   // break-even, trailing, scale, averaging, or retry management is allowed.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_broker = 0;
   if(!Strategy_FindOurPosition(open_broker))
      return false;

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime open_utc = QM_BrokerToUTC(open_broker);
   if(now_utc <= 0 || open_utc <= 0)
      return false;
   const datetime now_ny = Strategy_NewYorkLocal(now_utc);
   const datetime open_ny = Strategy_NewYorkLocal(open_utc);
   const int now_date = Strategy_DateKey(now_ny);
   const int open_date = Strategy_DateKey(open_ny);
   if(now_date <= 0 || open_date <= 0)
      return false;
   if(now_date > open_date)
      return true;
   if(now_date < open_date)
      return false;

   MqlDateTime parts;
   if(!TimeToStruct(now_ny, parts))
      return false;
   return (parts.hour * 60 + parts.min >= 16 * 60);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The card keeps the governed central blackout unchanged. Returning false
   // defers to QM_NewsAllowsTrade2 in the framework entry path.
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_M30,
         QM_FRIDAY_CLOSE_CARD_RULE,
         "CARD_V2_FRIDAY_21_SAFETY_FLATTEN"))
      return INIT_FAILED;

   g_cash_calendar_ready =
      QM_USCashCalendarLoad(strategy_cash_calendar_file,
                            strategy_cash_calendar_sha256);
   if(!g_cash_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"dependency\":\"NYSE_US_CASH_CALENDAR\",\"file\":\"%s\",\"expected_sha256\":\"%s\",\"actual_sha256\":\"%s\",\"detail\":\"%s\"}",
                               QM_LoggerEscapeJson(strategy_cash_calendar_file),
                               QM_LoggerEscapeJson(strategy_cash_calendar_sha256),
                               QM_LoggerEscapeJson(QM_USCashCalendarActualSha256()),
                               QM_LoggerEscapeJson(QM_USCashCalendarLastError())));
   else
      QM_LogEvent(QM_INFO,
                  "CASH_CALENDAR_READY",
                  StringFormat("{\"calendar_id\":\"NYSE_GROUP_US_CASH_EQUITIES\",\"file\":\"%s\",\"sha256\":\"%s\",\"manifest_sha256\":\"%s\",\"coverage_start\":%d,\"coverage_end\":%d,\"exception_rows\":%d}",
                               QM_LoggerEscapeJson(strategy_cash_calendar_file),
                               QM_LoggerEscapeJson(QM_USCashCalendarActualSha256()),
                               QM_US_CASH_CALENDAR_MANIFEST_SHA256,
                               QM_US_CASH_COVERAGE_START,
                               QM_US_CASH_COVERAGE_END,
                               QM_US_CASH_EXPECTED_ROWS));

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"routed\":%s,\"period\":%d,\"signal_tf\":%d,\"inputs_valid\":%s,\"variant\":\"%s\"}",
                            Strategy_IsRoutedSymbol(_Symbol) ? "true" : "false",
                            (int)_Period,
                            (int)strategy_signal_tf,
                            (!Strategy_NoTradeFilter()) ? "true" : "false",
                            QM_LoggerEscapeJson(strategy_variant_id)));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Consume the exact 10:30 ET opportunity before the central news gate.
   // News can suppress this attempt, but cannot postpone it to a later bar.
   const bool strategy_new_bar = QM_IsNewBar(_Symbol, PERIOD_M30);
   if(strategy_new_bar)
      Strategy_AdvanceStateOnNewBar();

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
     {
      if(strategy_new_bar && g_pending_signal)
        {
         Strategy_LogEntryReject(g_attempt_date_key,
                                 g_pending_entry_bar_utc,
                                 "news_filter_block");
         // The card permits news to consume the one daily attempt, but never
         // to postpone it into a later quote or bar.
         Strategy_ClearPending();
        }
      return;
     }

   if(!strategy_new_bar)
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
