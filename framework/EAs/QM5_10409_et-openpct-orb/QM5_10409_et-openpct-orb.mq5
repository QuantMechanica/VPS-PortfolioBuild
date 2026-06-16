#property strict
#property version   "5.0"
#property description "QM5_10409 Elite Trader Open-Percent Afternoon ORB"
// rework v2 2026-06-16: (1) US/DAX session-open mapped to wrong broker time
//   (DXZ NY-Close = GMT+2/+3 = ET+7h year-round): US cash open 09:30 ET = 16:30
//   broker (was 1530 = 08:30 ET, 1h pre-open); Xetra 09:00 CET = 10:00 broker
//   (was 0900 = 08:00 CET, 1h pre-open). (2) Stop-distance sanity cap used
//   ATR(20,M1): a fixed ~0.66%-of-open band (buy_mult-sell_mult) is structurally
//   far wider than 2.5x a 1-minute ATR, so the cap rejected ~every day
//   (s_trade_done=true) -> near-zero fills -> Q02 MIN_TRADES_NOT_MET. The cap is
//   meant to reject abnormal wide-gap days, which is a session-scale check ->
//   compute it on D1 (strategy_atr_tf).

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
input int    qm_ea_id                   = 10409;
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
input int    strategy_us_open_hhmm       = 1630;   // 09:30 ET cash open in DXZ broker time (ET+7h)
input int    strategy_us_arm_hhmm        = 2000;   // 13:00 ET
input int    strategy_us_last_entry_hhmm = 2159;   // 14:59 ET
input int    strategy_us_exit_hhmm       = 2200;   // 15:00 ET
input int    strategy_dax_open_hhmm      = 1000;   // 09:00 CET Xetra open in DXZ broker time (CET+1h)
input int    strategy_dax_arm_hhmm       = 1330;
input int    strategy_dax_last_entry_hhmm= 1529;
input int    strategy_dax_exit_hhmm      = 1530;
input double strategy_buy_mult           = 1.0033;
input double strategy_sell_mult          = 0.9967;
input int    strategy_atr_period         = 20;
// rework v2 2026-06-16: stop-distance sanity cap runs on D1 (session scale), not
// the M1 trading TF, so a ~0.66%-of-open band is normally WITHIN 2.5x ATR and the
// cap only rejects genuinely abnormal wide-gap days.
input ENUM_TIMEFRAMES strategy_atr_tf    = PERIOD_D1;
input double strategy_max_stop_atr_mult  = 2.5;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_MinutesFromHhmm(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

bool Strategy_IsDaxSymbol()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "GER40") >= 0);
  }

void Strategy_SessionTimes(int &open_hhmm, int &arm_hhmm, int &last_entry_hhmm, int &exit_hhmm)
  {
   if(Strategy_IsDaxSymbol())
     {
      open_hhmm = strategy_dax_open_hhmm;
      arm_hhmm = strategy_dax_arm_hhmm;
      last_entry_hhmm = strategy_dax_last_entry_hhmm;
      exit_hhmm = strategy_dax_exit_hhmm;
      return;
     }

   open_hhmm = strategy_us_open_hhmm;
   arm_hhmm = strategy_us_arm_hhmm;
   last_entry_hhmm = strategy_us_last_entry_hhmm;
   exit_hhmm = strategy_us_exit_hhmm;
  }

bool Strategy_TimeReached(const int now_hhmm, const int threshold_hhmm)
  {
   return Strategy_MinutesFromHhmm(now_hhmm) >= Strategy_MinutesFromHhmm(threshold_hhmm);
  }

bool Strategy_TimeBeforeOrAt(const int now_hhmm, const int threshold_hhmm)
  {
   return Strategy_MinutesFromHhmm(now_hhmm) <= Strategy_MinutesFromHhmm(threshold_hhmm);
  }

double Strategy_RoundToTick(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0 || price <= 0.0)
      return 0.0;
   return QM_TM_NormalizePrice(_Symbol, MathRound(price / tick_size) * tick_size);
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_HasOurOpenPosition()
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
         return true;
     }
   return false;
  }

bool Strategy_IsOurPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int Strategy_OurPendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
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
      if(Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

bool Strategy_DeletePendingOrder(const ulong ticket, const string reason)
  {
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   request.symbol = _Symbol;
   request.comment = reason;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   return QM_TradeContextSend(request, result, error_class);
  }

void Strategy_DeleteOurPendingStops(const string reason)
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
      if(!Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      Strategy_DeletePendingOrder(ticket, reason);
     }
  }

