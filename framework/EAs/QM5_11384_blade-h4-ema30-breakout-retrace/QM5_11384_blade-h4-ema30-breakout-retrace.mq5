#property strict
#property version   "5.0"
#property description "QM5_11384 Blade H4 EMA30 breakout retrace"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11384 blade-h4-ema30-breakout-retrace
// Source card: artifacts/cards_approved/QM5_11384_blade-h4-ema30-breakout-retrace.md
//
// Card mapping:
// - No Trade Filter: invalid quote and spread cap only; news and Friday close are
//   handled by the framework, with Strategy_NewsFilterHook callable for Q09/P8.
// - Trade Entry: H4 EMA30 slope + price-side trend, H4 swing S/R over shifts
//   10..30, strong ATR breakout candle, then pending limit at the broken level.
// - Trade Management: cancel stale failed-retest pending orders, move to BE after
//   one stop distance, then step-trail by fixed pips.
// - Trade Close: no discretionary close; exits are SL/TP/trailing/Friday close.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11384;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period          = 30;
input int    strategy_slope_lookback      = 20;
input int    strategy_sr_start_shift      = 10;
input int    strategy_sr_end_shift        = 30;
input int    strategy_atr_period          = 14;
input double strategy_breakout_atr_mult   = 1.5;
input int    strategy_retrace_tol_pips    = 5;
input int    strategy_sl_pips             = 25;
input int    strategy_sl_cap_pips         = 40;
input double strategy_tp_rr               = 2.5;
input int    strategy_pending_expiry_bars = 6;
input int    strategy_cancel_pips         = 30;
input int    strategy_spread_cap_pips     = 20;
input int    strategy_be_buffer_pips      = 1;
input int    strategy_trail_trigger_pips  = 35;
input int    strategy_trail_step_pips     = 15;

double StrategyPipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

int StrategyEffectiveStopPips()
  {
   if(strategy_sl_pips <= 0)
      return 0;
   if(strategy_sl_cap_pips > 0 && strategy_sl_pips > strategy_sl_cap_pips)
      return strategy_sl_cap_pips;
   return strategy_sl_pips;
  }

bool StrategyHasOurPendingOrder()
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
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }

   return false;
  }

double StrategyNearestEmaTarget(const QM_OrderType side, const double entry_price)
  {
   double targets[3];
   targets[0] = QM_EMA(_Symbol, PERIOD_H4, 150, 1);
   targets[1] = QM_EMA(_Symbol, PERIOD_H4, 200, 1);
   targets[2] = QM_EMA(_Symbol, PERIOD_H4, 365, 1);

   double best = 0.0;
   for(int i = 0; i < 3; ++i)
     {
      const double target = targets[i];
      if(target <= 0.0)
         continue;

      if(QM_OrderTypeIsBuy(side))
        {
         if(target <= entry_price)
            continue;
         if(best <= 0.0 || target < best)
            best = target;
        }
      else
        {
         if(target >= entry_price)
            continue;
         if(best <= 0.0 || target > best)
            best = target;
        }
     }

   return (best > 0.0) ? QM_StopRulesNormalizePrice(_Symbol, best) : 0.0;
  }

double StrategyTakeProfit(const QM_OrderType side,
                          const double entry_price,
                          const double sl_price)
  {
   const double ema_target = StrategyNearestEmaTarget(side, entry_price);
   if(ema_target > 0.0)
      return ema_target;
   return QM_TakeRR(_Symbol, side, entry_price, sl_price, strategy_tp_rr);
  }

// Return TRUE to BLOCK trading this tick. Time has no extra card-specific gate;
// the framework handles news and Friday close before this hook.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double cap = StrategyPipDistance(strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   if(ask > bid && spread > cap)
      return true;

   return false;
  }

