#property strict
#property version   "5.0"
#property description "QM5_11901 London Asia Range Breakout M15"

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
input int    qm_ea_id                   = 11901;
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
input int    strategy_asia_start_hour_utc       = 0;
input int    strategy_asia_end_hour_utc         = 8;
input int    strategy_london_open_hour_utc      = 8;
input int    strategy_breakout_window_minutes   = 180;
input int    strategy_required_asia_bars        = 32;
input int    strategy_scan_bars                 = 96;
input int    strategy_stop_buffer_pips          = 2;
input int    strategy_take_profit_pips          = 30;
input int    strategy_timeout_hour_utc          = 20;

int Strategy_UTC_DayKey(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

int Strategy_UTC_Minutes(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   return (dt.hour * 60 + dt.min);
  }

bool Strategy_HaveOurPosition(datetime &open_time)
  {
   open_time = 0;
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

      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_BuildAsiaRange(const int day_key, double &asia_high, double &asia_low)
  {
   asia_high = -DBL_MAX;
   asia_low = DBL_MAX;
   int bars_found = 0;

   const int start_minute = strategy_asia_start_hour_utc * 60;
   const int end_minute = strategy_asia_end_hour_utc * 60;

   // perf-allowed: bounded 96-bar M15 structural session scan, called only from
   // Strategy_EntrySignal after the framework QM_IsNewBar() gate.
   for(int shift = 1; shift <= strategy_scan_bars; ++shift)
     {
      const datetime bar_broker_time = iTime(_Symbol, PERIOD_CURRENT, shift);
      if(bar_broker_time <= 0)
         continue;

      const datetime bar_utc_time = QM_BrokerToUTC(bar_broker_time);
      if(Strategy_UTC_DayKey(bar_utc_time) != day_key)
         continue;

      const int minute = Strategy_UTC_Minutes(bar_utc_time);
      if(minute < start_minute || minute >= end_minute)
         continue;

      const double bar_high = iHigh(_Symbol, PERIOD_CURRENT, shift);
      const double bar_low = iLow(_Symbol, PERIOD_CURRENT, shift);
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high < bar_low)
         continue;

      asia_high = MathMax(asia_high, bar_high);
      asia_low = MathMin(asia_low, bar_low);
      bars_found++;
     }

   return (bars_found >= strategy_required_asia_bars && asia_high > asia_low && asia_low > 0.0);
  }

int g_strategy_session_day_key = 0;
bool g_strategy_trade_taken_today = false;

void Strategy_RefreshSessionState(const int day_key)
  {
   if(day_key != g_strategy_session_day_key)
     {
      g_strategy_session_day_key = day_key;
      g_strategy_trade_taken_today = false;
     }

   datetime open_time = 0;
   if(Strategy_HaveOurPosition(open_time))
      g_strategy_trade_taken_today = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(strategy_asia_start_hour_utc < 0 || strategy_asia_start_hour_utc > 23 ||
      strategy_asia_end_hour_utc <= strategy_asia_start_hour_utc ||
      strategy_london_open_hour_utc < 0 || strategy_london_open_hour_utc > 23 ||
      strategy_breakout_window_minutes <= 0 ||
      strategy_required_asia_bars <= 0 ||
      strategy_scan_bars < strategy_required_asia_bars ||
      strategy_stop_buffer_pips <= 0 ||
      strategy_take_profit_pips <= 0 ||
      strategy_timeout_hour_utc < 0 || strategy_timeout_hour_utc > 23)
      return false;

   const datetime breakout_bar_broker_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(breakout_bar_broker_time <= 0)
      return false;

   const datetime breakout_bar_utc_time = QM_BrokerToUTC(breakout_bar_broker_time);
   const int day_key = Strategy_UTC_DayKey(breakout_bar_utc_time);
   Strategy_RefreshSessionState(day_key);
   if(g_strategy_trade_taken_today)
      return false;

   const int breakout_minute = Strategy_UTC_Minutes(breakout_bar_utc_time);
   const int window_start = strategy_london_open_hour_utc * 60;
   const int window_end = window_start + strategy_breakout_window_minutes;
   if(breakout_minute < window_start || breakout_minute >= window_end)
      return false;

   double asia_high = 0.0;
   double asia_low = 0.0;
   if(!Strategy_BuildAsiaRange(day_key, asia_high, asia_low))
      return false;

   const double close_price = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double bar_high = iHigh(_Symbol, PERIOD_CURRENT, 1);
   const double bar_low = iLow(_Symbol, PERIOD_CURRENT, 1);
   if(close_price <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0)
      return false;

   const double stop_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_buffer_pips);
   const double take_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_take_profit_pips);
   if(stop_buffer <= 0.0 || take_distance <= 0.0)
      return false;

   if(close_price > asia_high)
     {
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bar_low - stop_buffer);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, close_price + take_distance);
      req.reason = "ASIA_RANGE_LONG_BREAKOUT";
      g_strategy_trade_taken_today = true;
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl < close_price && req.tp > close_price);
     }

   if(close_price < asia_low)
     {
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bar_high + stop_buffer);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, close_price - take_distance);
      req.reason = "ASIA_RANGE_SHORT_BREAKOUT";
      g_strategy_trade_taken_today = true;
      return (req.sl > close_price && req.tp > 0.0 && req.tp < close_price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or scale-in logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime open_broker_time = 0;
   if(!Strategy_HaveOurPosition(open_broker_time))
      return false;

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   const datetime open_utc = QM_BrokerToUTC(open_broker_time);
   const int now_day = Strategy_UTC_DayKey(now_utc);
   const int open_day = Strategy_UTC_DayKey(open_utc);
   const int timeout_minute = strategy_timeout_hour_utc * 60;

   if(now_day > open_day)
      return true;
   if(now_day == open_day && Strategy_UTC_Minutes(now_utc) >= timeout_minute)
      return true;

   return false;
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
