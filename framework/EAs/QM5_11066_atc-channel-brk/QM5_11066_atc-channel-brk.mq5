#property strict
#property version   "5.0"
#property description "QM5_11066 ATC 2010 Horizontal Channel Breakout"

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
input int    qm_ea_id                   = 11066;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_M5;
input int    strategy_channel_bars             = 48;
input double strategy_depth_min                = 0.35;
input double strategy_depth_max                = 0.65;
input int    strategy_entry_buffer_points      = 5;
input double strategy_stop_channel_mult        = 0.50;
input double strategy_take_profit_rr           = 1.50;
input int    strategy_order_expiry_bars        = 12;
input int    strategy_atr_period               = 14;
input double strategy_min_channel_atr_mult     = 0.80;
input int    strategy_max_spread_points        = 30;
input bool   strategy_session_filter_enabled   = true;
input int    strategy_session_start_hour       = 7;
input int    strategy_session_end_hour         = 21;
input bool   strategy_trailing_enabled         = true;
input double strategy_trail_start_r            = 1.00;
input double strategy_trail_distance_r         = 0.50;

bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_CurrentSpreadPoints(double &spread_points)
  {
   spread_points = 0.0;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || point <= 0.0)
      return false;

   spread_points = (ask - bid) / point;
   return true;
  }

bool Strategy_SessionAllowsEntry()
  {
   if(!strategy_session_filter_enabled)
      return true;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);

   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour));
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (now_dt.hour >= start_h && now_dt.hour < end_h);
   return (now_dt.hour >= start_h || now_dt.hour < end_h);
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
      if(Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

bool Strategy_HasOurExposure()
  {
   return (Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0);
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
      if(!Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_DeleteExpiredPendingStops()
  {
   const int max_age_seconds = MathMax(1, strategy_order_expiry_bars) *
                               MathMax(60, PeriodSeconds(strategy_timeframe));
   const datetime now = TimeCurrent();
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

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= max_age_seconds)
         QM_TM_RemovePendingOrder(ticket, "channel_breakout_order_expiry");
     }
  }

bool Strategy_ChannelExtremes(const int bars, double &channel_high, double &channel_low)
  {
   channel_high = -DBL_MAX;
   channel_low = DBL_MAX;

   if(bars <= 1)
      return false;

   for(int shift = 1; shift <= bars; ++shift)
     {
      const double high = iHigh(_Symbol, strategy_timeframe, shift); // perf-allowed: bounded closed-bar channel structure
      const double low = iLow(_Symbol, strategy_timeframe, shift);   // perf-allowed: bounded closed-bar channel structure
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      channel_high = MathMax(channel_high, high);
      channel_low = MathMin(channel_low, low);
     }

   return (channel_high > 0.0 && channel_low > 0.0 && channel_high > channel_low);
  }

double Strategy_MinStopDistancePrice()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0 || stops_level <= 0)
      return 0.0;
   return stops_level * point;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_order_expiry_bars) *
                            MathMax(60, PeriodSeconds(strategy_timeframe));
  }

bool Strategy_BuildStopRequest(const QM_OrderType side,
                               const double entry_price,
                               const double stop_distance,
                               QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   req.type = side;
   req.price = QM_TM_NormalizePrice(_Symbol, entry_price);
   if(req.price <= 0.0 || stop_distance <= 0.0)
      return false;

   req.sl = QM_TM_NormalizePrice(_Symbol,
            QM_OrderTypeIsBuy(side) ? req.price - stop_distance : req.price + stop_distance);
   req.tp = QM_TakeRR(_Symbol, side, req.price, req.sl, strategy_take_profit_rr);
   req.reason = QM_OrderTypeIsBuy(side) ? "ATC_CHANNEL_BREAKOUT_BUY_STOP"
                                        : "ATC_CHANNEL_BREAKOUT_SELL_STOP";

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(side))
      return (req.sl < req.price && req.tp > req.price);
   return (req.sl > req.price && req.tp < req.price);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: time, spread, news. Existing exposure remains manageable.
   if(Strategy_HasOurExposure())
      return false;

   if(_Period != strategy_timeframe)
      return true;

   double spread_points = 0.0;
   if(!Strategy_CurrentSpreadPoints(spread_points))
      return true;
   if(strategy_max_spread_points > 0 && spread_points > (double)strategy_max_spread_points)
      return true;

   if(!Strategy_SessionAllowsEntry())
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   Strategy_DeleteExpiredPendingStops();

   if(_Period != strategy_timeframe)
      return false;
   if(strategy_channel_bars <= 1 || strategy_stop_channel_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0 || strategy_atr_period <= 0)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;

   double spread_points = 0.0;
   if(!Strategy_CurrentSpreadPoints(spread_points))
      return false;
   if(strategy_max_spread_points > 0 && spread_points > (double)strategy_max_spread_points)
      return false;
   if(!Strategy_SessionAllowsEntry())
      return false;

   double channel_high = 0.0;
   double channel_low = 0.0;
   if(!Strategy_ChannelExtremes(strategy_channel_bars, channel_high, channel_low))
      return false;

   const double channel_width = channel_high - channel_low;
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0 || channel_width < strategy_min_channel_atr_mult * atr)
      return false;

   const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: closed-bar channel-depth read
   if(close1 <= 0.0)
      return false;

   const double depth = (close1 - channel_low) / channel_width;
   const double depth_min = MathMin(strategy_depth_min, strategy_depth_max);
   const double depth_max = MathMax(strategy_depth_min, strategy_depth_max);
   if(depth < depth_min || depth > depth_max)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double buffer = MathMax(0, strategy_entry_buffer_points) * point;
   const double min_stop_distance = Strategy_MinStopDistancePrice();
   const double stop_distance = MathMax(strategy_stop_channel_mult * channel_width, min_stop_distance);
   if(stop_distance <= 0.0)
      return false;

   const double buy_entry = channel_high + buffer;
   const double sell_entry = channel_low - buffer;
   if(buy_entry <= ask + min_stop_distance || sell_entry >= bid - min_stop_distance)
      return false;

   QM_EntryRequest buy_req;
   if(!Strategy_BuildStopRequest(QM_BUY_STOP, buy_entry, stop_distance, buy_req))
      return false;
   if(!Strategy_BuildStopRequest(QM_SELL_STOP, sell_entry, stop_distance, req))
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: expire stale orders, cancel the opposite order after fill, trail after +1R.
   Strategy_DeleteExpiredPendingStops();
   if(!Strategy_HasOurOpenPosition())
      return;

   Strategy_DeleteOurPendingStops("opposite_pending_cancel_after_fill");
   if(!strategy_trailing_enabled || strategy_trail_start_r <= 0.0 || strategy_trail_distance_r <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double initial_risk = MathAbs(open_price - current_sl);
      const double favorable_move = is_buy ? market - open_price : open_price - market;
      if(market <= 0.0 || initial_risk <= 0.0 ||
         favorable_move < strategy_trail_start_r * initial_risk)
         continue;

      const double trail_distance = strategy_trail_distance_r * initial_risk;
      const double raw_sl = is_buy ? market - trail_distance : market + trail_distance;
      const double new_sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
      if(new_sl <= 0.0)
         continue;

      const bool improves = is_buy ? (new_sl > current_sl + point * 0.5 && new_sl < market)
                                   : (new_sl < current_sl - point * 0.5 && new_sl > market);
      if(improves)
         QM_TM_MoveSL(ticket, new_sl, "atc_channel_breakout_trail_after_1r");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: broker SL/TP, trailing stop, Friday close, and news exits are framework-managed.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no custom override beyond the framework two-axis news gate.
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
