#property strict
#property version   "5.0"
#property description "QM5_11137 bt-btfd-hold — Backtrader BTFD fixed-hold (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11137 bt-btfd-hold
// -----------------------------------------------------------------------------
// Source: Daniel Rodriguez / backtrader, BTFD sample,
//   https://github.com/mementum/backtrader/blob/master/samples/btfd/btfd.py
// Card: artifacts/cards_approved/QM5_11137_bt-btfd-hold.md (g0_status APPROVED).
//
// Mechanics (long-only, D1, closed-bar reads at shift 1):
//   Entry  EVENT : percent-down measure (P2 default `highlow`) on the LAST
//                  closed bar = low[1]/high[1] - 1 <= -fall_pct (default -1.0%).
//                  One open position per symbol/magic.
//   Exit   RULE  : fixed time stop — exit exactly hold_bars (default 2) CLOSED
//                  D1 bars after the entry bar. No profit target in the source
//                  baseline; the framework still carries the emergency stop.
//   Stop   (safety): emergency stop = max(stop_atr_mult * ATR(14),
//                  stop_min_adverse_pct of entry), whichever is WIDER after
//                  symbol normalization. Source is silent on a stop; this is the
//                  P2 default protective floor only — the time stop is primary.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  emergency-stop distance (fail-OPEN on .DWX zero modeled spread).
//
// .DWX invariants honoured: gapless CFD percent-down uses the prior CLOSED bar's
// own low/high (no gap/range rule); spread guard fails open on zero spread; no
// swap gate; no session window (D1); no external-macro CSV. The fixed 2-bar hold
// is counted in CLOSED bars via the entry position's open time.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11137;
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
input double strategy_fall_pct          = 1.0;    // dip trigger: low/high-1 <= -fall_pct% (P2 default 1.0)
input int    strategy_hold_bars         = 2;      // exit exactly N closed bars after entry (source default 2)
input int    strategy_atr_period        = 14;     // ATR period for the emergency stop
input double strategy_stop_atr_mult     = 2.5;    // emergency stop = mult * ATR
input double strategy_stop_min_adverse_pct = 2.0; // emergency stop floor = % adverse move of entry
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of emergency-stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Emergency-stop distance (price units): WIDER of ATR-based and %-adverse floors.
double BtfdStopDistance(const double atr_value, const double entry_price)
  {
   const double atr_dist     = strategy_stop_atr_mult * atr_value;
   const double pct_dist      = (strategy_stop_min_adverse_pct / 100.0) * entry_price;
   return (atr_dist > pct_dist) ? atr_dist : pct_dist;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — entry work is on the closed-bar
// path. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = BtfdStopDistance(atr_value, ask);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only BTFD dip entry. Caller guarantees QM_IsNewBar() == true (closed-bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry EVENT: `highlow` percent-down on the LAST CLOSED bar ---
   // low[1]/high[1] - 1 <= -fall_pct%. Uses the prior closed bar's own
   // low/high (gapless-safe; no gap or cross-bar range rule).
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double pct_down = (low1 / high1 - 1.0) * 100.0; // negative number
   if(pct_down > -strategy_fall_pct)
      return false; // not a deep enough dip

   // --- Emergency protective stop (time stop is the primary exit) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double stop_distance = BtfdStopDistance(atr_value, entry);
   if(stop_distance <= 0.0)
      return false;

   const double sl = QM_TM_NormalizePrice(_Symbol, entry - stop_distance);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no profit target — time stop closes the trade
   req.reason = "btfd_dip_long";
   return true;
  }

// No active trade management beyond the fixed emergency stop. The fixed N-bar
// time stop lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Fixed-hold time stop: close exactly strategy_hold_bars CLOSED bars after the
// entry bar. Counts closed D1 bars between the position's open time and the most
// recently CLOSED bar (shift 1). entry bar = shift containing POSITION_TIME.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      // Shift of the bar that contained the entry (its open <= open_time).
      const int entry_shift  = iBarShift(_Symbol, _Period, open_time, false);
      // Closed bars elapsed since the entry bar (shift 1 = last closed bar).
      const int bars_elapsed = entry_shift - 1;
      if(bars_elapsed >= strategy_hold_bars)
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
