#property strict
#property version   "5.0"
#property description "QM5_10474 MQL5 TDSGlobal Pending Limit Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
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
input int    qm_ea_id                   = 10474;
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
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_work_timeframe = PERIOD_H1;
input int    strategy_macd_fast              = 12;
input int    strategy_macd_slow              = 26;
input int    strategy_macd_signal            = 9;
input int    strategy_force_period           = 24;
input int    strategy_entry_offset_points    = 1;
input int    strategy_min_pending_points     = 16;
input int    strategy_pending_expiry_bars    = 24;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input double strategy_reward_risk            = 2.0;

int Strategy_ForceHandle(const string sym,
                         const ENUM_TIMEFRAMES tf,
                         const int period)
  {
   const string key = StringFormat("FORCE|%s|%d|%d|%d|%d",
                                   sym,
                                   (int)tf,
                                   period,
                                   (int)MODE_EMA,
                                   (int)VOLUME_TICK);
   int handle = QM_IndicatorsLookup(key);
   if(handle != INVALID_HANDLE)
      return handle;

   handle = iForce(sym, tf, period, MODE_EMA, VOLUME_TICK);
   return QM_IndicatorsRegister(key, handle);
  }

double Strategy_Force(const string sym,
                      const ENUM_TIMEFRAMES tf,
                      const int period,
                      const int shift)
  {
   return QM_IndicatorReadBuffer(Strategy_ForceHandle(sym, tf, period), 0, shift);
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_IsPendingLimitType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT);
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_HasPendingLimitType(const ENUM_ORDER_TYPE wanted_type)
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
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == wanted_type)
         return true;
     }
   return false;
  }

void Strategy_RemovePendingLimits(const ENUM_ORDER_TYPE remove_type,
                                  const string reason,
                                  const bool remove_all_limit_types = false)
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

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!Strategy_IsPendingLimitType(order_type))
         continue;
      if(remove_all_limit_types || order_type == remove_type)
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_ExpirePendingLimits()
  {
   if(strategy_pending_expiry_bars <= 0)
      return;

   const int seconds_per_bar = PeriodSeconds(strategy_work_timeframe);
   if(seconds_per_bar <= 0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const datetime now = TimeCurrent();
   const int expiry_seconds = strategy_pending_expiry_bars * seconds_per_bar;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingLimitType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= expiry_seconds)
         QM_TM_RemovePendingOrder(ticket, "TDSGLOBAL_PENDING_EXPIRED");
     }
  }

int Strategy_SignalDirection()
  {
   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_force_period <= 0)
      return 0;

   const double macd_1 = QM_MACD_Main(_Symbol, strategy_work_timeframe,
                                      strategy_macd_fast,
                                      strategy_macd_slow,
                                      strategy_macd_signal,
                                      1,
                                      PRICE_CLOSE);
   const double macd_2 = QM_MACD_Main(_Symbol, strategy_work_timeframe,
                                      strategy_macd_fast,
                                      strategy_macd_slow,
                                      strategy_macd_signal,
                                      2,
                                      PRICE_CLOSE);
   const double sig_1 = QM_MACD_Signal(_Symbol, strategy_work_timeframe,
                                       strategy_macd_fast,
                                       strategy_macd_slow,
                                       strategy_macd_signal,
                                       1,
                                       PRICE_CLOSE);
   const double sig_2 = QM_MACD_Signal(_Symbol, strategy_work_timeframe,
                                       strategy_macd_fast,
                                       strategy_macd_slow,
                                       strategy_macd_signal,
                                       2,
                                       PRICE_CLOSE);
   const double osma_1 = macd_1 - sig_1;
   const double osma_2 = macd_2 - sig_2;
   const double force_1 = Strategy_Force(_Symbol, strategy_work_timeframe, strategy_force_period, 1);

   if(macd_1 == 0.0 || macd_2 == 0.0 || force_1 == 0.0)
      return 0;

   const int macd_dir = (macd_1 > macd_2) ? 1 : ((macd_1 < macd_2) ? -1 : 0);
   const int osma_dir = (osma_1 > osma_2) ? 1 : ((osma_1 < osma_2) ? -1 : 0);

   if(macd_dir >= 0 && osma_dir == 1 && force_1 < 0.0)
      return -1;
   if(macd_dir <= 0 && osma_dir == -1 && force_1 > 0.0)
      return 1;

   return 0;
  }

