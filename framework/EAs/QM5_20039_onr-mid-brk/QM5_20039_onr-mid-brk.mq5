#property strict
#property version   "5.0"
#property description "QM5_20039 overnight-range midpoint-side breakout"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20039_onr-mid-brk, G0 APPROVED 2026-07-22.
// The midpoint side filter is an explicitly UNVERIFIED QM repair hypothesis,
// implemented literally without representing it as a source-proven edge.

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
input int    qm_ea_id                   = 20039;
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
input string strategy_variant_id        = "ONR_MID_BRK_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input int    strategy_overnight_start_hour_new_york = 18;
input int    strategy_overnight_start_minute_new_york = 0;
input int    strategy_cash_open_hour_new_york = 9;
input int    strategy_cash_open_minute_new_york = 30;
input int    strategy_cash_close_hour_new_york = 16;
input int    strategy_cash_close_minute_new_york = 0;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points = 0;

int      g_quote_session_key = 0;
datetime g_overnight_start_utc = 0;
datetime g_cash_open_utc = 0;
datetime g_cash_close_utc = 0;
bool     g_range_failed = false;
bool     g_range_has_quote = false;
bool     g_range_frozen = false;
double   g_overnight_high = 0.0;
double   g_overnight_low = 0.0;
double   g_overnight_mid = 0.0;
int      g_armed_side = 0;
bool     g_cash_date_resolved = false;
bool     g_attempted = false;
datetime g_breakout_through_utc = 0;
int      g_pending_side = 0;
datetime g_pending_entry_utc = 0;
datetime g_active_close_broker = 0;
int      g_state_reject_mask = 0;
bool     g_cash_state_ready_logged = false;

const int STRATEGY_STATE_REJECT_OVERNIGHT = 1;
const int STRATEGY_STATE_REJECT_FIRST_RTH = 2;
const int STRATEGY_STATE_REJECT_CASH = 4;
const int STRATEGY_STATE_REJECT_CLOCK = 8;

void Strategy_LogStateRejected(const int reject_flag,
                               const string detail,
                               const int cash_date_key,
                               const datetime observed_utc,
                               const string diagnostics = "")
  {
   // Quote-state evaluation runs on every tick.  Emit each state failure at
   // most once per cash date so recovery evidence cannot become a log bomb.
   if((g_state_reject_mask & reject_flag) != 0)
      return;
   g_state_reject_mask |= reject_flag;
   QM_LogEvent(QM_WARN,
               "ENTRY_REJECTED",
               StringFormat("{\"result\":\"STRATEGY_STATE_REJECTED\",\"symbol\":\"%s\",\"reason\":\"ONR_MID_BRK\",\"detail\":\"%s\",\"cash_date_key\":%d,\"observed_utc\":%I64d,\"overnight_start_utc\":%I64d,\"cash_open_utc\":%I64d,\"cash_close_utc\":%I64d%s}",
                            QM_LoggerEscapeJson(_Symbol),
                            QM_LoggerEscapeJson(detail),
                            cash_date_key,
                            (long)observed_utc,
                            (long)g_overnight_start_utc,
                            (long)g_cash_open_utc,
                            (long)g_cash_close_utc,
                            diagnostics));
  }