int Strategy_SecondsUntilExit()
  {
   int open_hhmm = 0;
   int arm_hhmm = 0;
   int last_entry_hhmm = 0;
   int exit_hhmm = 0;
   Strategy_SessionTimes(open_hhmm, arm_hhmm, last_entry_hhmm, exit_hhmm);

   const int now_min = Strategy_MinutesFromHhmm(Strategy_Hhmm(TimeCurrent()));
   int exit_min = Strategy_MinutesFromHhmm(exit_hhmm);
   int remaining = exit_min - now_min;
   if(remaining <= 0)
      remaining += 24 * 60;
   return MathMax(60, remaining * 60);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;

   int open_hhmm = 0;
   int arm_hhmm = 0;
   int last_entry_hhmm = 0;
   int exit_hhmm = 0;
   Strategy_SessionTimes(open_hhmm, arm_hhmm, last_entry_hhmm, exit_hhmm);

   const int now_hhmm = Strategy_Hhmm(TimeCurrent());
   if(!Strategy_TimeReached(now_hhmm, open_hhmm))
      return true;
   if(Strategy_TimeReached(now_hhmm, exit_hhmm))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0 || ask <= bid);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(strategy_buy_mult <= 1.0 ||
      strategy_sell_mult >= 1.0 ||
      strategy_sell_mult <= 0.0 ||
      strategy_atr_period <= 0 ||
      strategy_max_stop_atr_mult <= 0.0)
      return false;

   static int    s_day_key = -1;
   static bool   s_session_open_ready = false;
   static bool   s_orders_placed = false;
   static bool   s_trade_done = false;
   static double s_session_open = 0.0;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   const int day_key = Strategy_DayKey(bar_time);
   if(day_key != s_day_key)
     {
      s_day_key = day_key;
      s_session_open_ready = false;
      s_orders_placed = false;
      s_trade_done = false;
      s_session_open = 0.0;
     }

   if(Strategy_HasOurOpenPosition())
     {
      s_trade_done = true;
      return false;
     }
   if(s_trade_done || s_orders_placed || Strategy_OurPendingStopCount() > 0)
      return false;

   int open_hhmm = 0;
   int arm_hhmm = 0;
   int last_entry_hhmm = 0;
   int exit_hhmm = 0;
   Strategy_SessionTimes(open_hhmm, arm_hhmm, last_entry_hhmm, exit_hhmm);

   if(Strategy_Hhmm(bar_time) == open_hhmm)
     {
      const double open_price = iOpen(_Symbol, _Period, 1);
      if(open_price > 0.0)
        {
         s_session_open = open_price;
         s_session_open_ready = true;
        }
     }

   const int now_hhmm = Strategy_Hhmm(TimeCurrent());
   if(!s_session_open_ready ||
      !Strategy_TimeReached(now_hhmm, arm_hhmm) ||
      !Strategy_TimeBeforeOrAt(now_hhmm, last_entry_hhmm))
      return false;

   const double buy_stop = Strategy_RoundToTick(s_session_open * strategy_buy_mult);
   const double sell_stop = Strategy_RoundToTick(s_session_open * strategy_sell_mult);
   const double atr = QM_ATR(_Symbol, strategy_atr_tf, strategy_atr_period, 1);
   if(buy_stop <= 0.0 || sell_stop <= 0.0 || buy_stop <= sell_stop || atr <= 0.0)
      return false;

   const double stop_distance = buy_stop - sell_stop;
   if(stop_distance > strategy_max_stop_atr_mult * atr)
     {
      s_trade_done = true;
      return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   if(ask >= buy_stop && bid <= sell_stop)
      return false;

   if(ask >= buy_stop)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sell_stop;
      req.tp = 0.0;
      req.reason = "ET_OPENPCT_ORB_BUY_MARKET";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      s_orders_placed = true;
      return true;
     }

   if(bid <= sell_stop)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = buy_stop;
      req.tp = 0.0;
      req.reason = "ET_OPENPCT_ORB_SELL_MARKET";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      s_orders_placed = true;
      return true;
     }

   QM_EntryRequest buy_req;
   Strategy_InitRequest(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_stop;
   buy_req.sl = sell_stop;
   buy_req.tp = 0.0;
   buy_req.reason = "ET_OPENPCT_ORB_BUY_STOP";
   buy_req.expiration_seconds = Strategy_SecondsUntilExit();

   req.type = QM_SELL_STOP;
   req.price = sell_stop;
   req.sl = buy_stop;
   req.tp = 0.0;
   req.reason = "ET_OPENPCT_ORB_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = Strategy_SecondsUntilExit();

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   s_orders_placed = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurOpenPosition())
     {
      Strategy_DeleteOurPendingStops("opposite_stop_after_fill");
      return;
     }

   int open_hhmm = 0;
   int arm_hhmm = 0;
   int last_entry_hhmm = 0;
   int exit_hhmm = 0;
   Strategy_SessionTimes(open_hhmm, arm_hhmm, last_entry_hhmm, exit_hhmm);
   if(Strategy_TimeReached(Strategy_Hhmm(TimeCurrent()), exit_hhmm))
      Strategy_DeleteOurPendingStops("time_exit_pending_cleanup");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;

   int open_hhmm = 0;
   int arm_hhmm = 0;
   int last_entry_hhmm = 0;
   int exit_hhmm = 0;
   Strategy_SessionTimes(open_hhmm, arm_hhmm, last_entry_hhmm, exit_hhmm);
   return Strategy_TimeReached(Strategy_Hhmm(TimeCurrent()), exit_hhmm);
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
