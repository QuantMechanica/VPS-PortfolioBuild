#property strict
#property version   "5.0"
#property description "QM5_11454 davey-session-open-bracket-breakout — Session-open opening-range bracket breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11454 davey-session-open-bracket-breakout
// -----------------------------------------------------------------------------
// Source: Kevin J. Davey, "My 5 Favorite Entries" (Entry #2 — opening-range
// bracket breakout). Card: artifacts/cards_approved/
// QM5_11454_davey-session-open-bracket-breakout.md (g0_status APPROVED).
//
// MECHANICS (H1, all reads on CLOSED bars at shift >= 1):
//   Session open : a fixed UTC session-open hour (default 08:00 GMT London),
//                  converted to BROKER time per bar via QM_BrokerToUTC. The
//                  "opening bar" is the FIRST CLOSED H1 bar whose bar-open
//                  timestamp (UTC, derived from the broker bar time) equals
//                  the session-open hour on the current calendar day.
//   Bracket      : high/low of that single CLOSED opening bar. Captured once
//                  per day from the prior closed bar — never from a forming bar.
//   Filter       : skip the day if (bracket_high - bracket_low) > max_pips.
//   Single EVENT : on each subsequent CLOSED H1 bar of the same trading day,
//                  a breakout is confirmed by the bar CLOSE (not an intrabar
//                  stop touch — .DWX index/FX CFDs are gapless so a
//                  close-confirmed breakout is the faithful, fillable form of
//                  Davey's stop-entry on this data). The FIRST side to close
//                  beyond its bracket level fires; one-position-per-magic makes
//                  this the OCO winner (the opposite side is moot thereafter).
//       LONG  : close > bracket_high + offset_pips
//       SHORT : close < bracket_low  - offset_pips
//   Stop         : opposite bracket level (+/- offset). If the bracket breaks
//                  back through after a fill, the framework SL exits.
//   Target       : entry +/- ATR(D1, atr_period)[shift 1] * tp_atr_mult.
//   Time stop    : flatten any open position at/after the session-close hour
//                  (broker time, DST-aware) — Davey's EOD exit.
//   Spread guard : fail-OPEN — block only a genuinely wide spread on a real
//                  (ask>bid) quote; .DWX models 0 spread so this never blocks.
//
// Only the 5 Strategy_* hooks + Strategy inputs + the small per-day bracket
// cache are EA-specific. Everything else is framework wiring and MUST stay
// intact. No external feed; broker-time sessions only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11454;
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
// Session open expressed in UTC/GMT hour. Default 8 = London open (08:00 GMT).
// NY open = 13 (13:30 GMT rounds to the 13:00 H1 bar). Per-symbol via setfile.
input int    strategy_session_open_utc_hour  = 8;
// Session close expressed in UTC/GMT hour for the EOD time stop. Default 21 =
// 21:00 GMT (= 17:00 ET, Davey's EOD). Converted to broker time DST-aware.
input int    strategy_session_close_utc_hour = 21;
// Breakout / stop offset beyond the bracket edge, in pips (Davey "1 tick").
input int    strategy_offset_pips            = 1;
// Bracket-width filter: skip the day if the opening bar is wider than this.
input int    strategy_max_bracket_pips       = 60;
// Target = entry +/- ATR(D1, period)[1] * mult. Davey daily-ATR context.
input int    strategy_atr_period             = 14;
input double strategy_tp_atr_mult            = 1.5;
// Spread guard: block only if spread exceeds this % of the stop distance.
input double strategy_spread_pct_of_stop     = 20.0;

// -----------------------------------------------------------------------------
// Per-day bracket cache (advanced once per new CLOSED H1 bar). This is strategy
// state, NOT a new-bar reimplementation: the framework QM_IsNewBar() gate drives
// AdvanceBracket_OnNewBar(); we never maintain our own timestamp gate for the
// entry cadence.
// -----------------------------------------------------------------------------
int      g_bracket_day        = -1;     // UTC day-of-year the bracket belongs to
bool     g_bracket_valid      = false;  // opening bar captured this day
bool     g_bracket_skipped    = false;  // bracket too wide -> skip the day
double   g_bracket_high       = 0.0;
double   g_bracket_low        = 0.0;