bool Strategy_BrokerTickToUtcMsc(const MqlTick &tick,
                                 datetime &utc,
                                 ulong &utc_msc)
  {
   utc = 0;
   utc_msc = 0;
   if(tick.time_msc <= 0)
      return false;
   const datetime broker_time = (datetime)(tick.time_msc / 1000);
   utc = QM_BrokerToUTC(broker_time);
   if(utc <= 0 || QM_UTCToBroker(utc) != broker_time)
      return false;
   utc_msc = (ulong)utc * 1000 + (ulong)(tick.time_msc % 1000);
   return (utc_msc > 0);
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

datetime Strategy_DateNoon(const int date_key)
  {
   if(date_key < 19000101)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   parts.hour = 12;
   return StructToTime(parts);
  }

int Strategy_ShiftDateKey(const int date_key, const int days)
  {
   const datetime noon = Strategy_DateNoon(date_key);
   return (noon > 0) ? Strategy_DateKey(noon + days * 24 * 60 * 60) : 0;
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

bool Strategy_ResolveSessionForCashDate(const int cash_date_key,
                                        datetime &overnight_start_utc,
                                        datetime &cash_open_utc,
                                        datetime &cash_close_utc)
  {
   const int overnight_date_key = Strategy_ShiftDateKey(cash_date_key, -1);
   overnight_start_utc = Strategy_NewYorkLocalToUtc(
      overnight_date_key,
      strategy_overnight_start_hour_new_york,
      strategy_overnight_start_minute_new_york);
   cash_open_utc = Strategy_NewYorkLocalToUtc(cash_date_key,
                                              strategy_cash_open_hour_new_york,
                                              strategy_cash_open_minute_new_york);
   cash_close_utc = Strategy_NewYorkLocalToUtc(cash_date_key,
                                               strategy_cash_close_hour_new_york,
                                               strategy_cash_close_minute_new_york);
   return (overnight_start_utc > 0 && cash_open_utc > overnight_start_utc &&
           cash_close_utc > cash_open_utc &&
           cash_open_utc - overnight_start_utc >= 12 * 60 * 60 &&
           cash_open_utc - overnight_start_utc <= 18 * 60 * 60 &&
           cash_close_utc - cash_open_utc == 390 * 60 &&
           Strategy_IsUtcWeekday(cash_open_utc));
  }

bool Strategy_ResolveSessionForUtc(const datetime utc,
                                   int &cash_date_key,
                                   datetime &overnight_start_utc,
                                   datetime &cash_open_utc,
                                   datetime &cash_close_utc)
  {
   cash_date_key = 0;
   const datetime local = Strategy_NewYorkLocal(utc);
   MqlDateTime parts;
   if(utc <= 0 || local <= 0 || !TimeToStruct(local, parts))
      return false;
   const int local_date_key = Strategy_DateKey(local);
   const int local_minutes = parts.hour * 60 + parts.min;
   const int overnight_minutes = strategy_overnight_start_hour_new_york * 60 +
                                 strategy_overnight_start_minute_new_york;
   cash_date_key = (local_minutes >= overnight_minutes)
                   ? Strategy_ShiftDateKey(local_date_key, 1)
                   : local_date_key;
   if(!Strategy_ResolveSessionForCashDate(cash_date_key,
                                          overnight_start_utc,
                                          cash_open_utc,
                                          cash_close_utc))
      return false;
   return (utc >= overnight_start_utc && utc < cash_close_utc);
  }

bool Strategy_IsRoutedSymbol(const string symbol)
  {
   return (symbol == "SP500.DWX" || symbol == "NDX.DWX");
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

void Strategy_RecoverAttempt(const datetime cash_open_utc)
  {
   g_attempted = false;
   const datetime from_broker = QM_UTCToBroker(cash_open_utc);
   const datetime now_broker = TimeCurrent();
   if(from_broker <= 0 || now_broker <= 0)
     {
      g_attempted = true;
      return;
     }
   // The quote session is initialized during the overnight window, before the
   // cash open.  There cannot be an attempt in the still-future cash session,
   // and HistorySelect() must never be called with a future start time.
   if(now_broker <= from_broker)
      return;
   if(!HistorySelect(from_broker, now_broker))
     {
      g_attempted = true;
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
         g_attempted = true;
         return;
        }
     }
   for(int i = 0; i < HistoryOrdersTotal(); ++i)
     {
      const ulong order = HistoryOrderGetTicket(i);
      if(order == 0 || (int)HistoryOrderGetInteger(order, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(order, ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(order, ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL)
        {
         g_attempted = true;
         return;
        }
     }
  }

void Strategy_ResetQuoteSession(const int cash_date_key,
                                const datetime overnight_start_utc,
                                const datetime cash_open_utc,
                                const datetime cash_close_utc)
  {
   g_quote_session_key = cash_date_key;
   g_overnight_start_utc = overnight_start_utc;
   g_cash_open_utc = cash_open_utc;
   g_cash_close_utc = cash_close_utc;
   g_range_failed = false;
   g_range_has_quote = false;
   g_range_frozen = false;
   g_overnight_high = 0.0;
   g_overnight_low = 0.0;
   g_overnight_mid = 0.0;
   g_armed_side = 0;
   g_cash_date_resolved = false;
   g_breakout_through_utc = 0;
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   g_state_reject_mask = 0;
   g_cash_state_ready_logged = false;
   Strategy_RecoverAttempt(cash_open_utc);
  }

bool Strategy_TickMid(const MqlTick &tick, double &mid)
  {
   mid = 0.0;
   if(tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      return false;
   mid = 0.5 * (tick.bid + tick.ask);
   return (mid > 0.0 && MathIsValidNumber(mid));
  }

void Strategy_AccumulateMid(const double mid)
  {
   if(!g_range_has_quote)
     {
      g_overnight_high = mid;
      g_overnight_low = mid;
      g_range_has_quote = true;
      return;
     }
   g_overnight_high = MathMax(g_overnight_high, mid);
   g_overnight_low = MathMin(g_overnight_low, mid);
  }

bool Strategy_RebuildOvernightTicks(const ulong to_msc)
  {
   // .DWX ticks are imported with broker-clock epoch labels.  Session
   // membership is resolved in UTC, then translated back only at the tick-DB
   // query boundary.
   const datetime start_broker = QM_UTCToBroker(g_overnight_start_utc);
   if(start_broker <= 0)
      return false;
   const ulong start_msc = (ulong)start_broker * 1000;
   if(to_msc < start_msc)
      return true;
   const ulong chunk_width = 30 * 60 * 1000;
   ulong cursor = start_msc;
   long previous_msc = 0;
   while(cursor <= to_msc)
     {
      ulong chunk_end = cursor + chunk_width - 1;
      if(chunk_end < cursor || chunk_end > to_msc)
         chunk_end = to_msc;
      MqlTick ticks[];
      const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, cursor, chunk_end);
      if(copied < 0)
         return false;
      for(int i = 0; i < copied; ++i)
        {
         if(previous_msc > 0 && ticks[i].time_msc < previous_msc)
            return false;
         previous_msc = ticks[i].time_msc;
         double mid = 0.0;
         if(Strategy_TickMid(ticks[i], mid))
            Strategy_AccumulateMid(mid);
        }
      if(chunk_end == to_msc)
         break;
      cursor = chunk_end + 1;
     }
   return g_range_has_quote;
  }

bool Strategy_FirstRthMid(const ulong available_to_msc,
                          double &rth_mid)
  {
   rth_mid = 0.0;
   const datetime open_broker = QM_UTCToBroker(g_cash_open_utc);
   const datetime close_broker = QM_UTCToBroker(g_cash_close_utc);
   if(open_broker <= 0 || close_broker <= open_broker)
      return false;
   ulong cursor = (ulong)open_broker * 1000;
   const ulong close_msc = (ulong)close_broker * 1000;
   const ulong stop_msc = (available_to_msc < close_msc) ? available_to_msc : close_msc - 1;
   const ulong chunk_width = 5 * 60 * 1000;
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
         if(Strategy_TickMid(ticks[i], rth_mid))
            return true;
        }
      if(chunk_end == stop_msc)
         break;
      cursor = chunk_end + 1;
     }
   return false;
  }

double Strategy_TickNormalizedPrice(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, MathRound(price / tick_size) * tick_size);
  }

bool Strategy_FreezeRangeAndSide(const ulong available_to_msc,
                                 string &reject_detail)
  {
   reject_detail = "";
   if(!g_range_has_quote || g_overnight_high <= g_overnight_low)
     {
      reject_detail = "OVERNIGHT_TICKS_INVALID";
      return false;
     }
   g_overnight_high = Strategy_TickNormalizedPrice(g_overnight_high);
   g_overnight_low = Strategy_TickNormalizedPrice(g_overnight_low);
   g_overnight_mid = Strategy_TickNormalizedPrice(0.5 * (g_overnight_high + g_overnight_low));
   if(g_overnight_high <= g_overnight_low || g_overnight_mid <= g_overnight_low ||
      g_overnight_mid >= g_overnight_high)
     {
      reject_detail = "OVERNIGHT_TICKS_INVALID";
      return false;
     }

   double rth_mid = 0.0;
   if(!Strategy_FirstRthMid(available_to_msc, rth_mid))
     {
      reject_detail = "FIRST_RTH_MID_MISSING";
      return false;
     }
   rth_mid = Strategy_TickNormalizedPrice(rth_mid);
   g_range_frozen = true;
   if(rth_mid <= g_overnight_low || rth_mid >= g_overnight_high || rth_mid == g_overnight_mid)
     {
      g_cash_date_resolved = true;
      return true;
     }
   g_armed_side = (rth_mid > g_overnight_mid) ? 1 : -1;
   return true;
  }

bool Strategy_UpdateQuoteState()
  {
   if(!SymbolIsSynchronized(_Symbol))
      return false;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.time_msc <= 0)
      return false;
   datetime utc = 0;
   ulong tick_utc_msc = 0;
   if(!Strategy_BrokerTickToUtcMsc(tick, utc, tick_utc_msc))
     {
      Strategy_LogStateRejected(
         STRATEGY_STATE_REJECT_CLOCK,
         "SESSION_CLOCK_INVALID",
         g_quote_session_key,
         0,
         StringFormat(",\"tick_broker_msc\":%I64d", tick.time_msc));
      return false;
     }
   int cash_date_key = 0;
   datetime overnight_start_utc = 0;
   datetime cash_open_utc = 0;
   datetime cash_close_utc = 0;
   if(!Strategy_ResolveSessionForUtc(utc,
                                     cash_date_key,
                                     overnight_start_utc,
                                     cash_open_utc,
                                     cash_close_utc))
      return true;

   if(g_quote_session_key != cash_date_key ||
      g_overnight_start_utc != overnight_start_utc ||
      g_cash_open_utc != cash_open_utc ||
      g_cash_close_utc != cash_close_utc)
     {
      Strategy_ResetQuoteSession(cash_date_key,
                                 overnight_start_utc,
                                 cash_open_utc,
                                 cash_close_utc);
      ulong rebuild_to = (ulong)tick.time_msc - 1;
      const datetime open_broker = QM_UTCToBroker(g_cash_open_utc);
      if(open_broker <= 0)
        {
         g_range_failed = true;
         Strategy_LogStateRejected(
            STRATEGY_STATE_REJECT_CLOCK,
            "SESSION_CLOCK_INVALID",
            cash_date_key,
            utc,
            StringFormat(",\"state_detail\":\"cash_open_conversion_failed\",\"cash_open_utc\":%I64d",
                         (long)g_cash_open_utc));
         return false;
        }
      const ulong open_msc = (ulong)open_broker * 1000;
      if(rebuild_to >= open_msc)
         rebuild_to = open_msc - 1;
      if(!Strategy_RebuildOvernightTicks(rebuild_to))
        {
         g_range_failed = true;
         Strategy_LogStateRejected(
            STRATEGY_STATE_REJECT_OVERNIGHT,
            "OVERNIGHT_TICKS_INVALID",
            cash_date_key,
            utc,
            StringFormat(",\"state_detail\":\"rebuild_failed\",\"tick_broker_msc\":%I64d,\"tick_utc_msc\":%I64d,\"rebuild_to_msc\":%I64d",
                         tick.time_msc,
                         (long)tick_utc_msc,
                         (long)rebuild_to));
        }
     }

   if(g_range_failed)
      return false;
   if(utc < g_cash_open_utc)
     {
      double mid = 0.0;
      if(!Strategy_TickMid(tick, mid))
        {
         g_range_failed = true;
         Strategy_LogStateRejected(
            STRATEGY_STATE_REJECT_OVERNIGHT,
            "OVERNIGHT_TICKS_INVALID",
            cash_date_key,
            utc,
            StringFormat(",\"state_detail\":\"current_quote_invalid\",\"bid\":%.8f,\"ask\":%.8f",
                         tick.bid,
                         tick.ask));
         return false;
        }
      Strategy_AccumulateMid(mid);
      return true;
     }

   string freeze_reject = "";
   if(!g_range_frozen &&
      !Strategy_FreezeRangeAndSide((ulong)tick.time_msc, freeze_reject))
     {
      g_range_failed = true;
      const int reject_flag = (freeze_reject == "FIRST_RTH_MID_MISSING")
                              ? STRATEGY_STATE_REJECT_FIRST_RTH
                              : STRATEGY_STATE_REJECT_OVERNIGHT;
      Strategy_LogStateRejected(
         reject_flag,
         freeze_reject,
         cash_date_key,
         utc,
         StringFormat(",\"state_detail\":\"freeze_failed\",\"tick_broker_msc\":%I64d,\"tick_utc_msc\":%I64d,\"range_has_quote\":%s,\"overnight_high\":%.8f,\"overnight_low\":%.8f",
                      tick.time_msc,
                      (long)tick_utc_msc,
                      g_range_has_quote ? "true" : "false",
                      g_overnight_high,
                      g_overnight_low));
      return false;
     }
   if(g_range_frozen && !g_cash_state_ready_logged)
     {
      g_cash_state_ready_logged = true;
      QM_LogEvent(QM_INFO,
                  "CASH_STATE_READY",
                  StringFormat("{\"symbol\":\"%s\",\"cash_date_key\":%d,\"observed_utc\":%I64d,\"overnight_high\":%.8f,\"overnight_low\":%.8f,\"overnight_mid\":%.8f,\"armed_side\":%d,\"cash_date_resolved\":%s}",
                               QM_LoggerEscapeJson(_Symbol),
                               cash_date_key,
                               (long)utc,
                               g_overnight_high,
                               g_overnight_low,
                               g_overnight_mid,
                               g_armed_side,
                               g_cash_date_resolved ? "true" : "false"));
     }
   return true;
  }

bool Strategy_ProcessCashBar(const MqlRates &bar,
                             const datetime bar_utc,
                             const datetime next_open_utc,
                             const bool allow_entry)
  {
   if(bar.close <= 0.0 || !MathIsValidNumber(bar.close))
      return false;

   g_breakout_through_utc = bar_utc;
   if(g_cash_date_resolved || g_attempted || g_armed_side == 0)
      return true;

   bool armed_break = false;
   bool opposite_break = false;
   if(g_armed_side > 0)
     {
      armed_break = (bar.close > g_overnight_high);
      opposite_break = (bar.close < g_overnight_low);
     }
   else
     {
      armed_break = (bar.close < g_overnight_low);
      opposite_break = (bar.close > g_overnight_high);
     }

   // Only closes count: a wick through either boundary has no state effect.
   // The first qualifying close resolves the cash date, so a news pause can
   // suppress this next-open attempt but can never defer it to a later bar.
   if(opposite_break)
     {
      g_cash_date_resolved = true;
      return true;
     }
   if(!armed_break)
      return true;

   g_cash_date_resolved = true;
   if(!allow_entry || g_quote_session_key <= 0 ||
      next_open_utc >= g_cash_close_utc)
      return true;
   datetime open_time = 0;
   if(Strategy_FindOurPosition(open_time))
      return true;
   g_pending_side = g_armed_side;
   g_pending_entry_utc = next_open_utc;
   return true;
  }

bool Strategy_RebuildCashBars(const datetime current_open_utc)
  {
   g_breakout_through_utc = 0;
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   const datetime start_broker = QM_UTCToBroker(g_cash_open_utc);
   const datetime stop_broker = QM_UTCToBroker(current_open_utc) - 1;
   if(start_broker <= 0 || stop_broker < start_broker)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded one-time cash-session rebuild behind QM_IsNewBar.
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
      if(bar_utc < g_cash_open_utc || bar_utc >= g_cash_close_utc ||
         bar_utc >= current_open_utc)
         continue;
      if(previous_utc > 0 && bar_utc != previous_utc + 5 * 60)
         return false;
      const bool is_latest = (bar_utc + 5 * 60 == current_open_utc);
      if(!Strategy_ProcessCashBar(rates[i], bar_utc, current_open_utc, is_latest))
         return false;
      previous_utc = bar_utc;
      ++processed;
     }
   return (processed > 0 && g_breakout_through_utc + 5 * 60 == current_open_utc);
  }

