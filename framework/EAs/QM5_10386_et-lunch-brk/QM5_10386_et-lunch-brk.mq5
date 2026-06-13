#property strict
#property version   "5.0"
#property description "QM5_10386 Elite Trader Lunch Breakout"

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
input int    qm_ea_id                   = 10386;
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
input int    strategy_range_bars        = 15;
input double strategy_stop_factor       = 0.30;
input int    strategy_trigger_ticks     = 1;
input int    strategy_atr_period        = 20;
input double strategy_max_range_atr_mult = 1.50;
input int    strategy_lunch_hhmm        = 1900;
input int    strategy_close_hhmm        = 2200;
input bool   strategy_allow_monday      = true;
input bool   strategy_allow_tuesday     = true;
input bool   strategy_allow_wednesday   = true;
input bool   strategy_allow_thursday    = true;
input bool   strategy_allow_friday      = true;

int  g_etlb_day_key = -1;
bool g_etlb_buy_submitted_today = false;
bool g_etlb_sell_submitted_today = false;
bool g_etlb_cycle_done_today = false;
int  g_etlb_range_day_key = -1;
bool g_etlb_range_ready = false;
bool g_etlb_range_valid = false;
double g_etlb_lunch_high = 0.0;
double g_etlb_lunch_low = 0.0;

int ETLB_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int ETLB_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool ETLB_DayAllowed(const datetime t)
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

void ETLB_RefreshDayState(const datetime broker_now)
  {
   const int day_key = ETLB_DayKey(broker_now);
   if(day_key == g_etlb_day_key)
      return;

   g_etlb_day_key = day_key;
   g_etlb_buy_submitted_today = false;
   g_etlb_sell_submitted_today = false;
   g_etlb_cycle_done_today = false;
   g_etlb_range_day_key = -1;
   g_etlb_range_ready = false;
   g_etlb_range_valid = false;
   g_etlb_lunch_high = 0.0;
   g_etlb_lunch_low = 0.0;
  }

bool ETLB_HasOpenPositionForMagic()
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
        {
         g_etlb_cycle_done_today = true;
         return true;
        }
     }
   return false;
  }

bool ETLB_HasPendingTypeForMagic(const ENUM_ORDER_TYPE order_type)
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
        {
         if(order_type == ORDER_TYPE_BUY_STOP)
            g_etlb_buy_submitted_today = true;
         if(order_type == ORDER_TYPE_SELL_STOP)
            g_etlb_sell_submitted_today = true;
         return true;
        }
     }
   return false;
  }

int ETLB_PendingCountForMagic()
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

      const ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_STOP)
         ++count;
     }
   return count;
  }

void ETLB_DeletePendingOrdersForMagic(const string reason)
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

      const ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_STOP && t != ORDER_TYPE_SELL_STOP)
         continue;

      if(!QM_TM_RemovePendingOrder(ticket, reason))
         QM_LogEvent(QM_WARN, "ETLB_CANCEL_FAILED", StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\"}", ticket, QM_LoggerEscapeJson(reason)));
     }
  }

bool ETLB_ComputeLunchRange(double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;

   const int bars = MathMax(1, strategy_range_bars);
   for(int i = 1; i <= bars; ++i)
     {
      const double hi = iHigh(_Symbol, _Period, i); // perf-allowed: bounded lunch-range structural scan inside framework-gated EntrySignal.
      const double lo = iLow(_Symbol, _Period, i);  // perf-allowed: bounded lunch-range structural scan inside framework-gated EntrySignal.
      if(hi <= 0.0 || lo <= 0.0)
         return false;
      range_high = MathMax(range_high, hi);
     range_low = MathMin(range_low, lo);
     }
   return (range_high > range_low && range_low > 0.0);
  }

void ETLB_EnsureLunchRange(const datetime broker_now)
  {
   const int day_key = ETLB_DayKey(broker_now);
   if(g_etlb_range_ready && g_etlb_range_day_key == day_key)
      return;

   g_etlb_range_day_key = day_key;
   g_etlb_range_ready = true;
   g_etlb_range_valid = false;
   g_etlb_lunch_high = 0.0;
   g_etlb_lunch_low = 0.0;

   double lunch_high = 0.0;
   double lunch_low = 0.0;
   if(!ETLB_ComputeLunchRange(lunch_high, lunch_low))
      return;

   const double range = lunch_high - lunch_low;
   const double spread = ETLB_SpreadDistance();
   if(spread <= 0.0 || range < 4.0 * spread)
      return;

   const double atr = QM_ATR(_Symbol, _Period, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0 || range > strategy_max_range_atr_mult * atr)
      return;

   g_etlb_lunch_high = lunch_high;
   g_etlb_lunch_low = lunch_low;
   g_etlb_range_valid = true;
  }

