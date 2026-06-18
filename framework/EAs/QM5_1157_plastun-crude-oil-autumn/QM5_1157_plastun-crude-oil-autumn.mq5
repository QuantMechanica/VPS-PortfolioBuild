#property strict
#property version   "5.0"
#property description "QM5_1157 plastun-crude-oil-autumn — WTI autumn seasonality (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1157 plastun-crude-oil-autumn
// -----------------------------------------------------------------------------
// Source: SSRN 3611068 — Plastun, Sibande, Gupta, Wohar (2020), "Calendar
// Anomalies in Crude Oil Futures Markets: New Evidence", Energy Economics.
// Card: artifacts/cards_approved/QM5_1157_plastun-crude-oil-autumn.md (APPROVED).
//
// Edge: WTI crude shows a robust autumn-strength anomaly — September and October
// average daily returns are statistically positive vs the rest of the year.
//
// Mechanics (long-only, D1-native, closed-bar reads at shift 1):
//   Universe   : XTIUSD.DWX (WTI crude CFD on DXZ; card "OIL"/WTI ported to the
//                only available DWX energy symbol — verified in
//                framework/registry/dwx_symbol_matrix.csv, commodities/energies).
//   Entry EVENT: first DXZ trading session of September each year, go LONG.
//                Detected by a broker-time month roll Aug(8) -> Sep(9): the
//                current closed bar is in month 9 and the prior closed bar was
//                in month 8 (one event per year, never the same bar as exit).
//   Exit EVENT : last DXZ trading session of October = first session of
//                November. Detected by a broker-time month roll Oct(10) ->
//                Nov(11): close any open position at the first November session.
//                Flat the remaining ~210 trading days of the year.
//   Stop       : entry - sl_atr_mult * ATR(D1, atr_period) hard stop on fill.
//   Trailing   : once the position is >= trail_trigger_rr in open profit
//                (measured in R against the initial ATR stop distance), ratchet
//                the stop with QM_TM_TrailATR(trail_atr_mult). The framework
//                trail only ever tightens the stop, never loosens it.
//   Warmup gate: require >= min_history_bars D1 bars (card: >=252) so the first
//                cycle has at least one prior year of context.
//
// Broker time: DXZ = NY-Close GMT+2 / GMT+3 during US DST. Month/day calendar
// logic is computed on broker-local bar-open time (TimeToStruct on the closed
// bar open time), which is the natural DXZ session calendar — no UTC conversion
// is needed for a calendar-month gate because the month boundary is identical
// in broker-local time. QM_BrokerToUTC is available if intraday session edges
// are ever needed; not required for this D1 month-roll rule.
//
// News: the EIA-inventory / FOMC / OPEC "defer entry if event within 24h" rule
// from the card maps to the framework's central two-axis news filter (see OnTick
// wiring). No external macro CSV feed is used — all signal logic is computed
// in-EA from XTIUSD.DWX D1 bars only.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1157;
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
input bool   qm_friday_close_enabled    = false;     // seasonal hold spans weekends; no Fri-close
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_month       = 9;     // open long on first session of this month (Sep)
input int    strategy_exit_month        = 11;    // close on first session of this month (Nov) = last Oct session
input int    strategy_atr_period        = 14;    // ATR period for the stop / trail
input double strategy_sl_atr_mult       = 3.0;   // hard stop distance = mult * ATR on entry
input double strategy_trail_trigger_rr  = 1.5;   // start trailing once open profit >= this many R
input double strategy_trail_atr_mult    = 2.0;   // trailing stop distance = mult * ATR
input int    strategy_min_history_bars  = 252;   // require >= this many D1 bars before first entry

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Returns the broker-local calendar month (1..12) of the closed bar at `shift`.
// Bar-open time on a DXZ D1 chart is already broker-local; a calendar-month
// gate is invariant under the GMT+2/+3 offset, so no UTC conversion is needed.
int CalendarMonth(const int shift)
  {
   const datetime bar_time = iTime(_Symbol, _Period, shift); // perf-allowed: single closed-bar time read
   if(bar_time <= 0)
      return -1;
   MqlDateTime mdt;
   TimeToStruct(bar_time, mdt);
   return mdt.mon;
  }

// Cheap O(1) per-tick gate. No spread guard needed for a once-a-year D1 calendar
// hold; never fail-closed on .DWX zero modeled spread. Always allow.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Long-only seasonal entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Warmup: need at least one prior cycle of D1 context (card: >= 252 bars).
   if(Bars(_Symbol, _Period) < strategy_min_history_bars) // perf-allowed: bar-count guard
      return false;

   // --- Entry EVENT: first session of the entry month (month roll Aug->Sep). ---
   // Current closed bar in entry_month, prior closed bar in the month before it.
   const int month_now  = CalendarMonth(1);
   const int month_prev = CalendarMonth(2);
   if(month_now < 0 || month_prev < 0)
      return false;
   const int month_before_entry = (strategy_entry_month == 1) ? 12 : (strategy_entry_month - 1);
   const bool first_session_of_entry_month =
      (month_now == strategy_entry_month && month_prev == month_before_entry);
   if(!first_session_of_entry_month)
      return false;

   // --- Volatility-scaled hard stop from ATR (same ATR value seeds the stop). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; exit is the calendar window / trailing stop
   req.reason = "autumn_seasonal_long";
   return true;
  }

// Trailing stop: once the open long is >= trail_trigger_rr in profit (R measured
// against the initial ATR stop distance), ratchet the stop with the framework
// ATR trail. The trail only ever tightens, locking autumn-strength gains.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double init_sl    = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || init_sl <= 0.0 || init_sl >= open_price)
         continue;

      const double r_distance = open_price - init_sl;            // initial risk per unit
      if(r_distance <= 0.0)
         continue;
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         continue;

      const double open_r = (bid - open_price) / r_distance;     // current profit in R
      if(open_r >= strategy_trail_trigger_rr)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Exit EVENT: first session of the exit month (month roll Oct->Nov) — closes
// the position at the end of the autumn window. One event per year.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int month_now  = CalendarMonth(1);
   const int month_prev = CalendarMonth(2);
   if(month_now < 0 || month_prev < 0)
      return false;
   const int month_before_exit = (strategy_exit_month == 1) ? 12 : (strategy_exit_month - 1);

   // Close on the first session of the exit month (last Oct session handed off).
   if(month_now == strategy_exit_month && month_prev == month_before_exit)
      return true;

   // Safety: also flat if we somehow hold outside the [entry_month, exit_month)
   // window (e.g. a gap that skipped the roll bar) — never carry past the season.
   const bool inside_window = (month_now >= strategy_entry_month &&
                               month_now <  strategy_exit_month);
   if(!inside_window)
      return true;

   return false;
  }

// Defer to the central two-axis news filter (EIA / FOMC / OPEC blackout).
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
