#property strict
#property version   "5.0"
#property description "QM5_11360 robo-range-wma-ema-rsi — RoboForex 'The Range' EMA channel + WMA cross + RSI (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11360 robo-range-wma-ema-rsi
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection, "Strategy The Range" (pages 24-25).
// Card: artifacts/cards_approved/QM5_11360_robo-range-wma-ema-rsi.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, M15):
//   Channel : two EMAs (16, 30) form a "red range" band.
//   Movers  : two WMAs (LWMA 5, 12) cross above/below that band.
//
//   Confluence — ONE trigger EVENT, the rest are STATES (avoids the
//   two-cross-same-bar zero-trade trap):
//     Trigger EVENT (LONG): WMA(12) crosses ABOVE EMA(30) — slower mover
//                           exits the red range from below. One event/bar.
//     STATE 1 (LONG)      : WMA(5) above BOTH EMA(16) and EMA(30) (already
//                           out of range — the early/leading mover).
//     STATE 2 (LONG)      : RSI(14) above the level (default 50) — trend confirm.
//   SHORT is the exact mirror.
//
//   Stop  : EMA(30) level at entry, pushed 5 pips beyond it (far edge of the
//           channel), but clamped to a MAX of 20 pips from entry. Pip-correct
//           via QM_StopRulesPipsToPriceDistance (handles 5-digit / JPY scaling).
//   Exit  : defensive — WMA(5) crosses back INTO the red range
//           (WMA5 crosses below EMA16 for LONG; above for SHORT).
//   Spread: fail-OPEN on .DWX zero modeled spread; block only a genuinely wide
//           spread above the pip cap.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11360;
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
input int    strategy_ema_fast_period    = 16;    // fast EMA — near edge of the red range
input int    strategy_ema_slow_period    = 30;    // slow EMA — far edge of the red range / SL anchor
input int    strategy_wma_fast_period    = 5;     // leading WMA (LWMA) — early mover (STATE)
input int    strategy_wma_slow_period    = 12;    // trailing WMA (LWMA) — cross trigger (EVENT)
input int    strategy_rsi_period         = 14;    // RSI lookback
input double strategy_rsi_level          = 50.0;  // RSI trend-confirmation threshold (STATE)
input int    strategy_sl_buffer_pips     = 5;     // push SL this many pips beyond EMA(30)
input int    strategy_sl_max_pips        = 20;    // hard cap on SL distance from entry
input double strategy_spread_cap_pips    = 5.0;   // skip only if spread exceeds this many pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread       = ask - bid;
   const double spread_cap   = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Confluence entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// ONE trigger EVENT (WMA12 x EMA30 cross), two STATES (WMA5 out of range, RSI).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Channel + movers, closed bar (shift 1) and prior closed bar (shift 2) ---
   const double ema_fast  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double wma_fast  = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   const double wma_slow1 = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 1);
   const double wma_slow2 = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 2);
   const double ema_slow2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || wma_fast <= 0.0 ||
      wma_slow1 <= 0.0 || wma_slow2 <= 0.0 || ema_slow2 <= 0.0)
      return false;

   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   // === LONG =================================================================
   // Trigger EVENT: WMA(12) crosses ABOVE EMA(30) — prev below/at, now above.
   const bool long_cross = (wma_slow2 <= ema_slow2 && wma_slow1 > ema_slow);
   // STATE 1: WMA(5) above BOTH EMAs (already out of the range / leading).
   const bool long_state_wma = (wma_fast > ema_fast && wma_fast > ema_slow);
   // STATE 2: RSI above the level — trend confirmation.
   const bool long_state_rsi = (rsi > strategy_rsi_level);

   if(long_cross && long_state_wma && long_state_rsi)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = ComputeStopPrice(QM_BUY, entry, ema_slow);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — exit is the defensive WMA5/EMA16 cross
      req.reason = "robo_range_long";
      return true;
     }

   // === SHORT (mirror) =======================================================
   // Trigger EVENT: WMA(12) crosses BELOW EMA(30).
   const bool short_cross = (wma_slow2 >= ema_slow2 && wma_slow1 < ema_slow);
   // STATE 1: WMA(5) below BOTH EMAs.
   const bool short_state_wma = (wma_fast < ema_fast && wma_fast < ema_slow);
   // STATE 2: RSI below the level.
   const bool short_state_rsi = (rsi < strategy_rsi_level);

   if(short_cross && short_state_wma && short_state_rsi)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = ComputeStopPrice(QM_SELL, entry, ema_slow);
      if(sl <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "robo_range_short";
      return true;
     }

   return false;
  }

// Stop = EMA(30) edge of the channel, pushed sl_buffer_pips beyond it, clamped
// to a maximum of sl_max_pips from entry. Pip-correct distances (5-digit/JPY).
double ComputeStopPrice(const QM_OrderType type, const double entry, const double ema_slow)
  {
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double maxdist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(maxdist <= 0.0)
      return 0.0;

   double sl;
   if(type == QM_BUY)
     {
      sl = ema_slow - buffer;                 // far edge below entry, plus buffer
      const double floor_price = entry - maxdist;  // never further than max cap
      if(sl < floor_price)
         sl = floor_price;
      if(sl >= entry)                          // EMA30 above entry → use max cap
         sl = entry - maxdist;
     }
   else
     {
      sl = ema_slow + buffer;
      const double ceil_price = entry + maxdist;
      if(sl > ceil_price)
         sl = ceil_price;
      if(sl <= entry)
         sl = entry + maxdist;
     }
   return QM_StopRulesNormalizePrice(_Symbol, sl);
  }

// No active trade management beyond the fixed stop. Exit handled in ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: WMA(5) crosses back INTO the red range — i.e. WMA5 crosses
// below EMA(16) for a LONG, above EMA(16) for a SHORT. One event at shift 1.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double ema_fast1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_fast2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double wma_fast1 = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   const double wma_fast2 = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 2);
   if(ema_fast1 <= 0.0 || ema_fast2 <= 0.0 || wma_fast1 <= 0.0 || wma_fast2 <= 0.0)
      return false;

   // Determine the direction of the currently open position for this magic.
   const int magic = QM_FrameworkMagic();
   bool is_long = false;
   bool found   = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found   = true;
      break;
     }
   if(!found)
      return false;

   if(is_long)
     {
      // WMA5 crosses below EMA16 — re-enters the range from above.
      return (wma_fast2 >= ema_fast2 && wma_fast1 < ema_fast1);
     }
   // SHORT: WMA5 crosses above EMA16 — re-enters the range from below.
   return (wma_fast2 <= ema_fast2 && wma_fast1 > ema_fast1);
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
