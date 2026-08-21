#property strict
#property version   "5.0"
#property description "QM5_20147 ndx-ema50-momentum-d1 (V5)"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 9999;
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
input int strategy_ema_period = 50;

int      g_str127_ema_handle = INVALID_HANDLE;
datetime g_str127_last_state_bar = 0;
datetime g_str127_last_position_eval_bar = 0;
datetime g_str127_last_place_attempt_bar = 0;
datetime g_str127_last_cancel_attempt_bar = 0;
datetime g_str127_last_close_attempt_bar = 0;
datetime g_str127_last_data_log_bar = 0;

bool Strategy127_ConfigValid()
  {
   return (strategy_ema_period == 50);
  }

bool Strategy127_EnsureHandle()
  {
   if(g_str127_ema_handle == INVALID_HANDLE)
      g_str127_ema_handle =
         QM_IndMA(_Symbol,
                  PERIOD_D1,
                  strategy_ema_period,
                  MODE_EMA,
                  PRICE_CLOSE);
   return (g_str127_ema_handle != INVALID_HANDLE);
  }

bool Strategy127_HandleReady()
  {
   return (Strategy127_EnsureHandle() &&
           QM_IndicatorWarmupReady(g_str127_ema_handle,
                                   0, 1, 60, "STR-127_ema"));
  }

bool Strategy127_CurrentD1Bar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_D1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) forming-D1 clock for strategy-owned guards
   return (bar_time > 0);
  }

void Strategy127_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str127_last_data_log_bar)
      return;
   g_str127_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-127\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

double Strategy127_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick =
         SymbolInfoDouble(_Symbol,
                          SYMBOL_POINT);
   return tick;
  }

double Strategy127_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy127_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol,
                               units * tick);
  }

bool Strategy127_NewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol,
                             broker_time,
                             qm_news_mode_legacy);
  }

bool Strategy127_FindOwnPosition(
   ulong &ticket,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   datetime &position_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   position_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

int Strategy127_OwnPendingCount()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP ||
         order_type == ORDER_TYPE_SELL_STOP)
         ++count;
     }
   return count;
  }

bool Strategy127_DailySignalAlreadyConsumed(
   const datetime forming_time)
  {
   if(forming_time <= 0)
      return false;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const datetime setup_time =
         (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time >= forming_time)
         return true;
     }
   if(!HistorySelect(forming_time,
                     TimeCurrent()))
      return false;
   for(int i = 0; i < HistoryOrdersTotal(); ++i)
     {
      const ulong order = HistoryOrderGetTicket(i);
      if(order == 0 ||
         (int)HistoryOrderGetInteger(order, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(order, ORDER_SYMBOL) != _Symbol)
         continue;
      const datetime setup_time =
         (datetime)HistoryOrderGetInteger(order,
                                          ORDER_TIME_SETUP);
      if(setup_time >= forming_time)
         return true;
     }
   return false;
  }

bool Strategy127_CancelOwnPending(const string reason,
                                  const datetime forming_time,
                                  const bool paced)
  {
   if(Strategy127_OwnPendingCount() <= 0)
      return true;
   if(paced &&
      forming_time > 0 &&
      forming_time == g_str127_last_cancel_attempt_bar)
      return false;
   if(paced && forming_time > 0)
      g_str127_last_cancel_attempt_bar = forming_time;

   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return all_ok &&
          Strategy127_OwnPendingCount() == 0;
  }

bool Strategy127_PendingLegal(const bool buy_side,
                              const double entry,
                              const double sl,
                              const double bid,
                              const double ask)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy127_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_FREEZE_LEVEL);
   const double minimum =
      MathMax(tick,
              (double)MathMax(stops_level,
                              freeze_level) * point);
   if(buy_side)
      return (entry > ask &&
              sl < entry &&
              entry - ask + tick * 0.1 >= minimum &&
              entry - sl + tick * 0.1 >= minimum);
   return (entry < bid &&
           sl > entry &&
           bid - entry + tick * 0.1 >= minimum &&
           sl - entry + tick * 0.1 >= minimum);
  }

void Strategy127_PlaceDailyPending(const MqlRates &bar,
                                   const datetime forming_time,
                                   const bool buy_side)
  {
   if(forming_time <= 0 ||
      forming_time == g_str127_last_place_attempt_bar)
      return;
   g_str127_last_place_attempt_bar = forming_time;

   if(!Strategy127_NewsAllows(TimeCurrent()))
      return; // this closed D1 signal remains consumed
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry =
      Strategy127_AlignPrice(
         buy_side ? bar.high : bar.low,
         buy_side ? 1 : -1);
   const double sl =
      Strategy127_AlignPrice(
         buy_side ? bar.low : bar.high,
         buy_side ? -1 : 1);

   // A newly calculated stop already crossed at placement is skipped. Live
   // pendings that existed before a gap retain native broker stop semantics.
   if(!Strategy127_PendingLegal(buy_side,
                                entry,
                                sl,
                                bid,
                                ask))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-127\",\"reason\":\"fresh_pending_gap_or_geometry\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"bid\":%.8f,\"ask\":%.8f}",
            (long)bar.time,
            entry,
            sl,
            bid,
            ask));
      return;
     }

   QM_EntryRequest req;
   ZeroMemory(req);
   req.type = buy_side ? QM_BUY_STOP : QM_SELL_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason =
      buy_side
      ? "STR127_D1_EMA50_BUY_STOP"
      : "STR127_D1_EMA50_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   ulong ticket = 0;
   if(QM_TM_OpenPosition(req, ticket))
      g_str127_last_cancel_attempt_bar = 0;
  }

