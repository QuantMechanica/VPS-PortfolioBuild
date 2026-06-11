#property strict
#property version   "5.0"
#property description "QM5_12474 GitHub Dual Thrust Breakout"

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
input int    qm_ea_id                   = 12474;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input ENUM_TIMEFRAMES strategy_timeframe           = PERIOD_M1;
input int             strategy_lookback_sessions   = 5;
input double          strategy_param               = 0.50;
input double          strategy_stop_range_mult     = 1.00;
input int             strategy_session_open_hhmm   = 1000;
input int             strategy_session_close_hhmm  = 1900;
input int             strategy_max_spread_points   = 0;

struct SessionStats
  {
   double high;
   double low;
   double close;
   bool   valid;
  };

int    g_session_day_key = -1;
bool   g_session_ready   = false;
double g_session_open    = 0.0;
double g_session_upper   = 0.0;
double g_session_lower   = 0.0;
double g_session_range   = 0.0;

int HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

datetime DayMidnight(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime SessionTime(const datetime day_midnight, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(day_midnight, dt);
   int hour = hhmm / 100;
   int minute = hhmm % 100;
   if(hour < 0)
      hour = 0;
   if(hour > 23)
      hour = 23;
   if(minute < 0)
      minute = 0;
   if(minute > 59)
      minute = 59;
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool IsSessionActive(const datetime broker_time)
  {
   const int hhmm = HHMM(broker_time);
   if(strategy_session_open_hhmm < strategy_session_close_hhmm)
      return (hhmm >= strategy_session_open_hhmm && hhmm < strategy_session_close_hhmm);
   return (hhmm >= strategy_session_open_hhmm || hhmm < strategy_session_close_hhmm);
  }

bool IsSessionClosed(const datetime broker_time)
  {
   const int hhmm = HHMM(broker_time);
   if(strategy_session_open_hhmm < strategy_session_close_hhmm)
      return (hhmm >= strategy_session_close_hhmm || hhmm < strategy_session_open_hhmm);
   return (hhmm >= strategy_session_close_hhmm && hhmm < strategy_session_open_hhmm);
  }

bool HasOurOpenPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      return true;
     }

   return false;
  }

bool LoadSessionStats(const datetime day_midnight, SessionStats &stats)
  {
   stats.high = 0.0;
   stats.low = 0.0;
   stats.close = 0.0;
   stats.valid = false;

   datetime open_t = SessionTime(day_midnight, strategy_session_open_hhmm);
   datetime close_t = SessionTime(day_midnight, strategy_session_close_hhmm);
   if(close_t <= open_t)
      close_t += 86400;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, strategy_timeframe, open_t, close_t - 1, rates); // perf-allowed: bounded prior-session OHLC window, recalculated only when the cached broker-day changes.
   if(copied <= 0)
      return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   double close_price = 0.0;
   bool have = false;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time < open_t || rates[i].time >= close_t)
         continue;
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].close <= 0.0)
         continue;

      hi = MathMax(hi, rates[i].high);
      lo = MathMin(lo, rates[i].low);
      close_price = rates[i].close;
      have = true;
     }

   if(!have || hi <= 0.0 || lo <= 0.0 || close_price <= 0.0 || hi < lo)
      return false;

   stats.high = hi;
   stats.low = lo;
   stats.close = close_price;
   stats.valid = true;
   return true;
  }

bool LoadCurrentSessionOpen(const datetime day_midnight, double &open_price)
  {
   open_price = 0.0;
   const datetime open_t = SessionTime(day_midnight, strategy_session_open_hhmm);

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, strategy_timeframe, open_t, open_t + 3600, rates); // perf-allowed: bounded current-session open lookup, cached per broker-day.
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time < open_t)
         continue;
      if(rates[i].open <= 0.0)
         continue;
      open_price = rates[i].open;
      return true;
     }

   return false;
  }

bool EnsureSessionLevels()
  {
   const datetime broker_now = TimeCurrent();
   const int day_key = DayKey(broker_now);
   if(g_session_ready && g_session_day_key == day_key)
      return true;

   g_session_day_key = day_key;
   g_session_ready = false;
   g_session_open = 0.0;
   g_session_upper = 0.0;
   g_session_lower = 0.0;
   g_session_range = 0.0;

   if(!IsSessionActive(broker_now))
      return false;
   if(strategy_lookback_sessions < 1 || strategy_param < 0.0 || strategy_param > 1.0 || strategy_stop_range_mult <= 0.0)
      return false;

   const datetime today_midnight = DayMidnight(broker_now);
   double open_price = 0.0;
   if(!LoadCurrentSessionOpen(today_midnight, open_price))
      return false;

   double max_high = -DBL_MAX;
   double min_low = DBL_MAX;
   double max_close = -DBL_MAX;
   double min_close = DBL_MAX;
   int sessions = 0;
   int max_calendar_scan = strategy_lookback_sessions * 7 + 7;
   if(max_calendar_scan < 14)
      max_calendar_scan = 14;

   for(int back = 1; back <= max_calendar_scan && sessions < strategy_lookback_sessions; ++back)
     {
      SessionStats s;
      if(!LoadSessionStats(today_midnight - back * 86400, s))
         continue;

      max_high = MathMax(max_high, s.high);
      min_low = MathMin(min_low, s.low);
      max_close = MathMax(max_close, s.close);
      min_close = MathMin(min_close, s.close);
      ++sessions;
     }

   if(sessions < strategy_lookback_sessions)
      return false;

   const double range1 = max_high - min_close;
   const double range2 = max_close - min_low;
   const double dual_range = MathMax(range1, range2);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(dual_range <= point || point <= 0.0)
      return false;

   g_session_open = open_price;
   g_session_range = dual_range;
   g_session_upper = NormalizeDouble(open_price + strategy_param * dual_range, _Digits);
   g_session_lower = NormalizeDouble(open_price - (1.0 - strategy_param) * dual_range, _Digits);
   g_session_ready = (g_session_upper > g_session_open && g_session_lower < g_session_open);
   return g_session_ready;
  }

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   const bool has_position = HasOurOpenPosition(ptype, ticket);
   if(has_position)
      return false;

   const datetime broker_now = TimeCurrent();
   if(!IsSessionActive(broker_now))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);

   const datetime broker_now = TimeCurrent();
   if(!IsSessionActive(broker_now))
      return false;
   if(!EnsureSessionLevels())
      return false;

   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   if(HasOurOpenPosition(ptype, ticket))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double stop_dist = g_session_range * strategy_stop_range_mult;
   if(stop_dist <= SymbolInfoDouble(_Symbol, SYMBOL_POINT))
      return false;

   if(ask > g_session_upper)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ask - stop_dist, _Digits);
      req.tp = 0.0;
      req.reason = "GH_DUAL_THRUST_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(bid < g_session_lower)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(bid + stop_dist, _Digits);
      req.tp = 0.0;
      req.reason = "GH_DUAL_THRUST_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   if(!HasOurOpenPosition(ptype, ticket))
      return false;

   const datetime broker_now = TimeCurrent();
   if(IsSessionClosed(broker_now))
      return true;

   if(!EnsureSessionLevels())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && bid < g_session_lower)
      return true;
   if(ptype == POSITION_TYPE_SELL && ask > g_session_upper)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework news filter.
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
