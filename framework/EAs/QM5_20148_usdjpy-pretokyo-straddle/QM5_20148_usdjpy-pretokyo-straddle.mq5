#property strict
#property version   "5.0"
#property description "QM5_20148 usdjpy-pretokyo-straddle (V5)"

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
input int    strategy_range_start_et_hour  = 18;
input int    strategy_range_end_et_hour    = 20;
input int    strategy_entry_cutoff_et_hour = 22;
input double strategy_entry_offset_pips    = 2.0;
input double strategy_sl_pips              = 15.0;
input bool   strategy_sl_add_spread        = true;
input double strategy_tp1_pips             = 40.0;
input double strategy_tp1_fraction         = 0.50;
input double strategy_tp2_pips             = 70.0;
input double strategy_be_plus_pips         = 0.0;

datetime g_str132_day_key_et = 0;
datetime g_str132_day_start_utc = 0;
datetime g_str132_range_start_utc = 0;
datetime g_str132_range_end_utc = 0;
datetime g_str132_cutoff_utc = 0;
datetime g_str132_last_state_bar = 0;
datetime g_str132_last_place_attempt_bar = 0;
datetime g_str132_last_cancel_attempt_bar = 0;
datetime g_str132_last_partial_attempt_bar = 0;
datetime g_str132_last_be_attempt_bar = 0;
datetime g_str132_last_sl_attempt_bar = 0;
datetime g_str132_last_tp_attempt_bar = 0;
datetime g_str132_last_anomaly_attempt_bar = 0;
datetime g_str132_last_data_log_bar = 0;
bool     g_str132_day_consumed = false;
bool     g_str132_day_blocked = false;
bool     g_str132_range_ready = false;
double   g_str132_range_high = 0.0;
double   g_str132_range_low = 0.0;
double   g_str132_setup_spread = 0.0;

ulong  g_str132_campaign_position_id = 0;
double g_str132_original_volume = 0.0;
double g_str132_captured_spread = 0.0;
bool   g_str132_campaign_facts_valid = false;
bool   g_str132_tp1_triggered = false;
bool   g_str132_partial_done = false;
bool   g_str132_be_done = false;

bool Strategy132_ConfigValid()
  {
   return (strategy_range_start_et_hour == 18 &&
           strategy_range_end_et_hour == 20 &&
           strategy_entry_cutoff_et_hour == 22 &&
           MathIsValidNumber(strategy_entry_offset_pips) &&
           MathAbs(strategy_entry_offset_pips - 2.0) < 1e-9 &&
           MathIsValidNumber(strategy_sl_pips) &&
           MathAbs(strategy_sl_pips - 15.0) < 1e-9 &&
           strategy_sl_add_spread &&
           MathIsValidNumber(strategy_tp1_pips) &&
           MathAbs(strategy_tp1_pips - 40.0) < 1e-9 &&
           MathIsValidNumber(strategy_tp1_fraction) &&
           MathAbs(strategy_tp1_fraction - 0.50) < 1e-9 &&
           MathIsValidNumber(strategy_tp2_pips) &&
           MathAbs(strategy_tp2_pips - 70.0) < 1e-9 &&
           MathIsValidNumber(strategy_be_plus_pips) &&
           MathAbs(strategy_be_plus_pips) < 1e-9);
  }

datetime Strategy132_UTCToETCivil(const datetime utc)
  {
   if(utc <= 0)
      return 0;
   return utc + (QM_IsUSDSTUTC(utc) ? -4 : -5) * 3600;
  }

bool Strategy132_ETCivilToUTC(const datetime civil,
                              datetime &utc)
  {
   utc = 0;
   if(civil <= 0)
      return false;
   const datetime standard_candidate = civil + 5 * 3600;
   if(Strategy132_UTCToETCivil(standard_candidate) == civil)
     {
      utc = standard_candidate;
      return true;
     }
   const datetime daylight_candidate = civil + 4 * 3600;
   if(Strategy132_UTCToETCivil(daylight_candidate) == civil)
     {
      utc = daylight_candidate;
      return true;
     }
   return false;
  }

