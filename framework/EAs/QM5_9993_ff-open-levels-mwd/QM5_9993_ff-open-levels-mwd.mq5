#property strict
#property version   "5.0"
#property description "QM5_9993 FF Open Levels MWD"

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
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 9993;
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
input int    strategy_rsi_period        = 14;
input int    strategy_atr_period        = 14;
input double strategy_touch_atr_mult    = 0.15;
input double strategy_rsi_midline       = 50.0;
input double strategy_min_stop_atr      = 1.0;
input double strategy_max_stop_atr      = 2.5;
input double strategy_fallback_rr       = 1.5;
input int    strategy_time_stop_bars    = 24;
input double strategy_max_spread_atr    = 0.25;

#define QM_PERIOD_DAY   1
#define QM_PERIOD_WEEK  2
#define QM_PERIOD_MONTH 3

int    g_cached_day_key   = -1;
int    g_cached_week_key  = -1;
int    g_cached_month_key = -1;
double g_dop              = 0.0;
double g_wop              = 0.0;
double g_mop              = 0.0;
double g_prev_day_high    = 0.0;
double g_prev_day_low     = 0.0;
double g_week_high        = 0.0;
double g_week_low         = 0.0;

int UtcDayKey(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

datetime UtcDayStart(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime UtcWeekStart(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(UtcDayStart(utc_time), dt);
   const int days_from_monday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   return StructToTime(dt) - days_from_monday * 86400;
  }

int UtcWeekKey(const datetime utc_time)
  {
   return UtcDayKey(UtcWeekStart(utc_time));
  }

int UtcMonthKey(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   return dt.year * 100 + dt.mon;
  }

bool UtcPeriodMatches(const datetime utc_time, const int period_kind, const int period_key)
  {
   if(period_kind == QM_PERIOD_DAY)
      return UtcDayKey(utc_time) == period_key;
   if(period_kind == QM_PERIOD_WEEK)
      return UtcWeekKey(utc_time) == period_key;
   if(period_kind == QM_PERIOD_MONTH)
      return UtcMonthKey(utc_time) == period_key;
   return false;
  }

int OldestClosedShiftInUtcPeriod(const int period_kind,
                                 const int period_key,
                                 const int max_shift)
  {
   int oldest_shift = 0;
   bool found = false;
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const datetime broker_t = iTime(_Symbol, PERIOD_M30, shift); // perf-allowed: bounded closed-bar UTC period scan for open-level strategy
      if(broker_t <= 0)
         break;

      const datetime utc_t = QM_BrokerToUTC(broker_t);
      if(!UtcPeriodMatches(utc_t, period_kind, period_key))
        {
         if(found)
            break;
         continue;
        }

      oldest_shift = shift;
      found = true;
     }
   return oldest_shift;
  }

double OpenForUtcPeriod(const int period_kind,
                        const int period_key,
                        const int max_shift)
  {
   const int shift = OldestClosedShiftInUtcPeriod(period_kind, period_key, max_shift);
   if(shift <= 0)
      return 0.0;
   return iOpen(_Symbol, PERIOD_M30, shift); // perf-allowed: open of first closed UTC period bar, computed only on period rollover
  }

bool RangeForUtcPeriod(const int period_kind,
                       const int period_key,
                       const int max_shift,
                       double &out_high,
                       double &out_low)
  {
   out_high = 0.0;
   out_low = 0.0;
   bool found = false;
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const datetime broker_t = iTime(_Symbol, PERIOD_M30, shift); // perf-allowed: bounded closed-bar UTC range scan for card key levels
      if(broker_t <= 0)
         break;

      const datetime utc_t = QM_BrokerToUTC(broker_t);
      if(!UtcPeriodMatches(utc_t, period_kind, period_key))
        {
         if(found)
            break;
         continue;
        }

      const double high = iHigh(_Symbol, PERIOD_M30, shift); // perf-allowed: bounded closed-bar UTC range scan for card key levels
      const double low = iLow(_Symbol, PERIOD_M30, shift); // perf-allowed: bounded closed-bar UTC range scan for card key levels
      if(high <= 0.0 || low <= 0.0)
         continue;

      if(!found)
        {
         out_high = high;
         out_low = low;
         found = true;
        }
      else
        {
         if(high > out_high)
            out_high = high;
         if(low < out_low)
            out_low = low;
        }
     }
   return found;
  }

