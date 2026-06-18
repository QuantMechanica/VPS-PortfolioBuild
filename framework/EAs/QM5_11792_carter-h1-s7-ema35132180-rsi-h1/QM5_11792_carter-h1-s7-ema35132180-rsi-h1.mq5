#property strict
#property version   "5.0"
#property description "QM5_11792 carter-h1-s7-ema35132180-rsi-h1 — 5-EMA cascade + RSI trend cross (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11792 carter-h1-s7-ema35132180-rsi-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Strategy #7", in 20 Forex Trading Strategies
//   (1 Hour Time Frame), 2014 (source_id 529382f8). pages 16-17.
// Card: artifacts/cards_approved/QM5_11792_carter-h1-s7-ema35132180-rsi-h1.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one open position per magic).
// Card body is the binding spec; this implements its LITERAL cascade wording:
//
//   Trend STATE  : five-EMA cascade alignment (NOT a strict monotone fan).
//                  LONG  : EMA3 and EMA5 are BOTH above EMA13 and EMA21,
//                          AND EMA13 and EMA21 are BOTH above EMA80.
//                  SHORT : EMA3 and EMA5 are BOTH below EMA13 and EMA21,
//                          AND EMA13 and EMA21 are BOTH below EMA80.
//                  (The fast pair's relative order is supplied by the trigger
//                   cross below, so it is intentionally NOT part of the state.)
//   Momentum STATE: RSI(period) on the SAME side — LONG needs RSI > rsi_level,
//                   SHORT needs RSI < rsi_level. STATE, never a cross.
//   Trigger EVENT: the fastest pair EMA3/EMA5 crosses in the entry direction.
//                  LONG : EMA3 was <= EMA5 at shift 2 and is > EMA5 at shift 1.
//                  SHORT: EMA3 was >= EMA5 at shift 2 and is < EMA5 at shift 1.
//                  Exactly ONE cross event drives entry (no two-cross trap);
//                  the cascade ordering + RSI side are STATES alongside it.
//   Stop loss    : fixed pips (card: 25 pips), scale-correct via pip helper.
//   Take profit  : card has no fixed TP — exit on reversal; a 4xATR(14) cap is
//                  applied as a hard ceiling (card "Factory: 4xATR(14) as cap").
//                  Disabled when strategy_tp_atr_mult <= 0.
//   Exit         : the fast pair EMA3/EMA5 crosses back the other way, OR RSI
//                  crosses back through rsi_level against the position. Closed-bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11792;
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
input int    strategy_ema_p1            = 3;     // fastest EMA (cascade + trigger leg)
input int    strategy_ema_p2            = 5;     // EMA #2 (cascade + trigger leg)
input int    strategy_ema_p3            = 13;    // EMA #3 (intermediate cascade)
input int    strategy_ema_p4            = 21;    // EMA #4 (intermediate cascade)
input int    strategy_ema_p5            = 80;    // slowest EMA (macro filter)
input int    strategy_rsi_period        = 21;    // RSI confirmation period
input double strategy_rsi_level         = 50.0;  // RSI side level (>level long, <level short)
input int    strategy_sl_pips           = 25;    // fixed stop, in pips
input double strategy_tp_atr_mult       = 4.0;   // TP cap = mult * ATR(period); <=0 disables
input int    strategy_atr_period        = 14;    // ATR period for the TP cap
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — cascade/RSI/cross work runs on
// the closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
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

   // --- Closed-bar EMA cascade (shift 1) for the five periods ---
   const double e1 = QM_EMA(_Symbol, _Period, strategy_ema_p1, 1);
   const double e2 = QM_EMA(_Symbol, _Period, strategy_ema_p2, 1);
   const double e3 = QM_EMA(_Symbol, _Period, strategy_ema_p3, 1);
   const double e4 = QM_EMA(_Symbol, _Period, strategy_ema_p4, 1);
   const double e5 = QM_EMA(_Symbol, _Period, strategy_ema_p5, 1);
   if(e1 <= 0.0 || e2 <= 0.0 || e3 <= 0.0 || e4 <= 0.0 || e5 <= 0.0)
      return false;

   // Cascade alignment = trend STATE (card's literal wording).
   const bool casc_long = (e1 > e3 && e2 > e3 && e1 > e4 && e2 > e4 &&
                           e3 > e5 && e4 > e5);
   const bool casc_short = (e1 < e3 && e2 < e3 && e1 < e4 && e2 < e4 &&
                            e3 < e5 && e4 < e5);
   if(!casc_long && !casc_short)
      return false;

   // --- RSI side = momentum STATE (not a cross) ---
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   // --- Trigger EVENT: fastest pair EMA1/EMA2 cross in the entry direction ---
   // shift 2 = state before the trigger bar; shift 1 = the closed trigger bar.
   const double e1_prev = QM_EMA(_Symbol, _Period, strategy_ema_p1, 2);
   const double e2_prev = QM_EMA(_Symbol, _Period, strategy_ema_p2, 2);
   if(e1_prev <= 0.0 || e2_prev <= 0.0)
      return false;

   const bool cross_up   = (e1_prev <= e2_prev && e1 > e2);
   const bool cross_down = (e1_prev >= e2_prev && e1 < e2);

   bool go_long  = false;
   bool go_short = false;
   if(casc_long && cross_up && rsi > strategy_rsi_level)
      go_long = true;
   else if(casc_short && cross_down && rsi < strategy_rsi_level)
      go_short = true;

   if(!go_long && !go_short)
      return false;

   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, otype, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;

   double tp = 0.0; // 0 => no fixed TP; signal-based exit closes the trade
   if(strategy_tp_atr_mult > 0.0)
     {
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value > 0.0)
        {
         tp = QM_TakeATRFromValue(_Symbol, otype, entry, atr_value, strategy_tp_atr_mult);
         if(tp <= 0.0)
            tp = 0.0; // fall back to signal-only exit if the cap can't be priced
        }
     }

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "ema_cascade_rsi_long" : "ema_cascade_rsi_short";
   return true;
  }

// No active management beyond the fixed stop / ATR-cap target. Signal exit below.
void Strategy_ManageOpenPosition()
  {
  }

// Signal exit: fast pair crosses back against the open position, OR RSI crosses
// the level against it. One closed-bar event per call.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current position side for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double e1       = QM_EMA(_Symbol, _Period, strategy_ema_p1, 1);
   const double e2       = QM_EMA(_Symbol, _Period, strategy_ema_p2, 1);
   const double e1_prev  = QM_EMA(_Symbol, _Period, strategy_ema_p1, 2);
   const double e2_prev  = QM_EMA(_Symbol, _Period, strategy_ema_p2, 2);
   const double rsi      = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(e1 <= 0.0 || e2 <= 0.0 || e1_prev <= 0.0 || e2_prev <= 0.0 ||
      rsi <= 0.0 || rsi_prev <= 0.0)
      return false;

   if(is_long)
     {
      const bool cross_down = (e1_prev >= e2_prev && e1 < e2);
      const bool rsi_break  = (rsi_prev >= strategy_rsi_level && rsi < strategy_rsi_level);
      return (cross_down || rsi_break);
     }

   // short
   const bool cross_up  = (e1_prev <= e2_prev && e1 > e2);
   const bool rsi_break = (rsi_prev <= strategy_rsi_level && rsi > strategy_rsi_level);
   return (cross_up || rsi_break);
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
