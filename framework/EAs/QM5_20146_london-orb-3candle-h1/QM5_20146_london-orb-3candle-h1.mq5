#property strict
#property version   "5.0"
#property description "QM5_20146 london-orb-3candle-h1 (V5)"

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
input int    qm_ea_id                   = 9999;
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
input int    strategy_london_open_uk_hour = 8;
input int    strategy_range_bars          = 3;
input double strategy_tp_r                = 1.5;
input int    strategy_close_ny_hour       = 16;
input int    strategy_close_ny_min        = 45;

datetime g_str120_day_key_london = 0;
datetime g_str120_day_start_utc = 0;
datetime g_str120_range_start_utc = 0;
datetime g_str120_london_open_utc = 0;
datetime g_str120_cutoff_utc = 0;
datetime g_str120_last_state_bar = 0;
datetime g_str120_last_entry_attempt_bar = 0;
datetime g_str120_last_close_attempt_bar = 0;
datetime g_str120_last_tp_attempt_bar = 0;
datetime g_str120_last_data_log_bar = 0;
ulong    g_str120_position_id = 0;
bool     g_str120_range_ready = false;
bool     g_str120_day_consumed = false;
bool     g_str120_day_blocked = false;
double   g_str120_range_high = 0.0;
double   g_str120_range_low = 0.0;

bool Strategy120_ConfigValid()
  {
   return (strategy_london_open_uk_hour == 8 &&
           strategy_range_bars == 3 &&
           MathIsValidNumber(strategy_tp_r) &&
           MathAbs(strategy_tp_r - 1.5) < 1e-9 &&
           strategy_close_ny_hour == 16 &&
           strategy_close_ny_min == 45);
  }

datetime Strategy120_LastSundayUTC(const int year,
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
   datetime last_day = StructToTime(next_month) - 86400;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(last_day <= 0 || !TimeToStruct(last_day, parts))
      return 0;
   last_day -= parts.day_of_week * 86400;
   return last_day + hour_utc * 3600;
  }

int Strategy120_LondonOffsetSecondsUTC(const datetime utc)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return 0;
   const datetime summer_start =
      Strategy120_LastSundayUTC(parts.year, 3, 1);
   const datetime summer_end =
      Strategy120_LastSundayUTC(parts.year, 10, 1);
   if(summer_start > 0 &&
      summer_end > summer_start &&
      utc >= summer_start &&
      utc < summer_end)
      return 3600;
   return 0;
  }

datetime Strategy120_UTCToLondonCivil(const datetime utc)
  {
   if(utc <= 0)
      return 0;
   return utc + Strategy120_LondonOffsetSecondsUTC(utc);
  }

bool Strategy120_LondonCivilToUTC(const datetime civil,
                                  datetime &utc)
  {
   utc = 0;
   if(civil <= 0)
      return false;
   const datetime standard_candidate = civil;
   if(Strategy120_UTCToLondonCivil(standard_candidate) == civil)
     {
      utc = standard_candidate;
      return true;
     }
   const datetime summer_candidate = civil - 3600;
   if(Strategy120_UTCToLondonCivil(summer_candidate) == civil)
     {
      utc = summer_candidate;
      return true;
     }
   return false;
  }

datetime Strategy120_UTCToNewYorkCivil(const datetime utc)
  {
   if(utc <= 0)
      return 0;
   return utc + (QM_IsUSDSTUTC(utc) ? -4 : -5) * 3600;
  }

bool Strategy120_NewYorkCivilToUTC(const datetime civil,
                                   datetime &utc)
  {
   utc = 0;
   if(civil <= 0)
      return false;
   const datetime standard_candidate = civil + 5 * 3600;
   if(Strategy120_UTCToNewYorkCivil(standard_candidate) == civil)
     {
      utc = standard_candidate;
      return true;
     }
   const datetime daylight_candidate = civil + 4 * 3600;
   if(Strategy120_UTCToNewYorkCivil(daylight_candidate) == civil)
     {
      utc = daylight_candidate;
      return true;
     }
   return false;
  }

