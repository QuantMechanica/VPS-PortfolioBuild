#property strict
#property version   "5.0"
#property description "QM5_10827 TradingView Volatility Expansion"

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
input int    qm_ea_id                   = 10827;
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
input int    strategy_lookback_bars     = 20;
input int    strategy_atr_period        = 14;
input double strategy_outlier_mult      = 1.5;
input double strategy_rr_target         = 2.0;
input bool   strategy_midline_stop      = true;
input double strategy_atr_fallback_mult = 2.0;
input int    strategy_stale_bars        = 12;
input double strategy_max_range_atr     = 2.5;
input double strategy_min_stop_atr      = 0.5;
input double strategy_max_stop_atr      = 3.0;

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
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
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_Box(const int bars, double &box_high, double &box_low)
  {
   box_high = -DBL_MAX;
   box_low = DBL_MAX;
   if(bars < 2)
      return false;

   // perf-allowed: consolidation-box structure needs raw closed-bar highs/lows;
   // caller is the framework new-bar gated entry hook.
   for(int i = 1; i <= bars; ++i)
     {
      const double high = iHigh(_Symbol, _Period, i);
      const double low = iLow(_Symbol, _Period, i);
      if(high <= 0.0 || low <= 0.0)
         return false;
      box_high = MathMax(box_high, high);
      box_low = MathMin(box_low, low);
     }

   return (box_high > box_low && box_low > 0.0);
  }

bool Strategy_HasPendingStop(const ENUM_ORDER_TYPE desired_type)
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
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == desired_type)
         return true;
     }
   return false;
  }

void Strategy_CancelStaleStops()
  {
   const int magic = QM_FrameworkMagic();
   const int stale_seconds = MathMax(60, strategy_stale_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period));
   const datetime now = TimeCurrent();
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

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= stale_seconds)
         QM_TM_RemovePendingOrder(ticket, "tv_vol_exp_stale_stop");
     }
  }

bool Strategy_BuildStopRequest(const QM_OrderType type,
                               const double entry_price,
                               const double zone_mid,
                               const double atr,
                               QM_EntryRequest &req)
  {
   req.type = type;
   req.price = Strategy_NormalizePrice(entry_price);
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (type == QM_BUY_STOP) ? "TV_VOL_EXP_BUY_STOP" : "TV_VOL_EXP_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(60, strategy_stale_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period));

   if(req.price <= 0.0 || atr <= 0.0)
      return false;

   double stop_distance = strategy_midline_stop
                          ? MathAbs(req.price - zone_mid)
                          : atr * strategy_atr_fallback_mult;
   stop_distance = MathMax(stop_distance, atr * strategy_min_stop_atr);
   stop_distance = MathMin(stop_distance, atr * strategy_max_stop_atr);
   if(stop_distance <= 0.0)
      return false;

   if(type == QM_BUY_STOP)
     {
      req.sl = Strategy_NormalizePrice(req.price - stop_distance);
      req.tp = Strategy_NormalizePrice(req.price + stop_distance * strategy_rr_target);
      return (req.sl > 0.0 && req.tp > req.price && req.sl < req.price);
     }

   req.sl = Strategy_NormalizePrice(req.price + stop_distance);
   req.tp = Strategy_NormalizePrice(req.price - stop_distance * strategy_rr_target);
   return (req.sl > req.price && req.tp > 0.0 && req.tp < req.price);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No card-specific time or spread filter. Framework handles news, Friday
   // close, kill-switch, and broker guard rails before this hook.
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

   if(strategy_lookback_bars < 2 ||
      strategy_atr_period < 1 ||
      strategy_outlier_mult <= 0.0 ||
      strategy_rr_target <= 0.0 ||
      strategy_atr_fallback_mult <= 0.0 ||
      strategy_stale_bars < 1 ||
      strategy_max_range_atr <= 0.0 ||
      strategy_min_stop_atr <= 0.0 ||
      strategy_max_stop_atr < strategy_min_stop_atr)
      return false;

   if(Strategy_HasOurPosition())
     {
      Strategy_CancelOurPendingStops("tv_vol_exp_position_open");
      return false;
     }

   double box_high = 0.0;
   double box_low = 0.0;
   if(!Strategy_Box(strategy_lookback_bars, box_high, box_low))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double box_range = box_high - box_low;
   if(box_range <= 0.0)
      return false;

   if(box_range > atr * strategy_max_range_atr)
     {
      Strategy_CancelOurPendingStops("tv_vol_exp_box_range_expanded");
      return false;
     }

   Strategy_CancelStaleStops();

   const bool has_buy_stop = Strategy_HasPendingStop(ORDER_TYPE_BUY_STOP);
   const bool has_sell_stop = Strategy_HasPendingStop(ORDER_TYPE_SELL_STOP);
   if(has_buy_stop && has_sell_stop)
      return false;

   const double zone_mid = (box_high + box_low) * 0.5;
   const double buy_stop = box_high + strategy_outlier_mult * atr;
   const double sell_stop = box_low - strategy_outlier_mult * atr;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   if(!Strategy_BuildStopRequest(QM_BUY_STOP, buy_stop, zone_mid, atr, buy_req))
      return false;
   if(!Strategy_BuildStopRequest(QM_SELL_STOP, sell_stop, zone_mid, atr, sell_req))
      return false;

   if(!has_buy_stop && !has_sell_stop)
     {
      ulong buy_ticket = 0;
      QM_TM_OpenPosition(buy_req, buy_ticket);
      req = sell_req;
      return true;
     }

   if(!has_buy_stop)
     {
      req = buy_req;
      return true;
     }

   if(!has_sell_stop)
     {
      req = sell_req;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurPosition())
      Strategy_CancelOurPendingStops("tv_vol_exp_cancel_opposite_after_fill");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
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

      // perf-allowed: O(1) closed-bar read for the card's midline close rule.
      const double close_last = iClose(_Symbol, _Period, 1);
      const double stop_level = PositionGetDouble(POSITION_SL);
      if(close_last <= 0.0 || stop_level <= 0.0)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && close_last < stop_level)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close_last > stop_level)
         return true;
     }
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
