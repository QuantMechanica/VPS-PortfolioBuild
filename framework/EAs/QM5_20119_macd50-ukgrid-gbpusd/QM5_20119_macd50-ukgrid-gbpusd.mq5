#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

#include <QM/QM_Common.mqh>

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
input int    qm_ea_id                   = 20119;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
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
input int    strategy_macd_fast    = 5;
input int    strategy_macd_slow    = 13;
input double strategy_delta_price  = 0.00050;
input double strategy_p1_tp_pips   = 30.0;
input double strategy_p2_tp_pips   = 45.0;
input double strategy_sl_pips      = 30.0;
input int    strategy_seed_bars    = 240;

datetime g_str051_last_entry_bar = 0;
datetime g_str051_last_boundary_local = 0;
datetime g_str051_cache_bar = 0;
datetime g_str051_cache_boundary_local = 0;
datetime g_str051_last_partial_attempt_bar = 0;
datetime g_str051_last_be_attempt_bar = 0;
datetime g_str051_last_data_log_bar = 0;
bool     g_str051_cache_valid = false;
double   g_str051_cache_main1 = 0.0;
double   g_str051_cache_main3 = 0.0;

ulong  g_str051_campaign_ticket = 0;
double g_str051_initial_volume = 0.0;
bool   g_str051_partial_done = false;
bool   g_str051_breakeven_done = false;

bool Strategy051_ConfigValid()
  {
   return (strategy_macd_fast > 1 &&
           strategy_macd_slow > strategy_macd_fast &&
           MathIsValidNumber(strategy_delta_price) &&
           strategy_delta_price > 0.0 &&
           MathIsValidNumber(strategy_p1_tp_pips) &&
           strategy_p1_tp_pips > 0.0 &&
           MathIsValidNumber(strategy_p2_tp_pips) &&
           strategy_p2_tp_pips > strategy_p1_tp_pips &&
           MathIsValidNumber(strategy_sl_pips) &&
           strategy_sl_pips > 0.0 &&
           strategy_seed_bars >=
              strategy_macd_slow + 3);
  }

datetime Strategy051_LastSundayUTC(const int year,
                                   const int month,
                                   const int hour_utc)
  {
   MqlDateTime next_month;
   ZeroMemory(next_month);
   next_month.year = year;
   next_month.mon = month + 1;
   next_month.day = 1;
   if(next_month.mon > 12)
     {
      next_month.mon = 1;
      next_month.year++;
     }
   datetime last_day =
      StructToTime(next_month) - 86400;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(last_day <= 0 ||
      !TimeToStruct(last_day, parts))
      return 0;
   last_day -= parts.day_of_week * 86400;
   return last_day + hour_utc * 3600;
  }

int Strategy051_LondonOffsetSecondsUTC(const datetime utc)
  {
   if(utc <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(utc, parts))
      return 0;

   // In-EA UK analogue of QM_DSTAware's calendar-rule US helper:
   // UK summer time starts/ends on the last Sunday of March/October at
   // 01:00 UTC. No broker-clock inference or hard-coded annual dates.
   const datetime summer_start =
      Strategy051_LastSundayUTC(parts.year, 3, 1);
   const datetime summer_end =
      Strategy051_LastSundayUTC(parts.year, 10, 1);
   if(summer_start > 0 &&
      summer_end > summer_start &&
      utc >= summer_start &&
      utc < summer_end)
      return 3600;
   return 0;
  }

datetime Strategy051_UTCToLondonCivil(const datetime utc)
  {
   if(utc <= 0)
      return 0;
   return utc + Strategy051_LondonOffsetSecondsUTC(utc);
  }

bool Strategy051_LondonCivilToUTC(
   const datetime london_civil,
   datetime &utc)
  {
   utc = 0;
   if(london_civil <= 0)
      return false;

   const datetime standard_candidate =
      london_civil;
   if(Strategy051_UTCToLondonCivil(
         standard_candidate) == london_civil)
     {
      utc = standard_candidate;
      return true;
     }

   const datetime summer_candidate =
      london_civil - 3600;
   if(Strategy051_UTCToLondonCivil(
         summer_candidate) == london_civil)
     {
      utc = summer_candidate;
      return true;
     }
   return false;
  }

