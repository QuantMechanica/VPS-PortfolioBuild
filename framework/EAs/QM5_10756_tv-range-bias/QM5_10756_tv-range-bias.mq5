#property strict
#property version   "5.0"
#property description "QM5_10756 TradingView Session Bias Range Break"

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
input int    qm_ea_id                   = 10756;
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
input int    strategy_asia_start_hour      = 0;
input int    strategy_asia_end_hour        = 7;
input int    strategy_london_start_hour    = 7;
input int    strategy_london_end_hour      = 12;
input int    strategy_ny_range_start_hour  = 13;
input int    strategy_ny_range_end_hour    = 14;
input int    strategy_force_flat_hour      = 21;
input int    strategy_atr_period           = 14;
input double strategy_min_range_atr_mult   = 0.25;
input double strategy_max_range_atr_mult   = 3.00;
input double strategy_london_body_min_ratio = 0.55;
input int    strategy_retest_tolerance_points = 10;
input double strategy_rr_target            = 2.00;
input bool   strategy_one_trade_per_day    = true;

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

   const datetime broker_now = TimeCurrent();
   MqlDateTime now_dt;
   TimeToStruct(broker_now, now_dt);
   const int day_key = now_dt.year * 10000 + now_dt.mon * 100 + now_dt.day;

   static int  cached_day_key = 0;
   static int  retest_state = 0;       // 0 none, +1 long break, +2 long retest, -1 short break, -2 short retest.
   static bool trade_taken_today = false;

   if(day_key != cached_day_key)
     {
      cached_day_key = day_key;
      retest_state = 0;
      trade_taken_today = false;
     }

   if(strategy_one_trade_per_day && trade_taken_today)
      return false;
   if(now_dt.hour < strategy_ny_range_end_hour || now_dt.hour >= strategy_force_flat_hour)
      return false;

   MqlDateTime day_start_dt = now_dt;
   day_start_dt.hour = 0;
   day_start_dt.min = 0;
   day_start_dt.sec = 0;
   const datetime day_start = StructToTime(day_start_dt);

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   // perf-allowed: one broker-day M15 OHLC scan inside the framework new-bar entry gate for session ranges.
   const int copied = CopyRates(_Symbol, PERIOD_M15, day_start, broker_now, rates);
   if(copied < 20)
      return false;

   const int period_seconds = PeriodSeconds(PERIOD_M15);
   if(period_seconds <= 0)
      return false;
   const datetime current_bar_open = (datetime)((long)broker_now - ((long)broker_now % period_seconds));

   bool have_asia = false;
   bool have_london = false;
   bool have_ny = false;
   double asia_high = 0.0;
   double asia_low = 0.0;
   double london_high = 0.0;
   double london_low = 0.0;
   double london_open = 0.0;
   double london_close = 0.0;
   double ny_high = 0.0;
   double ny_low = 0.0;
   double last_close = 0.0;
   double last_high = 0.0;
   double last_low = 0.0;
   int closed_count = 0;

   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time >= current_bar_open)
         continue;

      MqlDateTime bar_dt;
      TimeToStruct(rates[i].time, bar_dt);
      const int h = bar_dt.hour;

      if(h >= strategy_asia_start_hour && h < strategy_asia_end_hour)
        {
         if(!have_asia)
           {
            asia_high = rates[i].high;
            asia_low = rates[i].low;
            have_asia = true;
           }
         else
           {
            asia_high = MathMax(asia_high, rates[i].high);
            asia_low = MathMin(asia_low, rates[i].low);
           }
        }

      if(h >= strategy_london_start_hour && h < strategy_london_end_hour)
        {
         if(!have_london)
           {
            london_high = rates[i].high;
            london_low = rates[i].low;
            london_open = rates[i].open;
            have_london = true;
           }
         else
           {
            london_high = MathMax(london_high, rates[i].high);
            london_low = MathMin(london_low, rates[i].low);
           }
         london_close = rates[i].close;
        }

      if(h >= strategy_ny_range_start_hour && h < strategy_ny_range_end_hour)
        {
         if(!have_ny)
           {
            ny_high = rates[i].high;
            ny_low = rates[i].low;
            have_ny = true;
           }
         else
           {
            ny_high = MathMax(ny_high, rates[i].high);
            ny_low = MathMin(ny_low, rates[i].low);
           }
        }

      last_close = rates[i].close;
      last_high = rates[i].high;
      last_low = rates[i].low;
      ++closed_count;
     }

   if(closed_count < 2 || !have_asia || !have_london || !have_ny)
      return false;
   if(asia_high <= asia_low || london_high <= london_low || ny_high <= ny_low)
      return false;

   const double london_range = london_high - london_low;
   const double london_body_ratio = MathAbs(london_close - london_open) / london_range;
   int bias = 0;
   if(london_close > asia_high && london_body_ratio >= strategy_london_body_min_ratio)
      bias = 1;
   else if(london_close < asia_low && london_body_ratio >= strategy_london_body_min_ratio)
      bias = -1;
   else
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double ny_range = ny_high - ny_low;
   if(atr <= 0.0 || ny_range < atr * strategy_min_range_atr_mult || ny_range > atr * strategy_max_range_atr_mult)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double tolerance = strategy_retest_tolerance_points * point;

   if(bias > 0)
     {
      if(retest_state < 0)
         retest_state = 0;
      if(retest_state == 0 && last_close > ny_high + tolerance)
        {
         retest_state = 1;
         return false;
        }
      if(retest_state == 1 && last_low <= ny_high + tolerance)
        {
         retest_state = 2;
         if(last_close <= ny_high + tolerance)
            return false;
        }
      if(retest_state == 2 && last_close > ny_high + tolerance)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0 || ny_low >= entry)
            return false;
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = ny_low;
         req.tp = QM_TakeRR(_Symbol, QM_BUY, entry, req.sl, strategy_rr_target);
         if(req.tp <= entry)
            return false;
         req.reason = "NY_RANGE_RETEST_BREAK_LONG";
         trade_taken_today = true;
         return true;
        }
     }
   else if(bias < 0)
     {
      if(retest_state > 0)
         retest_state = 0;
      if(retest_state == 0 && last_close < ny_low - tolerance)
        {
         retest_state = -1;
         return false;
        }
      if(retest_state == -1 && last_high >= ny_low - tolerance)
        {
         retest_state = -2;
         if(last_close >= ny_low - tolerance)
            return false;
        }
      if(retest_state == -2 && last_close < ny_low - tolerance)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0 || ny_high <= entry)
            return false;
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = ny_high;
         req.tp = QM_TakeRR(_Symbol, QM_SELL, entry, req.sl, strategy_rr_target);
         if(req.tp >= entry || req.tp <= 0.0)
            return false;
         req.reason = "NY_RANGE_RETEST_BREAK_SHORT";
         trade_taken_today = true;
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // P2 baseline has no breakeven, trailing, partial, or scale-out management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.hour >= strategy_force_flat_hour)
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
