#property strict
#property version   "5.0"
#property description "QM5_12540 ICT AMD / Judas Swing Asia-range fade"

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
input int    qm_ea_id                   = 12540;
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
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
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
input int    strategy_asia_start_hour        = 1;
input int    strategy_asia_end_hour          = 9;
input int    strategy_judas_start_hour       = 9;
input int    strategy_judas_end_hour         = 11;
input int    strategy_failure_bars           = 4;
input int    strategy_atr_period             = 14;
input double strategy_min_range_atr_mult     = 0.5;
input double strategy_max_range_atr_mult     = 2.5;
input double strategy_stop_atr_mult          = 0.3;
input double strategy_max_risk_atr_mult      = 2.0;
input double strategy_runner_range_mult      = 1.5;
input double strategy_max_rr                 = 3.0;
input double strategy_partial_close_percent  = 50.0;
input int    strategy_time_exit_hour         = 21;

int    g_day_key              = 0;
bool   g_asia_ready           = false;
double g_asia_high            = 0.0;
double g_asia_low             = 0.0;
double g_asia_height          = 0.0;
int    g_pending_direction    = 0;     // +1 long fade after downside Judas, -1 short fade after upside Judas.
double g_judas_extreme        = 0.0;
int    g_pending_bars_left    = 0;
bool   g_trade_taken_today    = false;
double g_active_tp1           = 0.0;
bool   g_tp1_attempted        = false;

int BrokerDayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000) + (dt.mon * 100) + dt.day;
  }

bool BrokerHourInWindow(const datetime t, const int start_hour, const int end_hour)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(start_hour <= end_hour)
      return (dt.hour >= start_hour && dt.hour < end_hour);
   return (dt.hour >= start_hour || dt.hour < end_hour);
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

void ResetDailyStateIfNeeded(const datetime broker_time)
  {
   const int today = BrokerDayKey(broker_time);
   if(today == g_day_key)
      return;

   g_day_key = today;
   g_asia_ready = false;
   g_asia_high = 0.0;
   g_asia_low = 0.0;
   g_asia_height = 0.0;
   g_pending_direction = 0;
   g_judas_extreme = 0.0;
   g_pending_bars_left = 0;
   g_trade_taken_today = false;
   g_active_tp1 = 0.0;
   g_tp1_attempted = false;
  }

bool HasOurOpenPosition()
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
      return true;
     }
   return false;
  }

bool BuildAsiaRangeForToday(const datetime broker_time)
  {
   ResetDailyStateIfNeeded(broker_time);
   if(g_asia_ready)
      return true;
   if(!BrokerHourInWindow(broker_time, strategy_asia_end_hour, 24))
      return false;

   const int today = BrokerDayKey(broker_time);
   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   int count = 0;

   for(int shift = 1; shift <= 96; ++shift)
     {
      const datetime bt = iTime(_Symbol, PERIOD_M15, shift); // perf-allowed: bounded session scan, called only from closed-bar hook.
      if(bt <= 0)
         break;
      const int key = BrokerDayKey(bt);
      if(key < today)
         break;
      if(key != today)
         continue;
      if(!BrokerHourInWindow(bt, strategy_asia_start_hour, strategy_asia_end_hour))
         continue;
      // perf-allowed: bounded Asia-range structure read.
      const double bh = iHigh(_Symbol, PERIOD_M15, shift); // perf-allowed: bounded Asia-range structure read.
      const double bl = iLow(_Symbol, PERIOD_M15, shift);  // perf-allowed: bounded Asia-range structure read.
      if(bh <= 0.0 || bl <= 0.0)
         continue;
      hi = MathMax(hi, bh);
      lo = MathMin(lo, bl);
      count++;
     }

   if(count < 4 || hi <= lo)
      return false;

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double height = hi - lo;
   if(atr_h1 <= 0.0 || height < strategy_min_range_atr_mult * atr_h1 || height > strategy_max_range_atr_mult * atr_h1)
      return false;

   g_asia_high = hi;
   g_asia_low = lo;
   g_asia_height = height;
   g_asia_ready = true;
   return true;
  }