bool Strategy_AdvanceBreakoutOnNewBar()
  {
   g_pending_side = 0;
   g_pending_entry_utc = 0;
   if(!Strategy_IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      strategy_signal_tf != PERIOD_M5)
      return false;

   MqlRates current_bar;
   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 0, current_bar) ||
      !QM_ReadBar(_Symbol, strategy_signal_tf, 1, closed_bar))
      return false;
   const datetime current_open_utc = QM_BrokerToUTC(current_bar.time);
   const datetime closed_bar_utc = QM_BrokerToUTC(closed_bar.time);
   const int cash_date_key = Strategy_DateKey(Strategy_NewYorkLocal(closed_bar_utc));
   datetime overnight_start_utc = 0;
   datetime cash_open_utc = 0;
   datetime cash_close_utc = 0;
   if(!Strategy_ResolveSessionForCashDate(cash_date_key,
                                          overnight_start_utc,
                                          cash_open_utc,
                                          cash_close_utc) ||
      closed_bar_utc < cash_open_utc || closed_bar_utc >= cash_close_utc)
      return false;

   if(g_quote_session_key != cash_date_key ||
      g_overnight_start_utc != overnight_start_utc ||
      g_cash_open_utc != cash_open_utc || g_cash_close_utc != cash_close_utc ||
      !g_range_frozen || g_range_failed)
     {
      Strategy_LogStateRejected(
         STRATEGY_STATE_REJECT_CASH,
         "CASH_STATE_NOT_READY",
         cash_date_key,
         current_open_utc,
         StringFormat(",\"state_detail\":\"quote_state_mismatch\",\"quote_session_key\":%d,\"range_has_quote\":%s,\"range_frozen\":%s,\"range_failed\":%s,\"armed_side\":%d",
                      g_quote_session_key,
                      g_range_has_quote ? "true" : "false",
                      g_range_frozen ? "true" : "false",
                      g_range_failed ? "true" : "false",
                      g_armed_side));
      return false;
     }

   if(g_breakout_through_utc == 0 ||
      g_breakout_through_utc + 5 * 60 != closed_bar_utc)
     {
      const bool rebuilt = Strategy_RebuildCashBars(current_open_utc);
      if(!rebuilt)
         Strategy_LogStateRejected(
            STRATEGY_STATE_REJECT_CASH,
            "CASH_STATE_NOT_READY",
            cash_date_key,
            current_open_utc,
            StringFormat(",\"state_detail\":\"cash_bar_rebuild_failed\",\"closed_bar_utc\":%I64d,\"breakout_through_utc\":%I64d",
                         (long)closed_bar_utc,
                         (long)g_breakout_through_utc));
      return rebuilt;
     }

   const bool advanced = Strategy_ProcessCashBar(closed_bar,
                                                  closed_bar_utc,
                                                  current_open_utc,
                                                  current_open_utc < cash_close_utc);
   if(!advanced)
      Strategy_LogStateRejected(
         STRATEGY_STATE_REJECT_CASH,
         "CASH_STATE_NOT_READY",
         cash_date_key,
         current_open_utc,
         StringFormat(",\"state_detail\":\"cash_bar_advance_failed\",\"closed_bar_utc\":%I64d",
                      (long)closed_bar_utc));
   return advanced;
  }

