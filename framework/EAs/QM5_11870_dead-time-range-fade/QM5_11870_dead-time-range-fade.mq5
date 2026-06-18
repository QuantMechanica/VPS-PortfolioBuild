#property strict
#property version   "5.0"
#property description "QM5_11870 dead-time-range-fade — Dead-Time Range Fade (3pm EST anchor, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11870 dead-time-range-fade
// -----------------------------------------------------------------------------
// Source: Jason Fielder, Forex Trading Cheat Sheets (TriadFormula.com, ~2010).
// Card: artifacts/cards_approved/QM5_11870_dead-time-range-fade.md (g0 APPROVED).
//
// Idea: during the quiet off-hours "dead time" after the US banks close, major
// FX pairs tend to range and revert to the 3pm-EST H1 close (a magnetic anchor)
// rather than trend. We FADE the range extreme: when the anchor candle was
// bullish (close > open) the anchor is a HIGH water mark -> we SHORT when price
// revisits it from below; when bearish (close < open) the anchor is a LOW water
// mark -> we LONG when price revisits it from above. One trade per session.
//
// STATE  (dead-time window + anchor):
//   * Window in UTC = [ref_hour_utc, ref_hour_utc + window_hours).
//     ref_hour_utc = 20 normally, 19 during US DST (3pm EST tracks US DST).
//   * Anchor level + direction captured from the H1 closed bar whose UTC open
//     hour == ref_hour_utc (the "3pm EST" candle): bull -> high water mark,
//     bear -> low water mark.
// EVENT  (single trigger, one per closed bar, one fill per session):
//   * Bull anchor: bar HIGH of a closed window bar >= anchor  -> SHORT fade.
//   * Bear anchor: bar LOW  of a closed window bar <= anchor  -> LONG  fade.
//   The touch is the lone trigger EVENT; the window+anchor are STATE. No
//   two-cross-same-bar trap: a single inequality on one bar fires the entry.
// EXIT   : fixed SL/TP in pips (12/12, 1:1) via QM_StopFixedPips + QM_TakeRR.
//
// Broker time -> UTC via QM_BrokerToUTC; US DST via QM_IsUSDSTUTC. Only the 5
// Strategy_* hooks + Strategy inputs are EA-specific; framework wiring is intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11870;
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
// Dead-time window in UTC. 3pm EST = 20:00 UTC (non-DST) / 19:00 UTC (US DST);
// the window runs 3pm-7pm EST = 4 hours. ref_hour is the non-DST UTC anchor
// hour; during US DST the anchor + window shift one hour earlier automatically.
input int    strategy_ref_hour_utc        = 20;    // anchor UTC hour (non-DST 3pm EST)
input int    strategy_window_hours        = 4;     // dead-time window length (hours)
input bool   strategy_dst_shift           = true;  // shift anchor/window -1h during US DST
input int    strategy_sl_pips             = 12;    // fixed stop distance in pips
input int    strategy_tp_pips             = 12;    // fixed target distance in pips (1:1)
input int    strategy_touch_buffer_pips   = 0;     // extra pips past anchor required to trigger

// -----------------------------------------------------------------------------
// File-scope session STATE (advanced once per closed bar via the new-bar gate).
// -----------------------------------------------------------------------------
int      g_session_day        = -1;     // day-of-year of the current session's anchor
double   g_anchor_level       = 0.0;    // captured anchor (3pm EST close)
int      g_anchor_dir         = 0;      // +1 bull (high water mark) / -1 bear / 0 none
bool     g_anchor_set         = false;  // anchor captured for the current session?
bool     g_traded_session     = false;  // already fired one entry this session?

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Effective anchor UTC hour, shifted -1h during US DST when enabled.
int Strategy_AnchorHourUTC(const datetime utc_now)
  {
   int h = strategy_ref_hour_utc;
   if(strategy_dst_shift && QM_IsUSDSTUTC(utc_now))
      h -= 1;
   if(h < 0)  h += 24;
   if(h > 23) h -= 24;
   return h;
  }

// UTC hour of a given UTC datetime.
int Strategy_HourOfUTC(const datetime utc_time)
  {
   MqlDateTime mdt;
   TimeToStruct(utc_time, mdt);
   return mdt.hour;
  }

// True if utc_hour lies inside [anchor_hour, anchor_hour + window_hours),
// wrap-safe across midnight.
bool Strategy_InWindow(const int utc_hour, const int anchor_hour)
  {
   const int span = strategy_window_hours;
   for(int k = 0; k < span; ++k)
     {
      int hh = anchor_hour + k;
      if(hh > 23) hh -= 24;
      if(hh == utc_hour)
         return true;
     }
   return false;
  }

