#property strict
#property version   "5.0"
#property description "QM5_10008 ForexFactory Supply Demand First-Touch H1"

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
input int    qm_ea_id                   = 10008;
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
input int    strategy_atr_period              = 14;
input int    strategy_min_base_bars           = 2;
input int    strategy_max_base_bars           = 6;
input double strategy_base_atr_mult           = 1.0;
input int    strategy_impulse_bars            = 3;
input double strategy_impulse_atr_mult        = 1.5;
input int    strategy_min_impulse_closes      = 2;
input double strategy_stop_atr_buffer_mult    = 0.15;
input double strategy_max_zone_atr_mult       = 2.0;
input double strategy_reward_risk             = 2.0;
input int    strategy_pending_expiry_bars     = 20;
input int    strategy_trade_time_stop_bars    = 30;
input int    strategy_lookback_bars           = 72;

struct StrategyZone
  {
   bool     valid;
   int      direction;
   double   high;
   double   low;
   double   atr;
   datetime impulse_time;
  };

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

bool Strategy_HasPendingLimit()
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
      if(Strategy_IsPendingLimitType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelExpiredPendingLimits()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_pending_expiry_bars <= 0)
      return;

   const int expiry_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_H1);
   if(expiry_seconds <= 0)
      return;

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
      if(!Strategy_IsPendingLimitType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= expiry_seconds)
         QM_TM_RemovePendingOrder(ticket, "sd_pending_time_stop");
     }
  }

