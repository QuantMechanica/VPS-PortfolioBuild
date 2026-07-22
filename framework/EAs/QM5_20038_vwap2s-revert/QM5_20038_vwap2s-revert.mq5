#property strict
#property version   "5.0"
#property description "QM5_20038 session-anchored VWAP two-sigma reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_USCashCalendar.mqh>

// Strategy Card: QM5_20038_vwap2s-revert, G0 APPROVED 2026-07-22.
// Cash-session eligibility comes from the provenance-locked NYSE calendar.

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
input int    qm_ea_id                   = 20038;
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
input string strategy_variant_id        = "VWAP2S_REVERT_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input int    strategy_cash_open_hour_new_york = 9;
input int    strategy_cash_open_minute_new_york = 30;
input int    strategy_cash_close_hour_new_york = 16;
input int    strategy_cash_close_minute_new_york = 0;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points = 0;

int      g_state_session_key = 0;
datetime g_state_open_utc = 0;
datetime g_state_close_utc = 0;
datetime g_state_through_utc = 0;
double   g_sum_volume = 0.0;
double   g_sum_price_volume = 0.0;
double   g_sum_price2_volume = 0.0;
double   g_session_vwap = 0.0;
double   g_session_sigma = 0.0;
double   g_slope_changes[];
bool     g_estimator_valid = true;
bool     g_long_attempted = false;
bool     g_short_attempted = false;

int      g_pending_side = 0;
datetime g_pending_entry_utc = 0;
double   g_pending_vwap = 0.0;
double   g_pending_sigma = 0.0;
datetime g_active_close_broker = 0;

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

