#property strict
#property version   "5.0"
#property description "QM5_9916 ForexFactory Roadmap ADR Failure M5"

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
input int    qm_ea_id                   = 9916;
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
input int    strategy_atr_period              = 14;
input int    strategy_ema_period              = 8;
input int    strategy_ema200_period           = 200;
input int    strategy_adr_days                = 14;
input int    strategy_session_start_hour      = 7;
input int    strategy_session_end_hour        = 17;
input double strategy_boundary_near_adr_mult  = 0.20;
input int    strategy_failure_lookback_bars   = 8;
input double strategy_failure_close_atr_mult  = 0.15;
input double strategy_sl_atr_buffer           = 0.25;
input double strategy_stop_min_atr            = 0.60;
input double strategy_stop_max_atr            = 2.40;
input double strategy_tp_r_multiple           = 1.60;
input double strategy_daily_range_min_adr     = 0.45;
input double strategy_max_spread_atr_pct      = 12.0;
input int    strategy_time_stop_bars          = 30;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return true;

   bool session_ok = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         session_ok = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
      else
         session_ok = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
     }
   if(!session_ok)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask < bid)
      return true;
   if(strategy_max_spread_atr_pct > 0.0 &&
      (ask - bid) > atr * strategy_max_spread_atr_pct / 100.0)
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

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   if(Strategy_NoTradeFilter())
      return false;

   if(strategy_atr_period <= 0 || strategy_ema_period <= 0 ||
      strategy_ema200_period <= 0 || strategy_adr_days <= 0 ||
      strategy_failure_lookback_bars <= 0 || strategy_time_stop_bars <= 0 ||
      strategy_stop_min_atr <= 0.0 || strategy_stop_max_atr <= strategy_stop_min_atr ||
      strategy_tp_r_multiple <= 0.0)
      return false;

   // perf-allowed: bounded structural OHLC reads for ADR/PDH/PDL failure logic, called only by the framework new-bar gate.
   const double day_open = iOpen(_Symbol, PERIOD_D1, 0);       // perf-allowed
   const double day_high = iHigh(_Symbol, PERIOD_D1, 0);       // perf-allowed
   const double day_low = iLow(_Symbol, PERIOD_D1, 0);         // perf-allowed
   const double pdh = iHigh(_Symbol, PERIOD_D1, 1);            // perf-allowed
   const double pdl = iLow(_Symbol, PERIOD_D1, 1);             // perf-allowed
   const double open1 = iOpen(_Symbol, PERIOD_M5, 1);          // perf-allowed
   const double high1 = iHigh(_Symbol, PERIOD_M5, 1);          // perf-allowed
   const double low1 = iLow(_Symbol, PERIOD_M5, 1);            // perf-allowed
   const double close1 = iClose(_Symbol, PERIOD_M5, 1);        // perf-allowed
   if(day_open <= 0.0 || day_high <= 0.0 || day_low <= 0.0 ||
      pdh <= 0.0 || pdl <= 0.0 || pdh <= pdl ||
      open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   double adr = 0.0;
   int adr_count = 0;
   for(int d = 1; d <= strategy_adr_days; ++d)
     {
      const double dh = iHigh(_Symbol, PERIOD_D1, d); // perf-allowed: bounded ADR loop behind closed-bar gate
      const double dl = iLow(_Symbol, PERIOD_D1, d);  // perf-allowed: bounded ADR loop behind closed-bar gate
      if(dh <= 0.0 || dl <= 0.0 || dh <= dl)
         continue;
      adr += (dh - dl);
      adr_count++;
     }
   if(adr_count <= 0)
      return false;
   adr /= (double)adr_count;

   if((day_high - day_low) < strategy_daily_range_min_adr * adr)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double ema_close1 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1, PRICE_CLOSE);
   const double ema200 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema200_period, 1, PRICE_CLOSE);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || ema_close1 <= 0.0 || ema200 <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   const double adr_high = day_open + adr;
   const double adr_low = day_open - adr;
   const double near_dist = strategy_boundary_near_adr_mult * adr;
   const double failure_dist = strategy_failure_close_atr_mult * atr;

   double long_boundary = 0.0;
   string long_name = "";
   double long_best_dist = DBL_MAX;
   if(MathAbs(close1 - adr_low) <= near_dist)
     {
      long_boundary = adr_low;
      long_name = "ADR_LOW";
      long_best_dist = MathAbs(close1 - adr_low);
     }
   if(MathAbs(close1 - pdl) <= near_dist && MathAbs(close1 - pdl) < long_best_dist)
     {
      long_boundary = pdl;
      long_name = "PDL";
      long_best_dist = MathAbs(close1 - pdl);
     }

   double short_boundary = 0.0;
   string short_name = "";
   double short_best_dist = DBL_MAX;
   if(MathAbs(close1 - adr_high) <= near_dist)
     {
      short_boundary = adr_high;
      short_name = "ADR_HIGH";
      short_best_dist = MathAbs(close1 - adr_high);
     }
   if(MathAbs(close1 - pdh) <= near_dist && MathAbs(close1 - pdh) < short_best_dist)
     {
      short_boundary = pdh;
      short_name = "PDH";
      short_best_dist = MathAbs(close1 - pdh);
     }

   bool long_breached = false;
   bool short_breached = false;
   if(long_boundary > 0.0)
     {
      for(int s = 2; s <= strategy_failure_lookback_bars + 1; ++s)
        {
         const double ema_low = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, s, PRICE_LOW);
         const double ema_close = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, s, PRICE_CLOSE);
         if((ema_low > 0.0 && ema_low < long_boundary) ||
            (ema_close > 0.0 && ema_close < long_boundary))
           {
            long_breached = true;
            break;
           }
        }
     }
   if(short_boundary > 0.0)
     {
      for(int s = 2; s <= strategy_failure_lookback_bars + 1; ++s)
        {
         const double ema_high = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, s, PRICE_HIGH);
         const double ema_close = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, s, PRICE_CLOSE);
         if((ema_high > 0.0 && ema_high > short_boundary) ||
            (ema_close > 0.0 && ema_close > short_boundary))
           {
            short_breached = true;
            break;
           }
        }
     }

   const bool long_signal = (long_breached &&
                             ema_close1 > long_boundary &&
                             close1 > ema_close1 &&
                             close1 > open1 &&
                             close1 >= long_boundary + failure_dist);
   const bool short_signal = (short_breached &&
                              ema_close1 < short_boundary &&
                              close1 < ema_close1 &&
                              close1 < open1 &&
                              close1 <= short_boundary - failure_dist);
   if(!long_signal && !short_signal)
      return false;

   double swing_low = low1;
   double swing_high = high1;
   for(int s = 2; s <= strategy_failure_lookback_bars + 1; ++s)
     {
      const double l = iLow(_Symbol, PERIOD_M5, s);  // perf-allowed: bounded failure swing read behind closed-bar gate
      const double h = iHigh(_Symbol, PERIOD_M5, s); // perf-allowed: bounded failure swing read behind closed-bar gate
      if(l > 0.0 && l < swing_low)
         swing_low = l;
      if(h > 0.0 && h > swing_high)
         swing_high = h;
     }

   if(long_signal)
     {
      const double entry = ask;
      const double sl = MathMin(swing_low, long_boundary - strategy_sl_atr_buffer * atr);
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
         return false;
      const double risk = entry - sl;
      if(risk < strategy_stop_min_atr * atr || risk > strategy_stop_max_atr * atr)
         return false;

      double tp = entry + strategy_tp_r_multiple * risk;
      if(day_open > entry && day_open < tp)
         tp = day_open;
      if(ema200 > entry && ema200 < tp)
         tp = ema200;
      if(adr_high > entry && adr_high < tp)
         tp = adr_high;
      if(pdh > entry && pdh < tp)
         tp = pdh;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FF_ROADMAP_ADR_FAIL_LONG_" + long_name;
      return (tp > entry);
     }

   const double entry = bid;
   const double sl = MathMax(swing_high, short_boundary + strategy_sl_atr_buffer * atr);
   if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
      return false;
   const double risk = sl - entry;
   if(risk < strategy_stop_min_atr * atr || risk > strategy_stop_max_atr * atr)
      return false;

   double tp = entry - strategy_tp_r_multiple * risk;
   if(day_open < entry && day_open > tp)
      tp = day_open;
   if(ema200 < entry && ema200 > tp)
      tp = ema200;
   if(adr_low < entry && adr_low > tp)
      tp = adr_low;
   if(pdl < entry && pdl > tp)
      tp = pdl;

   req.type = QM_SELL;
   req.sl = sl;
   req.tp = tp;
   req.reason = "FF_ROADMAP_ADR_FAIL_SHORT_" + short_name;
   return (tp < entry);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, scale-in, or scale-out logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_time_stop_bars <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int max_hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_M5);

   const double day_open = iOpen(_Symbol, PERIOD_D1, 0);    // perf-allowed: O(1) boundary read for open-position exit
   const double pdh = iHigh(_Symbol, PERIOD_D1, 1);         // perf-allowed: O(1) boundary read for open-position exit
   const double pdl = iLow(_Symbol, PERIOD_D1, 1);          // perf-allowed: O(1) boundary read for open-position exit
   const double ema_close1 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1, PRICE_CLOSE);
   if(day_open <= 0.0 || pdh <= 0.0 || pdl <= 0.0 || ema_close1 <= 0.0)
      return false;

   double adr = 0.0;
   int adr_count = 0;
   for(int d = 1; d <= strategy_adr_days; ++d)
     {
      const double dh = iHigh(_Symbol, PERIOD_D1, d); // perf-allowed: bounded ADR read only while a position may need boundary-cross exit
      const double dl = iLow(_Symbol, PERIOD_D1, d);  // perf-allowed: bounded ADR read only while a position may need boundary-cross exit
      if(dh <= 0.0 || dl <= 0.0 || dh <= dl)
         continue;
      adr += (dh - dl);
      adr_count++;
     }
   if(adr_count <= 0)
      return false;
   adr /= (double)adr_count;
   const double adr_high = day_open + adr;
   const double adr_low = day_open - adr;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(now - open_time >= max_hold_seconds)
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const string comment = PositionGetString(POSITION_COMMENT);
      if(open_price <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         double boundary = (StringFind(comment, "ADR_LOW") >= 0) ? adr_low : pdl;
         if(boundary <= 0.0)
            boundary = (adr_low < open_price && adr_low > pdl) ? adr_low : pdl;
         if(ema_close1 < boundary)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         double boundary = (StringFind(comment, "ADR_HIGH") >= 0) ? adr_high : pdh;
         if(boundary <= 0.0)
            boundary = (adr_high > open_price && adr_high < pdh) ? adr_high : pdh;
         if(ema_close1 > boundary)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework's standard high-impact news filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9916_ff-roadmap-adr-fail-m5\"}");
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
