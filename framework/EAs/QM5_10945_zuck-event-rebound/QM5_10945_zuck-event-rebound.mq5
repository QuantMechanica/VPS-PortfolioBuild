#property strict
#property version   "5.0"
#property description "QM5_10945 Zuckerman Event Rebound — pre-event adverse-move buy, time-stop exit"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10945 — Zuckerman Event Rebound (M5)
// -----------------------------------------------------------------------------
// Source: Gregory Zuckerman, "The Man Who Solved the Market" (2019). Medallion
// short-term desk observed some instruments falling BEFORE certain scheduled
// macro releases and rising right AFTER — model bought before the release and
// sold almost immediately after. Did NOT hold for employment statistics.
//
// Mechanic (price-action AROUND a framework-news-calendar event window — this is
// the explicitly-permitted realization; the EA needs NO external/event feed
// beyond the framework high-impact news calendar):
//   * Locate the next relevant high-impact calendar event (symbol-currency match).
//   * On the closed M5 bar nearest to `event - entry_minutes_before`, measure the
//     pre-event return over `pre_event_minutes` from prior CLOSES (gapless CFD —
//     never gaps, never prior-range; see .DWX invariant #6).
//   * pre_event_return <= -atr_trigger_mult*ATR  -> BUY  (adverse pre-event move
//     into the release, expecting the post-release rebound).
//   * Optional symmetric SELL (P3 only, OFF by default) on the inverse move.
//   * Exit at `event + exit_minutes_after` (primary, time-stop). Emergency SL =
//     atr_stop_mult*ATR from entry. No TP. One position per magic, no pyramiding.
//
// CALENDAR-SCHEMA LIMITATION (flagged in build_result.open_questions / notes):
// The framework news calendar (QM_NewsEvent) stores only {event_utc, currency,
// impact} — NO event NAME / category. The card's "skip US Dept of Labor
// employment statistics" exclusion and the named-release allowlist CANNOT be
// expressed at the EA layer without a framework change. This build implements
// the faithful price-action mechanic gated on currency + high-impact; the
// employment-stat carve-out is documented but not enforced here.
//
// IMPORTANT SETFILE REQUIREMENT (hard_rules_at_risk: news_pause_default):
// This EA deliberately trades INSIDE the news window. The framework OnTick news
// gate (QM_NewsAllowsTrade2) must therefore NOT block the event window, yet the
// calendar must still LOAD (QM_FrameworkInit only loads it when an axis is
// active). Run with:  qm_news_temporal = QM_NEWS_TEMPORAL_OFF  AND
// qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ  — DXZ keeps the calendar loaded
// (any_news_active=true) while QM_NewsInFirmWindow(DXZ) never blocks. With this,
// the strategy reads g_qm_news_events directly and gates its own entry/exit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10945;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// NOTE (see header): for this event-rebound EA the setfile should set
// qm_news_temporal = QM_NEWS_TEMPORAL_OFF and qm_news_compliance =
// QM_NEWS_COMPLIANCE_DXZ so the calendar LOADS but does not blackout the window.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
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
// Pre-event measurement window, in minutes (card default 45; M5 => 9 bars).
input int    strategy_pre_event_minutes   = 45;
// How many minutes BEFORE the event the entry decision is taken (card default 10).
input int    strategy_entry_minutes_before = 10;
// How many minutes AFTER the event the time-stop exit fires (card default 15).
input int    strategy_exit_minutes_after  = 15;
// Adverse pre-event move threshold as a multiple of ATR (card default 0.35).
input double strategy_atr_trigger_mult    = 0.35;
// Emergency stop distance as a multiple of ATR (card default 1.2).
input double strategy_atr_stop_mult       = 1.2;
// ATR period / timeframe for the trigger + stop (card: ATR(14, M5)).
input int    strategy_atr_period          = 14;
// Spread cap as a fraction of ATR (card: skip if spread > 20% of ATR).
input double strategy_spread_atr_frac     = 0.20;
// Optional symmetric SELL leg (card: "P3 only"). OFF by default.
input bool   strategy_allow_short         = false;
// Only consider events within this many minutes ahead when arming an entry.
// Bounds the forward scan and prevents arming days early. Default 60.
input int    strategy_event_lookahead_min = 60;

// -----------------------------------------------------------------------------
// File-scope state. Advanced only on closed bars / at entry — never per-tick.
// -----------------------------------------------------------------------------
// UTC of the event this EA is currently positioned around (0 = flat / unset).
datetime g_active_event_utc = 0;

// Smallest index in g_qm_news_events with event_utc >= target (binary search).
// Local copy of the framework lower-bound so we never linear-scan ~95k events.
int QM_10945_LowerBound(const datetime target)
  {
   const int n = ArraySize(g_qm_news_events);
   int lo = 0;
   int hi = n;
   while(lo < hi)
     {
      const int mid = (lo + hi) / 2;
      if(g_qm_news_events[mid].event_utc < target)
         lo = mid + 1;
      else
         hi = mid;
     }
   return lo;
  }