bool EnsureOpenLevels()
  {
   const datetime signal_broker = iTime(_Symbol, PERIOD_M30, 1); // perf-allowed: fixed closed-bar timestamp for UTC keying
   if(signal_broker <= 0)
      return false;

   const datetime signal_utc = QM_BrokerToUTC(signal_broker);
   const int day_key = UtcDayKey(signal_utc);
   const int week_key = UtcWeekKey(signal_utc);
   const int month_key = UtcMonthKey(signal_utc);

   if(day_key != g_cached_day_key)
     {
      g_dop = OpenForUtcPeriod(QM_PERIOD_DAY, day_key, 120);
      const int prev_day_key = UtcDayKey(UtcDayStart(signal_utc) - 86400);
      RangeForUtcPeriod(QM_PERIOD_DAY, prev_day_key, 220, g_prev_day_high, g_prev_day_low);
      g_cached_day_key = day_key;
     }

   if(week_key != g_cached_week_key)
     {
      g_wop = OpenForUtcPeriod(QM_PERIOD_WEEK, week_key, 420);
      g_cached_week_key = week_key;
     }
   RangeForUtcPeriod(QM_PERIOD_WEEK, week_key, 420, g_week_high, g_week_low);

   if(month_key != g_cached_month_key)
     {
      g_mop = OpenForUtcPeriod(QM_PERIOD_MONTH, month_key, 1800);
      g_cached_month_key = month_key;
     }

   return (g_dop > 0.0 && g_wop > 0.0 && g_mop > 0.0);
  }

int CountAboveOpenLevels(const double price)
  {
   int count = 0;
   if(price > g_dop)
      ++count;
   if(price > g_wop)
      ++count;
   if(price > g_mop)
      ++count;
   return count;
  }

int CountBelowOpenLevels(const double price)
  {
   int count = 0;
   if(price < g_dop)
      ++count;
   if(price < g_wop)
      ++count;
   if(price < g_mop)
      ++count;
   return count;
  }

bool PickLongBounceLevel(const double low, const double close, const double atr, double &level)
  {
   level = 0.0;
   const double tolerance = atr * strategy_touch_atr_mult;
   const double levels[3] = {g_dop, g_wop, g_mop};
   double best_distance = DBL_MAX;
   for(int i = 0; i < 3; ++i)
     {
      const double candidate = levels[i];
      if(candidate <= 0.0 || close <= candidate)
         continue;
      const double distance = MathAbs(low - candidate);
      if(distance <= tolerance && distance < best_distance)
        {
         best_distance = distance;
         level = candidate;
        }
     }
   return level > 0.0;
  }

bool PickShortBounceLevel(const double high, const double close, const double atr, double &level)
  {
   level = 0.0;
   const double tolerance = atr * strategy_touch_atr_mult;
   const double levels[3] = {g_dop, g_wop, g_mop};
   double best_distance = DBL_MAX;
   for(int i = 0; i < 3; ++i)
     {
      const double candidate = levels[i];
      if(candidate <= 0.0 || close >= candidate)
         continue;
      const double distance = MathAbs(high - candidate);
      if(distance <= tolerance && distance < best_distance)
        {
         best_distance = distance;
         level = candidate;
        }
     }
   return level > 0.0;
  }

