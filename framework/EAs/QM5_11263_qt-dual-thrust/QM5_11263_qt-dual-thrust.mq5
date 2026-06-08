#property strict
#property version   "5.0"
#property description "QM5_11263 Quant-Trading Dual Thrust"

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
input int    qm_ea_id                   = 11263;
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
input int    strategy_range_sessions       = 5;     // Prior source sessions used for Dual Thrust range.
input double strategy_threshold_param      = 0.50;  // Upper=open+param*range; lower=open-(1-param)*range.
input int    strategy_source_open_hhmm_est = 300;   // Source script threshold time, fixed EST.
input int    strategy_source_close_hhmm_est= 1200;  // Source script force-flat time, fixed EST.
input int    strategy_atr_period           = 14;    // Catastrophic stop ATR period on M30.
input double strategy_atr_sl_mult          = 1.50;  // Catastrophic stop ATR multiplier.
input double strategy_spread_max_frac      = 0.10;  // Max spread as fraction of threshold distance.

struct StrategySessionOhlc
  {
   int      day_key;
   double   open;
   double   high;
   double   low;
   double   close;
  };

#define STRATEGY_MAX_SESSIONS 16

StrategySessionOhlc g_prior_sessions[STRATEGY_MAX_SESSIONS];
int      g_prior_count       = 0;
int      g_active_day_key    = 0;
bool     g_active_valid      = false;
double   g_active_open       = 0.0;
double   g_active_high       = 0.0;
double   g_active_low        = 0.0;
double   g_active_close      = 0.0;
bool     g_levels_ready      = false;
double   g_session_upper     = 0.0;
double   g_session_lower     = 0.0;

