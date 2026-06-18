#property strict
#property version   "5.0"
#property description "QM5_11493 carter-t-bb-slope-midline-bounce-m5 — BB slope + midline bounce (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11493 carter-t-bb-slope-midline-bounce-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   System #4, self-published 2014. R1 CONDITIONAL (named author, self-published).
// Card: artifacts/cards_approved/QM5_11493_carter-t-bb-slope-midline-bounce-m5.md
//   (g0_status APPROVED).
//
// Concept: in a sloped Bollinger trend the BB midline (basis 20-SMA) acts as a
//   dynamic mean. Price periodically pulls back to the midline; a bounce off the
//   trend-side of the rising/falling midline is a continuation entry. The midline
//   SLOPE is the trend STATE; the bounce (touch-and-resume on the same closed bar)
//   is the single trigger EVENT. TP = opposite outer band; SL = same-side outer
//   band, capped at a pip cap (whichever is tighter). All reads at closed bar.
//
// .DWX invariants honoured:
//   * Slope STATE + bounce EVENT — never two cross events on the same bar
//     (two-cross trap). The bounce is one closed-bar test (low<=mid && close>=mid).
//   * Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks).
//   * QM_IsNewBar() consumed ONCE by the framework OnTick wiring.
//   * Friday entries suppressed via the no-trade filter (broker-time DST-aware).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11493;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period          = 20;     // Bollinger period (basis SMA)
input double strategy_bb_deviation       = 2.0;    // Bollinger std-dev multiple
input int    strategy_slope_lookback     = 3;      // bars back for midline slope (state)
input double strategy_sl_pip_cap         = 15.0;   // SL cap in pips (tighter of band/cap)
input bool   strategy_block_friday       = true;   // no new entries on Friday
input double strategy_spread_pct_of_stop = 25.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard (fail-open on .DWX zero spread) plus an
// optional no-Friday-entry filter in broker time.
bool Strategy_NoTradeFilter()
  {
   // --- No new entries on Friday (broker time, DST-aware) ---
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return true;
     }

   // --- Spread guard: only a genuinely wide spread blocks ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop-distance reference for the cap: the pip-cap distance scales with symbol.
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pip_cap);
   if(cap_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * cap_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
//
// LONG:  midline slope up (state) + price pulled back to touch the midline and
//        closed back above it (single bounce event on the last closed bar).
// SHORT: mirror.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger reads at the last closed bar (shift 1) for the bounce event ---
   const double mid1   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   // Slope reference: midline `slope_lookback` bars before the event bar.
   const int    slope_shift = strategy_slope_lookback + 1;
   const double mid_back = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, slope_shift);
   if(mid1 <= 0.0 || mid_back <= 0.0)
      return false;

   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(upper1 <= 0.0 || lower1 <= 0.0)
      return false;

   // Last closed-bar OHLC for the bounce test (perf-allowed single closed-bar reads).
   const double low1   = iLow(_Symbol, _Period, 1);
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(low1 <= 0.0 || high1 <= 0.0 || close1 <= 0.0)
      return false;

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pip_cap);
   if(cap_distance <= 0.0)
      return false;

   // --- LONG: rising midline + bounce up off the midline ---
   const bool slope_up   = (mid1 > mid_back);
   const bool bounce_up  = (low1 <= mid1 && close1 >= mid1); // touched midline, closed back above
   if(slope_up && bounce_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // SL = tighter of (lower band at entry, entry - pip cap). TP = upper band.
      double sl = lower1;
      const double cap_sl = entry - cap_distance;
      if(sl < cap_sl)            // lower band further than cap → use the cap (tighter)
         sl = cap_sl;
      if(sl >= entry)            // degenerate band above price → fall back to cap
         sl = cap_sl;

      double tp = upper1;
      if(tp <= entry)            // midline-hug case: ensure a TP beyond entry
         tp = entry + cap_distance;

      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      tp = QM_StopRulesNormalizePrice(_Symbol, tp);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb_slope_midline_bounce_long";
      return true;
     }

   // --- SHORT: falling midline + bounce down off the midline ---
   const bool slope_down  = (mid1 < mid_back);
   const bool bounce_down = (high1 >= mid1 && close1 <= mid1); // touched midline, closed back below
   if(slope_down && bounce_down)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = upper1;
      const double cap_sl = entry + cap_distance;
      if(sl > cap_sl)            // upper band further than cap → use the cap (tighter)
         sl = cap_sl;
      if(sl <= entry)            // degenerate band below price → fall back to cap
         sl = cap_sl;

      double tp = lower1;
      if(tp >= entry)            // midline-hug case: ensure a TP beyond entry
         tp = entry - cap_distance;

      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      tp = QM_StopRulesNormalizePrice(_Symbol, tp);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb_slope_midline_bounce_short";
      return true;
     }

   return false;
  }

// Fixed band-derived SL/TP only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP set at entry.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