datetime Strategy120_CivilMidnight(const datetime civil)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(civil <= 0 || !TimeToStruct(civil, parts))
      return 0;
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   return StructToTime(parts);
  }

bool Strategy120_BuildDayWindows(const datetime day_key_london,
                                 datetime &day_start_utc,
                                 datetime &range_start_utc,
                                 datetime &london_open_utc,
                                 datetime &cutoff_utc)
  {
   day_start_utc = 0;
   range_start_utc = 0;
   london_open_utc = 0;
   cutoff_utc = 0;
   if(day_key_london <= 0)
      return false;
   const datetime open_civil =
      day_key_london +
      strategy_london_open_uk_hour * 3600;
   const datetime range_civil =
      open_civil - strategy_range_bars * 3600;
   const datetime cutoff_civil =
      day_key_london +
      strategy_close_ny_hour * 3600 +
      strategy_close_ny_min * 60;
   return (Strategy120_LondonCivilToUTC(day_key_london,
                                        day_start_utc) &&
           Strategy120_LondonCivilToUTC(range_civil,
                                        range_start_utc) &&
           Strategy120_LondonCivilToUTC(open_civil,
                                        london_open_utc) &&
           Strategy120_NewYorkCivilToUTC(cutoff_civil,
                                         cutoff_utc) &&
           range_start_utc < london_open_utc &&
           london_open_utc < cutoff_utc);
  }

bool Strategy120_CurrentH1Bar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) forming-H1 clock for the strategy-owned guard
   return (bar_time > 0);
  }

void Strategy120_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str120_last_data_log_bar)
      return;
   g_str120_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-120\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

double Strategy120_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick =
         SymbolInfoDouble(_Symbol,
                          SYMBOL_POINT);
   return tick;
  }

double Strategy120_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy120_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol,
                               units * tick);
  }

bool Strategy120_NewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol,
                             broker_time,
                             qm_news_mode_legacy);
  }

bool Strategy120_FindOwnPosition(ulong &ticket,
                                 ulong &position_id,
                                 ENUM_POSITION_TYPE &position_type,
                                 double &open_price,
                                 double &current_sl,
                                 double &current_tp,
                                 datetime &position_time)
  {
   ticket = 0;
   position_id = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   current_tp = 0.0;
   position_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl =
         PositionGetDouble(POSITION_SL);
      current_tp =
         PositionGetDouble(POSITION_TP);
      position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy120_HasOwnActivitySince(const datetime start_utc)
  {
   if(start_utc <= 0)
      return false;
   const datetime start_broker =
      QM_UTCToBroker(start_utc);
   if(start_broker <= 0 ||
      !HistorySelect(start_broker, TimeCurrent()))
      return false;
   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < HistoryOrdersTotal(); ++i)
     {
      const ulong order = HistoryOrderGetTicket(i);
      if(order == 0 ||
         (int)HistoryOrderGetInteger(order, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(order, ORDER_SYMBOL) != _Symbol)
         continue;
      const datetime setup_time =
         (datetime)HistoryOrderGetInteger(order,
                                          ORDER_TIME_SETUP);
      if(setup_time >= start_broker)
         return true;
     }
   return false;
  }

bool Strategy120_LoadRange(const datetime forming_time)
  {
   g_str120_range_high = 0.0;
   g_str120_range_low = 0.0;
   int found = 0;
   datetime seen_times[3];
   ArrayInitialize(seen_times, 0);
   for(int shift = 1; shift <= 72; ++shift)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol,
                     PERIOD_H1,
                     shift,
                     bar)) // perf-allowed: bounded closed-H1 scan once per UK date; no forming-bar reads
         continue;
      const datetime bar_utc =
         QM_BrokerToUTC(bar.time);
      if(bar_utc < g_str120_range_start_utc ||
         bar_utc >= g_str120_london_open_utc)
         continue;
      bool duplicate = false;
      for(int i = 0; i < found; ++i)
         if(seen_times[i] == bar_utc)
            duplicate = true;
      if(duplicate || found >= strategy_range_bars ||
         bar.high <= 0.0 || bar.low <= 0.0 ||
         bar.high < bar.low)
         continue;
      seen_times[found] = bar_utc;
      if(found == 0)
        {
         g_str120_range_high = bar.high;
         g_str120_range_low = bar.low;
        }
      else
        {
         g_str120_range_high =
            MathMax(g_str120_range_high, bar.high);
         g_str120_range_low =
            MathMin(g_str120_range_low, bar.low);
        }
      ++found;
     }
   if(found != strategy_range_bars ||
      g_str120_range_low <= 0.0 ||
      g_str120_range_high <= g_str120_range_low)
     {
      Strategy120_LogDataMissing("three_bar_london_range",
                                 forming_time);
      return false;
     }
   return true;
  }