bool Strategy_ValidatePending(const QM_OrderType type,
                              const double entry,
                              const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   if(type == QM_BUY_LIMIT && entry >= ask - point)
      return false;
   if(type == QM_SELL_LIMIT && entry <= bid + point)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int min_points = (stops_level > freeze_level) ? stops_level : freeze_level;
   if(min_points < 1)
      min_points = 1;
   const double sl_points = MathAbs(entry - sl) / point;
   const double entry_points = (type == QM_BUY_LIMIT) ? ((ask - entry) / point)
                                                      : ((entry - bid) / point);
   return (sl_points > min_points && entry_points > min_points);
  }

bool Strategy_BuildLimitRequest(const int direction, QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(direction == 0 || strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_reward_risk <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_work_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double offset = MathMax(1, strategy_entry_offset_points) * point;
   const double min_dist = MathMax(1, strategy_min_pending_points) * point;
   const int expiry_seconds = strategy_pending_expiry_bars * PeriodSeconds(strategy_work_timeframe);

   if(direction < 0)
     {
      const double high_1 = iHigh(_Symbol, strategy_work_timeframe, 1); // perf-allowed: one closed-bar structural price
      double entry = high_1 + offset;
      if(entry <= bid + min_dist)
         entry = bid + min_dist;

      req.type = QM_SELL_LIMIT;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(req.price + atr * strategy_atr_sl_mult, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_reward_risk);
      req.reason = "QM5_10474_TDSGLOBAL_SELL_LIMIT";
      req.expiration_seconds = (expiry_seconds > 0) ? expiry_seconds : 0;
      return (req.tp > 0.0 && req.tp < req.price &&
              Strategy_ValidatePending(req.type, req.price, req.sl));
     }

   const double low_1 = iLow(_Symbol, strategy_work_timeframe, 1); // perf-allowed: one closed-bar structural price
   double entry = low_1 - offset;
   if(entry >= ask - min_dist)
      entry = ask - min_dist;

   req.type = QM_BUY_LIMIT;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = NormalizeDouble(req.price - atr * strategy_atr_sl_mult, _Digits);
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_reward_risk);
   req.reason = "QM5_10474_TDSGLOBAL_BUY_LIMIT";
   req.expiration_seconds = (expiry_seconds > 0) ? expiry_seconds : 0;
   return (req.tp > req.price &&
           Strategy_ValidatePending(req.type, req.price, req.sl));
  }

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   ENUM_POSITION_TYPE ignored_type;
   if(Strategy_HasOpenPosition(ignored_type))
      return false;

   const int direction = Strategy_SignalDirection();
   if(direction == 0)
      return false;

   if(direction > 0)
     {
      Strategy_RemovePendingLimits(ORDER_TYPE_SELL_LIMIT, "TDSGLOBAL_OPPOSITE_BUY_SIGNAL");
      if(Strategy_HasPendingLimitType(ORDER_TYPE_BUY_LIMIT))
         return false;
     }
   else
     {
      Strategy_RemovePendingLimits(ORDER_TYPE_BUY_LIMIT, "TDSGLOBAL_OPPOSITE_SELL_SIGNAL");
      if(Strategy_HasPendingLimitType(ORDER_TYPE_SELL_LIMIT))
         return false;
     }

   return Strategy_BuildLimitRequest(direction, req);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   Strategy_ExpirePendingLimits();
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   if(!QM_IsNewBar(_Symbol, strategy_work_timeframe))
      return false;

   const int direction = Strategy_SignalDirection();
   if(position_type == POSITION_TYPE_BUY && direction < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && direction > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
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
