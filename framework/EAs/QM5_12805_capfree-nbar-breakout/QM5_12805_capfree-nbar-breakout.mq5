#property strict
#property version   "5.0"
#property description "QM5_12805 CapFree N-bar High-Low Breakout"

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
input int    qm_ea_id                   = 12805;
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
input int    strategy_bars_n                    = 100;
input int    strategy_expiration_bars           = 300;
input int    strategy_session_start_hour        = 6;
input int    strategy_session_end_hour          = 21;
input bool   strategy_close_at_session_end      = true;
input double strategy_max_spread_points         = 0.0;
input bool   strategy_percent_profile           = true;
input double strategy_order_distance_pct_of_sl  = 50.0;
input double strategy_sl_pct                    = 0.4;
input double strategy_tp_pct                    = 0.4;
input int    strategy_fixed_order_distance_pips = 10;
input int    strategy_fixed_sl_pips             = 20;
input int    strategy_fixed_tp_pips             = 20;
input bool   strategy_rsi_filter_enabled        = true;
input int    strategy_rsi_period                = 14;
input double strategy_rsi_lower                 = 20.0;
input double strategy_rsi_upper                 = 80.0;
input bool   strategy_ma_filter_enabled         = false;
input int    strategy_ma_period                 = 200;
input double strategy_ma_max_distance_pct       = 3.0;
input int    strategy_trail_type                = 0;     // 0=fixed/percent, 1=previous candle, 2=fast EMA
input int    strategy_fixed_trail_trigger_pips  = 2;
input int    strategy_fixed_trail_distance_pips = 1;
input double strategy_trail_trigger_pct_of_sl   = 10.0;
input double strategy_trail_distance_pct_of_sl  = 5.0;
input int    strategy_trail_prev_candles        = 1;
input int    strategy_trail_fast_ema_period     = 5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

void Strategy_CopyRequest(const QM_EntryRequest &src, QM_EntryRequest &dst)
  {
   dst.type = src.type;
   dst.price = src.price;
   dst.sl = src.sl;
   dst.tp = src.tp;
   dst.reason = src.reason;
   dst.symbol_slot = src.symbol_slot;
   dst.expiration_seconds = src.expiration_seconds;
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_RemovePendingOrders(const string reason)
  {
   bool all_ok = true;
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
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return all_ok;
  }

bool Strategy_InSession(const datetime broker_time)
  {
   MqlDateTime t;
   TimeToStruct(broker_time, t);
   if(t.day_of_week == 0 || t.day_of_week == 6)
      return false;

   const int start_h = strategy_session_start_hour;
   const int end_h = strategy_session_end_hour;
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (t.hour >= start_h && t.hour < end_h);
   return (t.hour >= start_h || t.hour < end_h);
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(ask < bid)
      return false;
   if(ask > bid && ((ask - bid) / point) > strategy_max_spread_points)
      return false;
   return true;
  }

double Strategy_OrderDistance(const double reference_price)
  {
   if(strategy_percent_profile)
     {
      if(reference_price <= 0.0 || strategy_sl_pct <= 0.0 || strategy_order_distance_pct_of_sl <= 0.0)
         return 0.0;
      return reference_price * (strategy_sl_pct / 100.0) * (strategy_order_distance_pct_of_sl / 100.0);
     }

   return QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fixed_order_distance_pips);
  }

double Strategy_TrailTriggerDistance(const double entry_price)
  {
   if(strategy_percent_profile)
     {
      if(entry_price <= 0.0 || strategy_sl_pct <= 0.0 || strategy_trail_trigger_pct_of_sl <= 0.0)
         return 0.0;
      return entry_price * (strategy_sl_pct / 100.0) * (strategy_trail_trigger_pct_of_sl / 100.0);
     }

   return QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fixed_trail_trigger_pips);
  }

double Strategy_TrailDistance(const double entry_price)
  {
   if(strategy_percent_profile)
     {
      if(entry_price <= 0.0 || strategy_sl_pct <= 0.0 || strategy_trail_distance_pct_of_sl <= 0.0)
         return 0.0;
      return entry_price * (strategy_sl_pct / 100.0) * (strategy_trail_distance_pct_of_sl / 100.0);
     }

   return QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fixed_trail_distance_pips);
  }

bool Strategy_EntryFiltersAllow(bool &allow_buy, bool &allow_sell)
  {
   allow_buy = true;
   allow_sell = true;

   if(!Strategy_InSession(TimeCurrent()))
      return false;
   if(!Strategy_SpreadAllowed())
      return false;

   if(strategy_rsi_filter_enabled)
     {
      const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1, PRICE_TYPICAL);
      if(rsi <= 0.0 || rsi < strategy_rsi_lower || rsi > strategy_rsi_upper)
         return false;
     }

   if(strategy_ma_filter_enabled)
     {
      const double h4_close = QM_SMA(_Symbol, PERIOD_H4, 1, 1, PRICE_CLOSE);
      const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_ma_period, 1, PRICE_TYPICAL);
      if(h4_close <= 0.0 || h4_ema <= 0.0)
         return false;

      const double distance_pct = MathAbs((h4_close - h4_ema) / h4_ema) * 100.0;
      if(distance_pct > strategy_ma_max_distance_pct)
         return false;

      allow_buy = (h4_close > h4_ema);
      allow_sell = (h4_close < h4_ema);
      if(!allow_buy && !allow_sell)
         return false;
     }

   return true;
  }

