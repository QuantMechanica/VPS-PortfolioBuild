#property strict
#property version   "5.0"
#property description "QM5_11394 paul-langer-m5-bb20-scalper — BB(20,2) pierce + re-entry pending-stop scalper (M5)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11394 paul-langer-m5-bb20-scalper
// -----------------------------------------------------------------------------
// Source: Paul Langer, "The Black Book of Forex Trading" (Alura Publishing, 2015)
//         — Scalping Strategy. Card:
//         artifacts/cards_approved/QM5_11394_paul-langer-m5-bb20-scalper.md
//         (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; single EVENT = re-entry candle):
//   Session  STATE : trade only during London + NY windows, broker-time gated
//                    via the card's UTC hours converted with QM_BrokerToUTC.
//   SHORT setup    : close[1] > BB_upper[1]  (prior close pierced upper band)
//                    AND close[1] < BB_upper[1's-bar BB on the SAME bar)... no:
//                    The single re-entry EVENT is read on the just-closed bar
//                    (shift 1): prior bar (shift 2) closed ABOVE the band and
//                    the just-closed bar (shift 1) closed back INSIDE.
//                    -> place SELL STOP at Low[1] - 5pips, SL High[1] + 5pips.
//   LONG setup     : prior bar (shift 2) closed BELOW the lower band and the
//                    just-closed bar (shift 1) closed back INSIDE.
//                    -> place BUY STOP at High[1] + 5pips, SL Low[1] - 5pips.
//   Pending entry  : a STOP order placed on the new bar's open beyond the
//                    re-entry (signal) candle's extreme; valid for ONE bar
//                    (expiration = one M5 period). Stale pendings from the prior
//                    bar are removed at the top of each new-bar evaluation.
//   Take profit    : fixed tp_pips (20) from the pending entry price.
//   Stop loss      : signal-candle opposite extreme +/- sl_buffer_pips (5),
//                    capped at sl_max_pips (25).
//   Break-even     : move SL to entry once +be_trigger_pips (10) in profit.
//
// .DWX invariants honoured: spread guard fails OPEN on zero modeled spread; no
// swap gate; sessions in broker time via QM_BrokerToUTC; gapless-CFD safe (uses
// prior CLOSE-vs-band, not a range/gap rule); no external-macro CSV.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11394;
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
input int    strategy_bb_period          = 20;    // Bollinger Band period
input double strategy_bb_deviation       = 2.0;   // Bollinger Band std-dev multiplier
input int    strategy_tp_pips            = 20;    // fixed take-profit (pips)
input int    strategy_sl_buffer_pips     = 5;     // SL/entry buffer beyond signal candle (pips)
input int    strategy_sl_max_pips        = 25;    // P2 cap on stop distance (pips)
input int    strategy_be_trigger_pips    = 10;    // move SL to break-even at +this (pips)
// Session windows in UTC hours (card: London open 08-12 GMT, NY open 13-17 GMT).
// Converted to broker time per-bar via QM_BrokerToUTC so DST is handled centrally.
input int    strategy_london_start_utc   = 8;     // London window start hour (UTC, inclusive)
input int    strategy_london_end_utc     = 12;    // London window end hour   (UTC, exclusive)
input int    strategy_ny_start_utc       = 13;    // NY window start hour      (UTC, inclusive)
input int    strategy_ny_end_utc         = 17;    // NY window end hour        (UTC, exclusive)
input double strategy_spread_cap_pips     = 15.0; // skip a genuinely wide spread > this (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// True if the current bar's broker time falls inside the London OR NY UTC window.
bool QM_InSession(const datetime broker_now)
  {
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   if(QM_Sig_Session(utc_now, strategy_london_start_utc, strategy_london_end_utc) == 1)
      return true;
   if(QM_Sig_Session(utc_now, strategy_ny_start_utc, strategy_ny_end_utc) == 1)
      return true;
   return false;
  }

// Remove any leftover pending STOP order owned by this EA's magic (the prior
// bar's un-triggered re-entry order). Closed-bar gated by the caller.
void QM_RemoveStalePendings()
  {
   const long magic = (long)QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, "expire_prior_bar_reentry");
     }
  }

// Cheap O(1) per-tick gate. Spread guard only — session/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Re-entry pending-stop entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Clear any stale pending order from the previous bar (one-bar validity).
   QM_RemoveStalePendings();

   // One position per magic; do not stack a pending while a position is open.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Session gate (broker-time bar → UTC window).
   if(!QM_InSession(iTime(_Symbol, _Period, 0)))
      return false;

   // Bollinger bands on the prior bar (shift 2) and the just-closed bar (shift 1).
   const double up_prev  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double up_now   = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lo_prev  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double lo_now   = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(up_prev <= 0.0 || up_now <= 0.0 || lo_prev <= 0.0 || lo_now <= 0.0)
      return false;

   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double close_sig  = iClose(_Symbol, _Period, 1); // re-entry (signal) candle close
   const double high_sig   = iHigh(_Symbol, _Period, 1);  // perf-allowed: signal candle extreme
   const double low_sig    = iLow(_Symbol, _Period, 1);   // perf-allowed: signal candle extreme
   if(close_prev <= 0.0 || close_sig <= 0.0 || high_sig <= 0.0 || low_sig <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(buffer <= 0.0 || tp_dist <= 0.0 || sl_cap <= 0.0)
      return false;

   // --- SHORT: prior bar pierced ABOVE upper band, signal bar re-entered. ---
   const bool short_setup = (close_prev > up_prev) && (close_sig < up_now);
   // --- LONG : prior bar pierced BELOW lower band, signal bar re-entered. ---
   const bool long_setup  = (close_prev < lo_prev) && (close_sig > lo_now);

   if(short_setup && !long_setup)
     {
      double entry = low_sig - buffer;          // SELL STOP below signal Low
      double sl    = high_sig + buffer;         // SL above signal High
      // Cap the stop distance at sl_max_pips (measured from the pending entry).
      if((sl - entry) > sl_cap)
         sl = entry + sl_cap;
      const double tp = entry - tp_dist;        // fixed 20-pip target
      if(sl <= entry || tp >= entry)
         return false;

      req.type               = QM_SELL_STOP;
      req.price              = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl                 = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp                 = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason             = "bb20_reentry_sellstop";
      req.expiration_seconds = PeriodSeconds(_Period); // one-bar validity
      return true;
     }

   if(long_setup && !short_setup)
     {
      double entry = high_sig + buffer;         // BUY STOP above signal High
      double sl    = low_sig - buffer;          // SL below signal Low
      if((entry - sl) > sl_cap)
         sl = entry - sl_cap;
      const double tp = entry + tp_dist;        // fixed 20-pip target
      if(sl >= entry || tp <= entry)
         return false;

      req.type               = QM_BUY_STOP;
      req.price              = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl                 = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp                 = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason             = "bb20_reentry_buystop";
      req.expiration_seconds = PeriodSeconds(_Period); // one-bar validity
      return true;
     }

   return false;
  }

// Break-even management on the open position once +be_trigger_pips in profit.
void Strategy_ManageOpenPosition()
  {
   if(strategy_be_trigger_pips <= 0)
      return;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, 0);
     }
  }

// Fixed-TP / fixed-SL scalp — no discretionary close beyond SL/TP and BE.
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