// Caller guarantees QM_IsNewBar() == true. The CopyRates scan is bounded and
// runs once per closed H4 bar; it is the bespoke structural S/R read from the
// card's Implementation Notes.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(QM_TM_OpenPositionCount(magic) > 0 || StrategyHasOurPendingOrder())
      return false;
   if(strategy_ema_period <= 0 || strategy_slope_lookback <= 0 ||
      strategy_atr_period <= 0 || strategy_breakout_atr_mult <= 0.0 ||
      strategy_tp_rr <= 0.0)
      return false;
   if(strategy_sr_start_shift < 2 || strategy_sr_end_shift < strategy_sr_start_shift)
      return false;

   const int needed = strategy_sr_end_shift + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 0, needed, rates); // perf-allowed
   if(copied < needed)
      return false;

   const double ema_now = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1);
   const double ema_past = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period,
                                  1 + strategy_slope_lookback);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(ema_now <= 0.0 || ema_past <= 0.0 || atr <= 0.0)
      return false;

   const double close1 = rates[1].close;
   const double range1 = rates[1].high - rates[1].low;
   if(close1 <= 0.0 || range1 <= 0.0 || range1 < atr * strategy_breakout_atr_mult)
      return false;

   double resistance = 0.0;
   double support = 0.0;
   for(int shift = strategy_sr_start_shift; shift <= strategy_sr_end_shift; ++shift)
     {
      if(rates[shift].high > resistance)
         resistance = rates[shift].high;
      if(support <= 0.0 || rates[shift].low < support)
         support = rates[shift].low;
     }
   if(resistance <= 0.0 || support <= 0.0)
      return false;

   const int stop_pips = StrategyEffectiveStopPips();
   const int expiry_seconds = (strategy_pending_expiry_bars > 0)
                              ? strategy_pending_expiry_bars * PeriodSeconds(PERIOD_H4)
                              : 0;
   const double retrace_tol = StrategyPipDistance(strategy_retrace_tol_pips);
   if(stop_pips <= 0 || retrace_tol <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool uptrend = (ema_now > ema_past && close1 > ema_now);
   if(uptrend && close1 > resistance)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, resistance);
      if(entry <= 0.0 || ask <= entry)
         return false;

      const double sl = QM_StopFixedPips(_Symbol, QM_BUY_LIMIT, entry, stop_pips);
      const double tp = StrategyTakeProfit(QM_BUY_LIMIT, entry, sl);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type = QM_BUY_LIMIT;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "blade_h4_breakout_retrace_buy_limit";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   const bool downtrend = (ema_now < ema_past && close1 < ema_now);
   if(downtrend && close1 < support)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, support);
      if(entry <= 0.0 || bid >= entry)
         return false;

      const double sl = QM_StopFixedPips(_Symbol, QM_SELL_LIMIT, entry, stop_pips);
      const double tp = StrategyTakeProfit(QM_SELL_LIMIT, entry, sl);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
         return false;

      req.type = QM_SELL_LIMIT;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "blade_h4_breakout_retrace_sell_limit";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   return false;
  }

// Cancel failed retest pending orders and manage filled positions.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double cancel_dist = StrategyPipDistance(strategy_cancel_pips);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(cancel_dist > 0.0 && bid > 0.0 && ask > 0.0)
     {
      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong order_ticket = OrderGetTicket(i);
         if(order_ticket == 0 || !OrderSelect(order_ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != magic)
            continue;

         const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         const double entry = OrderGetDouble(ORDER_PRICE_OPEN);
         if(order_type == ORDER_TYPE_BUY_LIMIT && bid < entry - cancel_dist)
            QM_TM_RemovePendingOrder(order_ticket, "blade_retrace_buy_failed");
         else if(order_type == ORDER_TYPE_SELL_LIMIT && ask > entry + cancel_dist)
            QM_TM_RemovePendingOrder(order_ticket, "blade_retrace_sell_failed");
        }
     }

   const int stop_pips = StrategyEffectiveStopPips();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(stop_pips > 0)
         QM_TM_MoveToBreakEven(ticket, stop_pips, strategy_be_buffer_pips);
      if(strategy_trail_trigger_pips > 0 && strategy_trail_step_pips > 0)
         QM_TM_TrailStep(ticket, strategy_trail_trigger_pips, strategy_trail_step_pips);
     }
  }

// No strategy-specific market exit; SL/TP, BE/trailing, and framework Friday
// close own the close path.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Hook exists for Q09/P8 news impact mode; defer to the framework.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
