#property strict
#property version   "5.0"
#property description "QM5_10388 Elite Trader afternoon opening range breakout"

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
input int    qm_ea_id                   = 10388;
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
input int    strategy_session_start_hhmm = 1530;
input int    strategy_range_minutes      = 210;
input double strategy_stop_factor        = 0.60;
input int    strategy_trigger_ticks      = 1;
input double strategy_min_range_spreads  = 6.0;
input int    strategy_close_hhmm         = 2200;
input bool   strategy_allow_monday       = true;
input bool   strategy_allow_tuesday      = true;
input bool   strategy_allow_wednesday    = true;
input bool   strategy_allow_thursday     = true;
input bool   strategy_allow_friday       = true;

int ETO_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime ETO_TimeToday(const datetime t, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = hhmm / 100;
   dt.min = hhmm % 100;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool ETO_DayAllowed(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.day_of_week == 1) return strategy_allow_monday;
   if(dt.day_of_week == 2) return strategy_allow_tuesday;
   if(dt.day_of_week == 3) return strategy_allow_wednesday;
   if(dt.day_of_week == 4) return strategy_allow_thursday;
   if(dt.day_of_week == 5) return strategy_allow_friday;
   return false;
  }

double ETO_SpreadDistance()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > bid && bid > 0.0)
      return ask - bid;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(point > 0.0 && spread_points > 0)
      return (double)spread_points * point;
   return 0.0;
  }

bool ETO_HasOpenPositionForMagic()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool ETO_HasPendingTypeForMagic(const ENUM_ORDER_TYPE order_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == order_type)
         return true;
     }
   return false;
  }

int ETO_PendingStopCountForMagic()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         ++count;
     }
   return count;
  }

void ETO_DeletePendingStopsForMagic(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
         continue;

      if(!QM_TM_RemovePendingOrder(ticket, reason))
         QM_LogEvent(QM_WARN, "ETO_CANCEL_FAILED", StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\"}", ticket, QM_LoggerEscapeJson(reason)));
     }
  }

bool ETO_HasTradeToday(const datetime broker_now)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime session_start = ETO_TimeToday(broker_now, strategy_session_start_hhmm);
   if(!HistorySelect(session_start, broker_now))
      return false;

   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

bool ETO_OpeningRange(double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;

   const datetime broker_now = TimeCurrent();
   const datetime session_start = ETO_TimeToday(broker_now, strategy_session_start_hhmm);
   const datetime range_end = session_start + MathMax(1, strategy_range_minutes) * 60;
   if(broker_now < range_end)
      return false;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, session_start, range_end, rates); // perf-allowed: ORB structural window, called only from closed-bar EntrySignal
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bt = rates[i].time;
      if(bt <= 0)
         return false;
      if(bt < session_start)
         continue;
      if(bt >= range_end)
         continue;

      const double hi = rates[i].high;
      const double lo = rates[i].low;
      if(hi <= 0.0 || lo <= 0.0)
         return false;
      range_high = MathMax(range_high, hi);
      range_low = MathMin(range_low, lo);
     }

   return (range_high > range_low && range_low > 0.0);
  }

int ETO_SecondsUntilClose(const datetime broker_now)
  {
   const datetime close_time = ETO_TimeToday(broker_now, strategy_close_hhmm);
   return MathMax(60, (int)(close_time - broker_now));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(!ETO_DayAllowed(broker_now))
      return true;
   if(ETO_HHMM(broker_now) >= strategy_close_hhmm)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!ETO_DayAllowed(broker_now))
      return false;
   if(ETO_HHMM(broker_now) >= strategy_close_hhmm)
      return false;
   if(ETO_HasOpenPositionForMagic())
     {
      ETO_DeletePendingStopsForMagic("opposite_stop_after_fill");
      return false;
     }
   if(ETO_HasTradeToday(broker_now))
     {
      ETO_DeletePendingStopsForMagic("one_trade_per_day");
      return false;
     }
   if(ETO_PendingStopCountForMagic() >= 2)
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!ETO_OpeningRange(range_high, range_low))
      return false;

   const double range = range_high - range_low;
   const double spread = ETO_SpreadDistance();
   if(spread <= 0.0 || range < strategy_min_range_spreads * spread)
      return false;

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double trigger = MathMax(1, strategy_trigger_ticks) * ((tick_size > 0.0) ? tick_size : point);
   if(trigger <= 0.0)
      return false;

   const double min_stop = 4.0 * spread;
   req.expiration_seconds = ETO_SecondsUntilClose(broker_now);

   if(!ETO_HasPendingTypeForMagic(ORDER_TYPE_BUY_STOP))
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, range_high + trigger);
      const double raw_sl = range_low - strategy_stop_factor * range;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = QM_TM_NormalizePrice(_Symbol, MathMin(raw_sl, entry - min_stop));
      req.reason = "QM5_10388_ORB_BUY_STOP";
      return (req.price > 0.0 && req.sl > 0.0 && req.sl < req.price);
     }

   if(!ETO_HasPendingTypeForMagic(ORDER_TYPE_SELL_STOP))
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, range_low - trigger);
      const double raw_sl = range_high + strategy_stop_factor * range;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = QM_TM_NormalizePrice(_Symbol, MathMax(raw_sl, entry + min_stop));
      req.reason = "QM5_10388_ORB_SELL_STOP";
      return (req.price > 0.0 && req.sl > req.price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(ETO_HasOpenPositionForMagic())
      ETO_DeletePendingStopsForMagic("filled_position");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   if(ETO_HHMM(broker_now) < strategy_close_hhmm)
      return false;

   ETO_DeletePendingStopsForMagic("session_close");
   return ETO_HasOpenPositionForMagic();
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
