#property strict
#property version   "5.0"
#property description "QM5_20041 cash-session post-close continuation"

#include <QM/QM_Common.mqh>
#include <QM/QM_XetraCashCalendar.mqh>
#include <QM/QM_LondonCalendars.mqh>

// Strategy Card: QM5_20041_postclose-cont, G0 APPROVED 2026-07-22.
// GDAXI cash-session anchors come from the governed Xetra calendar and are
// converted Europe/Berlin -> UTC -> broker. UK100 uses the independently
// governed LSE calendar and Europe/London -> UTC -> broker conversion. Missing
// broker-break/rollover/financing inputs are logged as evidence gaps below.

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
input int    qm_ea_id                   = 20041;
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
input string strategy_variant_id        = "POSTCLOSE_CONT_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M15;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 1.0;
input int    strategy_hold_minutes      = 240;
// Legacy fields remain for historical setfile serialization. Neither route
// uses fixed broker-hour replacements.
input int    strategy_cash_open_hour_broker = 10;
input int    strategy_cash_open_minute_broker = 0;
input int    strategy_cash_close_hour_broker = 18;
input int    strategy_cash_close_minute_broker = 30;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points = 0;

int      g_pending_session_date_key = 0;
int      g_pending_side = 0;
datetime g_pending_entry_bar_utc = 0;
ulong    g_pending_entry_tick_msc = 0;
datetime g_pending_exit_utc = 0;
double   g_pending_atr = 0.0;
bool     g_session_attempted = false;
datetime g_active_exit_broker = 0;
int      g_last_state_attempt_date_key = 0;
int      g_last_state_reject_date_key = 0;
bool     g_xetra_calendar_ready = false;
bool     g_lse_calendar_ready = false;

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_CashDateKeyForBrokerTime(const datetime broker_time)
  {
   if(_Symbol == "GDAXI.DWX")
      return QM_XetraCashBerlinDateKeyFromUTC(QM_BrokerToUTC(broker_time));
   if(_Symbol == "UK100.DWX")
      return QM_LondonCalendarDateKeyFromUTC(QM_BrokerToUTC(broker_time));
   return Strategy_DateKey(broker_time);
  }

bool Strategy_ResolveCashSession(const int date_key,
                                 datetime &open_broker,
                                 datetime &close_broker,
                                 datetime &open_utc,
                                 datetime &close_utc)
  {
   open_broker = 0;
   close_broker = 0;
   open_utc = 0;
   close_utc = 0;
   if(_Symbol == "GDAXI.DWX")
     {
      if(!g_xetra_calendar_ready)
         return false;
      const QM_XetraCashSessionType session_type =
         QM_XetraCashCalendarClassify(date_key);
      if(session_type != QM_XETRA_CASH_NORMAL &&
         session_type != QM_XETRA_CASH_EARLY_CLOSE)
         return false;
      const int close_hour =
         (session_type == QM_XETRA_CASH_EARLY_CLOSE ? 14 : 17);
      const int close_minute =
         (session_type == QM_XETRA_CASH_EARLY_CLOSE ? 0 : 30);
      if(!QM_XetraCashBerlinLocalToUTC(date_key, 9, 0, open_utc) ||
         !QM_XetraCashBerlinLocalToUTC(date_key,
                                       close_hour,
                                       close_minute,
                                       close_utc))
         return false;
      open_broker = QM_UTCToBroker(open_utc);
      close_broker = QM_UTCToBroker(close_utc);
      return (open_broker > 0 && close_broker > open_broker &&
              QM_BrokerToUTC(open_broker) == open_utc &&
              QM_BrokerToUTC(close_broker) == close_utc);
     }

   if(_Symbol == "UK100.DWX")
     {
      if(!g_lse_calendar_ready)
         return false;
      QM_LondonLseCashSessionType session_type =
         QM_LONDON_LSE_CASH_INVALID;
      if(!QM_LondonLseCashSessionUTC(date_key,
                                     session_type,
                                     open_utc,
                                     close_utc))
         return false;
      open_broker = QM_UTCToBroker(open_utc);
      close_broker = QM_UTCToBroker(close_utc);
      return (open_broker > 0 && close_broker > open_broker &&
              QM_BrokerToUTC(open_broker) == open_utc &&
              QM_BrokerToUTC(close_broker) == close_utc);
     }
   return false;
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "GDAXI.DWX" || symbol == "UK100.DWX");
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