// UTC calendar-day key (year*1000 + day-of-year) so day rollover is unambiguous.
int UtcDayKey(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int UtcHour(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.hour;
  }

// Called ONCE per new CLOSED H1 bar (after OnTick passes QM_IsNewBar()).
// Detects the session-open opening bar from the bar TIMESTAMP in broker time
// (converted to UTC) and latches the bracket from that single closed bar.
void AdvanceBracket_OnNewBar()
  {
   // Bar-open broker timestamp of the just-closed bar (shift 1). perf-allowed:
   // bespoke session-timing structural read, single closed-bar shift.
   const datetime bar_open_broker = iTime(_Symbol, PERIOD_H1, 1);
   if(bar_open_broker <= 0)
      return;

   const datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   const int day_key = UtcDayKey(bar_open_utc);

   // New UTC day -> reset the bracket state.
   if(day_key != g_bracket_day)
     {
      g_bracket_day     = day_key;
      g_bracket_valid   = false;
      g_bracket_skipped = false;
      g_bracket_high    = 0.0;
      g_bracket_low     = 0.0;
     }

   // Already have (or skipped) today's bracket — nothing more to latch.
   if(g_bracket_valid || g_bracket_skipped)
      return;

   // Is THIS closed bar the session-open opening bar?
   if(UtcHour(bar_open_utc) != strategy_session_open_utc_hour)
      return;

   const double hi = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: opening-bar range
   const double lo = iLow(_Symbol, PERIOD_H1, 1);  // perf-allowed: opening-bar range
   if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return;

   const double width   = hi - lo;
   const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_bracket_pips);
   if(max_dist > 0.0 && width > max_dist)
     {
      // Too wide -> no edge; skip the rest of the day.
      g_bracket_skipped = true;
      return;
     }

   g_bracket_high  = hi;
   g_bracket_low   = lo;
   g_bracket_valid = true;
  }

// Is the current broker time at/after the session-close hour for the EOD stop?
bool IsAtOrAfterSessionClose(const datetime broker_now)
  {
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   return (UtcHour(utc_now) >= strategy_session_close_utc_hour);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — never block on it

   // Stop distance reference = current bracket width (opposite-edge stop). Use a
   // pip floor if no bracket is latched yet, so the cap still scales correctly.
   double stop_distance = 0.0;
   if(g_bracket_valid && g_bracket_high > g_bracket_low)
      stop_distance = g_bracket_high - g_bracket_low;
   if(stop_distance <= 0.0)
      stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_bracket_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread on a real ask>bid quote blocks. Zero/negative
   // modeled spread (.DWX) passes through — fail-OPEN.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Opening-range bracket breakout. Caller guarantees QM_IsNewBar() == true, so
// this is evaluated once per CLOSED H1 bar. The close-confirmed breakout is the
// single OCO event; one-position-per-magic enforces the OCO.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (OCO winner already live -> no re-entry).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Need a valid, non-skipped bracket for the current day.
   if(!g_bracket_valid)
      return false;

   // Do not arm new entries once we are in the EOD time-stop window.
   if(IsAtOrAfterSessionClose(iTime(_Symbol, PERIOD_H1, 0)))
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   const double long_trigger  = g_bracket_high + offset;
   const double short_trigger = g_bracket_low  - offset;

   // Breakout confirmed by the just-closed bar's CLOSE (shift 1). perf-allowed:
   // bespoke breakout structural read, single closed-bar shift.
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // LONG breakout: close above the upper bracket edge.
   if(close1 > long_trigger)
     {
      const double entry_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_ask <= 0.0)
         return false;
      // Stop = opposite (lower) bracket edge, minus the offset.
      const double sl = QM_StopRulesNormalizePrice(_Symbol, short_trigger);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry_ask, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || !(sl < entry_ask))
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "davey_bracket_long";
      return true;
     }

   // SHORT breakout: close below the lower bracket edge.
   if(close1 < short_trigger)
     {
      const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_bid <= 0.0)
         return false;
      // Stop = opposite (upper) bracket edge, plus the offset.
      const double sl = QM_StopRulesNormalizePrice(_Symbol, long_trigger);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry_bid, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || !(sl > entry_bid))
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "davey_bracket_short";
      return true;
     }

   return false;
  }

// No active trade management — the bracket SL / ATR TP / EOD time stop define
// the trade. (EOD flatten is handled in Strategy_ExitSignal.)
void Strategy_ManageOpenPosition()
  {
  }

// EOD time stop: flatten any open position at/after the session-close hour
// (broker time, DST-aware) — Davey's end-of-day exit.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   return IsAtOrAfterSessionClose(TimeCurrent());
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

   // Per-tick: trade management (no-op here; bracket SL/TP + EOD stop drive it).
   Strategy_ManageOpenPosition();

   // Per-tick: EOD time-stop exit (checked every tick so the flatten is prompt).
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

   // Per-closed-bar: advance the bracket cache, then evaluate the breakout.
   if(!QM_IsNewBar())
      return;

   AdvanceBracket_OnNewBar();

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
