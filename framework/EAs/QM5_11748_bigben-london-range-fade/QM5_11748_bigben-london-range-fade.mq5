#property strict
#property version   "5.0"
#property description "QM5_11748 Big Ben London Range Fade"

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
input int    qm_ea_id                   = 11748;
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
input int    strategy_asia_start_hour_utc    = 0;
input int    strategy_asia_end_hour_utc      = 7;
input int    strategy_breakout_start_hour_utc = 7;
input int    strategy_breakout_end_hour_utc   = 8;
input int    strategy_fade_hour_utc           = 8;
input int    strategy_time_stop_hour_utc      = 9;
input int    strategy_history_bars_h1         = 16;
input bool   strategy_use_body_range          = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card defines no global no-trade filter beyond framework news/Friday gates.
   // The London-session timing is enforced inside Strategy_EntrySignal so
   // exits and trade management remain available on every tick.
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

   if(_Period != PERIOD_H1)
      return false;
   if(strategy_asia_start_hour_utc < 0 || strategy_asia_end_hour_utc > 24 ||
      strategy_breakout_start_hour_utc < 0 || strategy_breakout_end_hour_utc > 24 ||
      strategy_fade_hour_utc < 0 || strategy_fade_hour_utc > 23 ||
      strategy_time_stop_hour_utc < 0 || strategy_time_stop_hour_utc > 23)
      return false;
   if(strategy_asia_start_hour_utc >= strategy_asia_end_hour_utc ||
      strategy_breakout_start_hour_utc >= strategy_breakout_end_hour_utc)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_to_copy = MathMax(10, MathMin(strategy_history_bars_h1, 48));
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, bars_to_copy, rates); // perf-allowed: bounded H1 session-structure read, called only after framework QM_IsNewBar()
   if(copied < 10)
      return false;

   MqlDateTime fade_dt;
   ZeroMemory(fade_dt);
   const datetime fade_utc = QM_BrokerToUTC(rates[0].time);
   TimeToStruct(fade_utc, fade_dt);
   if(fade_dt.hour != strategy_fade_hour_utc)
      return false;

   const int fade_day_key = fade_dt.year * 10000 + fade_dt.mon * 100 + fade_dt.day;
   double asia_high = -DBL_MAX;
   double asia_low = DBL_MAX;
   bool found_asia = false;

   for(int i = 0; i < copied; ++i)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      TimeToStruct(QM_BrokerToUTC(rates[i].time), dt);
      const int day_key = dt.year * 10000 + dt.mon * 100 + dt.day;
      if(day_key != fade_day_key)
         continue;
      if(dt.hour < strategy_asia_start_hour_utc || dt.hour >= strategy_asia_end_hour_utc)
         continue;

      const double hi = strategy_use_body_range ? MathMax(rates[i].open, rates[i].close) : rates[i].high;
      const double lo = strategy_use_body_range ? MathMin(rates[i].open, rates[i].close) : rates[i].low;
      asia_high = MathMax(asia_high, hi);
      asia_low = MathMin(asia_low, lo);
      found_asia = true;
     }

   if(!found_asia || asia_high <= asia_low || asia_high <= 0.0 || asia_low <= 0.0)
      return false;

   bool up_breakout = false;
   bool down_breakout = false;
   double pre_high_close = -DBL_MAX;
   double pre_low_close = DBL_MAX;
   bool found_pre = false;

   for(int i = 0; i < copied; ++i)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      TimeToStruct(QM_BrokerToUTC(rates[i].time), dt);
      const int day_key = dt.year * 10000 + dt.mon * 100 + dt.day;
      if(day_key != fade_day_key)
         continue;
      if(dt.hour < strategy_breakout_start_hour_utc || dt.hour >= strategy_breakout_end_hour_utc)
         continue;

      if(rates[i].close > asia_high)
         up_breakout = true;
      if(rates[i].close < asia_low)
         down_breakout = true;
      pre_high_close = MathMax(pre_high_close, rates[i].close);
      pre_low_close = MathMin(pre_low_close, rates[i].close);
      found_pre = true;
     }

   if(!found_pre)
      return false;

   const double range = asia_high - asia_low;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(range <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   if(up_breakout && rates[0].close < asia_high)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = pre_high_close;
      req.tp = asia_low - range;
      req.reason = "BIGBEN_SHORT_FADE";
      if(req.sl <= bid || req.tp >= bid)
         return false;
      return true;
     }

   if(down_breakout && rates[0].close > asia_low)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = pre_low_close;
      req.tp = asia_high + range;
      req.reason = "BIGBEN_LONG_FADE";
      if(req.sl >= ask || req.tp <= ask)
         return false;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlDateTime now_dt;
   ZeroMemory(now_dt);
   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   TimeToStruct(now_utc, now_dt);
   if(now_dt.hour < strategy_time_stop_hour_utc)
      return false;

   const int now_day_key = now_dt.year * 10000 + now_dt.mon * 100 + now_dt.day;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      MqlDateTime open_dt;
      ZeroMemory(open_dt);
      const datetime open_utc = QM_BrokerToUTC((datetime)PositionGetInteger(POSITION_TIME));
      TimeToStruct(open_utc, open_dt);
      const int open_day_key = open_dt.year * 10000 + open_dt.mon * 100 + open_dt.day;
      if(open_day_key == now_day_key)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy))
      return true;
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