bool Strategy_IsUtcWeekday(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

bool Strategy_ResolveCashSession(const int date_key,
                                 datetime &open_utc,
                                 datetime &close_utc)
  {
   open_utc = 0;
   close_utc = 0;
   const QM_USCashSessionType session_type =
      QM_USCashCalendarClassify(date_key);
   if(session_type != QM_US_CASH_NORMAL &&
      session_type != QM_US_CASH_EARLY_CLOSE)
      return false;
   open_utc = Strategy_NewYorkLocalToUtc(date_key,
                                         strategy_cash_open_hour_new_york,
                                         strategy_cash_open_minute_new_york);
   const int close_hour = (session_type == QM_US_CASH_EARLY_CLOSE)
                          ? 13
                          : strategy_cash_close_hour_new_york;
   const int close_minute = (session_type == QM_US_CASH_EARLY_CLOSE)
                            ? 0
                            : strategy_cash_close_minute_new_york;
   close_utc = Strategy_NewYorkLocalToUtc(date_key,
                                          close_hour,
                                          close_minute);
   const int expected_minutes =
      (session_type == QM_US_CASH_EARLY_CLOSE) ? 210 : 390;
   return (open_utc > 0 &&
           close_utc - open_utc == expected_minutes * 60);
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "SP500.DWX" || symbol == "XAUUSD.DWX");
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

void Strategy_RecoverSessionAttempts(const datetime cash_open_utc)
  {
   g_long_attempted = false;
   g_short_attempted = false;
   const datetime from_broker = QM_UTCToBroker(cash_open_utc);
   if(from_broker <= 0 || !HistorySelect(from_broker, TimeCurrent()))
     {
      g_long_attempted = true;
      g_short_attempted = true;
      return;
     }

   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < HistoryDealsTotal(); ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(deal_type == DEAL_TYPE_BUY)
         g_long_attempted = true;
      else if(deal_type == DEAL_TYPE_SELL)
         g_short_attempted = true;
     }

   for(int i = 0; i < HistoryOrdersTotal(); ++i)
     {
      const ulong order = HistoryOrderGetTicket(i);
      if(order == 0 || (int)HistoryOrderGetInteger(order, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(order, ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(order, ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY)
         g_long_attempted = true;
      else if(order_type == ORDER_TYPE_SELL)
         g_short_attempted = true;
     }
  }

void Strategy_ResetSessionState(const int date_key,
                                const datetime cash_open_utc,
                                const datetime cash_close_utc)
  {
   g_state_session_key = date_key;
   g_state_open_utc = cash_open_utc;
   g_state_close_utc = cash_close_utc;
   g_state_through_utc = 0;
   g_sum_volume = 0.0;
   g_sum_price_volume = 0.0;
   g_sum_price2_volume = 0.0;
   g_session_vwap = 0.0;
   g_session_sigma = 0.0;
   ArrayResize(g_slope_changes, 0);
   g_estimator_valid = true;
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   g_pending_vwap = 0.0;
   g_pending_sigma = 0.0;
   Strategy_RecoverSessionAttempts(cash_open_utc);
  }

double Strategy_PriorSlopeMedian()
  {
   const int n = ArraySize(g_slope_changes);
   if(n <= 0)
      return 0.0;
   double sorted[];
   if(ArrayResize(sorted, n) != n)
      return 0.0;
   for(int i = 0; i < n; ++i)
      sorted[i] = g_slope_changes[i];
   ArraySort(sorted);
   if((n % 2) == 1)
      return sorted[n / 2];
   return 0.5 * (sorted[n / 2 - 1] + sorted[n / 2]);
  }

bool Strategy_AppendSlopeChange(const double slope_abs)
  {
   const int n = ArraySize(g_slope_changes);
   if(ArrayResize(g_slope_changes, n + 1) != n + 1)
      return false;
   g_slope_changes[n] = slope_abs;
   return true;
  }

bool Strategy_ProcessClosedBar(const MqlRates &bar,
                               const datetime bar_utc,
                               const datetime next_open_utc,
                               const bool allow_signal)
  {
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   g_pending_vwap = 0.0;
   g_pending_sigma = 0.0;
   if(!g_estimator_valid || bar.tick_volume <= 0 || bar.high <= 0.0 ||
      bar.low <= 0.0 || bar.close <= 0.0 || bar.high < bar.low)
     {
      g_estimator_valid = false;
      return false;
     }

   const double typical_price = (bar.high + bar.low + bar.close) / 3.0;
   const double volume = (double)bar.tick_volume;
   const double previous_vwap = g_session_vwap;
   g_sum_volume += volume;
   g_sum_price_volume += volume * typical_price;
   g_sum_price2_volume += volume * typical_price * typical_price;
   if(g_sum_volume <= 0.0)
     {
      g_estimator_valid = false;
      return false;
     }

   g_session_vwap = g_sum_price_volume / g_sum_volume;
   double variance = g_sum_price2_volume / g_sum_volume - g_session_vwap * g_session_vwap;
   if(variance < 0.0 && variance > -1.0e-10)
      variance = 0.0;
   g_session_sigma = (variance > 0.0) ? MathSqrt(variance) : 0.0;
   if(!MathIsValidNumber(g_session_vwap) || !MathIsValidNumber(g_session_sigma))
     {
      g_estimator_valid = false;
      return false;
     }

   bool shallow_slope = false;
   double slope_abs = 0.0;
   if(previous_vwap > 0.0)
     {
      slope_abs = MathAbs(g_session_vwap - previous_vwap);
      const double slope_ref = Strategy_PriorSlopeMedian();
      shallow_slope = (ArraySize(g_slope_changes) > 0 && slope_abs <= slope_ref);
      if(!Strategy_AppendSlopeChange(slope_abs))
        {
         g_estimator_valid = false;
         return false;
        }
     }

   g_state_through_utc = bar_utc;
   if(!allow_signal || !shallow_slope || g_session_sigma <= 0.0 ||
      next_open_utc >= g_state_close_utc)
      return true;

   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return true;

   const double lower_band = g_session_vwap - 2.0 * g_session_sigma;
   const double upper_band = g_session_vwap + 2.0 * g_session_sigma;
   const bool long_tag = (bar.low <= lower_band);
   const bool short_tag = (bar.high >= upper_band);
   if(long_tag == short_tag)
      return true;

   if(long_tag && !g_long_attempted)
      g_pending_side = 1;
   else if(short_tag && !g_short_attempted)
      g_pending_side = -1;
   if(g_pending_side != 0)
     {
      g_pending_entry_utc = next_open_utc;
      g_pending_vwap = g_session_vwap;
      g_pending_sigma = g_session_sigma;
     }
   return true;
  }

bool Strategy_RebuildSessionState(const int date_key,
                                  const datetime cash_open_utc,
                                  const datetime cash_close_utc,
                                  const datetime current_open_utc)
  {
   Strategy_ResetSessionState(date_key, cash_open_utc, cash_close_utc);
   const datetime start_broker = QM_UTCToBroker(cash_open_utc);
   const datetime stop_broker = QM_UTCToBroker(current_open_utc) - 1;
   if(start_broker <= 0 || stop_broker < start_broker)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded one-time session rebuild behind QM_IsNewBar.
                                strategy_signal_tf,
                                start_broker,
                                stop_broker,
                                rates);
   if(copied <= 0 || copied > 78)
      return false;

   datetime previous_utc = 0;
   int processed = 0;
   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
      if(bar_utc < cash_open_utc || bar_utc >= cash_close_utc ||
         bar_utc >= current_open_utc)
         continue;
      if(previous_utc > 0 && bar_utc != previous_utc + 5 * 60)
         return false;
      const bool is_latest = (bar_utc + 5 * 60 == current_open_utc);
      if(!Strategy_ProcessClosedBar(rates[i], bar_utc, current_open_utc, is_latest))
         return false;
      previous_utc = bar_utc;
      ++processed;
     }
   return (processed > 0 && g_state_through_utc + 5 * 60 == current_open_utc);
  }

bool Strategy_AdvanceStateOnNewBar()
  {
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf)
      return false;

   MqlRates current_bar;
   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 1, closed_bar))
      return false;
   const datetime current_open_utc = QM_BrokerToUTC(current_bar.time);
   const datetime closed_bar_utc = QM_BrokerToUTC(closed_bar.time);
   const int date_key = Strategy_DateKey(Strategy_NewYorkLocal(closed_bar_utc));
   datetime cash_open_utc = 0;
   datetime cash_close_utc = 0;
   if(!Strategy_ResolveCashSession(date_key, cash_open_utc, cash_close_utc) ||
      closed_bar_utc < cash_open_utc || closed_bar_utc >= cash_close_utc)
      return false;

   if(g_state_session_key != date_key || g_state_open_utc != cash_open_utc ||
      g_state_close_utc != cash_close_utc ||
      g_state_through_utc == 0 || g_state_through_utc + 5 * 60 != closed_bar_utc)
      return Strategy_RebuildSessionState(date_key,
                                          cash_open_utc,
                                          cash_close_utc,
                                          current_open_utc);

   return Strategy_ProcessClosedBar(closed_bar,
                                    closed_bar_utc,
                                    current_open_utc,
                                    current_open_utc < cash_close_utc);
  }

