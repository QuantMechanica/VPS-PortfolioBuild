#property strict
#property version   "5.0"
#property description "QM5_11526 ciurea-rsi10-50-d1 — RSI(10) 50-midline cross momentum (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11526 ciurea-rsi10-50-d1
// -----------------------------------------------------------------------------
// Source: Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
//   ScientificForex.com ~2012. Card:
//   artifacts/cards_approved/QM5_11526_ciurea-rsi10-50-d1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; D1):
//   Trigger EVENT (the SINGLE trigger, one cross/bar):
//     LONG  : RSI(10) crosses ABOVE the midline -> RSI@2 <= level && RSI@1 > level
//     SHORT : RSI(10) crosses BELOW the midline -> RSI@2 >= level && RSI@1 < level
//   This treats RSI as a momentum-direction indicator (above 50 = recent
//   up-momentum), NOT an overbought/oversold oscillator.
//   Stop   : 3-bar D1 extreme +/- buffer pips beyond it.
//            LONG  SL = lowest(low, 3 bars from shift 1) - buffer
//            SHORT SL = highest(high, 3 bars from shift 1) + buffer
//   Stop cap: SL distance capped at strategy_sl_cap_pips (D1 extremes can be wide).
//   Take   : 2R (RR multiple) of the stop distance from entry.
//   Spread : skip only a genuinely wide spread (> strategy_spread_cap_pips);
//            fail-open on .DWX zero modeled spread.
//   No Friday entry: the framework Friday-close guard (qm_friday_close_*) plus an
//            explicit day-of-week block keep us out of fresh Friday entries.
//
// One position per magic. Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11526;
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
input int    strategy_rsi_period        = 10;     // RSI lookback (shorter than std 14)
input double strategy_rsi_cross_level   = 50.0;   // midline used as the momentum cross
input int    strategy_struct_lookback   = 3;      // bars for the 3-bar extreme stop
input int    strategy_sl_buffer_pips    = 3;      // buffer beyond the 3-bar extreme
input double strategy_tp_rr             = 2.0;    // take-profit = 2R of stop distance
input int    strategy_sl_cap_pips       = 150;    // max SL distance (D1 extremes can be wide)
input int    strategy_spread_cap_pips   = 30;     // skip only a genuinely wide spread
input bool   strategy_no_friday_entry   = true;   // no fresh entry on Fridays

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Handles the card's no-Friday-entry time filter
// and spread guard; regime/signal work is in Strategy_EntrySignal on the
// closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: RSI(10) crosses the midline (one cross only) ---
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   const bool crossed_up   = (rsi_prev <= strategy_rsi_cross_level &&
                              rsi_now  >  strategy_rsi_cross_level);
   const bool crossed_down = (rsi_prev >= strategy_rsi_cross_level &&
                              rsi_now  <  strategy_rsi_cross_level);
   if(!crossed_up && !crossed_down)
      return false;

   const QM_OrderType side = crossed_up ? QM_BUY : QM_SELL;

   // --- 3-bar D1 extreme stop (structure), with a buffer beyond the extreme ---
   // QM_StopStructure returns the raw extreme (lowest low / highest high) over
   // strategy_struct_lookback closed bars from shift 1. We add a buffer beyond it.
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double struct_stop = QM_StopStructure(_Symbol, side, entry, strategy_struct_lookback);
   if(struct_stop <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   // Push the stop further from entry by the buffer: below extreme for longs,
   // above extreme for shorts.
   double sl = (side == QM_BUY) ? (struct_stop - buffer)
                                : (struct_stop + buffer);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // Stop must be on the correct side of entry.
   if(side == QM_BUY  && !(sl < entry))
      return false;
   if(side == QM_SELL && !(sl > entry))
      return false;

   // --- SL distance cap (D1 3-bar extremes can be very wide) ---
   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(sl_cap > 0.0)
     {
      const double sl_dist = MathAbs(entry - sl);
      if(sl_dist > sl_cap)
        {
         // Clamp the stop to the cap distance, keeping it on the correct side.
         sl = (side == QM_BUY) ? (entry - sl_cap) : (entry + sl_cap);
         sl = QM_StopRulesNormalizePrice(_Symbol, sl);
         if(sl <= 0.0)
            return false;
        }
     }

   // --- Take profit: 2R of the (possibly capped) stop distance ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = crossed_up ? "rsi50_cross_long" : "rsi50_cross_short";
   return true;
  }

// Stop/target are fixed at entry (structure SL + 2R TP). No active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP.
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