void Strategy_RecoverAttempt(const datetime cash_close_utc)
  {
   g_session_attempted = false;
   const datetime from_broker = QM_UTCToBroker(cash_close_utc);
   if(from_broker <= 0 || !HistorySelect(from_broker, TimeCurrent()))
     {
      g_session_attempted = true;
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
      if(entry_kind == DEAL_ENTRY_IN || entry_kind == DEAL_ENTRY_INOUT)
        {
         g_session_attempted = true;
         return;
        }
     }
  }

bool Strategy_TickMid(const MqlTick &tick, double &mid)
  {
   mid = 0.0;
   if(tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      return false;
   mid = 0.5 * (tick.bid + tick.ask);
   return (mid > 0.0 && MathIsValidNumber(mid));
  }

double Strategy_TickNormalizedPrice(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, MathRound(price / tick_size) * tick_size);
  }

bool Strategy_FirstSessionMid(const datetime cash_open_broker,
                              const datetime cash_close_broker,
                              double &mid)
  {
   mid = 0.0;
   // .DWX custom ticks retain the broker-labelled epoch used to construct
   // their M1/M15 rates. CopyTicksRange must therefore use the same broker
   // labels as the bars, not the UTC-normalized audit timestamps.
   ulong cursor = (ulong)cash_open_broker * 1000;
   const ulong stop_msc = (ulong)cash_close_broker * 1000;
   const ulong chunk_width = 5 * 60 * 1000;
   long previous_msc = 0;
   while(cursor <= stop_msc)
     {
      ulong chunk_end = cursor + chunk_width - 1;
      if(chunk_end < cursor || chunk_end > stop_msc)
         chunk_end = stop_msc;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, cursor, chunk_end);
      if(copied < 0)
         return false;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
         if(Strategy_TickMid(ticks[i], mid))
            return true;
        }
      if(chunk_end == stop_msc)
         break;
      cursor = chunk_end + 1;
     }
   return false;
  }

bool Strategy_LastSessionMid(const datetime cash_open_broker,
                             const datetime cash_close_broker,
                             double &mid)
  {
   mid = 0.0;
   const ulong start_msc = (ulong)cash_open_broker * 1000;
   ulong window_end = (ulong)cash_close_broker * 1000;
   const ulong chunk_width = 5 * 60 * 1000;
   while(window_end >= start_msc)
     {
      ulong window_start = start_msc;
      if(window_end - start_msc + 1 > chunk_width)
         window_start = window_end - chunk_width + 1;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO,
                                        window_start, window_end);
      if(copied < 0)
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
         if(Strategy_TickMid(ticks[i], mid))
            return true;
        }
      if(window_start == start_msc)
         break;
      window_end = window_start - 1;
     }
   return false;
  }

bool Strategy_IsFirstTradableTick(const datetime entry_bar_broker,
                                  const MqlTick &current_tick)
  {
   double current_mid = 0.0;
   if(!Strategy_TickMid(current_tick, current_mid))
      return false;
   ulong cursor = (ulong)entry_bar_broker * 1000;
   const ulong stop_msc = (ulong)current_tick.time_msc;
   if(stop_msc < cursor)
      return false;
   const ulong chunk_width = 60 * 1000;
   while(cursor <= stop_msc)
     {
      ulong chunk_end = cursor + chunk_width - 1;
      if(chunk_end < cursor || chunk_end > stop_msc)
         chunk_end = stop_msc;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, cursor, chunk_end);
      if(copied < 0)
         return false;
      long previous_msc = 0;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
         double mid = 0.0;
         if(Strategy_TickMid(ticks[i], mid))
            return ((ulong)ticks[i].time_msc == (ulong)current_tick.time_msc);
        }
      if(chunk_end == stop_msc)
         break;
      cursor = chunk_end + 1;
     }
   return false;
  }