datetime Strategy132_CivilMidnight(const datetime civil)
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

bool Strategy132_BuildDayWindows(const datetime day_key_et,
                                 datetime &day_start_utc,
                                 datetime &range_start_utc,
                                 datetime &range_end_utc,
                                 datetime &cutoff_utc)
  {
   day_start_utc = 0;
   range_start_utc = 0;
   range_end_utc = 0;
   cutoff_utc = 0;
   if(day_key_et <= 0)
      return false;
   return (Strategy132_ETCivilToUTC(day_key_et,
                                    day_start_utc) &&
           Strategy132_ETCivilToUTC(
              day_key_et +
              strategy_range_start_et_hour * 3600,
              range_start_utc) &&
           Strategy132_ETCivilToUTC(
              day_key_et +
              strategy_range_end_et_hour * 3600,
              range_end_utc) &&
           Strategy132_ETCivilToUTC(
              day_key_et +
              strategy_entry_cutoff_et_hour * 3600,
              cutoff_utc) &&
           range_start_utc < range_end_utc &&
           range_end_utc < cutoff_utc);
  }

bool Strategy132_CurrentM15Bar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_M15,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) forming-M15 clock for strategy-owned guards
   return (bar_time > 0);
  }

void Strategy132_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str132_last_data_log_bar)
      return;
   g_str132_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-132\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

double Strategy132_TradeTick()
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

double Strategy132_Pip()
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits =
      (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return ((digits == 3 || digits == 5)
           ? 10.0 * point
           : point);
  }

double Strategy132_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy132_TradeTick();
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

bool Strategy132_NewsAllows(const datetime broker_time)
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

bool Strategy132_EntryWindowNewsClear()
  {
   if(g_str132_range_end_utc <= 0 ||
      g_str132_cutoff_utc <= g_str132_range_end_utc)
      return false;
   for(datetime utc = g_str132_range_end_utc;
       utc < g_str132_cutoff_utc;
       utc += 60)
     {
      const datetime broker_time =
         QM_UTCToBroker(utc);
      if(broker_time <= 0 ||
         !Strategy132_NewsAllows(broker_time))
         return false;
     }
   return true;
  }

bool Strategy132_FindOwnPosition(
   ulong &ticket,
   ulong &position_id,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   double &current_sl,
   double &current_tp,
   double &current_volume,
   datetime &position_time)
  {
   ticket = 0;
   position_id = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   current_tp = 0.0;
   current_volume = 0.0;
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
      current_volume =
         PositionGetDouble(POSITION_VOLUME);
      position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int Strategy132_OwnPositionCount()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ++count;
     }
   return count;
  }

int Strategy132_OwnPendingCount()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP ||
         order_type == ORDER_TYPE_SELL_STOP)
         ++count;
     }
   return count;
  }

bool Strategy132_CancelOwnPending(const string reason,
                                  const datetime forming_time,
                                  const bool paced)
  {
   if(Strategy132_OwnPendingCount() <= 0)
      return true;
   if(paced &&
      forming_time > 0 &&
      forming_time == g_str132_last_cancel_attempt_bar)
      return false;
   if(paced && forming_time > 0)
      g_str132_last_cancel_attempt_bar = forming_time;

   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return all_ok &&
          Strategy132_OwnPendingCount() == 0;
  }