bool Strategy_TradeGeometryAndVolumeAllow(const double entry_price,
                                          const double stop_price,
                                          const double target_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(RISK_FIXED != 1000.0 || RISK_PERCENT != 0.0 ||
      point <= 0.0 || entry_price <= 0.0 || stop_price <= 0.0 ||
      target_price <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double target_distance = MathAbs(entry_price - target_price);
   if(stop_distance <= 0.0 || target_distance <= 0.0)
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

bool Strategy_InputsValid()
  {
   return (strategy_variant_id == "VWAP2S_REVERT_BASELINE" &&
           strategy_signal_tf == PERIOD_M5 &&
           strategy_cash_open_hour_new_york == 9 &&
           strategy_cash_open_minute_new_york == 30 &&
           strategy_cash_close_hour_new_york == 16 &&
           strategy_cash_close_minute_new_york == 0);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

void Strategy_LogEntryRejected(const string detail,
                               const datetime candidate_utc)
  {
   QM_LogEvent(QM_WARN,
               "ENTRY_REJECTED",
               StringFormat("{\"result\":\"STRATEGY_HOOK_REJECTED\",\"symbol\":\"%s\",\"reason\":\"VWAP2S_REVERT\",\"detail\":\"%s\",\"candidate_utc\":%I64d}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            (long)candidate_utc));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return false;
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      !Strategy_InputsValid())
      return true;
   return Strategy_WideSpread();
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

   if(g_pending_side == 0)
      return false;
   const datetime candidate_utc = g_pending_entry_utc;
   if(candidate_utc <= 0 || g_pending_vwap <= 0.0 || g_pending_sigma <= 0.0 ||
      g_state_close_utc <= 0 || candidate_utc >= g_state_close_utc)
     {
      Strategy_LogEntryRejected("PENDING_CANDIDATE_INVALID", candidate_utc);
      return false;
     }

   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      QM_BrokerToUTC(current_bar.time) != candidate_utc)
     {
      Strategy_LogEntryRejected("ENTRY_BAR_MISMATCH", candidate_utc);
      return false;
     }
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
     {
      Strategy_LogEntryRejected("POSITION_ALREADY_OPEN", candidate_utc);
      return false;
     }

   const bool is_long = (g_pending_side > 0);
   if((is_long && g_long_attempted) || (!is_long && g_short_attempted))
     {
      Strategy_LogEntryRejected("SIDE_ALREADY_ATTEMPTED", candidate_utc);
      return false;
     }
   if(is_long)
      g_long_attempted = true;
   else
      g_short_attempted = true;

   const double frozen_vwap = QM_StopRulesNormalizePrice(_Symbol, g_pending_vwap);
   const double frozen_stop = QM_StopRulesNormalizePrice(_Symbol,
                                                          is_long
                                                          ? g_pending_vwap - 3.0 * g_pending_sigma
                                                          : g_pending_vwap + 3.0 * g_pending_sigma);
   g_pending_side = 0;
   g_pending_entry_utc = 0;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
     {
      Strategy_LogEntryRejected("MARKET_QUOTE_INVALID", candidate_utc);
      return false;
     }
   const double entry_price = is_long ? ask : bid;
   if(frozen_vwap <= 0.0 || frozen_stop <= 0.0 ||
      (is_long && !(frozen_stop < entry_price && entry_price < frozen_vwap)) ||
      (!is_long && !(frozen_vwap < entry_price && entry_price < frozen_stop)) ||
      !Strategy_TradeGeometryAndVolumeAllow(entry_price, frozen_stop, frozen_vwap))
     {
      Strategy_LogEntryRejected("TRADE_GEOMETRY_OR_VOLUME_REJECTED", candidate_utc);
      return false;
     }

   req.type = is_long ? QM_BUY : QM_SELL;
   req.sl = frozen_stop;
   req.tp = frozen_vwap;
   req.reason = is_long ? "VWAP2S_REVERT_LONG" : "VWAP2S_REVERT_SHORT";
   g_active_close_broker = QM_UTCToBroker(g_state_close_utc);
   if(g_active_close_broker <= 0)
     {
      Strategy_LogEntryRejected("EXIT_CLOCK_INVALID", candidate_utc);
      return false;
     }
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"symbol\":\"%s\",\"side\":\"%s\",\"candidate_utc\":%I64d,\"entry\":%.8f,\"stop\":%.8f,\"target\":%.8f,\"exit_broker\":%I64d}",
                            QM_LoggerEscapeJson(_Symbol),
                            is_long ? "BUY" : "SELL",
                            (long)candidate_utc,
                            entry_price,
                            frozen_stop,
                            frozen_vwap,
                            (long)g_active_close_broker));
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      g_active_close_broker = 0;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      return false;
   if(g_active_close_broker <= 0)
     {
      const datetime open_utc = QM_BrokerToUTC(open_time);
      const int date_key = Strategy_DateKey(Strategy_NewYorkLocal(open_utc));
      datetime cash_open_utc = 0;
      datetime cash_close_utc = 0;
      if(!Strategy_ResolveCashSession(date_key, cash_open_utc, cash_close_utc))
         return true;
      g_active_close_broker = QM_UTCToBroker(cash_close_utc);
     }
   return (g_active_close_broker > 0 && TimeCurrent() >= g_active_close_broker);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The approved baseline retains the framework default news pause.
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

   const bool calendar_ready =
      QM_USCashCalendarLoad(QM_US_CASH_CALENDAR_RUNTIME_FILE,
                            QM_US_CASH_CALENDAR_RUNTIME_SHA256);
   QM_LogEvent(calendar_ready ? QM_INFO : QM_ERROR,
               "US_CASH_CALENDAR_STATE",
               StringFormat("{\"required\":true,\"ready\":%s,\"file\":\"%s\",\"expected_sha256\":\"%s\",\"actual_sha256\":\"%s\",\"error\":\"%s\"}",
                            calendar_ready ? "true" : "false",
                            QM_LoggerEscapeJson(QM_US_CASH_CALENDAR_RUNTIME_FILE),
                            QM_US_CASH_CALENDAR_RUNTIME_SHA256,
                            QM_USCashCalendarActualSha256(),
                            QM_LoggerEscapeJson(QM_USCashCalendarLastError())));

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

   // Intraday cache: consume the M5 edge once, advance the estimator from the
   // single newly closed bar, then let news gate only the pending entry.
   const bool strategy_new_bar = QM_IsNewBar();
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
      return;

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