bool Strategy_BindClockExit(const datetime entry_utc,
                            datetime &exit_utc)
  {
   exit_utc = entry_utc + strategy_hold_minutes * 60;
   const datetime entry_broker = QM_UTCToBroker(entry_utc);
   const datetime exit_broker = QM_UTCToBroker(exit_utc);
   if(entry_utc <= 0 || entry_broker <= 0 || exit_broker <= entry_broker ||
      Strategy_DateKey(entry_broker) != Strategy_DateKey(exit_broker))
     {
      exit_utc = 0;
      return false;
     }
   return true;
  }

void Strategy_LogEntryRejected(const string detail,
                               const datetime candidate_utc,
                               const string context = "")
  {
   QM_LogEvent(QM_WARN,
               "ENTRY_REJECTED",
               StringFormat("{\"result\":\"STRATEGY_HOOK_REJECTED\",\"symbol\":\"%s\",\"reason\":\"POSTCLOSE_CONT\",\"detail\":\"%s\",\"candidate_utc\":%I64d,\"context\":\"%s\"}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            (long)candidate_utc,
                            QM_LoggerEscapeJson(context)));
  }

void Strategy_LogStateAttempt(const int session_date_key,
                              const datetime observation_bar_broker,
                              const datetime entry_bar_broker,
                              const datetime candidate_utc)
  {
   if(session_date_key <= 0 || g_last_state_attempt_date_key == session_date_key)
      return;
   g_last_state_attempt_date_key = session_date_key;
   QM_LogEvent(QM_INFO,
               "ENTRY_ATTEMPT",
               StringFormat("{\"symbol\":\"%s\",\"session_date\":%d,\"observation_bar_broker\":%I64d,\"entry_bar_broker\":%I64d,\"candidate_utc\":%I64d,\"tick_time_basis\":\"dwx_broker_label\"}",
                            QM_LoggerEscapeJson(_Symbol),
                            session_date_key,
                            (long)observation_bar_broker,
                            (long)entry_bar_broker,
                            (long)candidate_utc));
  }

void Strategy_LogStateRejected(const int session_date_key,
                               const string detail,
                               const datetime candidate_utc,
                               const string context = "")
  {
   if(session_date_key > 0 && g_last_state_reject_date_key == session_date_key)
      return;
   g_last_state_reject_date_key = session_date_key;
   Strategy_LogEntryRejected(detail, candidate_utc, context);
  }

