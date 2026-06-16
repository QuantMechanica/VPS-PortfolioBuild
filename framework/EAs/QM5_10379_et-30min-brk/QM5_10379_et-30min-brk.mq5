#property strict
#property version   "5.0"
#property description "QM5_10379 Elite Trader 30 Minute Breakout"
// rework v2 2026-06-16: session HHMMs were raw NY-exchange time (0930/1600) but
// TimeCurrent() is DXZ broker time (GMT+2/+3); set file has card_defaults_source=
// not_found so it cannot override. Range/entry window fell on the US overnight
// (~02:30-09:00 ET) -> 0 RTH breakouts -> MIN_TRADES_NOT_MET. Converted defaults
// to broker time (US cash 09:30 ET=15:30, 16:00 ET=22:00) per sibling US-index
// session-breakout convention (coi-flow=1540, residual-rev=1530, oops-gap=1630).

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
input int    qm_ea_id                   = 10379;
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
input int    strategy_session_start_hhmm = 1530;  // broker time = 09:30 ET US cash open
input int    strategy_range_minutes      = 30;
input int    strategy_latest_entry_hhmm  = 2200;  // broker time = 16:00 ET US cash close
input int    strategy_session_close_hhmm = 2200;  // broker time = 16:00 ET US cash close
input int    strategy_atr_period         = 20;
input double strategy_initial_stop_atr   = 0.75;
input double strategy_breakeven_atr      = 0.75;
input double strategy_trail_atr          = 0.75;
input double strategy_max_range_atr      = 1.50;
input double strategy_min_range_spreads  = 4.00;

int      g_strategy_day_key = 0;
int      g_strategy_range_bars = 0;
bool     g_strategy_range_ready = false;
bool     g_strategy_orders_placed = false;
bool     g_strategy_position_seen = false;
double   g_strategy_range_high = 0.0;
double   g_strategy_range_low = 0.0;

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_MinutesFromHHMM(const int hhmm)
  {
   const int h = MathMax(0, MathMin(23, hhmm / 100));
   const int m = MathMax(0, MathMin(59, hhmm % 100));
   return h * 60 + m;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

void Strategy_ResetSession(const datetime t)
  {
   const int day_key = Strategy_DayKey(t);
   if(day_key == g_strategy_day_key)
      return;

   g_strategy_day_key = day_key;
   g_strategy_range_bars = 0;
   g_strategy_range_ready = false;
   g_strategy_orders_placed = false;
   g_strategy_position_seen = false;
   g_strategy_range_high = 0.0;
   g_strategy_range_low = 0.0;
  }

double Strategy_CurrentSpreadPrice()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return 0.0;
   return ask - bid;
  }

bool Strategy_InEntryWindow(const datetime t)
  {
   const int now_min = Strategy_MinuteOfDay(t);
   const int start_min = Strategy_MinutesFromHHMM(strategy_session_start_hhmm) + MathMax(1, strategy_range_minutes);
   const int end_min = Strategy_MinutesFromHHMM(strategy_latest_entry_hhmm);
   return (now_min >= start_min && now_min < end_min);
  }

bool Strategy_AfterSessionClose(const datetime t)
  {
   return (Strategy_MinuteOfDay(t) >= Strategy_MinutesFromHHMM(strategy_session_close_hhmm));
  }

int Strategy_SecondsToSessionClose(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int close_min = Strategy_MinutesFromHHMM(strategy_session_close_hhmm);
   dt.hour = close_min / 60;
   dt.min = close_min % 60;
   dt.sec = 0;
   datetime close_time = StructToTime(dt);
   if(close_time <= t)
      close_time += 86400;
   return (int)MathMax(60, close_time - t);
  }

bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      g_strategy_position_seen = true;
      return true;
     }
   return false;
  }

bool Strategy_HasOurPendingStop()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;
      request.symbol = _Symbol;
      request.comment = reason;

      string error_class = BROKER_OTHER;
      QM_TradeContextSend(request, result, error_class);
     }
  }