bool Strategy120_EnsureDayState(const datetime now_utc,
                                const datetime forming_time)
  {
   const datetime london_civil =
      Strategy120_UTCToLondonCivil(now_utc);
   const datetime day_key =
      Strategy120_CivilMidnight(london_civil);
   if(day_key <= 0)
      return false;
   if(day_key == g_str120_day_key_london)
      return true;

   g_str120_day_key_london = day_key;
   g_str120_range_ready = false;
   g_str120_day_consumed = false;
   g_str120_day_blocked = false;
   g_str120_range_high = 0.0;
   g_str120_range_low = 0.0;
   g_str120_last_entry_attempt_bar = 0;
   if(!Strategy120_BuildDayWindows(
         day_key,
         g_str120_day_start_utc,
         g_str120_range_start_utc,
         g_str120_london_open_utc,
         g_str120_cutoff_utc))
     {
      g_str120_day_blocked = true;
      Strategy120_LogDataMissing("dst_day_windows",
                                 forming_time);
      return false;
     }
   g_str120_day_consumed =
      Strategy120_HasOwnActivitySince(
         g_str120_day_start_utc);
   return true;
  }

bool Strategy120_EntryGeometryLegal(const bool buy_side,
                                    const double entry,
                                    const double sl,
                                    const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy120_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_FREEZE_LEVEL);
   const double minimum =
      MathMax(tick,
              (double)MathMax(stops_level,
                              freeze_level) * point);
   if(buy_side)
      return (sl < entry && tp > entry &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   return (sl > entry && tp < entry &&
           sl - entry + tick * 0.1 >= minimum &&
           entry - tp + tick * 0.1 >= minimum);
  }

void Strategy120_AttemptEntry(const MqlRates &signal_bar,
                              const datetime forming_time,
                              const bool buy_side)
  {
   if(forming_time <= 0 ||
      forming_time == g_str120_last_entry_attempt_bar)
      return;
   g_str120_last_entry_attempt_bar = forming_time;
   g_str120_day_consumed = true; // qualifying close consumes the UK date

   if(!Strategy120_NewsAllows(TimeCurrent()))
      return;
   ulong existing_ticket = 0;
   ulong existing_id = 0;
   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   double existing_open = 0.0;
   double existing_sl = 0.0;
   double existing_tp = 0.0;
   datetime existing_time = 0;
   if(Strategy120_FindOwnPosition(existing_ticket,
                                  existing_id,
                                  existing_type,
                                  existing_open,
                                  existing_sl,
                                  existing_tp,
                                  existing_time))
      return;

   const double entry =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl =
      Strategy120_AlignPrice(
         buy_side
         ? g_str120_range_low
         : g_str120_range_high,
         buy_side ? -1 : 1);
   const double risk =
      buy_side ? entry - sl : sl - entry;
   const double tp =
      Strategy120_AlignPrice(
         buy_side
         ? entry + strategy_tp_r * risk
         : entry - strategy_tp_r * risk,
         buy_side ? 1 : -1);
   if(!Strategy120_EntryGeometryLegal(buy_side,
                                      entry,
                                      sl,
                                      tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-120\",\"reason\":\"entry_geometry\",\"signal_bar\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            (long)signal_bar.time,
            entry,
            sl,
            tp));
      return;
     }

   QM_EntryRequest req;
   ZeroMemory(req);
   req.type = buy_side ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      buy_side
      ? "STR120_LONDON_CLOSE_LONG"
      : "STR120_LONDON_CLOSE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   ulong ticket = 0;
   QM_TM_OpenPosition(req, ticket);
  }