bool Strategy132_EnforceSingleOwnPosition(
   const datetime forming_time)
  {
   const int magic = QM_FrameworkMagic();
   int own_count = 0;
   ulong keep_ticket = 0;
   long keep_time_msc = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long opened_msc =
         PositionGetInteger(POSITION_TIME_MSC);
      ++own_count;
      if(keep_ticket == 0 ||
         opened_msc < keep_time_msc ||
         (opened_msc == keep_time_msc &&
          candidate < keep_ticket))
        {
         keep_ticket = candidate;
         keep_time_msc = opened_msc;
        }
     }
   if(own_count <= 1)
      return true;
   g_str132_day_blocked = true;
   g_str132_day_consumed = true;
   Strategy132_CancelOwnPending("oco_double_fill",
                                forming_time,
                                true);
   if(forming_time == g_str132_last_anomaly_attempt_bar)
      return false;
   g_str132_last_anomaly_attempt_bar = forming_time;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         candidate == keep_ticket ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_ClosePosition(candidate,
                          QM_EXIT_STRATEGY);
     }
   QM_LogEvent(
      QM_WARN,
      "STRATEGY_EXIT",
      StringFormat(
         "{\"strategy\":\"STR-132\",\"reason\":\"oco_double_fill_flatten_later\",\"keep_ticket\":%I64u,\"position_count\":%d}",
         keep_ticket,
         own_count));
   return false;
  }

bool Strategy132_HasOwnActivitySince(const datetime start_utc)
  {
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

bool Strategy132_EnsureDayState(const datetime now_utc,
                                const datetime forming_time)
  {
   const datetime et_civil =
      Strategy132_UTCToETCivil(now_utc);
   const datetime day_key =
      Strategy132_CivilMidnight(et_civil);
   if(day_key <= 0)
      return false;
   if(day_key == g_str132_day_key_et)
      return true;

   g_str132_day_key_et = day_key;
   g_str132_day_consumed = false;
   g_str132_day_blocked = false;
   g_str132_range_ready = false;
   g_str132_range_high = 0.0;
   g_str132_range_low = 0.0;
   g_str132_setup_spread = 0.0;
   g_str132_last_place_attempt_bar = 0;
   if(!Strategy132_BuildDayWindows(
         day_key,
         g_str132_day_start_utc,
         g_str132_range_start_utc,
         g_str132_range_end_utc,
         g_str132_cutoff_utc))
     {
      g_str132_day_blocked = true;
      Strategy132_LogDataMissing("et_day_windows",
                                 forming_time);
      return false;
     }
   g_str132_day_consumed =
      Strategy132_HasOwnActivitySince(
         g_str132_day_start_utc);
   return true;
  }

bool Strategy132_LoadRange(const datetime forming_time)
  {
   g_str132_range_high = 0.0;
   g_str132_range_low = 0.0;
   int found = 0;
   datetime seen_times[8];
   ArrayInitialize(seen_times, 0);
   for(int shift = 1; shift <= 96; ++shift)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol,
                     PERIOD_M15,
                     shift,
                     bar)) // perf-allowed: bounded closed-M15 scan once per ET date; no forming-bar values
         continue;
      const datetime bar_utc =
         QM_BrokerToUTC(bar.time);
      if(bar_utc < g_str132_range_start_utc ||
         bar_utc >= g_str132_range_end_utc)
         continue;
      bool duplicate = false;
      for(int i = 0; i < found; ++i)
         if(seen_times[i] == bar_utc)
            duplicate = true;
      if(duplicate || found >= 8 ||
         bar.high <= 0.0 || bar.low <= 0.0 ||
         bar.high < bar.low)
         continue;
      seen_times[found] = bar_utc;
      if(found == 0)
        {
         g_str132_range_high = bar.high;
         g_str132_range_low = bar.low;
        }
      else
        {
         g_str132_range_high =
            MathMax(g_str132_range_high, bar.high);
         g_str132_range_low =
            MathMin(g_str132_range_low, bar.low);
        }
      ++found;
     }
   if(found != 8 ||
      g_str132_range_low <= 0.0 ||
      g_str132_range_high <= g_str132_range_low)
     {
      Strategy132_LogDataMissing("eight_bar_et_range",
                                 forming_time);
      return false;
     }
   return true;
  }

bool Strategy132_PendingLegal(const bool buy_side,
                              const double entry,
                              const double sl,
                              const double tp,
                              const double bid,
                              const double ask)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy132_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid)
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
      return (entry > ask && sl < entry && tp > entry &&
              entry - ask + tick * 0.1 >= minimum &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   return (entry < bid && sl > entry && tp < entry &&
           bid - entry + tick * 0.1 >= minimum &&
           sl - entry + tick * 0.1 >= minimum &&
           entry - tp + tick * 0.1 >= minimum);
  }