bool Strategy_BuildRequest(const QM_OrderType type,
                           const double entry,
                           const double stop_distance,
                           const int expiration_seconds,
                           const string reason,
                           QM_EntryRequest &req)
  {
   req.type = type;
   req.price = QM_TM_NormalizePrice(_Symbol, entry);
   req.sl = (QM_OrderTypeIsBuy(type))
            ? QM_TM_NormalizePrice(_Symbol, entry - stop_distance)
            : QM_TM_NormalizePrice(_Symbol, entry + stop_distance);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;

   if(req.price <= 0.0 || req.sl <= 0.0 || stop_distance <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(type) && req.sl >= req.price)
      return false;
   if(!QM_OrderTypeIsBuy(type) && req.sl <= req.price)
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetSession(now);

   if(Strategy_HasOurPosition() || Strategy_HasOurPendingStop())
      return false;
   if(Strategy_AfterSessionClose(now))
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

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;
   Strategy_ResetSession(bar_time);

   if(strategy_range_minutes <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_initial_stop_atr <= 0.0 ||
      strategy_breakeven_atr <= 0.0 ||
      strategy_trail_atr <= 0.0 ||
      strategy_max_range_atr <= 0.0 ||
      strategy_min_range_spreads <= 0.0)
      return false;

   if(g_strategy_orders_placed || g_strategy_position_seen ||
      Strategy_HasOurPosition() || Strategy_HasOurPendingStop())
      return false;

   const int bar_min = Strategy_MinuteOfDay(bar_time);
   const int range_start = Strategy_MinutesFromHHMM(strategy_session_start_hhmm);
   const int range_end = range_start + MathMax(1, strategy_range_minutes);
   if(bar_min >= range_start && bar_min < range_end)
     {
      const double high = iHigh(_Symbol, _Period, 1);
      const double low = iLow(_Symbol, _Period, 1);
      if(high <= 0.0 || low <= 0.0 || high <= low)
         return false;

      if(g_strategy_range_bars == 0)
        {
         g_strategy_range_high = high;
         g_strategy_range_low = low;
        }
      else
        {
         g_strategy_range_high = MathMax(g_strategy_range_high, high);
         g_strategy_range_low = MathMin(g_strategy_range_low, low);
        }

      ++g_strategy_range_bars;
      const int period_seconds = MathMax(60, PeriodSeconds((ENUM_TIMEFRAMES)_Period));
      const int bars_needed = MathMax(1, (strategy_range_minutes * 60 + period_seconds - 1) / period_seconds);
      if(g_strategy_range_bars >= bars_needed)
         g_strategy_range_ready = true;
     }

   if(!g_strategy_range_ready || !Strategy_InEntryWindow(TimeCurrent()))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = Strategy_CurrentSpreadPrice();
   if(ask <= 0.0 || bid <= 0.0 || spread <= 0.0)
      return false;

   const double range_width = g_strategy_range_high - g_strategy_range_low;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(range_width <= 0.0 || atr <= 0.0)
      return false;
   if(range_width < strategy_min_range_spreads * spread)
      return false;
   if(range_width > strategy_max_range_atr * atr)
      return false;

   const double stop_distance = strategy_initial_stop_atr * atr;
   const int expiration_seconds = Strategy_SecondsToSessionClose(TimeCurrent());

   QM_EntryRequest buy_req;
   const QM_OrderType buy_type = (ask >= g_strategy_range_high) ? QM_BUY : QM_BUY_STOP;
   const double buy_entry = (buy_type == QM_BUY) ? ask : g_strategy_range_high;
   if(!Strategy_BuildRequest(buy_type, buy_entry, stop_distance, expiration_seconds,
                             "ET_30MIN_BRK_LONG", buy_req))
      return false;

   const QM_OrderType sell_type = (bid <= g_strategy_range_low) ? QM_SELL : QM_SELL_STOP;
   const double sell_entry = (sell_type == QM_SELL) ? bid : g_strategy_range_low;
   if(!Strategy_BuildRequest(sell_type, sell_entry, stop_distance, expiration_seconds,
                             "ET_30MIN_BRK_SHORT", req))
      return false;

   if(buy_type == QM_BUY_STOP && buy_req.price <= ask)
      return false;
   if(sell_type == QM_SELL_STOP && req.price >= bid)
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   g_strategy_orders_placed = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetSession(now);

   if(Strategy_AfterSessionClose(now))
      Strategy_CancelOurPendingStops("et_30min_session_close");

   if(!Strategy_HasOurPosition())
      return;

   Strategy_CancelOurPendingStops("et_30min_opposite_after_fill");

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(point <= 0.0 || atr <= 0.0)
      return;

   const double be_trigger = strategy_breakeven_atr * atr;
   const double trail_dist = strategy_trail_atr * atr;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0)
         continue;

      const double profit = is_buy ? (market - open_price) : (open_price - market);
      if(profit < be_trigger)
         continue;

      double target_sl = is_buy ? MathMax(open_price, market - trail_dist)
                                : MathMin(open_price, market + trail_dist);
      target_sl = QM_TM_NormalizePrice(_Symbol, target_sl);
      if(target_sl <= 0.0)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5 && target_sl < market)
                                    : (target_sl < current_sl - point * 0.5 && target_sl > market));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "et_30min_be_trail_atr");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_AfterSessionClose(TimeCurrent()))
      return false;
   return Strategy_HasOurPosition();
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