datetime Strategy051_BucketStartLocal(const datetime utc)
  {
   const datetime london_civil =
      Strategy051_UTCToLondonCivil(utc);
   if(london_civil <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(london_civil, parts))
      return 0;
   parts.hour = (parts.hour / 4) * 4;
   parts.min = 0;
   parts.sec = 0;
   return StructToTime(parts);
  }

bool Strategy051_BucketUTCWindow(
   const datetime bucket_start_local,
   datetime &start_utc,
   datetime &end_utc,
   int &expected_m15)
  {
   start_utc = 0;
   end_utc = 0;
   expected_m15 = 0;
   if(!Strategy051_LondonCivilToUTC(
         bucket_start_local,
         start_utc) ||
      !Strategy051_LondonCivilToUTC(
         bucket_start_local + 4 * 3600,
         end_utc))
      return false;
   const long duration =
      (long)(end_utc - start_utc);
   if(duration <= 0 ||
      duration % 900 != 0)
      return false;
   expected_m15 = (int)(duration / 900);
   return (expected_m15 >= 12 &&
           expected_m15 <= 20);
  }

bool Strategy051_CurrentBar(datetime &bar_time)
  {
   bar_time = 0;
   MqlRates forming_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_M15, 0, forming_bar))
      return false;
   bar_time = forming_bar.time;
   return (bar_time > 0);
  }

void Strategy051_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str051_last_data_log_bar)
      return;
   g_str051_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-051\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

bool Strategy051_TargetBoundary(
   const datetime broker_bar_time,
   datetime &boundary_local)
  {
   boundary_local = 0;
   const datetime utc =
      QM_BrokerToUTC(broker_bar_time);
   const datetime london_civil =
      Strategy051_UTCToLondonCivil(utc);
   if(utc <= 0 || london_civil <= 0)
      return false;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(london_civil, parts))
      return false;
   if(parts.day_of_week < 1 ||
      parts.day_of_week > 5 ||
      parts.min != 0 ||
      parts.sec != 0 ||
      (parts.hour != 8 &&
       parts.hour != 12 &&
       parts.hour != 16 &&
       parts.hour != 20))
      return false;
   boundary_local = london_civil;
   return true;
  }

bool Strategy051_AppendCompleteBucket(
   const datetime bucket_key,
   const double bucket_close,
   datetime &keys[],
   double &closes[])
  {
   const int size = ArraySize(keys);
   if(ArrayResize(keys, size + 1) != size + 1 ||
      ArrayResize(closes, size + 1) != size + 1)
      return false;
   keys[size] = bucket_key;
   closes[size] = bucket_close;
   return true;
  }

bool Strategy051_FinalizeGroup(
   const datetime group_key,
   const int group_count,
   const datetime first_utc,
   const datetime last_utc,
   const bool contiguous,
   const double group_close,
   datetime &keys[],
   double &closes[])
  {
   if(group_key <= 0 || group_count <= 0)
      return true;
   datetime start_utc = 0;
   datetime end_utc = 0;
   int expected_m15 = 0;
   if(!Strategy051_BucketUTCWindow(group_key,
                                   start_utc,
                                   end_utc,
                                   expected_m15))
      return true;
   const bool complete =
      (contiguous &&
       group_count == expected_m15 &&
       first_utc == start_utc &&
       last_utc == end_utc - 900 &&
       MathIsValidNumber(group_close) &&
       group_close > 0.0);
   if(!complete)
      return true;
   return Strategy051_AppendCompleteBucket(group_key,
                                            group_close,
                                            keys,
                                            closes);
  }

int Strategy051_FindBucket(const datetime key,
                           const datetime &keys[])
  {
   for(int i = ArraySize(keys) - 1; i >= 0; --i)
      if(keys[i] == key)
         return i;
   return -1;
  }