bool BuildStopsAndTarget(const QM_OrderType side,
                         const double entry,
                         const double open_level,
                         const double atr,
                         double &out_sl,
                         double &out_tp)
  {
   out_sl = 0.0;
   out_tp = 0.0;
   if(entry <= 0.0 || open_level <= 0.0 || atr <= 0.0)
      return false;

   const double min_dist = atr * strategy_min_stop_atr;
   const double max_dist = atr * strategy_max_stop_atr;
   double stop = open_level;

   if(QM_OrderTypeIsBuy(side))
     {
      if(g_prev_day_low > 0.0 && g_prev_day_low < entry && g_prev_day_low > stop)
         stop = g_prev_day_low;
      if(stop >= entry || (entry - stop) < min_dist)
         stop = entry - min_dist;
      const double dist = entry - stop;
      if(dist <= 0.0 || dist > max_dist)
         return false;

      double key_tp = DBL_MAX;
      if(g_prev_day_high > entry)
         key_tp = g_prev_day_high;
      if(g_week_high > entry && g_week_high < key_tp)
         key_tp = g_week_high;
      out_sl = QM_StopRulesNormalizePrice(_Symbol, stop);
      out_tp = (key_tp < DBL_MAX) ? QM_StopRulesNormalizePrice(_Symbol, key_tp)
                                  : QM_TakeRR(_Symbol, side, entry, out_sl, strategy_fallback_rr);
      return (out_sl > 0.0 && out_tp > entry);
     }

   if(g_prev_day_high > 0.0 && g_prev_day_high > entry && g_prev_day_high < stop)
      stop = g_prev_day_high;
   if(stop <= entry || (stop - entry) < min_dist)
      stop = entry + min_dist;
   const double dist = stop - entry;
   if(dist <= 0.0 || dist > max_dist)
      return false;

   double key_tp = -DBL_MAX;
   if(g_prev_day_low > 0.0 && g_prev_day_low < entry)
      key_tp = g_prev_day_low;
   if(g_week_low > 0.0 && g_week_low < entry && g_week_low > key_tp)
      key_tp = g_week_low;
   out_sl = QM_StopRulesNormalizePrice(_Symbol, stop);
   out_tp = (key_tp > -DBL_MAX) ? QM_StopRulesNormalizePrice(_Symbol, key_tp)
                                : QM_TakeRR(_Symbol, side, entry, out_sl, strategy_fallback_rr);
   return (out_sl > entry && out_tp > 0.0 && out_tp < entry);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M30)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   if(atr > 0.0 && ask > bid && (ask - bid) > atr * strategy_max_spread_atr)
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

   if(strategy_rsi_period <= 1 || strategy_atr_period <= 1)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!EnsureOpenLevels())
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_M30, 1); // perf-allowed: fixed closed-bar entry signal read
   const double close_2 = iClose(_Symbol, PERIOD_M30, 2); // perf-allowed: fixed closed-bar breakout comparison read
   const double low_1 = iLow(_Symbol, PERIOD_M30, 1); // perf-allowed: fixed closed-bar bounce touch read
   const double high_1 = iHigh(_Symbol, PERIOD_M30, 1); // perf-allowed: fixed closed-bar bounce touch read
   if(close_1 <= 0.0 || close_2 <= 0.0 || low_1 <= 0.0 || high_1 <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   const double rsi = QM_RSI(_Symbol, PERIOD_M30, strategy_rsi_period, 1, PRICE_CLOSE);
   if(atr <= 0.0 || rsi <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double trigger_level = 0.0;
   QM_OrderType side = QM_BUY;
   string reason = "";

   if(close_2 <= g_dop && close_1 > g_dop && close_1 > g_wop && close_1 > g_mop && rsi > strategy_rsi_midline)
     {
      side = QM_BUY;
      trigger_level = g_dop;
      reason = "DOP_BREAKOUT_LONG";
     }
   else if(close_2 >= g_dop && close_1 < g_dop && close_1 < g_wop && close_1 < g_mop && rsi < strategy_rsi_midline)
     {
      side = QM_SELL;
      trigger_level = g_dop;
      reason = "DOP_BREAKOUT_SHORT";
     }
   else if(CountAboveOpenLevels(close_1) >= 2 && rsi > strategy_rsi_midline &&
           PickLongBounceLevel(low_1, close_1, atr, trigger_level))
     {
      side = QM_BUY;
      reason = "OPEN_LEVEL_BOUNCE_LONG";
     }
   else if(CountBelowOpenLevels(close_1) >= 2 && rsi < strategy_rsi_midline &&
           PickShortBounceLevel(high_1, close_1, atr, trigger_level))
     {
      side = QM_SELL;
      reason = "OPEN_LEVEL_BOUNCE_SHORT";
     }
   else
      return false;

   const double entry = QM_OrderTypeIsBuy(side) ? ask : bid;
   double sl = 0.0;
   double tp = 0.0;
   if(!BuildStopsAndTarget(side, entry, trigger_level, atr, sl, tp))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, scale-in, or partial close logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   datetime pos_open_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      have_position = true;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      pos_open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(!have_position)
      return false;

   if(strategy_time_stop_bars > 0)
     {
      const int stop_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_M30);
      if(stop_seconds > 0 && TimeCurrent() - pos_open_time >= stop_seconds)
         return true;
     }

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime open_utc = QM_BrokerToUTC(pos_open_time);
   if(UtcDayKey(now_utc) != UtcDayKey(open_utc))
      return true;

   if(!EnsureOpenLevels())
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_M30, 1); // perf-allowed: fixed closed-bar opposite DOP exit read
   const double close_2 = iClose(_Symbol, PERIOD_M30, 2); // perf-allowed: fixed closed-bar opposite DOP exit read
   const double rsi = QM_RSI(_Symbol, PERIOD_M30, strategy_rsi_period, 1, PRICE_CLOSE);
   if(close_1 <= 0.0 || close_2 <= 0.0 || rsi <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
      return (close_2 >= g_dop && close_1 < g_dop && rsi < strategy_rsi_midline);

   return (close_2 <= g_dop && close_1 > g_dop && rsi > strategy_rsi_midline);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
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
