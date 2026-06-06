#property strict
#property version   "5.0"
#property description "QM5_10920 Grimes Inside-Bar Momentum Breakout"

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
input int    qm_ea_id                   = 10920;
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
input double strategy_mother_atr_min_mult     = 1.25;
input int    strategy_level_lookback_bars     = 20;
input double strategy_level_atr_near_mult     = 0.35;
input double strategy_entry_buffer_atr_mult   = 0.05;
input double strategy_min_stop_atr_mult       = 0.35;
input double strategy_max_stop_atr_mult       = 2.50;
input double strategy_min_inside_mother_frac  = 0.25;
input double strategy_spread_stop_frac        = 0.10;
input double strategy_target_r_mult           = 1.00;
input int    strategy_pending_expiry_bars     = 2;
input int    strategy_time_exit_bars          = 3;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): framework handles news and Friday;
   // this card is D1-only, and setup-specific spread is checked at entry.
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(strategy_atr_period <= 0 ||
      strategy_mother_atr_min_mult <= 0.0 ||
      strategy_level_lookback_bars < 2 ||
      strategy_level_atr_near_mult < 0.0 ||
      strategy_entry_buffer_atr_mult < 0.0 ||
      strategy_min_stop_atr_mult <= 0.0 ||
      strategy_max_stop_atr_mult <= strategy_min_stop_atr_mult ||
      strategy_min_inside_mother_frac < 0.0 ||
      strategy_spread_stop_frac <= 0.0 ||
      strategy_target_r_mult <= 0.0 ||
      strategy_pending_expiry_bars <= 0 ||
      strategy_time_exit_bars <= 0)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: D1 inside-bar breakout. The skeleton calls this only after
   // QM_IsNewBar(), so this bounded structural OHLC read runs once per bar.
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   for(int ord = OrdersTotal() - 1; ord >= 0; --ord)
     {
      const ulong ticket = OrderGetTicket(ord);
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

   const int bars_needed = strategy_level_lookback_bars + 4;
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, bars_needed, bars); // perf-allowed: bounded D1 inside-bar and 20-bar level scan inside framework new-bar gate.
   if(copied < bars_needed)
      return false;

   const bool standard_inside = (bars[1].high < bars[2].high && bars[1].low > bars[2].low);
   const bool double_inside = (bars[1].high < bars[3].high && bars[1].low > bars[3].low &&
                               bars[2].high < bars[3].high && bars[2].low > bars[3].low);
   if(!standard_inside && !double_inside)
      return false;

   const int mother_shift = standard_inside ? 2 : 3;
   const double inside_high = bars[1].high;
   const double inside_low = bars[1].low;
   const double inside_close = bars[1].close;
   const double mother_high = bars[mother_shift].high;
   const double mother_low = bars[mother_shift].low;
   const double mother_open = bars[mother_shift].open;
   const double mother_close = bars[mother_shift].close;
   const double inside_range = inside_high - inside_low;
   const double mother_range = mother_high - mother_low;
   if(inside_high <= 0.0 || inside_low <= 0.0 ||
      mother_high <= 0.0 || mother_low <= 0.0 ||
      inside_range <= 0.0 || mother_range <= 0.0)
      return false;

   if(inside_range < strategy_min_inside_mother_frac * mother_range)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double high_20 = -DBL_MAX;
   double low_20 = DBL_MAX;
   for(int s = 1; s <= strategy_level_lookback_bars && s < copied; ++s)
     {
      high_20 = MathMax(high_20, bars[s].high);
      low_20 = MathMin(low_20, bars[s].low);
     }
   if(high_20 <= 0.0 || low_20 <= 0.0 || high_20 <= low_20)
      return false;

   const bool large_mother = (mother_range >= strategy_mother_atr_min_mult * atr);
   const bool near_high = (inside_close >= high_20 - strategy_level_atr_near_mult * atr);
   const bool near_low = (inside_close <= low_20 + strategy_level_atr_near_mult * atr);
   const bool long_setup = near_high || (large_mother && mother_close > mother_open);
   const bool short_setup = near_low || (large_mother && mother_close < mother_open);
   if(long_setup == short_setup)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double buffer = strategy_entry_buffer_atr_mult * atr;
   const int expiry_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_D1);
   if(buffer < 0.0 || expiry_seconds <= 0)
      return false;

   if(long_setup)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, inside_high + buffer);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, inside_low - buffer);
      if(entry <= ask || sl <= 0.0 || sl >= entry)
         return false;

      const double stop_dist = entry - sl;
      if(stop_dist < strategy_min_stop_atr_mult * atr ||
         stop_dist > strategy_max_stop_atr_mult * atr)
         return false;
      if((ask - bid) > strategy_spread_stop_frac * stop_dist)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_target_r_mult * stop_dist);
      req.reason = "GRIMES_IB_BREAK_LONG";
      req.expiration_seconds = expiry_seconds;
      return (req.tp > entry);
     }

   const double entry = QM_StopRulesNormalizePrice(_Symbol, inside_low - buffer);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, inside_high + buffer);
   if(entry >= bid || sl <= 0.0 || sl <= entry)
      return false;

   const double stop_dist = sl - entry;
   if(stop_dist < strategy_min_stop_atr_mult * atr ||
      stop_dist > strategy_max_stop_atr_mult * atr)
      return false;
   if((ask - bid) > strategy_spread_stop_frac * stop_dist)
      return false;

   req.type = QM_SELL_STOP;
   req.price = entry;
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_target_r_mult * stop_dist);
   req.reason = "GRIMES_IB_BREAK_SHORT";
   req.expiration_seconds = expiry_seconds;
   return (req.tp > 0.0 && req.tp < entry);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: one active position per symbol/magic; remove any stale
   // pending stop once a position exists.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool has_position = false;
   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      break;
     }

   if(!has_position)
      return;

   for(int ord = OrdersTotal() - 1; ord >= 0; --ord)
     {
      const ulong ticket = OrderGetTicket(ord);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "grimes_ib_position_active");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: SL handles the opposite-side breach; this enforces the
   // card's three-D1-bar time exit for filled positions.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int max_hold_seconds = strategy_time_exit_bars * PeriodSeconds(PERIOD_D1);
   if(max_hold_seconds <= 0)
      return false;

   const datetime now = TimeCurrent();
   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= max_hold_seconds)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; defer to framework Q09 axes.
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