bool Strategy132_ExactHalfLegal(const double total_volume,
                                double &half_volume)
  {
   half_volume = 0.0;
   const double step =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   const double minimum =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(total_volume <= 0.0 ||
      step <= 0.0 || minimum <= 0.0)
      return false;
   const double normalized_total =
      QM_TM_NormalizeVolume(_Symbol,
                            total_volume);
   half_volume =
      QM_TM_NormalizeVolume(_Symbol,
                            total_volume *
                            strategy_tp1_fraction);
   const double tolerance = step * 0.1 + 1e-10;
   return (normalized_total > 0.0 &&
           MathAbs(normalized_total -
                   total_volume) <= tolerance &&
           half_volume >= minimum &&
           normalized_total - half_volume >= minimum &&
           MathAbs(2.0 * half_volume -
                   normalized_total) <= tolerance);
  }

bool Strategy132_PreflightVolumeSplit(
   const double buy_entry,
   const double buy_sl,
   const double sell_entry,
   const double sell_sl)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double buy_points =
      MathAbs(buy_entry - buy_sl) / point;
   const double sell_points =
      MathAbs(sell_entry - sell_sl) / point;
   const double buy_volume =
      QM_LotsForRiskAtEntry(_Symbol,
                            buy_points,
                            ORDER_TYPE_BUY_STOP,
                            buy_entry);
   const double sell_volume =
      QM_LotsForRiskAtEntry(_Symbol,
                            sell_points,
                            ORDER_TYPE_SELL_STOP,
                            sell_entry);
   double buy_half = 0.0;
   double sell_half = 0.0;
   return (Strategy132_ExactHalfLegal(buy_volume,
                                      buy_half) &&
           Strategy132_ExactHalfLegal(sell_volume,
                                      sell_half));
  }