void Strategy120_CorrectFillRelativeTP(
   const ulong ticket,
   const ulong position_id,
   const ENUM_POSITION_TYPE position_type,
   const double open_price,
   const double current_sl,
   const double current_tp,
   const datetime forming_time)
  {
   if(position_id != g_str120_position_id)
     {
      g_str120_position_id = position_id;
      g_str120_last_tp_attempt_bar = 0;
     }
   if(ticket == 0 || open_price <= 0.0 ||
      current_sl <= 0.0 || forming_time <= 0)
      return;
   const bool buy_side =
      (position_type == POSITION_TYPE_BUY);
   const double risk =
      buy_side ? open_price - current_sl
               : current_sl - open_price;
   if(risk <= 0.0)
      return;
   const double desired =
      Strategy120_AlignPrice(
         buy_side
         ? open_price + strategy_tp_r * risk
         : open_price - strategy_tp_r * risk,
         buy_side ? 1 : -1);
   const double tick = Strategy120_TradeTick();
   if(desired <= 0.0 || tick <= 0.0 ||
      MathAbs(desired - current_tp) <= tick * 0.5 ||
      forming_time == g_str120_last_tp_attempt_bar)
      return;
   g_str120_last_tp_attempt_bar = forming_time;
   QM_TM_MoveTP(ticket,
                desired,
                "STR120_FILL_RELATIVE_1P5R");
  }

void Strategy120_ManagePosition(const datetime forming_time,
                                const datetime now_utc)
  {
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   datetime position_time = 0;
   if(!Strategy120_FindOwnPosition(ticket,
                                   position_id,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   current_tp,
                                   position_time))
     {
      g_str120_position_id = 0;
      return;
     }

   const datetime position_utc =
      QM_BrokerToUTC(position_time);
   const datetime position_day =
      Strategy120_CivilMidnight(
         Strategy120_UTCToLondonCivil(position_utc));
   datetime day_start_utc = 0;
   datetime range_start_utc = 0;
   datetime london_open_utc = 0;
   datetime cutoff_utc = 0;
   if(!Strategy120_BuildDayWindows(position_day,
                                   day_start_utc,
                                   range_start_utc,
                                   london_open_utc,
                                   cutoff_utc))
      return;

   if(now_utc >= cutoff_utc)
     {
      if(forming_time ==
         g_str120_last_close_attempt_bar)
         return;
      g_str120_last_close_attempt_bar = forming_time;
      if(!Strategy120_NewsAllows(TimeCurrent()))
        {
         QM_LogEvent(
            QM_WARN,
            "STRATEGY_EXIT",
            "{\"strategy\":\"STR-120\",\"reason\":\"cutoff_exit_deferred_by_compliance_news\"}");
         return;
        }
      QM_TM_ClosePosition(ticket,
                          QM_EXIT_TIME_STOP);
      return;
     }
   Strategy120_CorrectFillRelativeTP(ticket,
                                     position_id,
                                     position_type,
                                     open_price,
                                     current_sl,
                                     current_tp,
                                     forming_time);
  }

