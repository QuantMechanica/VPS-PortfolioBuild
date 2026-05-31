#property strict
#property version   "5.0"
#property description "QM5_10514 MQL5 Fractured Fractals Pending Stop"

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
input int    qm_ea_id                   = 10514;
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
input ENUM_TIMEFRAMES strategy_signal_tf      = PERIOD_H1;
input int    strategy_fractal_lookback_bars   = 120;
input int    strategy_pending_buffer_points   = 2;
input int    strategy_pending_lifetime_bars   = 6;
input int    strategy_atr_period              = 14;
input double strategy_atr_floor_mult          = 0.50;
input double strategy_tp_rr                   = 1.50;
input int    strategy_max_spread_points       = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

double g_latest_upper_fractal = 0.0;
double g_prior_upper_fractal  = 0.0;
double g_latest_lower_fractal = 0.0;
double g_prior_lower_fractal  = 0.0;
int    g_latest_upper_shift   = -1;
int    g_latest_lower_shift   = -1;

bool Strategy_IsPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_IsOurPendingStop(const ulong ticket)
  {
   if(ticket == 0 || !OrderSelect(ticket))
      return false;
   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return false;
   if((int)OrderGetInteger(ORDER_MAGIC) != QM_FrameworkMagic())
      return false;
   return Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_HasPendingStop()
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
      if(Strategy_IsOurPendingStop(OrderGetTicket(i)))
         return true;
   return false;
  }

void Strategy_RemoveExpiredPendingStops()
  {
   const int lifetime_seconds = MathMax(1, strategy_pending_lifetime_bars) * PeriodSeconds(strategy_signal_tf);
   if(lifetime_seconds <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(!Strategy_IsOurPendingStop(ticket))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= lifetime_seconds)
         QM_TM_RemovePendingOrder(ticket, "fractal_pending_lifetime_expired");
     }
  }

bool Strategy_IsUpperFractal(const int shift)
  {
   if(shift < 3)
      return false;
   const double h = iHigh(_Symbol, strategy_signal_tf, shift);
   if(h <= 0.0)
      return false;
   return (h > iHigh(_Symbol, strategy_signal_tf, shift + 1) &&
           h > iHigh(_Symbol, strategy_signal_tf, shift + 2) &&
           h > iHigh(_Symbol, strategy_signal_tf, shift - 1) &&
           h > iHigh(_Symbol, strategy_signal_tf, shift - 2));
  }

bool Strategy_IsLowerFractal(const int shift)
  {
   if(shift < 3)
      return false;
   const double l = iLow(_Symbol, strategy_signal_tf, shift);
   if(l <= 0.0)
      return false;
   return (l < iLow(_Symbol, strategy_signal_tf, shift + 1) &&
           l < iLow(_Symbol, strategy_signal_tf, shift + 2) &&
           l < iLow(_Symbol, strategy_signal_tf, shift - 1) &&
           l < iLow(_Symbol, strategy_signal_tf, shift - 2));
  }

bool Strategy_RefreshFractals()
  {
   g_latest_upper_fractal = 0.0;
   g_prior_upper_fractal = 0.0;
   g_latest_lower_fractal = 0.0;
   g_prior_lower_fractal = 0.0;
   g_latest_upper_shift = -1;
   g_latest_lower_shift = -1;

   int upper_count = 0;
   int lower_count = 0;
   const int max_shift = MathMax(6, strategy_fractal_lookback_bars);

   for(int shift = 3; shift <= max_shift && (upper_count < 2 || lower_count < 2); ++shift)
     {
      if(upper_count < 2 && Strategy_IsUpperFractal(shift))
        {
         const double h = iHigh(_Symbol, strategy_signal_tf, shift);
         if(upper_count == 0)
           {
            g_latest_upper_fractal = h;
            g_latest_upper_shift = shift;
           }
         else
            g_prior_upper_fractal = h;
         upper_count++;
        }

      if(lower_count < 2 && Strategy_IsLowerFractal(shift))
        {
         const double l = iLow(_Symbol, strategy_signal_tf, shift);
         if(lower_count == 0)
           {
            g_latest_lower_fractal = l;
            g_latest_lower_shift = shift;
           }
         else
            g_prior_lower_fractal = l;
         lower_count++;
        }
     }

   return (upper_count >= 2 && lower_count >= 2);
  }