bool Strategy132_BuildPendingRequest(
   const bool buy_side,
   const int expiration_seconds,
   const double entry,
   const double sl,
   const double tp,
   QM_EntryRequest &req)
  {
   if(expiration_seconds <= 0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;
   ZeroMemory(req);
   req.type = buy_side ? QM_BUY_STOP : QM_SELL_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      buy_side
      ? "STR132_ET_STRADDLE_BUY"
      : "STR132_ET_STRADDLE_SELL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   return true;
  }

bool Strategy132_OrderVolumeSplitLegal(const ulong ticket)
  {
   if(ticket == 0 || !OrderSelect(ticket))
      return false;
   const double initial_volume =
      OrderGetDouble(ORDER_VOLUME_INITIAL);
   double half_volume = 0.0;
   return Strategy132_ExactHalfLegal(initial_volume,
                                     half_volume);
  }

bool Strategy132_PlaceBoth(const datetime forming_time,
                           const double buy_entry,
                           const double buy_sl,
                           const double buy_tp,
                           const double sell_entry,
                           const double sell_sl,
                           const double sell_tp)
  {
   if(forming_time <= 0 ||
      forming_time == g_str132_last_place_attempt_bar)
      return false;
   g_str132_last_place_attempt_bar = forming_time;
   const datetime now_utc =
      QM_BrokerToUTC(TimeCurrent());
   const int expiration_seconds =
      (int)(g_str132_cutoff_utc - now_utc);
   if(expiration_seconds <= 0)
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   ZeroMemory(buy_req);
   ZeroMemory(sell_req);
   if(!Strategy132_BuildPendingRequest(true,
                                       expiration_seconds,
                                       buy_entry,
                                       buy_sl,
                                       buy_tp,
                                       buy_req) ||
      !Strategy132_BuildPendingRequest(false,
                                       expiration_seconds,
                                       sell_entry,
                                       sell_sl,
                                       sell_tp,
                                       sell_req))
      return false;

   ulong buy_ticket = 0;
   ulong sell_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;
   if(!QM_TM_OpenPosition(sell_req, sell_ticket))
     {
      QM_TM_RemovePendingOrder(buy_ticket,
                               "straddle_rollback");
      Strategy132_CancelOwnPending("straddle_rollback",
                                   forming_time,
                                   false);
      return false;
     }
   if(!Strategy132_OrderVolumeSplitLegal(buy_ticket) ||
      !Strategy132_OrderVolumeSplitLegal(sell_ticket))
     {
      QM_TM_RemovePendingOrder(buy_ticket,
                               "volume_split_rollback");
      QM_TM_RemovePendingOrder(sell_ticket,
                               "volume_split_rollback");
      Strategy132_CancelOwnPending(
         "volume_split_rollback",
         forming_time,
         false);
      return false;
     }
   g_str132_last_cancel_attempt_bar = 0;
   return true;
  }

void Strategy132_AttemptDateSetup(const datetime forming_time)
  {
   if(g_str132_day_consumed ||
      g_str132_day_blocked)
      return;
   g_str132_day_consumed = true;
   if(!Strategy132_LoadRange(forming_time))
     {
      g_str132_day_blocked = true;
      return;
     }
   g_str132_range_ready = true;
   if(!Strategy132_EntryWindowNewsClear())
     {
      g_str132_day_blocked = true;
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_FILTER",
         "{\"strategy\":\"STR-132\",\"reason\":\"news_intersects_20_22_et_window\"}");
      return;
     }

   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double pip = Strategy132_Pip();
   const double spread = ask - bid;
   if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
      pip <= 0.0 || spread < 0.0)
     {
      g_str132_day_blocked = true;
      Strategy132_LogDataMissing("placement_quote",
                                 forming_time);
      return;
     }
   g_str132_setup_spread = spread;
   const double buy_entry =
      Strategy132_AlignPrice(
         g_str132_range_high +
         strategy_entry_offset_pips * pip,
         1);
   const double sell_entry =
      Strategy132_AlignPrice(
         g_str132_range_low -
         strategy_entry_offset_pips * pip,
         -1);
   const double protected_distance =
      strategy_sl_pips * pip +
      g_str132_setup_spread;
   const double buy_sl =
      Strategy132_AlignPrice(
         buy_entry - protected_distance,
         -1);
   const double sell_sl =
      Strategy132_AlignPrice(
         sell_entry + protected_distance,
         1);
   const double buy_tp =
      Strategy132_AlignPrice(
         buy_entry + strategy_tp2_pips * pip,
         1);
   const double sell_tp =
      Strategy132_AlignPrice(
         sell_entry - strategy_tp2_pips * pip,
         -1);

   if(!Strategy132_PendingLegal(true,
                                buy_entry,
                                buy_sl,
                                buy_tp,
                                bid,
                                ask) ||
      !Strategy132_PendingLegal(false,
                                sell_entry,
                                sell_sl,
                                sell_tp,
                                bid,
                                ask) ||
      !Strategy132_PreflightVolumeSplit(
         buy_entry,
         buy_sl,
         sell_entry,
         sell_sl))
     {
      g_str132_day_blocked = true;
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-132\",\"reason\":\"both_sides_or_exact_half_preflight\",\"buy_entry\":%.8f,\"buy_sl\":%.8f,\"sell_entry\":%.8f,\"sell_sl\":%.8f,\"spread\":%.8f}",
            buy_entry,
            buy_sl,
            sell_entry,
            sell_sl,
            spread));
      return;
     }
   if(!Strategy132_PlaceBoth(forming_time,
                             buy_entry,
                             buy_sl,
                             buy_tp,
                             sell_entry,
                             sell_sl,
                             sell_tp))
      g_str132_day_blocked = true;
  }

void Strategy132_ResetCampaign()
  {
   g_str132_campaign_position_id = 0;
   g_str132_original_volume = 0.0;
   g_str132_captured_spread = 0.0;
   g_str132_campaign_facts_valid = false;
   g_str132_tp1_triggered = false;
   g_str132_partial_done = false;
   g_str132_be_done = false;
   g_str132_last_partial_attempt_bar = 0;
   g_str132_last_be_attempt_bar = 0;
   g_str132_last_sl_attempt_bar = 0;
   g_str132_last_tp_attempt_bar = 0;
  }

