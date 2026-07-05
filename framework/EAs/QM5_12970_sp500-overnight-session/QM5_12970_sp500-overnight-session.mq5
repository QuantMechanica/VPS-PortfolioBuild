#property strict
#property version   "5.0"
#property description "QM5_12970 SP500 Overnight Session Premium (close-to-open hold)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_12970 sp500-overnight-session
// Strategy Card: CEO-ANOMALY-SLATE-2026-07-03 (sp500-overnight-session),
// G0 APPROVED 2026-07-03. See D:\QM\strategy_farm\artifacts\cards_approved\
// QM5_12970_sp500-overnight-session.md
//
// Edge: US equity index returns accrue almost entirely overnight (cash close
// -> next cash open); the intraday session nets ~zero (Cooper/Cliff/Gulen 2008,
// Kelly/Clark 2011, Lachance 2020). Mechanical clock rule, no indicators:
//   BUY  at US cash close (16:00 ET)
//   EXIT at next US cash open (09:30 ET)
// Friday close is skipped by default (no weekend hold). Optional regime
// filter (close > SMA200) is OFF by default per the card's "anomaly purity"
// baseline.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12970;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
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
// Card Mechanics §3: Fridays exit at Friday open, NO weekend hold by default.
// Skipping the Friday cash-close entry is what actually prevents a weekend
// hold (the framework Friday-close guard above is a safety net, not the
// mechanism the card describes).
input bool   strategy_friday_flat          = true;
// Card Mechanics §4: optional regime input, close > SMA(200); default OFF
// so the pure overnight-anomaly signal is unfiltered.
input bool   strategy_sma_regime_filter    = false;
input int    strategy_sma_regime_period    = 200;

// -----------------------------------------------------------------------------
// Card mechanics §1: broker time derived from the documented DXZ NY-Close
// model (CLAUDE.md infra constants): broker UTC offset is GMT+2 outside US
// DST / GMT+3 during US DST — the SAME US-DST calendar that defines ET
// (GMT-5 outside DST / GMT-4 during DST). Both legs shift together on every
// US DST transition, so broker time = ET + 7h is constant year-round; no
// separate DST branch is required. Derived (not a bare guess):
//   US cash close 16:00 ET  -> 16:00 + 7h = 23:00 broker  (entry anchor)
//   US cash open  09:30 ET  -> 09:30 + 7h = 16:30 broker  (exit anchor)
// -----------------------------------------------------------------------------
const int SESSION_CLOSE_HOUR_BROKER = 23; // US cash close anchor (entry)
const int SESSION_CLOSE_MIN_BROKER  = 0;
const int SESSION_OPEN_HOUR_BROKER  = 16; // US cash open anchor (exit)
const int SESSION_OPEN_MIN_BROKER   = 30;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No blanket no-trade condition beyond the exact session-clock anchors that
// EntrySignal/ExitSignal already check — must stay false so the exit path
// (which runs on every tick, per the framework OnTick wiring, so the
// overnight hold keeps closing at the cash-open anchor) is never suppressed.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called once per new closed M30 bar (framework gates via QM_IsNewBar before
// invoking this hook). Fires only on the bar that opens at the US cash-close
// broker-time anchor.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;  // Card: no fixed price stop in the pure anomaly definition;
   req.tp = 0.0;  // overnight/session exit + V5 kill-switch bound the risk.
   req.reason = "sp500_overnight_session_close_to_open";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime bar_open = iTime(_Symbol, PERIOD_CURRENT, 0); // perf-allowed: session-anchor bar-open read, called once per new bar (framework QM_IsNewBar gate already passed by the caller)
   if(bar_open <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   if(dt.hour != SESSION_CLOSE_HOUR_BROKER || dt.min != SESSION_CLOSE_MIN_BROKER)
      return false;

   if(strategy_friday_flat)
     {
      // Mon..Sun; Fri/Sat/Sun disabled -> a Friday cash-close entry would hold
      // over the weekend gap, which the card excludes by default.
      bool day_enabled[7] = {true, true, true, true, false, false, false};
      if(QM_Sig_DayOfWeek(bar_open, day_enabled) == 0)
         return false;
     }

   if(strategy_sma_regime_filter)
     {
      const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: single closed-bar close for the optional SMA(200) regime filter, called once per new bar
      const double sma = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_sma_regime_period, 1);
      if(close_1 <= 0.0 || sma <= 0.0 || close_1 <= sma)
         return false;
     }

   return true;
  }

// Runs every tick while a position is open. Card carries no trailing/BE/
// partial-close rule for this pure overnight hold — risk is bounded by the
// V5 kill-switch, not per-trade trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Runs every tick (framework calls this ahead of the QM_IsNewBar gate so the
// overnight hold can close promptly at the cash-open anchor regardless of
// tick spacing). Closes the open position on the bar that opens at the US
// cash-open broker-time anchor.
bool Strategy_ExitSignal()
  {
   const datetime bar_open = iTime(_Symbol, PERIOD_CURRENT, 0); // perf-allowed: session-anchor bar-open read, evaluated every tick by framework design (trade-management path runs ahead of the new-bar gate)
   if(bar_open <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   return (dt.hour == SESSION_OPEN_HOUR_BROKER && dt.min == SESSION_OPEN_MIN_BROKER);
  }

// Optional news-filter override. Defer to the central 2-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// Canonical OnTick order (2026-07-02 audit finding, binding): the news
// blackout gate sits BELOW Strategy_ManageOpenPosition / exit handling and
// gates ONLY the entry path, so position management/exits keep running
// through news windows (see QM5_12821 OnTick after commit dc418a720).
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const int magic = QM_FrameworkMagic();

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (cash-open session anchor). Separate from
   // SL/TP (this EA sets neither).
   if(Strategy_ExitSignal())
     {
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

   // News blackout gates NEW entries only (below it must not sit above the
   // management/exit path above).
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

   // Per-closed-bar: entry-signal evaluation.
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
