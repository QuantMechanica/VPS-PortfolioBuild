#property strict
#property version   "5.0"
#property description "QM5_11352 rbt-bb-rsi11-breakout-m15 — BB(20,2) + RSI(11) momentum breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11352 rbt-bb-rsi11-breakout-m15
// -----------------------------------------------------------------------------
// Source: RoboForex "Strategy Bollinger Bands and RSI" (M15).
// Card: artifacts/cards_approved/QM5_11352_rbt-bb-rsi11-breakout-m15.md (APPROVED).
//
// Mechanics (momentum CONTINUATION, NOT reversal; closed-bar reads at shift 1):
//   LONG:
//     EVENT  : close crosses ABOVE BB(period,dev) upper band — i.e. the prior
//              closed bar (shift 2) was at/below the upper band and the trigger
//              closed bar (shift 1) is above it. ONE fresh breakout event/bar.
//     STATE  : RSI(11) at shift 1 is above rsi_long_level (momentum strong).
//     STATE  : ADX(period) > adx_min (trending, not ranging).
//   SHORT  : mirror — close crosses BELOW BB lower band (EVENT),
//            RSI(11) < rsi_short_level (STATE), ADX > adx_min (STATE).
//   Stop   : fixed sl_pips from entry (scale-correct via QM_StopFixedPips).
//   Target : RR multiple = tp_pips / sl_pips on the same stop distance.
//   Exit   : RSI(11) faded back through 50 (long: RSI<exit_level;
//            short: RSI>exit_level) — momentum gone.
//   Filters: London+NY session window in UTC (card 13:00-22:00 GMT); spread cap
//            in pips that FAILS OPEN on .DWX zero modeled spread.
//
// .DWX invariants honoured:
//   * Spread guard only blocks a genuinely wide spread (zero spread passes).
//   * No swap gating.
//   * QM_IsNewBar consumed ONCE by the framework before entry; exit/manage read
//     no new-bar event.
//   * Breakout uses prior CLOSED bars (shift 2 -> shift 1), NOT the live range.
//   * Single EVENT (BB cross on close) + STATES (RSI level, ADX, session) — two
//     simultaneous cross EVENTS never required.
//   * Session window converted from broker time to UTC via QM_BrokerToUTC.
//   * Pips->price via QM_StopFixedPips / QM_TakeRR (scale-correct on 5-digit/JPY).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11352;
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
input int    strategy_bb_period          = 20;     // Bollinger Bands period
input double strategy_bb_deviation       = 2.0;    // Bollinger Bands deviation (MANDATORY arg)
input int    strategy_rsi_period         = 11;     // RSI period
input double strategy_rsi_long_level     = 70.0;   // RSI must be above this for a LONG breakout
input double strategy_rsi_short_level    = 30.0;   // RSI must be below this for a SHORT breakout
input double strategy_rsi_exit_level     = 50.0;   // RSI fade-to-50 exit threshold
input int    strategy_adx_period         = 14;     // ADX period (trend-vs-range filter)
input double strategy_adx_min            = 20.0;   // require ADX above this (trending)
input int    strategy_sl_pips            = 15;     // fixed stop distance, in pips
input int    strategy_tp_pips            = 20;     // fixed take-profit distance, in pips
input double strategy_spread_cap_pips    = 5.0;    // skip only if spread exceeds this many pips
input int    strategy_session_start_utc  = 13;     // London+NY window start hour, UTC (inclusive)
input int    strategy_session_end_utc    = 22;     // London+NY window end hour, UTC (exclusive)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Pip size for the current symbol (5-digit / 3-digit JPY aware): one pip = 10
// points on 3/5-digit quotes, 1 point on 2/4-digit.
double QM5_11352_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Session window (UTC) + spread cap only. Signal work
// is on the closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX spread.
bool Strategy_NoTradeFilter()
  {
   // --- Session filter: card window 13:00-22:00 GMT (London + NY). Convert the
   //     current broker time to UTC and gate on the UTC hour (DST-robust). ---
   const datetime broker_now = TimeCurrent();
   const datetime utc_now     = QM_BrokerToUTC(broker_now);
   MqlDateTime t;
   TimeToStruct(utc_now, t);
   const int h = t.hour;
   if(strategy_session_start_utc <= strategy_session_end_utc)
     {
      if(h < strategy_session_start_utc || h >= strategy_session_end_utc)
         return true; // outside the session window — block
     }
   else
     {
      // wrap-around window (not used by default, but kept safe)
      if(h < strategy_session_start_utc && h >= strategy_session_end_utc)
         return true;
     }

   // --- Spread cap (fail-OPEN on .DWX zero modeled spread) ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block
   const double spread = ask - bid;
   const double cap    = strategy_spread_cap_pips * QM5_11352_PipSize();
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true; // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: ADX above the floor (filters ranging chop) ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(adx <= strategy_adx_min)
      return false;

   // --- Closed-bar reads: trigger bar = shift 1, prior bar = shift 2 ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double bb_up_1  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_up_2  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_lo_1  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lo_2  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(bb_up_1 <= 0.0 || bb_up_2 <= 0.0 || bb_lo_1 <= 0.0 || bb_lo_2 <= 0.0)
      return false;

   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   // --- LONG: close crosses ABOVE upper band (EVENT) + RSI strong (STATE) ---
   const bool long_break = (close2 <= bb_up_2 && close1 > bb_up_1);
   if(long_break && rsi1 > strategy_rsi_long_level)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      const double rr = (strategy_sl_pips > 0) ? ((double)strategy_tp_pips / (double)strategy_sl_pips) : 1.0;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb_rsi11_break_long";
      return true;
     }

   // --- SHORT: close crosses BELOW lower band (EVENT) + RSI weak (STATE) ---
   const bool short_break = (close2 >= bb_lo_2 && close1 < bb_lo_1);
   if(short_break && rsi1 < strategy_rsi_short_level)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      const double rr = (strategy_sl_pips > 0) ? ((double)strategy_tp_pips / (double)strategy_sl_pips) : 1.0;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb_rsi11_break_short";
      return true;
     }

   return false;
  }

// Fixed-stop / fixed-target strategy — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Momentum-fade exit: RSI(11) returns through the exit level (50). For a long,
// RSI falling below the exit level means momentum has faded; for a short, RSI
// rising above it. Reads the last closed bar (shift 1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   // Determine current direction from the open position.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && rsi1 < strategy_rsi_exit_level)
      return true;
   if(have_short && rsi1 > strategy_rsi_exit_level)
      return true;
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