bool BuildFadeRequest(const int direction, const double entry_estimate, QM_EntryRequest &req)
  {
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr_m15 <= 0.0 || g_asia_height <= 0.0 || entry_estimate <= 0.0)
      return false;

   const double stop_pad = strategy_stop_atr_mult * atr_m15;
   double sl = 0.0;
   double tp = 0.0;
   double risk = 0.0;
   double tp1 = 0.0;

   if(direction < 0)
     {
      sl = g_judas_extreme + stop_pad;
      risk = sl - entry_estimate;
      if(risk <= 0.0 || risk > strategy_max_risk_atr_mult * atr_m15)
         return false;
      tp1 = g_asia_low;
      const double distribution = g_asia_low - strategy_runner_range_mult * g_asia_height;
      const double rr_cap = entry_estimate - strategy_max_rr * risk;
      tp = MathMax(distribution, rr_cap);
      req.type = QM_SELL;
      req.reason = "AMD_JUDAS_SHORT";
     }
   else if(direction > 0)
     {
      sl = g_judas_extreme - stop_pad;
      risk = entry_estimate - sl;
      if(risk <= 0.0 || risk > strategy_max_risk_atr_mult * atr_m15)
         return false;
      tp1 = g_asia_high;
      const double distribution = g_asia_high + strategy_runner_range_mult * g_asia_height;
      const double rr_cap = entry_estimate + strategy_max_rr * risk;
      tp = MathMin(distribution, rr_cap);
      req.type = QM_BUY;
      req.reason = "AMD_JUDAS_LONG";
     }
   else
      return false;

   req.price = 0.0;
   req.sl = NormalizeStrategyPrice(sl);
   req.tp = NormalizeStrategyPrice(tp);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_active_tp1 = NormalizeStrategyPrice(tp1);
   g_tp1_attempted = false;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   ResetDailyStateIfNeeded(TimeCurrent());
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
   // perf-allowed: closed M15 signal bar.
   const datetime bar_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: closed M15 signal bar.
   if(bar_time <= 0)
      return false;
   ResetDailyStateIfNeeded(bar_time);

   if(g_trade_taken_today || HasOurOpenPosition())
     {
      g_trade_taken_today = true;
      return false;
     }

   if(!BuildAsiaRangeForToday(bar_time))
      return false;
   // perf-allowed: closed M15 signal bar and Judas extreme update.
   const double close1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: closed M15 signal bar.
   const double high1 = iHigh(_Symbol, PERIOD_M15, 1);   // perf-allowed: Judas extreme update.
   const double low1 = iLow(_Symbol, PERIOD_M15, 1);     // perf-allowed: Judas extreme update.
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   if(g_pending_direction != 0)
     {
      if(g_pending_direction < 0)
         g_judas_extreme = MathMax(g_judas_extreme, high1);
      else
         g_judas_extreme = MathMin(g_judas_extreme, low1);

      const bool closed_inside = (close1 <= g_asia_high && close1 >= g_asia_low);
      if(closed_inside)
        {
         const double entry_estimate = (g_pending_direction < 0)
                                       ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const int direction = g_pending_direction;
         g_pending_direction = 0;
         g_pending_bars_left = 0;
         if(BuildFadeRequest(direction, entry_estimate, req))
           {
            g_trade_taken_today = true;
            return true;
           }
         return false;
        }

      g_pending_bars_left--;
      if(g_pending_bars_left <= 0)
        {
         g_pending_direction = 0;
         g_pending_bars_left = 0;
        }
      return false;
     }

   if(!BrokerHourInWindow(bar_time, strategy_judas_start_hour, strategy_judas_end_hour))
      return false;

   if(close1 > g_asia_high)
     {
      g_pending_direction = -1;
      g_judas_extreme = high1;
      g_pending_bars_left = strategy_failure_bars;
      return false;
     }

   if(close1 < g_asia_low)
     {
      g_pending_direction = 1;
      g_judas_extreme = low1;
      g_pending_bars_left = strategy_failure_bars;
      return false;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(g_tp1_attempted)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   if(g_active_tp1 <= 0.0 && g_asia_ready)
     {
      for(int j = PositionsTotal() - 1; j >= 0; --j)
        {
         const ulong open_ticket = PositionGetTicket(j);
         if(open_ticket == 0 || !PositionSelectByTicket(open_ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         g_active_tp1 = (ptype == POSITION_TYPE_BUY) ? g_asia_high : g_asia_low;
         break;
        }
     }

   if(g_active_tp1 <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double trigger_price = (ptype == POSITION_TYPE_BUY)
                                   ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool hit_tp1 = (ptype == POSITION_TYPE_BUY) ? (trigger_price >= g_active_tp1)
                                                        : (trigger_price <= g_active_tp1);
      if(!hit_tp1)
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double close_lots = volume * strategy_partial_close_percent / 100.0;
      QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL);
      g_tp1_attempted = true;
      return;
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_time_exit_hour);
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
