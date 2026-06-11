#property strict
#property version   "5.0"
#property description "QM5_11480 Capra Pristine PBS/PSS Pullback D1"

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
input int    qm_ea_id                   = 11480;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_ema_period        = 20;
input int    strategy_ema_slope_bars    = 5;
input int    strategy_pullback_bars     = 3;
input double strategy_entry_offset_pips = 1.0;
input double strategy_max_sl_pips       = 80.0;
input int    strategy_pivot_lookback    = 10;
input double strategy_atr_tp_mult       = 2.0;
input int    strategy_atr_period        = 14;
input int    strategy_trail_after_bars  = 2;
input int    strategy_time_stop_bars    = 5;
input double strategy_spread_cap_pips   = 25.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return true;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0)
      return true;

   if((ask - bid) / pip > strategy_spread_cap_pips)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 24 * 60 * 60;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.day_of_week == 5)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return false;
     }

   if(strategy_ema_period < 2 || strategy_ema_slope_bars < 1 ||
      strategy_pullback_bars < 3 || strategy_pivot_lookback < 2 ||
      strategy_entry_offset_pips <= 0.0 || strategy_max_sl_pips <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   const double offset = strategy_entry_offset_pips * pip;

   const ENUM_TIMEFRAMES tf = PERIOD_D1;
   const double ema1 = QM_EMA(_Symbol, tf, strategy_ema_period, 1);
   const double ema_slope = QM_EMA(_Symbol, tf, strategy_ema_period, 1 + strategy_ema_slope_bars);
   if(ema1 <= 0.0 || ema_slope <= 0.0)
      return false;

   // perf-allowed: D1 OHLC structural pullback pattern, evaluated only after the framework new-bar gate.
   const double close1 = iClose(_Symbol, tf, 1);
   const double high1 = iHigh(_Symbol, tf, 1);
   const double high2 = iHigh(_Symbol, tf, 2);
   const double high3 = iHigh(_Symbol, tf, 3);
   const double high4 = iHigh(_Symbol, tf, 4);
   const double low1 = iLow(_Symbol, tf, 1);
   const double low2 = iLow(_Symbol, tf, 2);
   const double low3 = iLow(_Symbol, tf, 3);
   const double low4 = iLow(_Symbol, tf, 4);
   const double open1 = iOpen(_Symbol, tf, 1);
   const double open2 = iOpen(_Symbol, tf, 2);
   const double open3 = iOpen(_Symbol, tf, 3);
   const double close2 = iClose(_Symbol, tf, 2);
   const double close3 = iClose(_Symbol, tf, 3);
   if(close1 <= 0.0 || high1 <= 0.0 || high2 <= 0.0 || high3 <= 0.0 || high4 <= 0.0 ||
      low1 <= 0.0 || low2 <= 0.0 || low3 <= 0.0 || low4 <= 0.0 ||
      open1 <= 0.0 || open2 <= 0.0 || open3 <= 0.0 || close2 <= 0.0 || close3 <= 0.0)
      return false;

   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int shift = 2; shift < 2 + strategy_pivot_lookback; ++shift)
     {
      prior_high = MathMax(prior_high, iHigh(_Symbol, tf, shift));
      prior_low = MathMin(prior_low, iLow(_Symbol, tf, shift));
     }
   if(prior_high <= 0.0 || prior_low <= 0.0 || prior_low == DBL_MAX)
      return false;

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const bool lower_high_pullback = (high1 < high2 && high2 < high3 && high3 < high4);
   const bool bearish_bars = (close1 < open1 && close2 < open2 && close3 < open3);
   const bool higher_low_rally = (low1 > low2 && low2 > low3 && low3 > low4);
   const bool bullish_bars = (close1 > open1 && close2 > open2 && close3 > open3);

   if(close1 > ema1 && ema1 > ema_slope && (lower_high_pullback || bearish_bars))
     {
      const double entry = high1 + offset;
      const double sl = MathMin(low1, low2) - offset;
      double tp = prior_high;
      if(tp <= entry && atr > 0.0)
         tp = entry + atr * strategy_atr_tp_mult;
      const double sl_pips = MathAbs(entry - sl) / pip;
      if(sl <= 0.0 || tp <= entry || sl_pips > strategy_max_sl_pips)
         return false;

      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(entry, digits);
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(tp, digits);
      req.reason = "CAPRA_PBS_D1_BUY_STOP";
      return true;
     }

   if(close1 < ema1 && ema1 < ema_slope && (higher_low_rally || bullish_bars))
     {
      const double entry = low1 - offset;
      const double sl = MathMax(high1, high2) + offset;
      double tp = prior_low;
      if(tp >= entry && atr > 0.0)
         tp = entry - atr * strategy_atr_tp_mult;
      const double sl_pips = MathAbs(sl - entry) / pip;
      if(entry <= 0.0 || sl <= entry || tp >= entry || tp <= 0.0 || sl_pips > strategy_max_sl_pips)
         return false;

      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(entry, digits);
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(tp, digits);
      req.reason = "CAPRA_PSS_D1_SELL_STOP";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(now - opened < strategy_trail_after_bars * 24 * 60 * 60)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      // perf-allowed: one closed D1 bar extreme for card-defined bar-by-bar trail.
      if(ptype == POSITION_TYPE_BUY)
        {
         const double trail_sl = NormalizeDouble(iLow(_Symbol, PERIOD_D1, 1) - pip, digits);
         if(trail_sl > 0.0 && (current_sl <= 0.0 || trail_sl > current_sl + point))
            QM_TM_MoveSL(ticket, trail_sl, "CAPRA_PBS_TRAIL_D1_LOW");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double trail_sl = NormalizeDouble(iHigh(_Symbol, PERIOD_D1, 1) + pip, digits);
         if(trail_sl > 0.0 && (current_sl <= 0.0 || trail_sl < current_sl - point))
            QM_TM_MoveSL(ticket, trail_sl, "CAPRA_PSS_TRAIL_D1_HIGH");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(now - opened >= strategy_time_stop_bars * 24 * 60 * 60)
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