bool Strategy051_RecomputeCustomCache(
   const datetime forming_time,
   const datetime boundary_local)
  {
   if(forming_time == g_str051_cache_bar &&
      boundary_local ==
         g_str051_cache_boundary_local)
      return g_str051_cache_valid;
   g_str051_cache_bar = forming_time;
   g_str051_cache_boundary_local = boundary_local;
   g_str051_cache_valid = false;
   g_str051_cache_main1 = 0.0;
   g_str051_cache_main3 = 0.0;

   const int required_custom =
      strategy_seed_bars + strategy_macd_slow - 1;
   const int scan_bars =
      (strategy_seed_bars +
       strategy_macd_slow + 80) * 16;
   if(required_custom <= 0 ||
      scan_bars <= required_custom)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, scan_bars, rates); // perf-allowed: bounded closed-M15 custom-bar seed scan once per UK boundary
   if(copied < required_custom * 12)
      return false;

   datetime complete_keys[];
   double complete_closes[];
   datetime group_key = 0;
   datetime first_utc = 0;
   datetime last_utc = 0;
   int group_count = 0;
   double group_close = 0.0;
   bool contiguous = true;

   for(int i = 0; i < copied; ++i)
     {
      const datetime utc =
         QM_BrokerToUTC(rates[i].time);
      const datetime next_key =
         Strategy051_BucketStartLocal(utc);
      if(utc <= 0 ||
         next_key <= 0 ||
         !MathIsValidNumber(rates[i].close) ||
         rates[i].close <= 0.0)
         return false;

      if(group_key != 0 &&
         next_key != group_key)
        {
         if(!Strategy051_FinalizeGroup(group_key,
                                       group_count,
                                       first_utc,
                                       last_utc,
                                       contiguous,
                                       group_close,
                                       complete_keys,
                                       complete_closes))
            return false;
         group_key = 0;
         group_count = 0;
         first_utc = 0;
         last_utc = 0;
         group_close = 0.0;
         contiguous = true;
        }

      if(group_key == 0)
        {
         group_key = next_key;
         first_utc = utc;
         last_utc = utc;
         group_count = 1;
         group_close = rates[i].close;
         contiguous = true;
        }
      else
        {
         if(utc != last_utc + 900)
            contiguous = false;
         last_utc = utc;
         group_count++;
         group_close = rates[i].close;
        }
     }

   if(!Strategy051_FinalizeGroup(group_key,
                                 group_count,
                                 first_utc,
                                 last_utc,
                                 contiguous,
                                 group_close,
                                 complete_keys,
                                 complete_closes))
      return false;

   const datetime latest_key =
      boundary_local - 4 * 3600;
   const datetime middle_key =
      boundary_local - 8 * 3600;
   const datetime comparator_key =
      boundary_local - 12 * 3600;
   const int latest_index =
      Strategy051_FindBucket(latest_key,
                             complete_keys);
   const int middle_index =
      Strategy051_FindBucket(middle_key,
                             complete_keys);
   const int comparator_index =
      Strategy051_FindBucket(comparator_key,
                             complete_keys);
   if(latest_index < 2 ||
      middle_index != latest_index - 1 ||
      comparator_index != latest_index - 2 ||
      latest_index != ArraySize(complete_keys) - 1 ||
      latest_index + 1 < required_custom)
      return false;

   double series[];
   if(ArrayResize(series, required_custom) !=
      required_custom)
      return false;
   for(int shift = 0;
       shift < required_custom;
       ++shift)
     {
      series[shift] =
         complete_closes[latest_index - shift];
      if(!MathIsValidNumber(series[shift]) ||
         series[shift] <= 0.0)
         return false;
     }

   const int seed_index =
      strategy_seed_bars - 1;
   double ema_fast = 0.0;
   double ema_slow = 0.0;
   for(int i = seed_index;
       i < seed_index + strategy_macd_fast;
       ++i)
      ema_fast += series[i];
   for(int i = seed_index;
       i < seed_index + strategy_macd_slow;
       ++i)
      ema_slow += series[i];
   ema_fast /= (double)strategy_macd_fast;
   ema_slow /= (double)strategy_macd_slow;

   const double alpha_fast =
      2.0 / (strategy_macd_fast + 1.0);
   const double alpha_slow =
      2.0 / (strategy_macd_slow + 1.0);
   double main1 = 0.0;
   double main3 = 0.0;
   for(int i = seed_index - 1; i >= 0; --i)
     {
      ema_fast =
         alpha_fast * series[i] +
         (1.0 - alpha_fast) * ema_fast;
      ema_slow =
         alpha_slow * series[i] +
         (1.0 - alpha_slow) * ema_slow;
      const double main_value =
         ema_fast - ema_slow;
      if(i == 2)
         main3 = main_value;
      else if(i == 0)
         main1 = main_value;
     }
   if(!MathIsValidNumber(main1) ||
      !MathIsValidNumber(main3))
      return false;

   g_str051_cache_main1 = main1;
   g_str051_cache_main3 = main3;
   g_str051_cache_valid = true;
   return true;
  }

