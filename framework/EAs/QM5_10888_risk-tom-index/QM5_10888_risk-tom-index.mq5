#property strict
#property version   "5.0"
#property description "QM5_10888 Risk.net Index Turn-Of-Month Long Window"

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
input int    qm_ea_id                   = 10888;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period                 = 20;
input double strategy_atr_stop_mult              = 1.75;
input int    strategy_atr_percentile_lookback    = 252;
input double strategy_atr_skip_percentile        = 95.0;
input int    strategy_entry_days_before_month_end = 2;
input int    strategy_exit_trading_day_of_month  = 2;
input int    strategy_max_spread_points          = 0;
input bool   strategy_require_d1_period          = true;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int MonthOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

datetime DateFloor(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool HasScheduledTradeSession(const datetime date_time)
  {
   MqlDateTime dt;
   TimeToStruct(date_time, dt);

   datetime session_from = 0;
   datetime session_to = 0;
   for(uint session = 0; session < 10; ++session)
     {
      if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week,
                                session, session_from, session_to))
         return true;
     }

   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

datetime NextScheduledTradingDayAfter(const datetime bar_time)
  {
   const datetime day_start = DateFloor(bar_time);
   for(int day = 1; day <= 10; ++day)
     {
      const datetime candidate = day_start + (day * 86400);
      if(HasScheduledTradeSession(candidate))
         return candidate;
     }

   return 0;
  }

int ScheduledTradingDaysRemainingInMonthAfter(const datetime bar_time)
  {
   const int month = MonthOf(bar_time);
   const datetime day_start = DateFloor(bar_time);
   int remaining = 0;

   for(int day = 1; day <= 10; ++day)
     {
      const datetime candidate = day_start + (day * 86400);
      if(MonthOf(candidate) != month)
         break;
      if(HasScheduledTradeSession(candidate))
         remaining++;
     }

   return remaining;
  }

int TradingDayOrdinalInMonthForShift(const int shift)
  {
   const datetime target = iTime(_Symbol, PERIOD_D1, shift); // perf-allowed: calendar rule reads D1 session dates from MT5 bars.
   if(target <= 0)
      return 0;

   const int month = MonthOf(target);
   int ordinal = 0;
   for(int s = shift; s < shift + 40; ++s)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, s); // perf-allowed: bounded D1 calendar scan for trading-day ordinal.
      if(bar_time <= 0 || MonthOf(bar_time) != month)
         break;
      ordinal++;
     }

   return ordinal;
  }

bool IsNearD1SessionClose(const datetime current_d1)
  {
   const datetime next_d1 = NextScheduledTradingDayAfter(current_d1);
   if(next_d1 <= 0)
      return false;

   return (TimeCurrent() >= next_d1 - 60);
  }

bool GetOurPosition(datetime &open_time)
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

bool AtrPercentileAllowsEntry()
  {
   const int atr_period = (strategy_atr_period < 1) ? 1 : strategy_atr_period;
   const int lookback = (strategy_atr_percentile_lookback < 20) ? 20 : strategy_atr_percentile_lookback;
   double percentile = strategy_atr_skip_percentile;
   if(percentile < 1.0)
      percentile = 1.0;
   if(percentile > 99.9)
      percentile = 99.9;

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   double samples[];
   ArrayResize(samples, lookback);
   int count = 0;
   for(int i = 0; i < lookback; ++i)
     {
      const double value = QM_ATR(_Symbol, PERIOD_D1, atr_period, 2 + i);
      if(value <= 0.0)
         continue;
      samples[count] = value;
      count++;
     }

   const int min_samples = ((lookback / 2) < 20) ? 20 : (lookback / 2);
   if(count < min_samples)
      return false;

   ArrayResize(samples, count);
   ArraySort(samples);
   int index = (int)MathCeil((percentile / 100.0) * (double)count) - 1;
   if(index < 0)
      index = 0;
   if(index > count - 1)
      index = count - 1;

   return (current_atr <= samples[index]);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_require_d1_period && _Period != PERIOD_D1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime open_time = 0;
   if(GetOurPosition(open_time))
      return false;

   const datetime closed_d1 = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: entry calendar uses the just-closed D1 trading date.
   if(closed_d1 <= 0)
      return false;

   const int entry_offset = (strategy_entry_days_before_month_end < 1) ? 1 : strategy_entry_days_before_month_end;
   if(ScheduledTradingDaysRemainingInMonthAfter(closed_d1) != entry_offset)
      return false;

   if(!AtrPercentileAllowsEntry())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const int atr_period = (strategy_atr_period < 1) ? 1 : strategy_atr_period;
   const double atr = QM_ATR(_Symbol, PERIOD_D1, atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
   if(req.sl <= 0.0 || req.sl >= ask || ((ask - req.sl) / point) <= 0.0)
      return false;

   req.reason = "RISK_TOM_INDEX_LONG";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!GetOurPosition(open_time))
      return false;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: exit calendar uses current D1 trading date.
   if(current_d1 <= 0)
      return false;

   if(open_time > 0 && MonthOf(open_time) == MonthOf(current_d1))
      return false;

   const int exit_day = (strategy_exit_trading_day_of_month < 1) ? 1 : strategy_exit_trading_day_of_month;
   if(TradingDayOrdinalInMonthForShift(0) < exit_day)
      return false;

   return IsNearD1SessionClose(current_d1);
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10888\",\"ea\":\"risk_tom_index\"}");
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