void Strategy120_ProcessClosedBar(const datetime forming_time,
                                  const datetime now_utc)
  {
   if(!Strategy120_EnsureDayState(now_utc,
                                  forming_time) ||
      g_str120_day_blocked ||
      g_str120_day_consumed ||
      now_utc < g_str120_london_open_utc)
      return;
   if(now_utc >= g_str120_cutoff_utc)
     {
      g_str120_day_consumed = true;
      return;
     }
   if(!g_str120_range_ready)
     {
      g_str120_range_ready =
         Strategy120_LoadRange(forming_time);
      if(!g_str120_range_ready)
        {
         g_str120_day_blocked = true;
         return;
        }
     }

   MqlRates first_signal;
   ZeroMemory(first_signal);
   bool found_signal = false;
   bool buy_side = false;
   datetime first_signal_utc = 0;
   for(int shift = 1; shift <= 36; ++shift)
     {
      MqlRates candidate;
      if(!QM_ReadBar(_Symbol,
                     PERIOD_H1,
                     shift,
                     candidate)) // perf-allowed: bounded closed-H1 first-signal reconstruction for restart/no-backfill safety
         continue;
      const datetime candidate_utc =
         QM_BrokerToUTC(candidate.time);
      const datetime candidate_close_utc =
         candidate_utc + 3600;
      if(candidate_utc < g_str120_london_open_utc ||
         candidate_close_utc > g_str120_cutoff_utc ||
         candidate_close_utc > now_utc)
         continue;
      const bool candidate_long =
         (candidate.close > g_str120_range_high);
      const bool candidate_short =
         (candidate.close < g_str120_range_low);
      if(!candidate_long && !candidate_short)
         continue;
      if(!found_signal ||
         candidate_utc < first_signal_utc)
        {
         found_signal = true;
         buy_side = candidate_long;
         first_signal = candidate;
         first_signal_utc = candidate_utc;
        }
     }
   if(!found_signal)
      return;

   const datetime forming_utc =
      QM_BrokerToUTC(forming_time);
   if(first_signal_utc + 3600 != forming_utc)
     {
      // A restart after the first qualifying close must never backfill or
      // substitute a later breakout. Consume the date without an order.
      g_str120_day_consumed = true;
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_FILTER",
         StringFormat(
            "{\"strategy\":\"STR-120\",\"reason\":\"restart_after_first_signal_no_backfill\",\"signal_bar\":%I64d}",
            (long)first_signal.time));
      return;
     }
   Strategy120_AttemptEntry(first_signal,
                            forming_time,
                            buy_side);
  }

bool Strategy_NoTradeFilter()
  {
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   datetime position_time = 0;
   if(Strategy120_FindOwnPosition(ticket,
                                  position_id,
                                  position_type,
                                  open_price,
                                  current_sl,
                                  current_tp,
                                  position_time))
      return false;
   if(_Period != PERIOD_H1 ||
      !Strategy120_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) three-bar/session warmup gate
   return (bars_available < 80);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return false; // Manage owns the close-confirmed daily state machine
  }

void Strategy_ManageOpenPosition()
  {
   datetime forming_time = 0;
   if(!Strategy120_CurrentH1Bar(forming_time))
     {
      Strategy120_LogDataMissing("forming_h1_bar", 0);
      return;
     }
   const datetime now_utc =
      QM_BrokerToUTC(TimeCurrent());
   if(now_utc <= 0)
      return;

   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   datetime position_time = 0;
   if(Strategy120_FindOwnPosition(ticket,
                                  position_id,
                                  position_type,
                                  open_price,
                                  current_sl,
                                  current_tp,
                                  position_time))
     {
      Strategy120_ManagePosition(forming_time,
                                 now_utc);
      return;
     }
   if(forming_time == g_str120_last_state_bar)
      return;
   g_str120_last_state_bar = forming_time;
   Strategy120_ProcessClosedBar(forming_time,
                                now_utc);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(Strategy120_NewsAllows(broker_time))
      return false;
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   datetime position_time = 0;
   return !Strategy120_FindOwnPosition(ticket,
                                       position_id,
                                       position_type,
                                       open_price,
                                       current_sl,
                                       current_tp,
                                       position_time);
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