bool Strategy051_HasOwnPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                double &volume,
                                datetime &position_time,
                                ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   volume = 0.0;
   position_time = 0;
   position_id = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      volume = PositionGetDouble(POSITION_VOLUME);
      position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

bool Strategy051_CampaignOpenedSince(const datetime since_time)
  {
   if(since_time <= 0 ||
      !HistorySelect(since_time, TimeCurrent()))
      return false;
   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,
                                                DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN ||
         entry == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

double Strategy051_ReplayInitialVolume(const ulong position_id,
                                       const datetime position_time)
  {
   if(position_id == 0)
      return 0.0;
   const datetime history_from =
      (position_time > 86400)
      ? position_time - 86400
      : 0;
   if(!HistorySelect(history_from, TimeCurrent()))
      return 0.0;

   const int magic = QM_FrameworkMagic();
   double opened_volume = 0.0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (ulong)HistoryDealGetInteger(deal,
                                      DEAL_POSITION_ID) !=
            position_id ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,
                                                DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN ||
         entry == DEAL_ENTRY_INOUT)
         opened_volume +=
            HistoryDealGetDouble(deal, DEAL_VOLUME);
     }
   return opened_volume;
  }

double Strategy051_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy051_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy051_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol, units * tick);
  }

bool Strategy051_StopsLegal(const QM_OrderType side,
                            const double sl,
                            const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy051_TradeTick();
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || tick <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      sl <= 0.0 || tp <= 0.0)
      return false;

   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level)
      ? stops_level
      : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);
   if(side == QM_BUY)
      return (sl < bid && tp > ask &&
              bid - sl + tick * 0.1 >= minimum &&
              tp - ask + tick * 0.1 >= minimum);
   if(side == QM_SELL)
      return (sl > ask && tp < bid &&
              sl - ask + tick * 0.1 >= minimum &&
              bid - tp + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy051_StopLegal(const ENUM_POSITION_TYPE position_type,
                           const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy051_TradeTick();
   if(point <= 0.0 || tick <= 0.0 || candidate <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level)
      ? stops_level
      : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 &&
              candidate < bid &&
              bid - candidate + tick * 0.1 >= minimum);
     }
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 &&
           candidate > ask &&
           candidate - ask + tick * 0.1 >= minimum);
  }

bool Strategy051_StopAtBreakeven(
   const ENUM_POSITION_TYPE position_type,
   const double open_price,
   const double current_sl)
  {
   const double tick = Strategy051_TradeTick();
   if(open_price <= 0.0 || current_sl <= 0.0 || tick <= 0.0)
      return false;
   if(position_type == POSITION_TYPE_BUY)
      return (current_sl >= open_price - tick * 0.5);
   return (current_sl <= open_price + tick * 0.5);
  }

void Strategy051_SyncCampaign(
   const ulong ticket,
   const ENUM_POSITION_TYPE position_type,
   const double open_price,
   const double current_volume,
   const double current_sl,
   const datetime position_time,
   const ulong position_id)
  {
   if(ticket != g_str051_campaign_ticket)
     {
      g_str051_campaign_ticket = ticket;
      g_str051_initial_volume =
         Strategy051_ReplayInitialVolume(position_id,
                                         position_time);
      if(g_str051_initial_volume <= 0.0)
         g_str051_initial_volume = current_volume;
      const bool volume_reduced =
         (g_str051_initial_volume > 0.0 &&
          current_volume <
             0.995 * g_str051_initial_volume);
      const bool stop_at_be =
         Strategy051_StopAtBreakeven(position_type,
                                     open_price,
                                     current_sl);
      g_str051_partial_done =
         (volume_reduced || stop_at_be);
      g_str051_breakeven_done = stop_at_be;
      g_str051_last_partial_attempt_bar = 0;
      g_str051_last_be_attempt_bar = 0;
     }
   else
     {
      if(g_str051_initial_volume > 0.0 &&
         current_volume <
            0.995 * g_str051_initial_volume)
         g_str051_partial_done = true;
      if(Strategy051_StopAtBreakeven(position_type,
                                     open_price,
                                     current_sl))
         g_str051_breakeven_done = true;
     }
  }