bool Strategy_BuildPendingRequest(const QM_OrderType order_type,
                                  const double raw_entry,
                                  const string reason,
                                  QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   if(raw_entry <= 0.0)
      return false;

   const double entry_price = QM_StopRulesNormalizePrice(_Symbol, raw_entry);
   if(entry_price <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(strategy_percent_profile)
     {
      const double sl_distance = entry_price * (strategy_sl_pct / 100.0);
      const double tp_distance = entry_price * (strategy_tp_pct / 100.0);
      sl = QM_StopRulesStopFromDistance(_Symbol, order_type, entry_price, sl_distance);
      tp = QM_StopRulesTakeFromDistance(_Symbol, order_type, entry_price, tp_distance);
     }
   else
     {
      sl = QM_StopFixedPips(_Symbol, order_type, entry_price, strategy_fixed_sl_pips);
      tp = QM_TakeFixedPips(_Symbol, order_type, entry_price, strategy_fixed_tp_pips);
     }

   if(sl <= 0.0 || tp <= 0.0)
      return false;

   int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds_per_bar <= 0)
      seconds_per_bar = 300;

   req.type = order_type;
   req.price = entry_price;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_expiration_bars * seconds_per_bar;
   return true;
  }

void Strategy_ApplyTrailing(const ulong ticket)
  {
   if(strategy_trail_type < 0 || !PositionSelectByTicket(ticket))
      return;

   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open_price <= 0.0 || market_price <= 0.0 || point <= 0.0)
      return;

   const double trigger_distance = Strategy_TrailTriggerDistance(open_price);
   if(trigger_distance <= 0.0)
      return;

   const double profit_distance = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(profit_distance < trigger_distance)
      return;

   double target_sl = 0.0;
   if(strategy_trail_type == 1)
     {
      double lowest = 0.0;
      double highest = 0.0;
      if(!QM_StopRulesReadStructureExtremes(_Symbol, strategy_trail_prev_candles, lowest, highest))
         return;
      target_sl = is_buy ? lowest : highest;
     }
   else if(strategy_trail_type == 2)
     {
      target_sl = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_trail_fast_ema_period, 1, PRICE_CLOSE);
     }
   else
     {
      const double trail_distance = Strategy_TrailDistance(open_price);
      if(trail_distance <= 0.0)
         return;
      target_sl = is_buy ? (market_price - trail_distance) : (market_price + trail_distance);
     }

   target_sl = QM_StopRulesNormalizePrice(_Symbol, target_sl);
   if(target_sl <= 0.0)
      return;
   if(is_buy && target_sl >= market_price)
      return;
   if(!is_buy && target_sl <= market_price)
      return;

   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(!improves)
      return;

   QM_TM_MoveSL(ticket, target_sl, "capfree_trailing");
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const bool has_position = Strategy_HasOpenPosition();
   if(!Strategy_InSession(TimeCurrent()))
     {
      Strategy_RemovePendingOrders("session_closed");
      return !has_position;
     }

   if(!Strategy_SpreadAllowed())
     {
      Strategy_RemovePendingOrders("spread_filter");
      return !has_position;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(Strategy_HasOpenPosition())
     {
      Strategy_RemovePendingOrders("open_position_present");
      return false;
     }

   Strategy_RemovePendingOrders("refresh_breakout_levels");

   if(strategy_bars_n < 1 || strategy_expiration_bars < 1)
      return false;

   bool allow_buy = true;
   bool allow_sell = true;
   if(!Strategy_EntryFiltersAllow(allow_buy, allow_sell))
      return false;

   double lowest = 0.0;
   double highest = 0.0;
   if(!QM_StopRulesReadStructureExtremes(_Symbol, strategy_bars_n, lowest, highest))
      return false;
   if(lowest <= 0.0 || highest <= 0.0 || highest <= lowest)
      return false;

   const double buy_distance = Strategy_OrderDistance(highest);
   const double sell_distance = Strategy_OrderDistance(lowest);
   if(buy_distance <= 0.0 || sell_distance <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   const bool buy_ready = allow_buy &&
                          Strategy_BuildPendingRequest(QM_BUY_STOP,
                                                       highest + buy_distance,
                                                       "CAPFREE_BUY_STOP_NBAR",
                                                       buy_req);
   const bool sell_ready = allow_sell &&
                           Strategy_BuildPendingRequest(QM_SELL_STOP,
                                                        lowest - sell_distance,
                                                        "CAPFREE_SELL_STOP_NBAR",
                                                        sell_req);

   if(buy_ready && sell_ready)
     {
      ulong buy_ticket = 0;
      QM_TM_OpenPosition(buy_req, buy_ticket);
      Strategy_CopyRequest(sell_req, req);
      return true;
     }

   if(buy_ready)
     {
      Strategy_CopyRequest(buy_req, req);
      return true;
     }

   if(sell_ready)
     {
      Strategy_CopyRequest(sell_req, req);
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   bool has_position = false;
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

      has_position = true;
      Strategy_ApplyTrailing(ticket);
     }

   if(has_position)
      Strategy_RemovePendingOrders("position_open_cancel_oco");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_close_at_session_end && Strategy_HasOpenPosition() && !Strategy_InSession(TimeCurrent()))
      return true;
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance);
   else if(qm_news_mode_legacy != QM_NEWS_OFF)
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);

   if(!news_allows)
     {
      Strategy_RemovePendingOrders("news_filter_block");
      return true;
     }

   return false; // defer to framework pass-through when news allows trading
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