void Strategy127_ProcessFlatDailyBar(const datetime forming_time)
  {
   if(!Strategy127_HandleReady())
     {
      Strategy127_LogDataMissing("ema50_warmup",
                                 forming_time);
      return;
     }
   MqlRates bar;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_D1,
                  1,
                  bar)) // perf-allowed: one immutable just-closed D1 bar per forming-D1 transition
     {
      Strategy127_LogDataMissing("closed_d1_bar",
                                 forming_time);
      return;
     }
   const double ema =
      QM_IndicatorReadBuffer(g_str127_ema_handle,
                             0,
                             1); // perf-allowed: pooled EMA50 read at closed D1 shift 1
   if(!MathIsValidNumber(ema) ||
      ema == EMPTY_VALUE || ema <= 0.0 ||
      bar.close <= 0.0 ||
      bar.high <= bar.low)
     {
      Strategy127_LogDataMissing("closed_d1_ema",
                                 forming_time);
      return;
     }

   if(!Strategy127_CancelOwnPending(
         "daily_replace",
         forming_time,
         true))
      return;
   if(Strategy127_OwnPendingCount() > 0)
      return;

   if(bar.close > ema)
      Strategy127_PlaceDailyPending(bar,
                                    forming_time,
                                    true);
   else if(bar.close < ema)
      Strategy127_PlaceDailyPending(bar,
                                    forming_time,
                                    false);
   // Equality intentionally leaves the strategy flat with no pending.
  }

void Strategy127_ManagePosition(const datetime forming_time)
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   datetime position_time = 0;
   if(!Strategy127_FindOwnPosition(ticket,
                                   position_type,
                                   open_price,
                                   position_time))
      return;
   Strategy127_CancelOwnPending(
      "residual_after_fill",
      forming_time,
      true);
   if(forming_time <= position_time ||
      forming_time == g_str127_last_position_eval_bar)
      return;
   g_str127_last_position_eval_bar = forming_time;

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_D1,
                  1,
                  closed_bar)) // perf-allowed: one first-eligible profitable-close test at closed D1 shift 1
     {
      Strategy127_LogDataMissing("profitable_close_bar",
                                 forming_time);
      return;
     }
   const bool profitable =
      (position_type == POSITION_TYPE_BUY)
      ? closed_bar.close > open_price
      : closed_bar.close < open_price;
   if(!profitable ||
      forming_time == g_str127_last_close_attempt_bar)
      return;
   g_str127_last_close_attempt_bar = forming_time;
   if(!Strategy127_NewsAllows(TimeCurrent()))
     {
      QM_LogEvent(
         QM_WARN,
         "STRATEGY_EXIT",
         "{\"strategy\":\"STR-127\",\"reason\":\"profitable_close_deferred_by_compliance_news\"}");
      return;
     }
   QM_TM_ClosePosition(ticket,
                       QM_EXIT_STRATEGY);
  }

bool Strategy_NoTradeFilter()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   datetime position_time = 0;
   if(Strategy127_FindOwnPosition(ticket,
                                  position_type,
                                  open_price,
                                  position_time) ||
      Strategy127_OwnPendingCount() > 0)
      return false;
   if(_Period != PERIOD_D1 ||
      !Strategy127_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_D1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) D1 EMA warmup gate
   if(bars_available < 60)
      return true;
   return !Strategy127_HandleReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return false; // Manage owns all pending-order transitions
  }

void Strategy_ManageOpenPosition()
  {
   datetime forming_time = 0;
   if(!Strategy127_CurrentD1Bar(forming_time))
     {
      Strategy127_LogDataMissing("forming_d1_bar", 0);
      return;
     }

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   datetime position_time = 0;
   if(Strategy127_FindOwnPosition(ticket,
                                  position_type,
                                  open_price,
                                  position_time))
     {
      Strategy127_ManagePosition(forming_time);
      return;
     }
   if(Strategy127_DailySignalAlreadyConsumed(
         forming_time))
     {
      g_str127_last_state_bar = forming_time;
      return;
     }
   if(forming_time == g_str127_last_state_bar)
      return;
   g_str127_last_state_bar = forming_time;
   Strategy127_ProcessFlatDailyBar(forming_time);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(Strategy127_NewsAllows(broker_time))
      return false;
   datetime forming_time = 0;
   Strategy127_CurrentD1Bar(forming_time);
   Strategy127_CancelOwnPending("news_blackout",
                                forming_time,
                                true);

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   datetime position_time = 0;
   return !Strategy127_FindOwnPosition(ticket,
                                       position_type,
                                       open_price,
                                       position_time);
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
