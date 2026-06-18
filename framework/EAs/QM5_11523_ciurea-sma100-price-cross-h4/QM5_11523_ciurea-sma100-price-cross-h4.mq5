#property strict
#property version   "5.0"
#property description "QM5_11523 ciurea-sma100-price-cross-h4 — SMA(100) H4 price-cross trend (long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11523 ciurea-sma100-price-cross-h4
// -----------------------------------------------------------------------------
// Source: Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
//   ScientificForex.com, ~2012 (source_id 0192e348-5570-531c-9110-7954a36caca2).
// Card: artifacts/cards_approved/QM5_11523_ciurea-sma100-price-cross-h4.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, single trigger EVENT per bar):
//   Trigger EVENT (LONG) : close[1] > SMA100[1]  AND  close[2] <= SMA100[2]
//                          (price just closed ABOVE the SMA — one fresh cross).
//   Trigger EVENT (SHORT): close[1] < SMA100[1]  AND  close[2] >= SMA100[2]
//                          (price just closed BELOW the SMA — one fresh cross).
//   The price-vs-SMA100 cross is the ONLY trigger; everything else is a STATE.
//   No-Friday-entry is a STATE filter; spread cap is a STATE filter.
//   Stop  (LONG)  : 3-bar low  (shifts 1..N) - sl_buffer_pips, capped at sl_cap_pips.
//   Stop  (SHORT) : 3-bar high (shifts 1..N) + sl_buffer_pips, capped at sl_cap_pips.
//   Take profit   : entry +/- tp_rr * |entry - SL|  (2R per source methodology).
//
// SMA(100) on H4 spans ~16.7 calendar days — a slow trend filter. Dynamic SL
// from the 3-bar extreme adapts to volatility; TP is a fixed RR multiple.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11523;
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
input int    strategy_sma_period        = 100;    // SMA period on the base TF (H4)
input int    strategy_sl_extreme_bars   = 3;      // bars back for the SL high/low extreme
input int    strategy_sl_buffer_pips    = 3;      // pips beyond the 3-bar extreme
input int    strategy_sl_cap_pips       = 80;     // P2 SL distance cap (H4 bars can be wide)
input double strategy_tp_rr             = 2.0;    // take-profit = tp_rr * stop distance
input double strategy_spread_cap_pips   = 15.0;   // skip a genuinely wide spread (pips)
input bool   strategy_no_friday_entry   = true;   // no new entries on Friday (STATE filter)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — cross/SL work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — defer, do not block

   const double spread_cap_dist =
      QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_spread_cap_pips));
   if(spread_cap_dist <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(ask > bid && spread > spread_cap_dist)
      return true;

   return false;
  }

// Price/SMA(100) cross entry (long+short). Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- STATE filter: no new entries on Friday (broker time). ---
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- SMA(100) on the base TF at the two most recent closed bars. ---
   const double sma1 = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Trigger EVENT: ONE fresh price-vs-SMA cross (never two on same bar). ---
   const bool crossed_up   = (close1 > sma1 && close2 <= sma2);
   const bool crossed_down = (close1 < sma1 && close2 >= sma2);
   if(!crossed_up && !crossed_down)
      return false;

   const QM_OrderType side = crossed_up ? QM_BUY : QM_SELL;

   // --- Dynamic SL from the N-bar high/low extreme (closed bars, structural). ---
   double extreme_low  = 0.0;
   double extreme_high = 0.0;
   bool   have_extreme = false;
   const int bars = (strategy_sl_extreme_bars > 0 ? strategy_sl_extreme_bars : 3);
   for(int s = 1; s <= bars; ++s)
     {
      const double bar_low  = iLow(_Symbol, _Period, s);  // perf-allowed: bounded structural read
      const double bar_high = iHigh(_Symbol, _Period, s); // perf-allowed: bounded structural read
      if(bar_low <= 0.0 || bar_high <= 0.0)
         continue;
      if(!have_extreme)
        {
         extreme_low  = bar_low;
         extreme_high = bar_high;
         have_extreme = true;
        }
      else
        {
         if(bar_low  < extreme_low)  extreme_low  = bar_low;
         if(bar_high > extreme_high) extreme_high = bar_high;
        }
     }
   if(!have_extreme)
      return false;

   // Entry reference price (market fill side).
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // 3-pip buffer beyond the extreme, scale-correct for 3/5-digit symbols.
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   double sl = (side == QM_BUY) ? (extreme_low - buffer) : (extreme_high + buffer);
   if(sl <= 0.0)
      return false;

   // Clamp the stop DISTANCE to the P2 cap (H4 bars can be wide).
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   double sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0)
      return false;
   if(cap_dist > 0.0 && sl_dist > cap_dist)
     {
      sl_dist = cap_dist;
      sl = (side == QM_BUY) ? (entry - sl_dist) : (entry + sl_dist);
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   // TP = tp_rr * stop distance, on the correct side of entry.
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "sma100_cross_long" : "sma100_cross_short";
   return true;
  }

// Fixed SL/TP per trade; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP. Opposite cross simply opens a
// new position after the current one closes (one position per magic).
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
