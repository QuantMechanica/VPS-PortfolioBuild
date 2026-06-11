#property strict
#property version   "5.0"
#property description "QM5_9936 ForexFactory Range Breakout GMT+3 H1"

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
input int    qm_ea_id                   = 9936;
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
input int    strategy_range_start_hour_gmt3 = 1;
input int    strategy_range_end_hour_gmt3   = 6;
input int    strategy_order_cancel_hour_gmt3 = 13;
input int    strategy_session_close_hour_gmt3 = 20;
input int    strategy_atr_period            = 14;
input double strategy_min_range_atr_mult    = 0.4;
input double strategy_max_range_atr_mult    = 2.5;
input double strategy_trail_trigger_r       = 1.0;
input int    strategy_range_scan_bars       = 36;

double g_strategy_range_high = 0.0;
double g_strategy_range_low = 0.0;
int    g_strategy_range_day_key = -1;
int    g_strategy_orders_day_key = -1;
int    g_strategy_skip_day_key = -1;

int Strategy_Gmt3DayKey(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const datetime gmt3 = utc + 3 * 3600;
   MqlDateTime dt;
   TimeToStruct(gmt3, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_Gmt3Hour(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const datetime gmt3 = utc + 3 * 3600;
   MqlDateTime dt;
   TimeToStruct(gmt3, dt);
   return dt.hour;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool Strategy_IsOurPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int Strategy_RemoveOurPendingOrders(const string reason)
  {
   int removed = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(QM_TM_RemovePendingOrder(ticket, reason))
         removed++;
     }
   return removed;
  }

bool Strategy_HasOurPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
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

bool Strategy_BuildRangeForToday(const int day_key, double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;
   int bars_in_range = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, strategy_range_scan_bars, rates); // perf-allowed: closed-bar session range scan, bounded by input default 36.
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(Strategy_Gmt3DayKey(bar_time) != day_key)
         continue;
      const int hour = Strategy_Gmt3Hour(bar_time);
      if(hour < strategy_range_start_hour_gmt3 || hour >= strategy_range_end_hour_gmt3)
         continue;
      range_high = MathMax(range_high, rates[i].high);
      range_low = MathMin(range_low, rates[i].low);
      bars_in_range++;
     }

   return (bars_in_range >= (strategy_range_end_hour_gmt3 - strategy_range_start_hour_gmt3) &&
           range_high > range_low && range_low > 0.0);
  }

void Strategy_ResetDailyState(const int day_key)
  {
   if(g_strategy_range_day_key == day_key || g_strategy_orders_day_key == day_key || g_strategy_skip_day_key == day_key)
      return;
   g_strategy_range_high = 0.0;
   g_strategy_range_low = 0.0;
  }

void Strategy_PopulateEntry(QM_EntryRequest &req,
                            const QM_OrderType type,
                            const double entry,
                            const double sl,
                            const string reason)
  {
   req.type = type;
   req.price = Strategy_NormalizePrice(entry);
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): entry timing is enforced in
   // Strategy_EntrySignal; high-impact news is delegated to the V5 news gate.
   const int day_key = Strategy_Gmt3DayKey(TimeCurrent());
   Strategy_ResetDailyState(day_key);
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: at 06:00 GMT+3 place both stop orders around the completed
   // 01:00-06:00 GMT+3 range. Caller guarantees QM_IsNewBar() == true.
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime now = TimeCurrent();
   const int day_key = Strategy_Gmt3DayKey(now);
   const int hour = Strategy_Gmt3Hour(now);
   if(hour != strategy_range_end_hour_gmt3)
      return false;
   if(g_strategy_orders_day_key == day_key || g_strategy_skip_day_key == day_key)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_HasOurPendingOrders())
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!Strategy_BuildRangeForToday(day_key, range_high, range_low))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double range_height = range_high - range_low;
   if(atr <= 0.0 || range_height <= 0.0)
      return false;
   if(range_height < strategy_min_range_atr_mult * atr ||
      range_height > strategy_max_range_atr_mult * atr)
     {
      g_strategy_skip_day_key = day_key;
      return false;
     }

   g_strategy_range_high = range_high;
   g_strategy_range_low = range_low;
   g_strategy_range_day_key = day_key;

   QM_EntryRequest buy_req;
   Strategy_PopulateEntry(buy_req, QM_BUY_STOP, range_high, range_low, "FF_RANGE_BUY_STOP");
   ulong buy_ticket = 0;
   QM_TM_OpenPosition(buy_req, buy_ticket);

   Strategy_PopulateEntry(req, QM_SELL_STOP, range_low, range_high, "FF_RANGE_SELL_STOP");
   g_strategy_orders_day_key = day_key;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: cancel stale or opposite stop orders; after +1R trail
   // to the prior two completed H1 bars' structural lows/highs.
   const datetime now = TimeCurrent();
   const int hour = Strategy_Gmt3Hour(now);
   if(hour >= strategy_order_cancel_hour_gmt3)
      Strategy_RemoveOurPendingOrders("FF_RANGE_CANCEL_13_GMT3");

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      Strategy_RemoveOurPendingOrders("FF_RANGE_OPPOSITE_TRIGGERED");

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double risk_dist = MathAbs(open_price - current_sl);
      if(risk_dist <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < strategy_trail_trigger_r * risk_dist)
         continue;

      const double low1 = iLow(_Symbol, PERIOD_H1, 1);  // perf-allowed: constant two-bar structural trailing read.
      const double low2 = iLow(_Symbol, PERIOD_H1, 2);  // perf-allowed: constant two-bar structural trailing read.
      const double high1 = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: constant two-bar structural trailing read.
      const double high2 = iHigh(_Symbol, PERIOD_H1, 2); // perf-allowed: constant two-bar structural trailing read.
      if(low1 <= 0.0 || low2 <= 0.0 || high1 <= 0.0 || high2 <= 0.0)
         continue;

      const double target_sl = is_buy ? MathMin(low1, low2) : MathMax(high1, high2);
      const double normalized_sl = Strategy_NormalizePrice(target_sl);
      if(normalized_sl <= 0.0)
         continue;

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const bool improves = is_buy ? (normalized_sl > current_sl + point * 0.5)
                                   : (normalized_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, normalized_sl, "FF_RANGE_2BAR_SWING_TRAIL");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: deterministic session close at 20:00 GMT+3, or range
   // opposite-side touch if the original range state is available.
   const datetime now = TimeCurrent();
   if(Strategy_Gmt3Hour(now) >= strategy_session_close_hour_gmt3)
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || g_strategy_range_high <= 0.0 || g_strategy_range_low <= 0.0)
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= g_strategy_range_low)
         return true;
      if(pos_type == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= g_strategy_range_high)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: the card's high-impact 30-minute blackout is handled by
   // the framework's two-axis news inputs (PRE30_POST30 + DXZ compliance).
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
