#property strict
#property version   "5.0"
#property description "QM5_10687 TradingView Parent Session Sweep Reclaim"

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
input int    qm_ea_id                   = 10687;
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
input int    strategy_asia_start_hour_utc       = 0;
input int    strategy_asia_end_hour_utc         = 8;
input int    strategy_london_start_hour_utc     = 8;
input int    strategy_london_end_hour_utc       = 16;
input int    strategy_newyork_start_hour_utc    = 13;
input int    strategy_newyork_end_hour_utc      = 21;
input double strategy_min_rr                    = 1.5;
input bool   strategy_reclaim_filter            = true;
input int    strategy_atr_period                = 14;
input double strategy_stop_atr_buffer           = 0.10;
input int    strategy_session_lookback_bars     = 900;
input int    strategy_max_spread_points         = 60;
input int    strategy_rollover_start_hhmm_utc   = 2355;
input int    strategy_rollover_end_hhmm_utc     = 5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   const int hhmm = dt.hour * 100 + dt.min;

   if(strategy_rollover_start_hhmm_utc != strategy_rollover_end_hhmm_utc)
     {
      if(strategy_rollover_start_hhmm_utc < strategy_rollover_end_hhmm_utc)
        {
         if(hhmm >= strategy_rollover_start_hhmm_utc && hhmm < strategy_rollover_end_hhmm_utc)
            return true;
        }
      else
        {
         if(hhmm >= strategy_rollover_start_hhmm_utc || hhmm < strategy_rollover_end_hhmm_utc)
            return true;
        }
     }

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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int lookback = MathMax(96, MathMin(1000, strategy_session_lookback_bars));
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: bespoke parent-session range reconstruction, called only
   // by the framework's single QM_IsNewBar-gated Strategy_EntrySignal path.
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, lookback, rates);
   if(copied < 48)
      return false;

   const double open1 = rates[0].open;
   const double high1 = rates[0].high;
   const double low1 = rates[0].low;
   const double close1 = rates[0].close;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   const datetime last_bar_utc = QM_BrokerToUTC(rates[0].time);
   MqlDateTime last_dt;
   TimeToStruct(last_bar_utc, last_dt);
   last_dt.hour = 0;
   last_dt.min = 0;
   last_dt.sec = 0;
   const datetime today_utc = StructToTime(last_dt);

   int start_hours[3];
   int end_hours[3];
   start_hours[0] = MathMax(0, MathMin(23, strategy_asia_start_hour_utc));
   start_hours[1] = MathMax(0, MathMin(23, strategy_london_start_hour_utc));
   start_hours[2] = MathMax(0, MathMin(23, strategy_newyork_start_hour_utc));
   end_hours[0] = MathMax(0, MathMin(24, strategy_asia_end_hour_utc));
   end_hours[1] = MathMax(0, MathMin(24, strategy_london_end_hour_utc));
   end_hours[2] = MathMax(0, MathMin(24, strategy_newyork_end_hour_utc));

   int pair_parent[3];
   int pair_child[3];
   pair_parent[0] = 0; pair_child[0] = 1; // Asia -> London
   pair_parent[1] = 1; pair_child[1] = 2; // London -> New York
   pair_parent[2] = 0; pair_child[2] = 2; // Asia -> New York

   bool found_parent = false;
   double parent_high = 0.0;
   double parent_low = 0.0;
   datetime parent_start_best = 0;
   datetime child_end_best = 0;
   int best_pair = -1;

   for(int day_back = 0; day_back <= 3; ++day_back)
     {
      const datetime day_start = today_utc - (datetime)(day_back * 86400);
      for(int pair = 0; pair < 3; ++pair)
        {
         const int pidx = pair_parent[pair];
         const int cidx = pair_child[pair];
         datetime parent_start = day_start + (datetime)(start_hours[pidx] * 3600);
         datetime parent_end = day_start + (datetime)(end_hours[pidx] * 3600);
         datetime child_start = day_start + (datetime)(start_hours[cidx] * 3600);
         datetime child_end = day_start + (datetime)(end_hours[cidx] * 3600);
         if(end_hours[pidx] <= start_hours[pidx])
            parent_end += 86400;
         if(end_hours[cidx] <= start_hours[cidx])
            child_end += 86400;
         if(child_start < parent_start)
           {
            child_start += 86400;
            child_end += 86400;
           }
         if(child_end >= last_bar_utc || child_end <= parent_end)
            continue;

         bool have_parent = false;
         bool have_child = false;
         double ph = -DBL_MAX;
         double pl = DBL_MAX;
         double ch = -DBL_MAX;
         double cl = DBL_MAX;

         for(int i = 0; i < copied; ++i)
           {
            const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
            if(bar_utc >= parent_start && bar_utc < parent_end)
              {
               if(rates[i].high > ph)
                  ph = rates[i].high;
               if(rates[i].low < pl)
                  pl = rates[i].low;
               have_parent = true;
              }
            if(bar_utc >= child_start && bar_utc < child_end)
              {
               if(rates[i].high > ch)
                  ch = rates[i].high;
               if(rates[i].low < cl)
                  cl = rates[i].low;
               have_child = true;
              }
           }

         if(!have_parent || !have_child)
            continue;
         if(ph < ch || pl > cl)
            continue;
         if(found_parent && child_end <= child_end_best)
            continue;

         found_parent = true;
         parent_high = ph;
         parent_low = pl;
         parent_start_best = parent_start;
         child_end_best = child_end;
         best_pair = pair;
        }
     }

   if(!found_parent || parent_high <= parent_low)
      return false;

   static long last_traded_parent_key = -1;
   const long parent_key = ((long)parent_start_best / 60L) * 10L + (long)best_pair;
   if(parent_key == last_traded_parent_key)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(strategy_stop_atr_buffer > 0.0 && atr <= 0.0)
      return false;

   const double buffer = MathMax(0.0, strategy_stop_atr_buffer) * atr;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const bool bullish_reclaim = (low1 < parent_low && close1 > parent_low);
   const bool bearish_reclaim = (high1 > parent_high && close1 < parent_high);

   if(bullish_reclaim && (!strategy_reclaim_filter || close1 > open1))
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double entry = (ask > 0.0) ? ask : close1;
      const double sl = NormalizeDouble(low1 - buffer, digits);
      const double tp = NormalizeDouble(parent_high, digits);
      const double risk = MathAbs(entry - sl);
      const double reward = MathAbs(tp - entry);
      if(entry > 0.0 && sl > 0.0 && sl < entry && tp > entry &&
         risk > 0.0 && reward / risk >= strategy_min_rr)
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "PARENT_SWEEP_RECLAIM_LONG";
         last_traded_parent_key = parent_key;
         return true;
        }
     }

   if(bearish_reclaim && (!strategy_reclaim_filter || close1 < open1))
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double entry = (bid > 0.0) ? bid : close1;
      const double sl = NormalizeDouble(high1 + buffer, digits);
      const double tp = NormalizeDouble(parent_low, digits);
      const double risk = MathAbs(sl - entry);
      const double reward = MathAbs(entry - tp);
      if(entry > 0.0 && sl > entry && tp > 0.0 && tp < entry &&
         risk > 0.0 && reward / risk >= strategy_min_rr)
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "PARENT_SWEEP_RECLAIM_SHORT";
         last_traded_parent_key = parent_key;
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial-close, or scale-in rules.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   datetime open_time_broker = 0;
   bool have_position = false;
   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_time_broker = (datetime)PositionGetInteger(POSITION_TIME);
      have_position = true;
      break;
     }
   if(!have_position || open_time_broker <= 0)
      return false;

   const datetime open_utc = QM_BrokerToUTC(open_time_broker);
   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());

   int start_hours[3];
   int end_hours[3];
   start_hours[0] = MathMax(0, MathMin(23, strategy_asia_start_hour_utc));
   start_hours[1] = MathMax(0, MathMin(23, strategy_london_start_hour_utc));
   start_hours[2] = MathMax(0, MathMin(23, strategy_newyork_start_hour_utc));
   end_hours[0] = MathMax(0, MathMin(24, strategy_asia_end_hour_utc));
   end_hours[1] = MathMax(0, MathMin(24, strategy_london_end_hour_utc));
   end_hours[2] = MathMax(0, MathMin(24, strategy_newyork_end_hour_utc));

   MqlDateTime open_dt;
   TimeToStruct(open_utc, open_dt);
   open_dt.hour = 0;
   open_dt.min = 0;
   open_dt.sec = 0;
   const datetime open_day = StructToTime(open_dt);

   datetime exit_utc = 0;
   for(int day_offset = -1; day_offset <= 2; ++day_offset)
     {
      const datetime day_start = open_day + (datetime)(day_offset * 86400);
      for(int idx = 0; idx < 3; ++idx)
        {
         datetime session_start = day_start + (datetime)(start_hours[idx] * 3600);
         datetime session_end = day_start + (datetime)(end_hours[idx] * 3600);
         if(end_hours[idx] <= start_hours[idx])
            session_end += 86400;

         if(open_utc >= session_start && open_utc < session_end)
           {
            exit_utc = session_end;
            break;
           }

         if(session_start > open_utc && (exit_utc == 0 || session_end < exit_utc))
            exit_utc = session_end;
        }
      if(exit_utc > 0 && open_utc < exit_utc)
         break;
     }

   if(exit_utc <= 0)
      return false;
   return (now_utc >= exit_utc);
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