int HhmmToMinutes(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

int EstMinuteOfDay(const datetime broker_time)
  {
   datetime utc_time = QM_BrokerToUTC(broker_time);
   datetime est_time = utc_time - 5 * 3600;
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(est_time, dt);
   return dt.hour * 60 + dt.min;
  }

int EstDayKey(const datetime broker_time)
  {
   datetime utc_time = QM_BrokerToUTC(broker_time);
   datetime est_time = utc_time - 5 * 3600;
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(est_time, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

bool IsInsideSourceSession(const datetime broker_time)
  {
   const int minute = EstMinuteOfDay(broker_time);
   const int start_min = HhmmToMinutes(strategy_source_open_hhmm_est);
   const int end_min = HhmmToMinutes(strategy_source_close_hhmm_est);
   if(start_min < end_min)
      return (minute >= start_min && minute < end_min);
   return (minute >= start_min || minute < end_min);
  }

bool IsAtOrPastSourceClose(const datetime broker_time)
  {
   const int minute = EstMinuteOfDay(broker_time);
   const int start_min = HhmmToMinutes(strategy_source_open_hhmm_est);
   const int end_min = HhmmToMinutes(strategy_source_close_hhmm_est);
   if(start_min < end_min)
      return (minute >= end_min);
   return (minute >= end_min && minute < start_min);
  }

bool StrategyParamsValid()
  {
   if(strategy_range_sessions < 1 || strategy_range_sessions > STRATEGY_MAX_SESSIONS)
      return false;
   if(strategy_threshold_param <= 0.0 || strategy_threshold_param >= 1.0)
      return false;
   if(strategy_source_open_hhmm_est < 0 || strategy_source_open_hhmm_est > 2359)
      return false;
   if(strategy_source_close_hhmm_est < 0 || strategy_source_close_hhmm_est > 2359)
      return false;
   if(strategy_source_open_hhmm_est == strategy_source_close_hhmm_est)
      return false;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(strategy_spread_max_frac <= 0.0)
      return false;
   return true;
  }

void ArchiveActiveSession()
  {
   if(!g_active_valid || g_active_high <= 0.0 || g_active_low <= 0.0 || g_active_close <= 0.0)
      return;

   if(g_prior_count > 0 && g_prior_sessions[g_prior_count - 1].day_key == g_active_day_key)
     {
      g_prior_sessions[g_prior_count - 1].open  = g_active_open;
      g_prior_sessions[g_prior_count - 1].high  = g_active_high;
      g_prior_sessions[g_prior_count - 1].low   = g_active_low;
      g_prior_sessions[g_prior_count - 1].close = g_active_close;
      return;
     }

   if(g_prior_count >= STRATEGY_MAX_SESSIONS)
     {
      for(int i = 1; i < STRATEGY_MAX_SESSIONS; ++i)
         g_prior_sessions[i - 1] = g_prior_sessions[i];
      g_prior_count = STRATEGY_MAX_SESSIONS - 1;
     }

   g_prior_sessions[g_prior_count].day_key = g_active_day_key;
   g_prior_sessions[g_prior_count].open    = g_active_open;
   g_prior_sessions[g_prior_count].high    = g_active_high;
   g_prior_sessions[g_prior_count].low     = g_active_low;
   g_prior_sessions[g_prior_count].close   = g_active_close;
   g_prior_count++;
  }

bool BuildDualThrustLevels(const double session_open)
  {
   g_levels_ready = false;
   if(session_open <= 0.0 || g_prior_count < strategy_range_sessions)
      return false;

   double rolling_high = -DBL_MAX;
   double rolling_low = DBL_MAX;
   double close_min = DBL_MAX;
   double close_max = -DBL_MAX;

   const int start = g_prior_count - strategy_range_sessions;
   for(int i = start; i < g_prior_count; ++i)
     {
      rolling_high = MathMax(rolling_high, g_prior_sessions[i].high);
      rolling_low  = MathMin(rolling_low, g_prior_sessions[i].low);
      close_min    = MathMin(close_min, g_prior_sessions[i].close);
      close_max    = MathMax(close_max, g_prior_sessions[i].close);
     }

   const double range1 = rolling_high - close_min;
   const double range2 = close_max - rolling_low;
   const double range = MathMax(range1, range2);
   if(range <= 0.0 || rolling_high <= 0.0 || rolling_low <= 0.0)
      return false;

   g_session_upper = NormalizeDouble(session_open + strategy_threshold_param * range, _Digits);
   g_session_lower = NormalizeDouble(session_open - (1.0 - strategy_threshold_param) * range, _Digits);
   g_levels_ready = (g_session_upper > g_session_lower && g_session_lower > 0.0);
   return g_levels_ready;
  }

void StartSourceSession(const datetime broker_time)
  {
   if(g_active_valid)
      ArchiveActiveSession();

   const double session_open = iOpen(_Symbol, _Period, 0); // perf-allowed: source-session open captured once on framework new bar.
   g_active_day_key = EstDayKey(broker_time);
   g_active_open = session_open;
   g_active_high = session_open;
   g_active_low = session_open;
   g_active_close = session_open;
   g_active_valid = (session_open > 0.0);
   BuildDualThrustLevels(session_open);
  }

void UpdateActiveSessionFromClosedBar()
  {
   if(!g_active_valid)
      return;

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: bespoke session OHLC cache, once per framework new bar.
   if(bar_time <= 0 || EstDayKey(bar_time) != g_active_day_key || !IsInsideSourceSession(bar_time))
      return;

   const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: bespoke source-session high cache, once per framework new bar.
   const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed: bespoke source-session low cache, once per framework new bar.
   const double bar_close = iClose(_Symbol, _Period, 1); // perf-allowed: bespoke source-session close cache, once per framework new bar.
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return;

   g_active_high = MathMax(g_active_high, bar_high);
   g_active_low = MathMin(g_active_low, bar_low);
   g_active_close = bar_close;
  }

void AdvanceStateOnNewBar()
  {
   const datetime broker_now = TimeCurrent();
   if(!IsInsideSourceSession(broker_now))
     {
      if(g_active_valid && IsAtOrPastSourceClose(broker_now))
        {
         ArchiveActiveSession();
         g_active_valid = false;
         g_levels_ready = false;
        }
      return;
     }

   const int day_key = EstDayKey(broker_now);
   if(!g_active_valid || g_active_day_key != day_key)
      StartSourceSession(broker_now);

   UpdateActiveSessionFromClosedBar();
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &ptype)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool HasOurPosition()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   return SelectOurPosition(ptype);
  }

bool SpreadAllowed()
  {
   if(!g_levels_ready)
      return true;

   const double threshold_distance = g_session_upper - g_session_lower;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(threshold_distance <= 0.0 || ask <= 0.0 || bid <= 0.0 || spread < 0.0)
      return false;
   return (spread <= strategy_spread_max_frac * threshold_distance);
  }

int CurrentDualThrustSignal()
  {
   if(!g_levels_ready)
      return 0;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > g_session_upper)
      return 1;
   if(bid < g_session_lower)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: time, spread, and news. News is handled by the framework
   // before this hook; this hook keeps source-session and spread gates local.
   if(!StrategyParamsValid())
      return true;

   if(HasOurPosition())
      return false;

   if(!IsInsideSourceSession(TimeCurrent()))
      return true;

   return !SpreadAllowed();
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceStateOnNewBar();

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!StrategyParamsValid() || !IsInsideSourceSession(TimeCurrent()) || !g_levels_ready)
      return false;
   if(!SpreadAllowed())
      return false;

   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(SelectOurPosition(ptype))
      return false;

   const int signal = CurrentDualThrustSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr_m30 = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   const double stop = QM_StopATRFromValue(_Symbol, side, entry, atr_m30, strategy_atr_sl_mult);
   if(entry <= 0.0 || stop <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = (signal > 0) ? "DUAL_THRUST_LONG" : "DUAL_THRUST_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, partial, or break-even rule. The catastrophic ATR
   // stop is placed at entry and session/reversal exits live in Trade Close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ptype))
      return false;

   if(IsAtOrPastSourceClose(TimeCurrent()))
      return true;

   if(!g_levels_ready)
      return false;

   const int signal = CurrentDualThrustSignal();
   if(ptype == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && signal > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: central two-axis framework blackout handles entries and
   // reversals; no card-specific calendar override is defined.
   (void)broker_time;
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
