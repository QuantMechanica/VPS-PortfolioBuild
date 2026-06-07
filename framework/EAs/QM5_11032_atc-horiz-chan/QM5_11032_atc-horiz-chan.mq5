#property strict
#property version   "5.0"
#property description "QM5_11032 M5 horizontal channel breakout pending stops"

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
input int    qm_ea_id                   = 11032;
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
input int    strategy_channel_period_m5    = 48;
input double strategy_inside_depth_pct     = 0.20;
input int    strategy_atr_period           = 14;
input double strategy_entry_buffer_atr     = 0.10;
input double strategy_channel_sl_mult      = 0.75;
input double strategy_atr_sl_mult          = 1.50;
input double strategy_tp_r_multiple        = 3.00;
input bool   strategy_tp_enabled           = true;
input double strategy_trail_start_r        = 1.50;
input int    strategy_pending_expiry_bars  = 3;
input double strategy_width_min_atr_factor = 0.50;
input double strategy_width_max_atr_factor = 2.50;
input double strategy_median_spread_points = 25.0;
input double strategy_spread_mult          = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_median_spread_points > 0.0 && strategy_spread_mult > 0.0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)spread_points > strategy_median_spread_points * strategy_spread_mult)
         return true;
     }

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

   if(strategy_channel_period_m5 < 2 ||
      strategy_atr_period < 1 ||
      strategy_inside_depth_pct < 0.0 ||
      strategy_inside_depth_pct >= 0.5 ||
      strategy_entry_buffer_atr < 0.0 ||
      strategy_channel_sl_mult <= 0.0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_trail_start_r <= 0.0 ||
      strategy_pending_expiry_bars < 1)
      return false;

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
         return false;
     }

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
         return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, strategy_channel_period_m5, rates); // perf-allowed: closed-bar channel scan, EntrySignal is framework-gated by QM_IsNewBar().
   if(copied < strategy_channel_period_m5)
      return false;

   double channel_high = -DBL_MAX;
   double channel_low = DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      channel_high = MathMax(channel_high, rates[i].high);
      channel_low = MathMin(channel_low, rates[i].low);
     }

   if(channel_high <= 0.0 || channel_low <= 0.0 || channel_high <= channel_low)
      return false;

   const double close_last = rates[0].close;
   const double channel_width = channel_high - channel_low;
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(close_last <= 0.0 || channel_width <= 0.0 || atr <= 0.0)
      return false;

   const double depth = strategy_inside_depth_pct * channel_width;
   if(close_last < channel_low + depth || close_last > channel_high - depth)
      return false;

   const double width_scale = atr * ((double)strategy_channel_period_m5 / 14.0);
   if(width_scale <= 0.0)
      return false;
   if(channel_width < strategy_width_min_atr_factor * width_scale ||
      channel_width > strategy_width_max_atr_factor * width_scale)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double buffer = MathMax(strategy_entry_buffer_atr * atr, point);
   const double sl_dist = MathMax(strategy_channel_sl_mult * channel_width,
                                  strategy_atr_sl_mult * atr);
   if(sl_dist <= point)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_distance = MathMax((double)stops_level * point, point);
   const double buy_price = NormalizeDouble(channel_high + buffer, _Digits);
   const double sell_price = NormalizeDouble(channel_low - buffer, _Digits);
   if(buy_price <= ask + min_stop_distance || sell_price >= bid - min_stop_distance)
      return false;

   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_price;
   buy_req.sl = NormalizeDouble(buy_price - sl_dist, _Digits);
   buy_req.tp = strategy_tp_enabled ? NormalizeDouble(buy_price + strategy_tp_r_multiple * sl_dist, _Digits) : 0.0;
   buy_req.reason = "ATC_HORIZ_CHAN_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = PeriodSeconds(PERIOD_M5) * strategy_pending_expiry_bars;

   QM_EntryRequest sell_req;
   sell_req.type = QM_SELL_STOP;
   sell_req.price = sell_price;
   sell_req.sl = NormalizeDouble(sell_price + sl_dist, _Digits);
   sell_req.tp = strategy_tp_enabled ? NormalizeDouble(sell_price - strategy_tp_r_multiple * sl_dist, _Digits) : 0.0;
   sell_req.reason = "ATC_HORIZ_CHAN_SELL_STOP";
   sell_req.symbol_slot = qm_magic_slot_offset;
   sell_req.expiration_seconds = PeriodSeconds(PERIOD_M5) * strategy_pending_expiry_bars;

   ulong buy_ticket = 0;
   ulong sell_ticket = 0;
   const bool buy_ok = QM_TM_OpenPosition(buy_req, buy_ticket);
   const bool sell_ok = QM_TM_OpenPosition(sell_req, sell_ticket);
   if(!buy_ok && sell_ok)
      QM_TM_RemovePendingOrder(sell_ticket, "paired_buy_stop_failed");
   if(buy_ok && !sell_ok)
      QM_TM_RemovePendingOrder(buy_ticket, "paired_sell_stop_failed");

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool has_position = false;
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
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || point <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double initial_risk = MathAbs(open_price - current_sl);
      const double open_profit = is_buy ? (market_price - open_price)
                                        : (open_price - market_price);
      if(market_price <= 0.0 || initial_risk <= point ||
         open_profit < strategy_trail_start_r * initial_risk)
         continue;

      const double raw_sl = is_buy ? (market_price - initial_risk)
                                   : (market_price + initial_risk);
      const double target_sl = NormalizeDouble(raw_sl, _Digits);
      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "atc_channel_classical_trail");
     }

   if(!has_position)
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
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "opposite_pending_after_fill");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits are SL, TP, trailing stop, and framework Friday close.
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