bool Strategy_TradeGeometryAndVolumeAllow(const double entry_price,
                                          const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(RISK_FIXED != 1000.0 || RISK_PERCENT != 0.0 ||
      point <= 0.0 || entry_price <= 0.0 || stop_price <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
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
   return (strategy_variant_id == "ONR_MID_BRK_BASELINE" &&
           strategy_signal_tf == PERIOD_M5 &&
           strategy_overnight_start_hour_new_york == 18 &&
           strategy_overnight_start_minute_new_york == 0 &&
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
               StringFormat("{\"result\":\"STRATEGY_HOOK_REJECTED\",\"symbol\":\"%s\",\"reason\":\"ONR_MID_BRK\",\"detail\":\"%s\",\"candidate_utc\":%I64d}",
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
   return !Strategy_UpdateQuoteState();
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
   if(candidate_utc <= 0 || g_quote_session_key <= 0 ||
      candidate_utc >= g_cash_close_utc)
     {
      Strategy_LogEntryRejected("PENDING_CANDIDATE_INVALID", candidate_utc);
      return false;
     }
   if(g_attempted)
     {
      Strategy_LogEntryRejected("ATTEMPT_ALREADY_MADE", candidate_utc);
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
   g_attempted = true;
   g_pending_side = 0;
   g_pending_entry_utc = 0;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
     {
      Strategy_LogEntryRejected("MARKET_QUOTE_INVALID", candidate_utc);
      return false;
     }
   const double entry_price = is_long ? tick.ask : tick.bid;
   const double frozen_midpoint = Strategy_TickNormalizedPrice(g_overnight_mid);
   // The card requires the actual market fill to remain on the risk side of
   // the frozen midpoint; equality has zero defined risk and therefore fails.
   if(frozen_midpoint <= 0.0 ||
       (is_long && entry_price <= frozen_midpoint) ||
       (!is_long && entry_price >= frozen_midpoint))
     {
      Strategy_LogEntryRejected("MIDPOINT_GEOMETRY_INVALID", candidate_utc);
      return false;
     }
   if(Strategy_WideSpread())
     {
      Strategy_LogEntryRejected("SPREAD_REJECTED", candidate_utc);
      return false;
     }
   if(!Strategy_TradeGeometryAndVolumeAllow(entry_price, frozen_midpoint))
     {
      Strategy_LogEntryRejected("TRADE_GEOMETRY_OR_VOLUME_REJECTED", candidate_utc);
      return false;
     }

   req.type = is_long ? QM_BUY : QM_SELL;
   req.sl = frozen_midpoint;
   req.tp = 0.0;
   req.reason = is_long ? "ONR_MID_BRK_LONG" : "ONR_MID_BRK_SHORT";
   g_active_close_broker = QM_UTCToBroker(g_cash_close_utc);
   if(g_active_close_broker <= 0)
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
                            frozen_midpoint,
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
      const int cash_date_key = Strategy_DateKey(Strategy_NewYorkLocal(open_utc));
      datetime overnight_start_utc = 0;
      datetime cash_open_utc = 0;
      datetime cash_close_utc = 0;
      if(!Strategy_ResolveSessionForCashDate(cash_date_key,
                                             overnight_start_utc,
                                             cash_open_utc,
                                             cash_close_utc))
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

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"routed\":%s,\"period\":%d,\"signal_tf\":%d,\"inputs_valid\":%s,\"variant\":\"%s\",\"overnight_start_new_york\":\"%02d:%02d\",\"cash_open_new_york\":\"%02d:%02d\",\"cash_close_new_york\":\"%02d:%02d\",\"max_spread_points\":%d,\"risk_fixed\":%.2f,\"risk_percent\":%.8f,\"state_clock\":\"BROKER_TO_UTC\",\"tick_db_clock\":\"BROKER\"}",
                            Strategy_IsRoutedSymbol(_Symbol) ? "true" : "false",
                            (int)_Period,
                            (int)strategy_signal_tf,
                            Strategy_InputsValid() ? "true" : "false",
                            QM_LoggerEscapeJson(strategy_variant_id),
                            strategy_overnight_start_hour_new_york,
                            strategy_overnight_start_minute_new_york,
                            strategy_cash_open_hour_new_york,
                            strategy_cash_open_minute_new_york,
                            strategy_cash_close_hour_new_york,
                            strategy_cash_close_minute_new_york,
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

   // Resolve the first closed-bar breakout before the central news gate. A
   // blocked next-open entry is discarded, never shifted to a later bar.
   const bool strategy_new_bar = QM_IsNewBar();
   if(strategy_new_bar)
      Strategy_AdvanceBreakoutOnNewBar();

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