bool Strategy_AdvanceStateOnNewBar()
  {
   g_pending_session_date_key = 0;
   g_pending_side = 0;
   g_pending_entry_bar_utc = 0;
   g_pending_entry_tick_msc = 0;
   g_pending_exit_utc = 0;
   g_pending_atr = 0.0;
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      strategy_signal_tf != PERIOD_M15 ||
      !SymbolIsSynchronized(_Symbol))
      return false;

   MqlRates current_bar;
   MqlRates observation_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 1, observation_bar))
      return false;
   const datetime entry_bar_utc = QM_BrokerToUTC(current_bar.time);
   const datetime observation_bar_utc = QM_BrokerToUTC(observation_bar.time);
   const int session_date_key =
      Strategy_CashDateKeyForBrokerTime(observation_bar.time);
   datetime cash_open_broker = 0;
   datetime cash_close_broker = 0;
   datetime cash_open_utc = 0;
   datetime cash_close_utc = 0;
   const bool session_resolved = Strategy_ResolveCashSession(session_date_key,
                                                              cash_open_broker,
                                                              cash_close_broker,
                                                              cash_open_utc,
                                                              cash_close_utc);
   // Non-candidate bars remain silent. Once the closed bar is the configured
   // cash-close observation, every later failure is observable exactly once.
   if(observation_bar.time != cash_close_broker)
      return false;

   const datetime expected_entry_bar_broker = cash_close_broker + 15 * 60;
   const datetime candidate_utc = QM_BrokerToUTC(expected_entry_bar_broker);
   Strategy_LogStateAttempt(session_date_key,
                            observation_bar.time,
                            current_bar.time,
                            candidate_utc);

   if(!session_resolved)
     {
      Strategy_LogStateRejected(session_date_key,
                                "CASH_SESSION_CLOCK_INVALID",
                                candidate_utc);
      return true;
     }
   if(observation_bar_utc != cash_close_utc ||
      current_bar.time != expected_entry_bar_broker ||
      entry_bar_utc != cash_close_utc + 15 * 60)
     {
      Strategy_LogStateRejected(session_date_key,
                                "OBSERVATION_OR_ENTRY_BAR_MISMATCH",
                                candidate_utc,
                                StringFormat("observation_broker=%I64d;entry_broker=%I64d;expected_entry_broker=%I64d",
                                             (long)observation_bar.time,
                                             (long)current_bar.time,
                                             (long)expected_entry_bar_broker));
      return true;
     }
   if(observation_bar.open <= 0.0 || observation_bar.high <= 0.0 ||
      observation_bar.low <= 0.0 || observation_bar.close <= 0.0)
     {
      Strategy_LogStateRejected(session_date_key,
                                "OBSERVATION_BAR_INVALID",
                                candidate_utc);
      return true;
     }

   Strategy_RecoverAttempt(cash_close_utc);
   if(g_session_attempted)
     {
      Strategy_LogStateRejected(session_date_key,
                                "SESSION_ATTEMPT_ALREADY_MADE",
                                candidate_utc);
      return true;
     }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
     {
      Strategy_LogStateRejected(session_date_key,
                                "ENTRY_TICK_UNAVAILABLE",
                                candidate_utc);
      return true;
     }
   if(!Strategy_IsFirstTradableTick(expected_entry_bar_broker, tick))
     {
      Strategy_LogStateRejected(session_date_key,
                                "NOT_FIRST_TRADABLE_ENTRY_TICK",
                                candidate_utc,
                                StringFormat("entry_bar_broker=%I64d;current_tick_msc=%I64u",
                                             (long)expected_entry_bar_broker,
                                             (ulong)tick.time_msc));
      return true;
     }

   double cash_open_mid = 0.0;
   double cash_close_mid = 0.0;
   if(!Strategy_FirstSessionMid(cash_open_broker, cash_close_broker, cash_open_mid))
     {
      Strategy_LogStateRejected(session_date_key,
                                "CASH_OPEN_TICK_MISSING",
                                candidate_utc);
      return true;
     }
   if(!Strategy_LastSessionMid(cash_open_broker, cash_close_broker, cash_close_mid))
     {
      Strategy_LogStateRejected(session_date_key,
                                "CASH_CLOSE_TICK_MISSING",
                                candidate_utc);
      return true;
     }
   cash_open_mid = Strategy_TickNormalizedPrice(cash_open_mid);
   cash_close_mid = Strategy_TickNormalizedPrice(cash_close_mid);
   if(cash_open_mid <= 0.0 || cash_close_mid <= 0.0 || cash_open_mid == cash_close_mid)
     {
      Strategy_LogStateRejected(session_date_key,
                                "CASH_RETURN_ZERO_OR_INVALID",
                                candidate_utc,
                                StringFormat("cash_open_mid=%.8f;cash_close_mid=%.8f",
                                             cash_open_mid,
                                             cash_close_mid));
      return true;
     }

   const double frozen_atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const datetime entry_tick_broker = (datetime)(tick.time_msc / 1000);
   const datetime entry_tick_utc = QM_BrokerToUTC(entry_tick_broker);
   datetime verified_exit_utc = 0;
   if(frozen_atr <= 0.0 || !MathIsValidNumber(frozen_atr))
     {
      Strategy_LogStateRejected(session_date_key,
                                "ATR_INVALID",
                                candidate_utc,
                                StringFormat("atr=%.8f", frozen_atr));
      return true;
     }
   if(entry_tick_utc <= 0 || !Strategy_BindClockExit(entry_tick_utc, verified_exit_utc))
     {
      Strategy_LogStateRejected(session_date_key,
                                "EXIT_CLOCK_BIND_FAILED",
                                candidate_utc,
                                StringFormat("entry_tick_broker=%I64d;entry_tick_utc=%I64d",
                                             (long)entry_tick_broker,
                                             (long)entry_tick_utc));
      return true;
     }

   g_pending_session_date_key = session_date_key;
   g_pending_side = (cash_close_mid > cash_open_mid) ? 1 : -1;
   g_pending_entry_bar_utc = entry_bar_utc;
   g_pending_entry_tick_msc = (ulong)tick.time_msc;
   g_pending_exit_utc = verified_exit_utc;
   g_pending_atr = frozen_atr;
   QM_LogEvent(QM_INFO,
               "ENTRY_CANDIDATE_READY",
               StringFormat("{\"symbol\":\"%s\",\"session_date\":%d,\"side\":\"%s\",\"candidate_utc\":%I64d,\"entry_tick_broker\":%I64d,\"entry_tick_utc\":%I64d,\"cash_open_mid\":%.8f,\"cash_close_mid\":%.8f,\"atr\":%.8f}",
                            QM_LoggerEscapeJson(_Symbol),
                            session_date_key,
                            g_pending_side > 0 ? "BUY" : "SELL",
                            (long)entry_bar_utc,
                            (long)entry_tick_broker,
                            (long)entry_tick_utc,
                            cash_open_mid,
                            cash_close_mid,
                            frozen_atr));
   return true;
  }

