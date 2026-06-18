#property strict
#property version   "5.0"
#property description "QM5_11745 rfs-3sma-h4 — Triple SMA stack + fast/mid cross (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11745 rfs-3sma-h4
// -----------------------------------------------------------------------------
// Source: Anonymous, "Three moving average lines", Robo-forex Strategy
// Compilation (robofx.com, ~2015), p.87.
// Card: artifacts/cards_approved/QM5_11745_rfs-3sma-h4.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H4):
//   Trend STATE  : the slow pair SMA(mid) vs SMA(slow) ordering.
//                  bullish = SMA(mid) > SMA(slow);  bearish = SMA(mid) < SMA(slow).
//   Trigger EVENT: the fast SMA(fast) crosses the mid SMA(mid) in the stack
//                  direction — ONE fresh cross event (shift 2 -> shift 1).
//                  Long : SMA(fast)@2 <= SMA(mid)@2  AND  SMA(fast)@1 > SMA(mid)@1
//                  Short: SMA(fast)@2 >= SMA(mid)@2  AND  SMA(fast)@1 < SMA(mid)@1
//                  Only the fast/mid cross is the EVENT; the slow-pair ordering
//                  is a STATE — never two cross events on the same bar (avoids
//                  the .DWX two-cross zero-trade trap).
//   Stop         : entry -/+ sl_atr_mult * ATR(atr_period).
//   Take profit  : entry +/- tp_atr_mult * ATR (same ATR value as the stop).
//   Defensive exit: SMA(fast) crosses SMA(mid) in the OPPOSITE direction -> close.
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11745;
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
input int    strategy_sma_fast_period    = 13;    // fast SMA (the crossing line)
input int    strategy_sma_mid_period     = 26;    // mid SMA (the crossed line + slow-pair top)
input int    strategy_sma_slow_period    = 100;   // slow SMA (trend-state anchor)
input int    strategy_atr_period         = 14;    // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 3.0;   // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — alignment/cross work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Closed-bar SMA reads: fast/mid at shift 1 and shift 2 for the cross EVENT,
   // mid/slow at shift 1 for the trend STATE.
   const double fast1 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double fast2 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double mid1  = QM_SMA(_Symbol, _Period, strategy_sma_mid_period, 1);
   const double mid2  = QM_SMA(_Symbol, _Period, strategy_sma_mid_period, 2);
   const double slow1 = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   if(fast1 <= 0.0 || fast2 <= 0.0 || mid1 <= 0.0 || mid2 <= 0.0 || slow1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || entry_bid <= 0.0)
      return false;

   // --- LONG: bullish trend STATE (mid>slow) + fresh fast-over-mid cross EVENT ---
   const bool trend_up   = (mid1 > slow1);
   const bool cross_up   = (fast2 <= mid2 && fast1 > mid1);
   if(trend_up && cross_up)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "rfs_3sma_long";
      return true;
     }

   // --- SHORT: bearish trend STATE (mid<slow) + fresh fast-under-mid cross EVENT ---
   const bool trend_down = (mid1 < slow1);
   const bool cross_down = (fast2 >= mid2 && fast1 < mid1);
   if(trend_down && cross_down)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry_bid, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry_bid, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "rfs_3sma_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed ATR stop/target. The defensive
// reverse-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: fast SMA crosses the mid SMA in the OPPOSITE direction to the
// open position. One fresh cross event at shift 1 vs shift 2.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast1 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double fast2 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double mid1  = QM_SMA(_Symbol, _Period, strategy_sma_mid_period, 1);
   const double mid2  = QM_SMA(_Symbol, _Period, strategy_sma_mid_period, 2);
   if(fast1 <= 0.0 || fast2 <= 0.0 || mid1 <= 0.0 || mid2 <= 0.0)
      return false;

   const bool cross_down = (fast2 >= mid2 && fast1 < mid1); // exits a long
   const bool cross_up   = (fast2 <= mid2 && fast1 > mid1); // exits a short

   // Determine the side of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;
     }
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