bool Strategy132_RecoverEntryFacts(
   const ulong position_id,
   const datetime position_time,
   double &original_volume,
   double &captured_spread)
  {
   original_volume = 0.0;
   captured_spread = 0.0;
   if(position_id == 0 || position_time <= 0)
      return false;
   datetime history_start =
      position_time - 24 * 60 * 60;
   if(history_start < 0)
      history_start = 0;
   if(!HistorySelect(history_start,
                     TimeCurrent()))
      return false;
   const int magic = QM_FrameworkMagic();
   bool stop_facts_found = false;
   const double pip = Strategy132_Pip();
   for(int i = 0; i < HistoryDealsTotal(); ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (ulong)HistoryDealGetInteger(
            deal,
            DEAL_POSITION_ID) != position_id ||
         (int)HistoryDealGetInteger(
            deal,
            DEAL_MAGIC) != magic ||
         HistoryDealGetString(
            deal,
            DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
            deal,
            DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const double deal_volume =
         HistoryDealGetDouble(deal,
                              DEAL_VOLUME);
      if(deal_volume > 0.0)
         original_volume += deal_volume;
      if(!stop_facts_found)
        {
         const ulong order_ticket =
            (ulong)HistoryDealGetInteger(
               deal,
               DEAL_ORDER);
         const double requested_entry =
            (order_ticket > 0)
            ? HistoryOrderGetDouble(
                 order_ticket,
                 ORDER_PRICE_OPEN)
            : 0.0;
         const double initial_sl =
            (order_ticket > 0)
            ? HistoryOrderGetDouble(
                 order_ticket,
                 ORDER_SL)
            : 0.0;
         if(requested_entry > 0.0 &&
            initial_sl > 0.0 && pip > 0.0)
           {
            captured_spread =
               MathMax(0.0,
                       MathAbs(requested_entry -
                               initial_sl) -
                       strategy_sl_pips * pip);
            stop_facts_found = true;
           }
        }
     }
   return (original_volume > 0.0 &&
           stop_facts_found);
  }

void Strategy132_SyncCampaign(const ulong position_id,
                              const datetime position_time,
                              const double open_price,
                              const double current_sl,
                              const double current_volume)
  {
   if(position_id == 0 ||
      position_id == g_str132_campaign_position_id)
      return;
   Strategy132_ResetCampaign();
   g_str132_campaign_position_id = position_id;
   g_str132_campaign_facts_valid =
      Strategy132_RecoverEntryFacts(position_id,
                                    position_time,
                                    g_str132_original_volume,
                                    g_str132_captured_spread);
   if(!g_str132_campaign_facts_valid)
     {
      Strategy132_LogDataMissing("entry_volume_history",
                                 position_time);
      return;
     }
   const double step =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   const double tolerance =
      (step > 0.0) ? step * 0.5 : 1e-8;
   if(current_volume + tolerance <
      g_str132_original_volume)
     {
      g_str132_tp1_triggered = true;
      g_str132_partial_done = true;
     }
   const double tick = Strategy132_TradeTick();
   if(open_price > 0.0 && current_sl > 0.0 &&
      tick > 0.0 &&
      MathAbs(current_sl - open_price) <= tick * 0.5)
      g_str132_be_done = true;
  }

bool Strategy132_PositionLevelLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate,
   const bool is_stop)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy132_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      candidate <= 0.0)
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
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return is_stop
             ? (candidate < bid &&
                bid - candidate + tick * 0.1 >= minimum)
             : (candidate > bid &&
                candidate - bid + tick * 0.1 >= minimum);
     }
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return is_stop
          ? (candidate > ask &&
             candidate - ask + tick * 0.1 >= minimum)
          : (candidate < ask &&
             ask - candidate + tick * 0.1 >= minimum);
  }