// Advance per-closed-bar session state. Called once per new closed bar AFTER
// the framework QM_IsNewBar() gate passes — no second timestamp gate here.
// Reads the just-closed bar (shift 1) only.
void Strategy_AdvanceState_OnNewBar()
  {
   // perf-allowed: single closed-bar reads at fixed shift 1 (no history scan).
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return;
   datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   if(bar_open_utc <= 0)
      bar_open_utc = bar_open_broker; // defensive fallback; broker~UTC ordering

   MqlDateTime mdt;
   TimeToStruct(bar_open_utc, mdt);
   const int bar_hour = mdt.hour;
   const int bar_doy  = mdt.day_of_year;

   const int anchor_hour = Strategy_AnchorHourUTC(bar_open_utc);

   // New session begins when the anchor bar (the "3pm EST" candle) closes.
   if(bar_hour == anchor_hour)
     {
      const double o = iOpen(_Symbol, _Period, 1);
      const double c = iClose(_Symbol, _Period, 1);
      if(o > 0.0 && c > 0.0)
        {
         g_anchor_level    = c;            // anchor = 3pm-EST candle CLOSE
         g_anchor_dir      = (c > o) ? +1 : ((c < o) ? -1 : 0);
         g_anchor_set      = (g_anchor_dir != 0);
         g_session_day     = bar_doy;
         g_traded_session  = false;        // fresh session; one trade allowed
        }
      else
        {
         g_anchor_set = false;
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Block when outside the dead-time UTC window so the
// per-tick path stays trivial. Fail-open on missing quote/time.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   datetime utc_now = QM_BrokerToUTC(broker_now);
   if(utc_now <= 0)
      utc_now = broker_now;

   const int anchor_hour = Strategy_AnchorHourUTC(utc_now);
   const int utc_hour    = Strategy_HourOfUTC(utc_now);
   if(!Strategy_InWindow(utc_hour, anchor_hour))
      return true; // outside dead-time window -> block
   return false;
  }

// Counter-trend fade entry. Caller guarantees QM_IsNewBar()==true (closed bar).
// One trade per session; window membership already checked per-bar here too.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_anchor_set || g_traded_session)
      return false;

   // Confirm the just-closed bar sits inside the dead-time window (in UTC).
   // perf-allowed: single closed-bar timestamp read at shift 1.
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return false;
   datetime bar_open_utc = QM_BrokerToUTC(bar_open_broker);
   if(bar_open_utc <= 0)
      bar_open_utc = bar_open_broker;

   const int anchor_hour = Strategy_AnchorHourUTC(bar_open_utc);
   const int bar_hour    = Strategy_HourOfUTC(bar_open_utc);
   if(!Strategy_InWindow(bar_hour, anchor_hour))
      return false;

   // Do not trade on the anchor bar itself — touch must be a LATER window bar.
   if(bar_hour == anchor_hour)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_touch_buffer_pips);

   // perf-allowed: single closed-bar high/low reads at shift 1.
   const double bar_high = iHigh(_Symbol, _Period, 1);
   const double bar_low  = iLow(_Symbol, _Period, 1);
   if(bar_high <= 0.0 || bar_low <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   bool triggered = false;

   if(g_anchor_dir > 0)
     {
      // Bull anchor = HIGH water mark. Price revisits from below -> fade SHORT
      // when the closed bar's high reaches (or pierces by buffer) the anchor.
      if(bar_high >= g_anchor_level + buffer)
        {
         side = QM_SELL;
         triggered = true;
        }
     }
   else if(g_anchor_dir < 0)
     {
      // Bear anchor = LOW water mark. Price revisits from above -> fade LONG
      // when the closed bar's low reaches (or pierces by buffer) the anchor.
      if(bar_low <= g_anchor_level - buffer)
        {
         side = QM_BUY;
         triggered = true;
        }
     }

   if(!triggered)
      return false;

   const double entry = (side == QM_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   if(strategy_sl_pips <= 0)
      return false;
   const double rr = (double)strategy_tp_pips / (double)strategy_sl_pips;
   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0; // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_SELL) ? "deadtime_fade_short" : "deadtime_fade_long";

   g_traded_session = true; // one trade per session
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP. (Open position rides to SL or TP; any
// unfilled-by-window concept is moot here — we enter at market on the touch.)
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

   // Advance closed-bar session state (anchor capture / session reset) FIRST,
   // then evaluate the single entry trigger for this new closed bar.
   Strategy_AdvanceState_OnNewBar();

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
