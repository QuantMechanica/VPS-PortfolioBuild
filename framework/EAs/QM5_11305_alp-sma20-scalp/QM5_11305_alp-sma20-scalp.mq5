#property strict
#property version   "5.0"
#property description "QM5_11305 alp-sma20-scalp — SMA20 cross-up minute scalper (long-only, M1)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11305 alp-sma20-scalp
// -----------------------------------------------------------------------------
// Source: alpacahq/example-scalping (README + main.py).
// Card: artifacts/cards_approved/QM5_11305_alp-sma20-scalp.md (g0_status APPROVED).
//
// Mechanics (long-only, M1, closed-bar reads at shift 1):
//   Trigger EVENT : close crosses ABOVE SMA(20). One event/bar:
//                   close[2] <= SMA20[2]  AND  close[1] > SMA20[1].
//                   (single cross — invariant #4, never two coincident events.)
//   Session STATE : trade only inside a broker-time session window. The source
//                   is a US-cash-session scalper; broker = DXZ NY-Close GMT+2/+3.
//                   Hours are configured per symbol in the setfile (broker time).
//   Stop          : catastrophic stop = MIN(sl_atr_mult * ATR(14),
//                   sl_max_adverse_pct% of entry), whichever is TIGHTER —
//                   exactly the card's "1.5*ATR or 0.35% adverse, tighter".
//   Take profit   : tight scalp target = tp_pips (scale-correct via pip factor).
//                   This realises the source's "immediate limit exit just above
//                   entry" inside the framework single-position market model.
//   Session flatten: force-close any open position at/after the broker-time
//                   session-end-flatten hour (the source's 15:55 NY flatten).
//   Spread guard  : skip only a genuinely wide spread (> spread_pct_of_stop of
//                   the stop distance). Fail-OPEN on .DWX zero modeled spread.
//
// .DWX invariants honoured: fail-open spread (#1), no swap gate (#2), single
// QM_IsNewBar consume (#3), single cross event (#4), broker-time session in
// broker hours (#5/#13), no external macro CSV (#11), pip-scaled SL/TP (#14).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11305;
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
input int    strategy_sma_period         = 20;     // SMA period (close) for the cross
input int    strategy_session_start_hour = 9;      // broker-time session OPEN hour (inclusive)
input int    strategy_session_end_hour   = 22;     // broker-time session CLOSE hour (exclusive)
input int    strategy_flatten_hour_broker = 21;    // broker-time hour to force-flatten (>= => flat)
input int    strategy_flatten_min_broker  = 55;    // broker-time minute within flatten hour
input int    strategy_atr_period         = 14;     // ATR period for the catastrophic stop
input double strategy_sl_atr_mult        = 1.5;    // stop = mult * ATR ...
input double strategy_sl_max_adverse_pct = 0.35;   // ... or this % of entry, whichever TIGHTER
input double strategy_tp_pips            = 8.0;     // tight scalp take-profit, in pips
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/session work is on the
// closed-bar path. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing quote

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Catastrophic stop distance (price units): the TIGHTER of sl_atr_mult*ATR and
// sl_max_adverse_pct% of the entry price — exactly the card's rule.
double SmaScalp_StopDistance(const double entry_price, const double atr_value)
  {
   const double atr_dist = strategy_sl_atr_mult * atr_value;
   const double pct_dist  = (strategy_sl_max_adverse_pct / 100.0) * entry_price;
   if(atr_dist <= 0.0)
      return pct_dist;
   if(pct_dist <= 0.0)
      return atr_dist;
   return (atr_dist < pct_dist) ? atr_dist : pct_dist;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Session STATE: trade only inside the broker-time session window. ---
   // TimeCurrent() in the tester is broker time; QM_Sig_Session is wrap-safe.
   if(QM_Sig_Session(TimeCurrent(), strategy_session_start_hour, strategy_session_end_hour) != 1)
      return false;

   // --- Trigger EVENT: close crosses ABOVE SMA(20). One event per bar. ---
   const double sma_now  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma_prev = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   if(sma_now <= 0.0 || sma_prev <= 0.0)
      return false;

   const double close_now  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;

   const bool crossed_up = (close_prev <= sma_prev && close_now > sma_now);
   if(!crossed_up)
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double stop_distance = SmaScalp_StopDistance(entry, atr_value);
   if(stop_distance <= 0.0)
      return false;

   double sl = entry - stop_distance;
   sl = QM_TM_NormalizePrice(_Symbol, sl);

   // Tight scalp TP in pips (scale-correct on 5-digit / JPY / index symbols).
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_tp_pips));
   if(tp_dist <= 0.0)
      return false;
   double tp = QM_TM_NormalizePrice(_Symbol, entry + tp_dist);

   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "sma20_cross_scalp_long";
   return true;
  }

// No active trade management beyond the fixed scalp TP and catastrophic stop.
void Strategy_ManageOpenPosition()
  {
  }

// Session-end flatten: close the open position at/after the broker-time flatten
// time (the source's 15:55 NY end-of-day liquidation, ported to broker time).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t); // broker time in the tester
   const int now_minutes     = t.hour * 60 + t.min;
   const int flatten_minutes = strategy_flatten_hour_broker * 60 + strategy_flatten_min_broker;

   // Flat from the flatten time until end of the session day.
   if(now_minutes >= flatten_minutes)
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