double ETLB_SpreadDistance()
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

int ETLB_SecondsUntilClose(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   dt.hour = strategy_close_hhmm / 100;
   dt.min = strategy_close_hhmm % 100;
   dt.sec = 0;
   const datetime close_time = StructToTime(dt);
   const int seconds = (int)(close_time - broker_now);
   return MathMax(60, seconds);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   ETLB_RefreshDayState(TimeCurrent());
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
   ETLB_RefreshDayState(broker_now);
   const int hhmm = ETLB_HHMM(broker_now);
   if(hhmm < strategy_lunch_hhmm || hhmm >= strategy_close_hhmm)
      return false;
   if(!ETLB_DayAllowed(broker_now))
      return false;
   if(ETLB_HasOpenPositionForMagic())
     {
      ETLB_DeletePendingOrdersForMagic("filled_position");
      return false;
     }

   const bool has_buy_pending = ETLB_HasPendingTypeForMagic(ORDER_TYPE_BUY_STOP);
   const bool has_sell_pending = ETLB_HasPendingTypeForMagic(ORDER_TYPE_SELL_STOP);
   if(g_etlb_cycle_done_today || (g_etlb_buy_submitted_today && g_etlb_sell_submitted_today))
     {
      g_etlb_cycle_done_today = true;
      return false;
     }

   if(ETLB_PendingCountForMagic() >= 2)
      return false;

   ETLB_EnsureLunchRange(broker_now);
   if(!g_etlb_range_valid)
      return false;

   const double range = g_etlb_lunch_high - g_etlb_lunch_low;
   const double spread = ETLB_SpreadDistance();
   if(spread <= 0.0 || range <= 0.0)
      return false;
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double trigger = MathMax(1, strategy_trigger_ticks) * ((tick_size > 0.0) ? tick_size : point);
   if(trigger <= 0.0)
      return false;

   const double min_stop = 4.0 * spread;
   const int expiration_seconds = ETLB_SecondsUntilClose(broker_now);

   if(!g_etlb_buy_submitted_today && !has_buy_pending &&
      !g_etlb_sell_submitted_today && !has_sell_pending)
     {
      QM_EntryRequest sell_req;
      sell_req.type = QM_SELL_STOP;
      sell_req.price = QM_TM_NormalizePrice(_Symbol, g_etlb_lunch_low - trigger);
      sell_req.sl = QM_TM_NormalizePrice(_Symbol, MathMax(g_etlb_lunch_high + strategy_stop_factor * range,
                                                          sell_req.price + min_stop));
      sell_req.tp = 0.0;
      sell_req.reason = "QM5_10386_LUNCH_BRK_SELL_STOP";
      sell_req.symbol_slot = qm_magic_slot_offset;
      sell_req.expiration_seconds = expiration_seconds;

      if(sell_req.price > 0.0 && sell_req.sl > sell_req.price)
        {
         ulong sell_ticket = 0;
         if(QM_TM_OpenPosition(sell_req, sell_ticket))
            g_etlb_sell_submitted_today = true;
        }
     }

   if(!g_etlb_buy_submitted_today && !has_buy_pending)
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, g_etlb_lunch_high + trigger);
      const double raw_sl = g_etlb_lunch_low - strategy_stop_factor * range;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = QM_TM_NormalizePrice(_Symbol, MathMin(raw_sl, entry - min_stop));
      req.tp = 0.0;
      req.reason = "QM5_10386_LUNCH_BRK_BUY_STOP";
      req.expiration_seconds = expiration_seconds;
      g_etlb_buy_submitted_today = true;
      return (req.price > 0.0 && req.sl > 0.0 && req.sl < req.price);
     }

   if(!g_etlb_sell_submitted_today && !has_sell_pending)
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, g_etlb_lunch_low - trigger);
      const double raw_sl = g_etlb_lunch_high + strategy_stop_factor * range;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = QM_TM_NormalizePrice(_Symbol, MathMax(raw_sl, entry + min_stop));
      req.tp = 0.0;
      req.reason = "QM5_10386_LUNCH_BRK_SELL_STOP";
      req.expiration_seconds = expiration_seconds;
      g_etlb_sell_submitted_today = true;
      return (req.price > 0.0 && req.sl > req.price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ETLB_RefreshDayState(TimeCurrent());
   if(ETLB_HasOpenPositionForMagic())
      ETLB_DeletePendingOrdersForMagic("opposite_stop_after_fill");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   ETLB_RefreshDayState(broker_now);
   if(ETLB_HHMM(broker_now) < strategy_close_hhmm)
      return false;

   ETLB_DeletePendingOrdersForMagic("session_close");
   return ETLB_HasOpenPositionForMagic();
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