void Strategy132_ManagePosition(const datetime forming_time)
  {
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   double current_volume = 0.0;
   datetime position_time = 0;
   if(!Strategy132_FindOwnPosition(ticket,
                                   position_id,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   current_tp,
                                   current_volume,
                                   position_time))
     {
      Strategy132_ResetCampaign();
      return;
     }
   Strategy132_SyncCampaign(position_id,
                            position_time,
                            open_price,
                            current_sl,
                            current_volume);
   if(!g_str132_campaign_facts_valid ||
      open_price <= 0.0 || current_volume <= 0.0)
      return;

   const bool buy_side =
      (position_type == POSITION_TYPE_BUY);
   const double pip = Strategy132_Pip();
   const double tick = Strategy132_TradeTick();
   const double market =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(pip <= 0.0 || tick <= 0.0 || market <= 0.0)
      return;

   const double desired_initial_sl =
      Strategy132_AlignPrice(
         buy_side
         ? open_price -
           (strategy_sl_pips * pip +
            g_str132_captured_spread)
         : open_price +
           (strategy_sl_pips * pip +
            g_str132_captured_spread),
         buy_side ? -1 : 1);
   const bool initial_sl_tightens =
      buy_side
      ? desired_initial_sl >
        current_sl + tick * 0.5
      : (current_sl <= 0.0 ||
         desired_initial_sl <
         current_sl - tick * 0.5);
   if(initial_sl_tightens &&
      Strategy132_PositionLevelLegal(position_type,
                                     desired_initial_sl,
                                     true) &&
      forming_time != g_str132_last_sl_attempt_bar)
     {
      g_str132_last_sl_attempt_bar = forming_time;
      if(QM_TM_MoveSL(ticket,
                      desired_initial_sl,
                      "STR132_FILL_RELATIVE_SL15_SPREAD"))
         current_sl = desired_initial_sl;
     }

   const double desired_tp =
      Strategy132_AlignPrice(
         buy_side
         ? open_price + strategy_tp2_pips * pip
         : open_price - strategy_tp2_pips * pip,
         buy_side ? 1 : -1);
   if(MathAbs(desired_tp - current_tp) > tick * 0.5 &&
      Strategy132_PositionLevelLegal(position_type,
                                     desired_tp,
                                     false) &&
      forming_time != g_str132_last_tp_attempt_bar)
     {
      g_str132_last_tp_attempt_bar = forming_time;
      QM_TM_MoveTP(ticket,
                   desired_tp,
                   "STR132_FILL_RELATIVE_TP70");
     }

   const double favorable =
      buy_side
      ? market - open_price
      : open_price - market;
   if(favorable + tick * 0.1 >=
      strategy_tp1_pips * pip)
      g_str132_tp1_triggered = true;

   if(!g_str132_partial_done &&
      g_str132_tp1_triggered &&
      Strategy132_NewsAllows(TimeCurrent()) &&
      forming_time != g_str132_last_partial_attempt_bar)
     {
      g_str132_last_partial_attempt_bar = forming_time;
      double close_volume = 0.0;
      if(!Strategy132_ExactHalfLegal(
            g_str132_original_volume,
            close_volume) ||
         close_volume >= current_volume)
        {
         QM_LogEvent(
            QM_ERROR,
            "SETUP_CONFIG_INVALID",
            StringFormat(
               "{\"strategy\":\"STR-132\",\"reason\":\"post_fill_exact_half_violation\",\"original_volume\":%.8f,\"current_volume\":%.8f,\"close_volume\":%.8f}",
               g_str132_original_volume,
               current_volume,
               close_volume));
         return;
        }
      if(QM_TM_PartialClose(ticket,
                            close_volume,
                            QM_EXIT_PARTIAL))
        {
         g_str132_partial_done = true;
         QM_LogEvent(
            QM_INFO,
            "STRATEGY_EXIT",
            StringFormat(
               "{\"strategy\":\"STR-132\",\"reason\":\"tp1_40_partial\",\"exit_reason\":\"QM_EXIT_PARTIAL\",\"closed_volume\":%.8f,\"original_volume\":%.8f}",
               close_volume,
               g_str132_original_volume));
        }
      else
         return; // rejected partial retries no earlier than next M15 bar
     }
   if(!g_str132_partial_done || g_str132_be_done)
      return;

   const double desired_be =
      Strategy132_AlignPrice(
         buy_side
         ? open_price +
           strategy_be_plus_pips * pip
         : open_price -
           strategy_be_plus_pips * pip,
         buy_side ? -1 : 1);
   const bool tightens =
      buy_side
      ? desired_be > current_sl + tick * 0.5
      : (current_sl <= 0.0 ||
         desired_be < current_sl - tick * 0.5);
   if(!tightens)
     {
      if(MathAbs(current_sl - desired_be) <=
         tick * 0.5)
         g_str132_be_done = true;
      return;
     }
   if(forming_time == g_str132_last_be_attempt_bar ||
      !Strategy132_PositionLevelLegal(position_type,
                                      desired_be,
                                      true))
      return;
   g_str132_last_be_attempt_bar = forming_time;
   if(QM_TM_MoveSL(ticket,
                   desired_be,
                   "STR132_TP1_CONFIRMED_BE"))
      g_str132_be_done = true;
  }

