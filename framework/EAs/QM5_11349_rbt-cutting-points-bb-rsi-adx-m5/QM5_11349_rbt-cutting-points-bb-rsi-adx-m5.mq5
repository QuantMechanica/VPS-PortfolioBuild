#property strict
#property version   "5.0"
#property description "QM5_11349 rbt-cutting-points-bb-rsi-adx-m5 — RoboForex Cutting Points BB+RSI+ADX counter-trend (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11349 rbt-cutting-points-bb-rsi-adx-m5
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection, "Strategy Cutting Points" (institutional).
// Card: artifacts/cards_approved/QM5_11349_rbt-cutting-points-bb-rsi-adx-m5.md
//       (g0_status APPROVED).
//
// Mechanics (counter-trend mean-reversion scalp; closed-bar reads at shift 1/2):
//   The touch bar = shift 2 (the bar that pierced the band).
//   The confirm/trigger bar = shift 1 (the closed bar that returned inside).
//
//   Trigger EVENT (one event per bar — band RECAPTURE):
//     LONG : close[2] <= BB_lower[2]  AND  close[1] >  BB_lower[1].
//     SHORT: close[2] >= BB_upper[2]  AND  close[1] <  BB_upper[1].
//   RSI STATE (observed on the touch bar, shift 2 — extreme oscillator):
//     LONG : RSI[2] < rsi_oversold   (default 30).
//     SHORT: RSI[2] > rsi_overbought (default 70).
//   ADX STATE (regime filter, shift 1 — no strong trend = range-bound):
//     ADX[1] < adx_max (default 30).
//   Stop : touch-bar band extreme +/- sl_buffer_pips, capped at sl_max_pips.
//          Skip the setup if the band stop would exceed sl_max_pips (band too wide).
//   Take : BB middle (SMA20) of the confirm bar (shift 1) — mean-reversion target.
//   Spread guard : fail-OPEN — block ONLY a genuinely wide spread > spread_cap_pips.
//                  .DWX quotes ask==bid (0 modeled spread) -> must never block on it.
//   Session : London+NY in GMT/UTC (default 13:00-22:00 UTC). Broker time is
//             converted to UTC via QM_BrokerToUTC (DST-aware) before the check.
//
// The "touch is a STATE at shift 2 / recapture is the single EVENT at shift 1"
// split avoids the two-cross-same-bar zero-trade trap: there is exactly ONE
// fresh cross event; RSI extreme and ADX are states, not co-incident events.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11349;
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
input int    strategy_bb_period          = 20;     // Bollinger Band period
input double strategy_bb_deviation       = 2.0;    // Bollinger Band std-dev multiplier
input int    strategy_rsi_period         = 14;     // RSI lookback period
input double strategy_rsi_oversold       = 30.0;   // LONG: RSI on the touch bar must be below this
input double strategy_rsi_overbought     = 70.0;   // SHORT: RSI on the touch bar must be above this
input int    strategy_adx_period         = 14;     // ADX period
input double strategy_adx_max            = 30.0;   // skip if ADX >= this (strong trend = no reversal)
input int    strategy_sl_buffer_pips     = 3;      // SL placed this many pips beyond the touch-bar band
input int    strategy_sl_max_pips        = 15;     // skip the setup if SL distance exceeds this
input int    strategy_session_start_utc  = 13;     // session open hour, UTC (London+NY)
input int    strategy_session_end_utc    = 22;     // session close hour, UTC (exclusive)
input double strategy_spread_cap_pips    = 2.0;    // block only a genuinely wider spread (fail-OPEN)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker->UTC) + fail-OPEN spread cap.
bool Strategy_NoTradeFilter()
  {
   // --- Session filter: convert broker time to UTC (DST-aware) and gate hour ---
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   const int h = dt.hour;
   // Wrap-safe hour window [start, end). Default 13..22 is non-wrapping.
   bool in_session;
   if(strategy_session_start_utc <= strategy_session_end_utc)
      in_session = (h >= strategy_session_start_utc && h < strategy_session_end_utc);
   else
      in_session = (h >= strategy_session_start_utc || h < strategy_session_end_utc);
   if(!in_session)
      return true; // outside London+NY -> block

   // --- Spread guard: fail-OPEN. .DWX quotes ask==bid (0 spread) -> never block. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it
   const double spread = ask - bid;
   const double one_pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   const double cap = strategy_spread_cap_pips * one_pip;
   // Block only a genuinely wide spread; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Counter-trend entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Touch bar = shift 2, confirm/trigger bar = shift 1.
   const double bb_lower_touch  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_upper_touch  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_lower_now    = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_upper_now    = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_middle_now   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_lower_touch <= 0.0 || bb_upper_touch <= 0.0 ||
      bb_lower_now   <= 0.0 || bb_upper_now   <= 0.0 || bb_middle_now <= 0.0)
      return false;

   const double close_touch   = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double close_confirm = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close_touch <= 0.0 || close_confirm <= 0.0)
      return false;

   // --- ADX STATE: range-bound regime (no strong trend) ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(adx >= strategy_adx_max)
      return false;

   // --- RSI STATE: oscillator extreme on the touch bar (shift 2) ---
   const double rsi_touch = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_touch <= 0.0)
      return false;

   bool is_long  = false;
   bool is_short = false;

   // --- Trigger EVENT: band RECAPTURE (the single fresh cross) ---
   // LONG: touch bar pierced lower band, confirm bar closed back above it.
   if(close_touch <= bb_lower_touch && close_confirm > bb_lower_now &&
      rsi_touch < strategy_rsi_oversold)
      is_long = true;
   // SHORT: touch bar pierced upper band, confirm bar closed back below it.
   else if(close_touch >= bb_upper_touch && close_confirm < bb_upper_now &&
           rsi_touch > strategy_rsi_overbought)
      is_short = true;

   if(!is_long && !is_short)
      return false;

   const double entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);

   double sl = 0.0;
   double tp = bb_middle_now; // mean-reversion target = BB midline (SMA20)

   if(is_long)
     {
      sl = bb_lower_touch - buffer;
      // Reject too-wide bands: SL distance from entry must not exceed the cap.
      if(sl_cap > 0.0 && (entry - sl) > sl_cap)
         return false;
      if(sl >= entry)         // sanity: stop must sit below entry
         return false;
      if(tp <= entry)         // target must be above entry for a long
         return false;
      req.type = QM_BUY;
     }
   else // is_short
     {
      sl = bb_upper_touch + buffer;
      if(sl_cap > 0.0 && (sl - entry) > sl_cap)
         return false;
      if(sl <= entry)         // stop must sit above entry
         return false;
      if(tp >= entry)         // target must be below entry for a short
         return false;
      req.type = QM_SELL;
     }

   req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
   req.price  = 0.0; // framework fills market price at send
   req.reason = is_long ? "cutting_points_long" : "cutting_points_short";
   return true;
  }

// Fixed band-stop / midline-target only; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL (band extreme) and TP (BB middle).
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
