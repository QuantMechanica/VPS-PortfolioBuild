#property strict
#property version   "5.0"
#property description "QM5_10184 TradingView ATR ZigZag Breakout"

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
input int    qm_ea_id                   = 10184;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_H1;
input int    strategy_atr_period        = 14;
input double strategy_pivot_atr_mult    = 2.0;
input double strategy_sl_atr_mult       = 1.5;
input double strategy_rr_mult           = 1.5;
input double strategy_max_spread_stop_fraction = 0.15;
input int    strategy_rollover_start_hhmm_utc  = 2155;
input int    strategy_rollover_end_hhmm_utc    = 2210;

CTrade g_strategy_trade;
bool   g_zz_initialized       = false;
int    g_zz_trend             = 0;
double g_zz_candidate_high    = 0.0;
double g_zz_candidate_low     = 0.0;
double g_zz_latest_swing_high = 0.0;
double g_zz_latest_swing_low  = 0.0;
double g_zz_used_long_pivot   = 0.0;
double g_zz_used_short_pivot  = 0.0;

int Strategy_HhmmUtc()
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_InUtcWindow(const int now_hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm == end_hhmm)
      return false;
   if(start_hhmm < end_hhmm)
      return (now_hhmm >= start_hhmm && now_hhmm <= end_hhmm);
   return (now_hhmm >= start_hhmm || now_hhmm <= end_hhmm);
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_HasPendingOrder()
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
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

void Strategy_CancelPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   g_strategy_trade.SetExpertMagicNumber(magic);
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         g_strategy_trade.OrderDelete(ticket);
     }
  }

bool Strategy_LevelMatches(const double a, const double b)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   return MathAbs(a - b) <= point * 0.5;
  }

int Strategy_AdvanceZigZag(const double atr_value, double &arm_level)
  {
   arm_level = 0.0;
   const double high_1 = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low_1 = iLow(_Symbol, strategy_signal_tf, 1);
   if(high_1 <= 0.0 || low_1 <= 0.0 || high_1 < low_1 || atr_value <= 0.0)
      return 0;

   const double threshold = atr_value * strategy_pivot_atr_mult;
   if(threshold <= 0.0)
      return 0;

   if(!g_zz_initialized)
     {
      g_zz_candidate_high = high_1;
      g_zz_candidate_low = low_1;
      g_zz_initialized = true;
      return 0;
     }

   if(g_zz_trend >= 0)
     {
      if(high_1 > g_zz_candidate_high)
         g_zz_candidate_high = high_1;
      if(low_1 <= g_zz_candidate_high - threshold)
        {
         g_zz_latest_swing_high = g_zz_candidate_high;
         g_zz_candidate_low = low_1;
         g_zz_trend = -1;
         arm_level = g_zz_latest_swing_high;
         return 1;
        }
     }

   if(g_zz_trend <= 0)
     {
      if(low_1 < g_zz_candidate_low || g_zz_candidate_low <= 0.0)
         g_zz_candidate_low = low_1;
      if(high_1 >= g_zz_candidate_low + threshold)
        {
         g_zz_latest_swing_low = g_zz_candidate_low;
         g_zz_candidate_high = high_1;
         g_zz_trend = 1;
         arm_level = g_zz_latest_swing_low;
         return -1;
        }
     }

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_signal_tf != PERIOD_H1 && strategy_signal_tf != PERIOD_M15)
      return true;
   if(strategy_atr_period <= 0 || strategy_pivot_atr_mult <= 0.0 ||
      strategy_sl_atr_mult <= 0.0 || strategy_rr_mult <= 0.0)
      return true;
   if(strategy_max_spread_stop_fraction <= 0.0 || strategy_max_spread_stop_fraction > 1.0)
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
   req.reason = "QM5_10184_ATR_ZIGZAG_BREAK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Bars(_Symbol, strategy_signal_tf) < strategy_atr_period + 5)
      return false;

   if(Strategy_InUtcWindow(Strategy_HhmmUtc(),
                           strategy_rollover_start_hhmm_utc,
                           strategy_rollover_end_hhmm_utc))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double stop_distance = atr * strategy_sl_atr_mult;
   if(point <= 0.0 || stop_distance <= 0.0)
      return false;
   if((double)spread_points * point > stop_distance * strategy_max_spread_stop_fraction)
      return false;

   double arm_level = 0.0;
   const int arm_direction = Strategy_AdvanceZigZag(atr, arm_level);
   if(arm_direction == 0 || arm_level <= 0.0)
      return false;

   Strategy_CancelPendingOrders();

   if(Strategy_HasOpenPosition())
      return false;

   if(arm_direction > 0)
     {
      if(Strategy_LevelMatches(arm_level, g_zz_used_long_pivot))
         return false;
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0 || arm_level <= ask)
         return false;
      req.type = QM_BUY_STOP;
      req.price = arm_level;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr_mult);
      req.reason = "QM5_10184_LONG_PIVOT_BREAK";
      g_zz_used_long_pivot = arm_level;
     }
   else
     {
      if(Strategy_LevelMatches(arm_level, g_zz_used_short_pivot))
         return false;
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || arm_level >= bid)
         return false;
      req.type = QM_SELL_STOP;
      req.price = arm_level;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr_mult);
      req.reason = "QM5_10184_SHORT_PIVOT_BREAK";
      g_zz_used_short_pivot = arm_level;
     }

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY_STOP && (req.sl >= req.price || req.tp <= req.price))
      return false;
   if(req.type == QM_SELL_STOP && (req.sl <= req.price || req.tp >= req.price))
      return false;

   if(Strategy_HasPendingOrder())
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies bracket exits only; no break-even, trailing, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(position_type == POSITION_TYPE_BUY && g_zz_latest_swing_low > 0.0 && bid <= g_zz_latest_swing_low)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_zz_latest_swing_high > 0.0 && ask >= g_zz_latest_swing_high)
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