double Strategy_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double Strategy_StopWithAtrFloor(const QM_OrderType side,
                                 const double entry,
                                 const double structural_stop)
  {
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double floor_dist = atr * strategy_atr_floor_mult;
   if(entry <= 0.0 || structural_stop <= 0.0 || floor_dist <= 0.0)
      return 0.0;

   if(QM_OrderTypeIsBuy(side))
     {
      double sl = structural_stop;
      if(entry - sl < floor_dist)
         sl = entry - floor_dist;
      return Strategy_NormalizePrice(sl);
     }

   double sl = structural_stop;
   if(sl - entry < floor_dist)
      sl = entry + floor_dist;
   return Strategy_NormalizePrice(sl);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
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

   Strategy_RemoveExpiredPendingStops();

   if(Strategy_HasOpenPosition() || Strategy_HasPendingStop())
      return false;
   if(strategy_fractal_lookback_bars < 6 || strategy_atr_period <= 0 ||
      strategy_atr_floor_mult <= 0.0 || strategy_tp_rr <= 0.0)
      return false;
   if(!Strategy_RefreshFractals())
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double buffer = MathMax(0, strategy_pending_buffer_points) * point;
   const bool long_setup = (g_latest_upper_fractal > g_prior_upper_fractal);
   const bool short_setup = (g_latest_lower_fractal < g_prior_lower_fractal);

   if(!long_setup && !short_setup)
      return false;

   const bool prefer_long = long_setup && (!short_setup || g_latest_upper_shift <= g_latest_lower_shift);
   const bool prefer_short = short_setup && (!long_setup || g_latest_lower_shift < g_latest_upper_shift);

   if(prefer_long)
     {
      const double entry = Strategy_NormalizePrice(g_latest_upper_fractal + buffer);
      const double sl = Strategy_StopWithAtrFloor(QM_BUY_STOP, entry, g_latest_lower_fractal);
      const double tp = QM_TakeRR(_Symbol, QM_BUY_STOP, entry, sl, strategy_tp_rr);
      if(entry <= ask || sl <= 0.0 || sl >= entry || tp <= entry)
         return false;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = Strategy_NormalizePrice(tp);
      req.reason = "FRACTAL_HIGHER_HIGH_BUY_STOP";
      req.expiration_seconds = MathMax(1, strategy_pending_lifetime_bars) * PeriodSeconds(strategy_signal_tf);
      return true;
     }

   if(prefer_short)
     {
      const double entry = Strategy_NormalizePrice(g_latest_lower_fractal - buffer);
      const double sl = Strategy_StopWithAtrFloor(QM_SELL_STOP, entry, g_latest_upper_fractal);
      const double tp = QM_TakeRR(_Symbol, QM_SELL_STOP, entry, sl, strategy_tp_rr);
      if(entry >= bid || sl <= entry || tp <= 0.0 || tp >= entry)
         return false;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = Strategy_NormalizePrice(tp);
      req.reason = "FRACTAL_LOWER_LOW_SELL_STOP";
      req.expiration_seconds = MathMax(1, strategy_pending_lifetime_bars) * PeriodSeconds(strategy_signal_tf);
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   Strategy_RemoveExpiredPendingStops();

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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(type == POSITION_TYPE_BUY && g_latest_lower_fractal > 0.0)
        {
         const double new_sl = Strategy_NormalizePrice(g_latest_lower_fractal);
         if(new_sl > current_sl + point * 0.5)
            QM_TM_MoveSL(ticket, new_sl, "trail_latest_lower_fractal");
        }
      else if(type == POSITION_TYPE_SELL && g_latest_upper_fractal > 0.0)
        {
         const double new_sl = Strategy_NormalizePrice(g_latest_upper_fractal);
         if(current_sl <= 0.0 || new_sl < current_sl - point * 0.5)
            QM_TM_MoveSL(ticket, new_sl, "trail_latest_upper_fractal");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
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