// Find the next relevant high-impact event at or after `from_utc`, no later than
// `to_utc`. Relevance = affects this symbol's currency AND meets the configured
// minimum impact. Returns 0 if none in the window.
datetime QM_10945_NextEventUTC(const datetime from_utc, const datetime to_utc)
  {
   const int n = ArraySize(g_qm_news_events);
   if(n == 0)
      return 0;
   if(!g_qm_news_events_sorted)
      QM_NewsBuildUtcIndex();

   int i = QM_10945_LowerBound(from_utc);
   for(; i < n; i++)
     {
      if(g_qm_news_events[i].event_utc > to_utc)
         break; // sorted — nothing later can match
      if(!QM_NewsEventAffectsSymbol(g_qm_news_events[i].currency, _Symbol))
         continue;
      if(!QM_NewsImpactMeetsMinimum(g_qm_news_events[i].impact_upper, g_qm_news_min_impact_upper))
         continue;
      return g_qm_news_events[i].event_utc;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// O(1) per-tick block check. Block when the calendar is unavailable (no events
// to trade around) or when the spread is genuinely wide relative to ATR.
// Spread guard is fail-open on zero spread per .DWX invariant #1.
bool Strategy_NoTradeFilter()
  {
   if(!g_qm_news_available || ArraySize(g_qm_news_events) == 0)
      return true; // no calendar -> nothing to trade around

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true; // genuinely no price

   if(strategy_spread_atr_frac > 0.0 && ask > bid)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > (strategy_spread_atr_frac * atr))
         return true; // genuinely wide spread only
     }
   return false;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar()==true (single-consume).
// Arms a trade on the M5 bar nearest to (event - entry_minutes_before) when the
// pre-event return is an adverse move of >= atr_trigger_mult*ATR.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // OnTick already gates this hook behind QM_IsNewBar() (consumed once), so it
   // runs exactly once per closed M5 bar — no per-EA new-bar reimplementation.
   // We read the forming bar's open time only as an absolute timestamp to map
   // the just-closed bar onto the event window (strategy-time math, not cadence).
   const datetime bar_open_broker = iTime(_Symbol, PERIOD_M5, 0);
   if(bar_open_broker <= 0)
      return false;

   // Already positioned around an event — let the time-stop / SL run it out.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // The bar that just CLOSED opened at iTime(...,1); its close timestamp is the
   // open of the current forming bar (bar_open_broker). Decide in UTC.
   const datetime closed_bar_close_utc = QM_BrokerToUTC(bar_open_broker);
   if(closed_bar_close_utc <= 0)
      return false;

   // Find the next relevant event from this close forward, within lookahead.
   const datetime look_to = closed_bar_close_utc + (strategy_event_lookahead_min * 60);
   const datetime ev_utc  = QM_10945_NextEventUTC(closed_bar_close_utc, look_to);
   if(ev_utc <= 0)
      return false;

   // Entry point = event - entry_minutes_before. We act on the LAST closed M5 bar
   // at or before that point. M5 bar = 300s. Fire only when the just-closed bar's
   // close lands in the final M5 slot before the entry point (avoids the
   // exact-tick-minute miss, .DWX invariant #12 — we key off bar times).
   const datetime entry_point_utc = ev_utc - (strategy_entry_minutes_before * 60);
   const int      bar_secs        = PeriodSeconds(PERIOD_M5);
   if(closed_bar_close_utc > entry_point_utc)
      return false;                                   // event/entry point already passed
   if((entry_point_utc - closed_bar_close_utc) >= bar_secs)
      return false;                                   // not yet the trigger bar

   // Pre-event return over strategy_pre_event_minutes from prior CLOSES
   // (gapless CFD: use closes, never prior range — .DWX invariant #6).
   int lookback_bars = strategy_pre_event_minutes / 5;
   if(lookback_bars < 1)
      lookback_bars = 1;
   const double close_recent = QM_SMA(_Symbol, PERIOD_M5, 1, 1, PRICE_CLOSE); // close[1]
   const double close_prior  = QM_SMA(_Symbol, PERIOD_M5, 1, 1 + lookback_bars, PRICE_CLOSE);
   if(close_recent <= 0.0 || close_prior <= 0.0)
      return false;
   const double pre_event_return = close_recent - close_prior;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_trigger_mult <= 0.0)
      return false;
   const double trigger = strategy_atr_trigger_mult * atr;

   QM_OrderType side;
   if(pre_event_return <= -trigger)
      side = QM_BUY;                                  // adverse drop into release -> buy the rebound
   else if(strategy_allow_short && pre_event_return >= trigger)
      side = QM_SELL;                                 // symmetric (P3 only)
   else
      return false;

   const double entry_price = QM_EntryMarketPrice(side);
   if(entry_price <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;                                  // framework fills market price
   req.sl     = QM_StopATRFromValue(_Symbol, side, entry_price, atr, strategy_atr_stop_mult);
   req.tp     = 0.0;                                  // no TP — time-stop is primary
   req.reason = "zuck_event_rebound";
   req.symbol_slot = qm_magic_slot_offset;

   // Latch the event so the time-stop exit knows when to close.
   g_active_event_utc = ev_utc;
   return true;
  }

// No trailing / partials per card. Nothing to do per tick on the open position.
void Strategy_ManageOpenPosition()
  {
   // Card: trade_management.used = false (no trailing or partials).
  }

// Time-stop: close at event + exit_minutes_after. O(1) per-tick check.
bool Strategy_ExitSignal()
  {
   if(g_active_event_utc <= 0)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_active_event_utc = 0;   // position already gone (SL/Friday close) — reset
      return false;
     }

   const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
   if(now_utc <= 0)
      return false;

   const datetime exit_at_utc = g_active_event_utc + (strategy_exit_minutes_after * 60);
   if(now_utc >= exit_at_utc)
     {
      g_active_event_utc = 0;   // consumed — clear for the next event
      return true;
     }
   return false;
  }

// This EA trades INSIDE the news window by design (hard_rules_at_risk:
// news_pause_default). Defer to the framework gate, which the setfile keeps
// non-blocking via qm_news_temporal=OFF + qm_news_compliance=DXZ.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2(...)
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