bool Strategy_SelectOpenPosition(datetime &opened_at)
  {
   opened_at = 0;
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_BarOverlapsZone(const MqlRates &bar, const double zone_low, const double zone_high)
  {
   return (bar.high >= zone_low && bar.low <= zone_high);
  }

bool Strategy_ValidateStops(const QM_OrderType type,
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

   const double raw_spread_points = (ask - bid) / point;
   const double spread_points = (raw_spread_points > 0.0) ? raw_spread_points : 0.0;
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_points = (double)((stops_level > 0) ? stops_level : 0) + spread_points;
   const double sl_points = MathAbs(entry - sl) / point;
   const double entry_points = (type == QM_BUY_LIMIT) ? ((ask - entry) / point)
                                                      : ((entry - bid) / point);
   if(entry_points <= min_points)
      return false;
   return (sl_points > min_points);
  }

bool Strategy_FindFreshZone(StrategyZone &zone)
  {
   zone.valid = false;
   zone.direction = 0;
   zone.high = 0.0;
   zone.low = 0.0;
   zone.atr = 0.0;
   zone.impulse_time = 0;

   const int min_required_bars = strategy_max_base_bars + strategy_impulse_bars + 5;
   const int lookback = (strategy_lookback_bars > min_required_bars) ? strategy_lookback_bars : min_required_bars;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, lookback, rates); // perf-allowed: closed-bar structural supply/demand zone scan; Strategy_EntrySignal is called only after QM_IsNewBar().
   if(copied < strategy_max_base_bars + strategy_impulse_bars + 2)
      return false;

   const int max_base = (strategy_max_base_bars > strategy_min_base_bars) ? strategy_max_base_bars : strategy_min_base_bars;
   const int min_base = (strategy_min_base_bars > 1) ? strategy_min_base_bars : 1;
   const int impulse_bars = (strategy_impulse_bars > 1) ? strategy_impulse_bars : 1;
   const int min_impulse_closes = (strategy_min_impulse_closes > 1) ? strategy_min_impulse_closes : 1;

   for(int base_recent = impulse_bars + 1; base_recent < copied - min_base - 1; ++base_recent)
     {
      for(int base_len = min_base; base_len <= max_base; ++base_len)
        {
         const int base_oldest = base_recent + base_len - 1;
         const int prior_shift = base_recent + base_len;
         if(base_recent - impulse_bars < 1 || prior_shift > copied)
            continue;

         double zone_high = rates[base_recent - 1].high;
         double zone_low = rates[base_recent - 1].low;
         for(int s = base_recent; s <= base_oldest; ++s)
           {
            if(rates[s - 1].high > zone_high)
               zone_high = rates[s - 1].high;
            if(rates[s - 1].low < zone_low)
               zone_low = rates[s - 1].low;
           }

         const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, base_recent);
         if(atr <= 0.0 || zone_high <= zone_low)
            continue;

         const double zone_height = zone_high - zone_low;
         if(zone_height > strategy_base_atr_mult * atr || zone_height > strategy_max_zone_atr_mult * atr)
            continue;

         const bool prior_drop = (rates[prior_shift - 1].close < rates[prior_shift - 1].open);
         const bool prior_rally = (rates[prior_shift - 1].close > rates[prior_shift - 1].open);
         int bullish_closes = 0;
         int bearish_closes = 0;
         double impulse_high = rates[base_recent - 2].high;
         double impulse_low = rates[base_recent - 2].low;

         for(int s = base_recent - 1; s >= base_recent - impulse_bars; --s)
           {
            const MqlRates bar = rates[s - 1];
            if(bar.close > bar.open)
               bullish_closes++;
            if(bar.close < bar.open)
               bearish_closes++;
            if(bar.high > impulse_high)
               impulse_high = bar.high;
            if(bar.low < impulse_low)
               impulse_low = bar.low;
           }

         bool fresh = true;
         for(int s = base_recent - impulse_bars - 1; s >= 1; --s)
           {
            if(Strategy_BarOverlapsZone(rates[s - 1], zone_low, zone_high))
              {
               fresh = false;
               break;
              }
           }
         if(!fresh)
            continue;

         if(prior_drop &&
            bullish_closes >= min_impulse_closes &&
            impulse_high >= zone_high + strategy_impulse_atr_mult * atr)
           {
            zone.valid = true;
            zone.direction = 1;
            zone.high = zone_high;
            zone.low = zone_low;
            zone.atr = atr;
            zone.impulse_time = rates[base_recent - impulse_bars - 1].time;
            return true;
           }

         if(prior_rally &&
            bearish_closes >= min_impulse_closes &&
            impulse_low <= zone_low - strategy_impulse_atr_mult * atr)
           {
            zone.valid = true;
            zone.direction = -1;
            zone.high = zone_high;
            zone.low = zone_low;
            zone.atr = atr;
            zone.impulse_time = rates[base_recent - impulse_bars - 1].time;
            return true;
           }
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
// No Trade Filter (time, spread, news): no card-specific time filter; central
// framework news runs before this hook, and stop-distance spread validation
// runs before pending orders are submitted.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask <= bid);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
// Trade Entry: first-touch pending limit at a fresh H1 DBR demand or RBD
// supply zone after 1.5 ATR impulse departure.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(Strategy_HasOpenPosition() || Strategy_HasPendingLimit())
      return false;

   StrategyZone zone;
   if(!Strategy_FindFreshZone(zone) || !zone.valid)
      return false;

   if(zone.direction > 0)
     {
      req.type = QM_BUY_LIMIT;
      req.price = NormalizeDouble(zone.high, _Digits);
      req.sl = NormalizeDouble(zone.low - strategy_stop_atr_buffer_mult * zone.atr, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_reward_risk);
      req.reason = "SD_FIRST_TOUCH_DEMAND";
     }
   else if(zone.direction < 0)
     {
      req.type = QM_SELL_LIMIT;
      req.price = NormalizeDouble(zone.low, _Digits);
      req.sl = NormalizeDouble(zone.high + strategy_stop_atr_buffer_mult * zone.atr, _Digits);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_reward_risk);
      req.reason = "SD_FIRST_TOUCH_SUPPLY";
     }
   else
      return false;

   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_H1);
   if(req.expiration_seconds <= 0 || req.tp <= 0.0)
      return false;

   return Strategy_ValidateStops(req.type, req.price, req.sl);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
// Trade Management: cancel stale first-touch pending orders after 20 H1 bars.
void Strategy_ManageOpenPosition()
  {
   Strategy_CancelExpiredPendingLimits();
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
// Trade Close: close live positions after 30 H1 bars if SL/TP has not fired.
bool Strategy_ExitSignal()
  {
   if(strategy_trade_time_stop_bars <= 0)
      return false;

   datetime opened_at = 0;
   if(!Strategy_SelectOpenPosition(opened_at) || opened_at <= 0)
      return false;

   const int hold_seconds = strategy_trade_time_stop_bars * PeriodSeconds(PERIOD_H1);
   if(hold_seconds <= 0)
      return false;

   return (TimeCurrent() - opened_at >= hold_seconds);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
// News Filter Hook: no strategy-specific override; central P8-compatible
// framework news filter remains callable.
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
