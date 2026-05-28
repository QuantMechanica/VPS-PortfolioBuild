#property strict
#property version   "5.0"
#property description "QM5_10092 GitHub Asian Range Sweep Reversal"

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
input int    qm_ea_id                   = 10092;
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
input int    strategy_broker_gmt_offset_hours = 0;
input int    strategy_asian_start_hour_utc    = 0;
input int    strategy_asian_end_hour_utc      = 6;
input int    strategy_trade_start_hour_utc    = 6;
input int    strategy_trade_end_hour_utc      = 16;
input double strategy_range_min_pips          = 30.0;
input double strategy_range_max_pips          = 200.0;
input double strategy_sweep_min_pips          = 5.0;
input double strategy_sweep_max_pips          = 80.0;
input double strategy_sl_buffer_pips          = 15.0;
input double strategy_min_rr_ratio            = 1.5;
input bool   strategy_ema_filter_enabled      = true;
input int    strategy_ema_period              = 200;
input int    strategy_scan_bars               = 288;

int      g_range_day_key        = -1;
double   g_asian_high           = 0.0;
double   g_asian_low            = 0.0;
bool     g_range_ready          = false;
bool     g_high_sweep_seen      = false;
bool     g_low_sweep_seen       = false;
double   g_high_sweep_extreme   = 0.0;
double   g_low_sweep_extreme    = 0.0;
bool     g_signal_used_for_day  = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime utc_now = TimeCurrent() - strategy_broker_gmt_offset_hours * 3600;
   MqlDateTime tm;
   TimeToStruct(utc_now, tm);

   const int day_key = tm.year * 1000 + tm.day_of_year;
   if(day_key != g_range_day_key)
     {
      g_range_day_key = day_key;
      g_asian_high = 0.0;
      g_asian_low = 0.0;
      g_range_ready = false;
      g_high_sweep_seen = false;
      g_low_sweep_seen = false;
      g_high_sweep_extreme = 0.0;
      g_low_sweep_extreme = 0.0;
      g_signal_used_for_day = false;
     }

   if(tm.day_of_week == 0 || tm.day_of_week == 6)
      return true;

   if(tm.hour < strategy_trade_start_hour_utc || tm.hour >= strategy_trade_end_hour_utc)
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
   req.expiration_seconds = 30;

   if(g_signal_used_for_day)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
   if(pip <= 0.0)
      return false;

   const datetime utc_now = TimeCurrent() - strategy_broker_gmt_offset_hours * 3600;
   MqlDateTime now_tm;
   TimeToStruct(utc_now, now_tm);
   const int today_key = now_tm.year * 1000 + now_tm.day_of_year;

   if(today_key != g_range_day_key)
      return false;

   double day_high = 0.0;
   double day_low = 0.0;
   int samples = 0;
   const int scan_limit = MathMax(12, MathMin(strategy_scan_bars, 576));
   for(int shift = 1; shift <= scan_limit; ++shift)
     {
      const datetime bar_broker = iTime(_Symbol, PERIOD_M5, shift);
      if(bar_broker <= 0)
         break;

      const datetime bar_utc = bar_broker - strategy_broker_gmt_offset_hours * 3600;
      MqlDateTime bar_tm;
      TimeToStruct(bar_utc, bar_tm);
      const int bar_day_key = bar_tm.year * 1000 + bar_tm.day_of_year;
      if(bar_day_key < today_key)
         break;
      if(bar_day_key != today_key)
         continue;

      if(bar_tm.hour >= strategy_asian_start_hour_utc &&
         bar_tm.hour < strategy_asian_end_hour_utc)
        {
         const double hi = iHigh(_Symbol, PERIOD_M5, shift);
         const double lo = iLow(_Symbol, PERIOD_M5, shift);
         if(hi <= 0.0 || lo <= 0.0)
            continue;

         if(samples == 0)
           {
            day_high = hi;
            day_low = lo;
           }
         else
           {
            if(hi > day_high)
               day_high = hi;
            if(lo < day_low)
               day_low = lo;
           }
         samples++;
        }
     }

   if(samples > 0)
     {
      g_asian_high = day_high;
      g_asian_low = day_low;
      const double range_pips = (g_asian_high - g_asian_low) / pip;
      g_range_ready = (range_pips >= strategy_range_min_pips &&
                       range_pips <= strategy_range_max_pips);
     }

   if(!g_range_ready || g_asian_high <= g_asian_low)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double high_sweep_pips = (bid - g_asian_high) / pip;
   const double low_sweep_pips = (g_asian_low - bid) / pip;
   if(!g_low_sweep_seen &&
      high_sweep_pips >= strategy_sweep_min_pips &&
      high_sweep_pips <= strategy_sweep_max_pips)
     {
      g_high_sweep_seen = true;
      if(bid > g_high_sweep_extreme)
         g_high_sweep_extreme = bid;
     }
   if(!g_high_sweep_seen &&
      low_sweep_pips >= strategy_sweep_min_pips &&
      low_sweep_pips <= strategy_sweep_max_pips)
     {
      g_low_sweep_seen = true;
      if(g_low_sweep_extreme <= 0.0 || bid < g_low_sweep_extreme)
         g_low_sweep_extreme = bid;
     }

   const double close_1 = iClose(_Symbol, PERIOD_M5, 1);
   const double high_1 = iHigh(_Symbol, PERIOD_M5, 1);
   const double low_1 = iLow(_Symbol, PERIOD_M5, 1);
   const double open_0 = iOpen(_Symbol, PERIOD_M5, 0);
   if(close_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || open_0 <= 0.0)
      return false;

   if(strategy_ema_filter_enabled)
     {
      const double ema = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1);
      if(ema <= 0.0)
         return false;
      if(g_high_sweep_seen && bid >= ema)
         return false;
      if(g_low_sweep_seen && bid <= ema)
         return false;
     }

   const double buffer = strategy_sl_buffer_pips * pip;
   if(buffer <= 0.0)
      return false;

   if(g_high_sweep_seen && high_1 < g_asian_high && close_1 < g_asian_high && open_0 < g_asian_high && bid < g_asian_high)
     {
      const double sl = g_high_sweep_extreme + buffer;
      const double tp = g_asian_low;
      const double risk = sl - bid;
      const double reward = bid - tp;
      if(risk <= 0.0 || reward <= 0.0 || reward / risk < strategy_min_rr_ratio)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(tp, digits);
      req.reason = "GH_ASIAN_SWEEP_SHORT";
      g_signal_used_for_day = true;
      return true;
     }

   if(g_low_sweep_seen && low_1 > g_asian_low && close_1 > g_asian_low && open_0 > g_asian_low && bid > g_asian_low)
     {
      const double sl = g_low_sweep_extreme - buffer;
      const double tp = g_asian_high;
      const double risk = ask - sl;
      const double reward = tp - ask;
      if(risk <= 0.0 || reward <= 0.0 || reward / risk < strategy_min_rr_ratio)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(tp, digits);
      req.reason = "GH_ASIAN_SWEEP_LONG";
      g_signal_used_for_day = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed structural SL/TP only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card specifies exits via Asian-range target, structural stop, and framework Friday close.
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