bool Strategy_TradeGeometryAndVolumeAllow(const double entry_price,
                                          const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(RISK_FIXED != 1000.0 || RISK_PERCENT != 0.0 || point <= 0.0 ||
      entry_price <= 0.0 || stop_price <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   if(stop_distance <= 0.0)
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

bool Strategy_InputsValid()
  {
   if(strategy_variant_id != "POSTCLOSE_CONT_BASELINE" ||
      strategy_signal_tf != PERIOD_M15 || strategy_atr_period != 14 ||
      strategy_atr_stop_mult != 1.0 || strategy_hold_minutes != 240 ||
      strategy_max_spread_points < 0)
      return false;
   return true;
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points < 0 || spread_points > strategy_max_spread_points);
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
   if(_Symbol == "GDAXI.DWX" && !g_xetra_calendar_ready)
      return true;
   if(_Symbol == "UK100.DWX" && !g_lse_calendar_ready)
      return true;
   return false;
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
   const datetime candidate_utc = g_pending_entry_bar_utc;
   if(g_pending_session_date_key <= 0 || candidate_utc <= 0 ||
      g_pending_entry_tick_msc == 0 || g_pending_exit_utc <= 0 ||
      g_pending_atr <= 0.0)
     {
      Strategy_LogEntryRejected("PENDING_CANDIDATE_INVALID", candidate_utc);
      return false;
     }
   if(g_session_attempted)
     {
      Strategy_LogEntryRejected("SESSION_ATTEMPT_ALREADY_MADE", candidate_utc);
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
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || (ulong)tick.time_msc != g_pending_entry_tick_msc ||
       tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
     {
      Strategy_LogEntryRejected("ENTRY_TICK_MISMATCH_OR_INVALID", candidate_utc);
      return false;
     }
   if(Strategy_WideSpread())
     {
      Strategy_LogEntryRejected("SPREAD_REJECTED", candidate_utc);
      return false;
     }

   const int session_date_key = g_pending_session_date_key;
   const bool is_long = (g_pending_side > 0);
   const double frozen_atr = g_pending_atr;
   const datetime verified_exit_utc = g_pending_exit_utc;
   g_session_attempted = true;
   g_pending_session_date_key = 0;
   g_pending_side = 0;
   g_pending_entry_bar_utc = 0;
   g_pending_entry_tick_msc = 0;
   g_pending_exit_utc = 0;
   g_pending_atr = 0.0;

   const double entry_price = is_long ? tick.ask : tick.bid;
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol,
                                                         is_long
                                                         ? entry_price - strategy_atr_stop_mult * frozen_atr
                                                         : entry_price + strategy_atr_stop_mult * frozen_atr);
   if(stop_price <= 0.0 || (is_long && stop_price >= entry_price) ||
       (!is_long && stop_price <= entry_price) ||
       !Strategy_TradeGeometryAndVolumeAllow(entry_price, stop_price))
     {
      Strategy_LogEntryRejected("TRADE_GEOMETRY_OR_VOLUME_REJECTED", candidate_utc);
      return false;
     }

   req.type = is_long ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.tp = 0.0;
   req.reason = is_long ? "POSTCLOSE_CONT_LONG" : "POSTCLOSE_CONT_SHORT";
   g_active_exit_broker = QM_UTCToBroker(verified_exit_utc);
   if(g_active_exit_broker <= 0)
     {
      Strategy_LogEntryRejected("EXIT_CLOCK_INVALID", candidate_utc);
      return false;
     }
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"symbol\":\"%s\",\"side\":\"%s\",\"candidate_utc\":%I64d,\"entry\":%.8f,\"stop\":%.8f,\"exit_broker\":%I64d}",
                            QM_LoggerEscapeJson(_Symbol),
                            is_long ? "BUY" : "SELL",
                            (long)candidate_utc,
                            entry_price,
                            stop_price,
                            (long)g_active_exit_broker));
   QM_LogEvent(QM_INFO,
               "SESSION_ENTRY_ARMED",
               StringFormat("{\"symbol\":\"%s\",\"session_date\":%d,\"session_source\":\"%s\",\"exit_utc\":%I64d}",
                            _Symbol,
                            session_date_key,
                             _Symbol == "GDAXI.DWX"
                             ? "XETRA_EUROPE_BERLIN_CALENDAR"
                             : "LSE_EUROPE_LONDON_CALENDAR",
                            (long)verified_exit_utc));
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      g_active_exit_broker = 0;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(open_time))
      return false;
   if(g_active_exit_broker <= 0)
     {
      const int session_date_key = Strategy_CashDateKeyForBrokerTime(open_time);
      datetime cash_open_broker = 0;
      datetime cash_close_broker = 0;
      datetime cash_open_utc = 0;
      datetime cash_close_utc = 0;
      if(!Strategy_ResolveCashSession(session_date_key,
                                      cash_open_broker,
                                      cash_close_broker,
                                      cash_open_utc,
                                      cash_close_utc) ||
         open_time < cash_close_broker + 15 * 60 ||
         open_time >= cash_close_broker + 30 * 60)
         return true;
      const datetime open_utc = QM_BrokerToUTC(open_time);
      datetime verified_exit_utc = 0;
      if(!Strategy_BindClockExit(open_utc, verified_exit_utc))
         return true;
      g_active_exit_broker = QM_UTCToBroker(verified_exit_utc);
     }
   return (g_active_exit_broker > 0 && TimeCurrent() >= g_active_exit_broker);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The approved baseline retains the framework default high-impact pause.
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

   const int expected_slot = (_Symbol == "GDAXI.DWX") ? 0 :
                             ((_Symbol == "UK100.DWX") ? 1 : -1);
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

   const bool lse_calendar_required = (_Symbol == "UK100.DWX");
   g_lse_calendar_ready =
      (!lse_calendar_required || QM_LondonLseCashCalendarLoad());
   QM_LogEvent(g_lse_calendar_ready ? QM_INFO : QM_ERROR,
               "LSE_CASH_CALENDAR_STATE",
               StringFormat("{\"required\":%s,\"ready\":%s,\"file\":\"%s\",\"coverage_start\":%d,\"coverage_end\":%d,\"expected_sha256\":\"%s\",\"actual_sha256\":\"%s\",\"manifest_sha256\":\"%s\",\"error\":\"%s\",\"clock_source\":\"EUROPE_LONDON_TO_UTC_TO_BROKER\"}",
                            lse_calendar_required ? "true" : "false",
                            g_lse_calendar_ready ? "true" : "false",
                            QM_LoggerEscapeJson(QM_LONDON_LSE_CASH_FILE),
                            QM_LONDON_LSE_CASH_COVERAGE_START,
                            QM_LONDON_LSE_CASH_COVERAGE_END,
                            QM_LONDON_LSE_CASH_SHA256,
                            QM_LondonLseCashCalendarActualSha256(),
                            QM_LONDON_CALENDAR_MANIFEST_SHA256,
                            QM_LoggerEscapeJson(
                               QM_LondonLseCashCalendarLastError())));
   QM_LogEvent(QM_WARN,
               "STRATEGY_SETUP_COVERAGE_GAP",
               StringFormat("{\"symbol\":\"%s\",\"broker_symbol_session_metadata\":\"unavailable\",\"daily_break_rollover_metadata\":\"unavailable\",\"financing_metadata\":\"unavailable\",\"lse_calendar\":\"%s\",\"effect\":\"broker_safety_metadata_gap_logged_no_synthetic_runtime_gate\"}",
                            QM_LoggerEscapeJson(_Symbol),
                            !lse_calendar_required
                            ? "not_required"
                            : (g_lse_calendar_ready ? "ready" : "load_failed")));
   const bool route_calendar_ready =
      (_Symbol == "GDAXI.DWX") ? g_xetra_calendar_ready :
      ((_Symbol == "UK100.DWX") ? g_lse_calendar_ready : false);
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"symbol\":\"%s\",\"period\":%d,\"signal_tf\":%d,\"route_ok\":%s,\"magic_slot\":%d,\"expected_slot\":%d,\"inputs_valid\":%s,\"route_calendar_ready\":%s,\"legacy_cash_open_broker\":\"%02d:%02d\",\"legacy_cash_close_broker\":\"%02d:%02d\",\"legacy_broker_inputs_ignored\":true,\"hold_minutes\":%d,\"tick_time_basis\":\"dwx_broker_label\",\"gdaxi_clock_source\":\"XETRA_EUROPE_BERLIN_TO_UTC_TO_BROKER\",\"uk100_clock_source\":\"LSE_EUROPE_LONDON_TO_UTC_TO_BROKER\"}",
                            QM_LoggerEscapeJson(_Symbol),
                            (int)_Period,
                            (int)strategy_signal_tf,
                            Strategy_IsRoutedSymbol(_Symbol) ? "true" : "false",
                            qm_magic_slot_offset,
                            expected_slot,
                            Strategy_InputsValid() ? "true" : "false",
                            route_calendar_ready ? "true" : "false",
                            strategy_cash_open_hour_broker,
                            strategy_cash_open_minute_broker,
                            strategy_cash_close_hour_broker,
                            strategy_cash_close_minute_broker,
                            strategy_hold_minutes));
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

   // Freeze the cash anchors and exactly one completed post-close observation
   // before the central news gate. A blocked intended entry is never delayed.
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