void Strategy132_ProcessFlatState(const datetime forming_time,
                                  const datetime now_utc)
  {
   if(!Strategy132_EnsureDayState(now_utc,
                                  forming_time))
      return;

   if(Strategy132_OwnPendingCount() > 0)
     {
      g_str132_day_consumed = true;
      if(now_utc >= g_str132_cutoff_utc)
         Strategy132_CancelOwnPending("22_et_expiry",
                                      forming_time,
                                      true);
      return;
     }
   if(now_utc >= g_str132_cutoff_utc)
     {
      g_str132_day_consumed = true;
      return;
     }
   if(now_utc < g_str132_range_end_utc ||
      g_str132_day_consumed ||
      g_str132_day_blocked)
      return;
   Strategy132_AttemptDateSetup(forming_time);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy132_OwnPositionCount() > 0 ||
      Strategy132_OwnPendingCount() > 0)
      return false;
   if(_Period != PERIOD_M15 ||
      !Strategy132_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_M15,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) two-hour range warmup gate
   return (bars_available < 120);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return false; // Manage owns all OCO/state-machine transitions
  }

void Strategy_ManageOpenPosition()
  {
   datetime forming_time = 0;
   if(!Strategy132_CurrentM15Bar(forming_time))
     {
      Strategy132_LogDataMissing("forming_m15_bar", 0);
      return;
     }
   if(!Strategy132_EnforceSingleOwnPosition(forming_time))
      return;

   if(Strategy132_OwnPositionCount() > 0)
     {
      Strategy132_CancelOwnPending(
         "oco_peer_after_fill",
         forming_time,
         true);
      Strategy132_ManagePosition(forming_time);
      return;
     }
   Strategy132_ResetCampaign();
   const datetime now_utc =
      QM_BrokerToUTC(TimeCurrent());
   if(now_utc <= 0)
      return;

   // Expiry/OCO lifecycle is checked every tick. State creation itself is
   // evaluated once per forming M15 bar.
   if(g_str132_cutoff_utc > 0 &&
      now_utc >= g_str132_cutoff_utc &&
      Strategy132_OwnPendingCount() > 0)
      Strategy132_CancelOwnPending("22_et_expiry",
                                   forming_time,
                                   true);
   if(forming_time == g_str132_last_state_bar)
      return;
   g_str132_last_state_bar = forming_time;
   Strategy132_ProcessFlatState(forming_time,
                                now_utc);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(Strategy132_NewsAllows(broker_time))
      return false;
   datetime forming_time = 0;
   Strategy132_CurrentM15Bar(forming_time);
   if(Strategy132_OwnPendingCount() > 0)
     {
      g_str132_day_consumed = true;
      g_str132_day_blocked = true;
      Strategy132_CancelOwnPending("news_blackout",
                                   forming_time,
                                   true);
     }
   return (Strategy132_OwnPositionCount() == 0);
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
