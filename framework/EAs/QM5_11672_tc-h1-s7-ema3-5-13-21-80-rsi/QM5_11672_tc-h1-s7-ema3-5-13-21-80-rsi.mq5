#property strict
#property version   "5.0"
#property description "QM5_11672 tc-h1-s7-ema3-5-13-21-80-rsi — 5-EMA fan + RSI trend cross (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11672 tc-h1-s7-ema3-5-13-21-80-rsi
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trading Strategy #7", in 20 Forex Trading
//   Strategies Collection (H1), self-published 2014 (source_id 6b5ab225).
// Card: artifacts/cards_approved/QM5_11672_tc-h1-s7-ema3-5-13-21-80-rsi.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one open position per magic):
//   Trend STATE  : 5-EMA fan ordering on the closed bar.
//                  LONG  fan = EMA3 > EMA5 > EMA13 > EMA21 > EMA80.
//                  SHORT fan = EMA3 < EMA5 < EMA13 < EMA21 < EMA80.
//                  (Card's macro filter EMA13/EMA21 vs EMA80 is implied by, and
//                   stricter under, the full monotone fan.)
//   Momentum STATE: RSI(period) on the SAME side — LONG needs RSI > rsi_level,
//                   SHORT needs RSI < rsi_level. This is a STATE, never a cross.
//   Trigger EVENT: the fastest pair EMA3/EMA5 crosses in the fan direction.
//                  LONG : EMA3 was <= EMA5 at shift 2 and is > EMA5 at shift 1.
//                  SHORT: EMA3 was >= EMA5 at shift 2 and is < EMA5 at shift 1.
//                  Exactly ONE cross event drives entry (no two-cross trap):
//                  the fan ordering + RSI are STATES observed alongside it.
//   Stop loss    : fixed pips (card: 25 pips), scale-correct via pip helper.
//   Take profit  : optional fixed RR multiple of the stop (card: 2:1 fallback).
//                  rr <= 0 => no fixed TP; the signal-based exit closes the trade.
//   Exit         : the fast pair crosses back the other way (EMA3 vs EMA5), OR
//                  RSI crosses the rsi_level against the position. Closed-bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11672;
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
input int    strategy_ema_p1            = 3;     // fastest EMA (fan + trigger leg)
input int    strategy_ema_p2            = 5;     // EMA #2 (fan + trigger leg)
input int    strategy_ema_p3            = 13;    // EMA #3 (mid fan)
input int    strategy_ema_p4            = 21;    // EMA #4 (mid fan)
input int    strategy_ema_p5            = 80;    // slowest EMA (macro fan)
input int    strategy_rsi_period        = 21;    // RSI confirmation period
input double strategy_rsi_level         = 50.0;  // RSI side level (>level long, <level short)
input int    strategy_sl_pips           = 25;    // fixed stop, in pips
input double strategy_tp_rr             = 2.0;   // TP = rr * stop distance; <=0 disables fixed TP
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fan/RSI/cross work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

   // --- Closed-bar EMA fan (shift 1) for the five periods ---
   const double e1 = QM_EMA(_Symbol, _Period, strategy_ema_p1, 1);
   const double e2 = QM_EMA(_Symbol, _Period, strategy_ema_p2, 1);
   const double e3 = QM_EMA(_Symbol, _Period, strategy_ema_p3, 1);
   const double e4 = QM_EMA(_Symbol, _Period, strategy_ema_p4, 1);
   const double e5 = QM_EMA(_Symbol, _Period, strategy_ema_p5, 1);
   if(e1 <= 0.0 || e2 <= 0.0 || e3 <= 0.0 || e4 <= 0.0 || e5 <= 0.0)
      return false;

   // Fan ordering = trend STATE.
   const bool fan_long  = (e1 > e2 && e2 > e3 && e3 > e4 && e4 > e5);
   const bool fan_short = (e1 < e2 && e2 < e3 && e3 < e4 && e4 < e5);
   if(!fan_long && !fan_short)
      return false;

   // --- RSI side = momentum STATE (not a cross) ---
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   // --- Trigger EVENT: fastest pair EMA1/EMA2 cross in the fan direction ---
   // shift 2 = state before the trigger bar; shift 1 = the closed trigger bar.
   const double e1_prev = QM_EMA(_Symbol, _Period, strategy_ema_p1, 2);
   const double e2_prev = QM_EMA(_Symbol, _Period, strategy_ema_p2, 2);
   if(e1_prev <= 0.0 || e2_prev <= 0.0)
      return false;

   const bool cross_up   = (e1_prev <= e2_prev && e1 > e2);
   const bool cross_down = (e1_prev >= e2_prev && e1 < e2);

   bool        go_long  = false;
   bool        go_short = false;
   if(fan_long && cross_up && rsi > strategy_rsi_level)
      go_long = true;
   else if(fan_short && cross_down && rsi < strategy_rsi_level)
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
   if(strategy_tp_rr > 0.0)
     {
      tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
     }

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "ema_fan_rsi_long" : "ema_fan_rsi_short";
   return true;
  }

// No active management beyond the fixed stop/target. Signal exit lives below.
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

   const double e1      = QM_EMA(_Symbol, _Period, strategy_ema_p1, 1);
   const double e2      = QM_EMA(_Symbol, _Period, strategy_ema_p2, 1);
   const double e1_prev = QM_EMA(_Symbol, _Period, strategy_ema_p1, 2);
   const double e2_prev = QM_EMA(_Symbol, _Period, strategy_ema_p2, 2);
   const double rsi     = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(e1 <= 0.0 || e2 <= 0.0 || e1_prev <= 0.0 || e2_prev <= 0.0 ||
      rsi <= 0.0 || rsi_prev <= 0.0)
      return false;

   if(is_long)
     {
      const bool cross_down  = (e1_prev >= e2_prev && e1 < e2);
      const bool rsi_break   = (rsi_prev >= strategy_rsi_level && rsi < strategy_rsi_level);
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
