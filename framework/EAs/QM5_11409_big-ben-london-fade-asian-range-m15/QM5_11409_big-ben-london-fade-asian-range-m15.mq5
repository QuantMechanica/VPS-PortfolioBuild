#property strict
#property version   "5.0"
#property description "QM5_11409 Big Ben London fade of Asian-range false breakout, M15"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
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
input int    qm_ea_id                   = 11409;
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
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// TODO: declare strategy-specific input params here, e.g.:
//   input int    strategy_atr_period   = 14;
//   input double strategy_atr_sl_mult  = 2.0;
//   input double strategy_atr_tp_mult  = 3.0;
input int    strategy_asian_start_hour  = 1;      // broker hour, inclusive
input int    strategy_asian_end_hour    = 9;      // broker hour, exclusive
input int    strategy_london_open_hour  = 10;     // broker hour
input int    strategy_time_stop_hour    = 11;     // broker hour
input int    strategy_spread_cap_pips   = 20;     // card spread cap
input int    strategy_sl_cap_pips       = 40;     // P2 cap
input int    strategy_fallback_sl_pips  = 30;     // card alternate fixed stop
input double strategy_tp_range_mult     = 1.0;    // card default: Asian range

int BB_Hour(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   return dt.hour;
  }

datetime BB_DayStart(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool BB_LoadLastClosedBar(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, rates); // perf-allowed: called only from the framework new-bar entry hook
   if(copied != 1)
      return false;
   bar = rates[0];
   return (bar.time > 0 && bar.open > 0.0 && bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0);
  }

bool BB_LoadSessionContext(const MqlRates &last_bar,
                           double &asian_high,
                           double &asian_low,
                           int &sweep_dir,
                           datetime &first_long_fade,
                           datetime &first_short_fade)
  {
   asian_high = 0.0;
   asian_low = 0.0;
   sweep_dir = 0;
   first_long_fade = 0;
   first_short_fade = 0;

   const datetime day_start = BB_DayStart(last_bar.time);
   const datetime asian_start = day_start + strategy_asian_start_hour * 3600;
   const datetime asian_end = day_start + strategy_asian_end_hour * 3600;
   const datetime london_open = day_start + strategy_london_open_hour * 3600;
   const datetime time_stop = day_start + strategy_time_stop_hour * 3600;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, day_start, last_bar.time, rates); // perf-allowed: bounded same-day scan inside framework new-bar entry hook
   if(copied <= 0)
      return false;

   bool have_asian = false;
   bool ambiguous_sweep_bar = false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime t = rates[i].time;
      if(t <= 0 || t > last_bar.time)
         continue;

      if(t >= asian_start && t < asian_end)
        {
         const double body_hi = MathMax(rates[i].open, rates[i].close);
         const double body_lo = MathMin(rates[i].open, rates[i].close);
         if(body_hi <= 0.0 || body_lo <= 0.0)
            continue;

         if(!have_asian)
           {
            asian_high = body_hi;
            asian_low = body_lo;
            have_asian = true;
           }
         else
           {
            if(body_hi > asian_high)
               asian_high = body_hi;
            if(body_lo < asian_low)
               asian_low = body_lo;
           }
        }
     }

   if(!have_asian || asian_high <= asian_low)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime t = rates[i].time;
      if(t < asian_end || t >= london_open)
         continue;

      const bool swept_low = (rates[i].low < asian_low);
      const bool swept_high = (rates[i].high > asian_high);
      if(swept_low && swept_high)
        {
         ambiguous_sweep_bar = true;
         continue;
        }
      if(swept_low)
         sweep_dir = +1;
      else if(swept_high)
         sweep_dir = -1;
     }

   if(ambiguous_sweep_bar || sweep_dir == 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime t = rates[i].time;
      if(t < london_open || t >= time_stop || t > last_bar.time)
         continue;

      if(first_long_fade == 0 && rates[i].close > asian_low)
         first_long_fade = t;
      if(first_short_fade == 0 && rates[i].close < asian_high)
         first_short_fade = t;
     }

   return true;
  }

void BB_InitRequest(QM_EntryRequest &req)
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
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   BB_InitRequest(req);

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   MqlRates last_bar;
   if(!BB_LoadLastClosedBar(last_bar))
      return false;

   const int hour = BB_Hour(last_bar.time);
   if(hour < strategy_london_open_hour || hour >= strategy_time_stop_hour)
      return false;

   double asian_high = 0.0;
   double asian_low = 0.0;
   int sweep_dir = 0;
   datetime first_long_fade = 0;
   datetime first_short_fade = 0;
   if(!BB_LoadSessionContext(last_bar, asian_high, asian_low, sweep_dir, first_long_fade, first_short_fade))
      return false;

   const double range = asian_high - asian_low;
   if(range <= 0.0 || strategy_tp_range_mult <= 0.0)
      return false;

   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double fallback_sl = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fallback_sl_pips);
   if(sl_cap <= 0.0 || fallback_sl <= 0.0)
      return false;

   if(sweep_dir > 0)
     {
      if(first_long_fade != last_bar.time || !(last_bar.close > asian_low))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double sl = last_bar.low;
      if(!(sl < entry))
         sl = entry - fallback_sl;
      if((entry - sl) > sl_cap)
         sl = entry - sl_cap;

      req.type = QM_BUY;
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, entry + range * strategy_tp_range_mult);
      req.reason = "bigben_london_fade_long";
      return (req.sl > 0.0 && req.tp > entry);
     }

   if(sweep_dir < 0)
     {
      if(first_short_fade != last_bar.time || !(last_bar.close < asian_high))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = last_bar.high;
      if(!(sl > entry))
         sl = entry + fallback_sl;
      if((sl - entry) > sl_cap)
         sl = entry + sl_cap;

      req.type = QM_SELL;
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, entry - range * strategy_tp_range_mult);
      req.reason = "bigben_london_fade_short";
      return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int hour = BB_Hour(TimeCurrent());
   return (hour >= strategy_time_stop_hour && hour < qm_friday_close_hour_broker);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
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