void Strategy051_ResetCampaign()
  {
   g_str051_campaign_ticket = 0;
   g_str051_initial_volume = 0.0;
   g_str051_partial_done = false;
   g_str051_breakeven_done = false;
   g_str051_last_partial_attempt_bar = 0;
   g_str051_last_be_attempt_bar = 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15 ||
      !Strategy051_ConfigValid())
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const int required_m15 =
      (strategy_seed_bars +
       strategy_macd_slow - 1) * 16;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_M15,
                        SERIES_BARS_COUNT);
   return (bars_available < required_m15);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy051_CurrentBar(forming_time))
     {
      Strategy051_LogDataMissing("forming_m15_bar", 0);
      return false;
     }
   if(forming_time == g_str051_last_entry_bar)
      return false;
   g_str051_last_entry_bar = forming_time;

   datetime boundary_local = 0;
   if(!Strategy051_TargetBoundary(forming_time,
                                  boundary_local))
      return false;
   if(boundary_local ==
      g_str051_last_boundary_local)
      return false;
   g_str051_last_boundary_local = boundary_local;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_volume = 0.0;
   datetime position_time = 0;
   ulong position_id = 0;
   if(Strategy051_HasOwnPosition(ticket,
                                 position_type,
                                 open_price,
                                 current_sl,
                                 current_volume,
                                 position_time,
                                 position_id) ||
      Strategy051_CampaignOpenedSince(forming_time))
      return false;

   if(!Strategy051_RecomputeCustomCache(
         forming_time,
         boundary_local))
     {
      Strategy051_LogDataMissing(
         "uk4h_seed_or_required_bucket",
         forming_time);
      return false;
     }

   const double delta =
      g_str051_cache_main1 -
      g_str051_cache_main3;
   const bool long_signal =
      (delta >= strategy_delta_price);
   const bool short_signal =
      (delta <= -strategy_delta_price);
   if(!long_signal && !short_signal)
      return false;

   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double pip =
      QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
      pip <= 0.0)
     {
      Strategy051_LogDataMissing(
         "market_or_pip_metadata",
         forming_time);
      return false;
     }

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? ask : bid;
   const double raw_sl =
      long_signal
      ? entry - strategy_sl_pips * pip
      : entry + strategy_sl_pips * pip;
   const double raw_tp =
      long_signal
      ? entry + strategy_p2_tp_pips * pip
      : entry - strategy_p2_tp_pips * pip;
   req.sl =
      Strategy051_AlignPrice(raw_sl,
                             long_signal ? -1 : 1);
   req.tp =
      Strategy051_AlignPrice(raw_tp,
                             long_signal ? 1 : -1);
   if(!Strategy051_StopsLegal(req.type,
                              req.sl,
                              req.tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-051\",\"reason\":\"stop_geometry\",\"dir\":\"%s\",\"boundary_local\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            QM_LoggerEscapeJson(
               long_signal ? "LONG" : "SHORT"),
            (long)boundary_local,
            entry,
            req.sl,
            req.tp));
      return false;
     }

   req.price = 0.0;
   req.reason =
      StringFormat(long_signal
                   ? "STR051_L_%I64d"
                   : "STR051_S_%I64d",
                   (long)boundary_local);
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-051\",\"dir\":\"%s\",\"boundary_local\":%I64d,\"main1\":%.8f,\"main3\":%.8f,\"delta\":%.8f,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
         QM_LoggerEscapeJson(
            long_signal ? "LONG" : "SHORT"),
         (long)boundary_local,
         g_str051_cache_main1,
         g_str051_cache_main3,
         delta,
         entry,
         req.sl,
         req.tp));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_volume = 0.0;
   datetime position_time = 0;
   ulong position_id = 0;
   if(!Strategy051_HasOwnPosition(ticket,
                                  position_type,
                                  open_price,
                                  current_sl,
                                  current_volume,
                                  position_time,
                                  position_id))
     {
      Strategy051_ResetCampaign();
      return;
     }

   Strategy051_SyncCampaign(ticket,
                            position_type,
                            open_price,
                            current_volume,
                            current_sl,
                            position_time,
                            position_id);
   datetime forming_time = 0;
   if(!Strategy051_CurrentBar(forming_time))
     {
      Strategy051_LogDataMissing("manage_m15_bar", 0);
      return;
     }

   const double pip =
      QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(!g_str051_partial_done && pip > 0.0)
     {
      const double market =
         (position_type == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool at_p1 =
         (market > 0.0) &&
         (position_type == POSITION_TYPE_BUY
          ? market >=
             open_price + strategy_p1_tp_pips * pip
          : market <=
             open_price - strategy_p1_tp_pips * pip);
      if(at_p1 &&
         forming_time !=
            g_str051_last_partial_attempt_bar)
        {
         g_str051_last_partial_attempt_bar =
            forming_time;
         const double requested =
            g_str051_initial_volume * 0.5;
         const double close_volume =
            QM_TM_NormalizeVolume(_Symbol, requested);
         const double min_volume =
            SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(close_volume <= 0.0 ||
            close_volume >= current_volume ||
            current_volume - close_volume + 1e-10 <
               min_volume)
           {
            QM_LogEvent(
               QM_WARN,
               "SETUP_CONFIG_INVALID",
               StringFormat(
                  "{\"strategy\":\"STR-051\",\"reason\":\"half_volume\",\"ticket\":%I64u,\"initial_volume\":%.8f,\"current_volume\":%.8f,\"requested_close\":%.8f}",
                  ticket,
                  g_str051_initial_volume,
                  current_volume,
                  requested));
           }
         else if(QM_TM_PartialClose(ticket,
                                    close_volume,
                                    QM_EXIT_PARTIAL))
           {
            g_str051_partial_done = true;
            QM_LogEvent(
               QM_INFO,
               "STRATEGY_EXIT",
               StringFormat(
                  "{\"strategy\":\"STR-051\",\"ticket\":%I64u,\"reason\":\"half_at_30p\",\"closed_volume\":%.8f,\"initial_volume\":%.8f}",
                  ticket,
                  close_volume,
                  g_str051_initial_volume));
           }
         else
           {
            QM_LogEvent(
               QM_WARN,
               "TM_PARTIAL_RETRY_DEFERRED",
               StringFormat(
                  "{\"strategy\":\"STR-051\",\"ticket\":%I64u,\"stage\":\"half_close\",\"retry_after_bar\":%I64d}",
                  ticket,
                  (long)forming_time));
           }
        }
     }

   if(!g_str051_partial_done ||
      g_str051_breakeven_done ||
      forming_time == g_str051_last_be_attempt_bar)
      return;
   g_str051_last_be_attempt_bar = forming_time;
   const double be =
      Strategy051_AlignPrice(
         open_price,
         position_type == POSITION_TYPE_BUY ? -1 : 1);
   if(be > 0.0 &&
      Strategy051_StopLegal(position_type, be) &&
      QM_TM_MoveSL(ticket, be, "STR051_HALF_BE"))
     {
      g_str051_breakeven_done = true;
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_EXIT",
         StringFormat(
            "{\"strategy\":\"STR-051\",\"ticket\":%I64u,\"reason\":\"breakeven_armed\",\"sl\":%.8f}",
            ticket,
            be));
     }
   else
     {
      QM_LogEvent(
         QM_WARN,
         "TM_PARTIAL_RETRY_DEFERRED",
         StringFormat(
            "{\"strategy\":\"STR-051\",\"ticket\":%I64u,\"stage\":\"breakeven_move\",\"retry_after_bar\":%I64d}",
            ticket,
            (long)forming_time));
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
      return;

   if(!QM_IsNewBar())
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
