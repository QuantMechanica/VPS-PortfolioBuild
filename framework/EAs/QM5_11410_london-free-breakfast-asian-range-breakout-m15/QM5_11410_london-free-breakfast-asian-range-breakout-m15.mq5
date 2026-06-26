#property strict
#property version   "5.0"
#property description "QM5_11410 London Free Breakfast Asian Range Breakout M15"

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
input int    qm_ea_id                   = 11410;
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
input int    strategy_asian_start_hour_broker  = 1;
input int    strategy_asian_start_minute_broker = 0;
input int    strategy_asian_end_hour_broker    = 9;
input int    strategy_asian_end_minute_broker  = 0;
input int    strategy_london_start_hour_broker = 9;
input int    strategy_london_start_minute_broker = 0;
input int    strategy_london_end_hour_broker   = 10;
input int    strategy_london_end_minute_broker = 0;
input int    strategy_range_scan_bars          = 80;
input int    strategy_min_asian_bars           = 24;
input int    strategy_tp_pips                  = 40;
input int    strategy_sl_cap_pips              = 40;
input int    strategy_spread_cap_pips          = 20;

int  g_trade_day_key = -1;
bool g_trade_taken_today = false;

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 60 + dt.min);
  }

int Strategy_ConfigMinuteOfDay(const int hour, const int minute)
  {
   if(hour >= 24)
      return 1440;
   return MathMax(0, MathMin(23, hour)) * 60 + MathMax(0, MathMin(59, minute));
  }

bool Strategy_SameDay(const datetime a, const datetime b)
  {
   return (Strategy_DateKey(a) == Strategy_DateKey(b));
  }

void Strategy_ResetDayIfNeeded(const datetime broker_time)
  {
   const int key = Strategy_DateKey(broker_time);
   if(key != g_trade_day_key)
     {
      g_trade_day_key = key;
      g_trade_taken_today = false;
     }
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_BuildAsianRange(const datetime day_ref,
                              const MqlRates &rates[],
                              const int copied,
                              double &asian_high,
                              double &asian_low,
                              int &bars_found)
  {
   asian_high = -1.0e100;
   asian_low = 1.0e100;
   bars_found = 0;

   const int start_minute = Strategy_ConfigMinuteOfDay(strategy_asian_start_hour_broker,
                                                       strategy_asian_start_minute_broker);
   const int end_minute = Strategy_ConfigMinuteOfDay(strategy_asian_end_hour_broker,
                                                     strategy_asian_end_minute_broker);
   for(int i = 0; i < copied; ++i)
     {
      if(!Strategy_SameDay(rates[i].time, day_ref))
         continue;

      const int minute = Strategy_MinuteOfDay(rates[i].time);
      if(minute < start_minute || minute >= end_minute)
         continue;

      if(rates[i].high > asian_high)
         asian_high = rates[i].high;
      if(rates[i].low < asian_low)
         asian_low = rates[i].low;
      ++bars_found;
     }

   return (bars_found >= strategy_min_asian_bars && asian_high > 0.0 && asian_low > 0.0 && asian_high > asian_low);
  }

double Strategy_NormalizedStop(const QM_OrderType side,
                               const double entry,
                               const double breakout_extreme)
  {
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   double sl = breakout_extreme;
   if(cap_distance > 0.0)
     {
      if(side == QM_BUY)
         sl = MathMax(breakout_extreme, entry - cap_distance);
      else
         sl = MathMin(breakout_extreme, entry + cap_distance);
     }
   return QM_StopRulesNormalizePrice(_Symbol, sl);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(ask > bid && spread_cap > 0.0 && (ask - bid) > spread_cap)
      return true;

   const datetime broker_now = TimeCurrent();
   Strategy_ResetDayIfNeeded(broker_now);

   const int now_minute = Strategy_MinuteOfDay(broker_now);
   const int start_minute = Strategy_ConfigMinuteOfDay(strategy_london_start_hour_broker,
                                                       strategy_london_start_minute_broker);
   const int end_eval_minute = Strategy_ConfigMinuteOfDay(strategy_london_end_hour_broker,
                                                          strategy_london_end_minute_broker) + 15;
   if(now_minute < start_minute || now_minute > end_eval_minute)
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

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int requested = MathMax(strategy_range_scan_bars, strategy_min_asian_bars + 4);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, requested, rates); // perf-allowed: bounded M15 session range scan; EntrySignal is called only after QM_IsNewBar().
   if(copied < strategy_min_asian_bars + 2)
      return false;

   const MqlRates breakout = rates[0];
   const MqlRates previous = rates[1];
   Strategy_ResetDayIfNeeded(breakout.time);

   if(g_trade_taken_today || Strategy_HasOpenPosition())
     {
      g_trade_taken_today = true;
      return false;
     }

   const int breakout_minute = Strategy_MinuteOfDay(breakout.time);
   const int start_minute = Strategy_ConfigMinuteOfDay(strategy_london_start_hour_broker,
                                                       strategy_london_start_minute_broker);
   const int end_minute = Strategy_ConfigMinuteOfDay(strategy_london_end_hour_broker,
                                                     strategy_london_end_minute_broker);
   if(breakout_minute < start_minute || breakout_minute >= end_minute)
      return false;

   double asian_high = 0.0;
   double asian_low = 0.0;
   int asian_bars = 0;
   if(!Strategy_BuildAsianRange(breakout.time, rates, copied, asian_high, asian_low, asian_bars))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(breakout.close > asian_high && previous.close <= asian_high)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = Strategy_NormalizedStop(QM_BUY, ask, breakout.low);
      req.tp = QM_TakeFixedPips(_Symbol, QM_BUY, ask, strategy_tp_pips);
      req.reason = "asian_range_breakout_long";
      g_trade_taken_today = true;
      return true;
     }

   if(breakout.close < asian_low && previous.close >= asian_low)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = Strategy_NormalizedStop(QM_SELL, bid, breakout.high);
      req.tp = QM_TakeFixedPips(_Symbol, QM_SELL, bid, strategy_tp_pips);
      req.reason = "asian_range_breakout_short";
      g_trade_taken_today = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial, or scale-in management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits only through fixed TP, breakout-candle SL, and framework Friday close.
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
